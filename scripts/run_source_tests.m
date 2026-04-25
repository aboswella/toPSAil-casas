% Run Tier 1 source-transcription tests.

repoRoot = fileparts(fileparts(mfilename("fullpath")));
oldDir = pwd;
cleanupObj = onCleanup(@() cd(oldDir));
cd(repoRoot);
addpath(genpath(repoRoot));

fprintf("Running Tier 1 source-transcription tests...\n");
run(fullfile(repoRoot, "tests", "source", "test_casas2012_parameter_transcription.m"));
fprintf("Tier 1 source-transcription tests completed.\n");
