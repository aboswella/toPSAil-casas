function [volumetricFlow, flowState] = calcYangAdppBfBoundaryFlows(params, col, nS, nCo, endpoint)
%CALCYANGADPPBFBOUNDARYFLOWS Boundary flow law for FI-5 AD&PP->BF coupling.
%
% Feed-end flow is positive into the AD&PP donor. Product-end donor flow is
% positive out of the donor. Receiver product-end BF inflow is negative.

    %#ok<INUSD> nS and nCo are kept for native boundary-function signature.
    config = params.yangAdapterConfig;
    endpoint = string(endpoint);

    state = getEndpointState(params, col);
    cvFeed = getEffectiveCv(config, "Cv_ADPP_feed");
    cvProduct = getEffectiveCv(config, "Cv_ADPP_product");
    cvInternal = getEffectiveCv(config, "Cv_ADPP_BF_internal");

    rawFeed = cvFeed .* ...
        (config.feedPressureRatio - state.donor.feed.pressureRatio);
    if config.allowReverseFeedFlow
        nDotFeed = rawFeed;
    else
        nDotFeed = max(0, rawFeed);
    end

    rawExternalProduct = cvProduct .* ...
        (state.donor.product.pressureRatio - config.externalProductPressureRatio);
    if config.allowReverseProductFlow
        nDotExternalProduct = rawExternalProduct;
    else
        nDotExternalProduct = max(0, rawExternalProduct);
    end

    rawInternal = cvInternal .* ...
        (state.donor.product.pressureRatio - state.receiver.product.pressureRatio);
    if config.allowReverseInternalFlow
        nDotInternal = rawInternal;
    else
        nDotInternal = max(0, rawInternal);
    end

    switch endpoint
        case "donor_feed_end"
            volumetricFlow = nDotFeed ./ safeDenominator(state.donor.feed.gasTotal);
        case "donor_product_end"
            volumetricFlow = (nDotExternalProduct + nDotInternal) ./ ...
                safeDenominator(state.donor.product.gasTotal);
        case "receiver_product_end"
            volumetricFlow = -nDotInternal ./ ...
                safeDenominator(state.receiver.product.gasTotal);
        case "receiver_feed_end"
            volumetricFlow = zeros(size(nDotInternal));
        otherwise
            error('FI5:UnsupportedAdppBfEndpoint', ...
                'Unsupported AD&PP->BF endpoint %s.', char(endpoint));
    end

    flowState = struct();
    flowState.rawFeed = rawFeed;
    flowState.rawExternalProduct = rawExternalProduct;
    flowState.rawInternal = rawInternal;
    flowState.nDotFeed = nDotFeed;
    flowState.nDotExternalProduct = nDotExternalProduct;
    flowState.nDotInternal = nDotInternal;
    flowState.endpoint = endpoint;
    flowState.donor = state.donor;
    flowState.receiver = state.receiver;
end

function cv = getEffectiveCv(config, fieldName)
    fieldName = char(fieldName);
    if isfield(config, 'effectiveCv') && isfield(config.effectiveCv, fieldName)
        cv = config.effectiveCv.(fieldName);
    else
        cv = config.(fieldName);
    end
end

function state = getEndpointState(params, col)
    donorName = params.sColNums{1};
    receiverName = params.sColNums{2};

    donor = col.(donorName);
    receiver = col.(receiverName);

    state = struct();
    state.donor.feed = makeEndpoint(donor, "feed_end");
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
            error('FI5:UnsupportedAdppBfEndpoint', ...
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
