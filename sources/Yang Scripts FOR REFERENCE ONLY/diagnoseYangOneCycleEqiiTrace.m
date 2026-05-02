function report = diagnoseYangOneCycleEqiiTrace()
%DIAGNOSEYANGONECYCLEEQIITRACE One-cycle EQII slot-7 trace diagnostic.
%
% This diagnostic runs exactly one Yang four-bed cycle under the short
% commissioning baseline, then extracts compact rows for cycle 1 slot 7 EQII.

    repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    addpath(genpath(repoRoot));

    tStart = tic;
    outputDir = fullfile(repoRoot, 'validation', 'reports', ...
        'yang_diagnostics', 'one_cycle_eqii_trace');
    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    gitInfo = collectGitInfo(repoRoot);
    if gitInfo.branch ~= "codex/yang"
        error('FI8:WrongBranch', ...
            'One-cycle EQII trace diagnostic must run on codex/yang, not %s.', ...
            char(gitInfo.branch));
    end

    params = buildYangH2Co2AcTemplateParams( ...
        'NVols', 2, ...
        'NCols', 2, ...
        'NSteps', 1, ...
        'NTimePoints', 21, ...
        'CycleTimeSec', 2.4, ...
        'FinalizeForRuntime', true);
    assert(params.yangRuntimeDefaults.nativeValveCoefficient == 1e-6);

    manifest = getYangFourBedScheduleManifest();
    pairMap = getYangDirectTransferPairMap(manifest);
    container = makeSyntheticContainer(params, manifest, pairMap);
    controls = struct( ...
        'cycleTimeSec', 2.4, ...
        'Cv_directTransfer', 1e-6, ...
        'ADPP_BF_internalSplitFraction', 1/3, ...
        'balanceAbsTol', 1e-8, ...
        'balanceRelTol', 1e-6, ...
        'debugKeepStateHistory', false);

    simOutput = evalc(['simReport = runYangFourBedSimulation(container, ', ...
        'params, controls, ''MaxCycles'', 1, ''StopAtCss'', false, ', ...
        '''KeepCycleReports'', true, ''Manifest'', manifest, ''PairMap'', pairMap);']);
    runtimeSeconds = toc(tStart);
    writeText(fullfile(outputDir, 'solver_output.txt'), simOutput);

    cycleReport = simReport.cycleReports{1};
    opReport = findEqiiSlotOperation(cycleReport);
    eqiiRows = extractEqiiRows(simReport, opReport);
    trace = makeTrace(simReport, cycleReport, opReport, eqiiRows, controls);
    microComparison = readMicroDiagnosticComparison(repoRoot);

    writetable(eqiiRows.streamRows, fullfile(outputDir, 'eqii_slot7_stream_rows.csv'));
    writetable(eqiiRows.balanceRows, fullfile(outputDir, 'eqii_slot7_balance_rows.csv'));
    writetable(eqiiRows.failingBalanceRows, fullfile(outputDir, 'all_failing_balance_rows.csv'));
    writetable(eqiiRows.cycleExternalBalanceRows, fullfile(outputDir, 'cycle_external_balance_rows.csv'));
    writeOperationReport(fullfile(outputDir, 'eqii_slot7_operation_report.txt'), opReport, trace);

    report = struct();
    report.version = "FI8-Yang2009-one-cycle-EQII-slot7-trace-v1";
    report.createdAt = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
    report.runtimeSeconds = runtimeSeconds;
    report.matlabVersion = string(version);
    report.git = gitInfo;
    report.params = struct( ...
        'valScaleFac', params.valScaleFac, ...
        'nativeValveCoefficient', params.yangRuntimeDefaults.nativeValveCoefficient, ...
        'resolvedDefaultNativeValve', params.yangRuntimeDefaults.nativeValveCoefficient * params.valScaleFac, ...
        'nScaleFac', params.nScaleFac);
    report.controls = normalizeYangFourBedControls(controls, params);
    report.simReport = simReport;
    report.eqiiOperationReport = opReport;
    report.eqiiRows = eqiiRows;
    report.trace = trace;
    report.microComparison = microComparison;
    report.outputDir = string(outputDir);

    save(fullfile(outputDir, 'one_cycle_eqii_trace_report.mat'), 'report');
    writeSummary(report, outputDir);
    printConsoleSummary(report);
end

function container = makeSyntheticContainer(params, manifest, pairMap)
    beds = ["A", "B", "C", "D"];
    states = struct();
    for i = 1:numel(beds)
        one = [0.76 - 0.01*i; 0.24 + 0.01*i; 0.01; 0.02; 1.0; 1.0];
        states.(char("state_" + beds(i))) = extractYangPhysicalBedState(params, ...
            repmat(one, params.nVols, 1), ...
            'Metadata', struct( ...
                'source', "one-cycle EQII trace synthetic state", ...
                'bed', beds(i)));
    end
    container = makeYangFourBedStateContainer(states, ...
        'Manifest', manifest, ...
        'PairMap', pairMap, ...
        'InitializationPolicy', "one-cycle EQII trace diagnostic", ...
        'SourceNote', "synthetic physical states shared with native EQ microbalance diagnostic");
end

function opReport = findEqiiSlotOperation(cycleReport)
    ops = cycleReport.operationReports;
    idx = find(string({ops.operationFamily}) == "EQII" & [ops.sourceCol] == 7, 1);
    if isempty(idx)
        idx = find(string({ops.operationFamily}) == "EQII", 1);
    end
    if isempty(idx)
        error('FI8:EqiiOperationMissing', ...
            'No EQII operation report found in one-cycle report.');
    end
    opReport = ops(idx);
end

function rows = extractEqiiRows(simReport, opReport)
    streamRows = simReport.ledger.streamRows;
    balanceRows = simReport.ledger.balanceRows;
    opId = string(opReport.operationGroupId);
    slot = opReport.sourceCol;

    rows = struct();
    rows.streamRows = streamRows(streamRows.cycle_index == 1 & ...
        streamRows.slot_index == slot & ...
        streamRows.stage_label == "EQII" & ...
        streamRows.operation_group_id == opId, :);
    rows.balanceRows = balanceRows(balanceRows.cycle_index == 1 & ...
        balanceRows.slot_index == slot & ...
        balanceRows.stage_label == "EQII" & ...
        balanceRows.operation_group_id == opId, :);

    if height(rows.streamRows) == 0 || height(rows.balanceRows) == 0
        rows.streamRows = streamRows(streamRows.stage_label == "EQII", :);
        rows.balanceRows = balanceRows(balanceRows.stage_label == "EQII", :);
    end
    rows.failingBalanceRows = balanceRows(~balanceRows.pass, :);
    rows.cycleExternalBalanceRows = balanceRows(balanceRows.balance_scope == "cycle_external", :);
end

function trace = makeTrace(simReport, cycleReport, opReport, eqiiRows, controls)
    componentNames = string(simReport.ledger.componentNames(:));
    trace = struct();
    trace.operationGroupId = string(opReport.operationGroupId);
    trace.participants = string(opReport.participants(:));
    trace.donorBed = firstOrDefault(trace.participants, 1, "unknown");
    trace.receiverBed = firstOrDefault(trace.participants, 2, "unknown");
    trace.sourceCol = opReport.sourceCol;
    trace.durationSec = opReport.durationSec;
    trace.resolvedNativeValve = opReport.runReport.localRunPreparation.valveReport.defaultDimensionlessValve;
    trace.valFeedColNorm = opReport.runReport.localRunPreparation.valveReport.valFeedColNorm;
    trace.valProdColNorm = opReport.runReport.localRunPreparation.valveReport.valProdColNorm;
    trace.counterTailDeltas = opReport.runReport.counterTailDeltas;
    trace.rawNativeCounterTailDeltas = opReport.ledgerExtractionReport.rawNativeCounterTailDeltas;
    trace.inventoryRowsAppended = opReport.inventoryRowsAppended;
    trace.ledgerRowsAppended = opReport.ledgerRowsAppended;
    trace.warnings = string(opReport.warnings(:));
    trace.eqiiSlotReproducedFailure = any(~eqiiRows.balanceRows.pass);
    trace.failingOperationIds = unique(string(eqiiRows.failingBalanceRows.operation_group_id));
    trace.maxAbsResidual = maxAbsFinite(simReport.ledger.balanceRows.residual_moles);
    trace.eqiiSlotMaxAbsResidual = maxAbsFinite(eqiiRows.balanceRows.residual_moles);
    trace.adapterTraceMagnitudes = adapterTraceMagnitudes(cycleReport);
    trace.priorTouchingOperations = findPriorTouchingOperations(cycleReport, opReport);
    trace.componentRows = componentTraceRows(componentNames, eqiiRows.streamRows, ...
        eqiiRows.balanceRows, eqiiRows.cycleExternalBalanceRows, controls);
end

function rows = componentTraceRows(componentNames, streamRows, balanceRows, cycleExternalRows, controls)
    n = numel(componentNames);
    component = componentNames(:);
    internalOutOfDonor = zeros(n, 1);
    internalIntoReceiver = zeros(n, 1);
    donorInventoryDelta = zeros(n, 1);
    receiverInventoryDelta = zeros(n, 1);
    slotExternalResidual = zeros(n, 1);
    slotInternalResidual = zeros(n, 1);
    cycleExternalResidual = zeros(n, 1);
    internalMismatch = zeros(n, 1);
    pairInventoryDelta = zeros(n, 1);
    tolerance = zeros(n, 1);

    for i = 1:n
        comp = componentNames(i);
        internalOutOfDonor(i) = sumStream(streamRows, comp, "internal_transfer", "out_of_donor", "");
        internalIntoReceiver(i) = sumStream(streamRows, comp, "internal_transfer", "into_receiver", "");
        donorInventoryDelta(i) = sumStream(streamRows, comp, "bed_inventory_delta", "delta", "donor");
        receiverInventoryDelta(i) = sumStream(streamRows, comp, "bed_inventory_delta", "delta", "receiver");
        slotExternalResidual(i) = sumBalance(balanceRows, comp, "slot_external");
        slotInternalResidual(i) = sumBalance(balanceRows, comp, "slot_internal_transfer");
        cycleExternalResidual(i) = sumBalance(cycleExternalRows, comp, "cycle_external");
        internalMismatch(i) = internalIntoReceiver(i) - internalOutOfDonor(i);
        pairInventoryDelta(i) = donorInventoryDelta(i) + receiverInventoryDelta(i);
        tolerance(i) = controls.balanceAbsTol + controls.balanceRelTol * max(abs([ ...
            internalOutOfDonor(i), internalIntoReceiver(i), donorInventoryDelta(i), receiverInventoryDelta(i)]));
    end

    rows = table(component, internalOutOfDonor, internalIntoReceiver, ...
        donorInventoryDelta, receiverInventoryDelta, internalMismatch, ...
        pairInventoryDelta, slotExternalResidual, slotInternalResidual, ...
        cycleExternalResidual, tolerance);
end

function value = sumStream(rows, component, scope, direction, localRole)
    mask = rows.component == component & rows.stream_scope == string(scope) & ...
        rows.stream_direction == string(direction);
    if strlength(string(localRole)) > 0
        mask = mask & rows.local_role == string(localRole);
    end
    value = sum(rows.moles(mask));
end

function value = sumBalance(rows, component, scope)
    mask = rows.component == component & rows.balance_scope == string(scope);
    value = sum(rows.residual_moles(mask));
end

function priorRows = findPriorTouchingOperations(cycleReport, opReport)
    ops = cycleReport.operationReports;
    participants = string(opReport.participants(:));
    targetIdx = find(string({ops.operationGroupId}) == string(opReport.operationGroupId), 1);
    if isempty(targetIdx)
        targetIdx = numel(ops) + 1;
    end

    rows = table(strings(0,1), strings(0,1), zeros(0,1), strings(0,1), strings(0,1), ...
        'VariableNames', ["operation_group_id", "operation_family", "source_col", "participants", "touching_beds"]);
    for i = 1:(targetIdx-1)
        touched = intersect(string(ops(i).participants(:)), participants, 'stable');
        if isempty(touched)
            continue;
        end
        rows = [rows; table( ... %#ok<AGROW>
            string(ops(i).operationGroupId), ...
            string(ops(i).operationFamily), ...
            double(ops(i).sourceCol), ...
            strjoin(string(ops(i).participants(:)).', "+"), ...
            strjoin(touched(:).', "+"), ...
            'VariableNames', rows.Properties.VariableNames)];
    end
    priorRows = rows;
end

function magnitudes = adapterTraceMagnitudes(cycleReport)
    ops = cycleReport.operationReports;
    family = strings(0, 1);
    operationGroupId = strings(0, 1);
    maxAbsConservationResidual = zeros(0, 1);
    ledgerRowsAppended = zeros(0, 1);
    for i = 1:numel(ops)
        if string(ops(i).route) ~= "adapter"
            continue;
        end
        family(end+1, 1) = string(ops(i).operationFamily); %#ok<AGROW>
        operationGroupId(end+1, 1) = string(ops(i).operationGroupId); %#ok<AGROW>
        maxAbsConservationResidual(end+1, 1) = maxConservationResidual(ops(i).runReport); %#ok<AGROW>
        ledgerRowsAppended(end+1, 1) = ops(i).ledgerRowsAppended; %#ok<AGROW>
    end
    magnitudes = table(operationGroupId, family, maxAbsConservationResidual, ledgerRowsAppended);
end

function value = maxConservationResidual(runReport)
    value = NaN;
    if ~isstruct(runReport) || ~isfield(runReport, 'conservation') || ...
            ~isstruct(runReport.conservation)
        return;
    end
    values = [];
    fields = string(fieldnames(runReport.conservation));
    for i = 1:numel(fields)
        field = char(fields(i));
        if contains(lower(field), "residual") || contains(lower(field), "mismatch")
            candidate = runReport.conservation.(field);
            if isnumeric(candidate)
                values = [values; candidate(:)]; %#ok<AGROW>
            end
        end
    end
    values = values(isfinite(values));
    if ~isempty(values)
        value = max(abs(values));
    end
end

function comparison = readMicroDiagnosticComparison(repoRoot)
    path = fullfile(repoRoot, 'validation', 'reports', 'yang_diagnostics', ...
        'native_eq_microbalance', 'summary.md');
    comparison = struct();
    comparison.path = string(path);
    comparison.available = isfile(path);
    comparison.summaryText = "";
    comparison.eqiiResidualPass = "unknown";
    if comparison.available
        txt = string(fileread(path));
        comparison.summaryText = txt;
        if contains(txt, "## EQII") && contains(txt, "Residual pass: `false`")
            comparison.eqiiResidualPass = "false";
        elseif contains(txt, "## EQII") && contains(txt, "Residual pass: `true`")
            comparison.eqiiResidualPass = "true";
        end
    end
end

function writeOperationReport(path, opReport, trace)
    fid = fopen(path, 'w');
    if fid < 0
        error('FI8:CannotWriteDiagnosticReport', ...
            'Could not open %s for writing.', path);
    end
    cleaner = onCleanup(@() fclose(fid));

    fprintf(fid, 'operationGroupId: %s\n', trace.operationGroupId);
    fprintf(fid, 'participants: %s\n', strjoin(trace.participants(:).', ", "));
    fprintf(fid, 'donorBed: %s\n', trace.donorBed);
    fprintf(fid, 'receiverBed: %s\n', trace.receiverBed);
    fprintf(fid, 'sourceCol: %g\n', trace.sourceCol);
    fprintf(fid, 'durationSec: %.16g\n', trace.durationSec);
    fprintf(fid, 'resolvedNativeValve: %.16g\n', trace.resolvedNativeValve);
    fprintf(fid, 'valFeedColNorm: %s\n', numericList(trace.valFeedColNorm));
    fprintf(fid, 'valProdColNorm: %s\n\n', numericList(trace.valProdColNorm));
    fprintf(fid, 'runReport.localRunPreparation.valveReport:\n%s\n', ...
        evalc('disp(opReport.runReport.localRunPreparation.valveReport)'));
    fprintf(fid, 'runReport.counterTailDeltas:\n');
    for i = 1:numel(trace.counterTailDeltas)
        fprintf(fid, '- local %d: %s\n', i, numericList(trace.counterTailDeltas{i}));
    end
    fprintf(fid, '\nledgerExtractionReport.rawNativeCounterTailDeltas:\n');
    for i = 1:numel(trace.rawNativeCounterTailDeltas)
        fprintf(fid, '- local %d: %s\n', i, numericList(trace.rawNativeCounterTailDeltas{i}));
    end
    fprintf(fid, '\ninventoryRowsAppended: %d\n', trace.inventoryRowsAppended);
    fprintf(fid, 'ledgerRowsAppended: %d\n', trace.ledgerRowsAppended);
    fprintf(fid, 'warnings: %s\n\n', strjoin(trace.warnings(:).', " | "));
    fprintf(fid, 'component trace rows:\n%s\n', evalc('disp(trace.componentRows)'));
    fprintf(fid, 'prior touching operations:\n%s\n', evalc('disp(trace.priorTouchingOperations)'));
end

function writeSummary(report, outputDir)
    path = fullfile(outputDir, 'summary.md');
    fid = fopen(path, 'w');
    if fid < 0
        error('FI8:CannotWriteDiagnosticReport', ...
            'Could not open %s for writing.', path);
    end
    cleaner = onCleanup(@() fclose(fid));

    balancePass = report.simReport.balanceSummary.pass;
    cssPass = report.simReport.cssPass;
    metricsPass = report.simReport.metricsPass;
    trace = report.trace;
    eqiiFailure = any(~report.eqiiRows.balanceRows.pass);
    failingElsewhere = height(report.eqiiRows.failingBalanceRows) > 0 && ~eqiiFailure;
    interpretation = interpret(trace, eqiiFailure, failingElsewhere, report.microComparison);

    fprintf(fid, '# One-cycle EQII slot-7 trace\n\n');
    fprintf(fid, '- Created: %s\n', report.createdAt);
    fprintf(fid, '- MATLAB version: %s\n', report.matlabVersion);
    fprintf(fid, '- Runtime seconds: %.6g\n', report.runtimeSeconds);
    fprintf(fid, '- Branch: `%s`\n', report.git.branch);
    fprintf(fid, '- Commit SHA: `%s`\n', report.git.commit);
    fprintf(fid, '- Git status short:\n\n```text\n%s\n```\n\n', emptyText(report.git.statusShort));
    fprintf(fid, '- Recent commits:\n\n```text\n%s\n```\n\n', emptyText(report.git.logOneline5));
    fprintf(fid, '- Run completed: `%s`\n', boolText(report.simReport.runCompleted));
    fprintf(fid, '- Balance pass: `%s`\n', boolText(balancePass));
    fprintf(fid, '- Metrics pass: `%s`\n', boolText(metricsPass));
    fprintf(fid, '- CSS pass: `%s` (not meaningful for one cycle; reported only because the simulation API computes it)\n', boolText(cssPass));
    fprintf(fid, '- Max absolute residual: %.16g\n', trace.maxAbsResidual);
    fprintf(fid, '- Cycle 1 slot 7 EQII reproduced balance failure: `%s`\n', boolText(eqiiFailure));
    fprintf(fid, '- Operation group ID: `%s`\n', trace.operationGroupId);
    fprintf(fid, '- Participants: %s\n', strjoin(trace.participants(:).', ", "));
    fprintf(fid, '- Resolved native valve: %.16g\n', trace.resolvedNativeValve);
    fprintf(fid, '- `valFeedColNorm`: %s\n', numericList(trace.valFeedColNorm));
    fprintf(fid, '- `valProdColNorm`: %s\n\n', numericList(trace.valProdColNorm));

    fprintf(fid, '## Component Trace\n\n');
    fprintf(fid, '| Component | internal out | internal in | bed donor delta | bed receiver delta | slot external residual | slot internal residual | cycle external residual |\n');
    fprintf(fid, '|---|---:|---:|---:|---:|---:|---:|---:|\n');
    rows = trace.componentRows;
    for i = 1:height(rows)
        fprintf(fid, '| %s | %.16g | %.16g | %.16g | %.16g | %.16g | %.16g | %.16g |\n', ...
            rows.component(i), rows.internalOutOfDonor(i), rows.internalIntoReceiver(i), ...
            rows.donorInventoryDelta(i), rows.receiverInventoryDelta(i), ...
            rows.slotExternalResidual(i), rows.slotInternalResidual(i), ...
            rows.cycleExternalResidual(i));
    end

    fprintf(fid, '\n## Adapter Trace Magnitudes\n\n');
    if height(trace.adapterTraceMagnitudes) == 0
        fprintf(fid, 'No adapter trace magnitudes available.\n\n');
    else
        fprintf(fid, '| Operation | Family | Max adapter conservation residual | Ledger rows appended |\n');
        fprintf(fid, '|---|---|---:|---:|\n');
        for i = 1:height(trace.adapterTraceMagnitudes)
            fprintf(fid, '| %s | %s | %.16g | %d |\n', ...
                trace.adapterTraceMagnitudes.operationGroupId(i), ...
                trace.adapterTraceMagnitudes.family(i), ...
                trace.adapterTraceMagnitudes.maxAbsConservationResidual(i), ...
                trace.adapterTraceMagnitudes.ledgerRowsAppended(i));
        end
        fprintf(fid, '\n');
    end

    fprintf(fid, '## Micro-Diagnostic Comparison\n\n');
    fprintf(fid, '- Micro summary available: `%s`\n', boolText(report.microComparison.available));
    fprintf(fid, '- Isolated EQII residual pass from summary: `%s`\n', report.microComparison.eqiiResidualPass);
    if report.microComparison.available
        fprintf(fid, '- Compared against: `%s`\n', report.microComparison.path);
    end
    fprintf(fid, '\n## Prior Operations Touching EQII Beds\n\n');
    if height(trace.priorTouchingOperations) == 0
        fprintf(fid, 'No prior operations touched the EQII participant beds before this group.\n\n');
    else
        fprintf(fid, '| Operation | Family | Source col | Participants | Touching beds |\n');
        fprintf(fid, '|---|---|---:|---|---|\n');
        for i = 1:height(trace.priorTouchingOperations)
            fprintf(fid, '| %s | %s | %.0f | %s | %s |\n', ...
                trace.priorTouchingOperations.operation_group_id(i), ...
                trace.priorTouchingOperations.operation_family(i), ...
                trace.priorTouchingOperations.source_col(i), ...
                trace.priorTouchingOperations.participants(i), ...
                trace.priorTouchingOperations.touching_beds(i));
        end
        fprintf(fid, '\n');
    end

    fprintf(fid, '## Interpretation\n\n%s\n\n', interpretation);
    fprintf(fid, 'Next recommended action: %s\n', nextRecommendedAction(interpretation));
end

function text = interpret(trace, eqiiFailure, failingElsewhere, microComparison)
    if ~eqiiFailure && ~failingElsewhere
        text = "Case A: one-cycle current branch passes; the previous failure is not reproduced under the current codex/yang baseline.";
    elseif eqiiFailure && microComparison.eqiiResidualPass == "false"
        text = "Case B: one-cycle EQII fails and isolated EQII also failed; focus next on native EQII local-run accounting, especially counter-tail extraction versus physical inventory deltas.";
    elseif eqiiFailure && microComparison.eqiiResidualPass == "true"
        text = "Case C: one-cycle EQII fails but isolated EQII passed; the issue depends on sequence/state entering slot 7.";
    elseif failingElsewhere
        text = "Case D: failure is not EQII slot 7; review the actual failing balance rows before chasing EQII-specific hypotheses.";
    else
        text = "Mixed result: inspect compact trace files before assigning cause.";
    end

    if ~eqiiFailure && trace.eqiiSlotMaxAbsResidual > 0
        text = text + " EQII slot residuals are nonzero but below configured tolerance.";
    end
end

function text = nextRecommendedAction(interpretation)
    if contains(interpretation, "Case B")
        text = "inspect `extractYangNativeLedgerRows.m` EQII role/sign handling against signed native product-end counter tails and bed inventory deltas; do not adjust adapters yet.";
    elseif contains(interpretation, "Case C")
        text = "run a tiny prefix trace for only the prior operations touching the EQII participant beds.";
    elseif contains(interpretation, "Case A")
        text = "stop this diagnostic campaign and record that the current branch does not reproduce the prior EQII balance failure under baseline settings.";
    else
        text = "review `all_failing_balance_rows.csv` and decide the next focused diagnostic from the actual failing operation.";
    end
end

function printConsoleSummary(report)
    fprintf('Yang one-cycle EQII trace wrote %s\n', report.outputDir);
    fprintf('branch=%s\n', report.git.branch);
    fprintf('commit=%s\n', report.git.commit);
    fprintf('runCompleted=%d balancePass=%d metricsPass=%d cssPass=%d\n', ...
        report.simReport.runCompleted, report.simReport.balanceSummary.pass, ...
        report.simReport.metricsPass, report.simReport.cssPass);
    fprintf('maxAbsResidual=%.16g\n', report.trace.maxAbsResidual);
    fprintf('eqiiOperationGroupId=%s eqiiSlotMaxAbsResidual=%.16g eqiiFailure=%d\n', ...
        report.trace.operationGroupId, report.trace.eqiiSlotMaxAbsResidual, ...
        any(~report.eqiiRows.balanceRows.pass));
end

function gitInfo = collectGitInfo(repoRoot)
    gitInfo = struct();
    gitInfo.branch = runGit(repoRoot, 'rev-parse --abbrev-ref HEAD');
    gitInfo.commit = runGit(repoRoot, 'rev-parse HEAD');
    gitInfo.statusShort = runGit(repoRoot, 'status --short');
    gitInfo.logOneline5 = runGit(repoRoot, 'log --oneline -5');
end

function out = runGit(repoRoot, args)
    command = sprintf('git -C "%s" %s', repoRoot, args);
    [status, raw] = system(command);
    out = string(strtrim(raw));
    if status ~= 0
        out = "ERROR: " + out;
    end
end

function writeText(path, text)
    fid = fopen(path, 'w');
    if fid < 0
        error('FI8:CannotWriteDiagnosticReport', ...
            'Could not open %s for writing.', path);
    end
    cleaner = onCleanup(@() fclose(fid));
    fprintf(fid, '%s', text);
end

function value = firstOrDefault(values, idx, defaultValue)
    if numel(values) >= idx
        value = values(idx);
    else
        value = string(defaultValue);
    end
end

function value = maxAbsFinite(values)
    values = values(isfinite(values));
    if isempty(values)
        value = 0;
    else
        value = max(abs(values));
    end
end

function text = emptyText(text)
    if strlength(text) == 0
        text = "(empty)";
    end
end

function text = boolText(value)
    if value
        text = "true";
    else
        text = "false";
    end
end

function text = numericList(values)
    values = values(:);
    parts = strings(numel(values), 1);
    for i = 1:numel(values)
        parts(i) = sprintf('%.16g', values(i));
    end
    text = "[" + strjoin(parts, ", ") + "]";
end
