function [volumetricFlow, flowState] = calcYangAdppBfBoundaryFlows(params, col, nS, nCo, endpoint)
%CALCYANGADPPBFBOUNDARYFLOWS Boundary flow law for FI-5 AD&PP->BF coupling.
%
% Feed-end flow is positive into the AD&PP donor. Product-end donor flow is
% positive out of the donor. Receiver product-end BF inflow is negative.

    %#ok<INUSD> nS and nCo are kept for native boundary-function signature.
    config = params.yangAdapterConfig;
    endpoint = string(endpoint);

    state = getEndpointState(params, col);
    cvFeed = getBranchCv(config, 'Cv_ADPP_feed');
    cvProduct = getBranchCv(config, 'Cv_ADPP_product');
    cvInternal = getBranchCv(config, 'Cv_ADPP_BF_internal');

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
    flowState.branchConductance = struct( ...
        "Cv_ADPP_feed", cvFeed, ...
        "Cv_ADPP_product", cvProduct, ...
        "Cv_ADPP_BF_internal", cvInternal);
    flowState.legacyInternalSplitFraction = getLegacyInternalSplitFraction(config);
    flowState.legacyInternalSplitFractionRole = ...
        "legacy_unused_diagnostic_not_rate_control";
    flowState.splitMode = "pressure_driven_independent_branches";
    flowState.endpoint = endpoint;
    flowState.donor = state.donor;
    flowState.receiver = state.receiver;
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

function cv = getBranchCv(config, fieldName)
    if isfield(config, fieldName) && ~isempty(config.(fieldName))
        cv = config.(fieldName);
    elseif isfield(config, 'Cv_directTransfer') && ~isempty(config.Cv_directTransfer)
        cv = config.Cv_directTransfer;
    else
        error('FI5:InvalidAdapterConfig', ...
            'adapterConfig.%s or adapterConfig.Cv_directTransfer is required.', fieldName);
    end
    if ~isnumeric(cv) || ~isscalar(cv) || ~isreal(cv) || ...
            ~isfinite(cv) || cv < 0
        error('FI5:InvalidAdapterConfig', ...
            'adapterConfig.%s must be a finite nonnegative real scalar.', fieldName);
    end
    cv = double(cv);
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
