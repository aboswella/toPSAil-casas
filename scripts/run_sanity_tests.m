% Run Tier 3 physical sanity tests.

repoRoot = fileparts(fileparts(mfilename("fullpath")));
oldDir = pwd;
cleanupObj = onCleanup(@() cd(oldDir));
cd(repoRoot);
addpath(genpath(repoRoot));

fprintf("Running Tier 3 physical sanity tests...\n");
run(fullfile(repoRoot, "tests", "sanity", "test_casas_lite_breakthrough_sanity.m"));
fprintf("Tier 3 physical sanity tests completed.\n");
