function testYangMetricsExternalBasis()
%TESTYANGMETRICSEXTERNALBASIS T-MET-01 Yang purity/recovery reconstruction.
%
% Tier: Integration/sanity. Runtime class: < 10 s. Default smoke: yes.
% Failure mode caught: LEDGER-01 internal transfer counted as product or
% recovery numerator.

    [manifest, pairMap] = buildWp5ManifestContext();
    componentNames = ["H2"; "CO2"];
    ledger = makeYangFourBedLedger(componentNames, ...
        'Manifest', manifest, 'PairMap', pairMap, ...
        'LedgerNote', "T-MET-01 external metric basis");
    ledger = appendBaseMetricRows(ledger, componentNames, [500; 10]);

    metrics = computeYangPerformanceMetrics(ledger, 'TargetProductComponent', "H2");
    purity = getMetric(metrics, "product_purity");
    recovery = getMetric(metrics, "product_recovery");
    assertClose(purity, 75 / (75 + 0.001), 1e-12);
    assertClose(recovery, 75 / 100, 1e-12);
    assert(all(contains(metrics.rows.basis, "internal_transfers_excluded")));
    assert(all(contains(metrics.rows.notes, "internal_transfer rows excluded")));

    ledgerLargeInternal = makeYangFourBedLedger(componentNames, ...
        'Manifest', manifest, 'PairMap', pairMap, ...
        'LedgerNote', "T-MET-01 external metric basis large internal");
    ledgerLargeInternal = appendBaseMetricRows(ledgerLargeInternal, componentNames, [1000; 200]);
    metricsLargeInternal = computeYangPerformanceMetrics(ledgerLargeInternal, ...
        'TargetProductComponent', "H2");
    assertClose(getMetric(metricsLargeInternal, "product_purity"), purity, 1e-12);
    assertClose(getMetric(metricsLargeInternal, "product_recovery"), recovery, 1e-12);

    fprintf('T-MET-01 passed: Yang purity/recovery use only external ledger rows.\n');
end

function ledger = appendBaseMetricRows(ledger, componentNames, internalMoles)
    common = {'CycleIndex', 1, 'SlotIndex', 1, 'OperationGroupId', "metric-basis", ...
        'PairId', "none", 'StageLabel', "AD", 'DirectTransferFamily', "none", ...
        'RecordId', "A-01", 'YangLabel', "AD", 'GlobalBed', "A", ...
        'LocalIndex', 1, 'LocalRole', "external_single", 'Basis', "synthetic"};
    ledger = appendYangLedgerStreamRows(ledger, componentNames, [100; 20], common{:}, ...
        'StreamScope', "external_feed", 'StreamDirection', "in", 'Endpoint', "feed_end");
    ledger = appendYangLedgerStreamRows(ledger, componentNames, [75; 0.001], common{:}, ...
        'StreamScope', "external_product", 'StreamDirection', "out", 'Endpoint', "product_end");
    ledger = appendYangLedgerStreamRows(ledger, componentNames, internalMoles, common{:}, ...
        'PairId', "EQI-A-to-C", 'StageLabel', "EQI", 'DirectTransferFamily', "EQI", ...
        'YangLabel', "EQI-BD", 'LocalRole', "donor", ...
        'StreamScope', "internal_transfer", 'StreamDirection', "out_of_donor", ...
        'Endpoint', "product_end");
    ledger = appendYangLedgerStreamRows(ledger, componentNames, internalMoles, common{:}, ...
        'PairId', "EQI-A-to-C", 'StageLabel', "EQI", 'DirectTransferFamily', "EQI", ...
        'YangLabel', "EQI-PR", 'GlobalBed', "C", 'LocalIndex', 2, ...
        'LocalRole', "receiver", 'StreamScope', "internal_transfer", ...
        'StreamDirection', "into_receiver", 'Endpoint', "product_end");
end

function value = getMetric(metrics, metricName)
    row = metrics.rows(metrics.rows.metric_name == string(metricName), :);
    assert(height(row) == 1);
    value = row.value(1);
end

function assertClose(actual, expected, tol)
    assert(abs(actual - expected) <= tol);
end

function [manifest, pairMap] = buildWp5ManifestContext()
    manifest = getYangFourBedScheduleManifest();
    pairMap = getYangDirectTransferPairMap(manifest);
end
