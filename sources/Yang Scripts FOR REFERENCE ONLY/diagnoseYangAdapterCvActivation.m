function report = diagnoseYangAdapterCvActivation(varargin)
%DIAGNOSEYANGADAPTERCVACTIVATION Lightweight adapter Cv activation ladder.
%
% Diagnostic only. This script varies the wrapper adapter Cv_directTransfer
% while leaving native valve scaling, source constants, model physics, and
% acceptance thresholds unchanged.

    parser = inputParser;
    parser.FunctionName = "diagnoseYangAdapterCvActivation";
    addParameter(parser, "OutputDir", fullfile(pwd, "validation", "reports", ...
        "yang_diagnostics", "adapter_cv_activation"), ...
        @(x) ischar(x) || isstring(x));
    addParameter(parser, "RuntimeGuardSec", 120, @(x) isnumeric(x) && ...
        isscalar(x) && isfinite(x) && x > 0);
    addParameter(parser, "BalanceResidualGuardMol", 1e-6, @(x) isnumeric(x) && ...
        isscalar(x) && isfinite(x) && x > 0);
    addParameter(parser, "AdapterResidualGuardMol", 1e-6, @(x) isnumeric(x) && ...
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
    [params, initialContainer, baseline] = buildBaseline(manifest, pairMap);
    guards = struct( ...
        "runtimeSec", double(opts.RuntimeGuardSec), ...
        "balanceResidualMol", double(opts.BalanceResidualGuardMol), ...
        "adapterResidualMol", double(opts.AdapterResidualGuardMol));

    oneCycleRuns = runOneCycleLadder(params, initialContainer, manifest, pairMap, guards);
    oneCycleLadder = vertcatTables(oneCycleRuns.oneCycleRows);
    adapterDetails = vertcatTables(oneCycleRuns.adapterDetailRows);

    selectedCv = selectThreeCycleCandidates(oneCycleLadder);
    threeCycleRuns = runThreeCycleConfirmation(params, initialContainer, ...
        manifest, pairMap, selectedCv, guards);
    threeCycleComparison = vertcatTables(threeCycleRuns.threeCycleRows);
    adapterDetails = [adapterDetails; vertcatTables(threeCycleRuns.adapterDetailRows)];

    interpretation = interpretResults(oneCycleLadder, threeCycleComparison, selectedCv);
    completedAt = datetime("now", "TimeZone", "local");

    writetable(oneCycleLadder, fullfile(outputDir, "one_cycle_ladder.csv"));
    writetable(threeCycleComparison, fullfile(outputDir, "three_cycle_comparison.csv"));
    writetable(adapterDetails, fullfile(outputDir, "adapter_operation_details.csv"));

    report = struct();
    report.version = "Yang-adapter-Cv-activation-diagnostic-v1";
    report.startedAt = startedAt;
    report.completedAt = completedAt;
    report.outputDir = outputDir;
    report.runIdentity = runIdentity;
    report.baseline = baseline;
    report.guards = guards;
    report.oneCycleRuns = oneCycleRuns;
    report.threeCycleRuns = threeCycleRuns;
    report.selectedThreeCycleCv = selectedCv(:);
    report.oneCycleLadder = oneCycleLadder;
    report.threeCycleComparison = threeCycleComparison;
    report.adapterOperationDetails = adapterDetails;
    report.interpretation = interpretation;
    report.totalRuntimeSec = seconds(completedAt - startedAt);

    writeSummaryMarkdown(report, fullfile(outputDir, "summary.md"));
    save(fullfile(outputDir, "adapter_activation_report.mat"), "report");
end

function [params, initialContainer, baseline] = buildBaseline(manifest, pairMap)
    params = buildYangH2Co2AcTemplateParams( ...
        'NVols', 2, ...
        'NCols', 2, ...
        'NSteps', 1, ...
        'NTimePoints', 21, ...
        'CycleTimeSec', 2.4, ...
        'FinalizeForRuntime', true);

    initialContainer = makeDiagnosticInitialContainer(params, manifest, pairMap);

    baseline = struct();
    baseline.paramsBuilder = "buildYangH2Co2AcTemplateParams";
    baseline.paramsOptions = "NVols=2, NCols=2, NSteps=1, NTimePoints=21, CycleTimeSec=2.4, FinalizeForRuntime=true";
    baseline.controls = makeControls(1e-6, params);
    baseline.NativeValveCoefficient = params.yangRuntimeDefaults.nativeValveCoefficient;
    baseline.paramsValScaleFac = params.valScaleFac;
    baseline.resolvedNativeValveCoefficient = params.yangRuntimeDefaults.nativeValveCoefficient .* params.valScaleFac;
    baseline.initializationPolicy = string(initialContainer.initializationPolicy);
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
        "InitializationPolicy", "adapter Cv activation synthetic commissioning state", ...
        "SourceNote", "same two-volume synthetic pattern used by current Yang diagnostics");
end

function controls = makeControls(cvDirectTransfer, params)
    controls = struct( ...
        'cycleTimeSec', 2.4, ...
        'Cv_directTransfer', cvDirectTransfer, ...
        'ADPP_BF_internalSplitFraction', 1/3, ...
        'balanceAbsTol', 1e-8, ...
        'balanceRelTol', 1e-6, ...
        'cssAbsTol', 1e-8, ...
        'cssRelTol', 1e-6);
    controls = normalizeYangFourBedControls(controls, params);
end

function ladder = runOneCycleLadder(params, initialContainer, manifest, pairMap, guards)
    baseCandidates = [1e-6; 1e-5; 1e-4; 1e-3; 1e-2];
    oneRows = {};
    detailRows = {};
    simReports = {};
    stopReason = "";

    for i = 1:numel(baseCandidates)
        cv = baseCandidates(i);
        result = runCandidate(params, initialContainer, manifest, pairMap, cv, 1, ...
            "one_cycle_ladder", guards);
        oneRows{end+1, 1} = result.summaryRow; %#ok<AGROW>
        detailRows{end+1, 1} = result.adapterDetails; %#ok<AGROW>
        simReports{end+1, 1} = result; %#ok<AGROW>
        if result.stopFurtherLadder
            stopReason = "stopped upward ladder at Cv=" + string(cv) + ...
                " because " + result.stopReason;
            break;
        end
    end

    oneCycleRows = vertcatTables(oneRows);
    if strlength(stopReason) == 0 && height(oneCycleRows) == numel(baseCandidates) && ...
            all(oneCycleRows.numerically_stable) && all(oneCycleRows.activation_class == "spectator")
        cv = 1e-1;
        result = runCandidate(params, initialContainer, manifest, pairMap, cv, 1, ...
            "one_cycle_ladder", guards);
        oneRows{end+1, 1} = result.summaryRow;
        detailRows{end+1, 1} = result.adapterDetails;
        simReports{end+1, 1} = result;
        if result.stopFurtherLadder
            stopReason = "stopped upward ladder at Cv=" + string(cv) + ...
                " because " + result.stopReason;
        end
    end

    ladder = struct();
    ladder.version = "Yang-adapter-Cv-one-cycle-ladder-v1";
    ladder.cvCandidates = vertcatTables(oneRows).Cv_directTransfer;
    ladder.oneCycleRows = oneRows;
    ladder.adapterDetailRows = detailRows;
    ladder.candidateReports = simReports;
    ladder.stopReason = stopReason;
end

function confirmation = runThreeCycleConfirmation(params, initialContainer, manifest, pairMap, selectedCv, guards)
    threeRows = {};
    detailRows = {};
    simReports = {};
    for i = 1:numel(selectedCv)
        cv = selectedCv(i);
        result = runCandidate(params, initialContainer, manifest, pairMap, cv, 3, ...
            "three_cycle_confirmation", guards);
        threeRows{end+1, 1} = makeThreeCycleRows(result); %#ok<AGROW>
        detailRows{end+1, 1} = result.adapterDetails; %#ok<AGROW>
        simReports{end+1, 1} = result; %#ok<AGROW>
    end

    confirmation = struct();
    confirmation.version = "Yang-adapter-Cv-three-cycle-confirmation-v1";
    confirmation.selectedCv = selectedCv(:);
    confirmation.threeCycleRows = threeRows;
    confirmation.adapterDetailRows = detailRows;
    confirmation.candidateReports = simReports;
end

function result = runCandidate(params, initialContainer, manifest, pairMap, cv, maxCycles, runStage, guards)
    controls = makeControls(cv, params);
    result = struct();
    result.Cv_directTransfer = cv;
    result.MaxCycles = maxCycles;
    result.runStage = string(runStage);
    result.controls = controls;
    result.runCompleted = false;
    result.runError = "";
    result.runtimeSec = NaN;
    result.solverOutput = "";
    result.simReport = [];

    try
        tic;
        solverOutput = evalc(['simReport = runYangFourBedSimulation(initialContainer, ', ...
            'params, controls, ''MaxCycles'', maxCycles, ''StopAtCss'', false, ', ...
            '''KeepCycleReports'', true, ''Manifest'', manifest, ''PairMap'', pairMap);']);
        result.runtimeSec = toc;
        result.solverOutput = string(solverOutput);
        result.simReport = simReport;
        result.runCompleted = true;
    catch ME
        result.runtimeSec = toc;
        result.runError = string(getReport(ME, "basic", "hyperlinks", "off"));
        result.runCompleted = false;
    end

    if result.runCompleted
        result.summaryRow = makeOneCycleSummaryRow(result, guards);
        result.adapterDetails = makeAdapterOperationDetails(result);
        result.stopFurtherLadder = shouldStopFurther(result.summaryRow, guards);
        result.stopReason = stopReason(result.summaryRow, guards);
    else
        result.summaryRow = makeFailedSummaryRow(result);
        result.adapterDetails = emptyAdapterDetailsTable();
        result.stopFurtherLadder = true;
        result.stopReason = "run failed";
    end
end

function rowTable = makeOneCycleSummaryRow(result, guards)
    simReport = result.simReport;
    cycleIndex = 1;
    rows = simReport.ledger.streamRows;
    balanceRows = simReport.ledger.balanceRows;

    h2Feed = sumLedgerRows(rows, cycleIndex, "H2", "external_feed", "", "", "");
    h2Product = sumLedgerRows(rows, cycleIndex, "H2", "external_product", "", "", "");
    h2Waste = sumLedgerRows(rows, cycleIndex, "H2", "external_waste", "", "", "");
    h2Delta = sumLedgerRows(rows, cycleIndex, "H2", "bed_inventory_delta", "", "", "");
    h2ProductAd = sumLedgerRows(rows, cycleIndex, "H2", "external_product", "AD", "", "");
    h2ProductAdpp = sumLedgerRows(rows, cycleIndex, "H2", "external_product", "ADPP_BF", "", "");
    h2WasteBd = sumLedgerRows(rows, cycleIndex, "H2", "external_waste", "BD", "", "");
    h2WastePpPu = sumLedgerRows(rows, cycleIndex, "H2", "external_waste", "PP_PU", "", "");
    h2InternalEqi = sumLedgerRows(rows, cycleIndex, "H2", "internal_transfer", "EQI", "", "out_of_donor");
    h2InternalEqii = sumLedgerRows(rows, cycleIndex, "H2", "internal_transfer", "EQII", "", "out_of_donor");
    h2InternalAdpp = sumLedgerRows(rows, cycleIndex, "H2", "internal_transfer", "ADPP_BF", "", "out_of_donor");
    h2InternalPpPu = sumLedgerRows(rows, cycleIndex, "H2", "internal_transfer", "PP_PU", "", "out_of_donor");
    totalInternal = h2InternalEqi + h2InternalEqii + h2InternalAdpp + h2InternalPpPu;
    nativeInternal = h2InternalEqi + h2InternalEqii;
    maxAdapterResidual = maxAdapterConservationResidual(simReport);
    adapterWarnings = countAdapterWarnings(simReport);
    flowWarnings = countAdapterWarnings(simReport, "flow");
    sanityWarnings = countSanityWarnings(simReport);
    stateHasNaN = finalContainerHasNaN(simReport);
    maxResidual = simReport.balanceSummary.maxAbsResidual;
    balancePass = simReport.balanceSummary.pass;
    metricsPass = simReport.metricsPass;
    stable = result.runCompleted && balancePass && metricsPass && ...
        maxResidual <= guards.balanceResidualMol && ...
        nanPass(maxAdapterResidual, guards.adapterResidualMol) && ...
        ~stateHasNaN && sanityWarnings == 0;

    nativeFractions = [
        safeRatio(h2ProductAdpp, h2ProductAd)
        safeRatio(h2InternalAdpp, nativeInternal)
        safeRatio(h2InternalPpPu, nativeInternal)
        safeRatio(h2WastePpPu, h2WasteBd)
    ];
    maxAdapterNativeFraction = max(nativeFractions(isfinite(nativeFractions)), [], "omitnan");
    if isempty(maxAdapterNativeFraction)
        maxAdapterNativeFraction = NaN;
    end
    activationClass = classifyActivation(stable, maxAdapterNativeFraction, ...
        result.runtimeSec, maxResidual, maxAdapterResidual, guards);

    row = oneCycleRowTemplate();
    row.run_stage = string(result.runStage);
    row.Cv_directTransfer = result.Cv_directTransfer;
    row.MaxCycles = result.MaxCycles;
    row.runtime_seconds = result.runtimeSec;
    row.runCompleted = result.runCompleted;
    row.balancePass = balancePass;
    row.metricsPass = metricsPass;
    row.max_balance_residual = maxResidual;
    row.H2_feed = h2Feed;
    row.H2_product = h2Product;
    row.H2_waste = h2Waste;
    row.H2_bed_delta = h2Delta;
    row.H2_recovery = metricValue(simReport, cycleIndex, "product_recovery", "H2");
    row.H2_purity = metricValue(simReport, cycleIndex, "product_purity", "H2");
    row.H2_product_AD = h2ProductAd;
    row.H2_product_ADPP_BF = h2ProductAdpp;
    row.H2_waste_BD = h2WasteBd;
    row.H2_waste_PP_PU = h2WastePpPu;
    row.H2_internal_EQI = h2InternalEqi;
    row.H2_internal_EQII = h2InternalEqii;
    row.H2_internal_ADPP_BF = h2InternalAdpp;
    row.H2_internal_PP_PU = h2InternalPpPu;
    row.ADPP_BF_product_fraction_of_total_product = safeRatio(h2ProductAdpp, h2Product);
    row.ADPP_BF_internal_fraction_of_total_internal = safeRatio(h2InternalAdpp, totalInternal);
    row.PP_PU_internal_fraction_of_total_internal = safeRatio(h2InternalPpPu, totalInternal);
    row.PP_PU_waste_fraction_of_total_waste = safeRatio(h2WastePpPu, h2Waste);
    row.ADPP_BF_product_fraction_of_native_AD_product = safeRatio(h2ProductAdpp, h2ProductAd);
    row.ADPP_BF_internal_fraction_of_native_EQ_internal = safeRatio(h2InternalAdpp, nativeInternal);
    row.PP_PU_internal_fraction_of_native_EQ_internal = safeRatio(h2InternalPpPu, nativeInternal);
    row.PP_PU_waste_fraction_of_native_BD_waste = safeRatio(h2WastePpPu, h2WasteBd);
    row.max_adapter_native_fraction = maxAdapterNativeFraction;
    row.max_adapter_conservation_residual = maxAdapterResidual;
    row.n_adapter_warnings = adapterWarnings;
    row.n_flow_sign_warnings = flowWarnings;
    row.n_sanity_warnings = sanityWarnings;
    row.state_contains_nan = stateHasNaN;
    row.numerically_stable = stable;
    row.activation_class = activationClass;
    row.stop_guard_triggered = shouldStopFurther(row, guards);
    row.stop_reason = stopReason(row, guards);
    row.run_error = "";
    rowTable = struct2table(row);
end

function rowTable = makeFailedSummaryRow(result)
    row = oneCycleRowTemplate();
    row.run_stage = string(result.runStage);
    row.Cv_directTransfer = result.Cv_directTransfer;
    row.MaxCycles = result.MaxCycles;
    row.runtime_seconds = result.runtimeSec;
    row.runCompleted = false;
    row.balancePass = false;
    row.metricsPass = false;
    row.numerically_stable = false;
    row.activation_class = "unstable";
    row.stop_guard_triggered = true;
    row.stop_reason = "run failed";
    row.run_error = result.runError;
    rowTable = struct2table(row);
end

function row = oneCycleRowTemplate()
    row = struct( ...
        "run_stage", "", ...
        "Cv_directTransfer", NaN, ...
        "MaxCycles", NaN, ...
        "runtime_seconds", NaN, ...
        "runCompleted", false, ...
        "balancePass", false, ...
        "metricsPass", false, ...
        "max_balance_residual", NaN, ...
        "H2_feed", NaN, ...
        "H2_product", NaN, ...
        "H2_waste", NaN, ...
        "H2_bed_delta", NaN, ...
        "H2_recovery", NaN, ...
        "H2_purity", NaN, ...
        "H2_product_AD", NaN, ...
        "H2_product_ADPP_BF", NaN, ...
        "H2_waste_BD", NaN, ...
        "H2_waste_PP_PU", NaN, ...
        "H2_internal_EQI", NaN, ...
        "H2_internal_EQII", NaN, ...
        "H2_internal_ADPP_BF", NaN, ...
        "H2_internal_PP_PU", NaN, ...
        "ADPP_BF_product_fraction_of_total_product", NaN, ...
        "ADPP_BF_internal_fraction_of_total_internal", NaN, ...
        "PP_PU_internal_fraction_of_total_internal", NaN, ...
        "PP_PU_waste_fraction_of_total_waste", NaN, ...
        "ADPP_BF_product_fraction_of_native_AD_product", NaN, ...
        "ADPP_BF_internal_fraction_of_native_EQ_internal", NaN, ...
        "PP_PU_internal_fraction_of_native_EQ_internal", NaN, ...
        "PP_PU_waste_fraction_of_native_BD_waste", NaN, ...
        "max_adapter_native_fraction", NaN, ...
        "max_adapter_conservation_residual", NaN, ...
        "n_adapter_warnings", NaN, ...
        "n_flow_sign_warnings", NaN, ...
        "n_sanity_warnings", NaN, ...
        "state_contains_nan", false, ...
        "numerically_stable", false, ...
        "activation_class", "", ...
        "stop_guard_triggered", false, ...
        "stop_reason", "", ...
        "run_error", "");
end

function tbl = makeAdapterOperationDetails(result)
    if ~result.runCompleted
        tbl = emptyAdapterDetailsTable();
        return;
    end
    simReport = result.simReport;
    streamRows = simReport.ledger.streamRows;
    rows = repmat(adapterDetailTemplate(), 0, 1);
    for c = 1:numel(simReport.cycleReports)
        cycleReport = simReport.cycleReports{c};
        ops = cycleReport.operationReports;
        for k = 1:numel(ops)
            op = ops(k);
            family = string(op.operationFamily);
            if ~ismember(family, ["ADPP_BF", "PP_PU"])
                continue;
            end
            opId = string(op.operationGroupId);
            h2Rows = streamRows(streamRows.cycle_index == cycleReport.cycleIndex & ...
                streamRows.operation_group_id == opId & streamRows.component == "H2", :);
            rr = op.runReport;
            pressure = pressureFields(rr);
            row = adapterDetailTemplate();
            row.run_stage = string(result.runStage);
            row.MaxCycles = result.MaxCycles;
            row.cycle_index = cycleReport.cycleIndex;
            row.operation_group_id = opId;
            row.family = family;
            row.Cv_directTransfer = result.Cv_directTransfer;
            row.duration_sec = op.durationSec;
            row.initial_donor_product_pressure_ratio = pressure.donorInitialProduct;
            row.initial_receiver_product_pressure_ratio = pressure.receiverInitialProduct;
            row.initial_donor_feed_pressure_ratio = pressure.donorInitialFeed;
            row.initial_receiver_feed_pressure_ratio = pressure.receiverInitialFeed;
            row.terminal_donor_product_pressure_ratio = pressure.donorTerminalProduct;
            row.terminal_receiver_product_pressure_ratio = pressure.receiverTerminalProduct;
            row.terminal_donor_feed_pressure_ratio = pressure.donorTerminalFeed;
            row.terminal_receiver_feed_pressure_ratio = pressure.receiverTerminalFeed;
            row.initial_product_pressure_delta_donor_minus_receiver = ...
                pressure.donorInitialProduct - pressure.receiverInitialProduct;
            row.initial_feed_pressure_delta_donor_minus_receiver = ...
                pressure.donorInitialFeed - pressure.receiverInitialFeed;
            row.total_external_feed_H2 = sumScope(h2Rows, "external_feed");
            row.total_external_product_H2 = sumScope(h2Rows, "external_product");
            row.total_external_waste_H2 = sumScope(h2Rows, "external_waste");
            row.total_internal_out_H2 = sumDirection(h2Rows, "internal_transfer", "out_of_donor");
            row.total_internal_in_H2 = sumDirection(h2Rows, "internal_transfer", "into_receiver");
            row.max_conservation_residual = maxConservationResidual(rr);
            row.effective_split_H2 = effectiveSplitField(rr, "H2");
            row.effective_split_total = effectiveSplitField(rr, "total");
            row.flow_sign_warning_count = countWarningsInStrings(op.warnings, "flow");
            row.adapter_warning_count = numel(string(op.warnings(:)));
            row.sanity_warning_count = countSanityWarningStrings(op.warnings);
            row.pressure_data_available = pressure.available;
            rows(end+1, 1) = row; %#ok<AGROW>
        end
    end
    tbl = struct2table(rows);
end

function tbl = emptyAdapterDetailsTable()
    tbl = struct2table(repmat(adapterDetailTemplate(), 0, 1));
end

function row = adapterDetailTemplate()
    row = struct( ...
        "run_stage", "", ...
        "MaxCycles", NaN, ...
        "cycle_index", NaN, ...
        "operation_group_id", "", ...
        "family", "", ...
        "Cv_directTransfer", NaN, ...
        "duration_sec", NaN, ...
        "initial_donor_product_pressure_ratio", NaN, ...
        "initial_receiver_product_pressure_ratio", NaN, ...
        "initial_donor_feed_pressure_ratio", NaN, ...
        "initial_receiver_feed_pressure_ratio", NaN, ...
        "terminal_donor_product_pressure_ratio", NaN, ...
        "terminal_receiver_product_pressure_ratio", NaN, ...
        "terminal_donor_feed_pressure_ratio", NaN, ...
        "terminal_receiver_feed_pressure_ratio", NaN, ...
        "initial_product_pressure_delta_donor_minus_receiver", NaN, ...
        "initial_feed_pressure_delta_donor_minus_receiver", NaN, ...
        "total_external_feed_H2", NaN, ...
        "total_external_product_H2", NaN, ...
        "total_external_waste_H2", NaN, ...
        "total_internal_out_H2", NaN, ...
        "total_internal_in_H2", NaN, ...
        "max_conservation_residual", NaN, ...
        "effective_split_H2", NaN, ...
        "effective_split_total", NaN, ...
        "flow_sign_warning_count", NaN, ...
        "adapter_warning_count", NaN, ...
        "sanity_warning_count", NaN, ...
        "pressure_data_available", false);
end

function selectedCv = selectThreeCycleCandidates(oneCycleLadder)
    baseline = 1e-6;
    selectedCv = baseline;
    stable = oneCycleLadder(oneCycleLadder.numerically_stable, :);
    activated = stable(stable.activation_class == "activated", :);
    if height(activated) > 0
        selectedCv(end+1, 1) = min(activated.Cv_directTransfer); %#ok<AGROW>
    end
    nonDominant = stable(stable.activation_class ~= "dominant" & ...
        stable.activation_class ~= "unstable" & stable.Cv_directTransfer ~= baseline, :);
    if height(nonDominant) > 0
        selectedCv(end+1, 1) = max(nonDominant.Cv_directTransfer); %#ok<AGROW>
    end
    selectedCv = unique(selectedCv(:), "stable");
    if numel(selectedCv) > 3
        selectedCv = selectedCv(1:3);
    end
end

function tbl = makeThreeCycleRows(result)
    if ~result.runCompleted
        row = threeCycleTemplate();
        row.run_stage = string(result.runStage);
        row.Cv_directTransfer = result.Cv_directTransfer;
        row.MaxCycles = result.MaxCycles;
        row.row_scope = "run_failed";
        row.runCompleted = false;
        row.run_error = result.runError;
        tbl = struct2table(row);
        return;
    end

    simReport = result.simReport;
    cycles = unique(simReport.ledger.streamRows.cycle_index);
    cycles = cycles(isfinite(cycles));
    rows = repmat(threeCycleTemplate(), numel(cycles) + 1, 1);
    cum = cumulativeTotalsTemplate();
    for i = 1:numel(cycles)
        cycleIndex = cycles(i);
        row = makeCycleComparisonRow(result, cycleIndex);
        rows(i) = row;
        cum.feed = cum.feed + row.H2_feed;
        cum.product = cum.product + row.H2_product;
        cum.waste = cum.waste + row.H2_waste;
        cum.delta = cum.delta + row.H2_bed_delta;
    end
    cumulative = threeCycleTemplate();
    cumulative.run_stage = string(result.runStage);
    cumulative.Cv_directTransfer = result.Cv_directTransfer;
    cumulative.MaxCycles = result.MaxCycles;
    cumulative.row_scope = "cumulative_3cycle";
    cumulative.cycle_index = NaN;
    cumulative.runtime_seconds = result.runtimeSec;
    cumulative.runCompleted = result.runCompleted;
    cumulative.balance_pass = simReport.balanceSummary.pass;
    cumulative.max_balance_residual = simReport.balanceSummary.maxAbsResidual;
    cumulative.H2_feed = cum.feed;
    cumulative.H2_product = cum.product;
    cumulative.H2_waste = cum.waste;
    cumulative.H2_bed_delta = cum.delta;
    cumulative.H2_recovery = safeRatio(cum.product, cum.feed);
    cumulative.fraction_feed_to_product = safeRatio(cum.product, cum.feed);
    cumulative.fraction_feed_to_waste = safeRatio(cum.waste, cum.feed);
    cumulative.fraction_feed_to_bed_accumulation = safeRatio(cum.delta, cum.feed);
    rows(end) = cumulative;
    tbl = struct2table(rows);
end

function row = makeCycleComparisonRow(result, cycleIndex)
    simReport = result.simReport;
    rows = simReport.ledger.streamRows;
    row = threeCycleTemplate();
    row.run_stage = string(result.runStage);
    row.Cv_directTransfer = result.Cv_directTransfer;
    row.MaxCycles = result.MaxCycles;
    row.row_scope = "cycle";
    row.cycle_index = cycleIndex;
    row.runtime_seconds = result.runtimeSec;
    row.runCompleted = result.runCompleted;
    row.balance_pass = cycleBalancePass(simReport, cycleIndex);
    row.max_balance_residual = cycleMaxResidual(simReport, cycleIndex);
    row.H2_feed = sumLedgerRows(rows, cycleIndex, "H2", "external_feed", "", "", "");
    row.H2_product = sumLedgerRows(rows, cycleIndex, "H2", "external_product", "", "", "");
    row.H2_waste = sumLedgerRows(rows, cycleIndex, "H2", "external_waste", "", "", "");
    row.H2_bed_delta = sumLedgerRows(rows, cycleIndex, "H2", "bed_inventory_delta", "", "", "");
    row.H2_recovery = metricValue(simReport, cycleIndex, "product_recovery", "H2");
    row.H2_purity = metricValue(simReport, cycleIndex, "product_purity", "H2");
    row.H2_product_AD = sumLedgerRows(rows, cycleIndex, "H2", "external_product", "AD", "", "");
    row.H2_product_ADPP_BF = sumLedgerRows(rows, cycleIndex, "H2", "external_product", "ADPP_BF", "", "");
    row.H2_waste_BD = sumLedgerRows(rows, cycleIndex, "H2", "external_waste", "BD", "", "");
    row.H2_waste_PP_PU = sumLedgerRows(rows, cycleIndex, "H2", "external_waste", "PP_PU", "", "");
    row.H2_internal_EQI = sumLedgerRows(rows, cycleIndex, "H2", "internal_transfer", "EQI", "", "out_of_donor");
    row.H2_internal_EQII = sumLedgerRows(rows, cycleIndex, "H2", "internal_transfer", "EQII", "", "out_of_donor");
    row.H2_internal_ADPP_BF = sumLedgerRows(rows, cycleIndex, "H2", "internal_transfer", "ADPP_BF", "", "out_of_donor");
    row.H2_internal_PP_PU = sumLedgerRows(rows, cycleIndex, "H2", "internal_transfer", "PP_PU", "", "out_of_donor");
end

function row = threeCycleTemplate()
    row = struct( ...
        "run_stage", "", ...
        "Cv_directTransfer", NaN, ...
        "MaxCycles", NaN, ...
        "row_scope", "", ...
        "cycle_index", NaN, ...
        "runtime_seconds", NaN, ...
        "runCompleted", false, ...
        "balance_pass", false, ...
        "max_balance_residual", NaN, ...
        "H2_feed", NaN, ...
        "H2_product", NaN, ...
        "H2_waste", NaN, ...
        "H2_bed_delta", NaN, ...
        "H2_recovery", NaN, ...
        "H2_purity", NaN, ...
        "H2_product_AD", NaN, ...
        "H2_product_ADPP_BF", NaN, ...
        "H2_waste_BD", NaN, ...
        "H2_waste_PP_PU", NaN, ...
        "H2_internal_EQI", NaN, ...
        "H2_internal_EQII", NaN, ...
        "H2_internal_ADPP_BF", NaN, ...
        "H2_internal_PP_PU", NaN, ...
        "fraction_feed_to_product", NaN, ...
        "fraction_feed_to_waste", NaN, ...
        "fraction_feed_to_bed_accumulation", NaN, ...
        "run_error", "");
end

function totals = cumulativeTotalsTemplate()
    totals = struct("feed", 0, "product", 0, "waste", 0, "delta", 0);
end

function interpretation = interpretResults(oneCycleLadder, threeCycleComparison, selectedCv)
    interpretation = struct();
    interpretation.lowCvLinearity = assessLowCvLinearity(oneCycleLadder);
    interpretation.selectedCv = selectedCv(:);
    interpretation.category = "D";
    interpretation.categoryLabel = "Cv activation still does nothing";
    interpretation.recommendation = "inspect adapter pressure endpoint logic and clamp conditions";
    interpretation.reason = "adapter streams remained spectator-scale across the stable ladder";

    stableNonBaseline = oneCycleLadder(oneCycleLadder.Cv_directTransfer ~= 1e-6 & ...
        oneCycleLadder.numerically_stable, :);
    if any(oneCycleLadder.activation_class == "unstable")
        interpretation.category = "C";
        interpretation.categoryLabel = "Cv activation destabilises";
        interpretation.recommendation = "inspect the first unstable adapter case before any higher-Cv run";
        interpretation.reason = "at least one ladder candidate tripped a diagnostic stability guard";
        return;
    end
    if isempty(stableNonBaseline) || ~any(stableNonBaseline.activation_class ~= "spectator")
        return;
    end

    cumulative = threeCycleComparison(threeCycleComparison.row_scope == "cumulative_3cycle", :);
    baseline = cumulative(cumulative.Cv_directTransfer == 1e-6, :);
    nonBase = cumulative(cumulative.Cv_directTransfer ~= 1e-6 & cumulative.runCompleted, :);
    if height(baseline) == 0 || height(nonBase) == 0
        interpretation.category = "D";
        interpretation.categoryLabel = "Cv activation still does nothing";
        interpretation.recommendation = "run one targeted three-cycle confirmation at the lowest activated Cv";
        interpretation.reason = "one-cycle activation was seen but three-cycle comparison was unavailable";
        return;
    end

    recoveryDelta = max(nonBase.H2_recovery) - baseline.H2_recovery(1);
    wasteDelta = min(nonBase.fraction_feed_to_waste) - baseline.fraction_feed_to_waste(1);
    anyNonNegligible = any(stableNonBaseline.activation_class == "activated" | ...
        stableNonBaseline.activation_class == "dominant");
    if anyNonNegligible && recoveryDelta > 1e-4
        interpretation.category = "A";
        interpretation.categoryLabel = "Cv activation helps";
        interpretation.recommendation = "run a narrow physics-positioned Cv sensitivity around the lowest activated value";
        interpretation.reason = sprintf("three-cycle recovery improved by %.6g without balance failure", recoveryDelta);
    elseif anyNonNegligible
        interpretation.category = "B";
        interpretation.categoryLabel = "Cv activation merely increases losses";
        interpretation.recommendation = "inspect PP->PU and ADPP_BF endpoint pressure policies before calibration";
        interpretation.reason = sprintf("adapter streams grew, but recovery did not improve materially; best recovery delta %.6g and best waste-fraction delta %.6g", ...
            recoveryDelta, wasteDelta);
    end
end

function tf = shouldStopFurther(row, guards)
    tf = ~logical(row.runCompleted) || ...
        row.runtime_seconds > guards.runtimeSec || ...
        row.max_balance_residual > guards.balanceResidualMol || ...
        row.state_contains_nan || ...
        row.n_sanity_warnings > 0 || ...
        (isfinite(row.max_adapter_conservation_residual) && ...
        row.max_adapter_conservation_residual > guards.adapterResidualMol);
end

function reason = stopReason(row, guards)
    reason = "";
    if ~logical(row.runCompleted)
        reason = "run failed";
    elseif row.runtime_seconds > guards.runtimeSec
        reason = "runtime guard exceeded";
    elseif row.max_balance_residual > guards.balanceResidualMol
        reason = "balance residual guard exceeded";
    elseif row.state_contains_nan
        reason = "state contains NaN";
    elseif row.n_sanity_warnings > 0
        reason = "NaN/negative/invalid sanity warning";
    elseif isfinite(row.max_adapter_conservation_residual) && ...
            row.max_adapter_conservation_residual > guards.adapterResidualMol
        reason = "adapter conservation residual guard exceeded";
    end
end

function cls = classifyActivation(stable, maxFraction, runtimeSec, maxResidual, maxAdapterResidual, guards)
    if ~stable || runtimeSec > guards.runtimeSec || ...
            maxResidual > guards.balanceResidualMol || ...
            (isfinite(maxAdapterResidual) && maxAdapterResidual > guards.adapterResidualMol)
        cls = "unstable";
    elseif ~isfinite(maxFraction) || maxFraction < 0.01
        cls = "spectator";
    elseif maxFraction < 0.20
        cls = "activated";
    else
        cls = "dominant";
    end
end

function linearity = assessLowCvLinearity(oneCycleLadder)
    lowCv = [1e-6; 1e-5; 1e-4];
    values = NaN(size(lowCv));
    for i = 1:numel(lowCv)
        mask = oneCycleLadder.Cv_directTransfer == lowCv(i) & ...
            oneCycleLadder.runCompleted;
        if any(mask)
            row = oneCycleLadder(find(mask, 1), :);
            values(i) = row.H2_product_ADPP_BF + row.H2_internal_ADPP_BF + ...
                row.H2_internal_PP_PU + row.H2_waste_PP_PU;
        end
    end
    ratios = values ./ lowCv;
    finite = ratios(isfinite(ratios) & ratios > 0);
    linearity = struct();
    linearity.cv = lowCv;
    linearity.adapterMagnitude = values;
    linearity.magnitudePerCv = ratios;
    if numel(finite) < 2
        linearity.classification = "insufficient_data";
        linearity.note = "low-Cv runs did not provide enough positive adapter flow data";
    elseif max(finite) / min(finite) <= 2
        linearity.classification = "approximately_linear";
        linearity.note = "adapter stream magnitude per Cv stayed within a factor of two";
    else
        linearity.classification = "not_linear";
        linearity.note = "adapter stream magnitude per Cv varied by more than a factor of two";
    end
end

function writeSummaryMarkdown(report, path)
    lines = strings(0, 1);
    lines(end+1) = "# Yang adapter Cv activation diagnostic";
    lines(end+1) = "";
    lines(end+1) = "## Run metadata";
    lines(end+1) = sprintf("- Branch: `%s`", report.runIdentity.branch);
    lines(end+1) = sprintf("- Commit: `%s`", report.runIdentity.commitSha);
    lines(end+1) = sprintf("- MATLAB version: `%s`", report.runIdentity.matlabVersion);
    lines(end+1) = sprintf("- Runtime: %.3f s", report.totalRuntimeSec);
    lines(end+1) = "- Dirty/untracked status:";
    lines(end+1) = "```text";
    statusLines = splitlines(report.runIdentity.gitStatusShort);
    lines = [lines(:); statusLines(:)];
    lines(end+1) = "```";
    lines(end+1) = "";

    lines(end+1) = "## Baseline conclusion";
    lines(end+1) = "- The previous accounting run showed low H2 recovery as a real wrapper-ledger outcome, with product dominated by native AD, waste dominated by native BD, and adapters at spectator scale.";
    lines(end+1) = sprintf("- NativeValveCoefficient remains %.3g raw and resolves to %.6g through `params.valScaleFac`; adapter `Cv_directTransfer` remains raw/direct.", ...
        report.baseline.NativeValveCoefficient, report.baseline.resolvedNativeValveCoefficient);
    lines(end+1) = "";

    lines(end+1) = "## One-cycle ladder table";
    tableLines = oneCycleMarkdownTable(report.oneCycleLadder);
    lines = [lines(:); tableLines(:)];
    lines(end+1) = "";

    lines(end+1) = "## Adapter operation details";
    lines(end+1) = adapterDetailsSummary(report);
    lines(end+1) = sprintf("- Low-Cv scaling: `%s`; %s.", ...
        report.interpretation.lowCvLinearity.classification, ...
        report.interpretation.lowCvLinearity.note);
    lines(end+1) = "";

    lines(end+1) = "## Three-cycle confirmation";
    tableLines = threeCycleMarkdownTable(report.threeCycleComparison);
    lines = [lines(:); tableLines(:)];
    lines(end+1) = "";

    lines(end+1) = "## Interpretation";
    lines(end+1) = sprintf("- Category %s: %s.", ...
        report.interpretation.category, report.interpretation.categoryLabel);
    lines(end+1) = sprintf("- Reason: %s.", report.interpretation.reason);
    lines(end+1) = "";

    lines(end+1) = "## Recommendation";
    lines(end+1) = "- " + string(report.interpretation.recommendation);
    writelines(lines, path);
end

function lines = oneCycleMarkdownTable(tbl)
    lines = strings(0, 1);
    lines(end+1) = "| Cv | recovery | ADPP product/total | PP_PU waste/total | adapter internal/total | balance | class | runtime s |";
    lines(end+1) = "|---:|---:|---:|---:|---:|---|---|---:|";
    for i = 1:height(tbl)
        adapterInternal = tbl.ADPP_BF_internal_fraction_of_total_internal(i) + ...
            tbl.PP_PU_internal_fraction_of_total_internal(i);
        lines(end+1) = sprintf("| %.0e | %.6g | %.6g | %.6g | %.6g | %s | %s | %.2f |", ...
            tbl.Cv_directTransfer(i), tbl.H2_recovery(i), ...
            tbl.ADPP_BF_product_fraction_of_total_product(i), ...
            tbl.PP_PU_waste_fraction_of_total_waste(i), adapterInternal, ...
            yesNo(tbl.balancePass(i)), tbl.activation_class(i), ...
            tbl.runtime_seconds(i));
    end
end

function lines = threeCycleMarkdownTable(tbl)
    lines = strings(0, 1);
    cumulative = tbl(tbl.row_scope == "cumulative_3cycle", :);
    lines(end+1) = "| Cv | cumulative recovery | product/feed | waste/feed | bed accumulation/feed | balance | runtime s |";
    lines(end+1) = "|---:|---:|---:|---:|---:|---|---:|";
    for i = 1:height(cumulative)
        lines(end+1) = sprintf("| %.0e | %.6g | %.6g | %.6g | %.6g | %s | %.2f |", ...
            cumulative.Cv_directTransfer(i), cumulative.H2_recovery(i), ...
            cumulative.fraction_feed_to_product(i), ...
            cumulative.fraction_feed_to_waste(i), ...
            cumulative.fraction_feed_to_bed_accumulation(i), ...
            yesNo(cumulative.balance_pass(i)), cumulative.runtime_seconds(i));
    end
end

function text = adapterDetailsSummary(report)
    details = report.adapterOperationDetails;
    if height(details) == 0
        text = "- No adapter operation detail rows were available.";
        return;
    end
    oneCycle = details(details.run_stage == "one_cycle_ladder", :);
    hasPressure = any(oneCycle.pressure_data_available);
    maxProductDelta = max(abs(oneCycle.initial_product_pressure_delta_donor_minus_receiver), [], "omitnan");
    maxFeedDelta = max(abs(oneCycle.initial_feed_pressure_delta_donor_minus_receiver), [], "omitnan");
    maxFlowWarnings = max(oneCycle.flow_sign_warning_count, [], "omitnan");
    text = sprintf("- Adapter pressure diagnostics available: %s. Max initial product-end pressure delta %.6g; max initial feed-end pressure delta %.6g; max flow-sign warnings per adapter operation %.0f.", ...
        yesNo(hasPressure), maxProductDelta, maxFeedDelta, maxFlowWarnings);
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

function pass = cycleBalancePass(simReport, cycleIndex)
    rows = simReport.ledger.balanceRows(simReport.ledger.balanceRows.cycle_index == cycleIndex, :);
    pass = ~isempty(rows) && all(rows.pass);
end

function residual = cycleMaxResidual(simReport, cycleIndex)
    rows = simReport.ledger.balanceRows(simReport.ledger.balanceRows.cycle_index == cycleIndex, :);
    if height(rows) == 0
        residual = NaN;
    else
        residual = max(abs(rows.residual_moles), [], "omitnan");
    end
end

function value = safeRatio(numerator, denominator)
    if isempty(denominator) || ~isfinite(denominator) || abs(denominator) <= eps
        value = NaN;
    else
        value = numerator ./ denominator;
    end
end

function tf = nanPass(value, threshold)
    tf = ~isfinite(value) || value <= threshold;
end

function maxResidual = maxAdapterConservationResidual(simReport)
    values = [];
    for c = 1:numel(simReport.cycleReports)
        ops = simReport.cycleReports{c}.operationReports;
        for k = 1:numel(ops)
            if ~ismember(string(ops(k).operationFamily), ["ADPP_BF", "PP_PU"])
                continue;
            end
            values = [values; collectConservationResiduals(ops(k).runReport)]; %#ok<AGROW>
        end
    end
    values = values(isfinite(values));
    if isempty(values)
        maxResidual = NaN;
    else
        maxResidual = max(abs(values));
    end
end

function maxResidual = maxConservationResidual(runReport)
    values = collectConservationResiduals(runReport);
    values = values(isfinite(values));
    if isempty(values)
        maxResidual = NaN;
    else
        maxResidual = max(abs(values));
    end
end

function values = collectConservationResiduals(runReport)
    values = [];
    if ~isstruct(runReport) || ~isfield(runReport, "conservation") || ...
            ~isstruct(runReport.conservation)
        return;
    end
    cons = runReport.conservation;
    fields = ["donorResidualByComponent", "receiverResidualByComponent", ...
        "pairResidualByComponent", "internalTransferMismatchByComponent"];
    for i = 1:numel(fields)
        name = char(fields(i));
        if isfield(cons, name) && isnumeric(cons.(name))
            values = [values; cons.(name)(:)]; %#ok<AGROW>
        end
    end
end

function count = countAdapterWarnings(simReport, pattern)
    if nargin < 2
        pattern = "";
    end
    count = 0;
    for c = 1:numel(simReport.cycleReports)
        ops = simReport.cycleReports{c}.operationReports;
        for k = 1:numel(ops)
            if ismember(string(ops(k).operationFamily), ["ADPP_BF", "PP_PU"])
                count = count + countWarningsInStrings(ops(k).warnings, pattern);
            end
        end
    end
end

function count = countSanityWarnings(simReport)
    count = 0;
    for c = 1:numel(simReport.cycleReports)
        ops = simReport.cycleReports{c}.operationReports;
        for k = 1:numel(ops)
            if ismember(string(ops(k).operationFamily), ["ADPP_BF", "PP_PU"])
                count = count + countSanityWarningStrings(ops(k).warnings);
            end
        end
    end
end

function count = countWarningsInStrings(warnings, pattern)
    warnings = string(warnings(:));
    warnings = warnings(strlength(warnings) > 0);
    if strlength(string(pattern)) == 0
        count = numel(warnings);
    else
        count = sum(contains(lower(warnings), lower(string(pattern))));
    end
end

function count = countSanityWarningStrings(warnings)
    warnings = lower(string(warnings(:)));
    count = sum(contains(warnings, "nan") | ...
        contains(warnings, "negative") | ...
        contains(warnings, "invalid"));
end

function tf = finalContainerHasNaN(simReport)
    tf = false;
    if ~isstruct(simReport) || ~isfield(simReport, "finalContainer")
        return;
    end
    container = simReport.finalContainer;
    if ~isfield(container, "stateFields")
        return;
    end
    fields = string(container.stateFields(:));
    for i = 1:numel(fields)
        payload = container.(char(fields(i)));
        try
            vec = extractYangStateVector(payload);
            tf = tf || any(isnan(vec(:)));
        catch
            tf = true;
        end
    end
end

function pressure = pressureFields(runReport)
    pressure = struct( ...
        "available", false, ...
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
    pressure.donorInitialFeed = nestedNumeric(pd, ["initial", "donor", "feedEndPressureRatio"]);
    pressure.donorInitialProduct = nestedNumeric(pd, ["initial", "donor", "productEndPressureRatio"]);
    pressure.receiverInitialFeed = nestedNumeric(pd, ["initial", "receiver", "feedEndPressureRatio"]);
    pressure.receiverInitialProduct = nestedNumeric(pd, ["initial", "receiver", "productEndPressureRatio"]);
    pressure.donorTerminalFeed = nestedNumeric(pd, ["terminal", "donor", "feedEndPressureRatio"]);
    pressure.donorTerminalProduct = nestedNumeric(pd, ["terminal", "donor", "productEndPressureRatio"]);
    pressure.receiverTerminalFeed = nestedNumeric(pd, ["terminal", "receiver", "feedEndPressureRatio"]);
    pressure.receiverTerminalProduct = nestedNumeric(pd, ["terminal", "receiver", "productEndPressureRatio"]);
end

function value = effectiveSplitField(runReport, fieldName)
    value = NaN;
    if ~isstruct(runReport) || ~isfield(runReport, "effectiveSplit") || ...
            ~isstruct(runReport.effectiveSplit)
        return;
    end
    split = runReport.effectiveSplit;
    name = char(fieldName);
    if isfield(split, name) && isnumeric(split.(name)) && isscalar(split.(name))
        value = split.(name);
    end
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

function tbl = vertcatTables(tables)
    if isempty(tables)
        tbl = table();
        return;
    end
    tbl = tables{1};
    for i = 2:numel(tables)
        tbl = [tbl; tables{i}]; %#ok<AGROW>
    end
end

function text = yesNo(value)
    if logical(value)
        text = "yes";
    else
        text = "no";
    end
end
