function out = runRibeiroSurrogate(varargin)
%RUNRIBEIROSURROGATE Build and optionally run the Ribeiro PSA surrogate.

parser = inputParser;
parser.FunctionName = mfilename;
addParameter(parser, 'NCycles', 20, @mustBePositiveIntegerScalar);
addParameter(parser, 'NVols', 8, @mustBePositiveIntegerScalar);
addParameter(parser, 'TFeedSec', 40, @mustBePositiveNumericScalar);
addParameter(parser, 'NTimePoints', 2, @mustBePositiveIntegerScalar);
addParameter(parser, 'NativeValveCoefficient', 1e-6, @mustBePositiveNumericScalar);
addParameter(parser, 'FeedValveCoefficient', [], @mustBeEmptyOrPositiveNumericScalar);
addParameter(parser, 'PurgeValveCoefficient', [], @mustBeEmptyOrPositiveNumericScalar);
addParameter(parser, 'LdfMassTransferPerSec', [], @mustBeEmptyPositiveScalarOrBinaryVector);
addParameter(parser, 'StopAfterBuild', false, @mustBeLogicalScalar);
parse(parser, varargin{:});
opts = parser.Results;

basis = ribeiroSurrogateConstants();

params = buildRibeiroSurrogateTemplateParams( ...
    "NCycles", opts.NCycles, ...
    "NVols", opts.NVols, ...
    "NTimePoints", opts.NTimePoints, ...
    "TFeedSec", opts.TFeedSec, ...
    "NativeValveCoefficient", opts.NativeValveCoefficient, ...
    "FeedValveCoefficient", opts.FeedValveCoefficient, ...
    "PurgeValveCoefficient", opts.PurgeValveCoefficient, ...
    "LdfMassTransferPerSec", opts.LdfMassTransferPerSec, ...
    "FinalizeForRuntime", true);

schedule = buildRibeiroNativeSchedule("TFeedSec", opts.TFeedSec);
params = applyRibeiroNativeSchedule(params, schedule, ...
    "NativeValveCoefficient", opts.NativeValveCoefficient, ...
    "FeedValveCoefficient", opts.FeedValveCoefficient, ...
    "PurgeValveCoefficient", opts.PurgeValveCoefficient);

if opts.StopAfterBuild
    sol = [];
else
    sol = runPsaCycle(params);
end

summary = summarizeRibeiroRun(params, schedule, sol);

out = struct();
out.version = "Ribeiro2008-surrogate-run-v1";
out.basis = basis;
out.params = params;
out.schedule = schedule;
out.sol = sol;
out.summary = summary;

end

function mustBePositiveIntegerScalar(value)

if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || ...
        value <= 0 || value ~= fix(value)
    error('RibeiroSurrogate:InvalidPositiveInteger', ...
        'Value must be a positive integer scalar.');
end

end

function mustBePositiveNumericScalar(value)

if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || value <= 0
    error('RibeiroSurrogate:InvalidPositiveScalar', ...
        'Value must be a positive numeric scalar.');
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

function mustBeEmptyPositiveScalarOrBinaryVector(value)

if isempty(value)
    return;
end
if ~isnumeric(value) || any(~isfinite(value(:))) || any(value(:) <= 0)
    error('RibeiroSurrogate:InvalidPositiveScalarOrVector', ...
        'Value must be empty, a positive scalar, or a positive two-element vector.');
end
if ~(isscalar(value) || numel(value) == 2)
    error('RibeiroSurrogate:InvalidPositiveScalarOrVector', ...
        'Value must be empty, a positive scalar, or a positive two-element vector.');
end

end

function mustBeLogicalScalar(value)

if ~(islogical(value) && isscalar(value))
    error('RibeiroSurrogate:InvalidLogicalScalar', ...
        'Value must be a logical scalar.');
end

end
