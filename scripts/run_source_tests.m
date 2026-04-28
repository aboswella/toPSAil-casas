% Tier 1 source tests: run source/parameter transcription checks.
% Failure mode caught: project source packs or validation target files drift
% before simulator cases are built.

scriptDir = fileparts(mfilename("fullpath"));
repoRoot = fileparts(scriptDir);

fprintf("Tier 1 source tests: starting.\n");
run(fullfile(repoRoot, "tests", "test_schell_source_pack.m"));
fprintf("Tier 1 source tests passed.\n");
