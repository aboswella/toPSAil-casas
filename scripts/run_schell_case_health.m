% SCHELL-08 health run for the central Schell 2013 PSA case.
% Failure mode caught: the Schell central route cannot complete a minimal
% native runPsaCycle health simulation or emits nonphysical state summaries.

summary = runSchellCaseHealth();

function summary = runSchellCaseHealth(caseId, cyclesRequested)
    if nargin < 1 || isempty(caseId)
        caseId = "schell_20bar_tads40_performance_central";
    else
        caseId = string(caseId);
    end

    if nargin < 2 || isempty(cyclesRequested)
        cyclesRequested = 1;
    end

    scriptDir = fileparts(mfilename("fullpath"));
    repoRoot = fileparts(scriptDir);
    sourcePackPath = fullfile(repoRoot, "params", ...
        "schell2013_ap360_sips_binary", "schell_2013_source_pack.json");
    sourcePack = jsondecode(fileread(sourcePackPath));
    cycleCase = findCycleCase(sourcePack.cycle_cases, caseId);

    scaffold = build_schell_params_from_source_pack(caseId, cyclesRequested);
    [params, fullParams, healthConfig] = buildRunnableSchellParams( ...
        scaffold.params, sourcePack, cycleCase, cyclesRequested);

    fprintf("SCHELL-08 health: running %s for %d cycle(s).\n", ...
        caseId, cyclesRequested);
    runTimer = tic;
    sol = runPsaCycle(params);
    runtimeSeconds = toc(runTimer);

    reportDir = fullfile(repoRoot, "validation", "reports", ...
        "schell_2013", "health");
    if ~isfolder(reportDir)
        mkdir(reportDir);
    end

    rawOutputPath = fullfile(reportDir, caseId + "_raw.mat");
    rawRun = makeRawRunRecord(scaffold, fullParams, healthConfig);
    save(rawOutputPath, "sol", "rawRun", "-v7");

    summaryPath = fullfile(reportDir, caseId + "_summary.json");
    summary = makeHealthSummary(scaffold, fullParams, sol, healthConfig, ...
        runtimeSeconds, summaryPath, rawOutputPath);
    summary.hard_checks.summary_json_emitted = true;
    writeJson(summaryPath, summary);

    assertHealthPassed(summary);
    fprintf("SCHELL-08 health passed: wrote %s\n", summaryPath);
end

function [params, fullParams, healthConfig] = buildRunnableSchellParams( ...
    scaffoldParams, sourcePack, cycleCase, cyclesRequested)
    healthConfig.schema_version = "0.1.0";
    healthConfig.grid_cells = 20;
    healthConfig.time_points_per_step = 20;
    healthConfig.thermal_mode = "isothermal_health_check";
    healthConfig.native_pressure_flow_mode = ...
        "topsail_native_no_axial_pressure_drop_flow_control";
    healthConfig.equalization_mode = "topsail_native_feed_end_equalization";
    healthConfig.purge_connection_note = ...
        "native LP-EXT-RAF purge uses the raffinate tank connection seeded with equimolar feed";
    healthConfig.adsorption_flow_target_cm3_per_s = ...
        sourcePack.feed_and_process.flow_rate_conversion_basis.adsorption_flow_cm3_per_s;
    healthConfig.purge_flow_target_cm3_per_s = ...
        sourcePack.feed_and_process.flow_rate_conversion_basis.purge_flow_cm3_per_s;

    rawParams = makeRawSchellParams(scaffoldParams, sourcePack, ...
        cycleCase, cyclesRequested, healthConfig, 1.0);
    [~, trialFullParams] = deriveTopsailParams(rawParams);
    scaleFactor = healthConfig.adsorption_flow_target_cm3_per_s ...
        / max(abs(trialFullParams.volFlowFeed), eps);

    rawParams = makeRawSchellParams(scaffoldParams, sourcePack, ...
        cycleCase, cyclesRequested, healthConfig, scaleFactor);
    [params, fullParams] = deriveTopsailParams(rawParams);

    healthConfig.native_adsorption_flow_cm3_per_s = fullParams.volFlowFeed;
    healthConfig.valve_scale_factor = scaleFactor;
    healthConfig.cycle_duration_s = sum(fullParams.durStep);
end

function raw = makeRawSchellParams(scaffoldParams, sourcePack, cycleCase, ...
    cyclesRequested, healthConfig, valveScale)
    nativeComponents = scaffoldParams.components;
    gasConstantJ = sourcePack.gas_constant_J_per_mol_K;
    adsValve = 5.0e-6 * valveScale;
    blowValve = adsValve;
    equalizationValve = adsValve;
    purgeValve = adsValve ...
        * healthConfig.purge_flow_target_cm3_per_s ...
        / healthConfig.adsorption_flow_target_cm3_per_s;

    raw.bool = [1; 0; 0; 0; 0; 0; 0; 0; 1; 0; 1; 0];
    raw.modSp = [7; 1; 1; 1; 0; 0; 0];
    raw.nVols = healthConfig.grid_cells;
    raw.nTiPts = healthConfig.time_points_per_step;
    raw.numIntSolv = "ode15s";
    raw.odeAbsTol = 1e-6;
    raw.odeRelTol = 1e-3;
    raw.numZero = 1e-8;
    raw.plot = zeros(8, 1);

    raw.tempAmbi = sourcePack.feed_and_process.ambient_temperature_K;
    raw.presAmbi = sourcePack.feed_and_process.low_pressure_Pa / 1e5;
    raw.tempStan = 273.15;
    raw.presStan = 1.01325;
    raw.gasCons = gasConstantJ * 10;

    raw.sCom = cellstr(nativeComponents);
    raw.molecWtC = componentVector(nativeComponents, ...
        struct("H2", 2.01588, "CO2", 44.0095));
    raw.htCapCpC = scaffoldParams.topsail_native_vectors ...
        .gas_heat_capacity_J_per_mol_K(:);
    raw.htCapCvC = raw.htCapCpC - gasConstantJ;
    raw.compFacC = ones(numel(nativeComponents), 1);
    raw.nComs = numel(nativeComponents);
    raw.nLKs = scaffoldParams.nLKs;

    raw.henryC = zeros(raw.nComs, 1);
    raw.ldfMtc = scaffoldParams.topsail_native_vectors.ldf_rate_per_s(:);
    raw.diamPellet = sourcePack.bed_and_adsorbent.particle_diameter_m * 100;
    raw.maTrRes = 1;
    raw.pellDens = sourcePack.bed_and_adsorbent.particle_density_kg_per_m3 ...
        / 1e6;
    raw.bulkDens = sourcePack.bed_and_adsorbent.bed_density_kg_per_m3 ...
        / 1e6;
    raw.tempRefIso = sourcePack.feed_and_process.ambient_temperature_K;

    raw.yFeC = scaffoldParams.feed.mole_fraction(:);
    raw.tempFeed = sourcePack.feed_and_process.feed_temperature_K;
    raw.densFeGas = idealGasDensityKgPerM3(raw.yFeC, raw.molecWtC, ...
        cycleCase.p_high_bar, raw.tempFeed, gasConstantJ) / 1e6;
    raw.viscFeGas = sourcePack.model_parameters.fluid_viscosity_Pa_s;
    raw.yRaC = raw.yFeC;
    raw.yExC = [0.001; 0.999];

    raw.inConBed = [6; 1];
    raw.heightCol = sourcePack.geometry.column_length_m * 100;
    raw.radInCol = sourcePack.geometry.internal_radius_m * 100;
    raw.radOutCol = sourcePack.geometry.external_radius_m * 100;
    raw.voidFracBed = 1 ...
        - sourcePack.bed_and_adsorbent.bed_density_kg_per_m3 ...
        / sourcePack.bed_and_adsorbent.particle_density_kg_per_m3;
    raw.massAds = sourcePack.bed_and_adsorbent.adsorbent_mass_per_bed_kg_approx;
    raw.presColHigh = cycleCase.p_high_bar;
    raw.presColLow = sourcePack.feed_and_process.low_pressure_Pa / 1e5;
    raw.tempCol = sourcePack.feed_and_process.ambient_temperature_K;
    raw.waDensCol = sourcePack.bed_and_adsorbent.material_density_kg_per_m3 ...
        / 1e6;

    raw.inConFeTa = 1;
    raw.tempFeTa = raw.tempFeed;
    raw.presFeTa = 1.1 * raw.presColHigh;
    raw.inConRaTa = 4;
    raw.tempRaTa = raw.tempFeed;
    raw.presRaTa = 1.1 * raw.presColLow;
    raw.inConExTa = 4;
    raw.tempExTa = raw.tempFeed;
    raw.presExTa = raw.presColLow;
    raw = addHealthTankGeometry(raw, sourcePack);

    raw.isEntEffFeComp = 1.0;
    raw.isEntEffExComp = 1.0;
    raw.isEntEffPump = 1.0;
    raw.presDoSt = raw.presColLow;

    raw.nCols = 2;
    raw.nCycles = cyclesRequested;
    raw.nSteps = 10;
    raw.durStep = joinNumbers([ ...
        cycleCase.t_peq_s, ...
        cycleCase.t_press_s, ...
        cycleCase.t_blow_s - cycleCase.t_press_s, ...
        cycleCase.t_ads_s - (cycleCase.t_blow_s - cycleCase.t_press_s), ...
        cycleCase.t_purge_s - (cycleCase.t_ads_s ...
            - (cycleCase.t_blow_s - cycleCase.t_press_s)), ...
        cycleCase.t_peq_s, ...
        cycleCase.t_press_s, ...
        cycleCase.t_blow_s - cycleCase.t_press_s, ...
        cycleCase.t_ads_s - (cycleCase.t_blow_s - cycleCase.t_press_s), ...
        cycleCase.t_purge_s - (cycleCase.t_ads_s ...
            - (cycleCase.t_blow_s - cycleCase.t_press_s))]);
    raw.eveVal = joinNumbers(zeros(1, raw.nSteps));
    raw.eveUnit = joinStrings(repmat("None", 1, raw.nSteps));
    raw.eveLoc = joinStrings(repmat("None", 1, raw.nSteps));

    stepCol1 = ["EQ-AFE-XXX", "RP-FEE-XXX", "HP-FEE-RAF", ...
        "HP-FEE-RAF", "RT-XXX-XXX", "EQ-AFE-XXX", ...
        "DP-EXT-XXX", "DP-EXT-XXX", "LP-EXT-RAF", "LP-EXT-RAF"];
    stepCol2 = ["EQ-AFE-XXX", "DP-EXT-XXX", "DP-EXT-XXX", ...
        "LP-EXT-RAF", "LP-EXT-RAF", "EQ-AFE-XXX", ...
        "RP-FEE-XXX", "HP-FEE-RAF", "HP-FEE-RAF", "RT-XXX-XXX"];
    raw.sStepCol = {char(joinStrings(stepCol1)); char(joinStrings(stepCol2))};
    raw.sTypeCol = {char(stepTypes(stepCol1)); char(stepTypes(stepCol2))};
    raw.valFeedCol = {char(valveRow(stepCol1, adsValve, blowValve, ...
        equalizationValve, purgeValve, "feed")); ...
        char(valveRow(stepCol2, adsValve, blowValve, ...
        equalizationValve, purgeValve, "feed"))};
    raw.valProdCol = {char(valveRow(stepCol1, adsValve, blowValve, ...
        equalizationValve, purgeValve, "product")); ...
        char(valveRow(stepCol2, adsValve, blowValve, ...
        equalizationValve, purgeValve, "product"))};
    raw.flowDirCol = {char(flowDirections(stepCol1)); ...
        char(flowDirections(stepCol2))};

    raw.schellSipsNInfA_molPerKg = scaffoldParams.schellSipsNInfA_molPerKg;
    raw.schellSipsNInfB_JPerMol = scaffoldParams.schellSipsNInfB_JPerMol;
    raw.schellSipsAffA_invPa = scaffoldParams.schellSipsAffA_invPa;
    raw.schellSipsAffB_JPerMol = scaffoldParams.schellSipsAffB_JPerMol;
    raw.schellSipsAlpha = scaffoldParams.schellSipsAlpha;
    raw.schellSipsBeta_invK = scaffoldParams.schellSipsBeta_invK;
    raw.schellSipsSref = scaffoldParams.schellSipsSref;
    raw.schellSipsTref_K = scaffoldParams.schellSipsTref_K;
end

function raw = addHealthTankGeometry(raw, sourcePack)
    tankRadiusInCm = 5.0;
    tankWallCm = 0.5;
    tankHeightCm = 20.0;
    wallDensityKgPerCm3 = sourcePack.bed_and_adsorbent ...
        .material_density_kg_per_m3 / 1e6;

    raw.radInFeTa = tankRadiusInCm;
    raw.radOutFeTa = tankRadiusInCm + tankWallCm;
    raw.heightFeTa = tankHeightCm;
    raw.waDensFeTa = wallDensityKgPerCm3;

    raw.radInRaTa = tankRadiusInCm;
    raw.radOutRaTa = tankRadiusInCm + tankWallCm;
    raw.heightRaTa = tankHeightCm;
    raw.waDensRaTa = wallDensityKgPerCm3;

    raw.radInExTa = tankRadiusInCm;
    raw.radOutExTa = tankRadiusInCm + tankWallCm;
    raw.heightExTa = tankHeightCm;
    raw.waDensExTa = wallDensityKgPerCm3;
end

function [params, fullParams] = deriveTopsailParams(rawParams)
    params = rawParams;
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
    params.volFlowEq = params.maxMolFe ...
        / params.maxTiFe ...
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

function summary = makeHealthSummary(scaffold, fullParams, sol, ...
    healthConfig, runtimeSeconds, summaryPath, rawOutputPath)
    health = collectHealthExtrema(fullParams, sol);
    cyclesCompleted = floor(sol.lastStep / fullParams.nSteps);
    lastCycle = max(1, min(cyclesCompleted, size(sol.perMet.productPurity, 1)));

    summary.schema_version = "0.1.0";
    summary.case_id = scaffold.case_id;
    summary.model_mode = scaffold.model_mode;
    summary.source_pack_sha256 = scaffold.source_pack_sha256;
    summary.parameter_pack = "params/schell2013_ap360_sips_binary/schell_2013_source_pack.json";
    summary.source_reference_file = ...
        "docs/source_reference/02_schell_2013_two_bed_psa_validation.md";
    summary.component_order.source = scaffold.params.component_order.source;
    summary.component_order.topsail_native = ...
        scaffold.params.component_order.topsail_native;

    summary.run.matlab_version = string(version);
    summary.run.cycles_requested = fullParams.nCycles;
    summary.run.cycles_completed = cyclesCompleted;
    summary.run.steps_completed = sol.lastStep;
    summary.run.grid_cells = fullParams.nVols;
    summary.run.cycle_duration_s = healthConfig.cycle_duration_s;
    summary.run.runtime_s = runtimeSeconds;
    summary.run.css_metric_name = "toPSAil overall state L2";
    summary.run.css_residual = sol.css(min(numel(sol.css), fullParams.nCycles + 1));
    summary.run.thermal_mode = healthConfig.thermal_mode;
    summary.run.native_pressure_flow_mode = healthConfig.native_pressure_flow_mode;
    summary.run.equalization_mode = healthConfig.equalization_mode;
    summary.run.native_adsorption_flow_cm3_per_s = ...
        healthConfig.native_adsorption_flow_cm3_per_s;

    summary.hard_checks.matlab_completed = true;
    summary.hard_checks.requested_cycles_completed = ...
        cyclesCompleted >= fullParams.nCycles;
    summary.hard_checks.no_nan_inf = health.all_finite;
    summary.hard_checks.positive_pressure = health.min_pressure_bar > 0;
    summary.hard_checks.positive_temperature = health.min_temperature_K > 0;
    summary.hard_checks.mole_fractions_valid = ...
        health.min_mole_fraction >= -1e-8 ...
        && health.max_mole_fraction <= 1 + 1e-8 ...
        && health.max_mole_fraction_sum_error <= 1e-8;
    summary.hard_checks.summary_json_emitted = false;

    nativeOneCycleMetrics.h2_purity_pct = ...
        100 * sol.perMet.productPurity(lastCycle, 1);
    nativeOneCycleMetrics.h2_recovery_pct = ...
        100 * sol.perMet.productRecovery(lastCycle, 1);
    nativeOneCycleMetrics.co2_purity_pct = ...
        100 * sol.perMet.productPurity(lastCycle, 2);
    nativeOneCycleMetrics.co2_recovery_pct = ...
        100 * sol.perMet.productRecovery(lastCycle, 2);

    summary.performance.h2_purity_pct = missing;
    summary.performance.h2_recovery_pct = missing;
    summary.performance.co2_purity_pct = missing;
    summary.performance.co2_recovery_pct = missing;
    summary.performance.classification = "not_evaluated";

    summary.temperature_profiles.min_temperature_K = health.min_temperature_K;
    summary.temperature_profiles.max_temperature_K = health.max_temperature_K;
    summary.pressure_profiles.min_pressure_bar = health.min_pressure_bar;
    summary.pressure_profiles.max_pressure_bar = health.max_pressure_bar;
    summary.pressure_profiles.equalization_policy = ...
        "toPSAil native feed-end equalization; p_peq not prescribed";

    summary.stream_accounting.product_moles_raffinate = ...
        sol.perMet.productMolesRaff(lastCycle, :);
    summary.stream_accounting.product_moles_extract = ...
        sol.perMet.productMolesExtr(lastCycle, :);
    summary.stream_accounting.waste_moles_raffinate = ...
        sol.perMet.wasteMolesRaff(lastCycle, :);
    summary.stream_accounting.waste_moles_extract = ...
        sol.perMet.wasteMolesExtr(lastCycle, :);
    summary.stream_accounting.native_one_cycle_metrics = ...
        nativeOneCycleMetrics;

    summary.raw_outputs = [
        relativePath(summaryPath)
        relativePath(rawOutputPath)
    ];
    summary.warnings = [
        "SCHELL-08 is a one-cycle health run, not CSS validation."
        "Performance numbers are emitted only as health-run diagnostics and are classified not_evaluated."
        "FLOW_BASIS remains an explicit source uncertainty."
        "P_PEQ remains unresolved; native equalization is used without prescribing p_peq."
        "Finite-wall thermal validation is deferred; this health run uses an explicitly labelled isothermal mode."
        healthConfig.purge_connection_note
    ];
end

function health = collectHealthExtrema(params, sol)
    health.min_pressure_bar = inf;
    health.max_pressure_bar = -inf;
    health.min_temperature_K = inf;
    health.max_temperature_K = -inf;
    health.min_mole_fraction = inf;
    health.max_mole_fraction = -inf;
    health.max_mole_fraction_sum_error = 0;
    health.all_finite = allFiniteNumeric(sol);

    stepFields = string(fieldnames(sol));
    stepFields = stepFields(startsWith(stepFields, "Step"));
    for i = 1:numel(stepFields)
        step = sol.(stepFields(i));
        for j = 1:params.nCols
            colName = params.sColNums{j};
            health = updateGasHealth(health, params, step.col.(colName));
        end
        health = updateGasHealth(health, params, step.feTa.n1);
        health = updateGasHealth(health, params, step.raTa.n1);
        health = updateGasHealth(health, params, step.exTa.n1);
    end
end

function health = updateGasHealth(health, params, unit)
    gasTotal = unit.gasConsTot;
    tempNorm = unit.temps.cstr;
    pressureBar = gasTotal .* tempNorm ...
        .* params.gasConsNormEq .* params.presColHigh;
    temperatureK = tempNorm .* params.teScaleFac;

    health.min_pressure_bar = min(health.min_pressure_bar, ...
        min(pressureBar, [], "all"));
    health.max_pressure_bar = max(health.max_pressure_bar, ...
        max(pressureBar, [], "all"));
    health.min_temperature_K = min(health.min_temperature_K, ...
        min(temperatureK, [], "all"));
    health.max_temperature_K = max(health.max_temperature_K, ...
        max(temperatureK, [], "all"));

    validRows = gasTotal > eps;
    moleFractionSum = zeros(size(gasTotal));
    for k = 1:params.nComs
        component = unit.gasCons.(params.sComNums{k});
        moleFraction = component(validRows) ./ gasTotal(validRows);
        if ~isempty(moleFraction)
            health.min_mole_fraction = min(health.min_mole_fraction, ...
                min(moleFraction, [], "all"));
            health.max_mole_fraction = max(health.max_mole_fraction, ...
                max(moleFraction, [], "all"));
        end
        moleFractionSum(validRows) = moleFractionSum(validRows) ...
            + component(validRows) ./ gasTotal(validRows);
    end

    if any(validRows, "all")
        sumError = abs(moleFractionSum(validRows) - 1);
        health.max_mole_fraction_sum_error = max( ...
            health.max_mole_fraction_sum_error, max(sumError, [], "all"));
    end
end

function rawRun = makeRawRunRecord(scaffold, fullParams, healthConfig)
    rawRun.case_id = scaffold.case_id;
    rawRun.model_mode = scaffold.model_mode;
    rawRun.components = scaffold.params.components;
    rawRun.nLKs = scaffold.params.nLKs;
    rawRun.nVols = fullParams.nVols;
    rawRun.nSteps = fullParams.nSteps;
    rawRun.nCycles = fullParams.nCycles;
    rawRun.durStep_s = fullParams.durStep;
    rawRun.sStepCol = fullParams.sStepCol;
    rawRun.thermal_mode = healthConfig.thermal_mode;
    rawRun.native_adsorption_flow_cm3_per_s = ...
        healthConfig.native_adsorption_flow_cm3_per_s;
end

function assertHealthPassed(summary)
    checks = summary.hard_checks;
    passed = checks.matlab_completed ...
        && checks.requested_cycles_completed ...
        && checks.no_nan_inf ...
        && checks.positive_pressure ...
        && checks.positive_temperature ...
        && checks.mole_fractions_valid ...
        && checks.summary_json_emitted;
    if ~passed
        error("run_schell_case_health:hardCheckFailed", ...
            "SCHELL-08 health run failed one or more hard checks.");
    end
end

function writeJson(filePath, value)
    jsonText = jsonencode(value);
    fid = fopen(filePath, "w");
    if fid < 0
        error("run_schell_case_health:jsonOpenFailed", ...
            "Could not open summary JSON for writing: %s", filePath);
    end
    cleanupObj = onCleanup(@() fclose(fid));
    fprintf(fid, "%s\n", jsonText);
end

function values = componentVector(components, valueStruct)
    values = zeros(numel(components), 1);
    for i = 1:numel(components)
        values(i) = valueStruct.(char(components(i)));
    end
end

function densityKgPerM3 = idealGasDensityKgPerM3(moleFractions, ...
    molecularWeightsGPerMol, pressureBar, temperatureK, gasConstantJ)
    mixtureMolecularWeightKgPerMol = sum(moleFractions(:) ...
        .* molecularWeightsGPerMol(:)) / 1000;
    densityKgPerM3 = (pressureBar * 1e5) * mixtureMolecularWeightKgPerMol ...
        / (gasConstantJ * temperatureK);
end

function text = stepTypes(stepNames)
    values = strings(size(stepNames));
    for i = 1:numel(stepNames)
        if stepNames(i) == "HP-FEE-RAF" || stepNames(i) == "LP-EXT-RAF"
            values(i) = "constant_pressure";
        else
            values(i) = "varying_pressure";
        end
    end
    text = joinStrings(values);
end

function text = flowDirections(stepNames)
    values = strings(size(stepNames));
    for i = 1:numel(stepNames)
        if stepNames(i) == "EQ-AFE-XXX"
            values(i) = "TBD";
        elseif stepNames(i) == "DP-EXT-XXX" || stepNames(i) == "LP-EXT-RAF"
            values(i) = "1_(negative)";
        else
            values(i) = "0_(positive)";
        end
    end
    text = joinStrings(values);
end

function text = valveRow(stepNames, adsValve, blowValve, ...
    equalizationValve, purgeValve, valveSide)
    values = zeros(size(stepNames));
    for i = 1:numel(stepNames)
        stepName = stepNames(i);
        if valveSide == "feed"
            if stepName == "EQ-AFE-XXX"
                values(i) = equalizationValve;
            elseif stepName == "RP-FEE-XXX" || stepName == "HP-FEE-RAF"
                values(i) = adsValve;
            elseif stepName == "DP-EXT-XXX"
                values(i) = blowValve;
            else
                values(i) = 0;
            end
        else
            if stepName == "LP-EXT-RAF"
                values(i) = purgeValve;
            elseif stepName == "HP-FEE-RAF"
                values(i) = 1;
            else
                values(i) = 0;
            end
        end
    end
    text = joinNumbers(values);
end

function text = joinNumbers(values)
    parts = strings(size(values));
    for i = 1:numel(values)
        parts(i) = strip(sprintf("%.16g", values(i)));
    end
    text = joinStrings(parts);
end

function text = joinStrings(values)
    text = strjoin(string(values), " ");
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

function cycleCase = findCycleCase(cycleCases, caseId)
    matches = false(numel(cycleCases), 1);
    for i = 1:numel(cycleCases)
        matches(i) = string(cycleCases(i).case_id) == caseId;
    end
    if nnz(matches) ~= 1
        error("run_schell_case_health:caseNotFound", ...
            "Expected exactly one Schell cycle case with case_id %s.", caseId);
    end
    cycleCase = cycleCases(matches);
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
