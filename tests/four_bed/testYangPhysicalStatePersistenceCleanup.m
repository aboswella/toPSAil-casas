function testYangPhysicalStatePersistenceCleanup()
%TESTYANGPHYSICALSTATEPERSISTENCECLEANUP T-STATE-02/T-CSS-01 physical state.
%
% Tier: Unit/sanity. Runtime class: < 10 s. Default smoke: yes.
% Failure modes caught: STATE-01/STATE-02 counter-tail persistence into
% named beds and CSS-01 boundary counters controlling convergence evidence.

    params = buildSyntheticParams();

    localFull = (1:params.nColStT)';
    payload = extractYangPhysicalBedState(params, localFull);
    assert(numel(payload.stateVector) == params.nColSt);
    assert(numel(payload.physicalStateVector) == params.nColSt);
    assert(isequal(payload.stateVector, localFull(1:params.nColSt)));
    assert(payload.payloadType == "yang_physical_adsorber_state_v1");

    counter = extractYangCounterTailDeltas(params, localFull);
    assert(~counter.persistAsBedState);
    assert(isequal(counter.counterTail(:), localFull(params.nColSt+1:params.nColStT)));
    assert(counter.counterTailMode == "terminal_tail_only_not_delta");

    initialFull = localFull;
    terminalFull = localFull;
    terminalFull(params.nColSt+1:params.nColStT) = ...
        terminalFull(params.nColSt+1:params.nColStT) + 5;
    delta = extractYangCounterTailDeltas(params, initialFull, terminalFull);
    assert(isequal(delta.counterTailDelta(:), 5 * ones(params.nColStT - params.nColSt, 1)));

    [container, selection] = buildWritebackContext();
    terminalStates = {
        struct("stateVector", localFull)
        struct("stateVector", localFull + 100)
    };
    [updated, report] = writeBackYangFourBedStates(container, selection, terminalStates, ...
        'Params', params, ...
        'UpdateNote', "T-STATE physical-only writeback");

    assert(all(report.counterTailStripped));
    assert(numel(updated.state_A.stateVector) == params.nColSt);
    assert(numel(updated.state_C.stateVector) == params.nColSt);
    assert(isequal(updated.state_A.stateVector, localFull(1:params.nColSt)));
    assert(isequal(updated.state_C.stateVector, localFull(1:params.nColSt) + 100));
    assert(isequaln(updated.state_B, container.state_B));
    assert(isequaln(updated.state_D, container.state_D));

    vec = extractYangStateVector(updated.state_A, 'Params', params);
    assert(numel(vec) == params.nColSt);

    css = computeCounterOnlyCss(params);
    assert(css.pass);
    assert(ismember("boundary_cumulative_flow_excluded", unique(css.rows.family)));

    fprintf('T-STATE physical cleanup passed: persistent beds exclude counter tails.\n');
end

function params = buildSyntheticParams()
    params = struct();
    params.nComs = 2;
    params.nVols = 2;
    params.nStates = 2*params.nComs + 2;
    params.nColSt = params.nStates * params.nVols;
    params.nColStT = params.nColSt + 2*params.nComs;
end

function [container, selection] = buildWritebackContext()
    manifest = getYangFourBedScheduleManifest();
    pairMap = getYangDirectTransferPairMap(manifest);
    states = struct();
    states.state_A = struct("bed", "A", "payload", 101, "marker", "sentinel_A");
    states.state_B = struct("bed", "B", "payload", 202, "marker", "sentinel_B");
    states.state_C = struct("bed", "C", "payload", 303, "marker", "sentinel_C");
    states.state_D = struct("bed", "D", "payload", 404, "marker", "sentinel_D");
    container = makeYangFourBedStateContainer(states, ...
        'Manifest', manifest, ...
        'PairMap', pairMap, ...
        'InitializationPolicy', "unit_test_distinguishable_sentinel_states", ...
        'SourceNote', "T-STATE physical cleanup synthetic states");

    pair = pairMap.transferPairs( ...
        pairMap.transferPairs.direct_transfer_family == "EQI" & ...
        pairMap.transferPairs.donor_bed == "A" & ...
        pairMap.transferPairs.receiver_bed == "C", :);
    selection = selectYangFourBedPairStates(container, pair);
end

function css = computeCounterOnlyCss(params)
    manifest = getYangFourBedScheduleManifest();
    pairMap = getYangDirectTransferPairMap(manifest);
    initial = makeCssContainer(manifest, pairMap, params, 0);
    final = initial;
    for bed = ["A", "B", "C", "D"]
        fieldName = "state_" + bed;
        final.(char(fieldName)).stateVector(params.nColSt+1:params.nColStT) = ...
            final.(char(fieldName)).stateVector(params.nColSt+1:params.nColStT) + 999;
    end

    css = computeYangFourBedCssResiduals(initial, final, ...
        'Params', params, 'AbsTol', 1e-12, 'RelTol', 1e-12, 'CycleIndex', 7);
end

function container = makeCssContainer(manifest, pairMap, params, offset)
    states = struct();
    states.state_A = struct("stateVector", (1:params.nColStT)' + offset);
    states.state_B = struct("stateVector", (1:params.nColStT)' + offset + 100);
    states.state_C = struct("stateVector", (1:params.nColStT)' + offset + 200);
    states.state_D = struct("stateVector", (1:params.nColStT)' + offset + 300);
    container = makeYangFourBedStateContainer(states, ...
        'Manifest', manifest, 'PairMap', pairMap, ...
        'InitializationPolicy', "unit_test_native_vectors_with_counter_tails", ...
        'SourceNote', "T-STATE physical cleanup CSS synthetic states");
end
