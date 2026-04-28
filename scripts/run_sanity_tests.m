% Tier 3 sanity tests: run one-step physical and scaffold sanity checks.
% Failure mode caught: route/input scaffolds drift before full validation
% runs are introduced.

scriptDir = fileparts(mfilename("fullpath"));
repoRoot = fileparts(scriptDir);

fprintf("Tier 3 sanity tests: starting.\n");
run(fullfile(repoRoot, "tests", "test_schell_case_scaffold.m"));
fprintf("Tier 3 sanity tests passed.\n");
