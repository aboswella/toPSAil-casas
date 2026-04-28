% Tier 2 equation tests: run isolated equation-local checks.
% Failure mode caught: local equation regressions before full PSA cases are
% introduced.

scriptDir = fileparts(mfilename("fullpath"));
repoRoot = fileparts(scriptDir);

fprintf("Tier 2 equation tests: starting.\n");
run(fullfile(repoRoot, "tests", "test_schell_sips_reference.m"));
fprintf("Tier 2 equation tests passed.\n");
