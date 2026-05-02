function testYangValveCoefficientScaling()
%TESTYANGVALVECOEFFICIENTSCALING FI-8 Yang Cv basis consistency.
%
% Tier: Unit/adapter smoke. Runtime class: < 10 s. Default smoke: yes.
% Failure modes caught: native-style dimensional top-level Cv controls used
% raw in adapter pressure-flow laws, missing valve-basis metadata, and
% default-control drift before valve sensitivity or optimisation work.

    testResolver();
    testDefaultControls();
    testPpPuAdapterScaling();
    testAdppBfAdapterScaling();

    fprintf('FI-8 Yang valve coefficient scaling passed: adapter Cvs use raw/effective basis metadata.\n');
end

function testResolver()
    params = struct("valScaleFac", 123.0);
    raw = 2.0e-6;
    assert(abs(resolveYangValveCoefficient(raw, params, struct(), "Cv_test") - raw * 123.0) < eps);
    assert(abs(resolveYangValveCoefficient(raw, params, ...
        struct("adapterCvBasis", "dimensional_kmol_per_bar_s"), "Cv_test") - raw * 123.0) < eps);
    assert(abs(resolveYangValveCoefficient(raw, params, ...
        struct("adapterCvBasis", "scaled_dimensionless"), "Cv_test") - raw) < eps);

    assertErrorIdentifier(@() resolveYangValveCoefficient(raw, params, ...
        struct("adapterCvBasis", "mystery_basis"), "Cv_test"), ...
        'FI8:UnknownValveCoefficientBasis');
    assertErrorIdentifier(@() resolveYangValveCoefficient(-raw, params, struct(), "Cv_test"), ...
        'FI8:InvalidValveCoefficient');
    assertErrorIdentifier(@() resolveYangValveCoefficient(NaN, params, struct(), "Cv_test"), ...
        'FI8:InvalidValveCoefficient');
    assertErrorIdentifier(@() resolveYangValveCoefficient(Inf, params, struct(), "Cv_test"), ...
        'FI8:InvalidValveCoefficient');
end

function testDefaultControls()
    controls = normalizeYangFourBedControls(struct(), struct());
    assert(controls.cycleTimeSec == 240);
    assert(controls.feedVelocityCmSec == 5.2);
    assert(controls.Cv_AD_feed == 5.0e-7);
    assert(controls.Cv_ADPP_feed == 1.0e-6);
    assert(controls.Cv_ADPP_product == 1.0e-6);
    assert(controls.Cv_ADPP_BF_internal == 5.0e-7);
    assert(controls.Cv_EQI == 1.0e-6);
    assert(controls.Cv_EQII == 1.0e-6);
    assert(controls.Cv_PP_PU_internal == 1.0e-6);
    assert(controls.Cv_PU_waste == 2.0e-6);
    assert(controls.Cv_BD_waste == 2.0e-6);
    assert(controls.adapterCvBasis == "dimensional_kmol_per_bar_s");

    override = normalizeYangFourBedControls(struct( ...
        "Cv_PU_waste", 9.0e-6, ...
        "adapterCvBasis", "scaled_dimensionless"), struct());
    assert(override.Cv_PU_waste == 9.0e-6);
    assert(override.Cv_PP_PU_internal == 1.0e-6);
    assert(override.adapterCvBasis == "scaled_dimensionless");
end

function testPpPuAdapterScaling()
    [params, ppCase] = buildAdapterContext("PP_PU");
    params.valScaleFac = 123.0;

    rawConfig = makePpPuConfig();
    [dimConfig, ~] = validateYangDirectCouplingAdapterInputs(ppCase, params, rawConfig);
    assert(dimConfig.adapterCvBasis == "dimensional_kmol_per_bar_s");
    assert(dimConfig.rawCv.Cv_PP_PU_internal == rawConfig.Cv_PP_PU_internal);
    assert(dimConfig.effectiveCv.Cv_PP_PU_internal == ...
        rawConfig.Cv_PP_PU_internal * params.valScaleFac);
    assert(dimConfig.effectiveCv.Cv_PU_waste == ...
        rawConfig.Cv_PU_waste * params.valScaleFac);

    [~, report] = runYangDirectCouplingAdapter(ppCase, params, ...
        setfield(rawConfig, 'validationOnly', true)); %#ok<SFLD>
    assert(report.rawCv.Cv_PP_PU_internal == rawConfig.Cv_PP_PU_internal);
    assert(report.effectiveCv.Cv_PP_PU_internal == dimConfig.effectiveCv.Cv_PP_PU_internal);
    assert(report.valveCoefficientBasis == "dimensional_kmol_per_bar_s");
    assert(report.adapterCvScalingApplied);
    assert(report.valScaleFac == params.valScaleFac);

    scaledConfig = rawConfig;
    scaledConfig.Cv_PP_PU_internal = rawConfig.Cv_PP_PU_internal * params.valScaleFac;
    scaledConfig.Cv_PU_waste = rawConfig.Cv_PU_waste * params.valScaleFac;
    scaledConfig.adapterCvBasis = "scaled_dimensionless";
    [scaledConfig, ~] = validateYangDirectCouplingAdapterInputs(ppCase, params, scaledConfig);
    assertEquivalentPpPuFlow(params, ppCase, dimConfig, scaledConfig);
end

function testAdppBfAdapterScaling()
    [params, adppCase] = buildAdapterContext("ADPP_BF");
    params.valScaleFac = 123.0;

    rawConfig = makeAdppBfConfig();
    [dimConfig, ~] = validateYangAdppBfAdapterInputs(adppCase, params, rawConfig);
    assert(dimConfig.adapterCvBasis == "dimensional_kmol_per_bar_s");
    assert(dimConfig.rawCv.Cv_ADPP_feed == rawConfig.Cv_ADPP_feed);
    assert(dimConfig.effectiveCv.Cv_ADPP_feed == ...
        rawConfig.Cv_ADPP_feed * params.valScaleFac);
    assert(dimConfig.effectiveCv.Cv_ADPP_product == ...
        rawConfig.Cv_ADPP_product * params.valScaleFac);
    assert(dimConfig.effectiveCv.Cv_ADPP_BF_internal == ...
        rawConfig.Cv_ADPP_BF_internal * params.valScaleFac);

    [~, report] = runYangDirectCouplingAdapter(adppCase, params, ...
        setfield(rawConfig, 'validationOnly', true)); %#ok<SFLD>
    assert(report.rawCv.Cv_ADPP_feed == rawConfig.Cv_ADPP_feed);
    assert(report.effectiveCv.Cv_ADPP_BF_internal == dimConfig.effectiveCv.Cv_ADPP_BF_internal);
    assert(report.valveCoefficientBasis == "dimensional_kmol_per_bar_s");
    assert(report.adapterCvScalingApplied);
    assert(report.valScaleFac == params.valScaleFac);

    scaledConfig = rawConfig;
    scaledConfig.Cv_ADPP_feed = rawConfig.Cv_ADPP_feed * params.valScaleFac;
    scaledConfig.Cv_ADPP_product = rawConfig.Cv_ADPP_product * params.valScaleFac;
    scaledConfig.Cv_ADPP_BF_internal = rawConfig.Cv_ADPP_BF_internal * params.valScaleFac;
    scaledConfig.adapterCvBasis = "scaled_dimensionless";
    [scaledConfig, ~] = validateYangAdppBfAdapterInputs(adppCase, params, scaledConfig);
    assertEquivalentAdppBfFlow(params, adppCase, dimConfig, scaledConfig);
end

function [params, tempCase] = buildAdapterContext(family)
    params = buildYangH2Co2AcTemplateParams("NVols", 2, "NCols", 2, "NSteps", 1);
    manifest = getYangFourBedScheduleManifest();
    pairMap = getYangDirectTransferPairMap(manifest);
    container = makeYangFourBedStateContainer(makePhysicalStates(params), ...
        'Manifest', manifest, ...
        'PairMap', pairMap, ...
        'InitializationPolicy', "FI8_valve_scaling_physical_states", ...
        'SourceNote', "FI-8 valve scaling tests");

    switch string(family)
        case "PP_PU"
            selection = selectPair(container, pairMap, "PP_PU", "B", "A");
        case "ADPP_BF"
            selection = selectPair(container, pairMap, "ADPP_BF", "A", "B");
        otherwise
            error('test:UnsupportedFamily', 'Unsupported family %s.', char(family));
    end
    tempCase = makeYangTemporaryPairedCase(selection, ...
        'DurationDimless', 0.01, ...
        'RunnerMode', "wrapper_adapter", ...
        'CaseNote', "FI-8 valve scaling adapter context");
end

function selection = selectPair(container, pairMap, family, donor, receiver)
    pair = pairMap.transferPairs( ...
        pairMap.transferPairs.direct_transfer_family == string(family) & ...
        pairMap.transferPairs.donor_bed == string(donor) & ...
        pairMap.transferPairs.receiver_bed == string(receiver), :);
    assert(height(pair) == 1);
    selection = selectYangFourBedPairStates(container, pair);
end

function states = makePhysicalStates(params)
    y = [0.7697228145; 0.2302771855];
    states = struct();
    states.state_A = makePhysicalPayload(params, 1.10, y, 0.02);
    states.state_B = makePhysicalPayload(params, 1.00, y, 0.03);
    states.state_C = makePhysicalPayload(params, 0.75, y, 0.04);
    states.state_D = makePhysicalPayload(params, 0.55, y, 0.05);
end

function payload = makePhysicalPayload(params, pressureRatio, y, adsValue)
    cstr = [pressureRatio .* y(:).', adsValue .* ones(1, params.nComs), 1, 1].';
    vector = repmat(cstr, params.nVols, 1);
    payload = struct();
    payload.payloadType = "yang_physical_adsorber_state_v1";
    payload.stateVector = vector;
    payload.physicalStateVector = vector;
    payload.metadata = struct("source", "FI8 valve scaling test");
end

function config = makePpPuConfig()
    config = struct();
    config.version = "FI4-Yang2009-PP-PU-adapter-config-v1";
    config.directTransferFamily = "PP_PU";
    config.durationDimless = 0.01;
    config.durationSeconds = [];
    config.Cv_PP_PU_internal = 2.0e-6;
    config.Cv_PU_waste = 3.0e-6;
    config.receiverWastePressureRatio = 0.20;
    config.receiverWastePressureClass = "P4";
    config.allowReverseInternalFlow = false;
    config.allowReverseWasteFlow = false;
    config.componentNames = ["H2"; "CO2"];
    config.conservationAbsTol = 1e-8;
    config.conservationRelTol = 1e-6;
    config.debugKeepStateHistory = false;
    config.validationOnly = false;
end

function config = makeAdppBfConfig()
    config = struct();
    config.version = "FI5-Yang2009-ADPP-BF-adapter-config-v1";
    config.directTransferFamily = "ADPP_BF";
    config.durationDimless = 0.01;
    config.durationSeconds = [];
    config.Cv_ADPP_feed = 2.0e-6;
    config.Cv_ADPP_product = 3.0e-6;
    config.Cv_ADPP_BF_internal = 4.0e-6;
    config.feedPressureRatio = 1.20;
    config.externalProductPressureRatio = 0.80;
    config.allowReverseFeedFlow = false;
    config.allowReverseProductFlow = false;
    config.allowReverseInternalFlow = false;
    config.componentNames = ["H2"; "CO2"];
    config.conservationAbsTol = 1e-8;
    config.conservationRelTol = 1e-6;
    config.debugKeepStateHistory = false;
    config.validationOnly = false;
end

function assertEquivalentPpPuFlow(params, ppCase, dimConfig, scaledConfig)
    row = makeTwoBedNativeRow(params, ppCase);
    stTime = [0; dimConfig.durationDimless];
    stStates = [row; row];
    dimFlow = integrateYangPpPuAdapterFlows(params, stTime, stStates, dimConfig);
    scaledFlow = integrateYangPpPuAdapterFlows(params, stTime, stStates, scaledConfig);
    assertVectorsClose(dimFlow.native.internalTransferOutByComponent, ...
        scaledFlow.native.internalTransferOutByComponent);
    assertVectorsClose(dimFlow.native.externalWasteByComponent, ...
        scaledFlow.native.externalWasteByComponent);
end

function assertEquivalentAdppBfFlow(params, adppCase, dimConfig, scaledConfig)
    row = makeTwoBedNativeRow(params, adppCase);
    stTime = [0; dimConfig.durationDimless];
    stStates = [row; row];
    dimFlow = integrateYangAdppBfAdapterFlows(params, stTime, stStates, dimConfig);
    scaledFlow = integrateYangAdppBfAdapterFlows(params, stTime, stStates, scaledConfig);
    assertVectorsClose(dimFlow.native.externalFeedByComponent, ...
        scaledFlow.native.externalFeedByComponent);
    assertVectorsClose(dimFlow.native.externalProductByComponent, ...
        scaledFlow.native.externalProductByComponent);
    assertVectorsClose(dimFlow.native.internalTransferOutByComponent, ...
        scaledFlow.native.internalTransferOutByComponent);
    assert(isfinite(dimFlow.effectiveSplit.total) || isnan(dimFlow.effectiveSplit.total));
end

function row = makeTwoBedNativeRow(params, tempCase)
    donor = [
        tempCase.localStates{1}.stateVector(:)
        zeros(2*params.nComs, 1)
    ];
    receiver = [
        tempCase.localStates{2}.stateVector(:)
        zeros(2*params.nComs, 1)
    ];
    row = [donor; receiver].';
end

function assertVectorsClose(actual, expected)
    tol = 10 * eps(max(1, max(abs(expected(:)))));
    assert(all(abs(actual(:) - expected(:)) <= tol));
end

function assertErrorIdentifier(func, expectedIdentifier)
    try
        func();
    catch ME
        assert(strcmp(ME.identifier, expectedIdentifier), ...
            'Expected %s but received %s: %s', ...
            expectedIdentifier, ME.identifier, ME.message);
        return;
    end
    error('ExpectedErrorNotThrown:%s', expectedIdentifier);
end
