function report = diagnoseYangAdapterEndpointPolicy(varargin)
%DIAGNOSEYANGADAPTERENDPOINTPOLICY Perturb adapter endpoint pressures.
%
% Diagnostic only. This script runs one full Yang four-bed cycle to harvest
% realistic adapter-entry states, then replays selected PP->PU and
% AD&PP->BF temporary adapter cases under endpoint-pressure variants.

    parser = inputParser;
    parser.FunctionName = "diagnoseYangAdapterEndpointPolicy";
    addParameter(parser, "OutputDir", fullfile(pwd, "validation", "reports", ...
        "yang_diagnostics", "adapter_endpoint_policy"), ...
        @(x) ischar(x) || isstring(x));
    addParameter(parser, "ReuseExistingReport", false, ...
        @(x) islogical(x) && isscalar(x));
    parse(parser, varargin{:});
    opts = parser.Results;

    outputDir = string(opts.OutputDir);
    if ~isfolder(outputDir)
        mkdir(outputDir);
    end

    startedAt = datetime("now", "TimeZone", "local");
    runIdentity = collectRunIdentity();
    assertRequiredBranch(runIdentity.branch);

    if opts.ReuseExistingReport
        reportPath = fullfile(outputDir, "endpoint_policy_report.mat");
        if ~isfile(reportPath)
            error('FI8:MissingEndpointPolicyReport', ...
                'Cannot reuse report because %s does not exist.', reportPath);
        end
        loaded = load(reportPath, "report");
        report = loaded.report;
        writeSummaryMarkdown(report, fullfile(outputDir, "summary.md"));
        report.summaryWriteError = "";
        save(reportPath, "report");
        fprintf("Yang adapter endpoint-policy summary regenerated from %s\n", reportPath);
        fprintf("Interpretation: %s\n", report.interpretation.categoryLabel);
        fprintf("Recommendation: %s\n", report.interpretation.recommendation);
        return;
    end

    manifest = getYangFourBedScheduleManifest();
    pairMap = getYangDirectTransferPairMap(manifest);
    [params, controls, initialContainer, baseline] = buildBaseline(manifest, pairMap);

    [simReport, solverOutput, baselineRuntimeSec] = runBaselineOneCycle( ...
        initialContainer, params, controls, manifest, pairMap);

    adapterOps = collectAdapterOperationContexts(simReport, params, pairMap);
    [selectedPpPuOps, selectedAdppBfOps] = selectRequestedOperations(adapterOps);
    selectedContext = operationContextsToTable([selectedPpPuOps; selectedAdppBfOps]);
    writetable(selectedContext, fullfile(outputDir, "selected_operation_context.csv"));

    ppPuVariants = runPpPuEndpointVariants(selectedPpPuOps, params);
    writetable(ppPuVariants, fullfile(outputDir, "pp_pu_endpoint_policy_variants.csv"));

    adppBfVariants = runAdppBfEndpointVariants(selectedAdppBfOps, params);
    writetable(adppBfVariants, fullfile(outputDir, "adpp_bf_endpoint_policy_variants.csv"));

    completedAt = datetime("now", "TimeZone", "local");
    interpretation = interpretEndpointPolicy(ppPuVariants, adppBfVariants);

    report = struct();
    report.version = "Yang-adapter-endpoint-policy-perturbation-diagnostic-v1";
    report.startedAt = startedAt;
    report.completedAt = completedAt;
    report.outputDir = outputDir;
    report.runIdentity = runIdentity;
    report.baseline = baseline;
    report.baselineRuntimeSec = baselineRuntimeSec;
    report.solverOutput = string(solverOutput);
    report.baselineSimReport = simReport;
    report.selectedOperationContext = selectedContext;
    report.ppPuEndpointVariants = ppPuVariants;
    report.adppBfEndpointVariants = adppBfVariants;
    report.interpretation = interpretation;
    report.totalRuntimeSec = seconds(completedAt - startedAt);

    save(fullfile(outputDir, "endpoint_policy_report.mat"), "report");
    try
        writeSummaryMarkdown(report, fullfile(outputDir, "summary.md"));
    catch ME
        report.summaryWriteError = string(getReport(ME, "basic", "hyperlinks", "off"));
        save(fullfile(outputDir, "endpoint_policy_report.mat"), "report");
        writeFallbackSummary(report, fullfile(outputDir, "summary.md"));
    end

    fprintf("Yang adapter endpoint-policy diagnostic wrote %s\n", outputDir);
    fprintf("Interpretation: %s\n", interpretation.categoryLabel);
    fprintf("Recommendation: %s\n", interpretation.recommendation);
end

function assertRequiredBranch(branch)
    if string(branch) ~= "codex/yang"
        error('FI8:WrongBranchForDiagnostic', ...
            'This diagnostic prompt is constrained to branch codex/yang; current branch is %s.', ...
            char(string(branch)));
    end
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
        'Cv_directTransfer', 1e-2, ...
        'ADPP_BF_internalSplitFraction', 1/3, ...
        'balanceAbsTol', 1e-8, ...
        'balanceRelTol', 1e-6, ...
        'debugKeepStateHistory', true);
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
        "InitializationPolicy", "adapter endpoint policy synthetic commissioning state", ...
        "SourceNote", "same two-volume synthetic pattern used by current Yang diagnostics");
end

function [simReport, solverOutput, runtimeSec] = runBaselineOneCycle( ...
        initialContainer, params, controls, manifest, pairMap)
    tic;
    solverOutput = evalc(['simReport = runYangFourBedSimulation(initialContainer, ', ...
        'params, controls, ''MaxCycles'', 1, ''StopAtCss'', false, ', ...
        '''KeepCycleReports'', true, ''Manifest'', manifest, ''PairMap'', pairMap);']);
    runtimeSec = toc;
end

function ops = collectAdapterOperationContexts(simReport, params, pairMap)
    if ~isstruct(simReport) || ~isfield(simReport, "cycleReports") || ...
            isempty(simReport.cycleReports)
        error('FI8:MissingCycleReports', ...
            'The baseline simulation did not retain cycleReports.');
    end

    ops = repmat(operationBundleTemplate(), 0, 1);
    for c = 1:numel(simReport.cycleReports)
        cycleReport = simReport.cycleReports{c};
        opReports = cycleReport.operationReports;
        for k = 1:numel(opReports)
            opReport = opReports(k);
            family = string(opReport.operationFamily);
            if ~ismember(family, ["PP_PU", "ADPP_BF"])
                continue;
            end
            if ~isstruct(opReport.stateHistory) || ...
                    ~isfield(opReport.stateHistory, "initialContainer")
                error('FI8:MissingAdapterEntryState', ...
                    'Operation %s did not retain stateHistory.initialContainer.', ...
                    char(string(opReport.operationGroupId)));
            end

            pairRow = pairMap.transferPairs( ...
                pairMap.transferPairs.pair_id == string(opReport.operationGroupId), :);
            if height(pairRow) ~= 1
                error('FI8:PairLookupFailed', ...
                    'Expected one pair-map row for operation %s.', ...
                    char(string(opReport.operationGroupId)));
            end

            selection = selectYangFourBedPairStates( ...
                opReport.stateHistory.initialContainer, pairRow);
            tempCase = makeYangTemporaryPairedCase(selection, ...
                'DurationSeconds', opReport.durationSec, ...
                'RunnerMode', "wrapper_adapter", ...
                'CaseNote', "endpoint policy perturbation diagnostic");

            pressure = makePressureContext(params, tempCase);
            context = makeOperationContextRow(cycleReport.cycleIndex, opReport, pairRow, pressure);

            bundle = operationBundleTemplate();
            bundle.context = context;
            bundle.tempCase = tempCase;
            bundle.operationReport = opReport;
            ops(end+1, 1) = bundle; %#ok<AGROW>
        end
    end

    if isempty(ops)
        error('FI8:NoAdapterOperationsFound', ...
            'The baseline cycle did not expose PP_PU or ADPP_BF operation reports.');
    end
end

function bundle = operationBundleTemplate()
    bundle = struct();
    bundle.context = operationContextTemplate();
    bundle.tempCase = struct();
    bundle.operationReport = struct();
end

function pressure = makePressureContext(params, tempCase)
    donor = summarizeYangBedPressureProfile(params, tempCase.localStates{1});
    receiver = summarizeYangBedPressureProfile(params, tempCase.localStates{2});
    pressure = struct();
    pressure.initialDonorFeed = donor.feedEndPressureRatio;
    pressure.initialDonorProduct = donor.productEndPressureRatio;
    pressure.initialReceiverFeed = receiver.feedEndPressureRatio;
    pressure.initialReceiverProduct = receiver.productEndPressureRatio;
    pressure.initialProductDeltaDonorMinusReceiver = ...
        donor.productEndPressureRatio - receiver.productEndPressureRatio;
    pressure.initialFeedDeltaDonorMinusReceiver = ...
        donor.feedEndPressureRatio - receiver.feedEndPressureRatio;
end

function row = makeOperationContextRow(cycleIndex, opReport, pairRow, pressure)
    row = operationContextTemplate();
    row.cycle_index = cycleIndex;
    row.operation_group_id = string(opReport.operationGroupId);
    row.operation_family = string(opReport.operationFamily);
    row.pair_id = string(pairRow.pair_id(1));
    row.donor_bed = string(pairRow.donor_bed(1));
    row.receiver_bed = string(pairRow.receiver_bed(1));
    row.donor_source_col = pairRow.donor_source_col(1);
    row.receiver_source_col = pairRow.receiver_source_col(1);
    row.duration_sec = opReport.durationSec;
    row.initial_donor_feed_pressure_ratio = pressure.initialDonorFeed;
    row.initial_donor_product_pressure_ratio = pressure.initialDonorProduct;
    row.initial_receiver_feed_pressure_ratio = pressure.initialReceiverFeed;
    row.initial_receiver_product_pressure_ratio = pressure.initialReceiverProduct;
    row.initial_product_pressure_delta_donor_minus_receiver = ...
        pressure.initialProductDeltaDonorMinusReceiver;
    row.initial_feed_pressure_delta_donor_minus_receiver = ...
        pressure.initialFeedDeltaDonorMinusReceiver;
    row.selection_reason = "";
end

function row = operationContextTemplate()
    row = struct( ...
        "cycle_index", NaN, ...
        "operation_group_id", "", ...
        "operation_family", "", ...
        "pair_id", "", ...
        "donor_bed", "", ...
        "receiver_bed", "", ...
        "donor_source_col", NaN, ...
        "receiver_source_col", NaN, ...
        "duration_sec", NaN, ...
        "initial_donor_feed_pressure_ratio", NaN, ...
        "initial_donor_product_pressure_ratio", NaN, ...
        "initial_receiver_feed_pressure_ratio", NaN, ...
        "initial_receiver_product_pressure_ratio", NaN, ...
        "initial_product_pressure_delta_donor_minus_receiver", NaN, ...
        "initial_feed_pressure_delta_donor_minus_receiver", NaN, ...
        "selection_reason", "");
end

function [selectedPpPu, selectedAdppBf] = selectRequestedOperations(adapterOps)
    selectedPpPu = selectFamilyOperations(adapterOps, "PP_PU", ...
        ["PP_PU-A-to-D"; "PP_PU-B-to-A"; "PP_PU-C-to-B"]);
    selectedAdppBf = selectFamilyOperations(adapterOps, "ADPP_BF", ...
        ["ADPP_BF-A-to-B"; "ADPP_BF-D-to-A"]);
end

function selected = selectFamilyOperations(adapterOps, family, requestedIds)
    families = operationFamilies(adapterOps);
    ids = operationIds(adapterOps);
    deltas = operationProductDeltas(adapterOps);
    familyIdx = find(families == family);
    selectedIdx = zeros(0, 1);

    for i = 1:numel(requestedIds)
        idx = find(ids == requestedIds(i), 1);
        if ~isempty(idx)
            adapterOps(idx).context.selection_reason = "requested_by_prompt";
            selectedIdx(end+1, 1) = idx; %#ok<AGROW>
        end
    end

    missingRequested = numel(selectedIdx) < numel(requestedIds);
    if missingRequested || isempty(selectedIdx)
        positiveCandidates = familyIdx(deltas(familyIdx) > 0);
        negativeCandidates = familyIdx(deltas(familyIdx) < 0);
        if ~isempty(positiveCandidates) && ~any(deltas(selectedIdx) > 0)
            [~, local] = max(deltas(positiveCandidates));
            idx = positiveCandidates(local);
            adapterOps(idx).context.selection_reason = "fallback_positive_product_delta";
            selectedIdx(end+1, 1) = idx; %#ok<AGROW>
        end
        if ~isempty(negativeCandidates) && ~any(deltas(selectedIdx) < 0)
            [~, local] = min(deltas(negativeCandidates));
            idx = negativeCandidates(local);
            adapterOps(idx).context.selection_reason = "fallback_negative_product_delta";
            selectedIdx(end+1, 1) = idx; %#ok<AGROW>
        end
    end

    selectedIdx = unique(selectedIdx, "stable");
    if isempty(selectedIdx)
        error('FI8:NoSelectedAdapterOperations', ...
            'No %s operations could be selected for endpoint-policy diagnostics.', ...
            char(family));
    end
    selected = adapterOps(selectedIdx);
end

function values = operationIds(ops)
    values = strings(numel(ops), 1);
    for i = 1:numel(ops)
        values(i) = ops(i).context.operation_group_id;
    end
end

function values = operationFamilies(ops)
    values = strings(numel(ops), 1);
    for i = 1:numel(ops)
        values(i) = ops(i).context.operation_family;
    end
end

function values = operationProductDeltas(ops)
    values = NaN(numel(ops), 1);
    for i = 1:numel(ops)
        values(i) = ops(i).context.initial_product_pressure_delta_donor_minus_receiver;
    end
end

function tbl = operationContextsToTable(ops)
    rows = repmat(operationContextTemplate(), numel(ops), 1);
    for i = 1:numel(ops)
        rows(i) = ops(i).context;
    end
    if isempty(rows)
        tbl = struct2table(repmat(operationContextTemplate(), 0, 1));
    else
        tbl = struct2table(rows);
    end
end

function tbl = runPpPuEndpointVariants(ops, params)
    rows = repmat(ppPuVariantTemplate(), 0, 1);
    [lowRatio, lowBasis] = lowPressureRatio(params);
    for i = 1:numel(ops)
        ctx = ops(i).context;
        values = [
            lowRatio
            0.50
            0.75
            0.90
            ctx.initial_receiver_feed_pressure_ratio
        ];
        labels = [
            "current_low_pressure_basis"
            "receiver_waste_0p50"
            "receiver_waste_0p75"
            "receiver_waste_0p90"
            "initial_receiver_feed_pressure"
        ];
        bases = [
            lowBasis
            "diagnostic_override"
            "diagnostic_override"
            "diagnostic_override"
            "diagnostic_initial_receiver_feed_pressure"
        ];
        [values, labels, bases] = uniqueNumericVariants(values, labels, bases, 1e-6);
        for v = 1:numel(values)
            rows(end+1, 1) = runOnePpPuVariant(ops(i), params, ...
                values(v), labels(v), bases(v)); %#ok<AGROW>
        end
    end
    tbl = struct2table(rows);
end

function row = runOnePpPuVariant(op, params, receiverWastePressureRatio, label, basis)
    ctx = op.context;
    row = ppPuVariantTemplate();
    row.operation_group_id = ctx.operation_group_id;
    row.variant_label = string(label);
    row.receiverWastePressureRatio = receiverWastePressureRatio;
    row.receiverWastePressureBasis = string(basis);
    row.initial_donor_product_pressure_ratio = ctx.initial_donor_product_pressure_ratio;
    row.initial_receiver_product_pressure_ratio = ctx.initial_receiver_product_pressure_ratio;
    row.initial_receiver_feed_pressure_ratio = ctx.initial_receiver_feed_pressure_ratio;
    row.initial_product_pressure_delta_donor_minus_receiver = ...
        ctx.initial_product_pressure_delta_donor_minus_receiver;

    config = makePpPuAdapterConfig(ctx, receiverWastePressureRatio);
    try
        [~, adapterReport] = runYangDirectCouplingAdapter(op.tempCase, params, config);
        [flow, unitBasis] = selectFlowBasis(adapterReport);
        h2 = h2ComponentIndex(adapterReport.componentNames);
        row.flow_unit_basis = unitBasis;
        row.total_internal_out_H2 = getVectorComponent(flow, "internalTransferOutByComponent", h2);
        row.total_internal_in_H2 = getVectorComponent(flow, "internalTransferInByComponent", h2);
        row.total_external_waste_H2 = getVectorComponent(flow, "externalWasteByComponent", h2);
        row.waste_to_internal_H2_ratio = safeRatio( ...
            row.total_external_waste_H2, row.total_internal_out_H2);
        row.waste_when_internal_near_zero = ...
            row.total_internal_out_H2 < 1e-10 && row.total_external_waste_H2 > 1e-8;
        row.terminal_receiver_feed_pressure_ratio = ...
            terminalPressure(adapterReport, "receiver", "feed");
        row.max_conservation_residual = maxConservationResidual(adapterReport);
        row.n_adapter_warnings = countReportWarnings(adapterReport);
        row.n_sanity_warnings = countSanityWarnings(adapterReport);
        row.run_completed = true;
    catch ME
        row.run_completed = false;
        row.run_error = string(getReport(ME, "basic", "hyperlinks", "off"));
    end
end

function row = ppPuVariantTemplate()
    row = struct( ...
        "operation_group_id", "", ...
        "variant_label", "", ...
        "receiverWastePressureRatio", NaN, ...
        "receiverWastePressureBasis", "", ...
        "initial_donor_product_pressure_ratio", NaN, ...
        "initial_receiver_product_pressure_ratio", NaN, ...
        "initial_receiver_feed_pressure_ratio", NaN, ...
        "initial_product_pressure_delta_donor_minus_receiver", NaN, ...
        "total_internal_out_H2", NaN, ...
        "total_internal_in_H2", NaN, ...
        "total_external_waste_H2", NaN, ...
        "waste_to_internal_H2_ratio", NaN, ...
        "waste_when_internal_near_zero", false, ...
        "terminal_receiver_feed_pressure_ratio", NaN, ...
        "max_conservation_residual", NaN, ...
        "n_adapter_warnings", NaN, ...
        "n_sanity_warnings", NaN, ...
        "flow_unit_basis", "", ...
        "run_completed", false, ...
        "run_error", "");
end

function config = makePpPuAdapterConfig(ctx, receiverWastePressureRatio)
    config = struct();
    config.directTransferFamily = "PP_PU";
    config.durationSeconds = ctx.duration_sec;
    config.durationDimless = [];
    config.Cv_directTransfer = 1e-2;
    config.receiverWastePressureRatio = receiverWastePressureRatio;
    config.receiverWastePressureBasis = "diagnostic_override";
    config.receiverWastePressureClass = "diagnostic_override";
    config.allowReverseInternalFlow = false;
    config.allowReverseWasteFlow = false;
    config.componentNames = ["H2"; "CO2"];
    config.conservationAbsTol = 1e-8;
    config.conservationRelTol = 1e-6;
    config.debugKeepStateHistory = false;
    config.validationOnly = false;
    config.cycleIndex = ctx.cycle_index;
    config.slotIndex = ctx.donor_source_col;
    config.operationGroupId = ctx.operation_group_id;
end

function tbl = runAdppBfEndpointVariants(ops, params)
    rows = repmat(adppBfVariantTemplate(), 0, 1);
    [defaultProductRatio, defaultProductBasis] = defaultProductPressureRatio(params);
    [lowRatio, lowBasis] = lowPressureRatio(params);
    [feedRatio, feedBasis] = defaultFeedPressureRatio(params);
    for i = 1:numel(ops)
        values = [
            defaultProductRatio
            0.90
            0.75
            0.50
            lowRatio
        ];
        labels = [
            "current_default"
            "external_product_0p90"
            "external_product_0p75"
            "external_product_0p50"
            "external_product_low_pressure"
        ];
        bases = [
            defaultProductBasis
            "diagnostic_override"
            "diagnostic_override"
            "diagnostic_override"
            lowBasis
        ];
        [values, labels, bases] = uniqueNumericVariants(values, labels, bases, 1e-6);
        for v = 1:numel(values)
            rows(end+1, 1) = runOneAdppBfVariant(ops(i), params, ...
                values(v), labels(v), bases(v), feedRatio, feedBasis); %#ok<AGROW>
        end
    end
    tbl = struct2table(rows);
end

function row = runOneAdppBfVariant(op, params, externalProductPressureRatio, ...
        label, basis, feedPressureRatio, feedBasis)
    ctx = op.context;
    row = adppBfVariantTemplate();
    row.operation_group_id = ctx.operation_group_id;
    row.variant_label = string(label);
    row.externalProductPressureRatio = externalProductPressureRatio;
    row.externalProductPressureBasis = string(basis);
    row.feedPressureRatio = feedPressureRatio;
    row.feedPressureBasis = string(feedBasis);
    row.initial_donor_product_pressure_ratio = ctx.initial_donor_product_pressure_ratio;
    row.initial_receiver_product_pressure_ratio = ctx.initial_receiver_product_pressure_ratio;
    row.initial_donor_feed_pressure_ratio = ctx.initial_donor_feed_pressure_ratio;
    row.initial_product_pressure_delta_donor_minus_receiver = ...
        ctx.initial_product_pressure_delta_donor_minus_receiver;
    row.initial_feed_pressure_delta_to_feed_source = ...
        feedPressureRatio - ctx.initial_donor_feed_pressure_ratio;

    config = makeAdppBfAdapterConfig(ctx, externalProductPressureRatio, ...
        feedPressureRatio, feedBasis);
    try
        [~, adapterReport] = runYangDirectCouplingAdapter(op.tempCase, params, config);
        [flow, unitBasis] = selectFlowBasis(adapterReport);
        h2 = h2ComponentIndex(adapterReport.componentNames);
        row.flow_unit_basis = unitBasis;
        row.total_external_feed_H2 = getVectorComponent(flow, "externalFeedByComponent", h2);
        row.total_external_product_H2 = getVectorComponent(flow, "externalProductByComponent", h2);
        row.total_internal_out_H2 = getVectorComponent(flow, "internalTransferOutByComponent", h2);
        row.product_to_feed_H2_ratio = safeRatio( ...
            row.total_external_product_H2, row.total_external_feed_H2);
        row.internal_to_feed_H2_ratio = safeRatio( ...
            row.total_internal_out_H2, row.total_external_feed_H2);
        row.effective_split_H2 = effectiveSplitH2(adapterReport);
        row.terminal_donor_product_pressure_ratio = ...
            terminalPressure(adapterReport, "donor", "product");
        row.terminal_receiver_product_pressure_ratio = ...
            terminalPressure(adapterReport, "receiver", "product");
        row.max_conservation_residual = maxConservationResidual(adapterReport);
        row.n_adapter_warnings = countReportWarnings(adapterReport);
        row.n_sanity_warnings = countSanityWarnings(adapterReport);
        row.run_completed = true;
    catch ME
        row.run_completed = false;
        row.run_error = string(getReport(ME, "basic", "hyperlinks", "off"));
    end
end

function row = adppBfVariantTemplate()
    row = struct( ...
        "operation_group_id", "", ...
        "variant_label", "", ...
        "externalProductPressureRatio", NaN, ...
        "externalProductPressureBasis", "", ...
        "feedPressureRatio", NaN, ...
        "feedPressureBasis", "", ...
        "initial_donor_product_pressure_ratio", NaN, ...
        "initial_receiver_product_pressure_ratio", NaN, ...
        "initial_donor_feed_pressure_ratio", NaN, ...
        "initial_product_pressure_delta_donor_minus_receiver", NaN, ...
        "initial_feed_pressure_delta_to_feed_source", NaN, ...
        "total_external_feed_H2", NaN, ...
        "total_external_product_H2", NaN, ...
        "total_internal_out_H2", NaN, ...
        "product_to_feed_H2_ratio", NaN, ...
        "internal_to_feed_H2_ratio", NaN, ...
        "effective_split_H2", NaN, ...
        "terminal_donor_product_pressure_ratio", NaN, ...
        "terminal_receiver_product_pressure_ratio", NaN, ...
        "max_conservation_residual", NaN, ...
        "n_adapter_warnings", NaN, ...
        "n_sanity_warnings", NaN, ...
        "flow_unit_basis", "", ...
        "run_completed", false, ...
        "run_error", "");
end

function config = makeAdppBfAdapterConfig(ctx, externalProductPressureRatio, ...
        feedPressureRatio, feedBasis)
    config = struct();
    config.directTransferFamily = "ADPP_BF";
    config.durationSeconds = ctx.duration_sec;
    config.durationDimless = [];
    config.Cv_directTransfer = 1e-2;
    config.ADPP_BF_internalSplitFraction = 1/3;
    config.externalProductPressureRatio = externalProductPressureRatio;
    config.externalProductPressureBasis = "diagnostic_override";
    config.feedPressureRatio = feedPressureRatio;
    config.feedPressureBasis = feedBasis;
    config.allowReverseFeedFlow = false;
    config.allowReverseProductFlow = false;
    config.allowReverseInternalFlow = false;
    config.componentNames = ["H2"; "CO2"];
    config.conservationAbsTol = 1e-8;
    config.conservationRelTol = 1e-6;
    config.debugKeepStateHistory = false;
    config.validationOnly = false;
    config.cycleIndex = ctx.cycle_index;
    config.slotIndex = ctx.donor_source_col;
    config.operationGroupId = ctx.operation_group_id;
end

function [values, labels, bases] = uniqueNumericVariants(values, labels, bases, tol)
    keep = false(numel(values), 1);
    kept = zeros(0, 1);
    for i = 1:numel(values)
        value = values(i);
        if ~isfinite(value)
            continue;
        end
        if isempty(kept) || all(abs(kept - value) > tol)
            keep(i) = true;
            kept(end+1, 1) = value; %#ok<AGROW>
        end
    end
    values = values(keep);
    labels = labels(keep);
    bases = bases(keep);
end

function [ratio, basis] = lowPressureRatio(params)
    if isfield(params, 'presColLow') && isfield(params, 'presColHigh') && ...
            ~isempty(params.presColLow) && ~isempty(params.presColHigh)
        ratio = params.presColLow ./ params.presColHigh;
        basis = "params.presColLow/params.presColHigh";
    elseif isfield(params, 'pRat') && ~isempty(params.pRat)
        ratio = params.pRat;
        basis = "params.pRat";
    else
        error('FI8:MissingLowPressureBasis', ...
            'Could not resolve low-pressure ratio from params.');
    end
end

function [ratio, basis] = defaultProductPressureRatio(params)
    if isfield(params, 'pRatRa') && ~isempty(params.pRatRa)
        ratio = params.pRatRa;
        basis = "params.pRatRa";
    else
        ratio = 1.0;
        basis = "dimensionless_high_pressure_product_default_from_template.presColHigh";
    end
end

function [ratio, basis] = defaultFeedPressureRatio(params)
    if isfield(params, 'pRatFe') && ~isempty(params.pRatFe)
        ratio = params.pRatFe;
        basis = "params.pRatFe";
    else
        ratio = 1.0;
        basis = "dimensionless_high_pressure_default_from_template.presColHigh";
    end
end

function [flow, unitBasis] = selectFlowBasis(adapterReport)
    flow = struct();
    unitBasis = "";
    if isstruct(adapterReport) && isfield(adapterReport, "flowReport") && ...
            isstruct(adapterReport.flowReport)
        fr = adapterReport.flowReport;
        if isfield(fr, "moles") && isstruct(fr.moles) && ...
                flowBasisAvailable(fr.moles)
            flow = fr.moles;
            unitBasis = string(fr.moles.unitBasis);
            return;
        end
        if isfield(fr, "native") && isstruct(fr.native)
            flow = fr.native;
            unitBasis = string(fr.native.unitBasis);
            return;
        end
    end
    if isfield(adapterReport, "flows") && isstruct(adapterReport.flows)
        flow = adapterReport.flows;
        unitBasis = string(adapterReport.flows.unitBasis);
    end
end

function tf = flowBasisAvailable(flow)
    names = string(fieldnames(flow));
    tf = false;
    for i = 1:numel(names)
        name = char(names(i));
        if isnumeric(flow.(name)) && ~isempty(flow.(name))
            tf = true;
            return;
        end
    end
end

function idx = h2ComponentIndex(componentNames)
    names = string(componentNames(:));
    idx = find(names == "H2", 1);
    if isempty(idx)
        idx = 1;
    end
end

function value = getVectorComponent(s, fieldName, index)
    value = 0;
    name = char(fieldName);
    if isstruct(s) && isfield(s, name) && isnumeric(s.(name)) && ...
            numel(s.(name)) >= index
        values = s.(name);
        value = values(index);
    end
end

function value = terminalPressure(adapterReport, bedRole, endpoint)
    value = NaN;
    if ~isstruct(adapterReport) || ~isfield(adapterReport, "pressureDiagnostics")
        return;
    end
    pd = adapterReport.pressureDiagnostics;
    name = char(string(endpoint) + "EndPressureRatio");
    role = char(string(bedRole));
    if isfield(pd, "terminal") && isstruct(pd.terminal) && ...
            isfield(pd.terminal, role) && isstruct(pd.terminal.(role)) && ...
            isfield(pd.terminal.(role), name)
        value = pd.terminal.(role).(name);
    end
end

function maxResidual = maxConservationResidual(report)
    values = [];
    if isstruct(report) && isfield(report, "conservation") && ...
            isstruct(report.conservation)
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

function count = countReportWarnings(report)
    count = 0;
    if isstruct(report) && isfield(report, "warnings")
        warnings = string(report.warnings(:));
        count = sum(strlength(warnings) > 0);
    end
end

function count = countSanityWarnings(report)
    count = 0;
    if isstruct(report) && isfield(report, "sanity") && ...
            isstruct(report.sanity) && isfield(report.sanity, "warnings")
        warnings = string(report.sanity.warnings(:));
        count = sum(strlength(warnings) > 0);
    elseif isstruct(report) && isfield(report, "warnings")
        warnings = lower(string(report.warnings(:)));
        count = sum(contains(warnings, "nan") | ...
            contains(warnings, "negative") | contains(warnings, "invalid"));
    end
end

function value = effectiveSplitH2(report)
    value = NaN;
    if isstruct(report) && isfield(report, "effectiveSplit") && ...
            isstruct(report.effectiveSplit)
        split = report.effectiveSplit;
        if isfield(split, "H2") && isnumeric(split.H2) && isscalar(split.H2)
            value = split.H2;
        elseif isfield(split, "byComponent") && isnumeric(split.byComponent) && ...
                ~isempty(split.byComponent)
            value = split.byComponent(1);
        elseif isfield(split, "total") && isnumeric(split.total) && isscalar(split.total)
            value = split.total;
        end
    end
end

function interpretation = interpretEndpointPolicy(ppPuRows, adppBfRows)
    ppSuspect = any(ppPuRows.run_completed & ...
        ppPuRows.variant_label == "current_low_pressure_basis" & ...
        ppPuRows.waste_when_internal_near_zero);
    adppSuspect = detectAdppBfSuppression(adppBfRows);

    interpretation = struct();
    interpretation.ppPuWastePolicySuspect = ppSuspect;
    interpretation.adppBfProductBackpressureSuspect = adppSuspect;
    interpretation.ppPuReason = explainPpPu(ppPuRows, ppSuspect);
    interpretation.adppBfReason = explainAdppBf(adppBfRows, adppSuspect);

    if ppSuspect && adppSuspect
        interpretation.category = "C";
        interpretation.categoryLabel = "C. Both endpoint policies are suspect.";
        interpretation.recommendation = ...
            "Prototype isolated endpoint-policy fixes starting with PP_PU receiver-waste gating, then repeat this diagnostic before touching ADPP_BF.";
    elseif ppSuspect
        interpretation.category = "A";
        interpretation.categoryLabel = "A. PP_PU waste policy is the main suspect.";
        interpretation.recommendation = ...
            "Prototype a PP_PU receiver-waste policy that gates feed-end waste on actual purge arrival, then rerun the one-cycle adapter endpoint diagnostic.";
    elseif adppSuspect
        interpretation.category = "B";
        interpretation.categoryLabel = "B. ADPP_BF product backpressure policy is the main suspect.";
        interpretation.recommendation = ...
            "Prototype an ADPP_BF external-product backpressure override and rerun the one-cycle adapter endpoint diagnostic.";
    else
        interpretation.category = "D";
        interpretation.categoryLabel = "D. Endpoint policies are not the main issue.";
        interpretation.recommendation = ...
            "Stop endpoint-pressure perturbations and inspect adapter state accounting versus native-slot dominance.";
    end
end

function tf = detectAdppBfSuppression(rows)
    tf = false;
    if height(rows) == 0
        return;
    end
    ids = unique(rows.operation_group_id, "stable");
    for i = 1:numel(ids)
        opRows = rows(rows.operation_group_id == ids(i) & rows.run_completed, :);
        current = opRows(opRows.variant_label == "current_default", :);
        if height(current) ~= 1
            continue;
        end
        lower = opRows(opRows.externalProductPressureRatio < ...
            current.externalProductPressureRatio(1) - 1e-6, :);
        lower = lower(lower.max_conservation_residual <= 1e-6 & ...
            lower.n_sanity_warnings == 0, :);
        if height(lower) == 0
            continue;
        end
        currentProduct = current.total_external_product_H2(1);
        bestProduct = max(lower.total_external_product_H2, [], "omitnan");
        absoluteIncrease = bestProduct - currentProduct;
        if (currentProduct <= 1e-10 && bestProduct > 1e-8) || ...
                (absoluteIncrease > 1e-8 && bestProduct > 2.0 * max(currentProduct, eps))
            tf = true;
            return;
        end
    end
end

function text = explainPpPu(rows, isSuspect)
    current = rows(rows.variant_label == "current_low_pressure_basis", :);
    nExtra = sum(current.waste_when_internal_near_zero & current.run_completed);
    if isSuspect
        text = sprintf(['%d current low-pressure PP_PU variant row(s) produced ' ...
            'waste H2 while internal H2 was below the near-zero threshold.'], nExtra);
    else
        text = "No current low-pressure PP_PU variant row met the near-zero-internal waste criterion.";
    end
end

function text = explainAdppBf(rows, isSuspect)
    if isSuspect
        text = "At least one lower external-product-pressure ADPP_BF variant sharply increased product H2 without a conservation or sanity failure.";
    else
        text = "Lowering ADPP_BF external product pressure did not meet the diagnostic sharp-increase criterion.";
    end
end

function writeSummaryMarkdown(report, path)
    lines = strings(0, 1);
    lines(end+1) = "# Yang adapter endpoint-policy perturbation diagnostic";
    lines(end+1) = "";
    lines(end+1) = "## Run metadata";
    lines(end+1) = sprintf("- branch: `%s`", report.runIdentity.branch);
    lines(end+1) = sprintf("- commit: `%s`", report.runIdentity.commitSha);
    lines(end+1) = sprintf("- MATLAB version: `%s`", report.runIdentity.matlabVersion);
    lines(end+1) = sprintf("- runtime: %.3f s", report.totalRuntimeSec);
    lines(end+1) = "- dirty/untracked status:";
    lines(end+1) = "```text";
    statusLines = splitlines(report.runIdentity.gitStatusShort);
    lines = [lines(:); statusLines(:)]; %#ok<AGROW>
    lines(end+1) = "```";
    lines(end+1) = "";

    lines(end+1) = "## Prior finding";
    lines(end+1) = "- The prior `adapter_cv_activation` run found that `Cv_directTransfer = 1e-2` increased adapter streams but slightly reduced cumulative H2 recovery, with waste/feed increasing and bed accumulation/feed decreasing.";
    lines(end+1) = "";

    lines(end+1) = "## Selected operation context";
    tableLines = contextMarkdownTable(report.selectedOperationContext);
    lines = [lines(:); tableLines(:)]; %#ok<AGROW>
    lines(end+1) = "";

    lines(end+1) = "## PP_PU endpoint variants";
    tableLines = ppPuMarkdownTable(report.ppPuEndpointVariants);
    lines = [lines(:); tableLines(:)]; %#ok<AGROW>
    lines(end+1) = "";

    lines(end+1) = "## ADPP_BF endpoint variants";
    tableLines = adppBfMarkdownTable(report.adppBfEndpointVariants);
    lines = [lines(:); tableLines(:)]; %#ok<AGROW>
    lines(end+1) = "";

    lines(end+1) = "## Interpretation";
    lines(end+1) = "- " + string(report.interpretation.categoryLabel);
    lines(end+1) = "- PP_PU: " + string(report.interpretation.ppPuReason);
    lines(end+1) = "- ADPP_BF: " + string(report.interpretation.adppBfReason);
    lines(end+1) = "";

    lines(end+1) = "## Recommendation";
    lines(end+1) = "- " + string(report.interpretation.recommendation);

    writelines(lines, path);
end

function writeFallbackSummary(report, path)
    lines = strings(0, 1);
    lines(end+1) = "# Yang adapter endpoint-policy perturbation diagnostic";
    lines(end+1) = "";
    lines(end+1) = "Summary formatting failed, but the CSV and MAT artifacts were written.";
    if isfield(report, "summaryWriteError")
        lines(end+1) = "";
        lines(end+1) = "```text";
        lines = [lines(:); splitlines(report.summaryWriteError)]; %#ok<AGROW>
        lines(end+1) = "```";
    end
    writelines(lines, path);
end

function lines = contextMarkdownTable(tbl)
    lines = strings(0, 1);
    lines(end+1) = "| operation | family | donor->receiver | product delta | donor product P | receiver product P | receiver feed P | reason |";
    lines(end+1) = "|---|---|---|---:|---:|---:|---:|---|";
    for i = 1:height(tbl)
        lines(end+1) = sprintf("| %s | %s | %s->%s | %.6g | %.6g | %.6g | %.6g | %s |", ...
            tbl.operation_group_id(i), tbl.operation_family(i), ...
            tbl.donor_bed(i), tbl.receiver_bed(i), ...
            tbl.initial_product_pressure_delta_donor_minus_receiver(i), ...
            tbl.initial_donor_product_pressure_ratio(i), ...
            tbl.initial_receiver_product_pressure_ratio(i), ...
            tbl.initial_receiver_feed_pressure_ratio(i), ...
            tbl.selection_reason(i));
    end
end

function lines = ppPuMarkdownTable(tbl)
    lines = strings(0, 1);
    lines(end+1) = "| operation | variant | waste P | internal H2 | waste H2 | waste/internal | near-zero internal waste | residual | warnings |";
    lines(end+1) = "|---|---|---:|---:|---:|---:|---|---:|---:|";
    for i = 1:height(tbl)
        lines(end+1) = sprintf("| %s | %s | %.6g | %.6g | %.6g | %.6g | %s | %.3g | %.0f |", ...
            tbl.operation_group_id(i), tbl.variant_label(i), ...
            tbl.receiverWastePressureRatio(i), ...
            tbl.total_internal_out_H2(i), ...
            tbl.total_external_waste_H2(i), ...
            tbl.waste_to_internal_H2_ratio(i), ...
            yesNo(tbl.waste_when_internal_near_zero(i)), ...
            tbl.max_conservation_residual(i), ...
            tbl.n_adapter_warnings(i));
    end
end

function lines = adppBfMarkdownTable(tbl)
    lines = strings(0, 1);
    lines(end+1) = "| operation | variant | product P | feed H2 | product H2 | internal H2 | product/feed | internal/feed | residual | warnings |";
    lines(end+1) = "|---|---|---:|---:|---:|---:|---:|---:|---:|---:|";
    for i = 1:height(tbl)
        lines(end+1) = sprintf("| %s | %s | %.6g | %.6g | %.6g | %.6g | %.6g | %.6g | %.3g | %.0f |", ...
            tbl.operation_group_id(i), tbl.variant_label(i), ...
            tbl.externalProductPressureRatio(i), ...
            tbl.total_external_feed_H2(i), ...
            tbl.total_external_product_H2(i), ...
            tbl.total_internal_out_H2(i), ...
            tbl.product_to_feed_H2_ratio(i), ...
            tbl.internal_to_feed_H2_ratio(i), ...
            tbl.max_conservation_residual(i), ...
            tbl.n_adapter_warnings(i));
    end
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

function value = safeRatio(numerator, denominator)
    if isempty(denominator) || ~isfinite(denominator) || abs(denominator) <= eps
        value = NaN;
    else
        value = numerator ./ denominator;
    end
end

function text = yesNo(value)
    if logical(value)
        text = "yes";
    else
        text = "no";
    end
end
