fprintf('Running Yang four-bed cycle tests...\n');

testYangFourBedOperationPlanCompleteness();
testYangNativeLedgerRowsSynthetic();
testYangAdapterLedgerRowsFromReports();
testYangAdapterAuditReportWrite();
testYangFourBedCycleDriverSpyWriteback();
testYangFourBedCycleLedgerSmoke();
testYangFourBedSimulationCssPlumbing();

fprintf('Yang four-bed cycle tests passed.\n');
