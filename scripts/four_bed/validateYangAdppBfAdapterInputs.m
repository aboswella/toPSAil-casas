function [adapterConfig, validationReport] = validateYangAdppBfAdapterInputs(tempCase, templateParams, adapterConfig)
%VALIDATEYANGADPPBFADAPTERINPUTS Validate FI-5 AD&PP->BF adapter inputs.

    if nargin < 2
        templateParams = struct();
    end
    if nargin < 3 || isempty(adapterConfig)
        adapterConfig = struct();
    end
    if ~isstruct(adapterConfig) || ~isscalar(adapterConfig)
        error('FI5:InvalidAdapterConfig', ...
            'adapterConfig must be a scalar struct.');
    end

    validateAdppBfTemporaryCase(tempCase);
    adapterConfig = normalizeConfig(tempCase, templateParams, adapterConfig);
    validationReport = makeValidationReport(tempCase, adapterConfig);
end

function validateAdppBfTemporaryCase(tempCase)
    result = validateYangTemporaryCase(tempCase);
    if ~result.pass
        error('FI5:InvalidTemporaryCase', ...
            'Cannot run invalid temporary case: %s', char(strjoin(result.failures, " | ")));
    end

    if string(tempCase.caseType) ~= "paired_direct_transfer"
        error('FI5:InvalidAdppBfTemporaryCase', ...
            'AD&PP->BF adapter requires tempCase.caseType paired_direct_transfer.');
    end
    if tempCase.nLocalBeds ~= 2
        error('FI5:InvalidAdppBfTemporaryCase', ...
            'AD&PP->BF adapter requires exactly two local beds.');
    end
    if string(tempCase.directTransferFamily) ~= "ADPP_BF"
        error('FI5:InvalidAdppBfTemporaryCase', ...
            'AD&PP->BF adapter requires directTransferFamily ADPP_BF.');
    end

    localMap = tempCase.localMap;
    if ~isequal(localMap.local_index(:), [1; 2])
        error('FI5:InvalidAdppBfTemporaryCase', ...
            'AD&PP->BF local indices must be [1; 2].');
    end
    if string(localMap.local_role(1)) ~= "donor" || string(localMap.local_role(2)) ~= "receiver"
        error('FI5:InvalidAdppBfTemporaryCase', ...
            'AD&PP->BF local roles must be donor then receiver.');
    end
    if string(localMap.yang_label(1)) ~= "AD&PP" || string(localMap.yang_label(2)) ~= "BF"
        error('FI5:InvalidAdppBfTemporaryCase', ...
            'AD&PP->BF local Yang labels must be AD&PP then BF.');
    end

    endpoint = tempCase.native.endpointPolicy;
    if string(endpoint.donorOutletEndpoint) ~= "product_end" || ...
            string(endpoint.receiverInletEndpoint) ~= "product_end" || ...
            string(endpoint.receiverWasteEndpoint) ~= "none"
        error('FI5:InvalidAdppBfEndpointPolicy', ...
            'AD&PP->BF requires donor product-end out, receiver product-end in, and no receiver waste.');
    end
    if isfield(endpoint, 'externalProductSeparated') && ...
            ~logical(endpoint.externalProductSeparated)
        error('FI5:InvalidAdppBfEndpointPolicy', ...
            'AD&PP->BF endpoint policy must keep external product separated.');
    end
    if logical(tempCase.native.nativeRunnable)
        error('FI5:InvalidAdppBfNativeStatus', ...
            'AD&PP->BF must remain a wrapper direct-coupling adapter, not a native-runnable step.');
    end
end

function adapterConfig = normalizeConfig(tempCase, templateParams, adapterConfig)
    adapterConfig.version = getStringField(adapterConfig, "version", ...
        "FI5-Yang2009-ADPP-BF-adapter-config-v1");
    adapterConfig.directTransferFamily = getStringField(adapterConfig, ...
        "directTransferFamily", "ADPP_BF");
    if string(adapterConfig.directTransferFamily) ~= "ADPP_BF"
        error('FI5:InvalidAdapterConfig', ...
            'adapterConfig.directTransferFamily must be ADPP_BF.');
    end

    adapterConfig.durationSeconds = getOptionalField(adapterConfig, "durationSeconds", []);
    adapterConfig.durationDimless = getOptionalField(adapterConfig, "durationDimless", []);
    validateDuration(adapterConfig.durationSeconds, adapterConfig.durationDimless);

    [adapterConfig.Cv_directTransfer, hasCvDirectTransfer] = ...
        getOptionalNonnegativeNumericScalar(adapterConfig, "Cv_directTransfer", NaN);
    adapterConfig.Cv_ADPP_feed = getBranchCvWithFallback(adapterConfig, ...
        "Cv_ADPP_feed", adapterConfig.Cv_directTransfer, hasCvDirectTransfer);
    adapterConfig.Cv_ADPP_product = getBranchCvWithFallback(adapterConfig, ...
        "Cv_ADPP_product", adapterConfig.Cv_directTransfer, hasCvDirectTransfer);
    adapterConfig.Cv_ADPP_BF_internal = getBranchCvWithFallback(adapterConfig, ...
        "Cv_ADPP_BF_internal", adapterConfig.Cv_directTransfer, hasCvDirectTransfer);
    adapterConfig.ADPP_BF_internalSplitFraction = getFractionWithDefault( ...
        adapterConfig, "ADPP_BF_internalSplitFraction", 1.0 / 3.0);
    adapterConfig.ADPP_BF_splitMode = "pressure_driven_independent_branches";
    adapterConfig.ADPP_BF_internalCvPolicy = ...
        "independent feed/product/internal conductances; effective split is diagnostic";
    adapterConfig.ADPP_BF_internalSplitFractionRole = ...
        "legacy_unused_diagnostic_not_rate_control";
    adapterConfig = resolveAdppBfConductanceBasis(adapterConfig);

    [adapterConfig.feedPressureRatio, adapterConfig.feedPressureBasis] = ...
        resolveFeedPressureRatio(templateParams, adapterConfig);
    [adapterConfig.externalProductPressureRatio, adapterConfig.externalProductPressureBasis] = ...
        resolveExternalProductPressureRatio(templateParams, adapterConfig);

    adapterConfig.allowReverseFeedFlow = getLogicalField(adapterConfig, ...
        "allowReverseFeedFlow", false);
    adapterConfig.allowReverseProductFlow = getLogicalField(adapterConfig, ...
        "allowReverseProductFlow", false);
    adapterConfig.allowReverseInternalFlow = getLogicalField(adapterConfig, ...
        "allowReverseInternalFlow", false);
    adapterConfig.componentNames = resolveComponentNames(templateParams, adapterConfig);
    adapterConfig.conservationAbsTol = getNumericScalarWithDefault(adapterConfig, ...
        "conservationAbsTol", 1e-8);
    adapterConfig.conservationRelTol = getNumericScalarWithDefault(adapterConfig, ...
        "conservationRelTol", 1e-6);
    adapterConfig.debugKeepStateHistory = getLogicalField(adapterConfig, ...
        "debugKeepStateHistory", false);
    adapterConfig.validationOnly = getLogicalField(adapterConfig, ...
        "validationOnly", false);
    adapterConfig.cycleIndex = getNumericScalarWithDefault(adapterConfig, ...
        "cycleIndex", NaN, true);
    adapterConfig.slotIndex = getNumericScalarWithDefault(adapterConfig, ...
        "slotIndex", NaN, true);
    adapterConfig.operationGroupId = getStringField(adapterConfig, ...
        "operationGroupId", string(tempCase.pairId));
end

function adapterConfig = resolveAdppBfConductanceBasis(adapterConfig)
    cv = adapterConfig.Cv_directTransfer;
    cvFeed = adapterConfig.Cv_ADPP_feed;
    cvProduct = adapterConfig.Cv_ADPP_product;
    cvInternal = adapterConfig.Cv_ADPP_BF_internal;
    adapterConfig.adapterCoefficientBasis = "scaled_dimensionless_raw_direct";
    adapterConfig.valveCoefficientBasis = adapterConfig.adapterCoefficientBasis;
    adapterConfig.rawCv = struct( ...
        "Cv_directTransfer", cv, ...
        "Cv_ADPP_feed", cvFeed, ...
        "Cv_ADPP_product", cvProduct, ...
        "Cv_ADPP_BF_internal", cvInternal);
    adapterConfig.effectiveCv = adapterConfig.rawCv;
    adapterConfig.adapterCvScalingApplied = false;
    adapterConfig.valScaleFac = NaN;
    adapterConfig.derivedConductance = struct( ...
        "ADPP_feed", cvFeed, ...
        "ADPP_product", cvProduct, ...
        "ADPP_BF_internal", cvInternal, ...
        "derivation", "ADPP_BF branches use independent pressure-driven conductances");
end

function validateDuration(durationSeconds, durationDimless)
    hasSeconds = ~isempty(durationSeconds);
    hasDimless = ~isempty(durationDimless);
    if hasSeconds == hasDimless
        error('FI5:InvalidAdapterDuration', ...
            'Provide exactly one of adapterConfig.durationSeconds or durationDimless.');
    end
    if hasSeconds
        validateNumericScalar(durationSeconds, "durationSeconds");
        if durationSeconds <= 0
            error('FI5:InvalidAdapterDuration', ...
                'durationSeconds must be positive.');
        end
    end
    if hasDimless
        validateNumericScalar(durationDimless, "durationDimless");
        if durationDimless <= 0
            error('FI5:InvalidAdapterDuration', ...
                'durationDimless must be positive.');
        end
    end
end

function [ratio, basis] = resolveFeedPressureRatio(templateParams, adapterConfig)
    if isfield(adapterConfig, 'feedPressureRatio') && ...
            ~isempty(adapterConfig.feedPressureRatio)
        ratio = validateNumericScalar(adapterConfig.feedPressureRatio, "feedPressureRatio");
        basis = getStringField(adapterConfig, "feedPressureBasis", ...
            "adapterConfig.feedPressureRatio");
    elseif isstruct(templateParams) && isfield(templateParams, 'pRatFe') && ...
            ~isempty(templateParams.pRatFe)
        ratio = validateNumericScalar(templateParams.pRatFe, "templateParams.pRatFe");
        basis = "templateParams.pRatFe";
    elseif hasHighPressureNormalization(templateParams)
        ratio = 1.0;
        basis = "dimensionless_high_pressure_default_from_template.presColHigh";
    else
        error('FI5:MissingFeedPressureBasis', ...
            'AD&PP->BF adapter requires feedPressureRatio or an unambiguous template high-pressure basis.');
    end
end

function [ratio, basis] = resolveExternalProductPressureRatio(templateParams, adapterConfig)
    if isfield(adapterConfig, 'externalProductPressureRatio') && ...
            ~isempty(adapterConfig.externalProductPressureRatio)
        ratio = validateNumericScalar(adapterConfig.externalProductPressureRatio, ...
            "externalProductPressureRatio");
        basis = getStringField(adapterConfig, "externalProductPressureBasis", ...
            "adapterConfig.externalProductPressureRatio");
    elseif isstruct(templateParams) && isfield(templateParams, 'pRatRa') && ...
            ~isempty(templateParams.pRatRa)
        ratio = validateNumericScalar(templateParams.pRatRa, "templateParams.pRatRa");
        basis = "templateParams.pRatRa";
    elseif hasHighPressureNormalization(templateParams)
        ratio = 1.0;
        basis = "dimensionless_high_pressure_product_default_from_template.presColHigh";
    else
        error('FI5:MissingProductPressureBasis', ...
            'AD&PP->BF adapter requires externalProductPressureRatio or an unambiguous template product pressure basis.');
    end
end

function tf = hasHighPressureNormalization(params)
    tf = isstruct(params) && isfield(params, 'presColHigh') && ...
        isfield(params, 'gasConT') && isfield(params, 'tempColNorm') && ...
        ~isempty(params.presColHigh) && ~isempty(params.gasConT) && ...
        ~isempty(params.tempColNorm);
end

function names = resolveComponentNames(templateParams, adapterConfig)
    if isfield(adapterConfig, 'componentNames') && ~isempty(adapterConfig.componentNames)
        names = string(adapterConfig.componentNames(:));
    elseif isstruct(templateParams) && isfield(templateParams, 'componentNames')
        names = string(templateParams.componentNames(:));
    elseif isstruct(templateParams) && isfield(templateParams, 'nComs')
        names = "C" + string((1:templateParams.nComs)');
    else
        names = ["H2"; "CO2"];
    end

    if isstruct(templateParams) && isfield(templateParams, 'nComs') && ...
            ~isempty(templateParams.nComs) && numel(names) ~= templateParams.nComs
        error('FI5:InvalidAdapterConfig', ...
            'adapterConfig.componentNames must match templateParams.nComs.');
    end
end

function validationReport = makeValidationReport(tempCase, adapterConfig)
    validationReport = struct();
    validationReport.version = "FI5-Yang2009-ADPP-BF-adapter-input-validation-v1";
    validationReport.pass = true;
    validationReport.directTransferFamily = "ADPP_BF";
    validationReport.pairId = string(tempCase.pairId);
    validationReport.localMap = tempCase.localMap;
    validationReport.endpointPolicy = tempCase.native.endpointPolicy;
    validationReport.configVersion = string(adapterConfig.version);
    validationReport.noDynamicInternalTanks = true;
    validationReport.noSharedHeaderInventory = true;
    validationReport.noFourBedRhsDae = true;
    validationReport.noCoreAdsorberPhysicsRewrite = true;
end

function value = getRequiredNumericScalar(config, fieldName)
    if ~isfield(config, char(fieldName)) || isempty(config.(char(fieldName)))
        error('FI5:MissingAdapterConfigField', ...
            'adapterConfig.%s is required for AD&PP->BF.', char(fieldName));
    end
    value = validateNumericScalar(config.(char(fieldName)), fieldName);
    if value < 0
        error('FI5:InvalidAdapterConfig', ...
            'adapterConfig.%s must be nonnegative.', char(fieldName));
    end
end

function [value, supplied] = getOptionalNonnegativeNumericScalar(config, fieldName, defaultValue)
    supplied = isfield(config, char(fieldName)) && ...
        ~isempty(config.(char(fieldName)));
    if supplied
        value = validateNumericScalar(config.(char(fieldName)), fieldName);
        if value < 0
            error('FI5:InvalidAdapterConfig', ...
                'adapterConfig.%s must be nonnegative.', char(fieldName));
        end
    else
        value = defaultValue;
    end
end

function value = getBranchCvWithFallback(config, fieldName, fallbackValue, hasFallback)
    if isfield(config, char(fieldName)) && ~isempty(config.(char(fieldName)))
        value = validateNumericScalar(config.(char(fieldName)), fieldName);
        if value < 0
            error('FI5:InvalidAdapterConfig', ...
                'adapterConfig.%s must be nonnegative.', char(fieldName));
        end
        return;
    end
    if hasFallback
        value = fallbackValue;
        return;
    end
    error('FI5:MissingAdapterConfigField', ...
        ['adapterConfig.%s is required for AD&PP->BF when ' ...
        'adapterConfig.Cv_directTransfer is not supplied.'], char(fieldName));
end

function value = getNumericScalarWithDefault(config, fieldName, defaultValue, allowNaN)
    if nargin < 4
        allowNaN = false;
    end
    value = getOptionalField(config, fieldName, defaultValue);
    if isempty(value)
        value = defaultValue;
    end
    value = validateNumericScalar(value, fieldName, allowNaN);
end

function value = getFractionWithDefault(config, fieldName, defaultValue)
    value = getNumericScalarWithDefault(config, fieldName, defaultValue);
    if value < 0 || value > 1
        error('FI5:InvalidAdapterConfig', ...
            'adapterConfig.%s must be between 0 and 1.', char(fieldName));
    end
end

function value = validateNumericScalar(value, fieldName, allowNaN)
    if nargin < 3
        allowNaN = false;
    end
    if ~isnumeric(value) || ~isscalar(value) || ~isreal(value)
        error('FI5:InvalidAdapterConfig', ...
            'adapterConfig.%s must be a real numeric scalar.', char(fieldName));
    end
    if allowNaN
        if isinf(value)
            error('FI5:InvalidAdapterConfig', ...
                'adapterConfig.%s must be finite or NaN.', char(fieldName));
        end
    elseif ~isfinite(value)
        error('FI5:InvalidAdapterConfig', ...
            'adapterConfig.%s must be finite.', char(fieldName));
    end
    value = double(value);
end

function value = getStringField(config, fieldName, defaultValue)
    value = defaultValue;
    if isfield(config, char(fieldName)) && ~isempty(config.(char(fieldName)))
        value = string(config.(char(fieldName)));
    end
end

function value = getLogicalField(config, fieldName, defaultValue)
    value = defaultValue;
    if isfield(config, char(fieldName)) && ~isempty(config.(char(fieldName)))
        value = config.(char(fieldName));
    end
    if ~islogical(value) || ~isscalar(value)
        error('FI5:InvalidAdapterConfig', ...
            'adapterConfig.%s must be a scalar logical.', char(fieldName));
    end
end

function value = getOptionalField(config, fieldName, defaultValue)
    value = defaultValue;
    if isfield(config, char(fieldName))
        value = config.(char(fieldName));
    end
end
