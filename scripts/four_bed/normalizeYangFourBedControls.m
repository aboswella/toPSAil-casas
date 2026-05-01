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

    controls = struct();
    controls.cycleTimeSec = getNumericField(controlsIn, 'cycleTimeSec', 240.0, false);
    controls.feedVelocityCmSec = getNumericField(controlsIn, 'feedVelocityCmSec', NaN, true);

    controls.Cv_EQI = getNumericField(controlsIn, 'Cv_EQI', NaN, true);
    controls.Cv_EQII = getNumericField(controlsIn, 'Cv_EQII', NaN, true);
    controls.Cv_PP_PU_internal = getNumericField(controlsIn, 'Cv_PP_PU_internal', NaN, true);
    controls.Cv_PU_waste = getNumericField(controlsIn, 'Cv_PU_waste', NaN, true);
    controls.Cv_ADPP_feed = getNumericField(controlsIn, 'Cv_ADPP_feed', NaN, true);
    controls.Cv_ADPP_product = getNumericField(controlsIn, 'Cv_ADPP_product', NaN, true);
    controls.Cv_ADPP_BF_internal = getNumericField(controlsIn, 'Cv_ADPP_BF_internal', NaN, true);
    controls.Cv_BD_waste = getNumericField(controlsIn, 'Cv_BD_waste', NaN, true);

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

function value = getLogicalField(s, name, defaultValue)
    value = getFieldOrDefault(s, name, defaultValue);
    if ~islogical(value) || ~isscalar(value)
        error('FI6:InvalidControls', ...
            'controls.%s must be a scalar logical.', name);
    end
end

function names = normalizeComponentNames(names)
    names = string(names(:));
    if isempty(names) || any(strlength(names) == 0) || numel(unique(names)) ~= numel(names)
        error('FI6:InvalidControls', ...
            'controls.componentNames must be nonempty and unique.');
    end
end
