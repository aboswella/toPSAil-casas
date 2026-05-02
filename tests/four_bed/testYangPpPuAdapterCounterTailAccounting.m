function testYangPpPuAdapterCounterTailAccounting()
%TESTYANGPPPUADAPTERCOUNTERTAILACCOUNTING FI-8 PP->PU counter ledger gate.
%
% Tier: Adapter/unit. Final item: FI-8. Runtime class: < 45 s. Default
% smoke: no. Failure mode caught: PP->PU accepted conservation depends on
% coarse sampled-history trapz reconstruction instead of native counters.

    for nTimePoints = [2, 21]
        [params, ppCase] = buildAdapterTestContext(nTimePoints);
        [~, adapterReport] = runYangPpPuAdapter(ppCase, params, struct( ...
            'validationOnly', false, ...
            'durationSeconds', 0.1, ...
            'Cv_directTransfer', 1e-2, ...
            'debugKeepStateHistory', true));

        assert(adapterReport.flowReport.primaryBasis == "native_counter_tail_delta");
        assert(adapterReport.flowReport.native.unitBasis == "native_counter_tail_delta");
        assert(adapterReport.flowReport.moles.unitBasis == ...
            "physical_moles_from_native_counter_tail_delta_using_params.nScaleFac");
        assert(adapterReport.conservation.pass);
        mismatch = adapterReport.flows.internalTransferOutByComponent - ...
            adapterReport.flows.internalTransferInByComponent;
        tol = adapterReport.conservationAbsTol + ...
            adapterReport.conservationRelTol * max(1, ...
            max(abs([adapterReport.flows.internalTransferOutByComponent; ...
            adapterReport.flows.internalTransferInByComponent])));
        assert(norm(mismatch, inf) <= tol);
        assert(all(adapterReport.flows.externalProductByComponent == 0));
        assert(isfield(adapterReport.flowReport, 'sampledReconstruction'));
        assert(isfield(adapterReport.flowReport, 'sampledMinusCounter'));
        sampledMinusCounter = adapterReport.flowReport.sampledMinusCounter.native;
        sampledMismatch = sampledMinusCounter.internalTransferOutByComponent;
        assert(all(isfinite(sampledMismatch)));
    end

    fprintf('FI-8 PP->PU counter-tail accounting passed at coarse and denser output grids.\n');
end

function [params, ppCase] = buildAdapterTestContext(nTimePoints)
    params = buildYangH2Co2AcTemplateParams('NVols', 2, 'NCols', 2, ...
        'NSteps', 1, 'NTimePoints', nTimePoints, ...
        'FinalizeForRuntime', true);
    manifest = getYangFourBedScheduleManifest();
    pairMap = getYangDirectTransferPairMap(manifest);
    container = makeCounterTestContainer(params, manifest, pairMap);
    ppCase = makeYangTemporaryPairedCase( ...
        selectPair(container, pairMap, "PP_PU", "B", "A"), ...
        'DurationSeconds', 0.1, ...
        'RunnerMode', "wrapper_adapter", ...
        'CaseNote', "FI-8 PP->PU counter-tail accounting");
end

function selection = selectPair(container, pairMap, family, donor, receiver)
    pair = pairMap.transferPairs( ...
        pairMap.transferPairs.direct_transfer_family == string(family) & ...
        pairMap.transferPairs.donor_bed == string(donor) & ...
        pairMap.transferPairs.receiver_bed == string(receiver), :);
    assert(height(pair) == 1);
    selection = selectYangFourBedPairStates(container, pair);
end

function container = makeCounterTestContainer(params, manifest, pairMap)
    y = [0.7697228145; 0.2302771855];
    states = struct();
    states.state_A = makePhysicalPayload(params, 0.45, y, 0.02);
    states.state_B = makePhysicalPayload(params, 1.00, y, 0.03);
    states.state_C = makePhysicalPayload(params, 0.75, y, 0.04);
    states.state_D = makePhysicalPayload(params, 0.65, y, 0.05);
    container = makeYangFourBedStateContainer(states, ...
        'Manifest', manifest, ...
        'PairMap', pairMap, ...
        'InitializationPolicy', "FI-8 PP->PU counter-tail accounting", ...
        'SourceNote', "synthetic physical states");
end

function payload = makePhysicalPayload(params, pressureRatio, y, adsValue)
    cstr = [pressureRatio .* y(:).', adsValue .* ones(1, params.nComs), 1, 1].';
    payload = extractYangPhysicalBedState(params, repmat(cstr, params.nVols, 1));
end
