function testYangValveCoefficientScaling()
%TESTYANGVALVECOEFFICIENTSCALING FI-8 minimal adapter Cv basis.
%
% Tier: Unit/adapter smoke. Runtime class: < 10 s. Default smoke: yes.
% Failure modes caught: dimensional adapter-Cv scaling, independent legacy
% adapter Cv aliases, and drift from the minimal custom-adapter controls.

    testMinimalControls();
    testLegacyAdapterAliasesCollapse();
    testPpPuRawDirectBasis();
    testAdppBfRawDirectBasis();

    fprintf('FI-8 Yang valve coefficient scaling passed: custom adapters use raw Cv_directTransfer.\n');
end

function testMinimalControls()
    controls = normalizeYangFourBedControls(struct(), struct());
    assert(controls.cycleTimeSec == 240);
    assert(controls.feedVelocityCmSec == 5.2);
    assert(controls.Cv_directTransfer == 1.0e-6);
    assert(controls.ADPP_BF_internalSplitFraction == 1/3);
    assert(isfield(controls, 'ADPP_BF_externalProductPressureRatio'));
    assert(isempty(controls.ADPP_BF_externalProductPressureRatio));
    assert(controls.Cv_ADPP_feed == controls.Cv_directTransfer);
    assert(controls.Cv_ADPP_product == controls.Cv_directTransfer);
    assert(controls.Cv_ADPP_BF_internal == controls.Cv_directTransfer);
    assert(controls.adapterCoefficientBasis == "scaled_dimensionless_raw_direct");
    assert(~isfield(controls, 'Cv_PP_PU_internal'));
    assert(~isfield(controls, 'Cv_PU_waste'));
    assert(~isfield(controls, 'adapterCvBasis'));
    assert(~isfield(controls, 'valveCoefficientBasis'));

    override = normalizeYangFourBedControls(struct( ...
        "Cv_directTransfer", 9.0e-6, ...
        "adapterCvBasis", "dimensional_kmol_per_bar_s", ...
        "Cv_EQI", 4.0e-6), struct());
    assert(override.Cv_directTransfer == 9.0e-6);
    assert(override.adapterCoefficientBasis == "scaled_dimensionless_raw_direct");
    assert(any(override.Cv_directTransferAliasReport.ignoredControlBasisFields == "adapterCvBasis"));
    assert(any(override.Cv_directTransferAliasReport.ignoredNativeCvFields == "Cv_EQI"));

    productPressureOverride = normalizeYangFourBedControls(struct( ...
        "ADPP_BF_externalProductPressureRatio", 0.75), struct());
    assert(productPressureOverride.ADPP_BF_externalProductPressureRatio == 0.75);
    assertErrorIdentifier(@() normalizeYangFourBedControls(struct( ...
        "ADPP_BF_externalProductPressureRatio", -0.1), struct()), ...
        'FI6:InvalidControls');
end

function testLegacyAdapterAliasesCollapse()
    aliased = normalizeYangFourBedControls(struct( ...
        "Cv_PP_PU_internal", 2.0e-6, ...
        "Cv_PU_waste", 4.0e-6, ...
        "Cv_ADPP_feed", 2.0e-6, ...
        "Cv_ADPP_product", 3.0e-6, ...
        "Cv_ADPP_BF_internal", 4.0e-6), struct());
    assert(aliased.Cv_directTransfer == 2.0e-6);
    assert(aliased.Cv_ADPP_feed == 2.0e-6);
    assert(aliased.Cv_ADPP_product == 3.0e-6);
    assert(aliased.Cv_ADPP_BF_internal == 4.0e-6);
    assert(numel(aliased.Cv_directTransferAliasReport.usedFallbackAliases) == 2);

    assertErrorIdentifier(@() normalizeYangFourBedControls(struct( ...
        "Cv_PP_PU_internal", 2.0e-6, ...
        "Cv_PU_waste", 6.0e-6), struct()), ...
        'FI6:ConflictingLegacyCvAliases');
end

function testPpPuRawDirectBasis()
    [params, ppCase] = buildAdapterContext("PP_PU");
    params.valScaleFac = 123.0;

    config = makePpPuConfig();
    [normalized, ~] = validateYangDirectCouplingAdapterInputs(ppCase, params, config);
    assert(normalized.Cv_directTransfer == config.Cv_directTransfer);
    assert(normalized.rawCv.Cv_directTransfer == config.Cv_directTransfer);
    assert(normalized.effectiveCv.Cv_directTransfer == config.Cv_directTransfer);
    assert(normalized.valveCoefficientBasis == "scaled_dimensionless_raw_direct");
    assert(~normalized.adapterCvScalingApplied);
    assert(isnan(normalized.valScaleFac));
    assert(normalized.derivedConductance.PU_waste == 2.0 * config.Cv_directTransfer);

    [~, report] = runYangDirectCouplingAdapter(ppCase, params, ...
        setfield(config, 'validationOnly', true)); %#ok<SFLD>
    assert(report.Cv_directTransfer == config.Cv_directTransfer);
    assert(report.effectiveCv.Cv_directTransfer == config.Cv_directTransfer);
    assert(report.valveCoefficientBasis == "scaled_dimensionless_raw_direct");
    assert(~report.adapterCvScalingApplied);
end

function testAdppBfRawDirectBasis()
    [params, adppCase] = buildAdapterContext("ADPP_BF");
    params.valScaleFac = 123.0;

    config = makeAdppBfConfig();
    [normalized, ~] = validateYangAdppBfAdapterInputs(adppCase, params, config);
    assert(normalized.Cv_directTransfer == config.Cv_directTransfer);
    assert(normalized.Cv_ADPP_feed == config.Cv_ADPP_feed);
    assert(normalized.Cv_ADPP_product == config.Cv_ADPP_product);
    assert(normalized.Cv_ADPP_BF_internal == config.Cv_ADPP_BF_internal);
    assert(normalized.rawCv.Cv_directTransfer == config.Cv_directTransfer);
    assert(normalized.rawCv.Cv_ADPP_feed == config.Cv_ADPP_feed);
    assert(normalized.rawCv.Cv_ADPP_product == config.Cv_ADPP_product);
    assert(normalized.rawCv.Cv_ADPP_BF_internal == config.Cv_ADPP_BF_internal);
    assert(normalized.effectiveCv.Cv_directTransfer == config.Cv_directTransfer);
    assert(normalized.valveCoefficientBasis == "scaled_dimensionless_raw_direct");
    assert(~normalized.adapterCvScalingApplied);
    assert(isnan(normalized.valScaleFac));
    assert(normalized.derivedConductance.ADPP_feed == config.Cv_ADPP_feed);
    assert(normalized.derivedConductance.ADPP_product == config.Cv_ADPP_product);
    assert(normalized.derivedConductance.ADPP_BF_internal == config.Cv_ADPP_BF_internal);

    [~, report] = runYangDirectCouplingAdapter(adppCase, params, ...
        setfield(config, 'validationOnly', true)); %#ok<SFLD>
    assert(report.Cv_directTransfer == config.Cv_directTransfer);
    assert(report.Cv_ADPP_feed == config.Cv_ADPP_feed);
    assert(report.Cv_ADPP_product == config.Cv_ADPP_product);
    assert(report.Cv_ADPP_BF_internal == config.Cv_ADPP_BF_internal);
    assert(report.effectiveCv.Cv_directTransfer == config.Cv_directTransfer);
    assert(report.valveCoefficientBasis == "scaled_dimensionless_raw_direct");
    assert(~report.adapterCvScalingApplied);
    assert(report.effectiveSplit.primaryControl == "pressure_driven_independent_branches");
end

function [params, tempCase] = buildAdapterContext(family)
    params = buildYangH2Co2AcTemplateParams("NVols", 2, "NCols", 2, "NSteps", 1);
    manifest = getYangFourBedScheduleManifest();
    pairMap = getYangDirectTransferPairMap(manifest);
    container = makeYangFourBedStateContainer(makePhysicalStates(params), ...
        'Manifest', manifest, ...
        'PairMap', pairMap, ...
        'InitializationPolicy', "FI8_minimal_valve_basis_physical_states", ...
        'SourceNote', "FI-8 minimal valve basis tests");

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
        'CaseNote', "FI-8 minimal valve basis adapter context");
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
    payload.metadata = struct("source", "FI8 minimal valve basis test");
end

function config = makePpPuConfig()
    config = struct();
    config.version = "FI4-Yang2009-PP-PU-adapter-config-v1";
    config.directTransferFamily = "PP_PU";
    config.durationDimless = 0.01;
    config.durationSeconds = [];
    config.Cv_directTransfer = 2.0e-6;
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
    config.Cv_directTransfer = 2.0e-6;
    config.Cv_ADPP_feed = 2.0e-6;
    config.Cv_ADPP_product = 3.0e-6;
    config.Cv_ADPP_BF_internal = 4.0e-6;
    config.ADPP_BF_internalSplitFraction = 1/3;
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
