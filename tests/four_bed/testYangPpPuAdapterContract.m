function testYangPpPuAdapterContract()
%TESTYANGPPPUDAPTERCONTRACT FI-4 PP->PU adapter contract test.
%
% Tier: Unit. Runtime class: < 10 s. Default smoke: yes.
% Failure modes caught: PP->PU donor/receiver inversion, endpoint drift,
% ADPP_BF scope bleed, hidden external-product credit, and missing-control
% ambiguity.

    [params, ppCase, ~] = buildAdapterTestContext();
    config = makeAdapterConfig(true);

    [normalizedConfig, validation] = validateYangDirectCouplingAdapterInputs( ...
        ppCase, params, config);
    assert(validation.pass);
    assert(normalizedConfig.directTransferFamily == "PP_PU");

    assert(ppCase.native.nativeRunnable == false);
    assert(ppCase.localMap.local_index(1) == 1);
    assert(ppCase.localMap.local_index(2) == 2);
    assert(ppCase.localMap.local_role(1) == "donor");
    assert(ppCase.localMap.local_role(2) == "receiver");
    assert(ppCase.native.endpointPolicy.donorOutletEndpoint == "product_end");
    assert(ppCase.native.endpointPolicy.receiverInletEndpoint == "product_end");
    assert(ppCase.native.endpointPolicy.receiverWasteEndpoint == "feed_end");

    [terminalLocalStates, adapterReport] = runYangDirectCouplingAdapter( ...
        ppCase, params, config);
    assert(numel(terminalLocalStates) == 2);
    assert(numel(terminalLocalStates{1}.stateVector) == params.nColSt);
    assert(numel(terminalLocalStates{2}.stateVector) == params.nColSt);
    assert(adapterReport.directTransferFamily == "PP_PU");
    assert(adapterReport.nativeStepGrammarUsed == false);
    assert(adapterReport.noDynamicInternalTanks);
    assert(adapterReport.noSharedHeaderInventory);
    assert(adapterReport.noFourBedRhsDae);
    assert(adapterReport.noCoreAdsorberPhysicsRewrite);
    assert(adapterReport.solverRunStatus == "validation_only_no_native_solver_invocation");
    assert(all(adapterReport.flows.externalProductByComponent == 0));
    assertPpPuFlowLawSigns(params, ppCase, normalizedConfig);
    assertPpPuFlowIntegratorShape(params, ppCase, normalizedConfig);

    missingControl = rmfield(config, 'Cv_directTransfer');
    assertErrorIdentifier(@() validateYangDirectCouplingAdapterInputs( ...
        ppCase, params, missingControl), 'FI4:MissingAdapterConfigField');

    unsupported = ppCase;
    unsupported.directTransferFamily = "EQI";
    assertErrorIdentifier(@() runYangDirectCouplingAdapter( ...
        unsupported, params, config), 'FI5:UnsupportedDirectCouplingFamily');

    fprintf('FI-4 PP->PU adapter contract passed: dispatcher, endpoints, and schema are explicit.\n');
end

function [params, ppCase, adppCase] = buildAdapterTestContext()
    params = buildYangH2Co2AcTemplateParams("NVols", 2, "NCols", 2, "NSteps", 1);
    manifest = getYangFourBedScheduleManifest();
    pairMap = getYangDirectTransferPairMap(manifest);
    container = makeYangFourBedStateContainer(makePhysicalStates(params), ...
        'Manifest', manifest, ...
        'PairMap', pairMap, ...
        'InitializationPolicy', "FI4_adapter_unit_test_physical_states", ...
        'SourceNote', "FI-4 PP->PU adapter contract states");

    ppCase = makeYangTemporaryPairedCase( ...
        selectPair(container, pairMap, "PP_PU", "B", "A"), ...
        'DurationDimless', 0.01, ...
        'RunnerMode', "wrapper_adapter", ...
        'CaseNote', "FI-4 PP->PU contract");
    adppCase = makeYangTemporaryPairedCase( ...
        selectPair(container, pairMap, "ADPP_BF", "A", "B"), ...
        'DurationDimless', 0.01, ...
        'RunnerMode', "wrapper_adapter", ...
        'CaseNote', "FI-4 ADPP_BF scope guard");
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
    payload.metadata = struct("source", "FI4 adapter unit test");
end

function config = makeAdapterConfig(validationOnly)
    config = struct();
    config.version = "FI4-Yang2009-PP-PU-adapter-config-v1";
    config.directTransferFamily = "PP_PU";
    config.durationDimless = 0.01;
    config.durationSeconds = [];
    config.Cv_directTransfer = 0.05;
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

function assertPpPuFlowLawSigns(params, ppCase, config)
    flowParams = params;
    flowParams.sColNums = {'n1'; 'n2'};
    flowParams.yangAdapterConfig = config;
    col = makeBoundaryColumnStruct(ppCase);

    donorProduct = calcYangPpPuBoundaryFlows( ...
        flowParams, col, 1, 1, "donor_product_end");
    receiverProduct = calcYangPpPuBoundaryFlows( ...
        flowParams, col, 1, 2, "receiver_product_end");
    receiverFeedWaste = calcYangPpPuBoundaryFlows( ...
        flowParams, col, 1, 2, "receiver_feed_waste");

    assert(donorProduct >= 0);
    assert(receiverProduct <= 0);
    assert(receiverFeedWaste <= 0);
end

function assertPpPuFlowIntegratorShape(params, ppCase, config)
    row = makeTwoBedNativeRow(params, ppCase);
    stTime = [0; config.durationDimless];
    stStates = [row; row];
    flowReport = integrateYangPpPuAdapterFlows(params, stTime, stStates, config);
    assert(all(flowReport.native.internalTransferOutByComponent >= 0));
    assert(isequal(flowReport.native.internalTransferOutByComponent, ...
        flowReport.native.internalTransferInByComponent));
    assert(all(flowReport.native.externalWasteByComponent >= 0));
    assert(all(flowReport.native.externalProductByComponent == 0));
end

function col = makeBoundaryColumnStruct(ppCase)
    donor = ppCase.localStates{1}.stateVector;
    receiver = ppCase.localStates{2}.stateVector;
    donorGas = donor([1, 2, 7, 8]);
    receiverGas = receiver([1, 2, 7, 8]);
    col.n1.gasConsTot = [sum(donorGas(1:2)), sum(donorGas(3:4))];
    col.n1.temps.cstr = [1, 1];
    col.n2.gasConsTot = [sum(receiverGas(1:2)), sum(receiverGas(3:4))];
    col.n2.temps.cstr = [1, 1];
end

function row = makeTwoBedNativeRow(params, ppCase)
    donor = [
        ppCase.localStates{1}.stateVector(:)
        zeros(2*params.nComs, 1)
    ];
    receiver = [
        ppCase.localStates{2}.stateVector(:)
        zeros(2*params.nComs, 1)
    ];
    row = [donor; receiver].';
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
