function report = diagnoseYangMetricAccountingLadder(varargin)
%DIAGNOSEYANGMETRICACCOUNTINGLADDER Lightweight H2 metric accounting audit.
%
% Diagnostic only. This script runs the current cheap Yang H2/CO2 AC
% four-bed baseline and explains H2 purity/recovery from wrapper ledger
% product, waste, bed-inventory, adapter, and paired-operation rows.

    parser = inputParser;
    parser.FunctionName = "diagnoseYangMetricAccountingLadder";
    addParameter(parser, "OutputDir", fullfile(pwd, "validation", "reports", ...
        "yang_diagnostics", "metric_accounting_ladder"), ...
        @(x) ischar(x) || isstring(x));
    addParameter(parser, "MaxCycles", 3, @(x) isnumeric(x) && isscalar(x) && ...
        isfinite(x) && x >= 1 && fix(x) == x);
    addParameter(parser, "RuntimeLimitSec", 150, @(x) isnumeric(x) && ...
        isscalar(x) && isfinite(x) && x > 0);
    parse(parser, varargin{:});
    opts = parser.Results;

    outputDir = string(opts.OutputDir);
    if ~isfolder(outputDir)
        mkdir(outputDir);
    end

    startedAt = datetime("now", "TimeZone", "local");
    runIdentity = collectRunIdentity();
    manifest = getYangFourBedScheduleManifest();
    pairMap = getYangDirectTransferPairMap(manifest);
    [params, controls, initialContainer, baseline] = buildBaseline(manifest, pairMap);

    maxCyclesRequested = min(double(opts.MaxCycles), 3);
    [simReport, solverOutput, runtimeSec, runCompleted, runError, cyclesUsed, fallbackReason] = ...
        runBaselineWithFallback(initialContainer, params, controls, manifest, pairMap, ...
        maxCyclesRequested, double(opts.RuntimeLimitSec));

    cycleH2 = makeCycleH2Accounting(simReport);
    cumulativeH2 = makeCumulativeH2Accounting(cycleH2);
    stageScope = makeStageScopeDecomposition(simReport.ledger.streamRows);
    operationH2 = makeOperationH2Decomposition(simReport);
    adapterMagnitude = makeAdapterMagnitudeSummary(simReport);
    pairedAudit = makePairedOperationDirectionAudit(simReport);
    failingBalanceRows = simReport.ledger.balanceRows(~simReport.ledger.balanceRows.pass, :);

    summaryStats = makeSummaryStats(simReport, cycleH2, cumulativeH2, ...
        stageScope, operationH2, adapterMagnitude, pairedAudit, failingBalanceRows);

    writetable(cycleH2, fullfile(outputDir, "cycle_h2_accounting.csv"));
    writetable(cumulativeH2, fullfile(outputDir, "cumulative_h2_accounting.csv"));
    writetable(stageScope, fullfile(outputDir, "stage_scope_decomposition.csv"));
    writetable(operationH2, fullfile(outputDir, "operation_h2_decomposition.csv"));
    writetable(adapterMagnitude, fullfile(outputDir, "adapter_magnitude_summary.csv"));
    writetable(pairedAudit, fullfile(outputDir, "paired_operation_direction_audit.csv"));
    writetable(failingBalanceRows, fullfile(outputDir, "failing_balance_rows.csv"));

    completedAt = datetime("now", "TimeZone", "local");
    report = struct();
    report.version = "Yang-metric-accounting-ladder-diagnostic-v1";
    report.startedAt = startedAt;
    report.completedAt = completedAt;
    report.outputDir = outputDir;
    report.runIdentity = runIdentity;
    report.baseline = baseline;
    report.runtimeSec = runtimeSec;
    report.cyclesUsed = cyclesUsed;
    report.maxCyclesRequested = maxCyclesRequested;
    report.fallbackReason = string(fallbackReason);
    report.runCompleted = runCompleted;
    report.runError = string(runError);
    report.solverOutput = string(solverOutput);
    report.paramsValScaleFac = params.valScaleFac;
    report.rawNativeValveCoefficient = params.yangRuntimeDefaults.nativeValveCoefficient;
    report.resolvedNativeValveCoefficient = params.yangRuntimeDefaults.nativeValveCoefficient .* params.valScaleFac;
    report.Cv_directTransfer = controls.Cv_directTransfer;
    report.simReport = simReport;
    report.cycleH2Accounting = cycleH2;
    report.cumulativeH2Accounting = cumulativeH2;
    report.stageScopeDecomposition = stageScope;
    report.operationH2Decomposition = operationH2;
    report.adapterMagnitudeSummary = adapterMagnitude;
    report.pairedOperationDirectionAudit = pairedAudit;
    report.failingBalanceRows = failingBalanceRows;
    report.summaryStats = summaryStats;

    writeSummaryMarkdown(report, fullfile(outputDir, "summary.md"));
    save(fullfile(outputDir, "metric_accounting_ladder_report.mat"), "report");
end

function [params, controls, initialContainer, baseline] = buildBaseline(manifest, pairMap)
    params = buildYangH2Co2AcTemplateParams( ...
        'NVols', 2, ...
        'NCols', 2, ...
        'NSteps', 1, ...
        'NTimePoints', 21, ...
        'CycleTimeSec', 2.4, ...
        'FinalizeForRuntime', true);

    controls = struct( ...
        'cycleTimeSec', 2.4, ...
        'Cv_directTransfer', 1e-6, ...
        'ADPP_BF_internalSplitFraction', 1/3, ...
        'balanceAbsTol', 1e-8, ...
        'balanceRelTol', 1e-6);
    controls = normalizeYangFourBedControls(controls, params);

    initialContainer = makeDiagnosticInitialContainer(params, manifest, pairMap);

    baseline = struct();
    baseline.paramsBuilder = "buildYangH2Co2AcTemplateParams";
    baseline.paramsOptions = "NVols=2, NCols=2, NSteps=1, NTimePoints=21, CycleTimeSec=2.4, FinalizeForRuntime=true";
    baseline.controls = controls;
    baseline.initializationPolicy = string(initialContainer.initializationPolicy);
    baseline.initializationSourceNote = string(initialContainer.stateMetadata.source_note(1));
end

function container = makeDiagnosticInitialContainer(params, manifest, pairMap)
    states = struct();
    beds = ["A", "B", "C", "D"];
    for i = 1:numel(beds)
        oneCell = [0.76 - 0.01 * i; 0.24 + 0.01 * i; 0.01; 0.02; 1.0; 1.0];
        states.("state_" + beds(i)) = extractYangPhysicalBedState(params, ...
            repmat(oneCell, params.nVols, 1));
    end
    container = makeYangFourBedStateContainer(states, ...
        "Manifest", manifest, ...
        "PairMap", pairMap, ...
        "InitializationPolicy", "metric accounting ladder synthetic commissioning state", ...
        "SourceNote", "same two-volume synthetic pattern used by current Yang diagnostics");
end

function [simReport, solverOutput, runtimeSec, runCompleted, runError, cyclesUsed, fallbackReason] = ...
        runBaselineWithFallback(initialContainer, params, controls, manifest, pairMap, ...
        maxCyclesRequested, runtimeLimitSec)
    runCompleted = false;
    runError = "";
    fallbackReason = "";
    cyclesUsed = maxCyclesRequested;

    try
        [simReport, solverOutput, runtimeSec] = runOneSimulation(initialContainer, ...
            params, controls, manifest, pairMap, maxCyclesRequested);
        runCompleted = true;
        if runtimeSec > runtimeLimitSec
            fallbackReason = sprintf("three-cycle run completed in %.3f s, above the %.3f s guidance; no rerun was needed because the diagnostic completed", ...
                runtimeSec, runtimeLimitSec);
        end
    catch ME
        fallbackReason = "requested run failed or became unstable; reran MaxCycles=1";
        runError = string(getReport(ME, "basic", "hyperlinks", "off"));
        cyclesUsed = 1;
        [simReport, solverOutput, runtimeSec] = runOneSimulation(initialContainer, ...
            params, controls, manifest, pairMap, 1);
        runCompleted = true;
    end
end

function [simReport, solverOutput, runtimeSec] = runOneSimulation(initialContainer, ...
        params, controls, manifest, pairMap, maxCycles)
    tic;
    solverOutput = evalc(['simReport = runYangFourBedSimulation(initialContainer, ', ...
        'params, controls, ''MaxCycles'', maxCycles, ''StopAtCss'', false, ', ...
        '''KeepCycleReports'', true, ''Manifest'', manifest, ''PairMap'', pairMap);']);
    runtimeSec = toc;
end

function runIdentity = collectRunIdentity()
    runIdentity = struct();
    runIdentity.branch = runSystemText("git branch --show-current");
    runIdentity.commitSha = runSystemText("git rev-parse HEAD");
    statusText = runSystemText("git status --short");
    if strlength(strtrim(statusText)) == 0
        statusText = "clean";
    end
    runIdentity.gitStatusShort = statusText;
    runIdentity.matlabVersion = string(version);
    runIdentity.generatedAt = string(datetime("now", "TimeZone", "local"));
end

function text = runSystemText(command)
    [status, output] = system(char(command));
    text = string(strtrim(output));
    if status ~= 0
        text = "system command failed: " + string(command) + " :: " + text;
    end
end

function tbl = makeCycleH2Accounting(simReport)
    rows = simReport.ledger.streamRows;
    cycles = unique(rows.cycle_index);
    cycles = cycles(isfinite(cycles));
    cycles = sort(cycles(:));
    outRows = repmat(cycleTemplate(), numel(cycles), 1);
    for i = 1:numel(cycles)
        cycleIndex = cycles(i);
        feed = sumLedgerRows(rows, cycleIndex, "H2", "external_feed", "", "", "");
        product = sumLedgerRows(rows, cycleIndex, "H2", "external_product", "", "", "");
        waste = sumLedgerRows(rows, cycleIndex, "H2", "external_waste", "", "", "");
        bedDelta = sumLedgerRows(rows, cycleIndex, "H2", "bed_inventory_delta", "", "", "");
        residual = feed - product - waste - bedDelta;
        balance = findBalanceRow(simReport.ledger.balanceRows, cycleIndex, ...
            "cycle_external", "cycle_total", "H2");

        row = cycleTemplate();
        row.cycle_index = cycleIndex;
        row.external_feed_H2_mol = feed;
        row.external_product_H2_mol = product;
        row.external_waste_H2_mol = waste;
        row.bed_inventory_delta_H2_mol = bedDelta;
        row.residual_H2_mol = residual;
        row.reported_recovery = metricValue(simReport, cycleIndex, ...
            "product_recovery", "H2");
        row.balance_predicted_recovery = safeRatio(productFromBalance(feed, waste, bedDelta), feed);
        row.recomputed_recovery = safeRatio(product, feed);
        row.waste_fraction = safeRatio(waste, feed);
        row.inventory_fraction = safeRatio(bedDelta, feed);
        row.product_purity_H2 = metricValue(simReport, cycleIndex, ...
            "product_purity", "H2");
        row.balance_pass = balance.pass;
        row.ledger_balance_residual_H2_mol = balance.residual_moles;
        row.ledger_balance_tolerance_H2_mol = balance.tolerance_moles;
        row.denominator_sensitive = abs(feed) <= tinyDenominatorThreshold(feed, product, waste, bedDelta);
        row.notes = denominatorNote(row.denominator_sensitive);
        outRows(i) = row;
    end
    tbl = struct2table(outRows);
end

function value = productFromBalance(feed, waste, bedDelta)
    value = feed - waste - bedDelta;
end

function row = cycleTemplate()
    row = struct( ...
        "cycle_index", NaN, ...
        "external_feed_H2_mol", NaN, ...
        "external_product_H2_mol", NaN, ...
        "external_waste_H2_mol", NaN, ...
        "bed_inventory_delta_H2_mol", NaN, ...
        "residual_H2_mol", NaN, ...
        "reported_recovery", NaN, ...
        "balance_predicted_recovery", NaN, ...
        "recomputed_recovery", NaN, ...
        "waste_fraction", NaN, ...
        "inventory_fraction", NaN, ...
        "product_purity_H2", NaN, ...
        "balance_pass", false, ...
        "ledger_balance_residual_H2_mol", NaN, ...
        "ledger_balance_tolerance_H2_mol", NaN, ...
        "denominator_sensitive", false, ...
        "notes", "");
end

function tbl = makeCumulativeH2Accounting(cycleTbl)
    rows = repmat(cumulativeTemplate(), height(cycleTbl), 1);
    cumFeed = 0;
    cumProduct = 0;
    cumWaste = 0;
    cumDelta = 0;
    for i = 1:height(cycleTbl)
        cumFeed = cumFeed + cycleTbl.external_feed_H2_mol(i);
        cumProduct = cumProduct + cycleTbl.external_product_H2_mol(i);
        cumWaste = cumWaste + cycleTbl.external_waste_H2_mol(i);
        cumDelta = cumDelta + cycleTbl.bed_inventory_delta_H2_mol(i);
        residual = cumFeed - cumProduct - cumWaste - cumDelta;

        row = cumulativeTemplate();
        row.through_cycle_index = cycleTbl.cycle_index(i);
        row.cumulative_feed_H2_mol = cumFeed;
        row.cumulative_product_H2_mol = cumProduct;
        row.cumulative_waste_H2_mol = cumWaste;
        row.cumulative_bed_inventory_delta_H2_mol = cumDelta;
        row.cumulative_residual_H2_mol = residual;
        row.cumulative_recovery = safeRatio(cumProduct, cumFeed);
        row.cumulative_waste_fraction = safeRatio(cumWaste, cumFeed);
        row.cumulative_inventory_fraction = safeRatio(cumDelta, cumFeed);
        row.denominator_sensitive = abs(cumFeed) <= tinyDenominatorThreshold(cumFeed, cumProduct, cumWaste, cumDelta);
        row.notes = denominatorNote(row.denominator_sensitive);
        rows(i) = row;
    end
    tbl = struct2table(rows);
end

function row = cumulativeTemplate()
    row = struct( ...
        "through_cycle_index", NaN, ...
        "cumulative_feed_H2_mol", NaN, ...
        "cumulative_product_H2_mol", NaN, ...
        "cumulative_waste_H2_mol", NaN, ...
        "cumulative_bed_inventory_delta_H2_mol", NaN, ...
        "cumulative_residual_H2_mol", NaN, ...
        "cumulative_recovery", NaN, ...
        "cumulative_waste_fraction", NaN, ...
        "cumulative_inventory_fraction", NaN, ...
        "denominator_sensitive", false, ...
        "notes", "");
end

function tbl = makeStageScopeDecomposition(rows)
    if height(rows) == 0
        tbl = struct2table(repmat(stageTemplate(), 0, 1));
        return;
    end
    keyVars = ["cycle_index", "stage_label", "direct_transfer_family", ...
        "stream_scope", "component"];
    keys = unique(rows(:, keyVars), "rows");
    outRows = repmat(stageTemplate(), height(keys), 1);
    for i = 1:height(keys)
        mask = rows.cycle_index == keys.cycle_index(i) & ...
            rows.stage_label == keys.stage_label(i) & ...
            rows.direct_transfer_family == keys.direct_transfer_family(i) & ...
            rows.stream_scope == keys.stream_scope(i) & ...
            rows.component == keys.component(i);
        total = sum(rows.moles(mask));
        scopeMask = rows.cycle_index == keys.cycle_index(i) & ...
            rows.stream_scope == keys.stream_scope(i) & ...
            rows.component == keys.component(i);
        scopeTotal = sum(rows.moles(scopeMask));

        row = stageTemplate();
        row.cycle_index = keys.cycle_index(i);
        row.stage_label = string(keys.stage_label(i));
        row.direct_transfer_family = string(keys.direct_transfer_family(i));
        row.stream_scope = string(keys.stream_scope(i));
        row.component = string(keys.component(i));
        row.moles = total;
        row.out_of_donor_moles = sum(rows.moles(mask & rows.stream_direction == "out_of_donor"));
        row.into_receiver_moles = sum(rows.moles(mask & rows.stream_direction == "into_receiver"));
        row.fraction_of_cycle_component_scope_total = safeRatio(total, scopeTotal);
        row.n_rows = sum(mask);
        outRows(i) = row;
    end
    tbl = struct2table(outRows);
    tbl = sortrows(tbl, ["cycle_index", "component", "stream_scope", "stage_label"]);
end

function row = stageTemplate()
    row = struct( ...
        "cycle_index", NaN, ...
        "stage_label", "", ...
        "direct_transfer_family", "", ...
        "stream_scope", "", ...
        "component", "", ...
        "moles", NaN, ...
        "out_of_donor_moles", NaN, ...
        "into_receiver_moles", NaN, ...
        "fraction_of_cycle_component_scope_total", NaN, ...
        "n_rows", NaN);
end

function tbl = makeOperationH2Decomposition(simReport)
    nOps = countOperationReports(simReport);
    rowsOut = repmat(operationTemplate(), nOps, 1);
    idx = 0;
    streamRows = simReport.ledger.streamRows;
    balanceRows = simReport.ledger.balanceRows;
    for c = 1:numel(simReport.cycleReports)
        cycleReport = simReport.cycleReports{c};
        cycleIndex = cycleReport.cycleIndex;
        ops = cycleReport.operationReports;
        for k = 1:numel(ops)
            idx = idx + 1;
            op = ops(k);
            opId = string(op.operationGroupId);
            opRows = streamRows(streamRows.cycle_index == cycleIndex & ...
                streamRows.operation_group_id == opId & streamRows.component == "H2", :);
            external = findBalanceRow(balanceRows, cycleIndex, "slot_external", opId, "H2");
            internal = findBalanceRow(balanceRows, cycleIndex, "slot_internal_transfer", opId, "H2");

            feed = sumScope(opRows, "external_feed");
            product = sumScope(opRows, "external_product");
            waste = sumScope(opRows, "external_waste");
            internalOut = sumDirection(opRows, "internal_transfer", "out_of_donor");
            internalIn = sumDirection(opRows, "internal_transfer", "into_receiver");
            delta = sumScope(opRows, "bed_inventory_delta");

            row = operationTemplate();
            row.cycle_index = cycleIndex;
            row.operation_group_id = opId;
            row.source_col = op.sourceCol;
            row.operation_family = string(op.operationFamily);
            row.route = string(op.route);
            row.participants = strjoin(string(op.participants(:)).', ";");
            row.H2_external_feed_mol = feed;
            row.H2_external_product_mol = product;
            row.H2_external_waste_mol = waste;
            row.H2_internal_out_mol = internalOut;
            row.H2_internal_in_mol = internalIn;
            row.H2_bed_inventory_delta_mol = delta;
            row.local_external_residual_mol = feed - product - waste - delta;
            row.slot_external_residual_mol = external.residual_moles;
            row.slot_external_tolerance_mol = external.tolerance_moles;
            row.slot_external_balance_pass = external.pass;
            row.slot_external_balance_available = external.available;
            row.slot_internal_transfer_residual_mol = internal.residual_moles;
            row.slot_internal_transfer_tolerance_mol = internal.tolerance_moles;
            row.slot_internal_transfer_balance_pass = internal.pass;
            row.slot_internal_transfer_balance_available = internal.available;
            rowsOut(idx) = row;
        end
    end
    tbl = struct2table(rowsOut);
end

function row = operationTemplate()
    row = struct( ...
        "cycle_index", NaN, ...
        "operation_group_id", "", ...
        "source_col", NaN, ...
        "operation_family", "", ...
        "route", "", ...
        "participants", "", ...
        "H2_external_feed_mol", NaN, ...
        "H2_external_product_mol", NaN, ...
        "H2_external_waste_mol", NaN, ...
        "H2_internal_out_mol", NaN, ...
        "H2_internal_in_mol", NaN, ...
        "H2_bed_inventory_delta_mol", NaN, ...
        "local_external_residual_mol", NaN, ...
        "slot_external_residual_mol", NaN, ...
        "slot_external_tolerance_mol", NaN, ...
        "slot_external_balance_pass", false, ...
        "slot_external_balance_available", false, ...
        "slot_internal_transfer_residual_mol", NaN, ...
        "slot_internal_transfer_tolerance_mol", NaN, ...
        "slot_internal_transfer_balance_pass", false, ...
        "slot_internal_transfer_balance_available", false);
end

function nOps = countOperationReports(simReport)
    nOps = 0;
    for c = 1:numel(simReport.cycleReports)
        nOps = nOps + numel(simReport.cycleReports{c}.operationReports);
    end
end

function tbl = makeAdapterMagnitudeSummary(simReport)
    streamRows = simReport.ledger.streamRows;
    adapterRows = repmat(adapterTemplate(), 0, 1);
    for c = 1:numel(simReport.cycleReports)
        cycleReport = simReport.cycleReports{c};
        cycleIndex = cycleReport.cycleIndex;
        ops = cycleReport.operationReports;
        nativeAdProduct = sumLedgerRows(streamRows, cycleIndex, "H2", ...
            "external_product", "AD", "", "");
        nativeEqInternal = sumLedgerRows(streamRows, cycleIndex, "H2", ...
            "internal_transfer", "EQI", "", "out_of_donor") + ...
            sumLedgerRows(streamRows, cycleIndex, "H2", ...
            "internal_transfer", "EQII", "", "out_of_donor");
        for k = 1:numel(ops)
            op = ops(k);
            family = string(op.operationFamily);
            if ~ismember(family, ["PP_PU", "ADPP_BF"])
                continue;
            end
            opId = string(op.operationGroupId);
            opRows = streamRows(streamRows.cycle_index == cycleIndex & ...
                streamRows.operation_group_id == opId & streamRows.component == "H2", :);
            rr = op.runReport;

            row = adapterTemplate();
            row.cycle_index = cycleIndex;
            row.operation_group_id = opId;
            row.family = family;
            row.source_col = op.sourceCol;
            row.adapter_conservation_residual_max = maxConservationResidual(rr);
            row.H2_external_feed_mol = sumScope(opRows, "external_feed");
            row.H2_external_product_mol = sumScope(opRows, "external_product");
            row.H2_internal_out_mol = sumDirection(opRows, "internal_transfer", "out_of_donor");
            row.H2_internal_in_mol = sumDirection(opRows, "internal_transfer", "into_receiver");
            row.H2_external_waste_mol = sumScope(opRows, "external_waste");
            row.effective_split_H2 = effectiveSplitH2(rr);
            row.requested_ADPP_BF_internalSplitFraction = getNumericReportField(rr, ...
                "ADPP_BF_internalSplitFraction", NaN);
            row.Cv_directTransfer_raw = getNumericReportField(rr, "Cv_directTransfer", NaN);
            row.Cv_directTransfer_resolved = getEffectiveCv(rr);
            row.native_AD_external_product_H2_cycle_mol = nativeAdProduct;
            row.native_EQ_internal_out_H2_cycle_mol = nativeEqInternal;
            row.external_product_fraction_of_native_AD_product = ...
                safeRatio(row.H2_external_product_mol, nativeAdProduct);
            row.internal_out_fraction_of_native_EQ_transfer = ...
                safeRatio(row.H2_internal_out_mol, nativeEqInternal);
            adapterRows(end+1, 1) = row; %#ok<AGROW>
        end
    end
    tbl = struct2table(adapterRows);
end

function row = adapterTemplate()
    row = struct( ...
        "cycle_index", NaN, ...
        "operation_group_id", "", ...
        "family", "", ...
        "source_col", NaN, ...
        "adapter_conservation_residual_max", NaN, ...
        "H2_external_feed_mol", NaN, ...
        "H2_external_product_mol", NaN, ...
        "H2_internal_out_mol", NaN, ...
        "H2_internal_in_mol", NaN, ...
        "H2_external_waste_mol", NaN, ...
        "effective_split_H2", NaN, ...
        "requested_ADPP_BF_internalSplitFraction", NaN, ...
        "Cv_directTransfer_raw", NaN, ...
        "Cv_directTransfer_resolved", NaN, ...
        "native_AD_external_product_H2_cycle_mol", NaN, ...
        "native_EQ_internal_out_H2_cycle_mol", NaN, ...
        "external_product_fraction_of_native_AD_product", NaN, ...
        "internal_out_fraction_of_native_EQ_transfer", NaN);
end

function tbl = makePairedOperationDirectionAudit(simReport)
    streamRows = simReport.ledger.streamRows;
    balanceRows = simReport.ledger.balanceRows;
    auditRows = repmat(pairedAuditTemplate(), 0, 1);
    pairedFamilies = ["EQI", "EQII", "PP_PU", "ADPP_BF"];
    for c = 1:numel(simReport.cycleReports)
        cycleReport = simReport.cycleReports{c};
        cycleIndex = cycleReport.cycleIndex;
        ops = cycleReport.operationReports;
        for k = 1:numel(ops)
            op = ops(k);
            family = string(op.operationFamily);
            if ~ismember(family, pairedFamilies)
                continue;
            end
            opId = string(op.operationGroupId);
            localMap = op.selectionLocalMap;
            [donorBed, receiverBed] = donorReceiverFromLocalMap(localMap);
            opRows = streamRows(streamRows.cycle_index == cycleIndex & ...
                streamRows.operation_group_id == opId & streamRows.component == "H2", :);
            donorDelta = sum(opRows.moles(opRows.stream_scope == "bed_inventory_delta" & ...
                opRows.global_bed == donorBed));
            receiverDelta = sum(opRows.moles(opRows.stream_scope == "bed_inventory_delta" & ...
                opRows.global_bed == receiverBed));
            internalOut = sumDirection(opRows, "internal_transfer", "out_of_donor");
            internalIn = sumDirection(opRows, "internal_transfer", "into_receiver");
            external = findBalanceRow(balanceRows, cycleIndex, "slot_external", opId, "H2");
            internal = findBalanceRow(balanceRows, cycleIndex, "slot_internal_transfer", opId, "H2");
            pressure = pressureAuditFields(op.runReport);
            tol = max(1e-12, 1e-6 * max(1, max(abs([donorDelta, receiverDelta, internalOut, internalIn]))));

            row = pairedAuditTemplate();
            row.cycle_index = cycleIndex;
            row.operation_group_id = opId;
            row.family = family;
            row.source_col = op.sourceCol;
            row.nominal_donor_bed = donorBed;
            row.nominal_receiver_bed = receiverBed;
            row.H2_internal_out_mol = internalOut;
            row.H2_internal_in_mol = internalIn;
            row.donor_bed_inventory_delta_H2_mol = donorDelta;
            row.receiver_bed_inventory_delta_H2_mol = receiverDelta;
            row.nominal_donor_inventory_change = signLabel(donorDelta, tol);
            row.nominal_receiver_inventory_change = signLabel(receiverDelta, tol);
            row.inventory_deltas_imply = directionImplication(donorDelta, receiverDelta, tol);
            row.contradicts_nominal_donor_receiver_names = ...
                donorDelta > tol && receiverDelta < -tol && internalOut > tol;
            row.slot_external_balance_pass = external.pass;
            row.slot_external_balance_available = external.available;
            row.slot_internal_transfer_balance_pass = internal.pass;
            row.slot_internal_transfer_balance_available = internal.available;
            row.pressure_diagnostics_available = pressure.available;
            row.pressure_diagnostic_note = pressure.note;
            row.donor_initial_feed_end_pressure_ratio = pressure.donorInitialFeed;
            row.donor_initial_product_end_pressure_ratio = pressure.donorInitialProduct;
            row.receiver_initial_feed_end_pressure_ratio = pressure.receiverInitialFeed;
            row.receiver_initial_product_end_pressure_ratio = pressure.receiverInitialProduct;
            row.donor_terminal_feed_end_pressure_ratio = pressure.donorTerminalFeed;
            row.donor_terminal_product_end_pressure_ratio = pressure.donorTerminalProduct;
            row.receiver_terminal_feed_end_pressure_ratio = pressure.receiverTerminalFeed;
            row.receiver_terminal_product_end_pressure_ratio = pressure.receiverTerminalProduct;
            auditRows(end+1, 1) = row; %#ok<AGROW>
        end
    end
    tbl = struct2table(auditRows);
end

function row = pairedAuditTemplate()
    row = struct( ...
        "cycle_index", NaN, ...
        "operation_group_id", "", ...
        "family", "", ...
        "source_col", NaN, ...
        "nominal_donor_bed", "", ...
        "nominal_receiver_bed", "", ...
        "H2_internal_out_mol", NaN, ...
        "H2_internal_in_mol", NaN, ...
        "donor_bed_inventory_delta_H2_mol", NaN, ...
        "receiver_bed_inventory_delta_H2_mol", NaN, ...
        "nominal_donor_inventory_change", "", ...
        "nominal_receiver_inventory_change", "", ...
        "inventory_deltas_imply", "", ...
        "contradicts_nominal_donor_receiver_names", false, ...
        "slot_external_balance_pass", false, ...
        "slot_external_balance_available", false, ...
        "slot_internal_transfer_balance_pass", false, ...
        "slot_internal_transfer_balance_available", false, ...
        "pressure_diagnostics_available", false, ...
        "pressure_diagnostic_note", "", ...
        "donor_initial_feed_end_pressure_ratio", NaN, ...
        "donor_initial_product_end_pressure_ratio", NaN, ...
        "receiver_initial_feed_end_pressure_ratio", NaN, ...
        "receiver_initial_product_end_pressure_ratio", NaN, ...
        "donor_terminal_feed_end_pressure_ratio", NaN, ...
        "donor_terminal_product_end_pressure_ratio", NaN, ...
        "receiver_terminal_feed_end_pressure_ratio", NaN, ...
        "receiver_terminal_product_end_pressure_ratio", NaN);
end

function stats = makeSummaryStats(simReport, cycleH2, cumulativeH2, stageScope, ...
        operationH2, adapterMagnitude, pairedAudit, failingBalanceRows)
    stats = struct();
    stats.balancePass = logical(simReport.balanceSummary.pass);
    stats.metricsPass = logical(simReport.metricsPass);
    stats.cssPass = logical(simReport.cssPass);
    stats.maxBalanceResidual = simReport.balanceSummary.maxAbsResidual;
    stats.nFailingBalanceRows = height(failingBalanceRows);
    stats.oldEqiiBalanceFailureReproduced = any(~simReport.ledger.balanceRows.pass & ...
        (simReport.ledger.balanceRows.stage_label == "EQII" | ...
        simReport.ledger.balanceRows.direct_transfer_family == "EQII"));
    stats.finalCumulativeRecovery = tableLastValue(cumulativeH2, "cumulative_recovery");
    stats.finalCumulativeWasteFraction = tableLastValue(cumulativeH2, "cumulative_waste_fraction");
    stats.finalCumulativeInventoryFraction = tableLastValue(cumulativeH2, "cumulative_inventory_fraction");
    stats.finalCumulativeResidual = tableLastValue(cumulativeH2, "cumulative_residual_H2_mol");
    stats.dominantProductFamily = dominantFamily(operationH2, "H2_external_product_mol");
    stats.dominantWasteFamily = dominantFamily(operationH2, "H2_external_waste_mol");
    stats.ADPP_BFProductToTotalProduct = stageRatio(stageScope, "ADPP_BF", ...
        "external_product", "H2", "moles");
    stats.ADPP_BFInternalToTotalInternalOut = stageRatio(stageScope, "ADPP_BF", ...
        "internal_transfer", "H2", "out_of_donor_moles");
    stats.PP_PUWasteToTotalWaste = stageRatio(stageScope, "PP_PU", ...
        "external_waste", "H2", "moles");
    stats.BDWasteToTotalWaste = stageRatio(stageScope, "BD", ...
        "external_waste", "H2", "moles");
    stats.maxAdapterExternalProductVsAdProduct = max(adapterMagnitude.external_product_fraction_of_native_AD_product, [], "omitnan");
    stats.maxAdapterInternalVsEqTransfer = max(adapterMagnitude.internal_out_fraction_of_native_EQ_transfer, [], "omitnan");
    stats.adapterMaterialityThreshold = 0.01;
    stats.adapterProductMateriality = materialityWord(stats.maxAdapterExternalProductVsAdProduct, stats.adapterMaterialityThreshold);
    stats.adapterInternalMateriality = materialityWord(stats.maxAdapterInternalVsEqTransfer, stats.adapterMaterialityThreshold);
    stats.nPairedInventoryContradictions = sum(pairedAudit.contradicts_nominal_donor_receiver_names);
    stats.nEqiiInventoryContradictions = sum(pairedAudit.family == "EQII" & ...
        pairedAudit.contradicts_nominal_donor_receiver_names);
    stats.nCycleRows = height(cycleH2);
end

function writeSummaryMarkdown(report, path)
    stats = report.summaryStats;
    cycleH2 = report.cycleH2Accounting;
    cumulativeH2 = report.cumulativeH2Accounting;
    adapter = report.adapterMagnitudeSummary;
    paired = report.pairedOperationDirectionAudit;

    finalCycle = height(cumulativeH2);
    if finalCycle > 0
        finalCum = cumulativeH2(finalCycle, :);
    else
        finalCum = table();
    end

    lines = strings(0, 1);
    lines(end+1) = "# Yang metric accounting ladder diagnostic";
    lines(end+1) = "";
    lines(end+1) = "## Run identity";
    lines(end+1) = sprintf("- Branch: `%s`", report.runIdentity.branch);
    lines(end+1) = sprintf("- Commit SHA: `%s`", report.runIdentity.commitSha);
    lines(end+1) = "- Git status:";
    lines(end+1) = "```text";
    statusLines = splitlines(report.runIdentity.gitStatusShort);
    lines = [lines(:); statusLines(:)]; %#ok<AGROW>
    lines(end+1) = "```";
    lines(end+1) = sprintf("- MATLAB version: `%s`", report.runIdentity.matlabVersion);
    lines(end+1) = sprintf("- Runtime: %.3f s", report.runtimeSec);
    lines(end+1) = sprintf("- Cycles used: %d", report.cyclesUsed);
    lines(end+1) = "- Exact baseline params: `NVols=2, NCols=2, NSteps=1, NTimePoints=21, CycleTimeSec=2.4, FinalizeForRuntime=true`";
    lines(end+1) = "- Exact baseline controls: `cycleTimeSec=2.4, Cv_directTransfer=1e-6, ADPP_BF_internalSplitFraction=1/3, balanceAbsTol=1e-8, balanceRelTol=1e-6`";
    lines(end+1) = sprintf("- `params.valScaleFac`: %.16g", report.paramsValScaleFac);
    lines(end+1) = sprintf("- Raw native valve coefficient: %.16g", report.rawNativeValveCoefficient);
    lines(end+1) = sprintf("- Resolved native valve coefficient: %.16g", report.resolvedNativeValveCoefficient);
    lines(end+1) = sprintf("- `Cv_directTransfer`: %.16g", report.Cv_directTransfer);
    if strlength(report.fallbackReason) > 0
        lines(end+1) = sprintf("- Fallback note: %s", report.fallbackReason);
    end
    lines(end+1) = "";

    lines(end+1) = "## Pass/fail headline";
    lines(end+1) = sprintf("- Run completed: %s", yesNo(report.runCompleted));
    lines(end+1) = sprintf("- Balance pass: %s", yesNo(stats.balancePass));
    lines(end+1) = sprintf("- Metrics pass: %s", yesNo(stats.metricsPass));
    lines(end+1) = sprintf("- CSS pass: %s. CSS is not meaningful after only %d cycle(s); this diagnostic does not use CSS as evidence of convergence.", ...
        yesNo(stats.cssPass), report.cyclesUsed);
    lines(end+1) = sprintf("- Max balance residual: %.6g mol", stats.maxBalanceResidual);
    lines(end+1) = sprintf("- Failing balance rows: %d", stats.nFailingBalanceRows);
    lines(end+1) = sprintf("- Old EQII balance failure reproduced: %s", ...
        yesNo(stats.oldEqiiBalanceFailureReproduced));
    lines(end+1) = "";

    lines(end+1) = "## H2 accounting conclusion";
    if ~isempty(finalCum)
        lines(end+1) = sprintf("- Reported recovery is `external_product_H2 / external_feed_H2`. Through cycle %d, cumulative recovery is %.6g.", ...
            finalCum.through_cycle_index, finalCum.cumulative_recovery);
        lines(end+1) = sprintf("- The cumulative H2 fractions are waste %.6g and bed inventory delta %.6g, with residual %.6g mol.", ...
            finalCum.cumulative_waste_fraction, finalCum.cumulative_inventory_fraction, ...
            finalCum.cumulative_residual_H2_mol);
    end
    lines(end+1) = "- The balance-predicted recovery column uses `(feed - waste - bed_delta) / feed`, so inventory release or accumulation is visible without calling a closed ledger a metric failure.";
    lines(end+1) = sprintf("- The apparent recovery behavior is explainable from the ledger: %s.", ...
        explainAccounting(stats));
    lines(end+1) = "";

    lines(end+1) = "## Product/waste source conclusion";
    lines(end+1) = sprintf("- Dominant external product family: `%s`.", stats.dominantProductFamily);
    lines(end+1) = sprintf("- Dominant external waste family: `%s`.", stats.dominantWasteFamily);
    lines(end+1) = sprintf("- ADPP_BF external product H2 / total external product H2: %.6g.", ...
        stats.ADPP_BFProductToTotalProduct);
    lines(end+1) = sprintf("- PP_PU waste H2 / total external waste H2: %.6g; BD waste H2 / total external waste H2: %.6g.", ...
        stats.PP_PUWasteToTotalWaste, stats.BDWasteToTotalWaste);
    lines(end+1) = "";

    lines(end+1) = "## Adapter magnitude conclusion";
    lines(end+1) = sprintf("- ADPP_BF internal transfer H2 / total internal-transfer-out H2: %.6g.", ...
        stats.ADPP_BFInternalToTotalInternalOut);
    lines(end+1) = sprintf("- Max adapter external product relative to same-cycle native AD product: %.6g, classified as %s at a %.3g diagnostic threshold.", ...
        stats.maxAdapterExternalProductVsAdProduct, stats.adapterProductMateriality, ...
        stats.adapterMaterialityThreshold);
    lines(end+1) = sprintf("- Max adapter internal transfer relative to same-cycle native EQ transfer: %.6g, classified as %s at the same diagnostic threshold.", ...
        stats.maxAdapterInternalVsEqTransfer, stats.adapterInternalMateriality);
    if height(adapter) > 0
        lines(end+1) = sprintf("- Adapter conservation residual max across adapter rows: %.6g.", ...
            max(adapter.adapter_conservation_residual_max, [], "omitnan"));
    end
    if string(stats.adapterProductMateriality) == "negligible" && ...
            string(stats.adapterInternalMateriality) == "negligible"
        lines(end+1) = "- The adapters are small against native AD/native EQ flows in this baseline, so this report does not recommend a split sweep.";
    else
        lines(end+1) = "- At least one adapter contribution is material against the native comparison basis in this baseline.";
    end
    lines(end+1) = "";

    lines(end+1) = "## Paired-operation direction conclusion";
    if height(paired) == 0
        lines(end+1) = "- No paired-operation rows were available.";
    else
        lines(end+1) = sprintf("- Inventory-delta donor/receiver contradictions flagged: %d total; EQII: %d.", ...
            stats.nPairedInventoryContradictions, stats.nEqiiInventoryContradictions);
        lines(end+1) = sprintf("- Slot/cycle mass balance remains the governing check here: balance pass is %s.", ...
            yesNo(stats.balancePass));
        lines(end+1) = "- Native EQ pressure diagnostics are recorded as `not_available` when the operation report does not expose clean initial/terminal pressure summaries.";
    end
    lines(end+1) = "";

    lines(end+1) = "## Recommended next smallest task";
    lines(end+1) = "- stop diagnostics and proceed to parameter/performance calibration";
    lines(end+1) = "";

    lines(end+1) = "## Artifacts";
    lines(end+1) = "- `cycle_h2_accounting.csv`";
    lines(end+1) = "- `cumulative_h2_accounting.csv`";
    lines(end+1) = "- `stage_scope_decomposition.csv`";
    lines(end+1) = "- `operation_h2_decomposition.csv`";
    lines(end+1) = "- `adapter_magnitude_summary.csv`";
    lines(end+1) = "- `paired_operation_direction_audit.csv`";
    lines(end+1) = "- `failing_balance_rows.csv`";
    lines(end+1) = "- `metric_accounting_ladder_report.mat`";

    writelines(lines, path);
end

function total = sumLedgerRows(rows, cycleIndex, component, streamScope, stageLabel, directTransferFamily, direction)
    if height(rows) == 0
        total = 0;
        return;
    end
    mask = true(height(rows), 1);
    if ~isempty(cycleIndex) && isfinite(cycleIndex)
        mask = mask & rows.cycle_index == cycleIndex;
    end
    if strlength(string(component)) > 0
        mask = mask & rows.component == string(component);
    end
    if strlength(string(streamScope)) > 0
        mask = mask & rows.stream_scope == string(streamScope);
    end
    if strlength(string(stageLabel)) > 0
        mask = mask & rows.stage_label == string(stageLabel);
    end
    if strlength(string(directTransferFamily)) > 0
        mask = mask & rows.direct_transfer_family == string(directTransferFamily);
    end
    if strlength(string(direction)) > 0
        mask = mask & rows.stream_direction == string(direction);
    end
    total = sum(rows.moles(mask));
end

function total = sumScope(rows, scope)
    if height(rows) == 0
        total = 0;
    else
        total = sum(rows.moles(rows.stream_scope == string(scope)));
    end
end

function total = sumDirection(rows, scope, direction)
    if height(rows) == 0
        total = 0;
    else
        total = sum(rows.moles(rows.stream_scope == string(scope) & ...
            rows.stream_direction == string(direction)));
    end
end

function value = metricValue(simReport, cycleIndex, metricName, component)
    value = NaN;
    metricRows = simReport.metrics.rows;
    mask = metricRows.cycle_index == cycleIndex & ...
        metricRows.metric_name == string(metricName) & ...
        metricRows.component == string(component);
    if any(mask)
        value = metricRows.value(find(mask, 1));
    end
end

function row = findBalanceRow(balanceRows, cycleIndex, balanceScope, operationGroupId, component)
    row = struct("available", false, "pass", false, ...
        "residual_moles", NaN, "tolerance_moles", NaN);
    mask = balanceRows.cycle_index == cycleIndex & ...
        balanceRows.balance_scope == string(balanceScope) & ...
        balanceRows.component == string(component);
    if strlength(string(operationGroupId)) > 0
        mask = mask & balanceRows.operation_group_id == string(operationGroupId);
    end
    if any(mask)
        idx = find(mask, 1);
        row.available = true;
        row.pass = logical(balanceRows.pass(idx));
        row.residual_moles = balanceRows.residual_moles(idx);
        row.tolerance_moles = balanceRows.tolerance_moles(idx);
    end
end

function value = safeRatio(numerator, denominator)
    if isempty(denominator) || ~isfinite(denominator) || abs(denominator) <= eps
        value = NaN;
    else
        value = numerator ./ denominator;
    end
end

function threshold = tinyDenominatorThreshold(varargin)
    values = cell2mat(varargin);
    scale = max(1, max(abs(values(isfinite(values)))));
    threshold = max(1e-12, 1e-10 * scale);
end

function note = denominatorNote(isSensitive)
    if isSensitive
        note = "denominator-sensitive: feed H2 is tiny";
    else
        note = "";
    end
end

function maxResidual = maxConservationResidual(report)
    values = [];
    if isstruct(report) && isfield(report, "conservation") && isstruct(report.conservation)
        cons = report.conservation;
        fields = ["donorResidualByComponent", "receiverResidualByComponent", ...
            "pairResidualByComponent", "internalTransferMismatchByComponent"];
        for i = 1:numel(fields)
            name = char(fields(i));
            if isfield(cons, name) && isnumeric(cons.(name))
                values = [values; cons.(name)(:)]; %#ok<AGROW>
            end
        end
    end
    values = values(isfinite(values));
    if isempty(values)
        maxResidual = NaN;
    else
        maxResidual = max(abs(values));
    end
end

function value = effectiveSplitH2(report)
    value = NaN;
    if isstruct(report) && isfield(report, "effectiveSplit") && ...
            isstruct(report.effectiveSplit)
        split = report.effectiveSplit;
        if isfield(split, "H2") && isnumeric(split.H2)
            value = split.H2;
        elseif isfield(split, "byComponent") && isnumeric(split.byComponent) && ...
                ~isempty(split.byComponent)
            value = split.byComponent(1);
        elseif isfield(split, "total") && isnumeric(split.total)
            value = split.total;
        end
    end
end

function value = getEffectiveCv(report)
    value = NaN;
    if isstruct(report) && isfield(report, "effectiveCv") && ...
            isstruct(report.effectiveCv) && isfield(report.effectiveCv, "Cv_directTransfer")
        value = report.effectiveCv.Cv_directTransfer;
    elseif isstruct(report) && isfield(report, "Cv_directTransfer")
        value = report.Cv_directTransfer;
    end
end

function value = getNumericReportField(report, fieldName, defaultValue)
    value = defaultValue;
    name = char(fieldName);
    if isstruct(report) && isfield(report, name) && isnumeric(report.(name)) && ...
            isscalar(report.(name))
        value = report.(name);
    end
end

function [donorBed, receiverBed] = donorReceiverFromLocalMap(localMap)
    donorBed = "";
    receiverBed = "";
    if height(localMap) == 0
        return;
    end
    donorMask = localMap.local_role == "donor";
    receiverMask = localMap.local_role == "receiver";
    if any(donorMask)
        donorBed = string(localMap.global_bed(find(donorMask, 1)));
    else
        donorBed = string(localMap.global_bed(1));
    end
    if any(receiverMask)
        receiverBed = string(localMap.global_bed(find(receiverMask, 1)));
    elseif height(localMap) >= 2
        receiverBed = string(localMap.global_bed(2));
    end
end

function label = signLabel(value, tol)
    if value > tol
        label = "gained_H2";
    elseif value < -tol
        label = "lost_H2";
    else
        label = "approximately_unchanged";
    end
end

function label = directionImplication(donorDelta, receiverDelta, tol)
    donor = signLabel(donorDelta, tol);
    receiver = signLabel(receiverDelta, tol);
    if donor == "lost_H2" && receiver == "gained_H2"
        label = "inventory_changes_match_nominal_donor_to_receiver";
    elseif donor == "gained_H2" && receiver == "lost_H2"
        label = "inventory_changes_oppose_nominal_donor_to_receiver";
    else
        label = "inventory_changes_do_not_cleanly_identify_direction";
    end
end

function pressure = pressureAuditFields(runReport)
    pressure = struct( ...
        "available", false, ...
        "note", "not_available", ...
        "donorInitialFeed", NaN, ...
        "donorInitialProduct", NaN, ...
        "receiverInitialFeed", NaN, ...
        "receiverInitialProduct", NaN, ...
        "donorTerminalFeed", NaN, ...
        "donorTerminalProduct", NaN, ...
        "receiverTerminalFeed", NaN, ...
        "receiverTerminalProduct", NaN);
    if ~isstruct(runReport) || ~isfield(runReport, "pressureDiagnostics") || ...
            ~isstruct(runReport.pressureDiagnostics)
        return;
    end
    pd = runReport.pressureDiagnostics;
    pressure.available = true;
    pressure.note = "available_from_operation_report";
    pressure.donorInitialFeed = nestedNumeric(pd, ["initial", "donor", "feedEndPressureRatio"]);
    pressure.donorInitialProduct = nestedNumeric(pd, ["initial", "donor", "productEndPressureRatio"]);
    pressure.receiverInitialFeed = nestedNumeric(pd, ["initial", "receiver", "feedEndPressureRatio"]);
    pressure.receiverInitialProduct = nestedNumeric(pd, ["initial", "receiver", "productEndPressureRatio"]);
    pressure.donorTerminalFeed = nestedNumeric(pd, ["terminal", "donor", "feedEndPressureRatio"]);
    pressure.donorTerminalProduct = nestedNumeric(pd, ["terminal", "donor", "productEndPressureRatio"]);
    pressure.receiverTerminalFeed = nestedNumeric(pd, ["terminal", "receiver", "feedEndPressureRatio"]);
    pressure.receiverTerminalProduct = nestedNumeric(pd, ["terminal", "receiver", "productEndPressureRatio"]);
end

function value = nestedNumeric(s, names)
    value = NaN;
    current = s;
    for i = 1:numel(names)
        name = char(names(i));
        if ~isstruct(current) || ~isfield(current, name)
            return;
        end
        current = current.(name);
    end
    if isnumeric(current) && isscalar(current)
        value = current;
    end
end

function value = tableLastValue(tbl, variableName)
    if height(tbl) == 0
        value = NaN;
    else
        value = tbl.(char(variableName))(end);
    end
end

function family = dominantFamily(operationTbl, valueName)
    if height(operationTbl) == 0
        family = "none";
        return;
    end
    families = unique(operationTbl.operation_family);
    totals = zeros(numel(families), 1);
    values = operationTbl.(char(valueName));
    for i = 1:numel(families)
        totals(i) = sum(values(operationTbl.operation_family == families(i)), "omitnan");
    end
    [maxValue, idx] = max(totals);
    if isempty(idx) || maxValue <= 0
        family = "none";
    else
        family = families(idx);
    end
end

function ratio = stageRatio(stageScope, family, scope, component, valueName)
    if height(stageScope) == 0
        ratio = NaN;
        return;
    end
    value = stageScope.(char(valueName));
    numMask = stageScope.stage_label == string(family) & ...
        stageScope.stream_scope == string(scope) & ...
        stageScope.component == string(component);
    denMask = stageScope.stream_scope == string(scope) & ...
        stageScope.component == string(component);
    numerator = sum(value(numMask), "omitnan");
    denominator = sum(value(denMask), "omitnan");
    ratio = safeRatio(numerator, denominator);
end

function word = materialityWord(value, threshold)
    if ~isfinite(value)
        word = "not_available";
    elseif value < threshold
        word = "negligible";
    else
        word = "material";
    end
end

function text = explainAccounting(stats)
    if stats.nFailingBalanceRows > 0
        text = "not fully, because at least one ledger balance row failed";
    elseif abs(stats.finalCumulativeInventoryFraction) > stats.finalCumulativeWasteFraction
        text = "inventory delta is larger than waste on the cumulative H2 feed basis";
    else
        text = "waste is larger than inventory delta on the cumulative H2 feed basis";
    end
end

function text = yesNo(value)
    if logical(value)
        text = "yes";
    else
        text = "no";
    end
end
