% SCHELL-09 bounded CSS attempt for the central Schell 2013 PSA case.
% Failure mode caught: the central native run cannot complete a bounded CSS
% attempt or cannot emit a schema-aligned summary/extractor record.
%
% Optional caller variables:
%   caseId            string, default central Schell case
%   cycleCap          positive integer, default 5
%   schellCssOptions  struct overriding builder options

if ~exist("caseId", "var") || isempty(caseId)
    caseId = "schell_20bar_tads40_performance_central";
else
    caseId = string(caseId);
end

if ~exist("cycleCap", "var") || isempty(cycleCap)
    cycleCap = 5;
end

if ~exist("schellCssOptions", "var") || isempty(schellCssOptions)
    schellCssOptions = struct();
end

summary = runSchellCentralCss(caseId, cycleCap, schellCssOptions);

function summary = runSchellCentralCss(caseId, cycleCap, options)
    validateCycleCap(cycleCap);

    scriptDir = fileparts(mfilename("fullpath"));
    repoRoot = fileparts(scriptDir);
    options.run_label = "central_css";
    if ~isfield(options, "thermal_mode")
        options.thermal_mode = "isothermal_bounded_css_attempt";
    end

    [params, fullParams, runConfig, scaffold] = ...
        build_schell_runnable_params(caseId, cycleCap, options);

    fprintf("SCHELL-09 central: running %s with %d-cycle cap.\n", ...
        caseId, cycleCap);
    runTimer = tic;
    sol = runPsaCycle(params);
    runtimeSeconds = toc(runTimer);

    reportDir = fullfile(repoRoot, "validation", "reports", ...
        "schell_2013", "central");
    if ~isfolder(reportDir)
        mkdir(reportDir);
    end

    rawOutputPath = fullfile(reportDir, "raw.mat");
    rawRun = makeRawRunRecord(scaffold, fullParams, runConfig);
    save(rawOutputPath, "sol", "rawRun", "-v7");

    summaryPath = fullfile(reportDir, "summary.json");
    summary = extract_schell_summary(scaffold, fullParams, sol, ...
        runConfig, runtimeSeconds, summaryPath, rawOutputPath, ...
        "central_css");
    summary.hard_checks.summary_json_emitted = true;
    writeJson(summaryPath, summary);

    assertSummaryHardChecks(summary);
    fprintf("SCHELL-09 central complete: wrote %s\n", summaryPath);
    fprintf("SCHELL-09 stop reason: %s; CSS residual %.6g.\n", ...
        summary.run.stop_reason, summary.run.css_residual);
end

function validateCycleCap(cycleCap)
    if ~(isnumeric(cycleCap) && isscalar(cycleCap) ...
            && isfinite(cycleCap) && cycleCap >= 1 ...
            && cycleCap == floor(cycleCap))
        error("run_schell_central_css:badCycleCap", ...
            "cycleCap must be a positive integer.");
    end
end

function rawRun = makeRawRunRecord(scaffold, fullParams, runConfig)
    rawRun.case_id = scaffold.case_id;
    rawRun.model_mode = scaffold.model_mode;
    rawRun.components = scaffold.params.components;
    rawRun.nLKs = scaffold.params.nLKs;
    rawRun.nVols = fullParams.nVols;
    rawRun.nSteps = fullParams.nSteps;
    rawRun.nCycles = fullParams.nCycles;
    rawRun.durStep_s = fullParams.durStep;
    rawRun.sStepCol = fullParams.sStepCol;
    rawRun.thermal_mode = runConfig.thermal_mode;
    rawRun.source_adsorption_actual_flow_cm3_per_s = ...
        runConfig.source_adsorption_actual_flow_cm3_per_s;
    rawRun.source_purge_actual_flow_cm3_per_s = ...
        runConfig.source_purge_actual_flow_cm3_per_s;
    rawRun.topsail_native_adsorption_flow_target_cm3_per_s = ...
        runConfig.topsail_native_adsorption_flow_target_cm3_per_s;
    rawRun.topsail_native_adsorption_flow_observed_cm3_per_s = ...
        runConfig.topsail_native_adsorption_flow_observed_cm3_per_s;
    rawRun.topsail_native_flow_conversion_formula = ...
        runConfig.topsail_native_flow_conversion_formula;
    rawRun.expected_source_adsorption_moles_per_component_two_beds = ...
        runConfig.expected_source_adsorption_moles_per_component_two_beds;
    rawRun.pressurization_valve_relative_to_adsorption = ...
        runConfig.pressurization_valve_relative_to_adsorption;
    rawRun.pressurization_valve_basis = runConfig.pressurization_valve_basis;
    rawRun.purge_native_step = runConfig.purge_native_step;
    rawRun.purge_source_basis = runConfig.purge_source_basis;
    rawRun.purge_valve_relative_to_adsorption = ...
        runConfig.purge_valve_relative_to_adsorption;
    rawRun.purge_valve_basis = runConfig.purge_valve_basis;
    rawRun.accepted_cycle_cap = runConfig.accepted_cycle_cap;
end

function assertSummaryHardChecks(summary)
    checks = summary.hard_checks;
    passed = checks.matlab_completed ...
        && checks.requested_cycles_completed ...
        && checks.no_nan_inf ...
        && checks.positive_pressure ...
        && checks.positive_temperature ...
        && checks.mole_fractions_valid ...
        && checks.css_metric_reported ...
        && checks.summary_json_emitted;
    if ~passed
        error("run_schell_central_css:hardCheckFailed", ...
            "SCHELL-09 central run failed one or more hard checks.");
    end
end

function writeJson(filePath, value)
    jsonText = jsonencode(value);
    fid = fopen(filePath, "w");
    if fid < 0
        error("run_schell_central_css:jsonOpenFailed", ...
            "Could not open summary JSON for writing: %s", filePath);
    end
    cleanupObj = onCleanup(@() fclose(fid));
    fprintf(fid, "%s\n", jsonText);
end
