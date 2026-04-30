function testYangTemporaryTwoBedCaseBuilder()
%TESTYANGTEMPORARYTWOBEDCASEBUILDER T-CASE-01 two-bed case builder.
%
% Tier: Unit. Runtime class: < 10 s. Default smoke: yes.
% Failure modes caught: CASE-01 state/parameter leakage, CASE-02 raw Yang
% labels in native fields, and STATE-03 crossed-pair local/global drift.

    [~, pairMap, container] = buildWp4SentinelContext();
    selection = selectPair(container, pairMap, "EQI", "B", "D");

    tempCase = makeYangTemporaryPairedCase(selection, ...
        'DurationSeconds', 1, ...
        'RunnerMode', "dry_run", ...
        'CaseNote', "T-CASE-01 crossed EQI pair");

    result = validateYangTemporaryCase(tempCase);
    assert(result.pass);
    assert(tempCase.caseType == "paired_direct_transfer");
    assert(tempCase.nLocalBeds == 2);
    assert(isequal(tempCase.localMap.global_bed, ["B"; "D"]));
    assert(isequal(tempCase.localMap.local_index, [1; 2]));
    assert(tempCase.localMap.local_role(1) == "donor");
    assert(tempCase.localMap.local_role(2) == "receiver");
    assert(all(tempCase.native.nativeStepNames == "EQ-XXX-APR"));
    assert(isequal(tempCase.native.numAdsEqPrEnd, [2; 1]));
    assert(tempCase.native.stageLabel == "EQI");
    assert(tempCase.architecture.noDynamicInternalTanks);
    assert(tempCase.architecture.noFourBedRhsDae);

    secondSelection = selectPair(container, pairMap, "EQI", "C", "A");
    secondCase = makeYangTemporaryPairedCase(secondSelection, ...
        'DurationSeconds', 1, ...
        'RunnerMode', "dry_run", ...
        'CaseNote', "T-CASE-01 crossed isolation pair");
    assert(~isequaln(tempCase.localStates, secondCase.localStates));
    assert(tempCase.pairId ~= secondCase.pairId);
    assert(isequal(secondCase.localMap.global_bed, ["C"; "A"]));

    fprintf('T-CASE-01 passed: temporary two-bed case builder preserves crossed pair identity.\n');
end

function selection = selectPair(container, pairMap, family, donor, receiver)
    pair = pairMap.transferPairs( ...
        pairMap.transferPairs.direct_transfer_family == string(family) & ...
        pairMap.transferPairs.donor_bed == string(donor) & ...
        pairMap.transferPairs.receiver_bed == string(receiver), :);
    assert(height(pair) == 1);
    selection = selectYangFourBedPairStates(container, pair);
end

function [manifest, pairMap, container] = buildWp4SentinelContext()
    manifest = getYangFourBedScheduleManifest();
    pairMap = getYangDirectTransferPairMap(manifest);
    initialStates = buildSentinelStates();
    container = makeYangFourBedStateContainer(initialStates, ...
        'Manifest', manifest, ...
        'PairMap', pairMap, ...
        'InitializationPolicy', "unit_test_distinguishable_sentinel_states", ...
        'SourceNote', "T-CASE-01 synthetic sentinel states");
end

function states = buildSentinelStates()
    states = struct();
    states.state_A = struct("bed", "A", "payload", 101, "marker", "sentinel_A");
    states.state_B = struct("bed", "B", "payload", 202, "marker", "sentinel_B");
    states.state_C = struct("bed", "C", "payload", 303, "marker", "sentinel_C");
    states.state_D = struct("bed", "D", "payload", 404, "marker", "sentinel_D");
end
