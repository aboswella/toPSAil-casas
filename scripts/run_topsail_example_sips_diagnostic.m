% Diagnostic: unchanged toPSAil case_study_1.0 versus the same setup routed
% through the optional Schell Sips isotherm.
% Failure mode caught: optional Sips route causes severe runtime growth or
% native receiver-tank pressure messages under otherwise native example inputs.
%
% Optional caller variables:
%   variant = "both" | "baseline" | "sips"
%   diagnosticConfig.grid_cells
%   diagnosticConfig.time_points_per_step
%   diagnosticConfig.cycles
%   diagnosticConfig.css_tolerance

if ~exist("variant", "var") || isempty(variant)
    variant = "both";
end
if ~exist("diagnosticConfig", "var") || isempty(diagnosticConfig)
    diagnosticConfig = struct();
end

summaries = runDiagnostic(variant, diagnosticConfig);

function summaries = runDiagnostic(variant, diagnosticConfig)
    variant = string(variant);
    config = defaultConfig(diagnosticConfig);

    scriptDir = fileparts(mfilename("fullpath"));
    repoRoot = fileparts(scriptDir);
    reportDir = fullfile(repoRoot, "validation", "reports", ...
        "schell_2013", "diagnostics");
    if ~isfolder(reportDir)
        mkdir(reportDir);
    end

    variants = variantList(variant);
    summaries = struct([]);
    for i = 1:numel(variants)
        summary = runVariant(repoRoot, reportDir, variants(i), config);
        if isempty(summaries)
            summaries = summary;
        else
            summaries(end+1, 1) = summary; %#ok<AGROW>
        end
    end
end

function config = defaultConfig(overrides)
    config.grid_cells = 8;
    config.time_points_per_step = 5;
    config.cycles = 3;
    config.css_tolerance = 1e-3;

    if isfield(overrides, "grid_cells")
        config.grid_cells = overrides.grid_cells;
    end
    if isfield(overrides, "time_points_per_step")
        config.time_points_per_step = overrides.time_points_per_step;
    end
    if isfield(overrides, "cycles")
        config.cycles = overrides.cycles;
    end
    if isfield(overrides, "css_tolerance")
        config.css_tolerance = overrides.css_tolerance;
    end
end

function variants = variantList(variant)
    if variant == "both"
        variants = ["baseline"; "sips"];
    elseif variant == "baseline" || variant == "sips"
        variants = variant;
    else
        error("run_topsail_example_sips_diagnostic:badVariant", ...
            "variant must be baseline, sips, or both.");
    end
end

function summary = runVariant(repoRoot, reportDir, variant, config)
    timestamp = string(datetime("now", "Format", "yyyyMMdd_HHmmss"));
    prefix = "case_study_1p0_" + variant + "_reduced_" + timestamp;
    summaryPath = fullfile(reportDir, prefix + "_summary.json");
    logPath = fullfile(reportDir, prefix + "_console.txt");

    summary = makeStartedSummary(variant, config, summaryPath, logPath);
    writeJson(summaryPath, summary);

    diary(logPath);
    diary on;
    cleanupObj = onCleanup(@() diary("off"));

    fprintf("\n=== TOPSAIL EXAMPLE SIPS DIAGNOSTIC START: %s ===\n", upper(variant));
    fprintf("grid_cells=%d, time_points_per_step=%d, cycles=%d, css_tolerance=%g\n", ...
        config.grid_cells, config.time_points_per_step, ...
        config.cycles, config.css_tolerance);

    try
        [params, fullParams] = buildExampleParams(repoRoot, variant, config);
        runTimer = tic;
        sol = runPsaCycle(params);
        summary.run.runtime_s = toc(runTimer);
        summary.run.completed = true;
        summary.run.steps_completed = sol.lastStep;
        summary.run.cycles_completed = floor(sol.lastStep / fullParams.nSteps);
        summary.run.css = sol.css(:).';
        summary.run.last_nonzero_css = lastNonzero(sol.css);

        metricsCycle = max(1, min(size(sol.perMet.productPurity, 1), ...
            max(1, summary.run.cycles_completed)));
        summary.performance.product_purity_last = ...
            sol.perMet.productPurity(metricsCycle, :);
        summary.performance.product_recovery_last = ...
            sol.perMet.productRecovery(metricsCycle, :);
        summary.performance.productivity_last = ...
            sol.perMet.productivity(metricsCycle, :);
        summary.performance.energy_efficiency_last = ...
            sol.perMet.energyEfficiency(metricsCycle, :);
        summary.health.all_finite = allFiniteNumeric(sol);
        summary.status = "completed";
    catch ME
        summary.run.completed = false;
        summary.status = "failed";
        summary.error.identifier = string(ME.identifier);
        summary.error.message = string(ME.message);
        summary.error.report = string(getReport(ME, ...
            "extended", "hyperlinks", "off"));
    end

    fprintf("\n=== TOPSAIL EXAMPLE SIPS DIAGNOSTIC END: %s ===\n", upper(variant));
    diary("off");
    summary.console = summarizeConsole(logPath);
    writeJson(summaryPath, summary);
    fprintf("Wrote diagnostic summary: %s\n", summaryPath);
end

function summary = makeStartedSummary(variant, config, summaryPath, logPath)
    summary.schema_version = "0.1.0";
    summary.diagnostic = "topsail_case_study_1p0_sips_route_reduced";
    summary.variant = variant;
    summary.status = "started";
    summary.case_name = "case_study_1.0";
    summary.model_interpretation = ...
        "Diagnostic plumbing stress test; Sips variant maps Schell H2/CO2 Sips coefficients onto native example component slots.";
    summary.config.grid_cells = config.grid_cells;
    summary.config.time_points_per_step = config.time_points_per_step;
    summary.config.cycles = config.cycles;
    summary.config.css_tolerance_numZero = config.css_tolerance;
    summary.outputs.summary_json = relativePath(summaryPath);
    summary.outputs.console_log = relativePath(logPath);
end

function [params, fullParams] = buildExampleParams(repoRoot, variant, config)
    originalDir = pwd;
    dirCleanup = onCleanup(@() cd(originalDir));
    cd(fullfile(repoRoot, "2_run"));
    addpath(pwd);

    user.folderNameExample = "case_study_1.0";
    [~, ~, exampleFolder] = definePath2SourceFolders(user);
    raw = loadRawExampleParams(exampleFolder);
    raw.nVols = config.grid_cells;
    raw.nTiPts = config.time_points_per_step;
    raw.nCycles = config.cycles;
    raw.numZero = config.css_tolerance;
    raw.plot = zeros(8, 1);

    if variant == "sips"
        raw.modSp(1) = 7;
        raw = addSchellSipsCoefficients(raw, repoRoot);
    end

    [params, fullParams] = deriveTopsailParams(raw);
end

function raw = loadRawExampleParams(exampleFolder)
    subFolderName = "1_simulation_inputs";
    excelFiles = [
        "0.1_simulation_configurations.xlsm"
        "0.2_numerical_methods.xlsm"
        "0.3_simulation_outputs.xlsm"
        "1.1_natural_constants.xlsm"
        "1.2_adsorbate_properties.xlsm"
        "1.3_adsorbent_properties.xlsm"
        "2.1_feed_stream_properties.xlsm"
        "2.2_raffinate_stream_properties.xlsm"
        "2.3_extract_stream_properties.xlsm"
        "3.1_adsorber_properties.xlsm"
        "3.2_feed_tank_properties.xlsm"
        "3.3_raffinate_tank_properties.xlsm"
        "3.4_extract_tank_properties.xlsm"
        "3.5_feed_compressor_properties.xlsm"
        "3.6_extract_compressor_properties.xlsm"
        "3.7_vacuum_pump_properties.xlsm"
        "4.1_cycle_organization.xlsm"
    ];

    raw = struct([]);
    for i = 1:numel(excelFiles)
        part = getExcelParams(exampleFolder, char(subFolderName), ...
            char(excelFiles(i)));
        if i == 6
            part = normalizeIsothermCellFields(part);
        end
        raw = merge2Structures(raw, part);
    end
end

function params = normalizeIsothermCellFields(params)
    names = fieldnames(params);
    for i = 1:numel(names)
        value = params.(names{i});
        if iscell(value)
            numEl = numel(value);
            numHys = length(str2num(value{1})); %#ok<ST2NM>
            numericValue = zeros(numEl, numHys);
            for j = 1:numEl
                numericValue(j, :) = str2num(value{j}); %#ok<ST2NM>
            end
            params.(names{i}) = numericValue;
        end
    end
end

function raw = addSchellSipsCoefficients(raw, repoRoot)
    sourcePackPath = fullfile(repoRoot, "params", ...
        "schell2013_ap360_sips_binary", "schell_2013_source_pack.json");
    sourcePack = jsondecode(fileread(sourcePackPath));
    iso = sourcePack.isotherm.parameters;

    % Native example slot 1 is the light key and slot 2 is the heavy key.
    % Use Schell H2 then CO2 to preserve that role ordering.
    raw.schellSipsNInfA_molPerKg = [iso.H2.a, iso.CO2.a];
    raw.schellSipsNInfB_JPerMol = [iso.H2.b, iso.CO2.b];
    raw.schellSipsAffA_invPa = [iso.H2.A, iso.CO2.A];
    raw.schellSipsAffB_JPerMol = [iso.H2.B, iso.CO2.B];
    raw.schellSipsAlpha = [iso.H2.alpha, iso.CO2.alpha];
    raw.schellSipsBeta_invK = [iso.H2.beta, iso.CO2.beta];
    raw.schellSipsSref = [iso.H2.sref, iso.CO2.sref];
    raw.schellSipsTref_K = [iso.H2.Tref, iso.CO2.Tref];
end

function [params, fullParams] = deriveTopsailParams(raw)
    params = raw;
    params = getStatesParams(params);
    params = getStreamParams(params);
    params = getStringParams(params);
    params = getSolverOpts(params);

    [models, subModels] = getSubModels(params);
    params.funcIso = models{1};
    params.funcRat = models{2};
    params.funcEos = models{3};
    params.funcVal = models{4};
    params.funcVol = models{6};
    params.funcVolUnits = subModels{6};
    params.funcCss = models{7};
    if params.bool(5) == 1
        params.funcHtCap = models{5};
    end

    params = getVoidAndDens(params);
    params = getPresRats(params);
    params = getTempRats(params);
    params = getColumnParams(params);
    params = getTankParams(params);
    params = getTotalGasConc(params);
    params = getAdsEquilParams(params);
    params = getAdsRateParams(params);
    params = getTotalAdsConc(params);
    params = getAdsEquilParams(params, 1);
    params = getFeHtCapRatio(params);
    params = getFeMixCompFac(params);
    params.volFlowFeed = calcVolFlowFeed(params);
    params = getScaleFacs(params);
    [params.maxMolPr, params.maxMolFe, params.maxMolAdsC] = ...
        calcEqTheoryHighPres(params);
    voidMolDiff = calcEqTheoryRePresVoid(params);
    adsMolDiff = calcEqTheoryRePresAds(params);
    params.maxNetPrdOp = params.maxMolPr - voidMolDiff - adsMolDiff;
    params = getDimLessParams(params);

    if params.bool(5) == 1
        params = getEnergyBalanceParams(params);
        params = removeEnergyBalanceParams(params);
    end
    if params.bool(3) == 1
        params = getMomentumBalanceParams(params);
        params = removeMomentumBalanceParams(params);
    end

    params.mtz = getMtzParams();
    areaThres = params.mtz.areaThres;
    [params.maxTiFe, ~] = calcMtzTheory(params, areaThres);
    params.volFlowEq = params.maxMolFe / params.maxTiFe ...
        / params.gConScaleFac;
    params = getFlowSheetValves(params);
    params = getColBoundConds(params);
    params = getTimeSpan(params);
    params = getEventParams(params);
    params.funcEve = getEventFuncs(params);
    params = getNumParams(params);
    params.initStates = getInitialStates(params);

    fullParams = orderfields(params);
    params = orderfields(removeParams(params));
end

function value = lastNonzero(values)
    values = values(:);
    idx = find(values ~= 0, 1, "last");
    if isempty(idx)
        value = 0;
    else
        value = values(idx);
    end
end

function console = summarizeConsole(logPath)
    if ~isfile(logPath)
        console.log_found = false;
        return;
    end
    text = string(fileread(logPath));
    console.log_found = true;
    console.raffinate_tank_not_reached_count = ...
        count(text, "The raff. tank pressure has not reached.");
    console.extract_tank_not_reached_count = ...
        count(text, "The extr. tank pressure has not reached.");
    console.either_tank_not_reached_count = ...
        count(text, "Either the raffinate tank pressure or the extract tank pressure has not reached.");
    console.solver_summary_count = count(text, "Numerical Integration Summary.");
end

function writeJson(filePath, value)
    fid = fopen(filePath, "w");
    if fid < 0
        error("run_topsail_example_sips_diagnostic:jsonOpenFailed", ...
            "Could not open JSON output for writing: %s", filePath);
    end
    cleanupObj = onCleanup(@() fclose(fid));
    fprintf(fid, "%s\n", jsonencode(value));
end

function pathText = relativePath(filePath)
    filePath = string(filePath);
    normalized = replace(filePath, "\", "/");
    marker = "/validation/";
    idx = strfind(normalized, marker);
    if isempty(idx)
        pathText = normalized;
    else
        pathText = "validation/" + extractAfter(normalized, ...
            idx(1) + strlength(marker) - 1);
    end
end

function ok = allFiniteNumeric(value)
    if isnumeric(value)
        ok = all(isfinite(value), "all");
    elseif isstruct(value)
        ok = true;
        fields = fieldnames(value);
        for i = 1:numel(fields)
            ok = ok && allFiniteNumeric(value.(fields{i}));
            if ~ok
                return;
            end
        end
    elseif iscell(value)
        ok = true;
        for i = 1:numel(value)
            ok = ok && allFiniteNumeric(value{i});
            if ~ok
                return;
            end
        end
    else
        ok = true;
    end
end
