function sweep = runRibeiroConvergenceSweep(varargin)
%RUNRIBEIROCONVERGENCESWEEP Run a pressure-gated Ribeiro NVols sweep.

parser = inputParser;
parser.FunctionName = mfilename;
addParameter(parser, 'NVols', [3, 8, 16, 32], @mustBePositiveIntegerVector);
addParameter(parser, 'NCycles', 20, @mustBePositiveIntegerScalar);
addParameter(parser, 'NTimePoints', 2, @mustBePositiveIntegerScalar);
addParameter(parser, 'TFeedSec', 40, @mustBePositiveNumericScalar);
addParameter(parser, 'BoundaryMode', "ribeiro_fixed_non_eq", @mustBeValidBoundaryMode);
addParameter(parser, 'FeedBasisMode', "full_total_renormalized_binary", ...
    @mustBeValidFeedBasisMode);
addParameter(parser, 'OutputDir', "", @(value) isstring(value) || ischar(value));
parse(parser, varargin{:});
opts = parser.Results;

nVolsList = opts.NVols(:).';
sweep = struct();
sweep.version = "Ribeiro2008-convergence-sweep-v1";
sweep.nVols = nVolsList;
sweep.nCycles = opts.NCycles;
sweep.nTimePoints = opts.NTimePoints;
sweep.tFeedSec = opts.TFeedSec;
sweep.boundaryMode = string(opts.BoundaryMode);
sweep.feedBasisMode = string(opts.FeedBasisMode);
sweep.results = repmat(emptyResult(), numel(nVolsList), 1);

for idx = 1:numel(nVolsList)
    out = runRibeiroSurrogate( ...
        "BoundaryMode", opts.BoundaryMode, ...
        "FeedBasisMode", opts.FeedBasisMode, ...
        "NVols", nVolsList(idx), ...
        "NCycles", opts.NCycles, ...
        "NTimePoints", opts.NTimePoints, ...
        "TFeedSec", opts.TFeedSec);

    if strlength(string(opts.OutputDir)) > 0
        writeRibeiroRunSummary(out, fullfile(char(opts.OutputDir), ...
            sprintf('nvols_%d', nVolsList(idx))));
    end

    sweep.results(idx) = summarizeCase(nVolsList(idx), out.summary);
end

end

function result = emptyResult()

result = struct( ...
    'nVols', NaN, ...
    'softValidationStatus', "", ...
    'cssMetricGatePassed', false, ...
    'maxFeedPressureErrorBar', NaN, ...
    'maxLowPressureErrorBar', NaN, ...
    'maxPressurizationErrorBar', NaN, ...
    'totalFeedMolesRelativeError', NaN, ...
    'purgeH2RelativeError', NaN, ...
    'ribeiroEq2PurityH2', NaN, ...
    'ribeiroEq3RecoveryH2', NaN, ...
    'feedStepProductCO2MolesFinalCycle', NaN, ...
    'purityH2AbsDriftLastCycle', NaN, ...
    'recoveryH2AbsDriftLastCycle', NaN);

end

function result = summarizeCase(nVols, summary)

result = emptyResult();
result.nVols = nVols;
result.softValidationStatus = string(summary.softValidationStatus);
result.cssMetricGatePassed = summary.cssMetricGatePassed;
result.maxFeedPressureErrorBar = ...
    summary.ribeiroPressureAudit.maxFeedPressureErrorBar;
result.maxLowPressureErrorBar = ...
    summary.ribeiroPressureAudit.maxLowPressureErrorBar;
result.maxPressurizationErrorBar = ...
    summary.ribeiroPressureAudit.maxPressurizationErrorBar;
result.totalFeedMolesRelativeError = summary.totalFeedMolesRelativeError;
result.purgeH2RelativeError = summary.purgeH2RelativeError;
result.ribeiroEq2PurityH2 = summary.ribeiroEq2PurityH2;
result.ribeiroEq3RecoveryH2 = summary.ribeiroEq3RecoveryH2;
if numel(summary.feedStepProductMolesFinalCycle) >= 2
    result.feedStepProductCO2MolesFinalCycle = ...
        summary.feedStepProductMolesFinalCycle(2);
end
result.purityH2AbsDriftLastCycle = summary.purityH2AbsDriftLastCycle;
result.recoveryH2AbsDriftLastCycle = summary.recoveryH2AbsDriftLastCycle;

end

function mustBePositiveIntegerVector(value)

if ~isnumeric(value) || isempty(value) || any(~isfinite(value(:))) || ...
        any(value(:) <= 0) || any(value(:) ~= fix(value(:)))
    error('RibeiroSurrogate:InvalidPositiveIntegerVector', ...
        'Value must be a nonempty vector of positive integers.');
end

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

function mustBeValidBoundaryMode(value)

validatestring(char(value), {'native_valves', 'ribeiro_fixed_non_eq'});

end

function mustBeValidFeedBasisMode(value)

validatestring(char(value), ...
    {'full_total_renormalized_binary', 'source_h2co2_partial_flow'});

end
