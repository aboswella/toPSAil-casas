function testYangFourBedStateContainerShape()
%TESTYANGFOURBEDSTATECONTAINERSHAPE T-STATE-01: state container shape.
%
% Tier: Unit. Runtime class: < 5 s. Default smoke: yes.
% Failure modes caught: STATE-01 terminal-state identity drift and STATE-03
% undocumented or ambiguous initialization policy.

    [manifest, pairMap, initialStates, container] = buildWp3TestContext();
    result = validateYangFourBedStateContainer(container, ...
        'Manifest', manifest, ...
        'PairMap', pairMap);

    if ~result.pass
        disp(result.checks);
        disp(result.failures);
        error('WP3:TState01Failed', ...
            'T-STATE-01 failed: WP3 state container schema is invalid.');
    end

    assert(isequal(string(container.bedLabels), ["A", "B", "C", "D"]));
    assert(isequal(string(container.stateFields), ["state_A", "state_B", "state_C", "state_D"]));
    assert(isequaln(container.state_A, initialStates.state_A));
    assert(isequaln(container.state_B, initialStates.state_B));
    assert(isequaln(container.state_C, initialStates.state_C));
    assert(isequaln(container.state_D, initialStates.state_D));
    assert(container.architecture.noDynamicInternalTanks);
    assert(container.architecture.noSharedHeaderInventory);
    assert(container.architecture.noFourBedRhsDae);
    assert(~container.architecture.wp3InvokesSolver);

    pair = pairMap.transferPairs( ...
        pairMap.transferPairs.direct_transfer_family == "EQI" & ...
        pairMap.transferPairs.donor_bed == "A" & ...
        pairMap.transferPairs.receiver_bed == "C", :);
    selection = selectYangFourBedPairStates(container, pair);

    assert(isequal(selection.localMap.local_index, [1; 2]));
    assert(isequal(selection.localMap.local_role, ["donor"; "receiver"]));
    assert(isequal(selection.localMap.global_bed, ["A"; "C"]));
    assert(isequal(selection.localMap.state_field, ["state_A"; "state_C"]));
    assert(isequaln(selection.localStates{1}, initialStates.state_A));
    assert(isequaln(selection.localStates{2}, initialStates.state_C));

    singleRow = manifest.bedSteps(manifest.bedSteps.bed == "A" & ...
        manifest.bedSteps.yang_label == "AD", :);
    singleSelection = selectYangFourBedSingleState(container, singleRow);
    assert(isequal(singleSelection.localMap.local_index, 1));
    assert(singleSelection.localMap.global_bed == "A");
    assert(singleSelection.localMap.state_field == "state_A");
    assert(isequaln(singleSelection.localStates{1}, initialStates.state_A));

    fprintf('T-STATE-01 passed: persistent four-bed state container shape and deterministic selection.\n');
end

function [manifest, pairMap, initialStates, container] = buildWp3TestContext()
    manifest = getYangFourBedScheduleManifest();
    pairMap = getYangDirectTransferPairMap(manifest);
    initialStates = buildSentinelStates();
    container = makeYangFourBedStateContainer(initialStates, ...
        'Manifest', manifest, ...
        'PairMap', pairMap, ...
        'InitializationPolicy', "unit_test_distinguishable_sentinel_states", ...
        'SourceNote', "T-STATE-01 synthetic sentinel states");
end

function states = buildSentinelStates()
    states = struct();
    states.state_A = struct("bed", "A", "payload", 101, "marker", "sentinel_A");
    states.state_B = struct("bed", "B", "payload", 202, "marker", "sentinel_B");
    states.state_C = struct("bed", "C", "payload", 303, "marker", "sentinel_C");
    states.state_D = struct("bed", "D", "payload", 404, "marker", "sentinel_D");
end
