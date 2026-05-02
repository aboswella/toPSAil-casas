function flowReport = integrateYangAdppBfAdapterFlows(params, stTime, stStates, adapterConfig)
%INTEGRATEYANGADPPBFADAPTERFLOWS Reconstruct AD&PP->BF stream integrals.

    if nargin < 4
        adapterConfig = params.yangAdapterConfig;
    end
    stTime = stTime(:);
    if size(stStates, 1) ~= numel(stTime)
        error('FI5:InvalidStateHistory', ...
            'stStates rows must match stTime entries for AD&PP->BF flow integration.');
    end

    nT = numel(stTime);
    nComs = params.nComs;
    externalFeedRate = zeros(nT, nComs);
    externalProductRate = zeros(nT, nComs);
    internalOutRate = zeros(nT, nComs);
    internalInRate = zeros(nT, nComs);
    wasteRate = zeros(nT, nComs);
    donorFeedVol = zeros(nT, 1);
    donorProductVol = zeros(nT, 1);
    receiverProductVol = zeros(nT, 1);
    receiverFeedVol = zeros(nT, 1);

    for t = 1:nT
        [donor, receiver] = parsePairState(params, stStates(t, :));
        rates = evaluateRates(params, donor, receiver, adapterConfig);
        externalFeedRate(t, :) = rates.externalFeedByComponent(:).';
        externalProductRate(t, :) = rates.externalProductByComponent(:).';
        internalOutRate(t, :) = rates.internalByComponent(:).';
        internalInRate(t, :) = rates.internalByComponent(:).';
        wasteRate(t, :) = zeros(1, nComs);
        donorFeedVol(t) = rates.donorFeedVol;
        donorProductVol(t) = rates.donorProductVol;
        receiverProductVol(t) = rates.receiverProductVol;
        receiverFeedVol(t) = rates.receiverFeedVol;
    end

    nativeExternalFeed = integrateRows(stTime, externalFeedRate);
    nativeExternalProduct = integrateRows(stTime, externalProductRate);
    nativeInternalOut = integrateRows(stTime, internalOutRate);
    nativeInternalIn = integrateRows(stTime, internalInRate);
    nativeWaste = integrateRows(stTime, wasteRate);

    flowReport = struct();
    flowReport.version = "FI5-Yang2009-ADPP-BF-flow-integration-v1";
    flowReport.native = struct();
    flowReport.native.unitBasis = "native_dimensionless_integral";
    flowReport.native.externalFeedByComponent = nativeExternalFeed;
    flowReport.native.externalProductByComponent = nativeExternalProduct;
    flowReport.native.internalTransferOutByComponent = nativeInternalOut;
    flowReport.native.internalTransferInByComponent = nativeInternalIn;
    flowReport.native.externalWasteByComponent = nativeWaste;
    flowReport.native.totalExternalFeed = sum(nativeExternalFeed);
    flowReport.native.totalExternalProduct = sum(nativeExternalProduct);
    flowReport.native.totalInternalTransferOut = sum(nativeInternalOut);
    flowReport.native.totalInternalTransferIn = sum(nativeInternalIn);
    flowReport.native.totalExternalWaste = sum(nativeWaste);

    if isfield(params, 'nScaleFac') && ~isempty(params.nScaleFac)
        flowReport.moles = struct();
        flowReport.moles.unitBasis = "physical_moles_using_params.nScaleFac";
        flowReport.moles.externalFeedByComponent = params.nScaleFac .* nativeExternalFeed;
        flowReport.moles.externalProductByComponent = params.nScaleFac .* nativeExternalProduct;
        flowReport.moles.internalTransferOutByComponent = params.nScaleFac .* nativeInternalOut;
        flowReport.moles.internalTransferInByComponent = params.nScaleFac .* nativeInternalIn;
        flowReport.moles.externalWasteByComponent = params.nScaleFac .* nativeWaste;
    else
        flowReport.moles = struct();
        flowReport.moles.unitBasis = "not_available_missing_params.nScaleFac";
        flowReport.moles.externalFeedByComponent = [];
        flowReport.moles.externalProductByComponent = [];
        flowReport.moles.internalTransferOutByComponent = [];
        flowReport.moles.internalTransferInByComponent = [];
        flowReport.moles.externalWasteByComponent = [];
    end

    flowReport.flowSigns = summarizeFlowSigns( ...
        donorFeedVol, donorProductVol, receiverProductVol, receiverFeedVol, adapterConfig);
    flowReport.rateSamples = struct();
    flowReport.rateSamples.externalFeedByComponent = externalFeedRate;
    flowReport.rateSamples.externalProductByComponent = externalProductRate;
    flowReport.rateSamples.internalOutByComponent = internalOutRate;
    flowReport.rateSamples.internalInByComponent = internalInRate;
    flowReport.rateSamples.externalWasteByComponent = wasteRate;
    flowReport.rateSamples.donorFeedVol = donorFeedVol;
    flowReport.rateSamples.donorProductVol = donorProductVol;
    flowReport.rateSamples.receiverProductVol = receiverProductVol;
    flowReport.rateSamples.receiverFeedVol = receiverFeedVol;
    flowReport.effectiveSplit = computeEffectiveSplit(flowReport.native, adapterConfig);
end

function amount = integrateRows(stTime, rate)
    if numel(stTime) < 2
        amount = zeros(size(rate, 2), 1);
    else
        amount = trapz(stTime, rate, 1).';
    end
end

function [donor, receiver] = parsePairState(params, stateRow)
    donorVector = stateRow(1:params.nColStT);
    receiverVector = stateRow(params.nColStT+1:2*params.nColStT);
    donor = parseLocalVector(params, donorVector);
    receiver = parseLocalVector(params, receiverVector);
end

function bed = parseLocalVector(params, localVector)
    localVector = localVector(:);
    nComs = params.nComs;
    nVols = params.nVols;
    nStates = params.nStates;
    reshaped = reshape(localVector(1:nStates*nVols), nStates, nVols).';
    bed.gas = reshaped(:, 1:nComs);
    bed.ads = reshaped(:, nComs+1:2*nComs);
    bed.temps = reshaped(:, 2*nComs+1:2*nComs+2);
end

function rates = evaluateRates(params, donor, receiver, config)
    donorFeGas = donor.gas(1, :).';
    donorPrGas = donor.gas(end, :).';
    receiverPrGas = receiver.gas(end, :).';

    donorFeTotal = sum(donorFeGas);
    donorPrTotal = sum(donorPrGas);
    receiverPrTotal = sum(receiverPrGas);

    pDonorFe = donorFeTotal .* donor.temps(1, 1);
    pDonorPr = donorPrTotal .* donor.temps(end, 1);
    pReceiverPr = receiverPrTotal .* receiver.temps(end, 1);
    cvDirect = config.Cv_directTransfer;
    internalSplit = getInternalSplitFraction(config);

    rawFeed = cvDirect .* (config.feedPressureRatio - pDonorFe);
    if config.allowReverseFeedFlow
        nDotFeed = rawFeed;
    else
        nDotFeed = max(0, rawFeed);
    end

    rawExternalProductCandidate = cvDirect .* ...
        (pDonorPr - config.externalProductPressureRatio);
    if config.allowReverseProductFlow
        nDotExternalProductCandidate = rawExternalProductCandidate;
    else
        nDotExternalProductCandidate = max(0, rawExternalProductCandidate);
    end

    rawInternalCandidate = cvDirect .* (pDonorPr - pReceiverPr);
    if config.allowReverseInternalFlow
        nDotInternalCandidate = rawInternalCandidate;
    else
        nDotInternalCandidate = max(0, rawInternalCandidate);
    end

    nDotProductTotal = nDotExternalProductCandidate + nDotInternalCandidate;
    nDotInternal = internalSplit .* nDotProductTotal;
    nDotExternalProduct = (1 - internalSplit) .* nDotProductTotal;

    yFeed = resolveFeedMoleFractions(params);
    yDonorPr = donorPrGas ./ safeDenominator(donorPrTotal);

    rates = struct();
    rates.externalFeedByComponent = yFeed .* nDotFeed;
    rates.externalProductByComponent = yDonorPr .* nDotExternalProduct;
    rates.internalByComponent = yDonorPr .* nDotInternal;
    rates.donorFeedVol = nDotFeed ./ safeDenominator(donorFeTotal);
    rates.donorProductVol = nDotProductTotal ./ safeDenominator(donorPrTotal);
    rates.receiverProductVol = -nDotInternal ./ safeDenominator(receiverPrTotal);
    rates.receiverFeedVol = 0;
end

function split = getInternalSplitFraction(config)
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

function y = resolveFeedMoleFractions(params)
    if isfield(params, 'yFeC') && ~isempty(params.yFeC)
        y = params.yFeC(:);
    elseif isfield(params, 'feedMoleFractions') && ~isempty(params.feedMoleFractions)
        y = params.feedMoleFractions(:);
    else
        error('FI5:TemplateParamsNotRunnable', ...
            'Template params must expose yFeC or feedMoleFractions for AD&PP external-feed accounting.');
    end
    if numel(y) ~= params.nComs || any(~isfinite(y)) || sum(y) <= 0
        error('FI5:InvalidFeedComposition', ...
            'AD&PP external-feed composition must match params.nComs and be finite.');
    end
    y = y ./ sum(y);
end

function signs = summarizeFlowSigns(donorFeedVol, donorProductVol, receiverProductVol, receiverFeedVol, config)
    signs = struct();
    signs.donorFeedEnd = summarizeOneFlow(donorFeedVol, "nonnegative_expected");
    signs.donorProductEnd = summarizeOneFlow(donorProductVol, "nonnegative_expected");
    signs.receiverProductEnd = summarizeOneFlow(receiverProductVol, "nonpositive_expected");
    signs.receiverFeedEnd = summarizeOneFlow(receiverFeedVol, "zero_expected");
    signs.allowReverseFeedFlow = logical(config.allowReverseFeedFlow);
    signs.allowReverseProductFlow = logical(config.allowReverseProductFlow);
    signs.allowReverseInternalFlow = logical(config.allowReverseInternalFlow);
    signs.reverseFeedSampleCount = sum(donorFeedVol < 0);
    signs.reverseProductSampleCount = sum(donorProductVol < 0);
    signs.reverseInternalSampleCount = sum(receiverProductVol > 0);
end

function one = summarizeOneFlow(values, expectation)
    one = struct();
    one.expectation = string(expectation);
    one.min = min(values);
    one.max = max(values);
    one.zeroCount = sum(values == 0);
    one.positiveCount = sum(values > 0);
    one.negativeCount = sum(values < 0);
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
    split.requestedInternalSplitFraction = getInternalSplitFraction(config);
    split.componentNames = componentNames;
    split.byComponent = byComponent;
    split.primaryControl = "ADPP_BF_internalSplitFraction";
    split.conductanceControl = "Cv_directTransfer";
end

function den = safeDenominator(value)
    den = value;
    tiny = eps(class(value));
    den(abs(den) < tiny) = tiny;
end
