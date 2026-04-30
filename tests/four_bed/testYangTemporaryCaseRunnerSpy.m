function testYangTemporaryCaseRunnerSpy()
%TESTYANGTEMPORARYCASERUNNERSPY WP4 runner/writeback contract.
%
% Tier: Unit. Runtime class: < 10 s. Default smoke: yes.
% Failure modes caught: STATE-01 wrong writeback target, STATE-02
% non-participant mutation, STATE-03 local-order drift, and CASE-01 runner
% invocation ambiguity.

    [manifest, pairMap, container] = buildWp4SentinelContext();

    pairSelection = selectPair(container, pairMap, "EQI", "B", "D");
    pairCase = makeYangTemporaryPairedCase(pairSelection, ...
        'DurationSeconds', 1, ...
        'RunnerMode', "spy", ...
        'CaseNote', "T-CASE runner spy crossed pair");

    [terminalLocalStates, runReport] = runYangTemporaryCase(pairCase, ...
        'Runner', "spy", ...
        'RunnerFunction', @makeYangTemporaryCaseRunnerSpy);
    assert(runReport.callCount == 1);
    assert(~runReport.didInvokeNative);
    assert(terminalLocalStates{1}.globalBed == "B");
    assert(terminalLocalStates{2}.globalBed == "D");
    assert(terminalLocalStates{1}.localIndex == 1);
    assert(terminalLocalStates{2}.localIndex == 2);

    [updated, wbReport] = writeBackYangFourBedStates(container, pairSelection, terminalLocalStates, ...
        'UpdateNote', "T-CASE runner spy terminal states");
    assert(isequaln(updated.state_B, terminalLocalStates{1}));
    assert(isequaln(updated.state_D, terminalLocalStates{2}));
    assert(isequaln(updated.state_A, container.state_A));
    assert(isequaln(updated.state_C, container.state_C));
    assert(isequal(string(wbReport.updatedBedLabels), ["B"; "D"]));

    singleSelection = selectSingle(container, manifest, "A", "AD");
    singleCase = makeYangTemporarySingleCase(singleSelection, ...
        'DurationSeconds', 1, ...
        'RunnerMode', "spy", ...
        'CaseNote', "T-CASE runner spy single AD");
    [singleTerminalStates, singleReport] = runYangTemporaryCase(singleCase, ...
        'Runner', "spy", ...
        'RunnerFunction', @makeYangTemporaryCaseRunnerSpy);
    assert(singleReport.callCount == 1);
    assert(numel(singleTerminalStates) == 1);
    assert(singleTerminalStates{1}.globalBed == "A");
    assert(singleTerminalStates{1}.localIndex == 1);

    fprintf('T-CASE runner spy passed: runner output remains in WP3 local writeback order.\n');
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
        'SourceNote', "T-CASE runner synthetic sentinel states");
end

function states = buildSentinelStates()
    states = struct();
    states.state_A = struct("bed", "A", "payload", 101, "marker", "sentinel_A");
    states.state_B = struct("bed", "B", "payload", 202, "marker", "sentinel_B");
    states.state_C = struct("bed", "C", "payload", 303, "marker", "sentinel_C");
    states.state_D = struct("bed", "D", "payload", 404, "marker", "sentinel_D");
end
