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

    controls.Cv_EQI = getNumericField(controlsIn, 'Cv_EQI', defaults.Cv_EQI, false);
    controls.Cv_EQII = getNumericField(controlsIn, 'Cv_EQII', defaults.Cv_EQII, false);
    controls.Cv_AD_feed = getNumericField(controlsIn, 'Cv_AD_feed', defaults.Cv_AD_feed, false);
    controls.Cv_PP_PU_internal = getNumericField(controlsIn, 'Cv_PP_PU_internal', defaults.Cv_PP_PU_internal, false);
    controls.Cv_PU_waste = getNumericField(controlsIn, 'Cv_PU_waste', defaults.Cv_PU_waste, false);
    controls.Cv_ADPP_feed = getNumericField(controlsIn, 'Cv_ADPP_feed', defaults.Cv_ADPP_feed, false);
    controls.Cv_ADPP_product = getNumericField(controlsIn, 'Cv_ADPP_product', defaults.Cv_ADPP_product, false);
    controls.Cv_ADPP_BF_internal = getNumericField(controlsIn, 'Cv_ADPP_BF_internal', defaults.Cv_ADPP_BF_internal, false);
    controls.Cv_BD_waste = getNumericField(controlsIn, 'Cv_BD_waste', defaults.Cv_BD_waste, false);
    controls.adapterCvBasis = getValveBasis(controlsIn, defaults.adapterCvBasis);
    controls.valveCoefficientBasis = controls.adapterCvBasis;
    controls.valveDefaultBasisNote = ...
        "first-pass valve coefficients assume corrected adsorption capacity; final values require sensitivity or optimization, and feed-like product may persist if the q_m correction is pending";

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
    defaults.Cv_AD_feed = 5.0e-7;
    defaults.Cv_ADPP_feed = 1.0e-6;
    defaults.Cv_ADPP_product = 1.0e-6;
    defaults.Cv_ADPP_BF_internal = 5.0e-7;
    defaults.Cv_EQI = 1.0e-6;
    defaults.Cv_EQII = 1.0e-6;
    defaults.Cv_PP_PU_internal = 1.0e-6;
    defaults.Cv_PU_waste = 2.0e-6;
    defaults.Cv_BD_waste = 2.0e-6;
    defaults.adapterCvBasis = "dimensional_kmol_per_bar_s";
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

function basis = getValveBasis(s, defaultValue)
    basis = defaultValue;
    if isstruct(s) && isfield(s, 'adapterCvBasis') && ~isempty(s.adapterCvBasis)
        basis = string(s.adapterCvBasis);
    elseif isstruct(s) && isfield(s, 'valveCoefficientBasis') && ~isempty(s.valveCoefficientBasis)
        basis = string(s.valveCoefficientBasis);
    end
    if ~isscalar(basis) || ~ismember(basis, ["dimensional_kmol_per_bar_s", "scaled_dimensionless"])
        error('FI6:InvalidControls', ...
            'controls.adapterCvBasis must be dimensional_kmol_per_bar_s or scaled_dimensionless.');
    end
end

function names = normalizeComponentNames(names)
    names = string(names(:));
    if isempty(names) || any(strlength(names) == 0) || numel(unique(names)) ~= numel(names)
        error('FI6:InvalidControls', ...
            'controls.componentNames must be nonempty and unique.');
    end
end
