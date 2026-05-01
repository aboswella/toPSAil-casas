function testYangAdapterAuditReportWrite()
%TESTYANGADAPTERAUDITREPORTWRITE FI-7 compact adapter audit output.
%
% Tier: Unit. Final item: FI-7. Runtime class: < 10 s. Default smoke: no.
% Failure mode caught: audit files that omit identity/flow/conservation
% metadata or dump full state histories in compact mode.

    plan = buildYangFourBedOperationPlan(getYangFourBedScheduleManifest(), ...
        getYangDirectTransferPairMap(), getYangNormalizedSlotDurations(240));
    group = firstGroup(plan, "ADPP_BF");
    auditDir = fullfile(tempdir, "yang_adapter_audit_test_" + string(java.util.UUID.randomUUID));

    report = struct();
    report.directTransferFamily = "ADPP_BF";
    report.operationGroupId = string(group.operationGroupId);
    report.cycleIndex = 2;
    report.slotIndex = group.sourceCol;
    report.donorBed = string(group.donorBed);
    report.receiverBed = string(group.receiverBed);
    report.localMap = group.localMap;
    report.durationSeconds = group.durationSec;
    report.Cv_ADPP_feed = 0.1;
    report.Cv_ADPP_product = 0.2;
    report.Cv_ADPP_BF_internal = 0.3;
    report.pressureDiagnostics = struct("initial", struct("ok", true), ...
        "terminal", struct("ok", true));
    report.flows = struct("externalFeedByComponent", [1; 0.1], ...
        "externalProductByComponent", [0.5; 0.01], ...
        "internalTransferOutByComponent", [0.2; 0.02], ...
        "internalTransferInByComponent", [0.2; 0.02], ...
        "unitBasis", "native_dimensionless_integral");
    report.effectiveSplit = struct("H2", 0.25);
    report.conservation = struct("pass", true, "pairResidualByComponent", [0; 0]);
    report.sanity = struct("hasNaN", false);
    report.warnings = strings(0, 1);
    report.debugStateHistory = struct("large", ones(4, 4));

    status = writeYangAdapterAuditReport(report, auditDir, ...
        'CycleIndex', 2, ...
        'SlotIndex', group.sourceCol, ...
        'OperationGroupId', string(group.operationGroupId), ...
        'OperationFamily', "ADPP_BF", ...
        'DonorBed', string(group.donorBed), ...
        'ReceiverBed', string(group.receiverBed), ...
        'LocalMap', group.localMap, ...
        'OutputMode', "compact", ...
        'IncludeStateHistory', false);

    assert(status.pass);
    assert(isfile(status.path));
    txt = fileread(status.path);
    assert(contains(txt, "operationGroupId"));
    assert(contains(txt, "valveCoefficients"));
    assert(contains(txt, "integratedFlowsByComponent"));
    assert(contains(txt, "conservationResiduals"));
    assert(contains(txt, "architectureFlags"));
    assert(~contains(txt, "debugStateHistory"));

    fprintf('FI-7 adapter audit writer passed: compact JSON audit artifact includes required diagnostics.\n');
end

function group = firstGroup(plan, family)
    groups = plan.operationGroups(string({plan.operationGroups.operationFamily}) == family);
    assert(~isempty(groups));
    group = groups(1);
end
