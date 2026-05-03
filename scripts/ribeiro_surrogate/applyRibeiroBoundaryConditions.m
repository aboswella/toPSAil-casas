function params = applyRibeiroBoundaryConditions(params, schedule, varargin)
%APPLYRIBEIROBOUNDARYCONDITIONS Override Ribeiro non-EQ boundary flows.

parser = inputParser;
parser.FunctionName = mfilename;
addParameter(parser, 'BoundaryMode', [], @mustBeEmptyOrValidBoundaryMode);
addParameter(parser, 'BlowdownGainMolSecBar', [], @mustBeEmptyOrNonnegativeNumericScalar);
addParameter(parser, 'PressurizationGainMolSecBar', [], @mustBeEmptyOrNonnegativeNumericScalar);
addParameter(parser, 'MaxBoundaryMolarFlowMolSec', [], @mustBeEmptyOrNonnegativeNumericScalar);
parse(parser, varargin{:});
opts = parser.Results;

if nargin < 1 || ~isstruct(params)
    error('RibeiroSurrogate:InvalidParams', ...
        'params must be a scalar struct.');
end
if nargin < 2
    schedule = [];
end

params = resolveBoundaryOptions(params, opts);

if params.ribeiroBoundary.mode == "native_valves"
    return;
end

params.ribeiroBoundary.nativeFuncVol = resolveNativeHandle( ...
    params, 'nativeFuncVol', params.funcVol);
params.ribeiroBoundary.nativeFuncVolUnits = resolveNativeHandle( ...
    params, 'nativeFuncVolUnits', params.funcVolUnits);
params.ribeiroBoundary.nativeVolFlBo = params.volFlBo;
params.ribeiroBoundary.nativeVolFlBoFree = params.volFlBoFree;
params.ribeiroBoundary.scheduleVersion = resolveScheduleVersion(schedule);

for step = 1:params.nSteps
    for col = 1:params.nCols
        label = string(params.sStepCol{col, step});
        switch label
            case "HP-FEE-RAF"
                params.volFlBo{2, col, step} = ...
                    @(p,c,f,r,e,nS,nCo) calcRibeiroFixedFeedBoundaryFlow(p,c,f,r,e,nS,nCo);
                params.volFlBoFree(col, step) = 1;

            case "DP-ATM-XXX"
                params.volFlBo{2, col, step} = ...
                    @(p,c,f,r,e,nS,nCo) calcRibeiroBlowdownBoundaryFlow(p,c,f,r,e,nS,nCo);

            case "LP-ATM-RAF"
                params.volFlBo{1, col, step} = ...
                    @(p,c,f,r,e,nS,nCo) calcRibeiroFixedPurgeBoundaryFlow(p,c,f,r,e,nS,nCo);
                params.volFlBoFree(col, step) = 0;

            case "RP-XXX-RAF"
                params.volFlBo{1, col, step} = ...
                    @(p,c,f,r,e,nS,nCo) calcRibeiroPressurizationBoundaryFlow(p,c,f,r,e,nS,nCo);

            case "EQ-XXX-APR"
                % Native column-to-column equalization is intentionally retained.
        end
    end
end

params.funcVol = @(p, units, nS) calcRibeiroVolFlowsWithFixedBoundaries(p, units, nS);

end

function params = resolveBoundaryOptions(params, opts)

if ~isfield(params, 'ribeiroBoundary') || ~isstruct(params.ribeiroBoundary)
    params.ribeiroBoundary = defaultBoundaryOptions();
else
    defaults = defaultBoundaryOptions();
    defaultFields = fieldnames(defaults);
    for idx = 1:numel(defaultFields)
        fieldName = defaultFields{idx};
        if ~isfield(params.ribeiroBoundary, fieldName) || ...
                isempty(params.ribeiroBoundary.(fieldName))
            params.ribeiroBoundary.(fieldName) = defaults.(fieldName);
        end
    end
end

if ~isempty(opts.BoundaryMode)
    params.ribeiroBoundary.mode = string(opts.BoundaryMode);
end
if ~isempty(opts.BlowdownGainMolSecBar)
    params.ribeiroBoundary.blowdownGainMolSecBar = opts.BlowdownGainMolSecBar;
end
if ~isempty(opts.PressurizationGainMolSecBar)
    params.ribeiroBoundary.pressurizationGainMolSecBar = opts.PressurizationGainMolSecBar;
end
if ~isempty(opts.MaxBoundaryMolarFlowMolSec)
    params.ribeiroBoundary.maxBoundaryMolarFlowMolSec = opts.MaxBoundaryMolarFlowMolSec;
end

params.ribeiroBoundary.mode = validatestring( ...
    char(params.ribeiroBoundary.mode), ...
    {'native_valves', 'ribeiro_fixed_non_eq'});
params.ribeiroBoundary.mode = string(params.ribeiroBoundary.mode);
params.ribeiroBoundary = updateBoundaryBasisText(params.ribeiroBoundary);

end

function boundary = defaultBoundaryOptions()

boundary = struct();
boundary.mode = "ribeiro_fixed_non_eq";
boundary.modeBasis = ...
    "Ribeiro fixed non-equalization boundary mode overrides feed, blowdown, purge, and pressurization while leaving native EQ-XXX-APR intact.";
boundary.feedBoundaryBasis = ...
    "HP-FEE-RAF uses prescribed Ribeiro Table 5 binary feed molar flow and H2/CO2 composition.";
boundary.purgeBoundaryBasis = ...
    "LP-ATM-RAF uses prescribed Ribeiro Table 5 pure-H2 purge molar flow at the product end.";
boundary.blowdownBoundaryBasis = ...
    "DP-ATM-XXX uses a fixed 1 bar sink with a pressure-relief controller gain.";
boundary.pressurizationBoundaryBasis = ...
    "RP-XXX-RAF uses a fixed pure-H2 product-end source with a high-pressure controller gain.";
boundary.equalizationBoundaryBasis = ...
    "native column-to-column EQ-XXX-APR retained";
boundary.blowdownGainMolSecBar = 0.30;
boundary.pressurizationGainMolSecBar = 0.18;
boundary.maxBoundaryMolarFlowMolSec = 0.5;

end

function boundary = updateBoundaryBasisText(boundary)

if boundary.mode == "native_valves"
    boundary.modeBasis = ...
        "Native toPSAil valves and dynamic tanks define all boundary flows.";
    boundary.feedBoundaryBasis = ...
        "HP-FEE-RAF uses native feed tank composition and feed valve flow.";
    boundary.purgeBoundaryBasis = ...
        "LP-ATM-RAF uses native raffinate tank composition and product-end valve flow.";
    boundary.blowdownBoundaryBasis = ...
        "DP-ATM-XXX uses native feed-end valve flow to low-pressure waste.";
    boundary.pressurizationBoundaryBasis = ...
        "RP-XXX-RAF uses native raffinate tank composition and product-end valve flow.";
    boundary.equalizationBoundaryBasis = ...
        "native column-to-column EQ-XXX-APR retained";
end

end

function value = resolveNativeHandle(params, fieldName, fallback)

if isfield(params, 'ribeiroBoundary') && ...
        isfield(params.ribeiroBoundary, fieldName) && ...
        ~isempty(params.ribeiroBoundary.(fieldName))
    value = params.ribeiroBoundary.(fieldName);
else
    value = fallback;
end

end

function version = resolveScheduleVersion(schedule)

version = "";
if isstruct(schedule) && isfield(schedule, 'version')
    version = string(schedule.version);
end

end

function mustBeEmptyOrValidBoundaryMode(value)

if isempty(value)
    return;
end
validatestring(char(value), {'native_valves', 'ribeiro_fixed_non_eq'});

end

function mustBeEmptyOrNonnegativeNumericScalar(value)

if isempty(value)
    return;
end
if ~isnumeric(value) || ~isscalar(value) || isnan(value) || value < 0
    error('RibeiroSurrogate:InvalidNonnegativeScalar', ...
        'Value must be empty or a nonnegative numeric scalar.');
end

end
