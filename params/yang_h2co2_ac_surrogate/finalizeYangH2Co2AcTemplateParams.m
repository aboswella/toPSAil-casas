function params = finalizeYangH2Co2AcTemplateParams(params, varargin)
%FINALIZEYANGH2CO2ACTEMPLATEPARAMS Add runtime fields for smoke runs.
%
% The values added here are commissioning defaults for the homogeneous
% H2/CO2 activated-carbon surrogate. They are not Yang source constants.

    parser = inputParser;
    parser.FunctionName = "finalizeYangH2Co2AcTemplateParams";
    addParameter(parser, "FeedVelocityCmSec", [], @(x) isempty(x) || ...
        (isnumeric(x) && isscalar(x) && isfinite(x) && x > 0));
    addParameter(parser, "CycleTimeSec", [], @(x) isempty(x) || ...
        (isnumeric(x) && isscalar(x) && isfinite(x) && x > 0));
    addParameter(parser, "LdfMassTransferPerSec", 0.05, @(x) isnumeric(x) && ...
        (isscalar(x) || isvector(x)) && all(isfinite(x(:))) && all(x(:) > 0));
    addParameter(parser, "NativeValveCoefficient", 1.0, @(x) isnumeric(x) && ...
        isscalar(x) && isfinite(x) && x > 0);
    parse(parser, varargin{:});
    opts = parser.Results;

    if nargin < 1 || ~isstruct(params)
        error('FI8:InvalidRuntimeTemplate', ...
            'params must be a Yang H2/CO2 AC template struct.');
    end
    assertSurrogateBasis(params);

    params = ensureRuntimeDesignDefaults(params, opts);
    params = ensureRuntimeGasAndEquipmentDefaults(params);
    params = ensureCoreRuntimeModels(params);
    params = ensureRuntimeSizing(params);
    params = ensureRuntimeBoundaryDefaults(params, opts.NativeValveCoefficient);
    params.initStates = getInitialStates(params);

    params.yangRuntimeFinalization = struct( ...
        "finalized", true, ...
        "version", "FI8-Yang2009-H2CO2-AC-runtime-finalization-v1", ...
        "basis", "H2_CO2_homogeneous_activated_carbon_surrogate", ...
        "usesExistingToPSAilAdsorberPhysics", true, ...
        "feedVelocityBasis", params.yangRuntimeDefaults.feedVelocityBasis, ...
        "gasAndEquipmentBasis", params.yangRuntimeDefaults.gasAndEquipmentBasis, ...
        "ldfBasis", params.yangRuntimeDefaults.ldfBasis, ...
        "nativeValveBasis", params.yangRuntimeDefaults.nativeValveBasis, ...
        "dynamicInternalTanksAdded", false, ...
        "sharedHeaderInventoryAdded", false, ...
        "globalFourBedRhsAdded", false);
end

function assertSurrogateBasis(params)
    required = ["nComs", "componentNames", "yangBasis"];
    missing = setdiff(required, string(fieldnames(params)));
    if ~isempty(missing)
        error('FI8:InvalidRuntimeTemplate', ...
            'Template is missing surrogate-basis fields: %s.', ...
            char(strjoin(missing, ", ")));
    end
    if params.nComs ~= 2 || any(string(params.componentNames(:)) ~= ["H2"; "CO2"])
        error('FI8:InvalidRuntimeTemplate', ...
            'Runtime template must use component order [H2; CO2].');
    end
    basis = params.yangBasis;
    forbidden = ["coIncluded", "ch4Included", "zeolite5AIncluded", ...
        "layeredBedEnabled", "pseudoImpurityIncluded"];
    for i = 1:numel(forbidden)
        name = char(forbidden(i));
        if isfield(basis, name) && logical(basis.(name))
            error('FI8:InvalidRuntimeTemplate', ...
                'Runtime template must not enable %s.', name);
        end
    end
end

function params = ensureRuntimeDesignDefaults(params, opts)
    basis = params.yangBasis;
    params.nLKs = 1;
    params.yFeC = params.feedMoleFractions(:);
    params.yRaC = [1; 0];
    params.yExC = [0; 1];

    params.presFeTa = params.presColHigh;
    params.presRaTa = params.presColHigh;
    params.presExTa = params.presColLow;
    params.presAmbi = params.presColLow;
    params.presDoSt = params.presColLow;
    params = getPresRats(params);
    params = getTempRats(params);

    params.radInFeTa = params.radInCol;
    params.radInRaTa = params.radInCol;
    params.radInExTa = params.radInCol;
    params.radOutFeTa = params.radOutCol;
    params.radOutRaTa = params.radOutCol;
    params.radOutExTa = params.radOutCol;
    params.heightFeTa = params.heightCol;
    params.heightRaTa = params.heightCol;
    params.heightExTa = params.heightCol;
    params = getTankParams(params);

    feedVelocity = opts.FeedVelocityCmSec;
    feedVelocityBasis = "caller_supplied";
    if isempty(feedVelocity)
        if isfield(params, 'feedVelocityCmSec') && ~isempty(params.feedVelocityCmSec)
            feedVelocity = params.feedVelocityCmSec;
            feedVelocityBasis = "template_feedVelocityCmSec";
        else
            feedVelocity = 1.0;
            feedVelocityBasis = "commissioning_design_default_not_source";
        end
    end
    params.feedVelocityCmSec = feedVelocity;
    params.volFlowFeed = feedVelocity * params.crsAreaInCol;

    cycleTime = opts.CycleTimeSec;
    cycleTimeBasis = "caller_supplied";
    if isempty(cycleTime)
        if isfield(params, 'cycleTimeSec') && ~isempty(params.cycleTimeSec)
            cycleTime = params.cycleTimeSec;
            cycleTimeBasis = "template_cycleTimeSec";
        else
            cycleTime = 240.0;
            cycleTimeBasis = "commissioning_design_default_not_source";
        end
    end
    params.cycleTimeSec = cycleTime;

    ldf = opts.LdfMassTransferPerSec(:);
    if isscalar(ldf)
        ldf = repmat(ldf, params.nComs, 1);
    end
    if numel(ldf) ~= params.nComs
        error('FI8:InvalidRuntimeTemplate', ...
            'LdfMassTransferPerSec must be scalar or one value per component.');
    end
    params.ldfMtc = ldf(:);

    params.inConBed = ones(params.nCols, 1);
    params.inConFeTa = 1;
    params.inConRaTa = 3;
    params.inConExTa = 3;

    params.numZero = 1e-10;
    params.numIntSolv = "ode15s";
    params.odeRelTol = getTolerance(params.solverTolerances, ...
        'relativeTolerance', 3e-4);
    params.odeAbsTol = getTolerance(params.solverTolerances, ...
        'absoluteTolerance', 1e-5);
    params.nRows = 1;
    params.valFeedCol = ones(params.nCols, params.nSteps);
    params.valProdCol = ones(params.nCols, params.nSteps);

    params.yangRuntimeDefaults = struct( ...
        "version", "FI8-Yang2009-runtime-defaults-v1", ...
        "feedVelocityCmSec", feedVelocity, ...
        "feedVelocityBasis", feedVelocityBasis, ...
        "cycleTimeSec", cycleTime, ...
        "cycleTimeBasis", cycleTimeBasis, ...
        "ldfMassTransferPerSec", ldf(:), ...
        "ldfBasis", "commissioning_design_default_not_source", ...
        "nativeValveCoefficient", 1.0, ...
        "nativeValveBasis", "sentinel_one_no_native_cv_control", ...
        "ignoredNativeValveCoefficientInput", opts.NativeValveCoefficient, ...
        "sourceCaveat", "Runtime defaults support smoke commissioning only; they are not Yang validation constants.");

    params = getScaleFacs(params);
    params = getDimLessParams(params);
end

function params = ensureRuntimeGasAndEquipmentDefaults(params)
    % Native work-rate helpers always unpack these fields, even for the
    % isothermal smoke path. Values are commissioning defaults.
    params.compFacC = ones(params.nComs, 1);
    params.htCapCpC = [28.84; 37.14];
    params.htCapCvC = params.htCapCpC - (params.gasCons / 10);
    params.isEntEffFeComp = 1.0;
    params.isEntEffExComp = 1.0;
    params.isEntEffPump = 1.0;

    params = getFeHtCapRatio(params);
    params = getFeMixCompFac(params);
    params.yangRuntimeDefaults.gasAndEquipmentBasis = ...
        "commissioning_design_default_not_source";
end

function params = ensureCoreRuntimeModels(params)
    params.bool(1) = double(params.nCols > 1);
    params.bool(3) = 0;
    params.bool(5) = double(~logical(params.isothermal));
    params.bool(6) = 0;
    params.bool(7) = 0;
    params.bool(8) = 0;
    params.bool(12) = 0;
    params.modSp(2) = 1;
    params.modSp(3) = 1;
    params.modSp(4) = 1;
    params.modSp(6) = 0;
    params.modSp(7) = 0;

    [models, subModels] = getSubModels(params);
    params.funcIso = models{1};
    params.funcRat = models{2};
    params.funcEos = models{3};
    params.funcVal = models{4};
    params.funcVol = models{6};
    params.funcVolUnits = subModels{6};
    params.funcCss = models{7};
    params = getSolverOpts(params);
end

function params = ensureRuntimeSizing(params)
    params = getStatesParams(params);
    params = getStreamParams(params);
    params.sComNums = cell(params.nComs, 1);
    for i = 1:params.nComs
        params.sComNums{i} = append('C', int2str(i));
    end
    params.sColNums = cell(params.nCols, 1);
    for i = 1:params.nCols
        params.sColNums{i} = append('n', int2str(i));
    end
end

function params = ensureRuntimeBoundaryDefaults(params, nativeValveCoefficient)
    params.nSteps = max(1, params.nSteps);
    params.durStep = params.cycleTimeSec;
    params.eveVal = NaN(1, params.nSteps);
    params.eveUnit = repmat({'None'}, 1, params.nSteps);
    params.eveLoc = repmat({'None'}, 1, params.nSteps);
    params.funcEve = repmat({[]}, 1, params.nSteps);

    params.sStepCol = repmat({'RT-XXX-XXX'}, params.nCols, params.nSteps);
    params.typeDaeModel = ones(params.nCols, params.nSteps);
    params.flowDirCol = zeros(params.nCols, params.nSteps);
    params.numAdsEqPrEnd = zeros(params.nCols, params.nSteps);
    params.numAdsEqFeEnd = zeros(params.nCols, params.nSteps);
    %#ok<NASGU> nativeValveCoefficient is retained as a compatibility input;
    % the minimal Yang wrapper keeps non-adapter native Cv controls disabled.
    params.valFeedColNorm = ones(params.nCols, params.nSteps);
    params.valProdColNorm = ones(params.nCols, params.nSteps);

    params = getFlowSheetValves(params);
    params = getColBoundConds(params);
    params = getTimeSpan(params);
    params = getEventParams(params);
    params = getNumParams(params);
end

function value = getTolerance(tolerances, fieldName, defaultValue)
    value = defaultValue;
    if isstruct(tolerances) && isfield(tolerances, fieldName) && ...
            ~isempty(tolerances.(fieldName))
        value = tolerances.(fieldName);
    end
    if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || value <= 0
        error('FI8:InvalidRuntimeTemplate', ...
            'solverTolerances.%s must be a finite positive scalar.', fieldName);
    end
end
