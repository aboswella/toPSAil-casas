function testYangAdapterRuntimeSmoke()
%TESTYANGADAPTERRUNTIMESMOKE FI-8 adapter native-runtime smoke.
%
% Tier: Adapter smoke. Final item: FI-8. Runtime class: < 45 s. Default
% smoke: no. Failure mode caught: PP->PU or AD&PP->BF adapters remain
% validation-only after the H2/CO2 AC template is runtime-finalized.

    params = buildYangH2Co2AcTemplateParams('NVols', 2, 'NCols', 2, ...
        'NSteps', 1, 'FinalizeForRuntime', true);
    manifest = getYangFourBedScheduleManifest();
    pairMap = getYangDirectTransferPairMap(manifest);
    container = makeCommissioningContainer(params, manifest, pairMap);

    ppCase = makeCase(container, pairMap, "PP_PU");
    [ppStates, ppReport] = runYangPpPuAdapter(ppCase, params, struct( ...
        'validationOnly', false, ...
        'durationSeconds', 0.1, ...
        'Cv_directTransfer', 1e-6));
    assertAdapterReport(ppStates, ppReport, params, "PP_PU");
    assert(all(ppReport.flowReport.moles.externalProductByComponent == 0));

    adppCase = makeCase(container, pairMap, "ADPP_BF");
    [adppStates, adppReport] = runYangAdppBfAdapter(adppCase, params, struct( ...
        'validationOnly', false, ...
        'durationSeconds', 0.1, ...
        'Cv_directTransfer', 1e-6));
    assertAdapterReport(adppStates, adppReport, params, "ADPP_BF");
    assert(isfield(adppReport, 'effectiveSplit'));

    fprintf('FI-8 adapter runtime smoke passed: PP->PU and AD&PP->BF invoke native runPsaCycleStep.\n');
end

function assertAdapterReport(terminalStates, report, params, family)
    assert(numel(terminalStates) == 2);
    assert(report.directTransferFamily == family);
    assert(report.didInvokeNative);
    assert(report.solverRunStatus == "completed_native_runPsaCycleStep");
    assert(report.timeBasis == "seconds_converted_to_dimensionless_using_tiScaleFac");
    assert(report.flowReport.primaryBasis == "native_counter_tail_delta");
    assert(report.flowReport.moles.unitBasis == ...
        "physical_moles_from_native_counter_tail_delta_using_params.nScaleFac");
    assert(isfield(report, 'terminalPhysicalStateChecksums'));
    assert(~report.sanity.hasNaN);
    for i = 1:numel(terminalStates)
        physical = extractYangPhysicalBedState(params, terminalStates{i});
        assert(numel(physical.physicalStateVector) == params.nColSt);
    end
end

function tempCase = makeCase(container, pairMap, family)
    rows = pairMap.transferPairs(pairMap.transferPairs.direct_transfer_family == string(family), :);
    selection = selectYangFourBedPairStates(container, rows(1, :));
    tempCase = makeYangTemporaryPairedCase(selection, 'DurationSeconds', 0.1);
end

function container = makeCommissioningContainer(params, manifest, pairMap)
    states = struct();
    beds = ["A", "B", "C", "D"];
    for i = 1:numel(beds)
        one = [0.76 - 0.01 * i; 0.24 + 0.01 * i; 0.01; 0.02; 1.0; 1.0];
        states.("state_" + beds(i)) = extractYangPhysicalBedState(params, ...
            repmat(one, params.nVols, 1));
    end
    container = makeYangFourBedStateContainer(states, ...
        'Manifest', manifest, ...
        'PairMap', pairMap, ...
        'InitializationPolicy', "FI-8 adapter runtime smoke", ...
        'SourceNote', "synthetic physical states");
end
