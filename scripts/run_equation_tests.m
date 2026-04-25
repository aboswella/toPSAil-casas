% Run Tier 2 equation-local tests.

repoRoot = fileparts(fileparts(mfilename("fullpath")));
oldDir = pwd;
cleanupObj = onCleanup(@() cd(oldDir));
cd(repoRoot);
addpath(genpath(repoRoot));

fprintf("Running Tier 2 equation-local tests...\n");
run(fullfile(repoRoot, "tests", "equations", "test_casas2012_equations.m"));
fprintf("Tier 2 equation-local tests completed.\n");
