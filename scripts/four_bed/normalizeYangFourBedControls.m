function controls = normalizeYangFourBedControls(controlsIn, templateParams)
%NORMALIZEYANGFOURBEDCONTROLS Return stable FI-6/FI-7 controls.

    if nargin < 1 || isempty(controlsIn)
        controlsIn = struct();
    end
    if nargin < 2
        templateParams = struct();
    end
    if ~isstruct(controlsIn) || ~isscalar(controlsIn)
        error('FI6:InvalidControls', ...
            'Yang four-bed controls must be a scalar struct.');
    end

    defaults = defaultYangFourBedControls();

    controls = struct();
    controls.cycleTimeSec = getNumericField(controlsIn, 'cycleTimeSec', defaults.cycleTimeSec, false);
    controls.feedVelocityCmSec = getNumericField(controlsIn, 'feedVelocityCmSec', defaults.feedVelocityCmSec, false);

    [controls.Cv_directTransfer, controls.Cv_directTransferAliasReport] = ...
        getDirectTransferCv(controlsIn, defaults.Cv_directTransfer);
    controls.PP_PU_wasteCouplingPolicy = getWasteCouplingPolicyField(controlsIn, ...
        'PP_PU_wasteCouplingPolicy', defaults.PP_PU_wasteCouplingPolicy);
    controls.PP_PU_wasteCouplingAlpha = getNonnegativeNumericField(controlsIn, ...
        'PP_PU_wasteCouplingAlpha', defaults.PP_PU_wasteCouplingAlpha);
    controls.ADPP_BF_internalSplitFraction = getFractionField(controlsIn, ...
        'ADPP_BF_internalSplitFraction', defaults.ADPP_BF_internalSplitFraction);
    controls.ADPP_BF_externalProductPressureRatio = getOptionalNonnegativeNumericField(controlsIn, ...
        'ADPP_BF_externalProductPressureRatio', defaults.ADPP_BF_externalProductPressureRatio);
    controls.Cv_ADPP_feed = getNonnegativeNumericField(controlsIn, ...
        'Cv_ADPP_feed', controls.Cv_directTransfer);
    controls.Cv_ADPP_product = getNonnegativeNumericField(controlsIn, ...
        'Cv_ADPP_product', controls.Cv_directTransfer);
    controls.Cv_ADPP_BF_internal = getNonnegativeNumericField(controlsIn, ...
        'Cv_ADPP_BF_internal', controls.Cv_directTransfer);
    controls.adapterCoefficientBasis = "scaled_dimensionless_raw_direct";
    controls.derivedConductancePolicy = ...
        "custom adapters use raw dimensionless Cv controls directly; PP->PU keeps Cv_directTransfer with configurable receiver-waste coupling; AD&PP->BF uses independent feed/product/internal conductances with diagnostic effective split";

    controls.nVols = getNumericField(controlsIn, 'nVols', getTemplateField(templateParams, 'nVols', NaN), true);
    controls.solverTolerances = getFieldOrDefault(controlsIn, 'solverTolerances', struct());
    controls.componentNames = normalizeComponentNames(getFieldOrDefault( ...
        controlsIn, 'componentNames', getTemplateField(templateParams, 'componentNames', ["H2"; "CO2"])));

    controls.nativeRunner = getFieldOrDefault(controlsIn, 'nativeRunner', @runYangTemporaryCase);
    if ~isa(controls.nativeRunner, 'function_handle')
        error('FI6:InvalidControls', ...
            'controls.nativeRunner must be a function handle.');
    end
    controls.nativeRunnerMode = string(getFieldOrDefault(controlsIn, 'nativeRunnerMode', "native"));
    controls.adapterValidationOnly = getLogicalField(controlsIn, 'adapterValidationOnly', false);
    controls.debugKeepStateHistory = getLogicalField(controlsIn, 'debugKeepStateHistory', false);
    controls.auditOutputMode = string(getFieldOrDefault(controlsIn, 'auditOutputMode', "compact"));

    controls.operationPlanPolicy = string(getFieldOrDefault( ...
        controlsIn, 'operationPlanPolicy', "topological_per_bed_sequence"));
    controls.pairedDurationPolicy = string(getFieldOrDefault( ...
        controlsIn, 'pairedDurationPolicy', "donor_source_col"));

    controls.balanceAbsTol = getNumericField(controlsIn, 'balanceAbsTol', 1e-8, false);
    controls.balanceRelTol = getNumericField(controlsIn, 'balanceRelTol', 1e-6, false);
    controls.cssAbsTol = getNumericField(controlsIn, 'cssAbsTol', 1e-8, false);
    controls.cssRelTol = getNumericField(controlsIn, 'cssRelTol', 1e-6, false);

    controls.surrogateBasis = "Yang-inspired H2/CO2 homogeneous activated-carbon surrogate";
    controls.validationPosition = ...
        "wrapper_cycle_controls_only_no_full_Yang_layered_four_component_validation_claim";
end

function defaults = defaultYangFourBedControls()
    defaults = struct();
    defaults.cycleTimeSec = 240.0;
    defaults.feedVelocityCmSec = 5.2;
    defaults.Cv_directTransfer = 1.0e-6;
    defaults.PP_PU_wasteCouplingPolicy = "pressure_driven_independent";
    defaults.PP_PU_wasteCouplingAlpha = 1.0;
    defaults.ADPP_BF_internalSplitFraction = 1.0 / 3.0;
    defaults.ADPP_BF_externalProductPressureRatio = [];
end

function value = getFieldOrDefault(s, name, defaultValue)
    if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
        value = s.(name);
    else
        value = defaultValue;
    end
end

function value = getTemplateField(s, name, defaultValue)
    value = defaultValue;
    if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
        value = s.(name);
    end
end

function value = getNumericField(s, name, defaultValue, allowNaN)
    value = getFieldOrDefault(s, name, defaultValue);
    if ~isnumeric(value) || ~isscalar(value) || ~isreal(value)
        error('FI6:InvalidControls', ...
            'controls.%s must be a real numeric scalar.', name);
    end
    if allowNaN
        if isinf(value)
            error('FI6:InvalidControls', ...
                'controls.%s must be finite or NaN.', name);
        end
    elseif ~isfinite(value)
        error('FI6:InvalidControls', ...
            'controls.%s must be finite.', name);
    end
    value = double(value);
end

function [cv, aliasReport] = getDirectTransferCv(s, defaultValue)
    aliasReport = struct();
    aliasReport.version = "Yang-direct-transfer-Cv-alias-report-v1";
    aliasReport.primaryField = "Cv_directTransfer";
    aliasReport.usedPrimary = isstruct(s) && isfield(s, 'Cv_directTransfer') && ...
        ~isempty(s.Cv_directTransfer);
    aliasReport.usedFallbackAliases = strings(0, 1);
    aliasReport.ignoredControlBasisFields = strings(0, 1);
    aliasReport.ignoredNativeCvFields = strings(0, 1);
    aliasReport.PP_PU_wasteDerivedMultiplier = 2.0;

    if aliasReport.usedPrimary
        cv = validateNonnegativeCv(s.Cv_directTransfer, 'Cv_directTransfer');
    else
        [candidateValues, aliasNames] = collectAdapterAliasCandidates(s);
        if isempty(candidateValues)
            cv = defaultValue;
        else
            cv = candidateValues(1);
            mismatch = abs(candidateValues - cv) > max(1e-15, 1e-9 * max(1, abs(cv)));
            if any(mismatch)
                error('FI6:ConflictingLegacyCvAliases', ...
                    ['Legacy adapter Cv aliases must collapse to one Cv_directTransfer ' ...
                    'value; conflicting aliases: %s.'], ...
                    char(strjoin(aliasNames, ", ")));
            end
            aliasReport.usedFallbackAliases = aliasNames(:);
        end
    end

    if isstruct(s)
        basisFields = ["adapterCvBasis"; "valveCoefficientBasis"];
        for i = 1:numel(basisFields)
            name = char(basisFields(i));
            if isfield(s, name) && ~isempty(s.(name))
                aliasReport.ignoredControlBasisFields(end+1, 1) = basisFields(i); %#ok<AGROW>
            end
        end

        nativeFields = ["Cv_EQI"; "Cv_EQII"; "Cv_AD_feed"; "Cv_BD_waste"];
        for i = 1:numel(nativeFields)
            name = char(nativeFields(i));
            if isfield(s, name) && ~isempty(s.(name))
                aliasReport.ignoredNativeCvFields(end+1, 1) = nativeFields(i); %#ok<AGROW>
            end
        end
    end
end

function [values, names] = collectAdapterAliasCandidates(s)
    values = [];
    names = strings(0, 1);
    if ~isstruct(s)
        return;
    end

    directAliases = "Cv_PP_PU_internal";
    for i = 1:numel(directAliases)
        name = char(directAliases(i));
        if isfield(s, name) && ~isempty(s.(name))
            values(end+1, 1) = validateNonnegativeCv(s.(name), name); %#ok<AGROW>
            names(end+1, 1) = directAliases(i); %#ok<AGROW>
        end
    end

    if isfield(s, 'Cv_PU_waste') && ~isempty(s.Cv_PU_waste)
        values(end+1, 1) = validateNonnegativeCv(s.Cv_PU_waste, ...
            'Cv_PU_waste') ./ 2.0; %#ok<AGROW>
        names(end+1, 1) = "Cv_PU_waste/2"; %#ok<AGROW>
    end
end

function value = validateNonnegativeCv(value, name)
    if ~isnumeric(value) || ~isscalar(value) || ~isreal(value) || ...
            ~isfinite(value) || value < 0
        error('FI6:InvalidControls', ...
            'controls.%s must be a finite nonnegative real scalar.', name);
    end
    value = double(value);
end

function value = getLogicalField(s, name, defaultValue)
    value = getFieldOrDefault(s, name, defaultValue);
    if ~islogical(value) || ~isscalar(value)
        error('FI6:InvalidControls', ...
            'controls.%s must be a scalar logical.', name);
    end
end

function value = getFractionField(s, name, defaultValue)
    value = getNumericField(s, name, defaultValue, false);
    if value < 0 || value > 1
        error('FI6:InvalidControls', ...
            'controls.%s must be between 0 and 1.', name);
    end
end

function value = getNonnegativeNumericField(s, name, defaultValue)
    value = getNumericField(s, name, defaultValue, false);
    if value < 0
        error('FI6:InvalidControls', ...
            'controls.%s must be nonnegative.', name);
    end
end

function value = getOptionalNonnegativeNumericField(s, name, defaultValue)
    value = defaultValue;
    if isstruct(s) && isfield(s, name)
        value = s.(name);
    end
    if isempty(value)
        value = [];
        return;
    end
    if ~isnumeric(value) || ~isscalar(value) || ~isreal(value) || ...
            ~isfinite(value) || value < 0
        error('FI6:InvalidControls', ...
            'controls.%s must be empty or a finite nonnegative real scalar.', name);
    end
    value = double(value);
end

function policy = getWasteCouplingPolicyField(s, name, defaultValue)
    policy = string(getFieldOrDefault(s, name, defaultValue));
    validPolicies = [
        "pressure_driven_independent"
        "gated_by_internal_flow"
        "capped_by_internal_flow"
    ];
    if ~isscalar(policy) || ~any(policy == validPolicies)
        error('FI6:InvalidControls', ...
            'controls.%s must be one of: %s.', ...
            name, char(strjoin(validPolicies, ", ")));
    end
end

function names = normalizeComponentNames(names)
    names = string(names(:));
    if isempty(names) || any(strlength(names) == 0) || numel(unique(names)) ~= numel(names)
        error('FI6:InvalidControls', ...
            'controls.componentNames must be nonempty and unique.');
    end
end
