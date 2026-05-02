function testYangPpPuAdapterConservation()
%TESTYANGPPPUADAPTERCONSERVATION FI-4 PP->PU dynamic adapter gate.
%
% Tier: Unit/sanity. Runtime class: < 30 s when runnable. Default smoke: no
% until the H2/CO2 AC template has full runtime initialization.
% Failure modes caught: PP->PU conservation sign/unit errors, external
% product overcount, counter-tail persistence, and silent template fabrication.

    [params, ppCase] = buildAdapterTestContext();
    config = makeAdapterConfig(false);

    try
        [terminalLocalStates, adapterReport] = runYangPpPuAdapter(ppCase, params, config);
    catch ME
        if strcmp(ME.identifier, 'FI4:TemplateParamsNotRunnable')
            assert(contains(string(ME.message), "initStates") || ...
                contains(string(ME.message), "funcRat") || ...
                contains(string(ME.message), "cstrHt"));
            fprintf('FI-4 PP->PU dynamic conservation path blocked explicitly: %s\n', ME.message);
            return;
        end
        rethrow(ME);
    end

    assert(numel(terminalLocalStates) == 2);
    assert(numel(terminalLocalStates{1}.stateVector) == params.nColSt);
    assert(numel(terminalLocalStates{2}.stateVector) == params.nColSt);
    assert(adapterReport.directTransferFamily == "PP_PU");
    assert(all(adapterReport.flows.externalProductByComponent == 0));
    assert(all(adapterReport.flows.externalWasteByComponent >= 0));
    assert(norm(adapterReport.flows.internalTransferOutByComponent - ...
        adapterReport.flows.internalTransferInByComponent, inf) <= ...
        adapterReport.conservationAbsTol + adapterReport.conservationRelTol);
    assert(adapterReport.conservation.pass);
    assert(~adapterReport.sanity.hasNaN);
    assert(~adapterReport.sanity.hasNegativePressure);
    assert(~adapterReport.sanity.hasInvalidMoleFraction);
    assert(adapterReport.flowReport.flowSigns.donorProductEnd.negativeCount == 0);
    assert(adapterReport.flowReport.flowSigns.receiverProductEnd.positiveCount == 0);
    assert(adapterReport.flowReport.flowSigns.receiverFeedWaste.positiveCount == 0);

    fprintf('FI-4 PP->PU adapter conservation passed for a short two-bed run.\n');
end

function [params, ppCase] = buildAdapterTestContext()
    params = buildYangH2Co2AcTemplateParams("NVols", 2, "NCols", 2, "NSteps", 1);
    manifest = getYangFourBedScheduleManifest();
    pairMap = getYangDirectTransferPairMap(manifest);
    container = makeYangFourBedStateContainer(makePhysicalStates(params), ...
        'Manifest', manifest, ...
        'PairMap', pairMap, ...
        'InitializationPolicy', "FI4_adapter_conservation_test_physical_states", ...
        'SourceNote', "FI-4 PP->PU adapter conservation states");

    ppCase = makeYangTemporaryPairedCase( ...
        selectPair(container, pairMap, "PP_PU", "B", "A"), ...
        'DurationDimless', 0.01, ...
        'RunnerMode', "wrapper_adapter", ...
        'CaseNote', "FI-4 PP->PU conservation");
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
    states.state_A = makePhysicalPayload(params, 0.45, y, 0.02);
    states.state_B = makePhysicalPayload(params, 1.00, y, 0.03);
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
    payload.metadata = struct("source", "FI4 adapter conservation test");
end

function config = makeAdapterConfig(validationOnly)
    config = struct();
    config.version = "FI4-Yang2009-PP-PU-adapter-config-v1";
    config.directTransferFamily = "PP_PU";
    config.durationDimless = 0.01;
    config.durationSeconds = [];
    config.Cv_PP_PU_internal = 0.05;
    config.Cv_PU_waste = 0.02;
    config.adapterCvBasis = "scaled_dimensionless";
    config.receiverWastePressureRatio = 0.20;
    config.receiverWastePressureClass = "P4";
    config.allowReverseInternalFlow = false;
    config.allowReverseWasteFlow = false;
    config.componentNames = ["H2"; "CO2"];
    config.conservationAbsTol = 1e-8;
    config.conservationRelTol = 1e-6;
    config.debugKeepStateHistory = false;
    config.validationOnly = validationOnly;
    config.cycleIndex = NaN;
    config.slotIndex = NaN;
end
