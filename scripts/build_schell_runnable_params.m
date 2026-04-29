function [params, fullParams, runConfig, scaffold, sourcePack, cycleCase] = ...
    build_schell_runnable_params(caseId, cyclesRequested, options)
%BUILD_SCHELL_RUNNABLE_PARAMS Build runnable toPSAil params for Schell route B.
%
% The source of truth remains the canonical Schell JSON pack. This helper
% constructs the native params struct used by runPsaCycle(params), while
% keeping Schell-specific pressure functions and validation tuning out of
% the default toPSAil-native route.

    if nargin < 1 || isempty(caseId)
        caseId = "schell_20bar_tads40_performance_central";
    else
        caseId = string(caseId);
    end

    if nargin < 2 || isempty(cyclesRequested)
        cyclesRequested = 1;
    end

    if nargin < 3 || isempty(options)
        options = struct();
    end

    scriptDir = fileparts(mfilename("fullpath"));
    repoRoot = fileparts(scriptDir);
    sourcePackPath = fullfile(repoRoot, "params", ...
        "schell2013_ap360_sips_binary", "schell_2013_source_pack.json");
    sourcePack = jsondecode(fileread(sourcePackPath));
    cycleCase = findCycleCase(sourcePack.cycle_cases, caseId);

    scaffold = build_schell_params_from_source_pack(caseId, cyclesRequested);
    runConfig = makeRunConfig(sourcePack, cycleCase, options);
    runConfig.accepted_cycle_cap = cyclesRequested;

    rawParams = makeRawSchellParams(scaffold.params, sourcePack, ...
        cycleCase, cyclesRequested, runConfig, 1.0);
    [~, trialFullParams] = deriveTopsailParams(rawParams);
    scaleFactor = runConfig.topsail_native_adsorption_flow_target_cm3_per_s ...
        / max(abs(trialFullParams.volFlowFeed), eps);

    rawParams = makeRawSchellParams(scaffold.params, sourcePack, ...
        cycleCase, cyclesRequested, runConfig, scaleFactor);
    [params, fullParams] = deriveTopsailParams(rawParams);

    runConfig.topsail_native_adsorption_flow_observed_cm3_per_s = ...
        fullParams.volFlowFeed;
    runConfig.topsail_native_adsorption_flow_error_cm3_per_s = ...
        fullParams.volFlowFeed ...
        - runConfig.topsail_native_adsorption_flow_target_cm3_per_s;
    runConfig.valve_scale_factor = scaleFactor;
    runConfig.cycle_duration_s = sum(fullParams.durStep);
end

function config = makeRunConfig(sourcePack, cycleCase, options)
    flowBasis = sourcePack.feed_and_process.flow_rate_conversion_basis;
    feedTemperatureK = sourcePack.feed_and_process.feed_temperature_K;
    nativeComponents = ["H2"; "CO2"];
    feedMoleFractionNative = componentVector(nativeComponents, ...
        sourcePack.feed_and_process.feed_mole_fraction).';

    config.schema_version = "0.1.0";
    config.run_label = getOption(options, "run_label", "schell_native");
    config.grid_cells = getOption(options, "grid_cells", 20);
    config.time_points_per_step = getOption(options, ...
        "time_points_per_step", 20);
    config.thermal_mode = getOption(options, "thermal_mode", ...
        "isothermal_health_check");
    config.native_pressure_flow_mode = getOption(options, ...
        "native_pressure_flow_mode", ...
        "topsail_native_no_axial_pressure_drop_flow_control");
    config.equalization_mode = getOption(options, "equalization_mode", ...
        "topsail_native_feed_end_equalization");
    config.css_tolerance = getOption(options, "css_tolerance", 1e-8);
    config.ode_abs_tol = getOption(options, "ode_abs_tol", 1e-6);
    config.ode_rel_tol = getOption(options, "ode_rel_tol", 1e-3);
    config.source_adsorption_actual_flow_cm3_per_s = ...
        flowBasis.adsorption_flow_cm3_per_s;
    config.source_purge_actual_flow_cm3_per_s = ...
        flowBasis.purge_flow_cm3_per_s;
    config.source_flow_basis = flowBasis.primary_conversion_assumption;
    config.topsail_native_flow_basis = ...
        "toPSAil calcVolFlowFeed normalisation basis at column pressure/temperature and standard reference pressure/temperature";
    config.topsail_native_flow_conversion_formula = ...
        "source_actual_cm3_per_s * (tempCol / presColHigh) * (presStan / tempStan)";
    config.topsail_native_adsorption_flow_target_cm3_per_s = ...
        convertSourceActualFlowToTopsailNativeBasis( ...
            config.source_adsorption_actual_flow_cm3_per_s, ...
            feedTemperatureK, cycleCase.p_high_bar, 1.01325, 273.15);
    config.topsail_native_purge_flow_at_low_pressure_cm3_per_s = ...
        convertSourceActualFlowToTopsailNativeBasis( ...
            config.source_purge_actual_flow_cm3_per_s, ...
            feedTemperatureK, ...
            sourcePack.feed_and_process.low_pressure_Pa / 1e5, ...
            1.01325, 273.15);
    config.old_unconverted_adsorption_flow_target_cm3_per_s = ...
        config.source_adsorption_actual_flow_cm3_per_s;
    config.flow_basis_old_to_converted_factor = ...
        config.old_unconverted_adsorption_flow_target_cm3_per_s ...
        / config.topsail_native_adsorption_flow_target_cm3_per_s;
    sourceAdsorptionMolPerSec = convertActualCm3PerSecToMolPerSec( ...
        config.source_adsorption_actual_flow_cm3_per_s, ...
        cycleCase.p_high_bar * 1e5, feedTemperatureK, ...
        sourcePack.gas_constant_J_per_mol_K);
    config.expected_source_adsorption_total_mol_per_s = ...
        sourceAdsorptionMolPerSec;
    config.expected_source_adsorption_moles_per_component_two_beds = ...
        sourceAdsorptionMolPerSec * cycleCase.t_ads_s * 2 ...
        .* feedMoleFractionNative;
    config.expected_source_adsorption_inventory_basis = ...
        "Schell source actual adsorption flow at p_high and 298.15 K, integrated over t_ads once per bed for two beds";
    config.purge_native_step = getOption(options, ...
        "purge_native_step", "HP-ATM-FEE");
    config.purge_source_basis = getOption(options, ...
        "purge_source_basis", ...
        "equimolar feed tank inventory enters the product end during low-pressure countercurrent purge");
    config.purge_connection_note = getOption(options, ...
        "purge_connection_note", ...
        "native HP-ATM-FEE is used as a low-pressure countercurrent purge: feed tank supplies equimolar gas to the product end, and the feed-end outlet is routed to the extract-waste side without core boundary-condition changes");
    config.purge_valve_relative_to_adsorption = getOption(options, ...
        "purge_valve_relative_to_adsorption", ...
        calcFeedTankPurgeValveRelative(sourcePack, cycleCase, config));
    config.purge_valve_basis = getOption(options, ...
        "purge_valve_basis", ...
        "adapter purge-source guard: HP-ATM-FEE valve is pressure-normalized so Schell's low-pressure purge/feed volumetric-flow ratio is not inflated by feed-tank headroom");
    config.pressurization_valve_reference_relative_before_flow_basis_conversion = ...
        0.016;
    config.pressurization_valve_relative_to_adsorption = getOption(options, ...
        "pressurization_valve_relative_to_adsorption", ...
        config.pressurization_valve_reference_relative_before_flow_basis_conversion ...
        * config.flow_basis_old_to_converted_factor);
    config.pressurization_valve_basis = getOption(options, ...
        "pressurization_valve_basis", ...
        "adapter pressure-program guard: RP-FEE-XXX uses a separate valve rescaled with the flow-basis conversion so the column reaches source p_high instead of preserving an under-pressured Type VII adsorption step");
    if ~(isnumeric(config.pressurization_valve_relative_to_adsorption) ...
            && isscalar(config.pressurization_valve_relative_to_adsorption) ...
            && isfinite(config.pressurization_valve_relative_to_adsorption) ...
            && config.pressurization_valve_relative_to_adsorption > 0)
        error("build_schell_runnable_params:badPressurizationValveScale", ...
            "pressurization_valve_relative_to_adsorption must be a positive finite scalar.");
    end
    if ~(isnumeric(config.purge_valve_relative_to_adsorption) ...
            && isscalar(config.purge_valve_relative_to_adsorption) ...
            && isfinite(config.purge_valve_relative_to_adsorption) ...
            && config.purge_valve_relative_to_adsorption > 0)
        error("build_schell_runnable_params:badPurgeValveScale", ...
            "purge_valve_relative_to_adsorption must be a positive finite scalar.");
    end
    config.flow_basis_warning_id = "FLOW_BASIS";
    config.equalization_warning_id = "P_PEQ";
    config.profile_warning_id = "TEMPERATURE_PROFILE_MANUAL_REVIEW";
end

function value = calcFeedTankPurgeValveRelative(sourcePack, cycleCase, config)
    pHighBar = cycleCase.p_high_bar;
    pLowBar = sourcePack.feed_and_process.low_pressure_Pa / 1e5;
    pFeedTankBar = 1.1 * pHighBar;
    adsorptionPressureDropBar = pFeedTankBar - pHighBar;
    purgePressureDropBar = pFeedTankBar - pLowBar;
    purgeToAdsorptionVolRatio = ...
        config.source_purge_actual_flow_cm3_per_s ...
        / config.source_adsorption_actual_flow_cm3_per_s;
    purgeToAdsorptionMolarRatio = purgeToAdsorptionVolRatio ...
        * pLowBar / pHighBar;
    value = purgeToAdsorptionMolarRatio ...
        * adsorptionPressureDropBar / purgePressureDropBar;
end

function value = convertSourceActualFlowToTopsailNativeBasis( ...
    flowCm3PerSec, temperatureK, pressureBar, presStanBar, tempStanK)
    value = flowCm3PerSec ...
        * (temperatureK / pressureBar) ...
        * (presStanBar / tempStanK);
end

function flowMolPerSec = convertActualCm3PerSecToMolPerSec( ...
    flowCm3PerSec, pressurePa, temperatureK, gasConstantJ)
    flowMolPerSec = pressurePa * (flowCm3PerSec * 1e-6) ...
        / (gasConstantJ * temperatureK);
end

function value = getOption(options, fieldName, defaultValue)
    if isfield(options, fieldName)
        value = options.(fieldName);
    else
        value = defaultValue;
    end
end

function raw = makeRawSchellParams(scaffoldParams, sourcePack, cycleCase, ...
    cyclesRequested, runConfig, valveScale)
    nativeComponents = scaffoldParams.components;
    gasConstantJ = sourcePack.gas_constant_J_per_mol_K;
    adsValve = 5.0e-6 * valveScale;
    blowValve = adsValve;
    equalizationValve = adsValve;
    pressValve = adsValve ...
        * runConfig.pressurization_valve_relative_to_adsorption;
    purgeValve = adsValve ...
        * runConfig.purge_valve_relative_to_adsorption;

    raw.bool = [1; 0; 0; 0; 0; 0; 0; 0; 1; 0; 1; 0];
    raw.modSp = [7; 1; 1; 1; 0; 0; 0];
    raw.nVols = runConfig.grid_cells;
    raw.nTiPts = runConfig.time_points_per_step;
    raw.numIntSolv = "ode15s";
    raw.odeAbsTol = runConfig.ode_abs_tol;
    raw.odeRelTol = runConfig.ode_rel_tol;
    raw.numZero = runConfig.css_tolerance;
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
    raw.durStep = makeCentralStepDurations(cycleCase);
    raw.eveVal = joinNumbers(zeros(1, raw.nSteps));
    raw.eveUnit = joinStrings(repmat("None", 1, raw.nSteps));
    raw.eveLoc = joinStrings(repmat("None", 1, raw.nSteps));

    stepCol1 = ["EQ-AFE-XXX", "RP-FEE-XXX", "HP-FEE-RAF", ...
        "HP-FEE-RAF", "RT-XXX-XXX", "EQ-AFE-XXX", ...
        "DP-EXT-XXX", "DP-EXT-XXX", "HP-ATM-FEE", "HP-ATM-FEE"];
    stepCol2 = ["EQ-AFE-XXX", "DP-EXT-XXX", "DP-EXT-XXX", ...
        "HP-ATM-FEE", "HP-ATM-FEE", "EQ-AFE-XXX", ...
        "RP-FEE-XXX", "HP-FEE-RAF", "HP-FEE-RAF", "RT-XXX-XXX"];
    raw.sStepCol = {char(joinStrings(stepCol1)); char(joinStrings(stepCol2))};
    raw.sTypeCol = {char(stepTypes(stepCol1)); char(stepTypes(stepCol2))};
    raw.valFeedCol = {char(valveRow(stepCol1, adsValve, pressValve, ...
        blowValve, equalizationValve, purgeValve, "feed")); ...
        char(valveRow(stepCol2, adsValve, pressValve, blowValve, ...
        equalizationValve, purgeValve, "feed"))};
    raw.valProdCol = {char(valveRow(stepCol1, adsValve, pressValve, ...
        blowValve, equalizationValve, purgeValve, "product")); ...
        char(valveRow(stepCol2, adsValve, pressValve, blowValve, ...
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

function text = makeCentralStepDurations(cycleCase)
    durations = [ ...
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
            - (cycleCase.t_blow_s - cycleCase.t_press_s))];

    if any(durations <= 0)
        error("build_schell_runnable_params:nonpositiveStepDuration", ...
            "Route-B schedule currently supports only positive central-case substeps.");
    end

    text = joinNumbers(durations);
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
        if stepNames(i) == "HP-FEE-RAF" || stepNames(i) == "HP-ATM-FEE"
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
        elseif stepNames(i) == "DP-EXT-XXX" || stepNames(i) == "HP-ATM-FEE"
            values(i) = "1_(negative)";
        else
            values(i) = "0_(positive)";
        end
    end
    text = joinStrings(values);
end

function text = valveRow(stepNames, adsValve, pressValve, blowValve, ...
    equalizationValve, purgeValve, valveSide)
    values = zeros(size(stepNames));
    for i = 1:numel(stepNames)
        stepName = stepNames(i);
        if valveSide == "feed"
            if stepName == "EQ-AFE-XXX"
                values(i) = equalizationValve;
            elseif stepName == "RP-FEE-XXX"
                values(i) = pressValve;
            elseif stepName == "HP-FEE-RAF"
                values(i) = adsValve;
            elseif stepName == "DP-EXT-XXX"
                values(i) = blowValve;
            else
                values(i) = 0;
            end
        else
            if stepName == "HP-ATM-FEE"
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

function cycleCase = findCycleCase(cycleCases, caseId)
    matches = false(numel(cycleCases), 1);
    for i = 1:numel(cycleCases)
        matches(i) = string(cycleCases(i).case_id) == caseId;
    end
    if nnz(matches) ~= 1
        error("build_schell_runnable_params:caseNotFound", ...
            "Expected exactly one Schell cycle case with case_id %s.", caseId);
    end
    cycleCase = cycleCases(matches);
end
