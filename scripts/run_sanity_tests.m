%RUN_SANITY_TESTS Run lightweight unit/sanity tests for project wrappers.
%
% Default smoke inclusion: yes for WP3-WP5 synthetic/structural tests.
% Runtime class: < 60 s. This runner must not hide long validation, optimization,
% sensitivity, event-policy, or pilot Yang runs.

fprintf('Running sanity/unit tests...\n');

testYangFourBedStateContainerShape();
testYangFourBedWritebackOnlyParticipants();
testYangFourBedCrossedPairRoundTrip();

scriptDir = fileparts(mfilename('fullpath'));
run(fullfile(scriptDir, "run_case_builder_tests.m"));
run(fullfile(scriptDir, "run_ledger_tests.m"));

fprintf('All sanity/unit tests passed.\n');
