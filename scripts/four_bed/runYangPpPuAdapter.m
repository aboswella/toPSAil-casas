function [terminalLocalStates, adapterReport] = runYangPpPuAdapter(tempCase, templateParams, adapterConfig)
%RUNYANGPPPUADAPTER Run the FI-4 Yang PP->PU direct-coupling adapter.

    if nargin < 3
        adapterConfig = struct();
    end

    [adapterConfig, validationReport] = validateYangDirectCouplingAdapterInputs( ...
        tempCase, templateParams, adapterConfig);
    adapterReport = initializeReport(tempCase, adapterConfig, validationReport);

    if adapterConfig.validationOnly
        [terminalLocalStates, adapterReport] = runValidationOnly( ...
            tempCase, templateParams, adapterConfig, adapterReport);
        return;
    end

    [params, prepReport] = prepareYangAdapterLocalRunParams( ...
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

    sampledFlowReport = integrateYangPpPuAdapterFlows(params, stTime, stStates, adapterConfig);
    flowReport = buildYangPpPuCounterFlowReport( ...
        params, stTime, stStates, adapterConfig, sampledFlowReport);
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
    report.version = "FI4-Yang2009-PP-PU-adapter-report-v1";
    report.payloadType = "yang_pp_pu_adapter_report_v1";
    report.directTransferFamily = "PP_PU";
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
    report.rawCv = config.rawCv;
    report.effectiveCv = config.effectiveCv;
    report.valveCoefficientBasis = string(config.valveCoefficientBasis);
    report.adapterCvScalingApplied = logical(config.adapterCvScalingApplied);
    report.valScaleFac = config.valScaleFac;
    report.receiverWastePressureRatio = config.receiverWastePressureRatio;
    report.receiverWastePressureBasis = string(config.receiverWastePressureBasis);
    report.receiverWastePressureClass = string(config.receiverWastePressureClass);
    report.PP_PU_wasteCouplingPolicy = string(config.PP_PU_wasteCouplingPolicy);
    report.PP_PU_wasteCouplingAlpha = config.PP_PU_wasteCouplingAlpha;
    report.allowReverseInternalFlow = logical(config.allowReverseInternalFlow);
    report.allowReverseWasteFlow = logical(config.allowReverseWasteFlow);
    report.componentNames = string(config.componentNames(:));
    report.conservationAbsTol = config.conservationAbsTol;
    report.conservationRelTol = config.conservationRelTol;
    report.solverRunStatus = "not_started";
    report.didInvokeNative = false;
    report.flows = makeZeroFlowSchema(numel(config.componentNames));
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
        "moles", struct("unitBasis", "not_evaluated_validation_only"));
    report.conservation = struct( ...
        "evaluated", false, ...
        "pass", false, ...
        "unitBasis", "not_evaluated_validation_only", ...
        "reason", "validationOnly mode checks the PP->PU contract without integrating dynamics");
    report.sanity = computeSanityFromPayloads(params, terminalLocalStates, pressure);
    report.terminalPhysicalStateChecksums = ...
        computeYangPhysicalStateChecksums(params, terminalLocalStates, tempCase.localMap);
    report.warnings = [
        "validationOnly mode did not integrate PP->PU dynamics"
        report.sanity.warnings(:)
    ];
end

function requireValidationOnlyParams(params)
    if ~isstruct(params) || ~isfield(params, 'nColSt') || ...
            ~isfield(params, 'nColStT') || ~isfield(params, 'nComs') || ...
            ~isfield(params, 'nVols')
        error('FI4:TemplateParamsNotRunnable', ...
            'Validation-only PP->PU adapter checks require nComs, nVols, nColSt, and nColStT.');
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
        error('FI4:CannotConvertDurationSeconds', ...
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
    pressure.donorInitialProductEndPressureRatio = pressure.donor.productEndPressureRatio;
    pressure.receiverInitialProductEndPressureRatio = pressure.receiver.productEndPressureRatio;
    pressure.receiverInitialFeedEndPressureRatio = pressure.receiver.feedEndPressureRatio;
end

function pressure = summarizeTerminalPressure(params, terminalLocalStates)
    pressure = struct();
    pressure.donor = summarizeYangBedPressureProfile(params, terminalLocalStates{1});
    pressure.receiver = summarizeYangBedPressureProfile(params, terminalLocalStates{2});
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
    internalOut = flowReport.native.internalTransferOutByComponent;
    internalIn = flowReport.native.internalTransferInByComponent;
    externalWaste = flowReport.native.externalWasteByComponent;

    donorResidual = donorDelta + internalOut;
    receiverResidual = receiverDelta - internalIn + externalWaste;
    pairResidual = pairDelta + externalWaste;
    internalMismatch = internalOut - internalIn;

    scale = max(1, max(abs([donorDelta; receiverDelta; internalOut; externalWaste])));
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
        warnings(end+1, 1) = "PP->PU component conservation residual exceeded tolerance";
    end
    signs = flowReport.flowSigns;
    if ~report.allowReverseInternalFlow && signs.reverseInternalSampleCount > 0
        warnings(end+1, 1) = "PP->PU internal flow reversed with allowReverseInternalFlow=false";
    end
    if ~report.allowReverseWasteFlow && signs.reverseWasteSampleCount > 0
        warnings(end+1, 1) = "PP->PU waste flow reversed with allowReverseWasteFlow=false";
    end
end

function flows = makeZeroFlowSchema(nComs)
    flows = struct();
    flows.unitBasis = "native_dimensionless_integral";
    flows.internalTransferOutByComponent = zeros(nComs, 1);
    flows.internalTransferInByComponent = zeros(nComs, 1);
    flows.externalWasteByComponent = zeros(nComs, 1);
    flows.externalProductByComponent = zeros(nComs, 1);
    flows.totalInternalTransferOut = 0;
    flows.totalInternalTransferIn = 0;
    flows.totalExternalWaste = 0;
end

function metadata = makeStateMetadata(tempCase, localIndex)
    metadata = struct();
    metadata.source = "FI4 PP->PU adapter validation-only";
    metadata.pairId = string(tempCase.pairId);
    metadata.directTransferFamily = string(tempCase.directTransferFamily);
    metadata.localIndex = localIndex;
    metadata.localRole = string(tempCase.localMap.local_role(localIndex));
    metadata.globalBed = string(tempCase.localMap.global_bed(localIndex));
    metadata.yangLabel = string(tempCase.localMap.yang_label(localIndex));
    metadata.recordId = string(tempCase.localMap.record_id(localIndex));
    metadata.sourceCol = tempCase.localMap.source_col(localIndex);
end
