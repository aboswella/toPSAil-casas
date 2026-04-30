function testYangNoDynamicTankInventoryGuard()
%TESTYANGNODYNAMICTANKINVENTORYGUARD T-STATIC-03 no internal inventory.
%
% Tier: Static/unit. Runtime class: < 5 s. Default smoke: yes.
% Failure mode caught: ARCH-01 dynamic internal tank or shared header state
% creation in the Yang wrapper path.

    [manifest, pairMap, container] = buildWp4SentinelContext();

    cases = {
        makeYangTemporaryPairedCase(selectPair(container, pairMap, "EQI", "B", "D"), 'DurationSeconds', 1)
        makeYangTemporaryPairedCase(selectPair(container, pairMap, "EQII", "A", "D"), 'DurationSeconds', 1)
        makeYangTemporaryPairedCase(selectPair(container, pairMap, "PP_PU", "B", "A"), 'DurationSeconds', 1)
        makeYangTemporaryPairedCase(selectPair(container, pairMap, "ADPP_BF", "A", "B"), 'DurationSeconds', 1)
        makeYangTemporarySingleCase(selectSingle(container, manifest, "A", "AD"), 'DurationSeconds', 1)
        makeYangTemporarySingleCase(selectSingle(container, manifest, "C", "BD"), 'DurationSeconds', 1)
    };

    for i = 1:numel(cases)
        tempCase = cases{i};
        result = assertNoYangInternalTankInventory(tempCase);
        assert(result.pass);
        assert(tempCase.architecture.noDynamicInternalTanks);
        assert(tempCase.architecture.noSharedHeaderInventory);
        assert(tempCase.architecture.noFourBedRhsDae);
    end

    fprintf('T-STATIC-03 passed: WP4 cases create no dynamic Yang internal tank/header inventory.\n');
end

function selection = selectPair(container, pairMap, family, donor, receiver)
    pair = pairMap.transferPairs( ...
        pairMap.transferPairs.direct_transfer_family == string(family) & ...
        pairMap.transferPairs.donor_bed == string(donor) & ...
        pairMap.transferPairs.receiver_bed == string(receiver), :);
    assert(height(pair) == 1);
    selection = selectYangFourBedPairStates(container, pair);
end

function selection = selectSingle(container, manifest, bed, yangLabel)
    row = manifest.bedSteps( ...
        manifest.bedSteps.bed == string(bed) & ...
        manifest.bedSteps.yang_label == string(yangLabel), :);
    assert(height(row) >= 1);
    selection = selectYangFourBedSingleState(container, row(1, :));
end

function [manifest, pairMap, container] = buildWp4SentinelContext()
    manifest = getYangFourBedScheduleManifest();
    pairMap = getYangDirectTransferPairMap(manifest);
    initialStates = buildSentinelStates();
    container = makeYangFourBedStateContainer(initialStates, ...
        'Manifest', manifest, ...
        'PairMap', pairMap, ...
        'InitializationPolicy', "unit_test_distinguishable_sentinel_states", ...
        'SourceNote', "T-STATIC-03 synthetic sentinel states");
end

function states = buildSentinelStates()
    states = struct();
    states.state_A = struct("bed", "A", "payload", 101, "marker", "sentinel_A");
    states.state_B = struct("bed", "B", "payload", 202, "marker", "sentinel_B");
    states.state_C = struct("bed", "C", "payload", 303, "marker", "sentinel_C");
    states.state_D = struct("bed", "D", "payload", 404, "marker", "sentinel_D");
end
