function testYangFourBedWritebackOnlyParticipants()
%TESTYANGFOURBEDWRITEBACKONLYPARTICIPANTS T-STATE-02: selective writeback.
%
% Tier: Unit. Runtime class: < 30 s. Default smoke: yes.
% Failure modes caught: STATE-01 wrong named-bed writeback and STATE-02
% accidental overwrite of non-participating persistent beds.

    [~, pairMap, initialStates, container] = buildWp3TestContext();
    pair = pairMap.transferPairs( ...
        pairMap.transferPairs.direct_transfer_family == "EQI" & ...
        pairMap.transferPairs.donor_bed == "A" & ...
        pairMap.transferPairs.receiver_bed == "C", :);
    selection = selectYangFourBedPairStates(container, pair);

    terminalStates = {
        struct("bed", "A", "payload", 1001, "marker", "terminal_A_from_local_1")
        struct("bed", "C", "payload", 3003, "marker", "terminal_C_from_local_2")
    };

    [updated, report] = writeBackYangFourBedStates(container, selection, terminalStates, ...
        'UpdateNote', "T-STATE-02 synthetic terminal states");

    assert(isequaln(updated.state_A, terminalStates{1}));
    assert(isequaln(updated.state_C, terminalStates{2}));
    assert(isequaln(updated.state_B, container.state_B));
    assert(isequaln(updated.state_D, container.state_D));
    assert(isequaln(container.state_A, initialStates.state_A));
    assert(isequaln(container.state_C, initialStates.state_C));
    assert(isequal(string(report.updatedStateFields), ["state_A"; "state_C"]));
    assert(isequal(string(report.unchangedStateFields), ["state_B"; "state_D"]));

    stateMetadata = updated.stateMetadata;
    assert(stateMetadata.writeback_count(stateMetadata.state_field == "state_A") == 1);
    assert(stateMetadata.writeback_count(stateMetadata.state_field == "state_C") == 1);
    assert(stateMetadata.writeback_count(stateMetadata.state_field == "state_B") == 0);
    assert(stateMetadata.writeback_count(stateMetadata.state_field == "state_D") == 0);
    assert(height(updated.writebackLog) == 2);

    fprintf('T-STATE-02 passed: writeback replaces only participating bed states.\n');
end

function [manifest, pairMap, initialStates, container] = buildWp3TestContext()
    manifest = getYangFourBedScheduleManifest();
    pairMap = getYangDirectTransferPairMap(manifest);
    initialStates = buildSentinelStates();
    container = makeYangFourBedStateContainer(initialStates, ...
        'Manifest', manifest, ...
        'PairMap', pairMap, ...
        'InitializationPolicy', "unit_test_distinguishable_sentinel_states", ...
        'SourceNote', "T-STATE-02 synthetic sentinel states");
end

function states = buildSentinelStates()
    states = struct();
    states.state_A = struct("bed", "A", "payload", 101, "marker", "sentinel_A");
    states.state_B = struct("bed", "B", "payload", 202, "marker", "sentinel_B");
    states.state_C = struct("bed", "C", "payload", 303, "marker", "sentinel_C");
    states.state_D = struct("bed", "D", "payload", 404, "marker", "sentinel_D");
end
