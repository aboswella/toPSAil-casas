% Tier 2 equation-local test for the Schell 2013 competitive Sips equation.
% Failure mode caught: Pa/bar unit mistakes, component cross-talk in pure
% cases, incorrect temperature dependence, or confusing Sips affinity with
% the LDF mass-transfer coefficient, including after source-to-native
% component-order mapping.

repoRoot = fileparts(fileparts(mfilename("fullpath")));
sourcePackPath = fullfile(repoRoot, "params", "schell2013_ap360_sips_binary", ...
    "schell_2013_source_pack.json");
anchorPath = fullfile(repoRoot, "tests", "fixtures", ...
    "schell_2013_sips_anchor_cases.json");

fprintf("Tier 2 equations: checking Schell competitive Sips anchors.\n");

sourcePack = readJsonObject(sourcePackPath);
anchorPack = readJsonObject(anchorPath);

assert(string(sourcePack.isotherm.model_name) == "competitive_temperature_dependent_sips", ...
    "test_schell_sips_reference:wrongIsotherm", ...
    "Expected Schell competitive temperature-dependent Sips source parameters.");
assert(numel(anchorPack.anchor_cases) >= 6, ...
    "test_schell_sips_reference:missingAnchors", ...
    "Expected all independent Schell Sips anchor cases.");
assertSchellSipsDispatch();

computed = struct();
for i = 1:numel(anchorPack.anchor_cases)
    anchor = anchorPack.anchor_cases(i);
    caseId = string(anchor.case_id);
    loading = computeSchellSipsLoading(sourcePack, anchor);
    coreLoading = computeSchellSipsCoreLoading(sourcePack, anchor);
    assertAnchorLoading(caseId, "CO2", loading.CO2, anchor.expected_loading_mol_per_kg.CO2, anchor.tolerance);
    assertAnchorLoading(caseId, "H2", loading.H2, anchor.expected_loading_mol_per_kg.H2, anchor.tolerance);
    assertAnchorLoading(caseId, "CO2 core", coreLoading.CO2, anchor.expected_loading_mol_per_kg.CO2, anchor.tolerance);
    assertAnchorLoading(caseId, "H2 core", coreLoading.H2, anchor.expected_loading_mol_per_kg.H2, anchor.tolerance);
    computed.(matlab.lang.makeValidName(caseId)) = loading;
end

assertZeroPureAbsentComponent(computed);
assertPureCo2PressureMonotonicity(computed);
assertBinaryCo2TemperatureDependence(computed);

fprintf("Tier 2 equations passed: Schell Sips reference anchors match.\n");

function value = readJsonObject(filePath)
    if ~isfile(filePath)
        error("test_schell_sips_reference:missingJson", "Missing JSON file: %s", filePath);
    end
    value = jsondecode(fileread(filePath));
end

function assertSchellSipsDispatch()
    params.modSp = [7; 1; 1; 1; 0; 0; 0];
    params.bool = zeros(8, 1);
    [models, ~] = getSubModels(params);
    modelText = string(func2str(models{1}));
    assert(contains(modelText, "calcIsothermSchellSips"), ...
        "test_schell_sips_reference:sipsDispatchMissing", ...
        "modSp(1) == 7 must dispatch to calcIsothermSchellSips.");
end

function loading = computeSchellSipsLoading(sourcePack, anchor)
    R = sourcePack.gas_constant_J_per_mol_K;
    T = anchor.temperature_K;
    p = anchor.total_pressure_Pa;
    y.CO2 = anchor.mole_fraction.CO2;
    y.H2 = anchor.mole_fraction.H2;

    params = sourcePack.isotherm.parameters;
    co2 = computeSipsComponent(params.CO2, y.CO2, p, T, R);
    h2 = computeSipsComponent(params.H2, y.H2, p, T, R);

    denominator = 1.0 + co2.term + h2.term;
    loading.CO2 = co2.n_inf_mol_per_kg * co2.term / denominator;
    loading.H2 = h2.n_inf_mol_per_kg * h2.term / denominator;
end

function loading = computeSchellSipsCoreLoading(sourcePack, anchor)
    components = ["H2"; "CO2"];
    params = makeCoreSipsParams(sourcePack, anchor, components);
    states = [
        anchor.mole_fraction.H2, anchor.mole_fraction.CO2, ...
        0.0, 0.0, ...
        1.0, 1.0
    ];
    newStates = calcIsothermSchellSips(params, states, 0);
    loading.H2 = newStates(1, 3);
    loading.CO2 = newStates(1, 4);
end

function params = makeCoreSipsParams(sourcePack, anchor, components)
    isoParams = sourcePack.isotherm.parameters;
    params.nComs = 2;
    params.nVols = 1;
    params.nRows = 1;
    params.nStates = 2*params.nComs + 2;
    params.nColStT = params.nStates;
    params.nTemp = 2;
    params.sComNums = {'C1'; 'C2'};
    params.sTemp = {'cstr'; 'wall'};
    params.gasCons = sourcePack.gas_constant_J_per_mol_K * 10;
    params.teScaleFac = anchor.temperature_K;
    params.gConScaleFac = (anchor.total_pressure_Pa/1e5) ...
        / (params.gasCons * anchor.temperature_K);
    params.aConScaleFac = 1;
    params.schellSipsNInfA_molPerKg = componentValues(isoParams, components, "a");
    params.schellSipsNInfB_JPerMol = componentValues(isoParams, components, "b");
    params.schellSipsAffA_invPa = componentValues(isoParams, components, "A");
    params.schellSipsAffB_JPerMol = componentValues(isoParams, components, "B");
    params.schellSipsAlpha = componentValues(isoParams, components, "alpha");
    params.schellSipsBeta_invK = componentValues(isoParams, components, "beta");
    params.schellSipsSref = componentValues(isoParams, components, "sref");
    params.schellSipsTref_K = componentValues(isoParams, components, "Tref");
end

function component = computeSipsComponent(params, moleFraction, totalPressurePa, temperatureK, R)
    component.n_inf_mol_per_kg = params.a * exp(-params.b / (R * temperatureK));
    sipsAffinityInvPa = params.A * exp(-params.B / (R * temperatureK));
    exponent = params.alpha * atan(params.beta * (temperatureK - params.Tref)) + params.sref;
    component.term = (sipsAffinityInvPa * moleFraction * totalPressurePa) ^ exponent;
end

function values = componentValues(componentStruct, components, fieldName)
    values = zeros(1, numel(components));
    for i = 1:numel(components)
        componentName = char(components(i));
        values(i) = componentStruct.(componentName).(char(fieldName));
    end
end

function assertAnchorLoading(caseId, componentName, actual, expected, tolerance)
    absoluteTolerance = tolerance.absolute_mol_per_kg;
    relativeTolerance = tolerance.relative;
    allowedError = max(absoluteTolerance, relativeTolerance * max(abs(expected), absoluteTolerance));
    actualError = abs(actual - expected);
    if actualError > allowedError
        error("test_schell_sips_reference:anchorMismatch", ...
            "%s %s loading expected %.16g mol/kg, got %.16g mol/kg; allowed %.3g, error %.3g.", ...
            caseId, componentName, expected, actual, allowedError, actualError);
    end
end

function assertZeroPureAbsentComponent(computed)
    pureCo2 = computed.pure_CO2_298p15K_1bar;
    pureH2 = computed.pure_H2_298p15K_20bar;

    assert(abs(pureCo2.H2) <= 1e-10, ...
        "test_schell_sips_reference:pureCo2H2Loading", ...
        "Pure CO2 anchor must give zero H2 loading.");
    assert(abs(pureH2.CO2) <= 1e-10, ...
        "test_schell_sips_reference:pureH2Co2Loading", ...
        "Pure H2 anchor must give zero CO2 loading.");
end

function assertPureCo2PressureMonotonicity(computed)
    lowPressure = computed.pure_CO2_298p15K_1bar.CO2;
    highPressure = computed.pure_CO2_298p15K_20bar.CO2;
    assert(highPressure > lowPressure, ...
        "test_schell_sips_reference:pureCo2PressureMonotonicity", ...
        "Pure CO2 loading must increase from 1 bar to 20 bar.");
end

function assertBinaryCo2TemperatureDependence(computed)
    ambient = computed.binary_50_50_298p15K_20bar.CO2;
    hot = computed.binary_50_50_323p15K_20bar.CO2;
    assert(hot < ambient, ...
        "test_schell_sips_reference:binaryCo2TemperatureDependence", ...
        "Binary CO2 loading at 323.15 K must be lower than at 298.15 K.");
end
