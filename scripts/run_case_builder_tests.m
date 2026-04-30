%RUN_CASE_BUILDER_TESTS Run WP4 temporary-case builder tests.
%
% Default smoke inclusion: yes for structural WP4 tests only. This runner
% excludes long numerical sensitivity, optimization, event-policy, and Yang
% pilot runs.

fprintf('Running WP4 case-builder tests...\n');

testYangNativeTranslationCoverage();
testYangTemporaryTwoBedCaseBuilder();
testYangTemporarySingleBedCaseBuilder();
testYangNoDynamicTankInventoryGuard();
testYangDirectPairEndpointMetadata();
testYangTemporaryCaseRunnerSpy();

fprintf('All WP4 case-builder tests passed.\n');
