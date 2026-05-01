function [tDom, timeReport] = resolveYangNativeTimeDomain(params, varargin)
%RESOLVEYANGNATIVETIMEDOMAIN Resolve native fixed-duration time basis.

    parser = inputParser;
    parser.FunctionName = "resolveYangNativeTimeDomain";
    addParameter(parser, 'DurationSeconds', []);
    addParameter(parser, 'DurationDimless', []);
    addParameter(parser, 'TempCase', []);
    parse(parser, varargin{:});
    opts = parser.Results;

    [durationSeconds, durationDimless, source] = resolveDurationInputs(opts);
    if ~isempty(durationDimless)
        timeBasis = "dimensionless";
    elseif ~isempty(durationSeconds)
        if ~isstruct(params) || ~isfield(params, 'tiScaleFac') || isempty(params.tiScaleFac)
            error('FI8:CannotConvertDurationSeconds', ...
                'DurationSeconds was supplied but params.tiScaleFac is missing.');
        end
        if ~isnumeric(params.tiScaleFac) || ~isscalar(params.tiScaleFac) || ...
                ~isfinite(params.tiScaleFac) || params.tiScaleFac <= 0
            error('FI8:CannotConvertDurationSeconds', ...
                'params.tiScaleFac must be a finite positive scalar.');
        end
        durationDimless = durationSeconds ./ params.tiScaleFac;
        timeBasis = "seconds_converted_to_dimensionless_using_tiScaleFac";
    else
        error('FI8:MissingDuration', ...
            'Native run requires DurationSeconds or DurationDimless.');
    end

    validateattributes(durationDimless, {'numeric'}, ...
        {'scalar', 'real', 'finite', 'positive'}, mfilename, 'durationDimless');
    tDom = [0, durationDimless];
    timeReport = struct( ...
        "durationSeconds", durationSeconds, ...
        "durationDimless", durationDimless, ...
        "timeBasis", timeBasis, ...
        "durationSource", source);
end

function [durationSeconds, durationDimless, source] = resolveDurationInputs(opts)
    durationSeconds = opts.DurationSeconds;
    durationDimless = opts.DurationDimless;
    source = "explicit_runner_option";
    if ~isempty(durationSeconds) && ~isempty(durationDimless)
        error('FI8:AmbiguousDuration', ...
            'Provide only one of DurationSeconds or DurationDimless.');
    end

    tempCase = opts.TempCase;
    if isempty(durationSeconds) && isempty(durationDimless) && isstruct(tempCase) && ...
            isfield(tempCase, 'execution')
        if isfield(tempCase.execution, 'durationDimless') && ...
                ~isempty(tempCase.execution.durationDimless)
            durationDimless = tempCase.execution.durationDimless;
            source = "tempCase.execution.durationDimless";
        elseif isfield(tempCase.execution, 'durationSeconds') && ...
                ~isempty(tempCase.execution.durationSeconds)
            durationSeconds = tempCase.execution.durationSeconds;
            source = "tempCase.execution.durationSeconds";
        end
    end

    if ~isempty(durationSeconds)
        validateattributes(durationSeconds, {'numeric'}, ...
            {'scalar', 'real', 'finite', 'positive'}, mfilename, 'durationSeconds');
    end
    if ~isempty(durationDimless)
        validateattributes(durationDimless, {'numeric'}, ...
            {'scalar', 'real', 'finite', 'positive'}, mfilename, 'durationDimless');
    end
end
