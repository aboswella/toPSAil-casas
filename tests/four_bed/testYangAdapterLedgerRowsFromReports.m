function testYangAdapterLedgerRowsFromReports()
%TESTYANGADAPTERLEDGERROWSFROMREPORTS FI-7 adapter ledger mapping.
%
% Tier: Unit. Final item: FI-7. Runtime class: < 10 s. Default smoke: no.
% Failure mode caught: PP->PU product overcount and AD&PP->BF
% external/internal branch collapse.

    params = buildYangH2Co2AcTemplateParams('NVols', 2, 'NCols', 2, 'NSteps', 1);
    controls = normalizeYangFourBedControls(struct(), params);
    plan = buildYangFourBedOperationPlan(getYangFourBedScheduleManifest(), ...
        getYangDirectTransferPairMap(), getYangNormalizedSlotDurations(240));

    ppGroup = firstGroup(plan, "PP_PU");
    ppReport = struct();
    ppReport.directTransferFamily = "PP_PU";
    ppReport.flowReport = struct();
    ppReport.flowReport.moles = struct( ...
        "unitBasis", "physical_moles_using_params.nScaleFac", ...
        "internalTransferOutByComponent", [2.0; 0.2], ...
        "internalTransferInByComponent", [2.0; 0.2], ...
        "externalWasteByComponent", [0.5; 0.1]);
    [rows, report] = extractYangAdapterLedgerRows(ppReport, ppGroup, params, controls, ...
        'CycleIndex', 1);
    assert(report.flowBasis.basis == "physical_moles");
    assert(any(rows.stream_scope == "external_waste"));
    assert(any(rows.stream_scope == "internal_transfer"));
    assert(~any(rows.stream_scope == "external_product"));

    adppGroup = firstGroup(plan, "ADPP_BF");
    adppReport = struct();
    adppReport.directTransferFamily = "ADPP_BF";
    adppReport.flowReport = struct();
    adppReport.flowReport.moles = struct( ...
        "unitBasis", "physical_moles_using_params.nScaleFac", ...
        "externalFeedByComponent", [5.0; 1.0], ...
        "externalProductByComponent", [3.0; 0.2], ...
        "internalTransferOutByComponent", [1.0; 0.1], ...
        "internalTransferInByComponent", [1.0; 0.1], ...
        "externalWasteByComponent", [0.0; 0.0]);
    adppReport.effectiveSplit = struct("H2", 0.25, ...
        "primaryControl", "valve_coefficients_not_hard_coded_split_ratio");
    [rows, report] = extractYangAdapterLedgerRows(adppReport, adppGroup, params, controls, ...
        'CycleIndex', 1);
    assert(any(rows.stream_scope == "external_feed"));
    assert(any(rows.stream_scope == "external_product"));
    assert(any(rows.stream_scope == "internal_transfer"));
    assert(~any(rows.stream_scope == "external_waste"));
    assert(report.effectiveSplit.H2 == 0.25);

    nativeReport = adppReport;
    nativeReport.flowReport = rmfield(nativeReport.flowReport, 'moles');
    nativeReport.flowReport.native = struct( ...
        "unitBasis", "native_dimensionless_integral", ...
        "externalFeedByComponent", [5.0; 1.0], ...
        "externalProductByComponent", [3.0; 0.2], ...
        "internalTransferOutByComponent", [1.0; 0.1], ...
        "internalTransferInByComponent", [1.0; 0.1]);
    [~, report] = extractYangAdapterLedgerRows(nativeReport, adppGroup, params, controls, ...
        'CycleIndex', 1);
    assert(report.flowBasis.basis == "native_counter_units");
    assert(strlength(report.flowBasis.warning) > 0);

    fprintf('FI-7 adapter ledger extraction passed: adapter reports map to external/internal rows.\n');
end

function group = firstGroup(plan, family)
    groups = plan.operationGroups(string({plan.operationGroups.operationFamily}) == family);
    assert(~isempty(groups));
    group = groups(1);
end
