function testYangFourBedCrossedPairRoundTrip()
%TESTYANGFOURBEDCROSSEDPAIRROUNDTRIP T-STATE-03: crossed pair round trip.
%
% Tier: Unit. Runtime class: < 30 s. Default smoke: yes.
% Failure modes caught: STATE-01 local/global writeback drift and SCHED-02
% accidental row-order, adjacency, or alphabetical pair inference.

    [~, pairMap, ~, container] = buildWp3TestContext();
    pair = pairMap.transferPairs( ...
        pairMap.transferPairs.direct_transfer_family == "EQI" & ...
        pairMap.transferPairs.donor_bed == "B" & ...
        pairMap.transferPairs.receiver_bed == "D", :);
    selection = selectYangFourBedPairStates(container, pair);

    assert(isequal(selection.localMap.local_index, [1; 2]));
    assert(isequal(selection.localMap.global_bed, ["B"; "D"]));
    assert(isequal(selection.localMap.state_field, ["state_B"; "state_D"]));
    assert(selection.localMap.local_role(1) == "donor");
    assert(selection.localMap.local_role(2) == "receiver");

    terminalStates = {
        struct("bed", "B", "payload", 2002, "marker", "local_1_donor_B_terminal")
        struct("bed", "D", "payload", 4004, "marker", "local_2_receiver_D_terminal")
    };

    [updated, report] = writeBackYangFourBedStates(container, selection, terminalStates, ...
        'UpdateNote', "T-STATE-03 crossed pair synthetic terminal states");

    assert(isequaln(updated.state_B, terminalStates{1}));
    assert(isequaln(updated.state_D, terminalStates{2}));
    assert(isequaln(updated.state_A, container.state_A));
    assert(isequaln(updated.state_C, container.state_C));
    assert(isequal(string(report.updatedBedLabels), ["B"; "D"]));
    assert(height(updated.writebackLog) == 2);
    assert(all(updated.writebackLog.writeback_index == report.writebackIndex));
    assert(isequal(updated.writebackLog.global_bed, ["B"; "D"]));

    fprintf('T-STATE-03 passed: crossed-pair local states write back to correct global beds.\n');
end

function [manifest, pairMap, initialStates, container] = buildWp3TestContext()
    manifest = getYangFourBedScheduleManifest();
    pairMap = getYangDirectTransferPairMap(manifest);
    initialStates = buildSentinelStates();
    container = makeYangFourBedStateContainer(initialStates, ...
        'Manifest', manifest, ...
        'PairMap', pairMap, ...
        'InitializationPolicy', "unit_test_distinguishable_sentinel_states", ...
        'SourceNote', "T-STATE-03 synthetic sentinel states");
end

function states = buildSentinelStates()
    states = struct();
    states.state_A = struct("bed", "A", "payload", 101, "marker", "sentinel_A");
    states.state_B = struct("bed", "B", "payload", 202, "marker", "sentinel_B");
    states.state_C = struct("bed", "C", "payload", 303, "marker", "sentinel_C");
    states.state_D = struct("bed", "D", "payload", 404, "marker", "sentinel_D");
end
