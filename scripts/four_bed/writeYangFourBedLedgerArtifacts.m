function status = writeYangFourBedLedgerArtifacts(ledger, outputDir, varargin)
%WRITEYANGFOURBEDLEDGERARTIFACTS Write compact FI-8 ledger handoff files.

    parser = inputParser;
    addParameter(parser, 'FileStem', "yang_four_bed_ledger");
    parse(parser, varargin{:});
    opts = parser.Results;

    result = validateYangFourBedLedger(ledger);
    if ~result.pass
        error('FI8:InvalidLedgerArtifacts', ...
            'Cannot write artifacts for invalid ledger: %s', ...
            char(strjoin(result.failures, " | ")));
    end
    if nargin < 2 || strlength(string(outputDir)) == 0
        error('FI8:MissingLedgerArtifactDir', ...
            'outputDir must be supplied for ledger artifacts.');
    end
    if ~exist(string(outputDir), 'dir')
        mkdir(string(outputDir));
    end

    fileStem = string(opts.FileStem);
    streamPath = fullfile(string(outputDir), fileStem + "_stream_rows.csv");
    balancePath = fullfile(string(outputDir), fileStem + "_balance_rows.csv");
    metricPath = fullfile(string(outputDir), fileStem + "_metric_rows.csv");
    summaryPath = fullfile(string(outputDir), fileStem + "_summary.json");

    writetable(ledger.streamRows, streamPath);
    writetable(ledger.balanceRows, balancePath);
    writetable(ledger.metricRows, metricPath);

    summary = summarizeYangFourBedLedger(ledger);
    summary.streamTotals = table2struct(summary.streamTotals);
    summary.balanceRowCount = height(ledger.balanceRows);
    summary.metricRowCount = height(ledger.metricRows);
    summary.cssRowCount = height(ledger.cssRows);
    writeJson(summaryPath, summary);

    paths = [streamPath; balancePath; metricPath; summaryPath];
    bytes = zeros(numel(paths), 1);
    exists = false(numel(paths), 1);
    for i = 1:numel(paths)
        info = dir(paths(i));
        exists(i) = ~isempty(info);
        if exists(i)
            bytes(i) = info.bytes;
        end
    end

    status = struct();
    status.version = "FI8-Yang2009-ledger-artifacts-status-v1";
    status.outputDir = string(outputDir);
    status.paths = paths;
    status.bytes = bytes;
    status.pass = all(exists) && all(bytes > 0);
end

function writeJson(path, payload)
    fid = fopen(path, 'w');
    if fid < 0
        error('FI8:LedgerArtifactWriteFailed', ...
            'Unable to open ledger artifact path %s.', char(path));
    end
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, '%s', jsonencode(payload, PrettyPrint=true));
    clear cleanup;
end
