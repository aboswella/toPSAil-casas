% Run Tier 4 Casas-lite breakthrough validation and write a report.

repoRoot = fileparts(fileparts(mfilename("fullpath")));
oldDir = pwd;
cleanupObj = onCleanup(@() cd(oldDir));
cd(repoRoot);
addpath(genpath(repoRoot));

fprintf("Running Tier 4 Casas-lite breakthrough validation...\n");
c = build_casas_lite_breakthrough_case( ...
    "n_cells", 24, ...
    "final_time_s", 700, ...
    "n_time_points", 281, ...
    "relative_tolerance", 1e-4, ...
    "absolute_tolerance", 1e-7, ...
    "max_step_s", 4);

tic;
result = simulate_casas_lite_breakthrough(c);
result.runtime_s = toc;

if ~result.health.all_hard_pass
    error("run_casas_lite_breakthrough_validation:HardChecksFailed", ...
          "Casas-lite validation hard checks failed.");
end

reportPath = fullfile(repoRoot, "validation", "reports", "casas_lite_breakthrough_report.md");
write_casas_lite_validation_report(result, reportPath);

fprintf("Casas-lite validation hard checks passed.\n");
fprintf("H2 y>=0.05 breakthrough: %.3g s\n", result.breakthrough.H2_y05_s);
fprintf("CO2 y>=0.05 breakthrough: %.3g s\n", result.breakthrough.CO2_y05_s);
fprintf("Maximum temperature rise: %.4f K\n", result.temperature.max_rise_K);
fprintf("Validation report written: %s\n", reportPath);
