function params = applyRibeiroNativeSchedule(params, schedule, varargin)
%APPLYRIBEIRONATIVESCHEDULE Apply the Ribeiro schedule to native params.

parser = inputParser;
parser.FunctionName = mfilename;
addParameter(parser, 'NativeValveCoefficient', [], @mustBeEmptyOrPositiveNumericScalar);
addParameter(parser, 'FeedValveCoefficient', [], @mustBeEmptyOrPositiveNumericScalar);
addParameter(parser, 'PurgeValveCoefficient', [], @mustBeEmptyOrPositiveNumericScalar);
addParameter(parser, 'BlowdownValveCoefficient', [], @mustBeEmptyOrPositiveNumericScalar);
addParameter(parser, 'EqualizationValveCoefficient', [], @mustBeEmptyOrPositiveNumericScalar);
addParameter(parser, 'PressurizationValveCoefficient', [], @mustBeEmptyOrPositiveNumericScalar);
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
if nargin < 2 || isempty(schedule)
    schedule = buildRibeiroNativeSchedule("TFeedSec", getTFeedSec(params));
end

validateScheduleStruct(schedule);

if ~isRuntimeFinalized(params)
    params = finalizeRibeiroSurrogateTemplateParams(params);
end

params.nCols = 4;
params.nSteps = 16;
params.durStep = double(schedule.durStep(:).');
params.sStepCol = cellstr(string(schedule.nativeStepCol));
params.typeDaeModel = double(schedule.typeDaeModel);
params.flowDirCol = double(schedule.flowDirCol);
params.numAdsEqPrEnd = double(schedule.numAdsEqPrEnd);
params.numAdsEqFeEnd = zeros(4, 16);
params.eveVal = NaN(1, 16);
params.eveUnit = repmat({'None'}, 1, 16);
params.eveLoc = repmat({'None'}, 1, 16);
params.funcEve = repmat({[]}, 1, 16);
params.sColNums = makeColumnNames(params.nCols);

nativeValveCoefficient = opts.NativeValveCoefficient;
if isempty(nativeValveCoefficient)
    nativeValveCoefficient = params.nativeValveCoefficient;
end
feedValveCoefficient = resolveValveCoefficient( ...
    opts.FeedValveCoefficient, params, 'feedValveCoefficient', nativeValveCoefficient);
purgeValveCoefficient = resolveValveCoefficient( ...
    opts.PurgeValveCoefficient, params, 'purgeValveCoefficient', nativeValveCoefficient);
blowdownValveCoefficient = resolveValveCoefficient( ...
    opts.BlowdownValveCoefficient, params, 'blowdownValveCoefficient', nativeValveCoefficient);
equalizationValveCoefficient = resolveValveCoefficient( ...
    opts.EqualizationValveCoefficient, params, 'equalizationValveCoefficient', nativeValveCoefficient);
pressurizationValveCoefficient = resolveValveCoefficient( ...
    opts.PressurizationValveCoefficient, params, 'pressurizationValveCoefficient', nativeValveCoefficient);

params.valFeedCol = nativeValveCoefficient * ones(4, 16);
params.valProdCol = nativeValveCoefficient * ones(4, 16);
params.valFeedCol(strcmp(params.sStepCol, 'HP-FEE-RAF')) = feedValveCoefficient;
params.valProdCol(strcmp(params.sStepCol, 'LP-ATM-RAF')) = purgeValveCoefficient;
params.valFeedCol(strcmp(params.sStepCol, 'DP-ATM-XXX')) = blowdownValveCoefficient;
params.valProdCol(strcmp(params.sStepCol, 'EQ-XXX-APR')) = equalizationValveCoefficient;
params.valProdCol(strcmp(params.sStepCol, 'RP-XXX-RAF')) = pressurizationValveCoefficient;
params.valFeedColNorm = params.valFeedCol .* params.valScaleFac;
params.valProdColNorm = params.valProdCol .* params.valScaleFac;
params.nativeValveCoefficient = nativeValveCoefficient;
params.feedValveCoefficient = feedValveCoefficient;
params.purgeValveCoefficient = purgeValveCoefficient;
params.blowdownValveCoefficient = blowdownValveCoefficient;
params.equalizationValveCoefficient = equalizationValveCoefficient;
params.pressurizationValveCoefficient = pressurizationValveCoefficient;

params = getFlowSheetValves(params);
params = getColBoundConds(params);
params = applyRibeiroBoundaryConditions(params, schedule, ...
    "BoundaryMode", opts.BoundaryMode, ...
    "BlowdownGainMolSecBar", opts.BlowdownGainMolSecBar, ...
    "PressurizationGainMolSecBar", opts.PressurizationGainMolSecBar, ...
    "MaxBoundaryMolarFlowMolSec", opts.MaxBoundaryMolarFlowMolSec);
params = getTimeSpan(params);
params = getEventParams(params);
params = getNumParams(params);
params.initStates = getInitialStates(params);

params.ribeiroSchedule = schedule;
params.ribeiroRuntimeFinalization = struct( ...
    "scheduled", true, ...
    "nativeScheduleVersion", string(schedule.version), ...
    "nativeValveCoefficient", nativeValveCoefficient, ...
    "feedValveCoefficient", feedValveCoefficient, ...
    "purgeValveCoefficient", purgeValveCoefficient, ...
    "blowdownValveCoefficient", blowdownValveCoefficient, ...
    "equalizationValveCoefficient", equalizationValveCoefficient, ...
    "pressurizationValveCoefficient", pressurizationValveCoefficient, ...
    "notes", "getStringParams intentionally skipped; numeric schedule matrices are explicit.");

end

function validateScheduleStruct(schedule)

requiredFields = [
    "durStep"
    "nativeStepCol"
    "typeDaeModel"
    "flowDirCol"
    "numAdsEqPrEnd"
];
fields = string(fieldnames(schedule));
missing = setdiff(requiredFields, fields);
if ~isempty(missing)
    error('RibeiroSurrogate:InvalidSchedule', ...
        'Schedule is missing required fields: %s.', char(strjoin(missing, ", ")));
end
if ~isequal(size(schedule.nativeStepCol), [4, 16])
    error('RibeiroSurrogate:InvalidScheduleSize', ...
        'schedule.nativeStepCol must be 4 by 16.');
end

end

function tf = isRuntimeFinalized(params)

required = [
    "funcIso"
    "funcRat"
    "funcEos"
    "funcVal"
    "funcVol"
    "valScaleFac"
    "nStatesT"
    "nColStT"
];
tf = all(ismember(required, string(fieldnames(params))));

end

function tFeedSec = getTFeedSec(params)

if isfield(params, 'tFeedSec') && ~isempty(params.tFeedSec)
    tFeedSec = params.tFeedSec;
else
    tFeedSec = 40;
end

end

function names = makeColumnNames(nCols)

names = cell(nCols, 1);
for idx = 1:nCols
    names{idx} = sprintf('n%d', idx);
end

end

function valveCoefficient = resolveValveCoefficient(inputValue, params, fieldName, defaultValue)

valveCoefficient = inputValue;
if isempty(valveCoefficient) && isfield(params, fieldName)
    valveCoefficient = params.(fieldName);
end
if isempty(valveCoefficient)
    valveCoefficient = defaultValue;
end

end

function mustBeEmptyOrPositiveNumericScalar(value)

if isempty(value)
    return;
end
if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || value <= 0
    error('RibeiroSurrogate:InvalidPositiveScalar', ...
        'Value must be empty or a positive numeric scalar.');
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
