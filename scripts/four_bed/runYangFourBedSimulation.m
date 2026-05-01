function simReport = runYangFourBedSimulation(initialContainer, templateParams, controls, varargin)
%RUNYANGFOURBEDSIMULATION Repeat FI-6 cycles and compute CSS plumbing.

    if nargin < 3
        controls = struct();
    end
    controls = normalizeYangFourBedControls(controls, templateParams);

    parser = inputParser;
    addParameter(parser, 'MaxCycles', 1);
    addParameter(parser, 'StopAtCss', false);
    addParameter(parser, 'CssAbsTol', controls.cssAbsTol);
    addParameter(parser, 'CssRelTol', controls.cssRelTol);
    addParameter(parser, 'Ledger', []);
    addParameter(parser, 'AuditDir', "");
    addParameter(parser, 'Manifest', []);
    addParameter(parser, 'PairMap', []);
    addParameter(parser, 'OperationPlan', []);
    addParameter(parser, 'WriteAdapterAudit', false);
    addParameter(parser, 'NativeRunner', controls.nativeRunner);
    addParameter(parser, 'AdapterValidationOnly', controls.adapterValidationOnly);
    addParameter(parser, 'KeepCycleReports', true);
    parse(parser, varargin{:});
    opts = parser.Results;

    validateattributes(opts.MaxCycles, {'numeric'}, ...
        {'scalar', 'integer', 'positive'}, mfilename, 'MaxCycles');

    manifest = opts.Manifest;
    if isempty(manifest)
        manifest = getYangFourBedScheduleManifest();
    end
    pairMap = opts.PairMap;
    if isempty(pairMap)
        pairMap = getYangDirectTransferPairMap(manifest);
    end
    ledger = opts.Ledger;
    if isempty(ledger)
        ledger = makeYangFourBedLedger(controls.componentNames, ...
            'Manifest', manifest, 'PairMap', pairMap, ...
            'LedgerNote', "FI-7 simulation ledger");
    end

    currentContainer = initialContainer;
    cycleReports = {};
    cssHistory = makeEmptyCssSummaryRows();
    stopReason = "max_cycles_reached";
    warnings = strings(0, 1);

    for cycleIndex = 1:opts.MaxCycles
        previousContainer = currentContainer;
        [currentContainer, cycleReport] = runYangFourBedCycle( ...
            previousContainer, templateParams, controls, ...
            'Manifest', manifest, ...
            'PairMap', pairMap, ...
            'OperationPlan', opts.OperationPlan, ...
            'CycleIndex', cycleIndex, ...
            'Ledger', ledger, ...
            'AuditDir', opts.AuditDir, ...
            'WriteAdapterAudit', opts.WriteAdapterAudit, ...
            'NativeRunner', opts.NativeRunner, ...
            'AdapterValidationOnly', opts.AdapterValidationOnly, ...
            'BalanceAbsTol', controls.balanceAbsTol, ...
            'BalanceRelTol', controls.balanceRelTol);
        ledger = cycleReport.ledger;
        warnings = [warnings; cycleReport.warnings(:)]; %#ok<AGROW>

        css = computeYangFourBedCssResiduals(previousContainer, currentContainer, ...
            'Params', templateParams, ...
            'AbsTol', opts.CssAbsTol, ...
            'RelTol', opts.CssRelTol, ...
            'CycleIndex', cycleIndex);
        ledger.cssRows = [ledger.cssRows; css.rows];
        cssHistory = [cssHistory; table( ... %#ok<AGROW>
            double(cycleIndex), ...
            double(css.aggregateResidual), ...
            logical(css.pass), ...
            string(css.controllingBed), ...
            string(css.controllingFamily), ...
            string(css.notes), ...
            'VariableNames', cssHistory.Properties.VariableNames)];

        if logical(opts.KeepCycleReports)
            cycleReports{end+1, 1} = cycleReport; %#ok<AGROW>
        end

        if logical(opts.StopAtCss) && css.pass
            stopReason = "css_tolerance_satisfied";
            break;
        end
    end

    [~, balanceSummary] = computeYangLedgerBalances(ledger, ...
        'AbsTol', controls.balanceAbsTol, ...
        'RelTol', controls.balanceRelTol);
    metrics = computeYangPerformanceMetrics(ledger);

    simReport = struct();
    simReport.version = "FI6-FI7-Yang2009-four-bed-simulation-report-v1";
    simReport.initialContainer = initialContainer;
    simReport.finalContainer = currentContainer;
    simReport.ledger = ledger;
    simReport.cycleReports = cycleReports;
    simReport.cssHistory = cssHistory;
    simReport.metrics = metrics;
    simReport.balanceSummary = balanceSummary;
    simReport.stopReason = stopReason;
    simReport.pass = isempty(cssHistory) || cssHistory.pass(end);
    simReport.warnings = warnings(strlength(warnings) > 0);
    simReport.architecture = struct( ...
        "noDynamicInternalTanks", true, ...
        "noSharedHeaderInventory", true, ...
        "noGlobalFourBedRhs", true, ...
        "persistentStateBasis", "physical_adsorber_state_only", ...
        "metricsBasis", "wrapper_external_stream_ledger");
end

function rows = makeEmptyCssSummaryRows()
    rows = table( ...
        zeros(0, 1), ...
        zeros(0, 1), ...
        false(0, 1), ...
        strings(0, 1), ...
        strings(0, 1), ...
        strings(0, 1), ...
        'VariableNames', [
            "cycle_index"
            "aggregate_residual"
            "pass"
            "controlling_bed"
            "controlling_family"
            "notes"
        ]);
end
