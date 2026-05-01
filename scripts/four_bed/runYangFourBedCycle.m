function [nextContainer, cycleReport] = runYangFourBedCycle(container, templateParams, controls, varargin)
%RUNYANGFOURBEDCYCLE Execute one FI-6 normalized four-bed cycle.

    if nargin < 3
        controls = struct();
    end
    controls = normalizeYangFourBedControls(controls, templateParams);

    parser = inputParser;
    addParameter(parser, 'Manifest', []);
    addParameter(parser, 'PairMap', []);
    addParameter(parser, 'OperationPlan', []);
    addParameter(parser, 'CycleIndex', 1);
    addParameter(parser, 'Ledger', []);
    addParameter(parser, 'AuditDir', "");
    addParameter(parser, 'WriteAdapterAudit', false);
    addParameter(parser, 'NativeRunner', controls.nativeRunner);
    addParameter(parser, 'AdapterValidationOnly', controls.adapterValidationOnly);
    addParameter(parser, 'BalanceAbsTol', controls.balanceAbsTol);
    addParameter(parser, 'BalanceRelTol', controls.balanceRelTol);
    addParameter(parser, 'StopOnOperationWarning', false);
    parse(parser, varargin{:});
    opts = parser.Results;

    manifest = opts.Manifest;
    if isempty(manifest)
        manifest = getYangFourBedScheduleManifest();
    end
    pairMap = opts.PairMap;
    if isempty(pairMap)
        pairMap = getYangDirectTransferPairMap(manifest);
    end
    durations = getYangNormalizedSlotDurations(controls.cycleTimeSec);
    plan = opts.OperationPlan;
    if isempty(plan)
        plan = buildYangFourBedOperationPlan(manifest, pairMap, durations, ...
            'Policy', controls.operationPlanPolicy, ...
            'PairedDurationPolicy', controls.pairedDurationPolicy);
    else
        validation = validateYangFourBedOperationPlan(plan, manifest, pairMap);
        if ~validation.pass
            error('FI6:InvalidOperationPlan', ...
                'Supplied operation plan failed validation: %s', ...
                char(strjoin(validation.failures, " | ")));
        end
    end

    ledger = opts.Ledger;
    if isempty(ledger)
        ledger = makeYangFourBedLedger(controls.componentNames, ...
            'Manifest', manifest, 'PairMap', pairMap, ...
            'LedgerNote', "FI-7 cycle ledger");
    end

    currentContainer = container;
    operationReports = repmat(emptyOperationReport(), 0, 1);
    warnings = plan.warnings(:);
    errors = strings(0, 1);

    for k = 1:numel(plan.operationGroups)
        group = plan.operationGroups(k);
        initialSnapshot = currentContainer;
        selection = makeSelectionForGroup(currentContainer, manifest, pairMap, group);
        tempCase = makeTemporaryCaseForGroup(selection, group);
        initialInventory = computeInventoriesForSelection(selection, currentContainer, templateParams);

        [terminalLocalStates, runReport, ledgerRows, ledgerExtractionReport, auditStatus] = ...
            runOperationAndExtractLedger(tempCase, templateParams, controls, opts, group);

        [updatedContainer, writebackReport] = writeBackYangFourBedStates( ...
            currentContainer, selection, terminalLocalStates, ...
            'Params', templateParams, ...
            'UpdateNote', "FI-6 cycle group " + string(group.operationGroupId));

        terminalInventory = computeInventoriesForSelection(selection, updatedContainer, templateParams);
        inventoryRows = appendYangBedInventoryDeltaRows(group, initialInventory, ...
            terminalInventory, controls, 'CycleIndex', opts.CycleIndex);
        ledgerRows = [ledgerRows; inventoryRows]; %#ok<AGROW>
        ledger = appendRowsToLedger(ledger, ledgerRows);

        opReport = emptyOperationReport();
        opReport.operationGroupIndex = k;
        opReport.operationGroupId = string(group.operationGroupId);
        opReport.operationFamily = string(group.operationFamily);
        opReport.route = string(group.route);
        opReport.participants = string(group.participants(:));
        opReport.sourceCol = group.sourceCol;
        opReport.durationSec = group.durationSec;
        opReport.selectionLocalMap = selection.localMap;
        opReport.runReport = runReport;
        opReport.ledgerExtractionReport = ledgerExtractionReport;
        opReport.inventoryRowsAppended = height(inventoryRows);
        opReport.ledgerRowsAppended = height(ledgerRows);
        opReport.writebackReport = writebackReport;
        opReport.auditStatus = auditStatus;
        opReport.nonParticipantsUnchanged = checkNonParticipantsUnchanged( ...
            initialSnapshot, updatedContainer, string(group.participants(:)));
        opReport.warnings = collectOperationWarnings(group, ledgerExtractionReport, runReport);
        if controls.debugKeepStateHistory
            opReport.stateHistory = struct( ...
                "initialContainer", initialSnapshot, ...
                "finalContainer", updatedContainer);
        end
        operationReports(end+1, 1) = opReport; %#ok<AGROW>

        if ~isempty(opReport.warnings)
            warnings = [warnings; opReport.warnings(:)]; %#ok<AGROW>
            if logical(opts.StopOnOperationWarning)
                error('FI6:OperationWarningStop', ...
                    'Operation %s emitted warnings: %s', ...
                    char(group.operationGroupId), char(strjoin(opReport.warnings, " | ")));
            end
        end

        currentContainer = updatedContainer;
    end

    [balanceRows, balanceSummary] = computeYangLedgerBalances(ledger, ...
        'CycleIndex', opts.CycleIndex, ...
        'AbsTol', opts.BalanceAbsTol, ...
        'RelTol', opts.BalanceRelTol);
    ledger.balanceRows = [ledger.balanceRows; balanceRows];
    performanceMetrics = computeYangPerformanceMetrics(ledger, ...
        'CycleIndex', opts.CycleIndex);
    ledger.metricRows = [ledger.metricRows; performanceMetrics.rows];

    nextContainer = currentContainer;
    cycleReport = struct();
    cycleReport.version = "FI6-FI7-Yang2009-four-bed-cycle-report-v1";
    cycleReport.cycleIndex = opts.CycleIndex;
    cycleReport.initialContainerChecksum = checksumContainer(container, templateParams);
    cycleReport.finalContainerChecksum = checksumContainer(nextContainer, templateParams);
    cycleReport.operationPlan = plan;
    cycleReport.operationReports = operationReports;
    cycleReport.ledger = ledger;
    cycleReport.balanceSummary = balanceSummary;
    cycleReport.performanceMetrics = performanceMetrics;
    cycleReport.warnings = warnings;
    cycleReport.errors = errors;
    cycleReport.architecture = architectureFlags();
end

function [terminalLocalStates, runReport, ledgerRows, extractionReport, auditStatus] = ...
        runOperationAndExtractLedger(tempCase, templateParams, controls, opts, group)
    auditStatus = struct("pass", true, "path", "", "warnings", strings(0, 1));
    switch string(group.route)
        case {"native_single", "native_pair"}
            [terminalLocalStates, runReport] = invokeNativeRunner( ...
                opts.NativeRunner, tempCase, templateParams, controls, group);
            [ledgerRows, extractionReport] = extractYangNativeLedgerRows( ...
                runReport, group, templateParams, controls, ...
                'CycleIndex', opts.CycleIndex);

        case "adapter"
            adapterConfig = makeAdapterConfig(group, controls, opts);
            [terminalLocalStates, runReport] = runYangDirectCouplingAdapter( ...
                tempCase, templateParams, adapterConfig);
            [ledgerRows, extractionReport] = extractYangAdapterLedgerRows( ...
                runReport, group, templateParams, controls, ...
                'CycleIndex', opts.CycleIndex);
            if logical(opts.WriteAdapterAudit)
                auditStatus = writeYangAdapterAuditReport(runReport, string(opts.AuditDir), ...
                    'CycleIndex', opts.CycleIndex, ...
                    'SlotIndex', group.sourceCol, ...
                    'OperationGroupId', string(group.operationGroupId), ...
                    'OperationFamily', string(group.operationFamily), ...
                    'DonorBed', string(group.donorBed), ...
                    'ReceiverBed', string(group.receiverBed), ...
                    'LocalMap', group.localMap, ...
                    'OutputMode', controls.auditOutputMode, ...
                    'IncludeStateHistory', controls.debugKeepStateHistory);
            end

        otherwise
            error('FI6:UnsupportedOperationRoute', ...
                'Unsupported operation route %s.', char(string(group.route)));
    end
end

function [terminalLocalStates, runReport] = invokeNativeRunner(runner, tempCase, templateParams, controls, group)
    if strcmp(func2str(runner), 'runYangTemporaryCase')
        [terminalLocalStates, runReport] = runYangTemporaryCase(tempCase, ...
            'Runner', controls.nativeRunnerMode, ...
            'TemplateParams', templateParams, ...
            'DurationSeconds', group.durationSec);
        return;
    end

    nArgs = nargin(runner);
    if nArgs == 1
        [terminalLocalStates, runReport] = runner(tempCase);
    elseif nArgs == 2
        [terminalLocalStates, runReport] = runner(tempCase, templateParams);
    elseif nArgs == 3
        [terminalLocalStates, runReport] = runner(tempCase, templateParams, controls);
    else
        [terminalLocalStates, runReport] = runner(tempCase, templateParams, controls, group);
    end
end

function adapterConfig = makeAdapterConfig(group, controls, opts)
    adapterConfig = struct();
    adapterConfig.durationSeconds = group.durationSec;
    adapterConfig.componentNames = controls.componentNames;
    adapterConfig.conservationAbsTol = controls.balanceAbsTol;
    adapterConfig.conservationRelTol = controls.balanceRelTol;
    adapterConfig.debugKeepStateHistory = controls.debugKeepStateHistory;
    adapterConfig.validationOnly = logical(opts.AdapterValidationOnly);
    adapterConfig.cycleIndex = opts.CycleIndex;
    adapterConfig.slotIndex = group.sourceCol;
    adapterConfig.operationGroupId = string(group.operationGroupId);

    switch string(group.operationFamily)
        case "PP_PU"
            adapterConfig.directTransferFamily = "PP_PU";
            adapterConfig.Cv_PP_PU_internal = controlValueOrValidationDefault( ...
                controls.Cv_PP_PU_internal, opts.AdapterValidationOnly);
            adapterConfig.Cv_PU_waste = controlValueOrValidationDefault( ...
                controls.Cv_PU_waste, opts.AdapterValidationOnly);
        case "ADPP_BF"
            adapterConfig.directTransferFamily = "ADPP_BF";
            adapterConfig.Cv_ADPP_feed = controlValueOrValidationDefault( ...
                controls.Cv_ADPP_feed, opts.AdapterValidationOnly);
            adapterConfig.Cv_ADPP_product = controlValueOrValidationDefault( ...
                controls.Cv_ADPP_product, opts.AdapterValidationOnly);
            adapterConfig.Cv_ADPP_BF_internal = controlValueOrValidationDefault( ...
                controls.Cv_ADPP_BF_internal, opts.AdapterValidationOnly);
        otherwise
            error('FI6:UnsupportedAdapterFamily', ...
                'No adapter config for operation family %s.', char(group.operationFamily));
    end
end

function value = controlValueOrValidationDefault(value, validationOnly)
    if isfinite(value)
        return;
    end
    if logical(validationOnly)
        value = 0.0;
    else
        error('FI6:MissingAdapterValveControl', ...
            'Adapter valve coefficients must be finite unless AdapterValidationOnly is true.');
    end
end

function selection = makeSelectionForGroup(container, manifest, pairMap, group)
    switch string(group.route)
        case "native_single"
            rows = manifest.bedSteps(manifest.bedSteps.record_id == string(group.localMap.record_id(1)), :);
            if height(rows) ~= 1
                error('FI6:ManifestLookupFailed', ...
                    'Expected one manifest row for record %s.', char(group.localMap.record_id(1)));
            end
            selection = selectYangFourBedSingleState(container, rows);
        otherwise
            pairs = pairMap.transferPairs(pairMap.transferPairs.pair_id == string(group.pairId), :);
            if height(pairs) ~= 1
                error('FI6:PairLookupFailed', ...
                    'Expected one pair-map row for pair %s.', char(group.pairId));
            end
            selection = selectYangFourBedPairStates(container, pairs);
    end
end

function tempCase = makeTemporaryCaseForGroup(selection, group)
    args = {'DurationSeconds', group.durationSec, ...
        'RunnerMode', string(group.route), ...
        'CaseNote', "FI-6 cycle group " + string(group.operationGroupId)};
    if string(selection.selectionType) == "single_bed_operation"
        tempCase = makeYangTemporarySingleCase(selection, args{:});
    else
        tempCase = makeYangTemporaryPairedCase(selection, args{:});
    end
end

function inventories = computeInventoriesForSelection(selection, container, params)
    inventories = struct();
    for i = 1:height(selection.localMap)
        bed = string(selection.localMap.global_bed(i));
        fieldName = string(selection.localMap.state_field(i));
        invField = matlab.lang.makeValidName("bed_" + bed);
        inventories.(invField) = computeYangBedComponentInventory(params, ...
            container.(char(fieldName)));
    end
end

function ledger = appendRowsToLedger(ledger, rows)
    ledger.streamRows = [ledger.streamRows; rows];
    result = validateYangFourBedLedger(ledger);
    if ~result.pass
        error('FI7:InvalidLedgerAfterCycleAppend', ...
            'Cycle ledger failed validation after append: %s', ...
            char(strjoin(result.failures, " | ")));
    end
end

function tf = checkNonParticipantsUnchanged(initialContainer, finalContainer, participants)
    bedLabels = string(initialContainer.bedLabels(:));
    nonParticipants = setdiff(bedLabels, participants, 'stable');
    tf = true;
    for i = 1:numel(nonParticipants)
        fieldName = "state_" + nonParticipants(i);
        tf = tf && isequaln(initialContainer.(char(fieldName)), finalContainer.(char(fieldName)));
    end
end

function warnings = collectOperationWarnings(group, extractionReport, runReport)
    warnings = string(group.warnings(:));
    if isstruct(extractionReport) && isfield(extractionReport, 'warnings')
        warnings = [warnings; string(extractionReport.warnings(:))]; %#ok<AGROW>
    end
    if isstruct(runReport) && isfield(runReport, 'warnings')
        warnings = [warnings; string(runReport.warnings(:))]; %#ok<AGROW>
    end
    warnings = warnings(strlength(warnings) > 0);
end

function checksum = checksumContainer(container, params)
    checksum = struct();
    bedLabels = string(container.bedLabels(:));
    for i = 1:numel(bedLabels)
        fieldName = "state_" + bedLabels(i);
        try
            vec = extractYangStateVector(container.(char(fieldName)), 'Params', params);
            checksum.(char(bedLabels(i))) = struct( ...
                "nValues", numel(vec), ...
                "sum", sum(vec), ...
                "norm", norm(vec));
        catch
            checksum.(char(bedLabels(i))) = struct( ...
                "nValues", NaN, ...
                "sum", NaN, ...
                "norm", NaN);
        end
    end
end

function arch = architectureFlags()
    arch = struct();
    arch.noDynamicInternalTanks = true;
    arch.noSharedHeaderInventory = true;
    arch.noGlobalFourBedRhs = true;
    arch.persistentStateBasis = "physical_adsorber_state_only";
    arch.metricsBasis = "wrapper_external_stream_ledger";
end

function report = emptyOperationReport()
    report = struct();
    report.operationGroupIndex = NaN;
    report.operationGroupId = "";
    report.operationFamily = "";
    report.route = "";
    report.participants = strings(0, 1);
    report.sourceCol = NaN;
    report.durationSec = NaN;
    report.selectionLocalMap = table();
    report.runReport = struct();
    report.ledgerExtractionReport = struct();
    report.inventoryRowsAppended = 0;
    report.ledgerRowsAppended = 0;
    report.writebackReport = struct();
    report.auditStatus = struct();
    report.nonParticipantsUnchanged = false;
    report.warnings = strings(0, 1);
    report.stateHistory = [];
end
