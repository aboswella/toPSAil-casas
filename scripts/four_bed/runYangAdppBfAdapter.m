function [terminalLocalStates, adapterReport] = runYangAdppBfAdapter(tempCase, templateParams, adapterConfig)
%RUNYANGADPPBFADAPTER Run the FI-5 Yang AD&PP->BF direct-coupling adapter.

    if nargin < 3
        adapterConfig = struct();
    end

    [adapterConfig, validationReport] = validateYangAdppBfAdapterInputs( ...
        tempCase, templateParams, adapterConfig);
    adapterReport = initializeReport(tempCase, adapterConfig, validationReport);

    if adapterConfig.validationOnly
        [terminalLocalStates, adapterReport] = runValidationOnly( ...
            tempCase, templateParams, adapterConfig, adapterReport);
        return;
    end

    [params, prepReport] = prepareYangAdppBfAdapterLocalRunParams( ...
        tempCase, templateParams, adapterConfig);
    adapterReport.localRunPreparation = prepReport;

    [tDom, timeReport] = resolveTimeDomain(params, adapterConfig);
    adapterReport.durationSeconds = timeReport.durationSeconds;
    adapterReport.durationDimless = timeReport.durationDimless;
    adapterReport.timeBasis = timeReport.timeBasis;

    initialPressure = summarizeInitialPressure(params, tempCase);
    initialInventory = computeInitialInventories(params, tempCase);

    [stTime, stStates, flags] = runPsaCycleStep(params, params.initStates, tDom, 1, 1);
    [terminalLocalStates, counterTailReport] = extractYangTerminalLocalStates( ...
        params, stStates, tempCase);

    flowReport = integrateYangAdppBfAdapterFlows(params, stTime, stStates, adapterConfig);
    finalPressure = summarizeTerminalPressure(params, terminalLocalStates);
    finalInventory = computeTerminalInventories(params, terminalLocalStates);
    conservation = computeConservationDiagnostics( ...
        initialInventory, finalInventory, flowReport, adapterConfig);
    sanity = computeSanityDiagnostics(params, stStates, initialPressure, finalPressure);

    adapterReport.solverRunStatus = "completed_native_runPsaCycleStep";
    adapterReport.didInvokeNative = true;
    adapterReport.timeDomain = tDom;
    adapterReport.flags = flags;
    adapterReport.counterTailReport = counterTailReport;
    adapterReport.pressureDiagnostics = struct( ...
        "initial", initialPressure, ...
        "terminal", finalPressure);
    adapterReport.flows = flowReport.native;
    adapterReport.flowReport = flowReport;
    adapterReport.effectiveSplit = flowReport.effectiveSplit;
    adapterReport.conservation = conservation;
    adapterReport.sanity = sanity;
    adapterReport.terminalPhysicalStateChecksums = ...
        computeYangPhysicalStateChecksums(params, terminalLocalStates, tempCase.localMap);
    adapterReport.warnings = collectWarnings(adapterReport, sanity, conservation, flowReport);

    if adapterConfig.debugKeepStateHistory
        adapterReport.debugStateHistory = struct( ...
            "stTime", stTime, ...
            "stStates", stStates);
    end
end

function report = initializeReport(tempCase, config, validationReport)
    report = struct();
    report.version = "FI5-Yang2009-ADPP-BF-adapter-report-v1";
    report.payloadType = "yang_adpp_bf_adapter_report_v1";
    report.directTransferFamily = "ADPP_BF";
    report.runner = "wrapper_direct_coupling_adapter";
    report.nativeStepGrammarUsed = false;
    report.noDynamicInternalTanks = true;
    report.noSharedHeaderInventory = true;
    report.noFourBedRhsDae = true;
    report.noCoreAdsorberPhysicsRewrite = true;
    report.cycleIndex = config.cycleIndex;
    report.slotIndex = config.slotIndex;
    report.pairId = string(tempCase.pairId);
    report.sourceColumns = tempCase.localMap.source_col(:);
    report.donorBed = string(tempCase.localMap.global_bed(1));
    report.receiverBed = string(tempCase.localMap.global_bed(2));
    report.donorRecordId = string(tempCase.localMap.record_id(1));
    report.receiverRecordId = string(tempCase.localMap.record_id(2));
    report.localMap = tempCase.localMap;
    report.operationGroupId = string(config.operationGroupId);
    report.configVersion = string(config.version);
    report.inputValidation = validationReport;
    report.durationSeconds = config.durationSeconds;
    report.durationDimless = config.durationDimless;
    report.timeBasis = "not_resolved";
    report.Cv_directTransfer = config.Cv_directTransfer;
    report.derivedConductance = config.derivedConductance;
    report.ADPP_BF_internalSplitFraction = config.ADPP_BF_internalSplitFraction;
    report.ADPP_BF_splitMode = string(config.ADPP_BF_splitMode);
    report.ADPP_BF_internalCvPolicy = string(config.ADPP_BF_internalCvPolicy);
    report.rawCv = config.rawCv;
    report.effectiveCv = config.effectiveCv;
    report.valveCoefficientBasis = string(config.valveCoefficientBasis);
    report.adapterCvScalingApplied = logical(config.adapterCvScalingApplied);
    report.valScaleFac = config.valScaleFac;
    report.feedPressureRatio = config.feedPressureRatio;
    report.feedPressureBasis = string(config.feedPressureBasis);
    report.externalProductPressureRatio = config.externalProductPressureRatio;
    report.externalProductPressureBasis = string(config.externalProductPressureBasis);
    report.allowReverseFeedFlow = logical(config.allowReverseFeedFlow);
    report.allowReverseProductFlow = logical(config.allowReverseProductFlow);
    report.allowReverseInternalFlow = logical(config.allowReverseInternalFlow);
    report.componentNames = string(config.componentNames(:));
    report.conservationAbsTol = config.conservationAbsTol;
    report.conservationRelTol = config.conservationRelTol;
    report.solverRunStatus = "not_started";
    report.didInvokeNative = false;
    report.flows = makeZeroFlowSchema(numel(config.componentNames));
    report.effectiveSplit = makeEmptyEffectiveSplit(config, report.flows.unitBasis);
    report.warnings = strings(0, 1);
end

function [terminalLocalStates, report] = runValidationOnly(tempCase, params, config, report)
    requireValidationOnlyParams(params);
    terminalLocalStates = cell(tempCase.nLocalBeds, 1);
    for i = 1:tempCase.nLocalBeds
        terminalLocalStates{i} = extractYangPhysicalBedState(params, ...
            tempCase.localStates{i}, 'Metadata', makeStateMetadata(tempCase, i));
    end

    pressure = summarizeTerminalPressure(params, terminalLocalStates);
    report.solverRunStatus = "validation_only_no_native_solver_invocation";
    report.didInvokeNative = false;
    report.timeBasis = "validation_only_not_integrated";
    report.pressureDiagnostics = struct( ...
        "initial", pressure, ...
        "terminal", pressure);
    report.flows = makeZeroFlowSchema(numel(config.componentNames));
    report.flowReport = struct( ...
        "native", report.flows, ...
        "moles", struct("unitBasis", "not_evaluated_validation_only"), ...
        "flowSigns", makeZeroFlowSigns(config), ...
        "rateSamples", makeZeroRateSamples(numel(config.componentNames)), ...
        "effectiveSplit", makeEmptyEffectiveSplit(config, report.flows.unitBasis));
    report.effectiveSplit = report.flowReport.effectiveSplit;
    report.conservation = struct( ...
        "evaluated", false, ...
        "pass", false, ...
        "unitBasis", "not_evaluated_validation_only", ...
        "reason", "validationOnly mode checks the AD&PP->BF contract without integrating dynamics");
    report.sanity = computeSanityFromPayloads(params, terminalLocalStates, pressure);
    report.terminalPhysicalStateChecksums = ...
        computeYangPhysicalStateChecksums(params, terminalLocalStates, tempCase.localMap);
    report.warnings = [
        "validationOnly mode did not integrate AD&PP->BF dynamics"
        report.sanity.warnings(:)
    ];
end

function requireValidationOnlyParams(params)
    if ~isstruct(params) || ~isfield(params, 'nColSt') || ...
            ~isfield(params, 'nColStT') || ~isfield(params, 'nComs') || ...
            ~isfield(params, 'nVols')
        error('FI5:TemplateParamsNotRunnable', ...
            'Validation-only AD&PP->BF adapter checks require nComs, nVols, nColSt, and nColStT.');
    end
end

function [tDom, timeReport] = resolveTimeDomain(params, config)
    if ~isempty(config.durationDimless)
        durationDimless = config.durationDimless;
        timeBasis = "dimensionless";
        durationSeconds = [];
    elseif isfield(params, 'tiScaleFac') && ~isempty(params.tiScaleFac)
        durationDimless = config.durationSeconds ./ params.tiScaleFac;
        timeBasis = "seconds_converted_to_dimensionless_using_tiScaleFac";
        durationSeconds = config.durationSeconds;
    else
        error('FI5:CannotConvertDurationSeconds', ...
            'durationSeconds was supplied but templateParams.tiScaleFac is missing.');
    end
    tDom = [0, durationDimless];
    timeReport = struct( ...
        "durationSeconds", durationSeconds, ...
        "durationDimless", durationDimless, ...
        "timeBasis", timeBasis);
end

function pressure = summarizeInitialPressure(params, tempCase)
    pressure = struct();
    pressure.donor = summarizeYangBedPressureProfile(params, tempCase.localStates{1});
    pressure.receiver = summarizeYangBedPressureProfile(params, tempCase.localStates{2});
    pressure.donorInitialFeedEndPressureRatio = pressure.donor.feedEndPressureRatio;
    pressure.donorInitialProductEndPressureRatio = pressure.donor.productEndPressureRatio;
    pressure.receiverInitialProductEndPressureRatio = pressure.receiver.productEndPressureRatio;
    pressure.receiverInitialFeedEndPressureRatio = pressure.receiver.feedEndPressureRatio;
end

function pressure = summarizeTerminalPressure(params, terminalLocalStates)
    pressure = struct();
    pressure.donor = summarizeYangBedPressureProfile(params, terminalLocalStates{1});
    pressure.receiver = summarizeYangBedPressureProfile(params, terminalLocalStates{2});
    pressure.donorTerminalFeedEndPressureRatio = pressure.donor.feedEndPressureRatio;
    pressure.donorTerminalProductEndPressureRatio = pressure.donor.productEndPressureRatio;
    pressure.receiverTerminalProductEndPressureRatio = pressure.receiver.productEndPressureRatio;
    pressure.receiverTerminalFeedEndPressureRatio = pressure.receiver.feedEndPressureRatio;
end

function inventories = computeInitialInventories(params, tempCase)
    inventories = struct();
    inventories.donor = computeYangBedComponentInventory(params, tempCase.localStates{1});
    inventories.receiver = computeYangBedComponentInventory(params, tempCase.localStates{2});
end

function inventories = computeTerminalInventories(params, terminalLocalStates)
    inventories = struct();
    inventories.donor = computeYangBedComponentInventory(params, terminalLocalStates{1});
    inventories.receiver = computeYangBedComponentInventory(params, terminalLocalStates{2});
end

function conservation = computeConservationDiagnostics(initialInventory, finalInventory, flowReport, config)
    donorInitial = initialInventory.donor.native.totalByComponent;
    donorFinal = finalInventory.donor.native.totalByComponent;
    receiverInitial = initialInventory.receiver.native.totalByComponent;
    receiverFinal = finalInventory.receiver.native.totalByComponent;

    donorDelta = donorFinal - donorInitial;
    receiverDelta = receiverFinal - receiverInitial;
    pairDelta = donorDelta + receiverDelta;
    externalFeed = flowReport.native.externalFeedByComponent;
    externalProduct = flowReport.native.externalProductByComponent;
    internalOut = flowReport.native.internalTransferOutByComponent;
    internalIn = flowReport.native.internalTransferInByComponent;

    internalMismatch = internalOut - internalIn;
    donorResidual = donorDelta - externalFeed + externalProduct + internalOut;
    receiverResidual = receiverDelta - internalIn;
    pairResidual = pairDelta - externalFeed + externalProduct;

    scale = max(1, max(abs([ ...
        donorDelta
        receiverDelta
        externalFeed
        externalProduct
        internalOut
    ])));
    absTol = config.conservationAbsTol;
    relTol = config.conservationRelTol;
    threshold = absTol + relTol .* scale;
    pass = all(abs([donorResidual; receiverResidual; pairResidual; internalMismatch]) <= threshold);

    conservation = struct();
    conservation.evaluated = true;
    conservation.unitBasis = flowReport.native.unitBasis;
    conservation.donorInventoryDeltaByComponent = donorDelta;
    conservation.receiverInventoryDeltaByComponent = receiverDelta;
    conservation.pairInventoryDeltaByComponent = pairDelta;
    conservation.externalFeedByComponent = externalFeed;
    conservation.externalProductByComponent = externalProduct;
    conservation.internalTransferOutByComponent = internalOut;
    conservation.internalTransferInByComponent = internalIn;
    conservation.internalTransferMismatchByComponent = internalMismatch;
    conservation.donorResidualByComponent = donorResidual;
    conservation.receiverResidualByComponent = receiverResidual;
    conservation.pairResidualByComponent = pairResidual;
    conservation.absTol = absTol;
    conservation.relTol = relTol;
    conservation.threshold = threshold;
    conservation.pass = pass;
end

function sanity = computeSanityDiagnostics(params, stStates, initialPressure, finalPressure)
    nCols = 2;
    hasNaN = any(isnan(stStates), "all");
    hasNegativeConcentration = false;
    hasInvalidMoleFraction = false;
    for i = 1:nCols
        local = stStates(end, (i-1)*params.nColStT+1:i*params.nColStT);
        localSanity = inspectLocalState(params, local);
        hasNegativeConcentration = hasNegativeConcentration || localSanity.hasNegativeConcentration;
        hasInvalidMoleFraction = hasInvalidMoleFraction || localSanity.hasInvalidMoleFraction;
    end

    hasNegativePressure = initialPressure.donor.hasNegativePressure || ...
        initialPressure.receiver.hasNegativePressure || ...
        finalPressure.donor.hasNegativePressure || ...
        finalPressure.receiver.hasNegativePressure;

    sanity = struct();
    sanity.hasNaN = hasNaN;
    sanity.hasNegativePressure = hasNegativePressure;
    sanity.hasNegativeConcentration = hasNegativeConcentration;
    sanity.hasInvalidMoleFraction = hasInvalidMoleFraction;
    sanity.warnings = makeSanityWarnings(sanity);
end

function sanity = computeSanityFromPayloads(params, terminalLocalStates, pressure)
    hasNaN = false;
    hasNegativeConcentration = false;
    hasInvalidMoleFraction = false;
    for i = 1:numel(terminalLocalStates)
        localSanity = inspectLocalState(params, terminalLocalStates{i});
        hasNaN = hasNaN || localSanity.hasNaN;
        hasNegativeConcentration = hasNegativeConcentration || localSanity.hasNegativeConcentration;
        hasInvalidMoleFraction = hasInvalidMoleFraction || localSanity.hasInvalidMoleFraction;
    end
    sanity = struct();
    sanity.hasNaN = hasNaN;
    sanity.hasNegativePressure = pressure.donor.hasNegativePressure || ...
        pressure.receiver.hasNegativePressure;
    sanity.hasNegativeConcentration = hasNegativeConcentration;
    sanity.hasInvalidMoleFraction = hasInvalidMoleFraction;
    sanity.warnings = makeSanityWarnings(sanity);
end

function localSanity = inspectLocalState(params, payload)
    physical = extractYangPhysicalBedState(params, payload);
    vector = physical.physicalStateVector(:);
    nComs = params.nComs;
    nVols = params.nVols;
    nStates = params.nStates;
    reshaped = reshape(vector(1:nStates*nVols), nStates, nVols).';
    gas = reshaped(:, 1:nComs);
    ads = reshaped(:, nComs+1:2*nComs);
    gasTotal = sum(gas, 2);
    moleFrac = gas ./ max(gasTotal, eps);

    localSanity = struct();
    localSanity.hasNaN = any(isnan(vector));
    localSanity.hasNegativeConcentration = any(gas < -eps, "all") || ...
        any(ads < -eps, "all");
    localSanity.hasInvalidMoleFraction = any(gasTotal <= 0) || ...
        any(abs(sum(moleFrac, 2) - 1) > 1e-8);
end

function warnings = makeSanityWarnings(sanity)
    warnings = strings(0, 1);
    if sanity.hasNaN
        warnings(end+1, 1) = "state history or terminal payload contains NaN";
    end
    if sanity.hasNegativePressure
        warnings(end+1, 1) = "pressure summary contains a negative pressure ratio";
    end
    if sanity.hasNegativeConcentration
        warnings(end+1, 1) = "state payload contains a negative concentration";
    end
    if sanity.hasInvalidMoleFraction
        warnings(end+1, 1) = "state payload contains invalid gas mole fractions";
    end
end

function warnings = collectWarnings(report, sanity, conservation, flowReport)
    warnings = sanity.warnings(:);
    if ~conservation.pass
        warnings(end+1, 1) = "AD&PP->BF component conservation residual exceeded tolerance";
    end
    signs = flowReport.flowSigns;
    if ~report.allowReverseFeedFlow && signs.reverseFeedSampleCount > 0
        warnings(end+1, 1) = "AD&PP->BF feed flow reversed with allowReverseFeedFlow=false";
    end
    if ~report.allowReverseProductFlow && signs.reverseProductSampleCount > 0
        warnings(end+1, 1) = "AD&PP->BF external product flow reversed with allowReverseProductFlow=false";
    end
    if ~report.allowReverseInternalFlow && signs.reverseInternalSampleCount > 0
        warnings(end+1, 1) = "AD&PP->BF internal BF flow reversed with allowReverseInternalFlow=false";
    end
    splitDen = flowReport.native.internalTransferOutByComponent + ...
        flowReport.native.externalProductByComponent;
    if all(abs(splitDen) <= eps)
        warnings(end+1, 1) = "AD&PP->BF effective split denominator was zero";
    end
end

function flows = makeZeroFlowSchema(nComs)
    flows = struct();
    flows.unitBasis = "native_dimensionless_integral";
    flows.externalFeedByComponent = zeros(nComs, 1);
    flows.externalProductByComponent = zeros(nComs, 1);
    flows.internalTransferOutByComponent = zeros(nComs, 1);
    flows.internalTransferInByComponent = zeros(nComs, 1);
    flows.externalWasteByComponent = zeros(nComs, 1);
    flows.totalExternalFeed = 0;
    flows.totalExternalProduct = 0;
    flows.totalInternalTransferOut = 0;
    flows.totalInternalTransferIn = 0;
    flows.totalExternalWaste = 0;
end

function signs = makeZeroFlowSigns(config)
    zerosSample = 0;
    signs = struct();
    signs.donorFeedEnd = makeZeroSignSummary(zerosSample, "nonnegative_expected");
    signs.donorProductEnd = makeZeroSignSummary(zerosSample, "nonnegative_expected");
    signs.receiverProductEnd = makeZeroSignSummary(zerosSample, "nonpositive_expected");
    signs.receiverFeedEnd = makeZeroSignSummary(zerosSample, "zero_expected");
    signs.allowReverseFeedFlow = logical(config.allowReverseFeedFlow);
    signs.allowReverseProductFlow = logical(config.allowReverseProductFlow);
    signs.allowReverseInternalFlow = logical(config.allowReverseInternalFlow);
    signs.reverseFeedSampleCount = 0;
    signs.reverseProductSampleCount = 0;
    signs.reverseInternalSampleCount = 0;
end

function one = makeZeroSignSummary(values, expectation)
    one = struct();
    one.expectation = string(expectation);
    one.min = min(values);
    one.max = max(values);
    one.zeroCount = sum(values == 0);
    one.positiveCount = sum(values > 0);
    one.negativeCount = sum(values < 0);
end

function samples = makeZeroRateSamples(nComs)
    samples = struct();
    samples.externalFeedByComponent = zeros(1, nComs);
    samples.externalProductByComponent = zeros(1, nComs);
    samples.internalOutByComponent = zeros(1, nComs);
    samples.internalInByComponent = zeros(1, nComs);
    samples.externalWasteByComponent = zeros(1, nComs);
    samples.donorFeedVol = 0;
    samples.donorProductVol = 0;
    samples.receiverProductVol = 0;
    samples.receiverFeedVol = 0;
end

function split = makeEmptyEffectiveSplit(config, unitBasis)
    nComs = numel(config.componentNames);
    split = struct();
    split.unitBasis = unitBasis;
    split.H2 = NaN;
    split.total = NaN;
    split.requestedInternalSplitFraction = config.ADPP_BF_internalSplitFraction;
    split.componentNames = string(config.componentNames(:));
    split.byComponent = NaN(nComs, 1);
    split.primaryControl = "ADPP_BF_internalSplitFraction";
    split.conductanceControl = "Cv_directTransfer";
end

function metadata = makeStateMetadata(tempCase, localIndex)
    metadata = struct();
    metadata.source = "FI5 ADPP_BF adapter validation-only";
    metadata.pairId = string(tempCase.pairId);
    metadata.directTransferFamily = string(tempCase.directTransferFamily);
    metadata.localIndex = localIndex;
    metadata.localRole = string(tempCase.localMap.local_role(localIndex));
    metadata.globalBed = string(tempCase.localMap.global_bed(localIndex));
    metadata.yangLabel = string(tempCase.localMap.yang_label(localIndex));
    metadata.recordId = string(tempCase.localMap.record_id(localIndex));
    metadata.sourceCol = tempCase.localMap.source_col(localIndex);
end
