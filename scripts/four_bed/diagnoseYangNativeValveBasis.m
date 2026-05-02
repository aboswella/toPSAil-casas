function report = diagnoseYangNativeValveBasis()
%DIAGNOSEYANGNATIVEVALVEBASIS Static/native Cv basis audit.
%
% This diagnostic prepares native Yang temporary cases only. It does not
% integrate the ODE solver or run a four-bed cycle.

    repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    addpath(genpath(repoRoot));

    tStart = tic;
    gitInfo = collectGitInfo(repoRoot);

    params = buildAuditParams(true, []);
    defaults = collectRuntimeDefaultSummary(params);

    [manifest, pairMap, durations, plan, group, tempCase] = buildEqiiTempCase(params);
    [localParams, prepReport] = prepareYangNativeLocalRunParams(tempCase, params, ...
        'Controls', struct('cycleTimeSec', 2.4), ...
        'DurationSeconds', group.durationSec);

    huge = prepareRawOneCase(tempCase, group);
    snippets = collectStaticAuditSnippets(repoRoot);

    report = struct();
    report.version = "FI8-Yang2009-native-valve-basis-audit-v1";
    report.createdAt = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
    report.runtimeSeconds = toc(tStart);
    report.matlabVersion = string(version);
    report.git = gitInfo;
    report.operationGroupId = string(group.operationGroupId);
    report.selectedGroup = group;
    report.paramsSummary = defaults;
    report.defaultPrep = collectPreparedValveSummary(localParams, prepReport);
    report.rawOnePrep = huge;
    report.staticAuditSnippets = snippets;
    report.manifestVersion = string(manifest.version);
    report.pairMapVersion = string(pairMap.version);
    report.planVersion = string(plan.version);
    report.conclusions = resolveConclusions(report);
    report.outputPath = fullfile(repoRoot, 'validation', 'reports', ...
        'yang_diagnostics', 'native_valve_basis_audit.md');

    writeMarkdownReport(report);
    printConsoleSummary(report);
end

function params = buildAuditParams(finalizeForRuntime, nativeValveCoefficient)
    args = { ...
        'NVols', 2, ...
        'NCols', 2, ...
        'NSteps', 1, ...
        'NTimePoints', 21, ...
        'CycleTimeSec', 2.4, ...
        'FinalizeForRuntime', finalizeForRuntime};
    params = buildYangH2Co2AcTemplateParams(args{:});
    if ~isempty(nativeValveCoefficient)
        params = finalizeYangH2Co2AcTemplateParams(params, ...
            'NativeValveCoefficient', nativeValveCoefficient);
    end
end

function summary = collectRuntimeDefaultSummary(params)
    summary = struct();
    summary.valScaleFac = params.valScaleFac;
    summary.nativeValveCoefficient = params.yangRuntimeDefaults.nativeValveCoefficient;
    summary.resolvedDefaultNativeValve = ...
        params.yangRuntimeDefaults.nativeValveCoefficient * params.valScaleFac;
    summary.valFeedColNormUnique = unique(params.valFeedColNorm(:));
    summary.valProdColNormUnique = unique(params.valProdColNorm(:));
end

function [manifest, pairMap, durations, plan, group, tempCase] = buildEqiiTempCase(params)
    manifest = getYangFourBedScheduleManifest();
    pairMap = getYangDirectTransferPairMap(manifest);
    durations = getYangNormalizedSlotDurations(2.4);
    plan = buildYangFourBedOperationPlan(manifest, pairMap, durations);

    groupIds = string({plan.operationGroups.operationGroupId});
    idx = find(groupIds == "EQII-B-to-A", 1);
    if isempty(idx)
        families = string({plan.operationGroups.operationFamily});
        sourceCols = [plan.operationGroups.sourceCol];
        idx = find(families == "EQII" & sourceCols == 7, 1);
    end
    if isempty(idx)
        error('FI8:DiagnosticGroupNotFound', ...
            'Could not find EQII-B-to-A or an EQII source-column-7 group.');
    end
    group = plan.operationGroups(idx);

    states = makeSyntheticFourBedStates(params);
    container = makeYangFourBedStateContainer(states, ...
        'Manifest', manifest, ...
        'PairMap', pairMap, ...
        'InitializationPolicy', "FI8_native_valve_basis_audit_synthetic_states", ...
        'SourceNote', "Synthetic physical states for static native valve basis audit");

    pairRows = pairMap.transferPairs(pairMap.transferPairs.pair_id == string(group.pairId), :);
    if height(pairRows) ~= 1
        error('FI8:DiagnosticPairNotFound', ...
            'Expected exactly one pair-map row for %s.', char(string(group.pairId)));
    end

    selection = selectYangFourBedPairStates(container, pairRows);
    tempCase = makeYangTemporaryPairedCase(selection, ...
        'DurationSeconds', group.durationSec, ...
        'RunnerMode', "native", ...
        'CaseNote', "FI-8 native valve basis audit; preparation only");
end

function states = makeSyntheticFourBedStates(params)
    beds = ["A", "B", "C", "D"];
    states = struct();
    for k = 1:numel(beds)
        one = [0.76 - 0.01 * k; 0.24 + 0.01 * k; 0.01; 0.02; 1.0; 1.0];
        states.(char("state_" + beds(k))) = extractYangPhysicalBedState(params, ...
            repmat(one, params.nVols, 1), ...
            'Metadata', struct( ...
                'source', "diagnoseYangNativeValveBasis synthetic state", ...
                'bed', beds(k)));
    end
end

function summary = collectPreparedValveSummary(localParams, prepReport)
    vr = prepReport.valveReport;
    summary = struct();
    summary.family = string(vr.family);
    summary.defaultDimensionlessValve = vr.defaultDimensionlessValve;
    summary.valFeedColNorm = vr.valFeedColNorm;
    summary.valProdColNorm = vr.valProdColNorm;
    summary.localParamsValFeedCol = localParams.valFeedCol;
    summary.localParamsValProdCol = localParams.valProdCol;
    summary.localParamsValFeedColNorm = localParams.valFeedColNorm;
    summary.localParamsValProdColNorm = localParams.valProdColNorm;
end

function huge = prepareRawOneCase(tempCase, group)
    huge = struct();
    huge.nativeValveCoefficient = 1.0;
    try
        paramsHuge = buildAuditParams(false, 1.0);
        huge.valScaleFac = paramsHuge.valScaleFac;
        huge.resolvedNativeValve = ...
            paramsHuge.yangRuntimeDefaults.nativeValveCoefficient * paramsHuge.valScaleFac;
        [localHuge, prepHuge] = prepareYangNativeLocalRunParams(tempCase, paramsHuge, ...
            'Controls', struct('cycleTimeSec', 2.4), ...
            'DurationSeconds', group.durationSec);
        huge.errorIdentifier = "";
        huge.errorMessage = "";
        huge.prep = collectPreparedValveSummary(localHuge, prepHuge);
    catch ME
        huge.errorIdentifier = string(ME.identifier);
        huge.errorMessage = string(ME.message);
        if ~isfield(huge, 'valScaleFac')
            huge.valScaleFac = NaN;
            huge.resolvedNativeValve = NaN;
        end
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

function snippets = collectStaticAuditSnippets(repoRoot)
    specs = [
        snippetSpec("Cv_directTransfer default", ...
            "scripts/four_bed/normalizeYangFourBedControls.m", ...
            ["defaults.Cv_directTransfer"])
        snippetSpec("ADPP_BF_internalSplitFraction default", ...
            "scripts/four_bed/normalizeYangFourBedControls.m", ...
            ["defaults.ADPP_BF_internalSplitFraction"])
        snippetSpec("adapterCoefficientBasis value", ...
            "scripts/four_bed/normalizeYangFourBedControls.m", ...
            ["adapterCoefficientBasis"])
        snippetSpec("legacy adapter Cv alias handling", ...
            "scripts/four_bed/normalizeYangFourBedControls.m", ...
            ["Legacy adapter Cv aliases", "collectAdapterAliasCandidates"])
        snippetSpec("ignored native Cv control fields", ...
            "scripts/four_bed/normalizeYangFourBedControls.m", ...
            ["ignoredNativeCvFields", "Cv_EQI", "Cv_EQII", "Cv_AD_feed", "Cv_BD_waste"])
        snippetSpec("PP->PU raw adapter basis", ...
            "scripts/four_bed/validateYangDirectCouplingAdapterInputs.m", ...
            ["adapterCoefficientBasis", "effectiveCv", "adapterCvScalingApplied"])
        snippetSpec("AD&PP->BF raw adapter basis", ...
            "scripts/four_bed/validateYangAdppBfAdapterInputs.m", ...
            ["adapterCoefficientBasis", "effectiveCv", "adapterCvScalingApplied"])
        snippetSpec("NativeValveCoefficient default", ...
            "params/yang_h2co2_ac_surrogate/finalizeYangH2Co2AcTemplateParams.m", ...
            ["NativeValveCoefficient"", 1e-6", "nativeValveCoefficient"])
        snippetSpec("runtime valFeedColNorm scaling", ...
            "params/yang_h2co2_ac_surrogate/finalizeYangH2Co2AcTemplateParams.m", ...
            ["valFeedColNorm", "valProdColNorm", "valScaleFac"])
        snippetSpec("prepare valScaleFac scaling", ...
            "scripts/four_bed/prepareYangNativeLocalRunParams.m", ...
            ["valFeedColNorm", "valProdColNorm", "valScaleFac", "getControlValve"])
        snippetSpec("prepare defaultNativeValveCoefficient behaviour", ...
            "scripts/four_bed/prepareYangNativeLocalRunParams.m", ...
            ["function value = defaultNativeValveCoefficient", "nativeValveCoefficient", "valScaleFac"])
        snippetSpec("resolved native valve equal-to-1 rejection", ...
            "scripts/four_bed/prepareYangNativeLocalRunParams.m", ...
            ["abs(value - 1)", "resolved to 1", "non-Cv flag"])
        snippetSpec("test coverage for raw/direct adapter basis", ...
            "tests/four_bed/testYangValveCoefficientScaling.m", ...
            ["custom adapters use raw Cv_directTransfer", "valScaleFac", "ignoredNativeCvFields"])
    ];

    snippets = repmat(struct('label', "", 'file', "", 'lines', strings(0, 1)), numel(specs), 1);
    for k = 1:numel(specs)
        snippets(k).label = specs(k).label;
        snippets(k).file = specs(k).file;
        snippets(k).lines = findSnippetLines(fullfile(repoRoot, specs(k).file), specs(k).patterns);
    end
end

function spec = snippetSpec(label, file, patterns)
    spec = struct();
    spec.label = string(label);
    spec.file = string(file);
    spec.patterns = string(patterns(:));
end

function matches = findSnippetLines(path, patterns)
    txt = fileread(path);
    lines = splitlines(string(txt));
    keep = false(numel(lines), 1);
    for p = 1:numel(patterns)
        keep = keep | contains(lines, patterns(p));
    end
    idx = find(keep);
    if isempty(idx)
        matches = "No matching snippet found.";
        return;
    end
    expanded = false(numel(lines), 1);
    for i = 1:numel(idx)
        lo = max(1, idx(i) - 1);
        hi = min(numel(lines), idx(i) + 1);
        expanded(lo:hi) = true;
    end
    idx = find(expanded);
    matches = strings(numel(idx), 1);
    for i = 1:numel(idx)
        matches(i) = sprintf('%d: %s', idx(i), lines(idx(i)));
    end
end

function conclusions = resolveConclusions(report)
    conclusions = strings(0, 1);
    if hasRawAdapterEvidence(report.staticAuditSnippets) && ...
            report.defaultPrep.defaultDimensionlessValve == ...
            report.paramsSummary.resolvedDefaultNativeValve
        conclusions(end+1, 1) = ...
            "A. current branch uses raw adapter Cv and scaled native Cv as intended";
    else
        conclusions(end+1, 1) = ...
            "B. local branch differs from expected Cv handling";
    end

    if strlength(report.rawOnePrep.errorIdentifier) > 0
        conclusions(end+1, 1) = ...
            "D. raw NativeValveCoefficient=1 is rejected before integration";
    elseif isfinite(report.rawOnePrep.resolvedNativeValve) && ...
            report.rawOnePrep.resolvedNativeValve ~= 1
        conclusions(end+1, 1) = ...
            "C. raw NativeValveCoefficient=1 would produce an unsafe huge native valve";
    end
end

function tf = hasRawAdapterEvidence(snippets)
    allText = strjoin(vertcat(snippets.lines), newline);
    tf = contains(allText, "scaled_dimensionless_raw_direct") && ...
        contains(allText, "adapterCvScalingApplied") && ...
        contains(allText, "valScaleFac = NaN");
end

function tf = hasNativeScalingEvidence(report)
    allText = strjoin(vertcat(report.staticAuditSnippets.lines), newline);
    tf = contains(allText, "nativeValveCoefficient * params.valScaleFac") && ...
        contains(allText, "controls Cv values are dimensional and multiplied by params.valScaleFac") && ...
        report.defaultPrep.defaultDimensionlessValve == report.paramsSummary.resolvedDefaultNativeValve;
end

function writeMarkdownReport(report)
    outputPath = char(report.outputPath);
    outputDir = fileparts(outputPath);
    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    fid = fopen(outputPath, 'w');
    if fid < 0
        error('FI8:CannotWriteDiagnosticReport', ...
            'Could not open %s for writing.', outputPath);
    end
    cleaner = onCleanup(@() fclose(fid));

    fprintf(fid, '# Yang native valve basis audit\n\n');
    fprintf(fid, '- Created: %s\n', report.createdAt);
    fprintf(fid, '- MATLAB version: %s\n', report.matlabVersion);
    fprintf(fid, '- Runtime seconds: %.6g\n', report.runtimeSeconds);
    fprintf(fid, '- Branch: `%s`\n', report.git.branch);
    fprintf(fid, '- Commit SHA: `%s`\n', report.git.commit);
    fprintf(fid, '- Git status short:\n\n```text\n%s\n```\n\n', emptyText(report.git.statusShort));
    fprintf(fid, '- Recent commits:\n\n```text\n%s\n```\n\n', emptyText(report.git.logOneline5));

    fprintf(fid, '## Static audit result\n\n');
    fprintf(fid, '- Adapter Cvs are raw/direct: `%s`\n', boolText(hasRawAdapterEvidence(report.staticAuditSnippets)));
    fprintf(fid, '- Native Cvs are scaled by `params.valScaleFac`: `%s`\n', boolText(hasNativeScalingEvidence(report)));
    fprintf(fid, '- `params.valScaleFac`: %.16g\n', report.paramsSummary.valScaleFac);
    fprintf(fid, '- Runtime default `NativeValveCoefficient`: %.16g\n', report.paramsSummary.nativeValveCoefficient);
    fprintf(fid, '- Resolved default native valve: %.16g\n', report.paramsSummary.resolvedDefaultNativeValve);
    fprintf(fid, '- Unique default `valFeedColNorm`: %s\n', numericList(report.paramsSummary.valFeedColNormUnique));
    fprintf(fid, '- Unique default `valProdColNorm`: %s\n\n', numericList(report.paramsSummary.valProdColNormUnique));

    fprintf(fid, '## Native preparation result\n\n');
    fprintf(fid, '- Operation group: `%s`\n', report.operationGroupId);
    fprintf(fid, '- Native family: `%s`\n', report.defaultPrep.family);
    fprintf(fid, '- `prepReport.valveReport.defaultDimensionlessValve`: %.16g\n', report.defaultPrep.defaultDimensionlessValve);
    fprintf(fid, '- `prepReport.valveReport.valFeedColNorm`: %s\n', numericList(report.defaultPrep.valFeedColNorm));
    fprintf(fid, '- `prepReport.valveReport.valProdColNorm`: %s\n', numericList(report.defaultPrep.valProdColNorm));
    fprintf(fid, '- `localParams.valFeedCol`: %s\n', numericList(report.defaultPrep.localParamsValFeedCol));
    fprintf(fid, '- `localParams.valProdCol`: %s\n', numericList(report.defaultPrep.localParamsValProdCol));
    fprintf(fid, '- `localParams.valFeedColNorm`: %s\n', numericList(report.defaultPrep.localParamsValFeedColNorm));
    fprintf(fid, '- `localParams.valProdColNorm`: %s\n\n', numericList(report.defaultPrep.localParamsValProdColNorm));

    fprintf(fid, '## Raw NativeValveCoefficient = 1 preparation\n\n');
    fprintf(fid, '- Raw native coefficient supplied: %.16g\n', report.rawOnePrep.nativeValveCoefficient);
    fprintf(fid, '- Raw-1 `valScaleFac`: %.16g\n', report.rawOnePrep.valScaleFac);
    fprintf(fid, '- Resolved raw-1 native valve: %.16g\n', report.rawOnePrep.resolvedNativeValve);
    if strlength(report.rawOnePrep.errorIdentifier) > 0
        fprintf(fid, '- Error identifier: `%s`\n', report.rawOnePrep.errorIdentifier);
        fprintf(fid, '- Error message: %s\n', report.rawOnePrep.errorMessage);
        fprintf(fid, '- Raw native 1 safe to integrate: `false`\n\n');
    else
        fprintf(fid, '- Error identifier: none\n');
        fprintf(fid, '- Raw-1 `prepReport.valveReport.defaultDimensionlessValve`: %.16g\n', ...
            report.rawOnePrep.prep.defaultDimensionlessValve);
        fprintf(fid, '- Raw-1 `prepReport.valveReport.valProdColNorm`: %s\n', ...
            numericList(report.rawOnePrep.prep.valProdColNorm));
        fprintf(fid, '- Raw native 1 safe to integrate: `false`\n\n');
    end

    fprintf(fid, '## Source snippets\n\n');
    for k = 1:numel(report.staticAuditSnippets)
        fprintf(fid, '### %s\n\n', report.staticAuditSnippets(k).label);
        fprintf(fid, 'File: `%s`\n\n', report.staticAuditSnippets(k).file);
        fprintf(fid, '```text\n%s\n```\n\n', ...
            strjoin(report.staticAuditSnippets(k).lines, newline));
    end

    fprintf(fid, '## Conclusions\n\n');
    for k = 1:numel(report.conclusions)
        fprintf(fid, '- %s\n', report.conclusions(k));
    end
    fprintf(fid, '\nShort conclusion: adapter direct-transfer Cv stays raw/direct, native valve coefficients resolve through `params.valScaleFac`, and a raw native coefficient of 1 is not a harmless neutral setting.\n');
end

function printConsoleSummary(report)
    fprintf('Yang native valve basis audit wrote %s\n', report.outputPath);
    fprintf('branch=%s\n', report.git.branch);
    fprintf('commit=%s\n', report.git.commit);
    fprintf('operationGroupId=%s\n', report.operationGroupId);
    fprintf('valScaleFac=%.16g\n', report.paramsSummary.valScaleFac);
    fprintf('resolvedDefaultNativeValve=%.16g\n', report.paramsSummary.resolvedDefaultNativeValve);
    fprintf('resolvedRawOneNativeValve=%.16g\n', report.rawOnePrep.resolvedNativeValve);
    if strlength(report.rawOnePrep.errorIdentifier) > 0
        fprintf('rawOneError=%s: %s\n', report.rawOnePrep.errorIdentifier, report.rawOnePrep.errorMessage);
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
