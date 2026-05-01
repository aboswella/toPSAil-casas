function testYangNativeLedgerRowsSynthetic()
%TESTYANGNATIVELEDGERROWSSYNTHETIC FI-7 native counter mapping.
%
% Tier: Unit. Final item: FI-7. Runtime class: < 10 s. Default smoke: no.
% Failure mode caught: feed/product counter-tail confusion and missing
% targeted errors when native counters are unavailable.

    params = buildYangH2Co2AcTemplateParams('NVols', 2, 'NCols', 2, 'NSteps', 1);
    controls = normalizeYangFourBedControls(struct(), params);
    [manifest, pairMap, plan] = planContext();

    adGroup = firstGroup(plan, "AD");
    nativeReport.counterTailDeltas = {[1.0; 0.2; 0.7; 0.05]};
    [rows, report] = extractYangNativeLedgerRows(nativeReport, adGroup, params, controls, ...
        'CycleIndex', 1);
    assert(report.operationFamily == "AD");
    assert(any(rows.stream_scope == "external_feed"));
    assert(any(rows.stream_scope == "external_product"));
    assert(~any(rows.stream_scope == "external_waste"));

    bdGroup = firstGroup(plan, "BD");
    nativeReport.counterTailDeltas = {[0.4; 0.1; 0.0; 0.0]};
    rows = extractYangNativeLedgerRows(nativeReport, bdGroup, params, controls, ...
        'CycleIndex', 1);
    assert(all(rows.stream_scope == "external_waste"));

    eqiGroup = firstGroup(plan, "EQI");
    nativeReport.counterTailDeltas = {
        [0.0; 0.0; 0.3; 0.03]
        [0.0; 0.0; 0.3; 0.03]
    };
    rows = extractYangNativeLedgerRows(nativeReport, eqiGroup, params, controls, ...
        'CycleIndex', 1);
    assert(all(rows.stream_scope == "internal_transfer"));
    assert(any(rows.stream_direction == "out_of_donor"));
    assert(any(rows.stream_direction == "into_receiver"));
    assert(all(rows.direct_transfer_family == "EQI"));

    eqiiGroup = firstGroup(plan, "EQII");
    nativeReport.counterTailDeltas = {
        [0.0; 0.0; 0.2; 0.02]
        [0.0; 0.0; 0.2; 0.02]
    };
    rows = extractYangNativeLedgerRows(nativeReport, eqiiGroup, params, controls, ...
        'CycleIndex', 1);
    assert(all(rows.direct_transfer_family == "EQII"));

    try
        extractYangNativeLedgerRows(struct(), adGroup, params, controls);
        error('test:ExpectedErrorMissingCounters', 'Expected missing counter error.');
    catch err
        assert(strcmp(err.identifier, 'FI7:NativeCounterTailUnavailable'));
    end

    fprintf('FI-7 native synthetic ledger extraction passed: native counter tails map to expected streams.\n');

    %#ok<NASGU>
    manifest;
    pairMap;
end

function [manifest, pairMap, plan] = planContext()
    manifest = getYangFourBedScheduleManifest();
    pairMap = getYangDirectTransferPairMap(manifest);
    plan = buildYangFourBedOperationPlan(manifest, pairMap, ...
        getYangNormalizedSlotDurations(240));
end

function group = firstGroup(plan, family)
    groups = plan.operationGroups(string({plan.operationGroups.operationFamily}) == family);
    assert(~isempty(groups));
    group = groups(1);
end
