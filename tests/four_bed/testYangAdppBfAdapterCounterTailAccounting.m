function testYangAdppBfAdapterCounterTailAccounting()
%TESTYANGADPPBFADAPTERCOUNTERTAILACCOUNTING FI-8 AD&PP->BF counter gate.
%
% Tier: Adapter/unit. Final item: FI-8. Runtime class: < 60 s. Default
% smoke: no. Failure mode caught: AD&PP->BF split/conservation acceptance
% depends on sampled trapz reconstruction or loses product-pressure control.

    defaultReport = runOne([]);
    ratio075Report = runOne(0.75);
    ratio050Report = runOne(0.50);

    assertCounterReport(defaultReport, []);
    assertCounterReport(ratio075Report, 0.75);
    assertCounterReport(ratio050Report, 0.50);

    product075 = ratio075Report.flows.externalProductByComponent(1);
    product050 = ratio050Report.flows.externalProductByComponent(1);
    assert(abs(product075 - product050) > ratio050Report.conservationAbsTol);

    fprintf('FI-8 AD&PP->BF counter-tail accounting passed with product-pressure overrides.\n');
end

function adapterReport = runOne(externalProductPressureRatio)
    [params, adppCase] = buildAdapterTestContext();
    config = struct( ...
        'validationOnly', false, ...
        'durationSeconds', 0.1, ...
        'Cv_directTransfer', 1e-2, ...
        'Cv_ADPP_feed', 1e-2, ...
        'Cv_ADPP_product', 1e-2, ...
        'Cv_ADPP_BF_internal', 1e-2, ...
        'feedPressureRatio', 1.20, ...
        'debugKeepStateHistory', true);
    if ~isempty(externalProductPressureRatio)
        config.externalProductPressureRatio = externalProductPressureRatio;
    end
    [~, adapterReport] = runYangAdppBfAdapter(adppCase, params, config);
end

function assertCounterReport(adapterReport, expectedExternalProductPressureRatio)
    assert(adapterReport.flowReport.primaryBasis == "native_counter_tail_delta");
    assert(adapterReport.flowReport.native.unitBasis == "native_counter_tail_delta");
    assert(adapterReport.flowReport.moles.unitBasis == ...
        "physical_moles_from_native_counter_tail_delta_using_params.nScaleFac");
    assert(adapterReport.conservation.pass);
    assert(all(adapterReport.flows.externalFeedByComponent >= 0));
    assert(all(adapterReport.flows.externalProductByComponent >= 0));
    assert(all(adapterReport.flows.internalTransferOutByComponent >= 0));
    assert(all(adapterReport.flows.internalTransferInByComponent >= 0));
    assert(all(adapterReport.flows.externalWasteByComponent == 0));

    mismatch = adapterReport.flows.internalTransferOutByComponent - ...
        adapterReport.flows.internalTransferInByComponent;
    scale = max(1, max(abs([adapterReport.flows.internalTransferOutByComponent; ...
        adapterReport.flows.internalTransferInByComponent])));
    tol = adapterReport.conservationAbsTol + adapterReport.conservationRelTol * scale;
    assert(norm(mismatch, inf) <= tol);
    assert(isfield(adapterReport.flowReport, 'sampledReconstruction'));
    assert(isfield(adapterReport.flowReport, 'sampledMinusCounter'));

    if ~isempty(expectedExternalProductPressureRatio)
        assert(adapterReport.externalProductPressureRatio == ...
            expectedExternalProductPressureRatio);
    end
end

function [params, adppCase] = buildAdapterTestContext()
    params = buildYangH2Co2AcTemplateParams('NVols', 2, 'NCols', 2, ...
        'NSteps', 1, 'NTimePoints', 2, ...
        'FinalizeForRuntime', true);
    manifest = getYangFourBedScheduleManifest();
    pairMap = getYangDirectTransferPairMap(manifest);
    container = makeCounterTestContainer(params, manifest, pairMap);
    adppCase = makeYangTemporaryPairedCase( ...
        selectPair(container, pairMap, "ADPP_BF", "A", "B"), ...
        'DurationSeconds', 0.1, ...
        'RunnerMode', "wrapper_adapter", ...
        'CaseNote', "FI-8 ADPP_BF counter-tail accounting");
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
    states.state_A = makePhysicalPayload(params, 1.10, y, 0.02);
    states.state_B = makePhysicalPayload(params, 0.55, y, 0.03);
    states.state_C = makePhysicalPayload(params, 0.75, y, 0.04);
    states.state_D = makePhysicalPayload(params, 0.65, y, 0.05);
    container = makeYangFourBedStateContainer(states, ...
        'Manifest', manifest, ...
        'PairMap', pairMap, ...
        'InitializationPolicy', "FI-8 ADPP_BF counter-tail accounting", ...
        'SourceNote', "synthetic physical states");
end

function payload = makePhysicalPayload(params, pressureRatio, y, adsValue)
    cstr = [pressureRatio .* y(:).', adsValue .* ones(1, params.nComs), 1, 1].';
    payload = extractYangPhysicalBedState(params, repmat(cstr, params.nVols, 1));
end
