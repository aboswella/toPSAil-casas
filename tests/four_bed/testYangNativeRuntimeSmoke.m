function testYangNativeRuntimeSmoke()
%TESTYANGNATIVERUNTIMESMOKE FI-8 native single/pair smoke.
%
% Tier: Native smoke. Final item: FI-8. Runtime class: < 45 s. Default
% smoke: no. Failure mode caught: temporary cases cannot reach native
% runPsaCycleStep or omit stStates/counter tails needed for ledgers.

    params = buildYangH2Co2AcTemplateParams('NVols', 2, 'NCols', 2, ...
        'NSteps', 1, 'FinalizeForRuntime', true);
    readiness = assertYangRuntimeTemplateReady(params);
    assert(readiness.pass);

    manifest = getYangFourBedScheduleManifest();
    pairMap = getYangDirectTransferPairMap(manifest);
    container = makeCommissioningContainer(params, manifest, pairMap);

    adRow = manifest.bedSteps(manifest.bedSteps.bed == "A" & ...
        manifest.bedSteps.yang_label == "AD", :);
    adSelection = selectYangFourBedSingleState(container, adRow(1, :));
    adCase = makeYangTemporarySingleCase(adSelection, 'DurationSeconds', 0.1);
    [adStates, adReport] = runYangTemporaryCase(adCase, ...
        'Runner', "native", ...
        'TemplateParams', params, ...
        'DurationSeconds', 0.1);
    assertNativeReport(adStates, adReport, 1, params);

    eqRows = pairMap.transferPairs(pairMap.transferPairs.direct_transfer_family == "EQI", :);
    eqSelection = selectYangFourBedPairStates(container, eqRows(1, :));
    eqCase = makeYangTemporaryPairedCase(eqSelection, 'DurationSeconds', 0.1);
    [eqStates, eqReport] = runYangTemporaryCase(eqCase, ...
        'Runner', "native", ...
        'TemplateParams', params, ...
        'DurationSeconds', 0.1);
    assertNativeReport(eqStates, eqReport, 2, params);

    fprintf('FI-8 native runtime smoke passed: AD and EQI temporary cases expose stStates/counter tails.\n');
end

function assertNativeReport(terminalStates, report, nLocal, params)
    assert(numel(terminalStates) == nLocal);
    assert(report.runner == "native");
    assert(report.didInvokeNative);
    assert(report.timeBasis == "seconds_converted_to_dimensionless_using_tiScaleFac");
    assert(isfield(report, 'stStates'));
    assert(size(report.stStates, 2) == report.localRunPreparation.nStatesT);
    assert(isfield(report, 'counterTailDeltas') && numel(report.counterTailDeltas) == nLocal);
    assert(report.counterTailBasis == "native_counter_tail_delta_from_stStates");
    for i = 1:nLocal
        physical = extractYangPhysicalBedState(params, terminalStates{i});
        assert(numel(physical.physicalStateVector) == params.nColSt);
        assert(numel(report.counterTailDeltas{i}) == 2 * params.nComs);
    end
end

function container = makeCommissioningContainer(params, manifest, pairMap)
    states = struct();
    beds = ["A", "B", "C", "D"];
    for i = 1:numel(beds)
        one = [0.78 - 0.01 * i; 0.22 + 0.01 * i; 0.01; 0.02; 1.0; 1.0];
        states.("state_" + beds(i)) = extractYangPhysicalBedState(params, ...
            repmat(one, params.nVols, 1));
    end
    container = makeYangFourBedStateContainer(states, ...
        'Manifest', manifest, ...
        'PairMap', pairMap, ...
        'InitializationPolicy', "FI-8 native runtime smoke", ...
        'SourceNote', "synthetic physical states");
end
