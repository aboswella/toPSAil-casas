% SCHELL diagnostic step ledger for the central Schell 2013 PSA case.
% Failure mode caught: pressure-program or boundary-routing defects hidden by
% cycle-level native performance metrics.
%
% Optional caller variables:
%   caseId               string, default central Schell case
%   cycleCap             positive integer, default 1
%   schellLedgerOptions  struct overriding builder options

if ~exist("caseId", "var") || isempty(caseId)
    caseId = "schell_20bar_tads40_performance_central";
else
    caseId = string(caseId);
end

if ~exist("cycleCap", "var") || isempty(cycleCap)
    cycleCap = 1;
end

if ~exist("schellLedgerOptions", "var") || isempty(schellLedgerOptions)
    schellLedgerOptions = struct();
end

ledger = runSchellStepLedger(caseId, cycleCap, schellLedgerOptions);

function ledger = runSchellStepLedger(caseId, cycleCap, options)
    validateCycleCap(cycleCap);

    scriptDir = fileparts(mfilename("fullpath"));
    repoRoot = fileparts(scriptDir);
    options.run_label = "step_ledger";
    if ~isfield(options, "thermal_mode")
        options.thermal_mode = "isothermal_step_ledger_diagnostic";
    end

    [params, fullParams, runConfig, scaffold] = ...
        build_schell_runnable_params(caseId, cycleCap, options);

    fprintf("SCHELL ledger: running %s for %d cycle(s).\n", ...
        caseId, cycleCap);
    sol = runPsaCycle(params);

    reportDir = fullfile(repoRoot, "validation", "reports", ...
        "schell_2013", "step_ledger");
    if ~isfolder(reportDir)
        mkdir(reportDir);
    end

    rawOutputPath = fullfile(reportDir, caseId + "_raw.mat");
    rawRun.case_id = scaffold.case_id;
    rawRun.model_mode = scaffold.model_mode;
    rawRun.nCycles = fullParams.nCycles;
    rawRun.nSteps = fullParams.nSteps;
    rawRun.durStep_s = fullParams.durStep;
    rawRun.sStepCol = fullParams.sStepCol;
    rawRun.source_adsorption_actual_flow_cm3_per_s = ...
        runConfig.source_adsorption_actual_flow_cm3_per_s;
    rawRun.topsail_native_adsorption_flow_target_cm3_per_s = ...
        runConfig.topsail_native_adsorption_flow_target_cm3_per_s;
    rawRun.topsail_native_adsorption_flow_observed_cm3_per_s = ...
        runConfig.topsail_native_adsorption_flow_observed_cm3_per_s;
    rawRun.pressurization_valve_relative_to_adsorption = ...
        runConfig.pressurization_valve_relative_to_adsorption;
    save(rawOutputPath, "sol", "rawRun", "-v7");

    [ledger, ledgerTable] = extract_schell_step_ledger(fullParams, sol, ...
        runConfig);
    ledger.case_id = scaffold.case_id;
    ledger.raw_output = relativePath(rawOutputPath);

    jsonPath = fullfile(reportDir, caseId + "_step_ledger.json");
    csvPath = fullfile(reportDir, caseId + "_step_ledger.csv");
    writeJson(jsonPath, ledger);
    writetable(ledgerTable, csvPath);

    fprintf("SCHELL ledger complete: wrote %s and %s\n", jsonPath, csvPath);
    printKeyLedgerSummary(ledgerTable);
end

function validateCycleCap(cycleCap)
    if ~(isnumeric(cycleCap) && isscalar(cycleCap) ...
            && isfinite(cycleCap) && cycleCap >= 1 ...
            && cycleCap == floor(cycleCap))
        error("run_schell_step_ledger:badCycleCap", ...
            "cycleCap must be a positive integer.");
    end
end

function printKeyLedgerSummary(ledgerTable)
    rpRows = ledgerTable(ledgerTable.step_name == "RP-FEE-XXX", :);
    hpRows = ledgerTable(ledgerTable.step_name == "HP-FEE-RAF", :);
    if ~isempty(rpRows)
        fprintf("RP-FEE-XXX end pressure range: %.4f to %.4f bar.\n", ...
            min(rpRows.pressure_end_bar), max(rpRows.pressure_end_bar));
    end
    if ~isempty(hpRows)
        h2Column = "raffinate_external_product_moles_H2";
        if any(string(hpRows.Properties.VariableNames) == h2Column)
            fprintf("HP-FEE-RAF external raffinate H2 total: %.6g mol.\n", ...
                sum(hpRows.(h2Column)));
        end
    end
end

function writeJson(filePath, value)
    jsonText = jsonencode(value);
    fid = fopen(filePath, "w");
    if fid < 0
        error("run_schell_step_ledger:jsonOpenFailed", ...
            "Could not open step ledger JSON for writing: %s", filePath);
    end
    cleanupObj = onCleanup(@() fclose(fid));
    fprintf(fid, "%s\n", jsonText);
end

function pathText = relativePath(filePath)
    parts = split(string(filePath), filesep);
    repoIndex = find(parts == "validation", 1);
    if isempty(repoIndex)
        pathText = string(filePath);
    else
        pathText = strjoin(parts(repoIndex:end), "/");
    end
end
