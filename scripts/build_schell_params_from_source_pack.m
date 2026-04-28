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
    sourceComponents = asStringArray(sourcePack.components_order);
    topsailComponents = ["H2"; "CO2"];
    assertSameComponentSet(sourceComponents, topsailComponents);
    topsailNativeToSourceIndex = componentIndices(sourceComponents, topsailComponents);
    sourceToTopsailNativeIndex = componentIndices(topsailComponents, sourceComponents);

    params.case_id = caseId;
    params.model_mode = "topsail_native";
    params.route = "B_json_to_params_runPsaCycle";
    params.nCycles_requested = cyclesRequested;
    params.modSp_isotherm_selector = 7;
    params.nCols = 2;
    params.component_order.source = sourceComponents;
    params.component_order.topsail_native = topsailComponents;
    params.component_order.note = ...
        "source order is preserved for traceability; topsail_native order puts the light product first";
    params.component_mapping.topsail_native_to_source_index = topsailNativeToSourceIndex;
    params.component_mapping.source_to_topsail_native_index = sourceToTopsailNativeIndex;
    params.components = topsailComponents;
    params.nComs = numel(params.components);
    params.nLKs = 1;
    params.component_roles.light_product = "H2";
    params.component_roles.heavy_product = "CO2";
    params.component_roles.raffinate_product = "H2";
    params.component_roles.extract_product = "CO2";

    params.geometry = sourcePack.geometry;
    params.bed_and_adsorbent = sourcePack.bed_and_adsorbent;
    params.feed.mole_fraction = componentValues( ...
        sourcePack.feed_and_process.feed_mole_fraction, topsailComponents).';
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
    params.topsail_native_vectors.ldf_rate_per_s = componentValues( ...
        sourcePack.model_parameters.LDF_mass_transfer_coefficient_per_s, ...
        topsailComponents);
    params.topsail_native_vectors.gas_heat_capacity_J_per_mol_K = ...
        componentValues(sourcePack.model_parameters.gas_heat_capacity_J_per_mol_K, ...
        topsailComponents);
    params.topsail_native_vectors.heat_of_adsorption_J_per_mol = ...
        componentValues(sourcePack.isotherm.parameters, topsailComponents, "deltaH");
    params.isotherm.model_name = string(sourcePack.isotherm.model_name);
    params.isotherm.selector = 7;
    params.isotherm.parameters = sourcePack.isotherm.parameters;
    params.isotherm.parameters_component_order = "source";
    params.isotherm.topsail_native_component_order = topsailComponents;
    params.isotherm.heat_of_adsorption_J_per_mol = ...
        params.topsail_native_vectors.heat_of_adsorption_J_per_mol;
    params.isotherm.core_integration_status = ...
        "ready_optional_nondefault_core_sips";
    params.isotherm.do_not_substitute = ...
        "native_extended_langmuir_freundlich_is_not_schell_sips";
    params = addSchellSipsCoreParams(params, sourcePack.isotherm.parameters, ...
        topsailComponents);
    params.boundary_condition_mode = ...
        "topsail_native_no_schell_pressure_functions";
    params.omitted_default_diagnostics = [
        "schell_pressure_boundary_reproduction_details"
        "piping_diagnostics"
        "stagnant_tank_diagnostic"
    ];
end

function params = addSchellSipsCoreParams(params, isoParams, components)
    params.schellSipsNInfA_molPerKg = componentValues(isoParams, components, "a");
    params.schellSipsNInfB_JPerMol = componentValues(isoParams, components, "b");
    params.schellSipsAffA_invPa = componentValues(isoParams, components, "A");
    params.schellSipsAffB_JPerMol = componentValues(isoParams, components, "B");
    params.schellSipsAlpha = componentValues(isoParams, components, "alpha");
    params.schellSipsBeta_invK = componentValues(isoParams, components, "beta");
    params.schellSipsSref = componentValues(isoParams, components, "sref");
    params.schellSipsTref_K = componentValues(isoParams, components, "Tref");
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

function assertSameComponentSet(sourceComponents, topsailComponents)
    if ~isequal(sort(sourceComponents), sort(topsailComponents))
        error("build_schell_params_from_source_pack:componentSetMismatch", ...
            "Source components [%s] do not match toPSAil-native components [%s].", ...
            strjoin(sourceComponents, ", "), strjoin(topsailComponents, ", "));
    end
end

function indices = componentIndices(fromComponents, toComponents)
    indices = zeros(numel(toComponents), 1);
    for i = 1:numel(toComponents)
        match = find(fromComponents == toComponents(i), 1);
        if isempty(match)
            error("build_schell_params_from_source_pack:componentLookupFailed", ...
                "Could not map component %s.", toComponents(i));
        end
        indices(i) = match;
    end
end

function values = componentValues(componentStruct, components, fieldName)
    values = zeros(1, numel(components));
    for i = 1:numel(components)
        componentName = char(components(i));
        if nargin < 3
            values(i) = componentStruct.(componentName);
        else
            values(i) = componentStruct.(componentName).(char(fieldName));
        end
    end
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
