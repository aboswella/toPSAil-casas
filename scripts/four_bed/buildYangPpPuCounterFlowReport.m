function flowReport = buildYangPpPuCounterFlowReport(params, stTime, stStates, adapterConfig, sampledFlowReport)
%BUILDYANGPPPUCOUNTERFLOWREPORT Build PP->PU flows from native counters.

    if nargin < 5 || isempty(sampledFlowReport)
        sampledFlowReport = integrateYangPpPuAdapterFlows( ...
            params, stTime, stStates, adapterConfig);
    end

    counterDeltas = computeYangCounterTailDeltasFromStates(params, stStates, 2);
    [donorFeedDelta, donorProductDelta] = splitYangBoundaryCounterTail( ...
        params, counterDeltas{1});
    [receiverFeedDelta, receiverProductDelta] = splitYangBoundaryCounterTail( ...
        params, counterDeltas{2});

    nativeInternalOut = expectedNonnegativeCounterAmount( ...
        donorProductDelta, "PP_PU donor product-end out", ...
        adapterConfig.conservationAbsTol, adapterConfig.conservationRelTol);
    nativeInternalIn = expectedNonnegativeCounterAmount( ...
        -receiverProductDelta, "PP_PU receiver product-end in", ...
        adapterConfig.conservationAbsTol, adapterConfig.conservationRelTol);
    nativeWaste = expectedNonnegativeCounterAmount( ...
        receiverFeedDelta, "PP_PU receiver feed-end waste out", ...
        adapterConfig.conservationAbsTol, adapterConfig.conservationRelTol);

    assertNoUnsupportedReverseFlow(sampledFlowReport.flowSigns, adapterConfig);

    flowReport = struct();
    flowReport.version = "FI8-Yang2009-PP-PU-counter-flow-report-v1";
    flowReport.primaryBasis = "native_counter_tail_delta";
    flowReport.native = struct();
    flowReport.native.unitBasis = "native_counter_tail_delta";
    flowReport.native.internalTransferOutByComponent = nativeInternalOut;
    flowReport.native.internalTransferInByComponent = nativeInternalIn;
    flowReport.native.externalWasteByComponent = nativeWaste;
    flowReport.native.externalProductByComponent = zeros(params.nComs, 1);
    flowReport.native.totalInternalTransferOut = sum(nativeInternalOut);
    flowReport.native.totalInternalTransferIn = sum(nativeInternalIn);
    flowReport.native.totalExternalWaste = sum(nativeWaste);
    flowReport.native.totalExternalProduct = 0;
    flowReport.moles = makePhysicalMoleReport(params, flowReport.native);
    flowReport.flowSigns = sampledFlowReport.flowSigns;
    flowReport.rateSamples = sampledFlowReport.rateSamples;
    flowReport.sampledReconstruction = sampledFlowReport;
    flowReport.counterTailDeltas = counterDeltas;
    flowReport.sampledMinusCounter = makeSampledMinusCounter( ...
        sampledFlowReport.native, flowReport.native);
    flowReport.counterDiagnostics = makeCounterDiagnostics( ...
        donorFeedDelta, adapterConfig);
end

function amount = expectedNonnegativeCounterAmount(rawAmount, label, absTol, relTol)
    rawAmount = rawAmount(:);
    scale = max(1, max(abs(rawAmount)));
    tol = absTol + relTol .* scale;
    if any(rawAmount < -tol)
        error('FI8:UnexpectedAdapterCounterSign', ...
            '%s had negative amount beyond tolerance. min=%g tol=%g', ...
            char(label), min(rawAmount), tol);
    end
    amount = max(0, rawAmount);
end

function assertNoUnsupportedReverseFlow(signs, config)
    if isfield(config, 'allowReverseInternalFlow') && ...
            logical(config.allowReverseInternalFlow) && ...
            isfield(signs, 'reverseInternalSampleCount') && ...
            signs.reverseInternalSampleCount > 0
        error('FI8:ReverseAdapterCounterFlowUnsupported', ...
            ['PP->PU reverse internal flow was sampled, but counter-tail ' ...
            'acceptance mapping is currently non-reverse only.']);
    end
    if isfield(config, 'allowReverseWasteFlow') && ...
            logical(config.allowReverseWasteFlow) && ...
            isfield(signs, 'reverseWasteSampleCount') && ...
            signs.reverseWasteSampleCount > 0
        error('FI8:ReverseAdapterCounterFlowUnsupported', ...
            ['PP->PU reverse waste flow was sampled, but counter-tail ' ...
            'acceptance mapping is currently non-reverse only.']);
    end
end

function moles = makePhysicalMoleReport(params, native)
    nComs = params.nComs;
    if isfield(params, 'nScaleFac') && ~isempty(params.nScaleFac)
        moles = struct();
        moles.unitBasis = ...
            "physical_moles_from_native_counter_tail_delta_using_params.nScaleFac";
        moles.internalTransferOutByComponent = ...
            params.nScaleFac .* native.internalTransferOutByComponent;
        moles.internalTransferInByComponent = ...
            params.nScaleFac .* native.internalTransferInByComponent;
        moles.externalWasteByComponent = ...
            params.nScaleFac .* native.externalWasteByComponent;
        moles.externalProductByComponent = zeros(nComs, 1);
    else
        moles = struct();
        moles.unitBasis = "not_available_missing_params.nScaleFac";
        moles.internalTransferOutByComponent = [];
        moles.internalTransferInByComponent = [];
        moles.externalWasteByComponent = [];
        moles.externalProductByComponent = [];
    end
end

function sampledMinusCounter = makeSampledMinusCounter(sampledNative, counterNative)
    sampledMinusCounter = struct();
    sampledMinusCounter.native = struct();
    sampledMinusCounter.native.internalTransferOutByComponent = ...
        sampledNative.internalTransferOutByComponent - ...
        counterNative.internalTransferOutByComponent;
    sampledMinusCounter.native.internalTransferInByComponent = ...
        sampledNative.internalTransferInByComponent - ...
        counterNative.internalTransferInByComponent;
    sampledMinusCounter.native.externalWasteByComponent = ...
        sampledNative.externalWasteByComponent - ...
        counterNative.externalWasteByComponent;
    sampledMinusCounter.native.externalProductByComponent = ...
        sampledNative.externalProductByComponent - ...
        counterNative.externalProductByComponent;
end

function diagnostics = makeCounterDiagnostics(donorFeedDelta, config)
    diagnostics = struct();
    diagnostics.donorFeedDeltaByComponent = donorFeedDelta(:);
    diagnostics.donorFeedDeltaExpected = "near_zero_not_a_PP_PU_ledger_stream";
    scale = max(1, max(abs(donorFeedDelta(:))));
    tol = config.conservationAbsTol + config.conservationRelTol .* scale;
    diagnostics.donorFeedAbsTolerance = tol;
    diagnostics.donorFeedNonzeroBeyondTolerance = any(abs(donorFeedDelta(:)) > tol);
end
