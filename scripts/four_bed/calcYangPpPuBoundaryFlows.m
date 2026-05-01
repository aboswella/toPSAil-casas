function [volumetricFlow, flowState] = calcYangPpPuBoundaryFlows(params, col, nS, nCo, endpoint)
%CALCYANGPPPUBOUNDARYFLOWS Boundary flow law for FI-4 PP->PU coupling.
%
% Product-end flow is positive out of a column in native toPSAil sign
% convention. Feed-end waste from the PU receiver is therefore negative.

    %#ok<INUSD> nS and nCo are kept for native boundary-function signature.
    config = params.yangAdapterConfig;
    endpoint = string(endpoint);

    state = getEndpointState(params, col);
    rawInternal = config.Cv_PP_PU_internal .* ...
        (state.donor.product.pressureRatio - state.receiver.product.pressureRatio);
    if config.allowReverseInternalFlow
        nDotInternal = rawInternal;
    else
        nDotInternal = max(0, rawInternal);
    end

    rawWaste = config.Cv_PU_waste .* ...
        (state.receiver.feed.pressureRatio - config.receiverWastePressureRatio);
    if config.allowReverseWasteFlow
        nDotWaste = rawWaste;
    else
        nDotWaste = max(0, rawWaste);
    end

    switch endpoint
        case "donor_product_end"
            volumetricFlow = nDotInternal ./ safeDenominator(state.donor.product.gasTotal);
        case "receiver_product_end"
            volumetricFlow = -nDotInternal ./ safeDenominator(state.receiver.product.gasTotal);
        case "receiver_feed_waste"
            volumetricFlow = -nDotWaste ./ safeDenominator(state.receiver.feed.gasTotal);
        case "zero"
            volumetricFlow = zeros(size(nDotInternal));
        otherwise
            error('FI4:UnsupportedPpPuEndpoint', ...
                'Unsupported PP->PU endpoint %s.', char(endpoint));
    end

    flowState = struct();
    flowState.rawInternal = rawInternal;
    flowState.rawWaste = rawWaste;
    flowState.nDotInternal = nDotInternal;
    flowState.nDotWaste = nDotWaste;
    flowState.endpoint = endpoint;
    flowState.donor = state.donor;
    flowState.receiver = state.receiver;
end

function state = getEndpointState(params, col)
    donorName = params.sColNums{1};
    receiverName = params.sColNums{2};

    donor = col.(donorName);
    receiver = col.(receiverName);

    state = struct();
    state.donor.product = makeEndpoint(donor, "product_end");
    state.receiver.product = makeEndpoint(receiver, "product_end");
    state.receiver.feed = makeEndpoint(receiver, "feed_end");
end

function endpoint = makeEndpoint(colStruct, endpointName)
    endpointName = string(endpointName);
    switch endpointName
        case "product_end"
            idx = size(colStruct.gasConsTot, 2);
        case "feed_end"
            idx = 1;
        otherwise
            error('FI4:UnsupportedPpPuEndpoint', ...
                'Unsupported endpoint %s.', char(endpointName));
    end
    gasTotal = colStruct.gasConsTot(:, idx);
    temp = colStruct.temps.cstr(:, idx);

    endpoint = struct();
    endpoint.gasTotal = gasTotal;
    endpoint.temperature = temp;
    endpoint.pressureRatio = gasTotal .* temp;
end

function den = safeDenominator(value)
    den = value;
    tiny = eps(class(value));
    den(abs(den) < tiny) = tiny;
end
