function flowReport = buildYangAdppBfCounterFlowReport(params, stTime, stStates, adapterConfig, sampledFlowReport)
%BUILDYANGADPPBFCOUNTERFLOWREPORT Build AD&PP->BF flows from counters.

    if nargin < 5 || isempty(sampledFlowReport)
        sampledFlowReport = integrateYangAdppBfAdapterFlows( ...
            params, stTime, stStates, adapterConfig);
    end

    counterDeltas = computeYangCounterTailDeltasFromStates(params, stStates, 2);
    [donorFeedDelta, donorProductDelta] = splitYangBoundaryCounterTail( ...
        params, counterDeltas{1});
    [receiverFeedDelta, receiverProductDelta] = splitYangBoundaryCounterTail( ...
        params, counterDeltas{2});

    nativeExternalFeed = expectedNonnegativeCounterAmount( ...
        -donorFeedDelta, "ADPP_BF donor feed-end external feed in", ...
        adapterConfig.conservationAbsTol, adapterConfig.conservationRelTol);
    nativeTotalDonorProductOut = expectedNonnegativeCounterAmount( ...
        donorProductDelta, "ADPP_BF donor product-end total out", ...
        adapterConfig.conservationAbsTol, adapterConfig.conservationRelTol);
    nativeInternalIn = expectedNonnegativeCounterAmount( ...
        -receiverProductDelta, "ADPP_BF receiver product-end internal in", ...
        adapterConfig.conservationAbsTol, adapterConfig.conservationRelTol);

    nativeInternalOut = nativeInternalIn;
    nativeExternalProduct = nativeTotalDonorProductOut - nativeInternalOut;
    scale = max(1, max(abs([nativeTotalDonorProductOut; nativeInternalOut])));
    tol = adapterConfig.conservationAbsTol + adapterConfig.conservationRelTol .* scale;
    if any(nativeExternalProduct < -tol)
        error('FI8:AdppBfCounterSplitImpossible', ...
            ['ADPP_BF receiver internal counter exceeds donor total product ' ...
            'counter. This indicates a real adapter endpoint/composition bug, ' ...
            'not an accounting rounding issue.']);
    end
    nativeExternalProduct = max(0, nativeExternalProduct);
    nativeWaste = zeros(params.nComs, 1);

    assertNoUnsupportedReverseFlow(sampledFlowReport.flowSigns, adapterConfig);

    flowReport = struct();
    flowReport.version = "FI8-Yang2009-ADPP-BF-counter-flow-report-v1";
    flowReport.primaryBasis = "native_counter_tail_delta";
    flowReport.native = struct();
    flowReport.native.unitBasis = "native_counter_tail_delta";
    flowReport.native.externalFeedByComponent = nativeExternalFeed;
    flowReport.native.externalProductByComponent = nativeExternalProduct;
    flowReport.native.internalTransferOutByComponent = nativeInternalOut;
    flowReport.native.internalTransferInByComponent = nativeInternalIn;
    flowReport.native.externalWasteByComponent = nativeWaste;
    flowReport.native.totalExternalFeed = sum(nativeExternalFeed);
    flowReport.native.totalExternalProduct = sum(nativeExternalProduct);
    flowReport.native.totalInternalTransferOut = sum(nativeInternalOut);
    flowReport.native.totalInternalTransferIn = sum(nativeInternalIn);
    flowReport.native.totalExternalWaste = 0;
    flowReport.moles = makePhysicalMoleReport(params, flowReport.native);
    flowReport.flowSigns = sampledFlowReport.flowSigns;
    flowReport.rateSamples = sampledFlowReport.rateSamples;
    flowReport.effectiveSplit = computeEffectiveSplit(flowReport.native, adapterConfig);
    flowReport.sampledReconstruction = sampledFlowReport;
    flowReport.counterTailDeltas = counterDeltas;
    flowReport.sampledMinusCounter = makeSampledMinusCounter( ...
        sampledFlowReport.native, flowReport.native);
    flowReport.counterDiagnostics = makeCounterDiagnostics( ...
        nativeTotalDonorProductOut, receiverFeedDelta, adapterConfig);
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
    if isfield(config, 'allowReverseFeedFlow') && ...
            logical(config.allowReverseFeedFlow) && ...
            isfield(signs, 'reverseFeedSampleCount') && ...
            signs.reverseFeedSampleCount > 0
        error('FI8:ReverseAdapterCounterFlowUnsupported', ...
            ['AD&PP->BF reverse feed flow was sampled, but counter-tail ' ...
            'acceptance mapping is currently non-reverse only.']);
    end
    if isfield(config, 'allowReverseProductFlow') && ...
            logical(config.allowReverseProductFlow) && ...
            isfield(signs, 'reverseProductSampleCount') && ...
            signs.reverseProductSampleCount > 0
        error('FI8:ReverseAdapterCounterFlowUnsupported', ...
            ['AD&PP->BF reverse product flow was sampled, but counter-tail ' ...
            'acceptance mapping is currently non-reverse only.']);
    end
    if isfield(config, 'allowReverseInternalFlow') && ...
            logical(config.allowReverseInternalFlow) && ...
            isfield(signs, 'reverseInternalSampleCount') && ...
            signs.reverseInternalSampleCount > 0
        error('FI8:ReverseAdapterCounterFlowUnsupported', ...
            ['AD&PP->BF reverse internal flow was sampled, but counter-tail ' ...
            'acceptance mapping is currently non-reverse only.']);
    end
end

function moles = makePhysicalMoleReport(params, native)
    if isfield(params, 'nScaleFac') && ~isempty(params.nScaleFac)
        moles = struct();
        moles.unitBasis = ...
            "physical_moles_from_native_counter_tail_delta_using_params.nScaleFac";
        moles.externalFeedByComponent = ...
            params.nScaleFac .* native.externalFeedByComponent;
        moles.externalProductByComponent = ...
            params.nScaleFac .* native.externalProductByComponent;
        moles.internalTransferOutByComponent = ...
            params.nScaleFac .* native.internalTransferOutByComponent;
        moles.internalTransferInByComponent = ...
            params.nScaleFac .* native.internalTransferInByComponent;
        moles.externalWasteByComponent = ...
            params.nScaleFac .* native.externalWasteByComponent;
    else
        moles = struct();
        moles.unitBasis = "not_available_missing_params.nScaleFac";
        moles.externalFeedByComponent = [];
        moles.externalProductByComponent = [];
        moles.internalTransferOutByComponent = [];
        moles.internalTransferInByComponent = [];
        moles.externalWasteByComponent = [];
    end
end

function sampledMinusCounter = makeSampledMinusCounter(sampledNative, counterNative)
    sampledMinusCounter = struct();
    sampledMinusCounter.native = struct();
    sampledMinusCounter.native.externalFeedByComponent = ...
        sampledNative.externalFeedByComponent - counterNative.externalFeedByComponent;
    sampledMinusCounter.native.externalProductByComponent = ...
        sampledNative.externalProductByComponent - counterNative.externalProductByComponent;
    sampledMinusCounter.native.internalTransferOutByComponent = ...
        sampledNative.internalTransferOutByComponent - ...
        counterNative.internalTransferOutByComponent;
    sampledMinusCounter.native.internalTransferInByComponent = ...
        sampledNative.internalTransferInByComponent - ...
        counterNative.internalTransferInByComponent;
    sampledMinusCounter.native.externalWasteByComponent = ...
        sampledNative.externalWasteByComponent - counterNative.externalWasteByComponent;
end

function split = computeEffectiveSplit(nativeFlows, config)
    internal = nativeFlows.internalTransferOutByComponent;
    externalProduct = nativeFlows.externalProductByComponent;
    denominator = internal + externalProduct;
    byComponent = nan(size(internal));
    nonzero = abs(denominator) > eps;
    byComponent(nonzero) = internal(nonzero) ./ denominator(nonzero);

    totalDenominator = sum(internal) + sum(externalProduct);
    total = NaN;
    if abs(totalDenominator) > eps
        total = sum(internal) ./ totalDenominator;
    end

    componentNames = string(config.componentNames(:));
    h2Index = find(componentNames == "H2", 1);
    if isempty(h2Index)
        h2Index = 1;
    end

    split = struct();
    split.unitBasis = nativeFlows.unitBasis;
    split.H2 = byComponent(h2Index);
    split.total = total;
    split.requestedInternalSplitFraction = getLegacyInternalSplitFraction(config);
    split.requestedInternalSplitFractionRole = ...
        "legacy_unused_diagnostic_not_rate_control";
    split.legacyInternalSplitFraction = split.requestedInternalSplitFraction;
    split.componentNames = componentNames;
    split.byComponent = byComponent;
    split.primaryControl = "pressure_driven_independent_branches";
    split.conductanceControl = "Cv_ADPP_feed/Cv_ADPP_product/Cv_ADPP_BF_internal";
end

function split = getLegacyInternalSplitFraction(config)
    if isfield(config, 'ADPP_BF_internalSplitFraction') && ...
            ~isempty(config.ADPP_BF_internalSplitFraction)
        split = config.ADPP_BF_internalSplitFraction;
    else
        split = 1.0 / 3.0;
    end
    if ~isnumeric(split) || ~isscalar(split) || ~isreal(split) || ...
            ~isfinite(split) || split < 0 || split > 1
        error('FI5:InvalidAdapterConfig', ...
            'adapterConfig.ADPP_BF_internalSplitFraction must be between 0 and 1.');
    end
    split = double(split);
end

function diagnostics = makeCounterDiagnostics(nativeTotalDonorProductOut, receiverFeedDelta, config)
    diagnostics = struct();
    diagnostics.donorProductTotalOutByComponent = nativeTotalDonorProductOut(:);
    diagnostics.receiverFeedDeltaByComponent = receiverFeedDelta(:);
    diagnostics.receiverFeedDeltaExpected = "near_zero_closed_feed_end";
    scale = max(1, max(abs(receiverFeedDelta(:))));
    tol = config.conservationAbsTol + config.conservationRelTol .* scale;
    diagnostics.receiverFeedAbsTolerance = tol;
    diagnostics.receiverFeedNonzeroBeyondTolerance = any(abs(receiverFeedDelta(:)) > tol);
end
