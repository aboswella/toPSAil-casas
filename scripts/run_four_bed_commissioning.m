%RUN_FOUR_BED_COMMISSIONING Run FI-8 staged four-bed commissioning gates.
%
% Default smoke inclusion: no. Runtime class: short staged commissioning
% only; excludes long CSS, sensitivity, optimization, event-policy, and
% Yang validation runs.

fprintf('Running FI-8 four-bed commissioning tests...\n');

testYangRuntimeTemplateReadiness();
testYangValveCoefficientScaling();
testYangNativeLedgerRowsSynthetic();
testYangNativeRuntimeSmoke();
testYangAdapterRuntimeSmoke();
testYangLedgerBasisSafety();
testYangAdapterAuditReportWrite();
testYangLedgerArtifactsWrite();

fprintf('FI-8 four-bed commissioning tests passed.\n');
