function testYangFourBedCycleDriverSpyWriteback()
%TESTYANGFOURBEDCYCLEDRIVERSPYWRITEBACK FI-6 cycle writeback contract.
%
% Tier: Integration/sanity using spy native runner. Final item: FI-6.
% Runtime class: < 15 s. Default smoke: no. Failure mode caught:
% local/global writeback drift, counter-tail persistence, and hidden
% four-bed/global-RHS architecture drift.

    params = buildYangH2Co2AcTemplateParams('NVols', 2, 'NCols', 2, 'NSteps', 1);
    params.nScaleFac = 1.0;
    container = makePhysicalContainer(params);
    controls = struct( ...
        "cycleTimeSec", 240, ...
        "nativeRunner", @spyNativeRunnerChanging, ...
        "adapterValidationOnly", true, ...
        "adapterCvBasis", "scaled_dimensionless", ...
        "debugKeepStateHistory", true);

    [nextContainer, report] = runYangFourBedCycle(container, params, controls);

    assert(height(nextContainer.writebackLog) == 40);
    assert(numel(report.operationReports) == 24);
    assert(all([report.operationReports.nonParticipantsUnchanged]));
    for bed = ["A", "B", "C", "D"]
        vec = extractYangStateVector(nextContainer.("state_" + bed), 'Params', params);
        assert(numel(vec) == params.nColSt);
    end
    assert(report.architecture.noDynamicInternalTanks);
    assert(report.architecture.noSharedHeaderInventory);
    assert(report.architecture.noGlobalFourBedRhs);
    assert(report.architecture.persistentStateBasis == "physical_adsorber_state_only");
    assert(report.architecture.metricsBasis == "wrapper_external_stream_ledger");

    fprintf('FI-6 cycle spy writeback passed: 24 groups update only participating physical beds.\n');
end

function [terminalLocalStates, nativeReport] = spyNativeRunnerChanging(tempCase, params, ~, group)
    terminalLocalStates = cell(tempCase.nLocalBeds, 1);
    for i = 1:tempCase.nLocalBeds
        payload = extractYangPhysicalBedState(params, tempCase.localStates{i});
        vec = payload.stateVector;
        vec(1) = vec(1) + 1e-4 * group.operationGroupIndex + 1e-5 * i;
        terminalLocalStates{i} = extractYangPhysicalBedState(params, vec, ...
            'Metadata', struct("source", "FI-6 changing spy native runner"));
    end
    nativeReport = makeNativeSpyReport(tempCase, params, group);
end

function nativeReport = makeNativeSpyReport(tempCase, params, group)
    nativeReport = struct();
    nativeReport.runner = "spy";
    nativeReport.didInvokeNative = false;
    nativeReport.warnings = strings(0, 1);
    nativeReport.counterTailDeltas = makeCounterDeltas(tempCase.nLocalBeds, params, group.operationFamily);
end

function deltas = makeCounterDeltas(nLocal, params, family)
    base = (1:params.nComs)' .* 0.01;
    deltas = cell(nLocal, 1);
    switch string(family)
        case "AD"
            deltas{1} = [base; 0.5 * base];
        case "BD"
            deltas{1} = [0.25 * base; zeros(params.nComs, 1)];
        case {"EQI", "EQII"}
            deltas{1} = [zeros(params.nComs, 1); base];
            deltas{2} = [zeros(params.nComs, 1); base];
        otherwise
            error('test:UnsupportedSpyFamily', 'Unsupported spy native family.');
    end
end

function container = makePhysicalContainer(params)
    states = struct();
    for idx = 1:4
        bed = ["A", "B", "C", "D"];
        states.("state_" + bed(idx)) = extractYangPhysicalBedState(params, ...
            makePhysicalVector(params, idx));
    end
    manifest = getYangFourBedScheduleManifest();
    pairMap = getYangDirectTransferPairMap(manifest);
    container = makeYangFourBedStateContainer(states, ...
        'Manifest', manifest, ...
        'PairMap', pairMap, ...
        'InitializationPolicy', "FI-6 spy physical states", ...
        'SourceNote', "synthetic physical H2/CO2 states");
end

function vec = makePhysicalVector(params, offset)
    one = [0.75 + 0.01 * offset; 0.25; 0.01 * offset; 0.02; 1.0; 1.0];
    vec = repmat(one, params.nVols, 1);
end
