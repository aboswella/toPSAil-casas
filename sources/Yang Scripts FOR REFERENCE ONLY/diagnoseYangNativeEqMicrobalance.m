function report = diagnoseYangNativeEqMicrobalance()
%DIAGNOSEYANGNATIVEEQMICROBALANCE Isolated native EQI/EQII balance audit.
%
% This diagnostic runs only two native equalisation temporary cases using a
% synthetic four-bed state container. It does not run a full four-bed cycle.

    repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    addpath(genpath(repoRoot));

    tStart = tic;
    outputDir = fullfile(repoRoot, 'validation', 'reports', ...
        'yang_diagnostics', 'native_eq_microbalance');
    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    gitInfo = collectGitInfo(repoRoot);
    if gitInfo.branch ~= "codex/yang"
        error('FI8:WrongBranch', ...
            'Native EQ micro-balance diagnostic must run on codex/yang, not %s.', ...
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
    durations = getYangNormalizedSlotDurations(2.4);
    plan = buildYangFourBedOperationPlan(manifest, pairMap, durations);
    controls = normalizeYangFourBedControls(struct( ...
        'cycleTimeSec', 2.4, ...
        'Cv_directTransfer', 1e-6, ...
        'ADPP_BF_internalSplitFraction', 1/3, ...
        'balanceAbsTol', 1e-8, ...
        'balanceRelTol', 1e-6), params);

    container = makeSyntheticContainer(params, manifest, pairMap);

    groupSpecs = [
        struct('label', "EQI", 'preferredId', "EQI-A-to-C", 'family', "EQI", 'fallbackSourceCol', NaN)
        struct('label', "EQII", 'preferredId', "EQII-B-to-A", 'family', "EQII", 'fallbackSourceCol', 7)
    ];

    groupReports = repmat(emptyGroupReport(), numel(groupSpecs), 1);
    residualTables = cell(numel(groupSpecs), 1);
    for i = 1:numel(groupSpecs)
        groupReports(i) = diagnoseGroup(groupSpecs(i), plan, pairMap, ...
            container, params, controls, manifest, outputDir);
        residualTables{i} = groupReports(i).residualRows;
    end

    residualRows = vertcat(residualTables{:});
    writetable(residualRows, fullfile(outputDir, 'native_eq_microbalance_residuals.csv'));

    report = struct();
    report.version = "FI8-Yang2009-native-EQ-microbalance-diagnostic-v1";
    report.createdAt = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
    report.runtimeSeconds = toc(tStart);
    report.matlabVersion = string(version);
    report.git = gitInfo;
    report.params = struct( ...
        'valScaleFac', params.valScaleFac, ...
        'nativeValveCoefficient', params.yangRuntimeDefaults.nativeValveCoefficient, ...
        'resolvedDefaultNativeValve', params.yangRuntimeDefaults.nativeValveCoefficient * params.valScaleFac, ...
        'nScaleFac', params.nScaleFac);
    report.controls = controls;
    report.groupReports = groupReports;
    report.residualRows = residualRows;
    report.outputDir = string(outputDir);

    save(fullfile(outputDir, 'native_eq_microbalance_report.mat'), 'report');
    writeSummary(report, outputDir);
    printConsoleSummary(report);
end

function groupReport = diagnoseGroup(spec, plan, pairMap, container, params, controls, manifest, outputDir)
    group = selectOperationGroup(plan, spec);
    pairRows = pairMap.transferPairs(pairMap.transferPairs.pair_id == string(group.pairId), :);
    if height(pairRows) ~= 1
        error('FI8:DiagnosticPairNotFound', ...
            'Expected exactly one pair-map row for %s.', char(string(group.pairId)));
    end

    selection = selectYangFourBedPairStates(container, pairRows);
    tempCase = makeYangTemporaryPairedCase(selection, ...
        'DurationSeconds', group.durationSec, ...
        'RunnerMode', "native", ...
        'CaseNote', "FI-8 isolated native EQ micro-balance diagnostic");

    ticGroup = tic;
    [terminalLocalStates, nativeReport] = runYangTemporaryCase(tempCase, ...
        'Runner', "native", ...
        'TemplateParams', params, ...
        'Controls', controls, ...
        'DurationSeconds', group.durationSec);
    runtimeSeconds = toc(ticGroup);

    [nativeRows, nativeExtractionReport] = extractYangNativeLedgerRows( ...
        nativeReport, group, params, controls, 'CycleIndex', 1);
    initialInventory = computeInventoriesFromStates(params, selection.localMap, selection.localStates);
    terminalInventory = computeInventoriesFromStates(params, selection.localMap, terminalLocalStates);
    inventoryRows = appendYangBedInventoryDeltaRows(group, initialInventory, ...
        terminalInventory, controls, 'CycleIndex', 1);

    ledger = makeYangFourBedLedger(controls.componentNames, ...
        'Manifest', manifest, ...
        'PairMap', pairMap, ...
        'LedgerNote', "native EQ microbalance diagnostic");
    ledger.streamRows = [nativeRows; inventoryRows];
    compatibility = checkYangLedgerPhysicalMoleCompatibility(ledger.streamRows, ...
        unique(ledger.streamRows.stream_scope));
    if ~compatibility.pass
        error('FI8:BasisIncompatibility', ...
            'Ledger rows for %s are not physical-mole compatible: %s.', ...
            char(string(group.operationGroupId)), char(compatibility.reason));
    end

    [balanceRows, balanceSummary] = computeYangLedgerBalances(ledger, ...
        'AbsTol', controls.balanceAbsTol, ...
        'RelTol', controls.balanceRelTol);
    residualRows = computeLocalResidualRows(group, nativeRows, inventoryRows, ...
        balanceRows, controls);

    label = char(string(spec.label));
    writetable(ledger.streamRows, fullfile(outputDir, sprintf('%s_stream_rows.csv', label)));
    writetable(balanceRows, fullfile(outputDir, sprintf('%s_balance_rows.csv', label)));
    writeCounterTailReport(fullfile(outputDir, sprintf('%s_native_counter_tail_report.txt', label)), ...
        group, nativeReport, nativeExtractionReport);

    groupReport = emptyGroupReport();
    groupReport.label = string(spec.label);
    groupReport.operationGroupId = string(group.operationGroupId);
    groupReport.sourceCol = group.sourceCol;
    groupReport.durationSec = group.durationSec;
    groupReport.runtimeSeconds = runtimeSeconds;
    groupReport.route = string(group.route);
    groupReport.family = string(group.operationFamily);
    groupReport.pairId = string(group.pairId);
    groupReport.donorBed = string(group.donorBed);
    groupReport.receiverBed = string(group.receiverBed);
    groupReport.resolvedNativeValve = ...
        nativeReport.localRunPreparation.valveReport.defaultDimensionlessValve;
    groupReport.valFeedColNorm = nativeReport.localRunPreparation.valveReport.valFeedColNorm;
    groupReport.valProdColNorm = nativeReport.localRunPreparation.valveReport.valProdColNorm;
    groupReport.nativeExtractionReport = nativeExtractionReport;
    groupReport.balanceSummary = balanceSummary;
    groupReport.balanceRows = balanceRows;
    groupReport.streamRows = ledger.streamRows;
    groupReport.residualRows = residualRows;
    groupReport.interpretation = interpretGroup(residualRows, controls, string(spec.label));
end

function container = makeSyntheticContainer(params, manifest, pairMap)
    beds = ["A", "B", "C", "D"];
    states = struct();
    for i = 1:numel(beds)
        one = [0.76 - 0.01*i; 0.24 + 0.01*i; 0.01; 0.02; 1.0; 1.0];
        states.(char("state_" + beds(i))) = extractYangPhysicalBedState(params, ...
            repmat(one, params.nVols, 1), ...
            'Metadata', struct( ...
                'source', "native EQ microbalance diagnostic synthetic state", ...
                'bed', beds(i)));
    end
    container = makeYangFourBedStateContainer(states, ...
        'Manifest', manifest, ...
        'PairMap', pairMap, ...
        'InitializationPolicy', "native EQ microbalance diagnostic", ...
        'SourceNote', "synthetic physical states");
end

function group = selectOperationGroup(plan, spec)
    ids = string({plan.operationGroups.operationGroupId});
    idx = find(ids == string(spec.preferredId), 1);
    if isempty(idx) && ~isnan(spec.fallbackSourceCol)
        families = string({plan.operationGroups.operationFamily});
        sourceCols = [plan.operationGroups.sourceCol];
        idx = find(families == string(spec.family) & sourceCols == spec.fallbackSourceCol, 1);
    end
    if isempty(idx)
        families = string({plan.operationGroups.operationFamily});
        idx = find(families == string(spec.family), 1);
    end
    if isempty(idx)
        error('FI8:DiagnosticGroupNotFound', ...
            'Could not find operation group for %s.', char(string(spec.family)));
    end
    group = plan.operationGroups(idx);
end

function inventories = computeInventoriesFromStates(params, localMap, localStates)
    inventories = struct();
    for j = 1:height(localMap)
        bed = string(localMap.global_bed(j));
        field = matlab.lang.makeValidName("bed_" + bed);
        inventory = computeYangBedComponentInventory(params, localStates{j});
        if ~isfield(inventory, 'usedPhysicalMoles') || ~inventory.usedPhysicalMoles
            error('FI8:BasisIncompatibility', ...
                'Inventory for bed %s is not available in physical moles.', char(bed));
        end
        inventories.(field) = inventory;
    end
end

function residualRows = computeLocalResidualRows(group, nativeRows, inventoryRows, balanceRows, controls)
    componentNames = string(controls.componentNames(:));
    nComp = numel(componentNames);

    operationGroupId = strings(nComp, 1);
    sourceCol = zeros(nComp, 1);
    family = strings(nComp, 1);
    component = strings(nComp, 1);
    donorInventoryDelta = zeros(nComp, 1);
    receiverInventoryDelta = zeros(nComp, 1);
    internalOutOfDonor = zeros(nComp, 1);
    internalIntoReceiver = zeros(nComp, 1);
    donorResidual = zeros(nComp, 1);
    receiverResidual = zeros(nComp, 1);
    pairInventoryDelta = zeros(nComp, 1);
    internalMismatch = zeros(nComp, 1);
    slotExternalResidual = zeros(nComp, 1);
    slotInternalResidual = zeros(nComp, 1);
    donorTolerance = zeros(nComp, 1);
    receiverTolerance = zeros(nComp, 1);
    pairTolerance = zeros(nComp, 1);
    internalTolerance = zeros(nComp, 1);
    donorPass = false(nComp, 1);
    receiverPass = false(nComp, 1);
    pairPass = false(nComp, 1);
    internalPass = false(nComp, 1);
    allPass = false(nComp, 1);

    for c = 1:nComp
        comp = componentNames(c);
        donorDelta = sumRows(inventoryRows, comp, "bed_inventory_delta", "delta", "donor");
        receiverDelta = sumRows(inventoryRows, comp, "bed_inventory_delta", "delta", "receiver");
        out = sumRows(nativeRows, comp, "internal_transfer", "out_of_donor", "donor");
        into = sumRows(nativeRows, comp, "internal_transfer", "into_receiver", "receiver");

        operationGroupId(c) = string(group.operationGroupId);
        sourceCol(c) = group.sourceCol;
        family(c) = string(group.operationFamily);
        component(c) = comp;
        donorInventoryDelta(c) = donorDelta;
        receiverInventoryDelta(c) = receiverDelta;
        internalOutOfDonor(c) = out;
        internalIntoReceiver(c) = into;
        donorResidual(c) = donorDelta + out;
        receiverResidual(c) = receiverDelta - into;
        pairInventoryDelta(c) = donorDelta + receiverDelta;
        internalMismatch(c) = into - out;

        slotExternalResidual(c) = balanceResidual(balanceRows, comp, "slot_external");
        slotInternalResidual(c) = balanceResidual(balanceRows, comp, "slot_internal_transfer");

        donorTolerance(c) = residualTolerance([donorDelta, out], controls);
        receiverTolerance(c) = residualTolerance([receiverDelta, into], controls);
        pairTolerance(c) = residualTolerance([donorDelta, receiverDelta], controls);
        internalTolerance(c) = residualTolerance([out, into], controls);
        donorPass(c) = abs(donorResidual(c)) <= donorTolerance(c);
        receiverPass(c) = abs(receiverResidual(c)) <= receiverTolerance(c);
        pairPass(c) = abs(pairInventoryDelta(c)) <= pairTolerance(c);
        internalPass(c) = abs(internalMismatch(c)) <= internalTolerance(c);
        allPass(c) = donorPass(c) && receiverPass(c) && pairPass(c) && internalPass(c);
    end

    residualRows = table(operationGroupId, sourceCol, family, component, ...
        donorInventoryDelta, receiverInventoryDelta, internalOutOfDonor, ...
        internalIntoReceiver, donorResidual, receiverResidual, pairInventoryDelta, ...
        internalMismatch, slotExternalResidual, slotInternalResidual, donorTolerance, ...
        receiverTolerance, pairTolerance, internalTolerance, donorPass, ...
        receiverPass, pairPass, internalPass, allPass);
end

function value = sumRows(rows, component, scope, direction, localRole)
    mask = rows.component == component & ...
        rows.stream_scope == string(scope) & ...
        rows.stream_direction == string(direction) & ...
        rows.local_role == string(localRole);
    subset = rows(mask, :);
    assertPhysicalMoles(subset);
    value = sum(subset.moles);
end

function residual = balanceResidual(balanceRows, component, balanceScope)
    mask = balanceRows.component == component & ...
        balanceRows.balance_scope == string(balanceScope);
    if ~any(mask)
        residual = NaN;
    else
        residual = sum(balanceRows.residual_moles(mask));
    end
end

function assertPhysicalMoles(rows)
    if height(rows) == 0
        return;
    end
    if any(rows.units ~= "mol")
        error('FI8:BasisIncompatibility', ...
            'Residual calculation encountered rows not expressed in mol.');
    end
    compatibility = checkYangLedgerPhysicalMoleCompatibility(rows, unique(rows.stream_scope));
    if ~compatibility.pass
        error('FI8:BasisIncompatibility', '%s', char(compatibility.reason));
    end
end

function tol = residualTolerance(values, controls)
    scale = max(abs(values));
    if isempty(scale) || ~isfinite(scale)
        scale = 0;
    end
    tol = controls.balanceAbsTol + controls.balanceRelTol * scale;
end

function interpretation = interpretGroup(residualRows, controls, label)
    maxInternalMismatch = max(abs(residualRows.internalMismatch));
    maxPairDelta = max(abs(residualRows.pairInventoryDelta));
    maxDonor = max(abs(residualRows.donorResidual));
    maxReceiver = max(abs(residualRows.receiverResidual));
    maxExternal = max(abs(residualRows.slotExternalResidual), [], 'omitnan');
    maxInternalTol = max(residualRows.internalTolerance);
    maxPairTol = max(residualRows.pairTolerance);
    if isempty(maxExternal) || ~isfinite(maxExternal)
        maxExternal = 0;
    end

    if all(residualRows.allPass)
        if label == "EQII"
            interpretation = "Case A: EQII micro-balance passes; isolated native EQII local run and extraction are probably not intrinsically broken under clean synthetic state.";
        else
            interpretation = "Representative EQI micro-balance passes under clean synthetic state.";
        end
    elseif maxInternalMismatch > maxInternalTol
        side = "both donor and receiver";
        if maxDonor > maxReceiver
            side = "donor side";
        elseif maxReceiver > maxDonor
            side = "receiver side";
        end
        interpretation = "Case B: EQ internal mismatch fails and local residuals point most strongly to " + side + "; inspect native counter tails and local-role interpretation.";
    elseif maxInternalMismatch <= maxInternalTol && maxPairDelta > maxPairTol
        interpretation = "Case C: internal transfer rows cancel but pair inventory delta fails; inspect physical inventory reconstruction and state extraction/writeback.";
    elseif (maxDonor > controls.balanceAbsTol || maxReceiver > controls.balanceAbsTol) && ...
            maxInternalMismatch <= maxInternalTol && maxPairDelta <= maxPairTol
        interpretation = "Internal cancellation and pair inventory delta pass, but donor/receiver residuals fail with opposite signs; this points to local role or counter-direction interpretation rather than a gross pair mass leak.";
    elseif maxExternal > controls.balanceAbsTol && maxInternalMismatch > controls.balanceAbsTol
        interpretation = "Case D: internal and external residuals both fail at non-negligible scale; native counters and physical inventory deltas are not representing the same movement.";
    else
        interpretation = "Mixed residual pattern; inspect residual CSV and counter-tail report before assigning cause.";
    end
end

function writeCounterTailReport(path, group, nativeReport, nativeExtractionReport)
    fid = fopen(path, 'w');
    if fid < 0
        error('FI8:CannotWriteDiagnosticReport', ...
            'Could not open %s for writing.', path);
    end
    cleaner = onCleanup(@() fclose(fid));

    fprintf(fid, 'operationGroupId: %s\n', string(group.operationGroupId));
    fprintf(fid, 'sourceCol: %g\n', group.sourceCol);
    fprintf(fid, 'family: %s\n', string(group.operationFamily));
    fprintf(fid, 'durationSec: %.16g\n\n', group.durationSec);
    fprintf(fid, 'localRunPreparation.valveReport:\n%s\n', ...
        evalc('disp(nativeReport.localRunPreparation.valveReport)'));
    fprintf(fid, 'valFeedColNorm: %s\n', ...
        numericList(nativeReport.localRunPreparation.valveReport.valFeedColNorm));
    fprintf(fid, 'valProdColNorm: %s\n\n', ...
        numericList(nativeReport.localRunPreparation.valveReport.valProdColNorm));
    fprintf(fid, 'counterTailLayout: %s\n', string(nativeReport.counterTailLayout));
    fprintf(fid, 'counterTailBasis: %s\n\n', string(nativeReport.counterTailBasis));
    fprintf(fid, 'counterTailDeltas by local bed:\n');
    for i = 1:numel(nativeReport.counterTailDeltas)
        fprintf(fid, '- local %d: %s\n', i, numericList(nativeReport.counterTailDeltas{i}));
    end
    fprintf(fid, '\nconvertedMolesByRow: %s\n\n', ...
        numericList(nativeExtractionReport.convertedMolesByRow));
    fprintf(fid, 'counterTailReport:\n%s\n', evalc('disp(nativeReport.counterTailReport)'));
    fprintf(fid, 'nativeExtractionReport:\n%s\n', evalc('disp(nativeExtractionReport)'));
end

function writeSummary(report, outputDir)
    path = fullfile(outputDir, 'summary.md');
    fid = fopen(path, 'w');
    if fid < 0
        error('FI8:CannotWriteDiagnosticReport', ...
            'Could not open %s for writing.', path);
    end
    cleaner = onCleanup(@() fclose(fid));

    fprintf(fid, '# Native EQ micro-balance diagnostic\n\n');
    fprintf(fid, '- Created: %s\n', report.createdAt);
    fprintf(fid, '- MATLAB version: %s\n', report.matlabVersion);
    fprintf(fid, '- Runtime seconds: %.6g\n', report.runtimeSeconds);
    fprintf(fid, '- Branch: `%s`\n', report.git.branch);
    fprintf(fid, '- Commit SHA: `%s`\n', report.git.commit);
    fprintf(fid, '- Git status short:\n\n```text\n%s\n```\n\n', emptyText(report.git.statusShort));
    fprintf(fid, '- Recent commits:\n\n```text\n%s\n```\n\n', emptyText(report.git.logOneline5));
    fprintf(fid, '- `params.valScaleFac`: %.16g\n', report.params.valScaleFac);
    fprintf(fid, '- Raw `NativeValveCoefficient`: %.16g\n', report.params.nativeValveCoefficient);
    fprintf(fid, '- Resolved default native valve: %.16g\n', report.params.resolvedDefaultNativeValve);
    fprintf(fid, '- `params.nScaleFac`: %.16g\n\n', report.params.nScaleFac);

    for i = 1:numel(report.groupReports)
        gr = report.groupReports(i);
        rr = gr.residualRows;
        fprintf(fid, '## %s\n\n', gr.label);
        fprintf(fid, '- Operation group ID: `%s`\n', gr.operationGroupId);
        fprintf(fid, '- Pair ID: `%s`\n', gr.pairId);
        fprintf(fid, '- Source column: %g\n', gr.sourceCol);
        fprintf(fid, '- Duration seconds: %.16g\n', gr.durationSec);
        fprintf(fid, '- Runtime seconds: %.6g\n', gr.runtimeSeconds);
        fprintf(fid, '- Resolved native valve from prep report: %.16g\n', gr.resolvedNativeValve);
        fprintf(fid, '- `valFeedColNorm`: %s\n', numericList(gr.valFeedColNorm));
        fprintf(fid, '- `valProdColNorm`: %s\n', numericList(gr.valProdColNorm));
        fprintf(fid, '- Max balance residual: %.16g\n', gr.balanceSummary.maxAbsResidual);
        fprintf(fid, '- Balance pass: `%s`\n', boolText(gr.balanceSummary.pass));
        fprintf(fid, '- Residual pass: `%s`\n\n', boolText(all(rr.allPass)));
        fprintf(fid, '| Component | internal mismatch | donor residual | receiver residual | pair inventory delta | slot external residual |\n');
        fprintf(fid, '|---|---:|---:|---:|---:|---:|\n');
        for r = 1:height(rr)
            fprintf(fid, '| %s | %.16g | %.16g | %.16g | %.16g | %.16g |\n', ...
                rr.component(r), rr.internalMismatch(r), rr.donorResidual(r), ...
                rr.receiverResidual(r), rr.pairInventoryDelta(r), rr.slotExternalResidual(r));
        end
        fprintf(fid, '\nInterpretation: %s\n\n', gr.interpretation);
    end

    fprintf(fid, '## Output files\n\n');
    fprintf(fid, '- `native_eq_microbalance_residuals.csv`\n');
    fprintf(fid, '- `EQI_stream_rows.csv`\n');
    fprintf(fid, '- `EQII_stream_rows.csv`\n');
    fprintf(fid, '- `EQI_balance_rows.csv`\n');
    fprintf(fid, '- `EQII_balance_rows.csv`\n');
    fprintf(fid, '- `EQI_native_counter_tail_report.txt`\n');
    fprintf(fid, '- `EQII_native_counter_tail_report.txt`\n');
    fprintf(fid, '- `native_eq_microbalance_report.mat`\n');
end

function printConsoleSummary(report)
    fprintf('Yang native EQ micro-balance diagnostic wrote %s\n', report.outputDir);
    fprintf('branch=%s\n', report.git.branch);
    fprintf('commit=%s\n', report.git.commit);
    for i = 1:numel(report.groupReports)
        gr = report.groupReports(i);
        fprintf('%s operationGroupId=%s maxBalanceResidual=%.16g residualPass=%d\n', ...
            gr.label, gr.operationGroupId, gr.balanceSummary.maxAbsResidual, ...
            all(gr.residualRows.allPass));
    end
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

function groupReport = emptyGroupReport()
    groupReport = struct();
    groupReport.label = "";
    groupReport.operationGroupId = "";
    groupReport.sourceCol = NaN;
    groupReport.durationSec = NaN;
    groupReport.runtimeSeconds = NaN;
    groupReport.route = "";
    groupReport.family = "";
    groupReport.pairId = "";
    groupReport.donorBed = "";
    groupReport.receiverBed = "";
    groupReport.resolvedNativeValve = NaN;
    groupReport.valFeedColNorm = [];
    groupReport.valProdColNorm = [];
    groupReport.nativeExtractionReport = struct();
    groupReport.balanceSummary = struct();
    groupReport.balanceRows = table();
    groupReport.streamRows = table();
    groupReport.residualRows = table();
    groupReport.interpretation = "";
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
