function [adapterConfig, validationReport] = validateYangDirectCouplingAdapterInputs(tempCase, templateParams, adapterConfig)
%VALIDATEYANGDIRECTCOUPLINGADAPTERINPUTS Validate FI-4 PP->PU adapter inputs.

    if nargin < 2
        templateParams = struct();
    end
    if nargin < 3 || isempty(adapterConfig)
        adapterConfig = struct();
    end
    if ~isstruct(adapterConfig)
        error('FI4:InvalidAdapterConfig', ...
            'adapterConfig must be a scalar struct.');
    end

    validatePpPuTemporaryCase(tempCase);
    adapterConfig = normalizeConfig(tempCase, templateParams, adapterConfig);
    validationReport = makeValidationReport(tempCase, adapterConfig);
end

function validatePpPuTemporaryCase(tempCase)
    result = validateYangTemporaryCase(tempCase);
    if ~result.pass
        error('FI4:InvalidTemporaryCase', ...
            'Cannot run invalid temporary case: %s', char(strjoin(result.failures, " | ")));
    end

    if string(tempCase.caseType) ~= "paired_direct_transfer"
        error('FI4:InvalidPpPuTemporaryCase', ...
            'PP->PU adapter requires tempCase.caseType paired_direct_transfer.');
    end
    if tempCase.nLocalBeds ~= 2
        error('FI4:InvalidPpPuTemporaryCase', ...
            'PP->PU adapter requires exactly two local beds.');
    end
    if string(tempCase.directTransferFamily) ~= "PP_PU"
        error('FI4:InvalidPpPuTemporaryCase', ...
            'PP->PU adapter requires directTransferFamily PP_PU.');
    end

    localMap = tempCase.localMap;
    if ~isequal(localMap.local_index(:), [1; 2])
        error('FI4:InvalidPpPuTemporaryCase', ...
            'PP->PU local indices must be [1; 2].');
    end
    if string(localMap.local_role(1)) ~= "donor" || string(localMap.local_role(2)) ~= "receiver"
        error('FI4:InvalidPpPuTemporaryCase', ...
            'PP->PU local roles must be donor then receiver.');
    end
    if string(localMap.yang_label(1)) ~= "PP" || string(localMap.yang_label(2)) ~= "PU"
        error('FI4:InvalidPpPuTemporaryCase', ...
            'PP->PU local Yang labels must be PP then PU.');
    end

    endpoint = tempCase.native.endpointPolicy;
    if string(endpoint.donorOutletEndpoint) ~= "product_end" || ...
            string(endpoint.receiverInletEndpoint) ~= "product_end" || ...
            string(endpoint.receiverWasteEndpoint) ~= "feed_end"
        error('FI4:InvalidPpPuEndpointPolicy', ...
            'PP->PU requires donor product-end out, receiver product-end in, receiver feed-end waste.');
    end
    if logical(tempCase.native.nativeRunnable)
        error('FI4:InvalidPpPuNativeStatus', ...
            'PP->PU must remain a wrapper direct-coupling adapter, not a native-runnable step.');
    end
end

function adapterConfig = normalizeConfig(tempCase, templateParams, adapterConfig)
    adapterConfig.version = getStringField(adapterConfig, "version", ...
        "FI4-Yang2009-PP-PU-adapter-config-v1");
    adapterConfig.directTransferFamily = getStringField(adapterConfig, ...
        "directTransferFamily", "PP_PU");
    if string(adapterConfig.directTransferFamily) ~= "PP_PU"
        error('FI4:InvalidAdapterConfig', ...
            'adapterConfig.directTransferFamily must be PP_PU.');
    end

    adapterConfig.durationSeconds = getOptionalField(adapterConfig, "durationSeconds", []);
    adapterConfig.durationDimless = getOptionalField(adapterConfig, "durationDimless", []);
    validateDuration(adapterConfig.durationSeconds, adapterConfig.durationDimless);

    adapterConfig.Cv_PP_PU_internal = getRequiredNumericScalar( ...
        adapterConfig, "Cv_PP_PU_internal");
    adapterConfig.Cv_PU_waste = getRequiredNumericScalar( ...
        adapterConfig, "Cv_PU_waste");

    if isfield(adapterConfig, 'receiverWastePressureRatio') && ...
            ~isempty(adapterConfig.receiverWastePressureRatio)
        adapterConfig.receiverWastePressureRatio = validateNumericScalar( ...
            adapterConfig.receiverWastePressureRatio, "receiverWastePressureRatio");
        adapterConfig.receiverWastePressureBasis = getStringField(adapterConfig, ...
            "receiverWastePressureBasis", "adapterConfig.receiverWastePressureRatio");
    elseif isstruct(templateParams) && isfield(templateParams, 'pRat') && ...
            ~isempty(templateParams.pRat)
        adapterConfig.receiverWastePressureRatio = validateNumericScalar( ...
            templateParams.pRat, "templateParams.pRat");
        adapterConfig.receiverWastePressureBasis = "templateParams.pRat";
    elseif isstruct(templateParams) && ...
            isfield(templateParams, 'presColLow') && isfield(templateParams, 'presColHigh') && ...
            ~isempty(templateParams.presColLow) && ~isempty(templateParams.presColHigh)
        adapterConfig.receiverWastePressureRatio = validateNumericScalar( ...
            templateParams.presColLow ./ templateParams.presColHigh, ...
            "templateParams.presColLow/templateParams.presColHigh");
        adapterConfig.receiverWastePressureBasis = ...
            "templateParams.presColLow/templateParams.presColHigh";
    else
        error('FI4:MissingWastePressureBasis', ...
            'PP->PU adapter requires receiverWastePressureRatio or a numeric template low/high pressure basis.');
    end

    adapterConfig.receiverWastePressureClass = getStringField(adapterConfig, ...
        "receiverWastePressureClass", "P4");
    adapterConfig.allowReverseInternalFlow = getLogicalField(adapterConfig, ...
        "allowReverseInternalFlow", false);
    adapterConfig.allowReverseWasteFlow = getLogicalField(adapterConfig, ...
        "allowReverseWasteFlow", false);
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

function validateDuration(durationSeconds, durationDimless)
    hasSeconds = ~isempty(durationSeconds);
    hasDimless = ~isempty(durationDimless);
    if hasSeconds == hasDimless
        error('FI4:InvalidAdapterDuration', ...
            'Provide exactly one of adapterConfig.durationSeconds or durationDimless.');
    end
    if hasSeconds
        validateNumericScalar(durationSeconds, "durationSeconds");
        if durationSeconds <= 0
            error('FI4:InvalidAdapterDuration', ...
                'durationSeconds must be positive.');
        end
    end
    if hasDimless
        validateNumericScalar(durationDimless, "durationDimless");
        if durationDimless <= 0
            error('FI4:InvalidAdapterDuration', ...
                'durationDimless must be positive.');
        end
    end
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
end

function validationReport = makeValidationReport(tempCase, adapterConfig)
    validationReport = struct();
    validationReport.version = "FI4-Yang2009-direct-coupling-adapter-input-validation-v1";
    validationReport.pass = true;
    validationReport.directTransferFamily = "PP_PU";
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
        error('FI4:MissingAdapterConfigField', ...
            'adapterConfig.%s is required for PP->PU.', char(fieldName));
    end
    value = validateNumericScalar(config.(char(fieldName)), fieldName);
    if value < 0
        error('FI4:InvalidAdapterConfig', ...
            'adapterConfig.%s must be nonnegative.', char(fieldName));
    end
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

function value = validateNumericScalar(value, fieldName, allowNaN)
    if nargin < 3
        allowNaN = false;
    end
    if ~isnumeric(value) || ~isscalar(value) || ~isreal(value)
        error('FI4:InvalidAdapterConfig', ...
            'adapterConfig.%s must be a real numeric scalar.', char(fieldName));
    end
    if allowNaN
        if isinf(value)
            error('FI4:InvalidAdapterConfig', ...
                'adapterConfig.%s must be finite or NaN.', char(fieldName));
        end
    elseif ~isfinite(value)
        error('FI4:InvalidAdapterConfig', ...
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
        error('FI4:InvalidAdapterConfig', ...
            'adapterConfig.%s must be a scalar logical.', char(fieldName));
    end
end

function value = getOptionalField(config, fieldName, defaultValue)
    value = defaultValue;
    if isfield(config, char(fieldName))
        value = config.(char(fieldName));
    end
end
