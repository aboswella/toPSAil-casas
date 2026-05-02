function testYangAdppBfAdapterSplitConservation()
%TESTYANGADPPBFADAPTERSPLITCONSERVATION FI-5 AD&PP->BF split/conservation gate.
%
% Tier: Unit/sanity. Runtime class: < 30 s when runnable. Default smoke: no
% until the H2/CO2 AC template has full runtime initialization.
% Failure modes caught: AD&PP product/BF branch collapse, BF internal gas
% counted as external product, internal mismatch, sign errors, and silent
% solver-field fabrication.

    [params, adppCase] = buildAdapterTestContext();
    config = makeAdppBfConfig(false);

    dynamicWasBlocked = false;
    try
        [terminalLocalStates, adapterReport] = runYangAdppBfAdapter(adppCase, params, config);
    catch ME
        if strcmp(ME.identifier, 'FI5:TemplateParamsNotRunnable')
            assert(contains(string(ME.message), "initStates") || ...
                contains(string(ME.message), "funcRat") || ...
                contains(string(ME.message), "cstrHt") || ...
                contains(string(ME.message), "pressure"));
            fprintf('FI-5 AD&PP->BF dynamic conservation path blocked explicitly: %s\n', ME.message);
            dynamicWasBlocked = true;
        else
            rethrow(ME);
        end
    end

    if ~dynamicWasBlocked
        assert(numel(terminalLocalStates) == 2);
        assert(numel(terminalLocalStates{1}.stateVector) == params.nColSt);
        assert(numel(terminalLocalStates{2}.stateVector) == params.nColSt);
        assert(adapterReport.directTransferFamily == "ADPP_BF");
        assert(all(adapterReport.flows.externalFeedByComponent >= 0));
        assert(all(adapterReport.flows.externalProductByComponent >= 0));
        assert(all(adapterReport.flows.internalTransferOutByComponent >= 0));
        assert(all(adapterReport.flows.internalTransferInByComponent >= 0));
        assert(all(adapterReport.flows.externalWasteByComponent == 0));
        assert(norm(adapterReport.flows.internalTransferOutByComponent - ...
            adapterReport.flows.internalTransferInByComponent, inf) <= ...
            adapterReport.conservationAbsTol + adapterReport.conservationRelTol);
        assert(adapterReport.conservation.pass);
        assert(~adapterReport.sanity.hasNaN);
        assert(~adapterReport.sanity.hasNegativePressure);
        assert(~adapterReport.sanity.hasInvalidMoleFraction);
        assert(adapterReport.flowReport.flowSigns.donorFeedEnd.negativeCount == 0);
        assert(adapterReport.flowReport.flowSigns.donorProductEnd.negativeCount == 0);
        assert(adapterReport.flowReport.flowSigns.receiverProductEnd.positiveCount == 0);
        assert(adapterReport.flowReport.flowSigns.receiverFeedEnd.positiveCount == 0);
        assert(adapterReport.effectiveSplit.primaryControl == ...
            "fixed_internal_split_fraction");
        assert(abs(adapterReport.effectiveSplit.requestedInternalSplitFraction - 1/3) < eps);
    end

    assertSyntheticSplitAccounting(params, adppCase, config);

    fprintf('FI-5 AD&PP->BF adapter split/conservation checks passed for structural and synthetic paths.\n');
end

function [params, adppCase] = buildAdapterTestContext()
    params = buildYangH2Co2AcTemplateParams("NVols", 2, "NCols", 2, "NSteps", 1);
    manifest = getYangFourBedScheduleManifest();
    pairMap = getYangDirectTransferPairMap(manifest);
    container = makeYangFourBedStateContainer(makePhysicalStates(params), ...
        'Manifest', manifest, ...
        'PairMap', pairMap, ...
        'InitializationPolicy', "FI5_adapter_split_test_physical_states", ...
        'SourceNote', "FI-5 ADPP_BF adapter split states");

    adppCase = makeYangTemporaryPairedCase( ...
        selectPair(container, pairMap, "ADPP_BF", "A", "B"), ...
        'DurationDimless', 0.01, ...
        'RunnerMode', "wrapper_adapter", ...
        'CaseNote', "FI-5 ADPP_BF split/conservation");
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
    states.state_B = makePhysicalPayload(params, 0.55, y, 0.03);
    states.state_C = makePhysicalPayload(params, 0.75, y, 0.04);
    states.state_D = makePhysicalPayload(params, 0.65, y, 0.05);
end

function payload = makePhysicalPayload(params, pressureRatio, y, adsValue)
    cstr = [pressureRatio .* y(:).', adsValue .* ones(1, params.nComs), 1, 1].';
    vector = repmat(cstr, params.nVols, 1);
    payload = struct();
    payload.payloadType = "yang_physical_adsorber_state_v1";
    payload.stateVector = vector;
    payload.physicalStateVector = vector;
    payload.metadata = struct("source", "FI5 adapter split test");
end

function config = makeAdppBfConfig(validationOnly)
    config = struct();
    config.version = "FI5-Yang2009-ADPP-BF-adapter-config-v1";
    config.directTransferFamily = "ADPP_BF";
    config.durationDimless = 0.01;
    config.durationSeconds = [];
    config.Cv_ADPP_feed = 0.05;
    config.Cv_ADPP_product = 0.02;
    config.Cv_ADPP_BF_internal = 0.03;
    config.ADPP_BF_internalSplitFraction = 1/3;
    config.adapterCvBasis = "scaled_dimensionless";
    config.feedPressureRatio = 1.20;
    config.externalProductPressureRatio = 0.80;
    config.allowReverseFeedFlow = false;
    config.allowReverseProductFlow = false;
    config.allowReverseInternalFlow = false;
    config.componentNames = ["H2"; "CO2"];
    config.conservationAbsTol = 1e-8;
    config.conservationRelTol = 1e-6;
    config.debugKeepStateHistory = false;
    config.validationOnly = validationOnly;
    config.cycleIndex = NaN;
    config.slotIndex = NaN;
end

function assertSyntheticSplitAccounting(params, adppCase, config)
    row = makeTwoBedNativeRow(params, adppCase);
    stTime = [0; config.durationDimless];
    stStates = [row; row];
    flowReport = integrateYangAdppBfAdapterFlows(params, stTime, stStates, config);

    assert(all(flowReport.native.externalFeedByComponent >= 0));
    assert(all(flowReport.native.externalProductByComponent >= 0));
    assert(all(flowReport.native.internalTransferOutByComponent >= 0));
    assert(all(flowReport.native.internalTransferInByComponent >= 0));
    assert(all(flowReport.native.externalWasteByComponent == 0));
    assert(norm(flowReport.native.internalTransferOutByComponent - ...
        flowReport.native.internalTransferInByComponent, inf) <= eps);
    assert(flowReport.native.externalProductByComponent(1) > 0);
    assert(flowReport.native.internalTransferOutByComponent(1) > 0);
    assert(abs(flowReport.effectiveSplit.H2 - 1/3) < 1e-12);
    assert(abs(flowReport.effectiveSplit.total - 1/3) < 1e-12);
    assert(flowReport.effectiveSplit.primaryControl == ...
        "fixed_internal_split_fraction");
    assert(abs(flowReport.effectiveSplit.requestedInternalSplitFraction - 1/3) < eps);
    assert(flowReport.flowSigns.donorFeedEnd.negativeCount == 0);
    assert(flowReport.flowSigns.donorProductEnd.negativeCount == 0);
    assert(flowReport.flowSigns.receiverProductEnd.positiveCount == 0);
    assert(flowReport.flowSigns.receiverFeedEnd.positiveCount == 0);
end

function row = makeTwoBedNativeRow(params, adppCase)
    donor = [
        adppCase.localStates{1}.stateVector(:)
        zeros(2*params.nComs, 1)
    ];
    receiver = [
        adppCase.localStates{2}.stateVector(:)
        zeros(2*params.nComs, 1)
    ];
    row = [donor; receiver].';
end
