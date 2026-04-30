function testYangTemporarySingleBedCaseBuilder()
%TESTYANGTEMPORARYSINGLEBEDCASEBUILDER T-CASE-02 single-bed builder.
%
% Tier: Unit. Runtime class: < 10 s. Default smoke: yes.
% Failure modes caught: CASE-01 state leakage and CASE-03 missing global
% identity for single-bed operations.

    [manifest, ~, container] = buildWp4SentinelContext();

    adSelection = selectSingle(container, manifest, "A", "AD");
    adCase = makeYangTemporarySingleCase(adSelection, ...
        'DurationSeconds', 1, ...
        'RunnerMode', "dry_run", ...
        'CaseNote', "T-CASE-02 AD single");
    adResult = validateYangTemporaryCase(adCase);
    assert(adResult.pass);
    assert(adCase.nLocalBeds == 1);
    assert(adCase.native.nativeStepNames == "HP-FEE-RAF");
    assert(adCase.native.endpointPolicy.externalFeed);
    assert(adCase.native.endpointPolicy.externalProduct);
    assert(adCase.localMap.global_bed == "A");
    assert(adCase.localMap.local_index == 1);
    assert(~isfield(adCase, 'state_B'));

    bdSelection = selectSingle(container, manifest, "C", "BD");
    bdCase = makeYangTemporarySingleCase(bdSelection, ...
        'DurationSeconds', 1, ...
        'RunnerMode', "dry_run", ...
        'CaseNote', "T-CASE-02 BD single");
    bdResult = validateYangTemporaryCase(bdCase);
    assert(bdResult.pass);
    assert(bdCase.nLocalBeds == 1);
    assert(bdCase.native.nativeStepNames == "DP-ATM-XXX");
    assert(bdCase.native.endpointPolicy.externalWaste);
    assert(bdCase.localMap.global_bed == "C");
    assert(bdCase.localMap.local_index == 1);
    assert(~isfield(bdCase, 'state_A'));

    fprintf('T-CASE-02 passed: temporary single-bed case builder preserves global identity.\n');
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
        'SourceNote', "T-CASE-02 synthetic sentinel states");
end

function states = buildSentinelStates()
    states = struct();
    states.state_A = struct("bed", "A", "payload", 101, "marker", "sentinel_A");
    states.state_B = struct("bed", "B", "payload", 202, "marker", "sentinel_B");
    states.state_C = struct("bed", "C", "payload", 303, "marker", "sentinel_C");
    states.state_D = struct("bed", "D", "payload", 404, "marker", "sentinel_D");
end
