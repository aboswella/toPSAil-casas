function testYangFourBedCycleAdapterCounterBalance()
%TESTYANGFOURBEDCYCLEADAPTERCOUNTERBALANCE FI-8 coarse-grid cycle balance.
%
% Tier: Sanity/integration. Final item: FI-8. Runtime class: < 90 s.
% Default smoke: no. Failure mode caught: full-cycle balance requires dense
% adapter output histories or emits adapter conservation warnings.

    params = buildYangH2Co2AcTemplateParams( ...
        'NVols', 2, 'NCols', 2, 'NSteps', 1, ...
        'NTimePoints', 21, 'FinalizeForRuntime', true);
    manifest = getYangFourBedScheduleManifest();
    pairMap = getYangDirectTransferPairMap(manifest);
    initial = makeCommissioningContainer(params, manifest, pairMap);

    controls = struct( ...
        'cycleTimeSec', 2.4, ...
        'adapterValidationOnly', false, ...
        'Cv_directTransfer', 1e-2, ...
        'ADPP_BF_externalProductPressureRatio', 0.75, ...
        'balanceAbsTol', 1e-8, ...
        'balanceRelTol', 1e-6);

    [~, report] = runYangFourBedCycle(initial, params, controls, ...
        'Manifest', manifest, ...
        'PairMap', pairMap, ...
        'CycleIndex', 1);

    assert(report.balanceSummary.pass);
    assert(report.balanceSummary.maxAbsResidual <= controls.balanceAbsTol + 10*eps);
    assert(~any(contains(report.warnings, ...
        "component conservation residual exceeded tolerance")));
    assertAdapterReportsUseCounterBasis(report, 0.75);

    fprintf('FI-8 four-bed cycle adapter counter balance passed at NTimePoints=21.\n');
end

function assertAdapterReportsUseCounterBasis(report, expectedExternalProductPressureRatio)
    for i = 1:numel(report.operationReports)
        op = report.operationReports(i);
        family = string(op.operationFamily);
        if family ~= "PP_PU" && family ~= "ADPP_BF"
            continue;
        end
        runReport = op.runReport;
        assert(isfield(runReport, 'flowReport'));
        assert(runReport.flowReport.primaryBasis == "native_counter_tail_delta");
        if family == "ADPP_BF"
            assert(isfield(runReport, 'externalProductPressureRatio'));
            assert(runReport.externalProductPressureRatio == ...
                expectedExternalProductPressureRatio);
        else
            assert(~isfield(runReport, 'externalProductPressureRatio'));
        end
    end
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
        'InitializationPolicy', "FI-8 adapter counter cycle balance", ...
        'SourceNote', "synthetic physical states");
end
