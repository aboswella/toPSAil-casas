% Tier 1 source/parameter transcription test for Schell 2013.
% Failure mode caught: source-pack or validation-target drift, text-encoded
% numeric constants, missing uncertainty guardrails, or accidental YAML
% source-of-truth duplication before simulation work begins.

repoRoot = fileparts(fileparts(mfilename("fullpath")));
packDir = fullfile(repoRoot, "params", "schell2013_ap360_sips_binary");
sourcePackPath = fullfile(packDir, "schell_2013_source_pack.json");
schemaPath = fullfile(packDir, "schell_2013_source_pack.schema.json");
targetsPath = fullfile(repoRoot, "validation", "targets", "schell_2013_validation_targets.csv");

fprintf("Tier 1 source: checking Schell source pack and validation targets.\n");

pack = readJsonObject(sourcePackPath);
schema = readJsonObject(schemaPath);
targets = readtable(targetsPath, "TextType", "string");

assert(islogical(pack.canonical) && isscalar(pack.canonical) && pack.canonical, ...
    "test_schell_source_pack:canonicalFlag", ...
    "Schell source pack must declare canonical == true.");

requiredTopFields = [
    "schema_version"
    "canonical"
    "paper"
    "units_policy"
    "gas_constant_J_per_mol_K"
    "components_order"
    "geometry"
    "bed_and_adsorbent"
    "feed_and_process"
    "cycle_cases"
    "model_parameters"
    "isotherm"
    "validation_policy"
    "unresolved_assumptions"
];
assertRequiredFields(pack, requiredTopFields, "source pack");
assertRequiredFields(pack, asStringArray(schema.required), "source pack per schema.required");
assertNoNumericStrings(pack, "source pack");

assertTable1Constants(pack);
assertCentralTargetConstants(pack, targets);
assertFlowConversionExamples(pack);
assertRequiredUnresolvedAssumptions(pack);
assertNoCanonicalYaml(packDir);

fprintf("Tier 1 source passed: Schell source pack and target constants are traceable.\n");

function value = readJsonObject(filePath)
    if ~isfile(filePath)
        error("test_schell_source_pack:missingJson", "Missing JSON file: %s", filePath);
    end
    value = jsondecode(fileread(filePath));
end

function values = asStringArray(value)
    if iscell(value)
        values = string(value);
    else
        values = string(value(:));
    end
    values = values(:);
end

function assertRequiredFields(obj, requiredFields, context)
    missing = strings(0, 1);
    for i = 1:numel(requiredFields)
        fieldName = requiredFields(i);
        if ~hasJsonField(obj, fieldName)
            missing(end + 1, 1) = fieldName; %#ok<AGROW>
        end
    end
    if ~isempty(missing)
        error("test_schell_source_pack:missingRequiredField", ...
            "%s is missing required field(s): %s", context, strjoin(missing, ", "));
    end
end

function tf = hasJsonField(obj, rawName)
    rawName = char(rawName);
    tf = isfield(obj, rawName) || isfield(obj, matlab.lang.makeValidName(rawName));
end

function value = getJsonField(obj, rawName)
    rawName = char(rawName);
    if isfield(obj, rawName)
        value = obj.(rawName);
        return
    end

    validName = matlab.lang.makeValidName(rawName);
    if isfield(obj, validName)
        value = obj.(validName);
        return
    end

    error("test_schell_source_pack:missingJsonField", ...
        "Missing JSON field: %s", rawName);
end

function assertNoNumericStrings(value, context)
    if isstruct(value)
        for itemIndex = 1:numel(value)
            names = string(fieldnames(value(itemIndex)));
            for i = 1:numel(names)
                name = names(i);
                assertNoNumericStrings(value(itemIndex).(name), context + "." + name);
            end
        end
    elseif iscell(value)
        for i = 1:numel(value)
            assertNoNumericStrings(value{i}, context + "{" + i + "}");
        end
    elseif isstring(value) || ischar(value)
        text = strtrim(string(value));
        numericLike = "^[+-]?((\d+(\.\d*)?)|(\.\d+))([eE][+-]?\d+)?$";
        if any(matches(text, numericLike))
            error("test_schell_source_pack:numericStoredAsText", ...
                "Numeric-looking value is stored as text at %s: %s", context, text);
        end
    end
end

function assertTable1Constants(pack)
    geometry = pack.geometry;
    bed = pack.bed_and_adsorbent;

    assertClose(geometry.column_length_m, 1.2, 1e-12, "geometry.column_length_m");
    assertClose(geometry.internal_radius_m, 0.0125, 1e-12, "geometry.internal_radius_m");
    assertClose(geometry.external_radius_m, 0.02, 1e-12, "geometry.external_radius_m");
    assertCloseArray(geometry.thermocouple_positions_m_from_bottom, ...
        [0.10, 0.35, 0.60, 0.85, 1.10], 1e-12, ...
        "geometry.thermocouple_positions_m_from_bottom");

    assertClose(bed.adsorbent_mass_per_bed_kg_approx, 0.28, 1e-12, ...
        "bed_and_adsorbent.adsorbent_mass_per_bed_kg_approx");
    assertClose(bed.material_density_kg_per_m3, 1965.0, 1e-12, ...
        "bed_and_adsorbent.material_density_kg_per_m3");
    assertClose(bed.particle_density_kg_per_m3, 850.0, 1e-12, ...
        "bed_and_adsorbent.particle_density_kg_per_m3");
    assertClose(bed.bed_density_kg_per_m3, 480.0, 1e-12, ...
        "bed_and_adsorbent.bed_density_kg_per_m3");
    assertClose(bed.particle_diameter_m, 0.003, 1e-12, ...
        "bed_and_adsorbent.particle_diameter_m");
    assertClose(bed.adsorbent_heat_capacity_J_per_kg_K, 1000.0, 1e-12, ...
        "bed_and_adsorbent.adsorbent_heat_capacity_J_per_kg_K");
    assertClose(bed.wall_heat_capacity_J_per_m3_K, 4.0e6, 1e-6, ...
        "bed_and_adsorbent.wall_heat_capacity_J_per_m3_K");
end

function assertCentralTargetConstants(pack, targets)
    expected.case_no = 5;
    expected.p_high_bar = 20.0;
    expected.t_press_s = 24.0;
    expected.t_ads_s = 40.0;
    expected.t_peq_s = 3.0;
    expected.t_blow_s = 50.0;
    expected.t_purge_s = 15.0;
    expected.h2_purity_pct = 93.4;
    expected.h2_purity_unc_pct = 1.5;
    expected.h2_recovery_pct = 74.4;
    expected.h2_recovery_unc_pct = 5.7;
    expected.co2_purity_pct = 78.7;
    expected.co2_purity_unc_pct = 4.7;
    expected.co2_recovery_pct = 94.8;
    expected.co2_recovery_unc_pct = 5.7;

    caseId = "schell_20bar_tads40_performance_central";
    cycleCase = findStructByField(pack.cycle_cases, "case_id", caseId);
    assertCaseConstants(cycleCase, expected, "source pack central cycle case");

    matchingRows = targets(targets.case_id == caseId, :);
    assert(height(matchingRows) == 1, ...
        "test_schell_source_pack:centralTargetRowCount", ...
        "Expected exactly one central target CSV row for %s.", caseId);
    assertCaseConstants(matchingRows, expected, "target CSV central row");
end

function item = findStructByField(items, fieldName, expectedValue)
    matchesFound = false(numel(items), 1);
    for i = 1:numel(items)
        matchesFound(i) = string(items(i).(fieldName)) == expectedValue;
    end
    assert(nnz(matchesFound) == 1, ...
        "test_schell_source_pack:caseLookupFailed", ...
        "Expected exactly one source-pack case with %s == %s.", fieldName, expectedValue);
    item = items(matchesFound);
end

function assertCaseConstants(caseData, expected, context)
    fields = string(fieldnames(expected));
    for i = 1:numel(fields)
        fieldName = fields(i);
        actual = caseData.(fieldName);
        if istable(actual)
            actual = actual{1, 1};
        end
        assertClose(actual, expected.(fieldName), 1e-12, context + "." + fieldName);
    end
end

function assertFlowConversionExamples(pack)
    basis = pack.feed_and_process.flow_rate_conversion_basis;
    examples = basis.examples_mol_per_s_at_298p15K;
    requiredExamples = [
        "20_cm3_per_s_at_1_bar"
        "20_cm3_per_s_at_10_bar"
        "20_cm3_per_s_at_20_bar"
        "20_cm3_per_s_at_30_bar"
        "50_cm3_per_s_at_1_bar"
    ];
    assertRequiredFields(examples, requiredExamples, ...
        "feed_and_process.flow_rate_conversion_basis.examples_mol_per_s_at_298p15K");

    central20bar = getJsonField(examples, "20_cm3_per_s_at_20_bar");
    assertClose(central20bar, 0.016135818218041397, 1e-14, ...
        "flow conversion 20 cm3/s at 20 bar");
    assertClose(central20bar, 0.01614, 5e-6, ...
        "flow conversion approximate central 20 bar value");
end

function assertRequiredUnresolvedAssumptions(pack)
    requiredIds = [
        "FLOW_BASIS"
        "P_PEQ"
        "CASE_INPUT_ROUTE"
        "SIPS_CORE_INTEGRATION"
        "TEMPERATURE_PROFILE_MANUAL_REVIEW"
    ];

    ids = strings(numel(pack.unresolved_assumptions), 1);
    for i = 1:numel(pack.unresolved_assumptions)
        ids(i) = string(pack.unresolved_assumptions(i).id);
    end

    missing = setdiff(requiredIds, ids);
    if ~isempty(missing)
        error("test_schell_source_pack:missingUnresolvedAssumptions", ...
            "Schell source pack is missing unresolved assumption ID(s): %s", ...
            strjoin(missing, ", "));
    end
end

function assertNoCanonicalYaml(packDir)
    yamlFiles = [
        dir(fullfile(packDir, "*.yaml"))
        dir(fullfile(packDir, "*.yml"))
    ];
    if ~isempty(yamlFiles)
        names = string({yamlFiles.name});
        error("test_schell_source_pack:yamlCanonicalDuplicate", ...
            "Schell source pack must remain JSON-only; remove YAML candidate(s): %s", ...
            strjoin(names, ", "));
    end
end

function assertClose(actual, expected, tolerance, context)
    assert(isnumeric(actual) && isscalar(actual) && isfinite(actual), ...
        "test_schell_source_pack:expectedNumericScalar", ...
        "Expected numeric scalar at %s.", context);
    if abs(double(actual) - double(expected)) > tolerance
        error("test_schell_source_pack:numericMismatch", ...
            "%s expected %.16g, got %.16g.", context, expected, actual);
    end
end

function assertCloseArray(actual, expected, tolerance, context)
    assert(isnumeric(actual), ...
        "test_schell_source_pack:expectedNumericArray", ...
        "Expected numeric array at %s.", context);
    actual = actual(:).';
    expected = expected(:).';
    assert(isequal(size(actual), size(expected)), ...
        "test_schell_source_pack:arraySizeMismatch", ...
        "%s expected size %s, got %s.", context, mat2str(size(expected)), mat2str(size(actual)));
    if any(abs(double(actual) - double(expected)) > tolerance, "all")
        error("test_schell_source_pack:arrayMismatch", ...
            "%s expected %s, got %s.", context, mat2str(expected), mat2str(actual));
    end
end
