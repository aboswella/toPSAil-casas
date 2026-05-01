function flowReport = integrateYangPpPuAdapterFlows(params, stTime, stStates, adapterConfig)
%INTEGRATEYANGPPPUADAPTERFLOWS Reconstruct PP->PU stream integrals.

    if nargin < 4
        adapterConfig = params.yangAdapterConfig;
    end
    stTime = stTime(:);
    if size(stStates, 1) ~= numel(stTime)
        error('FI4:InvalidStateHistory', ...
            'stStates rows must match stTime entries for PP->PU flow integration.');
    end

    nT = numel(stTime);
    nComs = params.nComs;
    internalOutRate = zeros(nT, nComs);
    internalInRate = zeros(nT, nComs);
    wasteRate = zeros(nT, nComs);
    donorProductVol = zeros(nT, 1);
    receiverProductVol = zeros(nT, 1);
    receiverFeedVol = zeros(nT, 1);

    for t = 1:nT
        [donor, receiver] = parsePairState(params, stStates(t, :));
        rates = evaluateRates(donor, receiver, adapterConfig);
        internalOutRate(t, :) = rates.internalByComponent(:).';
        internalInRate(t, :) = rates.internalByComponent(:).';
        wasteRate(t, :) = rates.wasteByComponent(:).';
        donorProductVol(t) = rates.donorProductVol;
        receiverProductVol(t) = rates.receiverProductVol;
        receiverFeedVol(t) = rates.receiverFeedWasteVol;
    end

    nativeInternalOut = integrateRows(stTime, internalOutRate);
    nativeInternalIn = integrateRows(stTime, internalInRate);
    nativeWaste = integrateRows(stTime, wasteRate);

    flowReport = struct();
    flowReport.version = "FI4-Yang2009-PP-PU-flow-integration-v1";
    flowReport.native = struct();
    flowReport.native.unitBasis = "native_dimensionless_integral";
    flowReport.native.internalTransferOutByComponent = nativeInternalOut;
    flowReport.native.internalTransferInByComponent = nativeInternalIn;
    flowReport.native.externalWasteByComponent = nativeWaste;
    flowReport.native.externalProductByComponent = zeros(nComs, 1);
    flowReport.native.totalInternalTransferOut = sum(nativeInternalOut);
    flowReport.native.totalInternalTransferIn = sum(nativeInternalIn);
    flowReport.native.totalExternalWaste = sum(nativeWaste);

    if isfield(params, 'nScaleFac') && ~isempty(params.nScaleFac)
        flowReport.moles = struct();
        flowReport.moles.unitBasis = "physical_moles_using_params.nScaleFac";
        flowReport.moles.internalTransferOutByComponent = params.nScaleFac .* nativeInternalOut;
        flowReport.moles.internalTransferInByComponent = params.nScaleFac .* nativeInternalIn;
        flowReport.moles.externalWasteByComponent = params.nScaleFac .* nativeWaste;
        flowReport.moles.externalProductByComponent = zeros(nComs, 1);
    else
        flowReport.moles = struct();
        flowReport.moles.unitBasis = "not_available_missing_params.nScaleFac";
        flowReport.moles.internalTransferOutByComponent = [];
        flowReport.moles.internalTransferInByComponent = [];
        flowReport.moles.externalWasteByComponent = [];
        flowReport.moles.externalProductByComponent = [];
    end

    flowReport.flowSigns = summarizeFlowSigns( ...
        donorProductVol, receiverProductVol, receiverFeedVol, adapterConfig);
    flowReport.rateSamples = struct();
    flowReport.rateSamples.internalOutByComponent = internalOutRate;
    flowReport.rateSamples.internalInByComponent = internalInRate;
    flowReport.rateSamples.externalWasteByComponent = wasteRate;
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

function rates = evaluateRates(donor, receiver, config)
    donorPrGas = donor.gas(end, :).';
    receiverPrGas = receiver.gas(end, :).';
    receiverFeGas = receiver.gas(1, :).';

    donorPrTotal = sum(donorPrGas);
    receiverPrTotal = sum(receiverPrGas);
    receiverFeTotal = sum(receiverFeGas);

    pDonorPr = donorPrTotal .* donor.temps(end, 1);
    pReceiverPr = receiverPrTotal .* receiver.temps(end, 1);
    pReceiverFe = receiverFeTotal .* receiver.temps(1, 1);

    rawInternal = config.Cv_PP_PU_internal .* (pDonorPr - pReceiverPr);
    if config.allowReverseInternalFlow
        nDotInternal = rawInternal;
    else
        nDotInternal = max(0, rawInternal);
    end

    rawWaste = config.Cv_PU_waste .* ...
        (pReceiverFe - config.receiverWastePressureRatio);
    if config.allowReverseWasteFlow
        nDotWaste = rawWaste;
    else
        nDotWaste = max(0, rawWaste);
    end

    yDonorPr = donorPrGas ./ safeDenominator(donorPrTotal);
    yReceiverFe = receiverFeGas ./ safeDenominator(receiverFeTotal);

    rates = struct();
    rates.internalByComponent = yDonorPr .* nDotInternal;
    rates.wasteByComponent = yReceiverFe .* nDotWaste;
    rates.donorProductVol = nDotInternal ./ safeDenominator(donorPrTotal);
    rates.receiverProductVol = -nDotInternal ./ safeDenominator(receiverPrTotal);
    rates.receiverFeedWasteVol = -nDotWaste ./ safeDenominator(receiverFeTotal);
end

function signs = summarizeFlowSigns(donorProductVol, receiverProductVol, receiverFeedVol, config)
    signs = struct();
    signs.donorProductEnd = summarizeOneFlow(donorProductVol, "nonnegative_expected");
    signs.receiverProductEnd = summarizeOneFlow(receiverProductVol, "nonpositive_expected");
    signs.receiverFeedWaste = summarizeOneFlow(receiverFeedVol, "nonpositive_expected");
    signs.allowReverseInternalFlow = logical(config.allowReverseInternalFlow);
    signs.allowReverseWasteFlow = logical(config.allowReverseWasteFlow);
    signs.reverseInternalSampleCount = sum(donorProductVol < 0 | receiverProductVol > 0);
    signs.reverseWasteSampleCount = sum(receiverFeedVol > 0);
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

function den = safeDenominator(value)
    den = value;
    if abs(den) < eps
        den = eps;
    end
end
