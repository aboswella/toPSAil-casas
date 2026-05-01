%RUN_SOURCE_TESTS Run lightweight static/source tests for the project.
%
% Default smoke inclusion: yes. Runtime class: < 30 s. This runner must not
% hide long validation, optimization, sensitivity, or event-policy runs.

fprintf('Running source/static tests...\n');

testYangManifestIntegrity();
testYangNormalizedSlotDurations();
testYangLayeredBedCapability();
testYangPairMapCompleteness();

fprintf('All source/static tests passed.\n');
