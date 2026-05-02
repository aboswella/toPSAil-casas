function testYangAdppBfAdapterContract()
%TESTYANGADPPBFADAPTERCONTRACT FI-5 AD&PP->BF adapter contract test.
%
% Tier: Unit. Runtime class: < 10 s. Default smoke: yes.
% Failure modes caught: AD&PP/BF donor/receiver inversion, endpoint drift,
% external product/internal BF collapse, hidden tank/header architecture,
% missing split controls, and PP->PU dispatcher regression.

    [params, adppCase, ppCase] = buildAdapterTestContext();
    config = makeAdppBfConfig(true);

    [normalizedConfig, validation] = validateYangAdppBfAdapterInputs( ...
        adppCase, params, config);
    assert(validation.pass);
    assert(normalizedConfig.directTransferFamily == "ADPP_BF");

    assert(adppCase.native.nativeRunnable == false);
    assert(adppCase.localMap.local_index(1) == 1);
    assert(adppCase.localMap.local_index(2) == 2);
    assert(adppCase.localMap.local_role(1) == "donor");
    assert(adppCase.localMap.local_role(2) == "receiver");
    assert(adppCase.localMap.yang_label(1) == "AD&PP");
    assert(adppCase.localMap.yang_label(2) == "BF");
    assert(adppCase.native.endpointPolicy.donorOutletEndpoint == "product_end");
    assert(adppCase.native.endpointPolicy.receiverInletEndpoint == "product_end");
    assert(adppCase.native.endpointPolicy.receiverWasteEndpoint == "none");
    assert(adppCase.native.endpointPolicy.externalProductSeparated);

    [terminalLocalStates, adapterReport] = runYangDirectCouplingAdapter( ...
        adppCase, params, config);
    assert(numel(terminalLocalStates) == 2);
    assert(numel(terminalLocalStates{1}.stateVector) == params.nColSt);
    assert(numel(terminalLocalStates{2}.stateVector) == params.nColSt);
    assert(adapterReport.directTransferFamily == "ADPP_BF");
    assert(adapterReport.nativeStepGrammarUsed == false);
    assert(adapterReport.noDynamicInternalTanks);
    assert(adapterReport.noSharedHeaderInventory);
    assert(adapterReport.noFourBedRhsDae);
    assert(adapterReport.noCoreAdsorberPhysicsRewrite);
    assert(adapterReport.solverRunStatus == "validation_only_no_native_solver_invocation");
    assert(isfield(adapterReport.flows, 'externalFeedByComponent'));
    assert(isfield(adapterReport.flows, 'externalProductByComponent'));
    assert(isfield(adapterReport.flows, 'internalTransferOutByComponent'));
    assert(isfield(adapterReport.flows, 'internalTransferInByComponent'));
    assert(all(adapterReport.flows.externalWasteByComponent == 0));
    assert(isfield(adapterReport, 'effectiveSplit'));
    assert(adapterReport.effectiveSplit.primaryControl == ...
        "fixed_internal_split_fraction");
    assert(abs(adapterReport.effectiveSplit.requestedInternalSplitFraction - 1/3) < eps);

    assertAdppBfFlowLawSignsAndSensitivity(params, adppCase, normalizedConfig);

    invalidControl = config;
    invalidControl.ADPP_BF_internalSplitFraction = 1.1;
    assertErrorIdentifier(@() validateYangAdppBfAdapterInputs( ...
        adppCase, params, invalidControl), 'FI5:InvalidAdapterConfig');

    ppConfig = makePpPuConfig(true);
    [~, ppReport] = runYangDirectCouplingAdapter(ppCase, params, ppConfig);
    assert(ppReport.directTransferFamily == "PP_PU");
    assert(all(ppReport.flows.externalProductByComponent == 0));

    fprintf('FI-5 AD&PP->BF adapter contract passed: split controls, endpoints, and schema are explicit.\n');
end

function [params, adppCase, ppCase] = buildAdapterTestContext()
    params = buildYangH2Co2AcTemplateParams("NVols", 2, "NCols", 2, "NSteps", 1);
    manifest = getYangFourBedScheduleManifest();
    pairMap = getYangDirectTransferPairMap(manifest);
    container = makeYangFourBedStateContainer(makePhysicalStates(params), ...
        'Manifest', manifest, ...
        'PairMap', pairMap, ...
        'InitializationPolicy', "FI5_adapter_unit_test_physical_states", ...
        'SourceNote', "FI-5 ADPP_BF adapter contract states");

    adppCase = makeYangTemporaryPairedCase( ...
        selectPair(container, pairMap, "ADPP_BF", "A", "B"), ...
        'DurationDimless', 0.01, ...
        'RunnerMode', "wrapper_adapter", ...
        'CaseNote', "FI-5 ADPP_BF contract");
    ppCase = makeYangTemporaryPairedCase( ...
        selectPair(container, pairMap, "PP_PU", "B", "A"), ...
        'DurationDimless', 0.01, ...
        'RunnerMode', "wrapper_adapter", ...
        'CaseNote', "FI-5 PP_PU dispatcher regression");
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
    payload.metadata = struct("source", "FI5 adapter unit test");
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

function config = makePpPuConfig(validationOnly)
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

function assertAdppBfFlowLawSignsAndSensitivity(params, adppCase, config)
    flowParams = params;
    flowParams.sColNums = {'n1'; 'n2'};
    flowParams.yangAdapterConfig = config;
    col = makeBoundaryColumnStruct(params, adppCase);

    donorFeed = calcYangAdppBfBoundaryFlows( ...
        flowParams, col, 1, 1, "donor_feed_end");
    donorProduct = calcYangAdppBfBoundaryFlows( ...
        flowParams, col, 1, 1, "donor_product_end");
    receiverProduct = calcYangAdppBfBoundaryFlows( ...
        flowParams, col, 1, 2, "receiver_product_end");
    receiverFeed = calcYangAdppBfBoundaryFlows( ...
        flowParams, col, 1, 2, "receiver_feed_end");

    assert(donorFeed >= 0);
    assert(donorProduct >= 0);
    assert(receiverProduct <= 0);
    assert(receiverFeed == 0);

    row = makeTwoBedNativeRow(params, adppCase);
    stTime = [0; config.durationDimless];
    stStates = [row; row];
    base = integrateYangAdppBfAdapterFlows(params, stTime, stStates, config);

    totalProductEnd = base.native.totalExternalProduct + base.native.totalInternalTransferOut;
    assert(totalProductEnd > 0);
    assert(abs(base.native.totalInternalTransferOut / totalProductEnd - 1/3) < 1e-12);
    assert(base.effectiveSplit.primaryControl == "fixed_internal_split_fraction");

    splitConfig = config;
    splitConfig.ADPP_BF_internalSplitFraction = 0.5;
    [splitConfig, ~] = validateYangAdppBfAdapterInputs(adppCase, params, splitConfig);
    splitChanged = integrateYangAdppBfAdapterFlows(params, stTime, stStates, splitConfig);
    splitTotal = splitChanged.native.totalExternalProduct + ...
        splitChanged.native.totalInternalTransferOut;
    assert(abs(splitChanged.native.totalInternalTransferOut / splitTotal - 0.5) < 1e-12);
end

function col = makeBoundaryColumnStruct(params, adppCase)
    donor = reshape(adppCase.localStates{1}.stateVector, params.nStates, params.nVols).';
    receiver = reshape(adppCase.localStates{2}.stateVector, params.nStates, params.nVols).';
    col.n1.gasConsTot = sum(donor(:, 1:params.nComs), 2).';
    col.n1.temps.cstr = donor(:, 2*params.nComs+1).';
    col.n2.gasConsTot = sum(receiver(:, 1:params.nComs), 2).';
    col.n2.temps.cstr = receiver(:, 2*params.nComs+1).';
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
