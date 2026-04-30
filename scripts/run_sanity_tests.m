%RUN_SANITY_TESTS Run lightweight unit/sanity tests for project wrappers.
%
% Default smoke inclusion: yes for WP3 state-container tests. Runtime class:
% < 30 s. This runner must not hide long validation, optimization,
% sensitivity, event-policy, or pilot Yang runs.

fprintf('Running sanity/unit tests...\n');

testYangFourBedStateContainerShape();
testYangFourBedWritebackOnlyParticipants();
testYangFourBedCrossedPairRoundTrip();

fprintf('All sanity/unit tests passed.\n');
