function [terminalLocalStates, runReport] = runYangTemporaryCase(tempCase, varargin)
%RUNYANGTEMPORARYCASE Execute or dry-run a WP4 temporary case.

    parser = inputParser;
    addParameter(parser, 'Runner', "dry_run");
    addParameter(parser, 'RunnerFunction', []);
    addParameter(parser, 'TemplateParams', []);
    addParameter(parser, 'Controls', []);
    addParameter(parser, 'DurationSeconds', []);
    addParameter(parser, 'DurationDimless', []);
    parse(parser, varargin{:});
    opts = parser.Results;

    result = validateYangTemporaryCase(tempCase);
    if ~result.pass
        error('WP4:InvalidTemporaryCase', ...
            'Cannot run invalid temporary case: %s', char(strjoin(result.failures, " | ")));
    end

    runner = string(opts.Runner);
    switch runner
        case "dry_run"
            terminalLocalStates = tempCase.localStates(:);
            runReport = baseReport(tempCase, runner);
            runReport.didInvokeNative = false;
            runReport.callCount = 0;
            runReport.message = "dry_run returned local states unchanged";

        case "spy"
            if isempty(opts.RunnerFunction) || ~isa(opts.RunnerFunction, 'function_handle')
                error('WP4:MissingRunnerFunction', ...
                    'Runner "spy" requires a RunnerFunction function handle.');
            end

            [terminalLocalStates, spyReport] = opts.RunnerFunction(tempCase);
            terminalLocalStates = normalizeTerminalStates(terminalLocalStates, tempCase.nLocalBeds);
            runReport = baseReport(tempCase, runner);
            runReport.didInvokeNative = false;
            runReport.callCount = getOptionalReportField(spyReport, "callCount", 1);
            runReport.spyReport = spyReport;
            runReport.message = "spy runner invoked once by WP4 adapter";

        case "native"
            [terminalLocalStates, runReport] = runNative(tempCase, opts);

        otherwise
            error('WP4:UnsupportedRunner', ...
                'Unsupported WP4 temporary case runner %s.', char(runner));
    end
end

function [terminalLocalStates, runReport] = runNative(tempCase, opts)
    if ~logical(tempCase.native.nativeRunnable)
        error('WP4:UnsupportedNativeOperation', ...
            'Temporary case operation %s is not native-runnable: %s', ...
            char(string(tempCase.native.wrapperOperation)), ...
            char(string(tempCase.native.unsupportedReason)));
    end

    if isempty(opts.TemplateParams) || ~isstruct(opts.TemplateParams)
        error('WP4:MissingTemplateParams', ...
            'Runner "native" requires initialized TemplateParams.');
    end

    [params, prepReport] = prepareYangNativeLocalRunParams(tempCase, opts.TemplateParams, ...
        'Controls', opts.Controls, ...
        'DurationSeconds', opts.DurationSeconds, ...
        'DurationDimless', opts.DurationDimless);
    [tDom, timeReport] = resolveYangNativeTimeDomain(params, ...
        'DurationSeconds', opts.DurationSeconds, ...
        'DurationDimless', opts.DurationDimless, ...
        'TempCase', tempCase);
    [stTime, stStates, flags] = runPsaCycleStep(params, params.initStates, tDom, 1, 1);
    [terminalLocalStates, counterTailReport] = extractYangTerminalLocalStates(params, stStates, tempCase);
    counterTailDeltas = computeYangCounterTailDeltasFromStates( ...
        params, stStates, tempCase.nLocalBeds);

    runReport = baseReport(tempCase, "native");
    runReport.didInvokeNative = true;
    runReport.callCount = 1;
    runReport.localRunPreparation = prepReport;
    runReport.durationSeconds = timeReport.durationSeconds;
    runReport.durationDimless = timeReport.durationDimless;
    runReport.timeBasis = timeReport.timeBasis;
    runReport.durationSource = timeReport.durationSource;
    runReport.timeDomain = tDom;
    runReport.stTime = stTime;
    runReport.stStates = stStates;
    runReport.flags = flags;
    runReport.counterTailReport = counterTailReport;
    runReport.counterTailDeltas = counterTailDeltas;
    runReport.counterTailBasis = "native_counter_tail_delta_from_stStates";
    runReport.counterTailLayout = "first_nComs_feed_end_second_nComs_product_end";
    runReport.message = "native runner invoked existing toPSAil step machinery";
end

function report = baseReport(tempCase, runner)
    report = struct();
    report.version = "WP4-Yang2009-temporary-case-run-report-v1";
    report.runner = string(runner);
    report.caseType = string(tempCase.caseType);
    report.pairId = string(tempCase.pairId);
    report.directTransferFamily = string(tempCase.directTransferFamily);
    report.localMap = tempCase.localMap;
end

function terminalLocalStates = normalizeTerminalStates(terminalLocalStates, nLocalBeds)
    if ~iscell(terminalLocalStates)
        error('WP4:InvalidTerminalStates', ...
            'Runner must return terminalLocalStates as a cell array.');
    end

    terminalLocalStates = terminalLocalStates(:);
    if numel(terminalLocalStates) ~= nLocalBeds
        error('WP4:TerminalStateCountMismatch', ...
            'Runner returned %d terminal states; expected %d.', ...
            numel(terminalLocalStates), nLocalBeds);
    end
end

function value = getOptionalReportField(report, fieldName, defaultValue)
    value = defaultValue;
    if isstruct(report) && isfield(report, char(fieldName))
        value = report.(char(fieldName));
    end
end
