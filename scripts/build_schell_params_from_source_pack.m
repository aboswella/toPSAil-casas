function scaffold = build_schell_params_from_source_pack(caseId, cyclesRequested)
%BUILD_SCHELL_PARAMS_FROM_SOURCE_PACK Build an inspectable Schell route-B scaffold.
%
% This is not a full simulation runner. It maps the canonical Schell source
% pack into a traceable params scaffold for the future runPsaCycle(params)
% route, including the optional non-default core Sips isotherm selector.

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

    scaffold.schema_version = "0.1.0";
    scaffold.route = "B_json_to_params_runPsaCycle";
    scaffold.model_mode = "topsail_native";
    scaffold.case_id = caseId;
    scaffold.source_pack_path = sourcePackPath;
    scaffold.source_pack_sha256 = sha256File(sourcePackPath);
    scaffold.params = makeParamsScaffold(sourcePack, cycleCase, caseId, cyclesRequested);
    scaffold.summary.expected_output_path = fullfile(repoRoot, "validation", ...
        "reports", "schell_2013", "health", ...
        caseId + "_summary.json");
    scaffold.run_entrypoint = "runPsaCycle(params)";
    scaffold.isotherm_route_ready = true;
    scaffold.run_ready = false;
    scaffold.not_run_reason = ...
        "SCHELL-08 health runner has not been implemented in this scaffold task.";
    scaffold.blocking_unresolved_assumption_ids = strings(0, 1);
    scaffold.unresolved_assumption_ids = collectUnresolvedIds(sourcePack);
end

function params = makeParamsScaffold(sourcePack, cycleCase, caseId, cyclesRequested)
    pressureHighPa = cycleCase.p_high_bar * 1e5;
    pressureLowPa = sourcePack.feed_and_process.low_pressure_Pa;
    flowBasis = sourcePack.feed_and_process.flow_rate_conversion_basis;

    params.case_id = caseId;
    params.model_mode = "topsail_native";
    params.route = "B_json_to_params_runPsaCycle";
    params.nCycles_requested = cyclesRequested;
    params.modSp_isotherm_selector = 7;
    params.nCols = 2;
    params.components = asStringArray(sourcePack.components_order);
    params.nComs = numel(params.components);

    params.geometry = sourcePack.geometry;
    params.bed_and_adsorbent = sourcePack.bed_and_adsorbent;
    params.feed.mole_fraction = [
        sourcePack.feed_and_process.feed_mole_fraction.CO2
        sourcePack.feed_and_process.feed_mole_fraction.H2
    ];
    params.feed.temperature_K = sourcePack.feed_and_process.feed_temperature_K;
    params.feed.ambient_temperature_K = sourcePack.feed_and_process.ambient_temperature_K;
    params.pressure.low_Pa = pressureLowPa;
    params.pressure.high_Pa = pressureHighPa;
    params.pressure.high_bar = cycleCase.p_high_bar;
    params.pressure.equalization_policy = ...
        "topsail_native_no_source_table_p_peq";

    params.step_times_s.pressurization = cycleCase.t_press_s;
    params.step_times_s.adsorption = cycleCase.t_ads_s;
    params.step_times_s.pressure_equalization = cycleCase.t_peq_s;
    params.step_times_s.blowdown = cycleCase.t_blow_s;
    params.step_times_s.purge = cycleCase.t_purge_s;

    params.flow.conversion_basis = flowBasis.primary_conversion_assumption;
    params.flow.warning_id = "FLOW_BASIS";
    params.flow.adsorption_cm3_per_s = flowBasis.adsorption_flow_cm3_per_s;
    params.flow.purge_cm3_per_s = flowBasis.purge_flow_cm3_per_s;
    params.flow.adsorption_mol_per_s_at_high_pressure = ...
        convertCm3PerSecToMolPerSec( ...
            flowBasis.adsorption_flow_cm3_per_s, pressureHighPa, ...
            sourcePack.feed_and_process.feed_temperature_K, ...
            sourcePack.gas_constant_J_per_mol_K);
    params.flow.purge_mol_per_s_at_low_pressure = ...
        convertCm3PerSecToMolPerSec( ...
            flowBasis.purge_flow_cm3_per_s, pressureLowPa, ...
            sourcePack.feed_and_process.feed_temperature_K, ...
            sourcePack.gas_constant_J_per_mol_K);

    params.model_parameters = sourcePack.model_parameters;
    params.isotherm.model_name = string(sourcePack.isotherm.model_name);
    params.isotherm.selector = 7;
    params.isotherm.parameters = sourcePack.isotherm.parameters;
    params.isotherm.core_integration_status = ...
        "ready_optional_nondefault_core_sips";
    params.isotherm.do_not_substitute = ...
        "native_extended_langmuir_freundlich_is_not_schell_sips";
    params = addSchellSipsCoreParams(params, sourcePack.isotherm.parameters);
    params.boundary_condition_mode = ...
        "topsail_native_no_schell_pressure_functions";
    params.omitted_default_diagnostics = [
        "schell_pressure_boundary_reproduction_details"
        "piping_diagnostics"
        "stagnant_tank_diagnostic"
    ];
end

function params = addSchellSipsCoreParams(params, isoParams)
    params.schellSipsNInfA_molPerKg = [isoParams.CO2.a, isoParams.H2.a];
    params.schellSipsNInfB_JPerMol = [isoParams.CO2.b, isoParams.H2.b];
    params.schellSipsAffA_invPa = [isoParams.CO2.A, isoParams.H2.A];
    params.schellSipsAffB_JPerMol = [isoParams.CO2.B, isoParams.H2.B];
    params.schellSipsAlpha = [isoParams.CO2.alpha, isoParams.H2.alpha];
    params.schellSipsBeta_invK = [isoParams.CO2.beta, isoParams.H2.beta];
    params.schellSipsSref = [isoParams.CO2.sref, isoParams.H2.sref];
    params.schellSipsTref_K = [isoParams.CO2.Tref, isoParams.H2.Tref];
end

function cycleCase = findCycleCase(cycleCases, caseId)
    matches = false(numel(cycleCases), 1);
    for i = 1:numel(cycleCases)
        matches(i) = string(cycleCases(i).case_id) == caseId;
    end

    if nnz(matches) ~= 1
        error("build_schell_params_from_source_pack:caseNotFound", ...
            "Expected exactly one Schell cycle case with case_id %s.", caseId);
    end

    cycleCase = cycleCases(matches);
end

function values = asStringArray(value)
    if iscell(value)
        values = string(value);
    else
        values = string(value(:));
    end
    values = values(:);
end

function flowMolPerSec = convertCm3PerSecToMolPerSec(flowCm3PerSec, pressurePa, temperatureK, gasConstant)
    flowMolPerSec = pressurePa * (flowCm3PerSec * 1e-6) ...
        / (gasConstant * temperatureK);
end

function ids = collectUnresolvedIds(sourcePack)
    ids = strings(numel(sourcePack.unresolved_assumptions), 1);
    for i = 1:numel(sourcePack.unresolved_assumptions)
        ids(i) = string(sourcePack.unresolved_assumptions(i).id);
    end
end

function hash = sha256File(filePath)
    fid = fopen(filePath, "r");
    if fid < 0
        error("build_schell_params_from_source_pack:hashOpenFailed", ...
            "Could not open file for hashing: %s", filePath);
    end
    cleanupObj = onCleanup(@() fclose(fid));
    bytes = fread(fid, Inf, "uint8=>uint8");

    digestEngine = java.security.MessageDigest.getInstance("SHA-256");
    digestEngine.update(bytes);
    digest = typecast(digestEngine.digest(), "uint8");
    hash = lower(string(reshape(dec2hex(digest, 2).', 1, [])));
end
