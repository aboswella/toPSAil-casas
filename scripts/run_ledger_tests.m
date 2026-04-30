%RUN_LEDGER_TESTS Run WP5 ledger/CSS/reporting tests.
%
% Default smoke inclusion: yes. Runtime class: < 60 s. These tests use
% synthetic stream/state packets and do not run long validation,
% optimization, sensitivity, event-policy, or Yang pilot cases.

fprintf('Running WP5 ledger/CSS/reporting tests...\n');

testYangFourBedLedgerSchema();
testYangPairLocalConservation();
testYangEqStageLedgerSeparation();
testYangAdppBfLedgerSplit();
testYangFullSlotLedgerBalance();
testYangCssResidualsAllBeds();
testYangMetricsExternalBasis();
testYangRunMetadataAssumptions();

fprintf('All WP5 ledger/CSS/reporting tests passed.\n');
