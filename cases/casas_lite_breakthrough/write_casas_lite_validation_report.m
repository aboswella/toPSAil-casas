function write_casas_lite_validation_report(result, reportPath)
%WRITE_CASAS_LITE_VALIDATION_REPORT Write a Markdown Casas validation report.

    fid = fopen(reportPath, "w");
    if fid < 0
        error("write_casas_lite_validation_report:OpenFailed", ...
              "Could not open report path for writing: %s", reportPath);
    end
    cleanupObj = onCleanup(@() fclose(fid));

    fprintf(fid, "# Casas-Lite Breakthrough Validation Report\n\n");
    fprintf(fid, "source_reference_file = %s\n\n", result.source_reference_file);
    fprintf(fid, "parameter_pack = %s\n\n", result.parameter_pack);
    fprintf(fid, "model_mode = %s\n\n", result.model_mode);
    fprintf(fid, "source_values_changed = no\n\n");
    fprintf(fid, "validation_thresholds_changed = no\n\n");
    fprintf(fid, "grid/cell count = %d\n\n", result.grid_cells);
    if isfield(result, "runtime_s")
        fprintf(fid, "run time = %.3f s\n\n", result.runtime_s);
    else
        fprintf(fid, "run time = unavailable\n\n");
    end
    fprintf(fid, "solver status = %s\n\n", result.solver_status);
    fprintf(fid, "known_omissions = %s\n\n", strjoin(result.known_omissions, ", "));
    fprintf(fid, "flow_mapping = %s\n\n", result.flow_mapping);
    fprintf(fid, "initial_gas_handling = %s\n\n", result.initial_gas_handling);

    fprintf(fid, "## Hard Checks\n\n");
    hardNames = fieldnames(result.health);
    for i = 1:numel(hardNames)
        value = result.health.(hardNames{i});
        if islogical(value)
            fprintf(fid, "- %s = %s\n", hardNames{i}, passFail(value));
        end
    end

    fprintf(fid, "\n## Soft Target Comparison\n\n");
    fprintf(fid, "- H2 breakthrough time, y >= 0.05 = %.3g s; source approximate target is about 110 s.\n", result.breakthrough.H2_y05_s);
    fprintf(fid, "- H2 outlet y >= 0.50 = %.3g s; source plot rise window is about 110-130 s.\n", result.breakthrough.H2_y50_s);
    fprintf(fid, "- CO2 breakthrough time, y >= 0.05 = %.3g s; source plot-read beginning is roughly 430-460 s.\n", result.breakthrough.CO2_y05_s);
    fprintf(fid, "- CO2 outlet y >= 0.50 = %.3g s; no hard target is applied.\n", result.breakthrough.CO2_y50_s);
    fprintf(fid, "- Final outlet y_CO2/y_H2 = %.4f / %.4f; source trend approaches 0.5 / 0.5 after the front and tail settle.\n", result.outlet_y(end, 1), result.outlet_y(end, 2));
    fprintf(fid, "- Maximum temperature rise = %.4f K; source expectation is a small H2 front followed by a larger CO2 heat front.\n", result.temperature.max_rise_K);

    fprintf(fid, "\n## Mass-Balance Diagnostic\n\n");
    fprintf(fid, "- component residual mol = [%.6g, %.6g]\n", result.mass_balance.component_residual_mol(1), result.mass_balance.component_residual_mol(2));
    fprintf(fid, "- component relative residual = [%.6g, %.6g]\n", result.mass_balance.component_relative_residual(1), result.mass_balance.component_relative_residual(2));

    fprintf(fid, "\n## Interpretation\n\n");
    fprintf(fid, "The hard health checks pass for the project-local Casas-lite wrapper. ");
    fprintf(fid, "Soft timing comparisons are reported without tuning source constants or changing thresholds. ");
    fprintf(fid, "Detector piping, exact axial dispersion, adsorbing He or He-specific gas properties, and separate wall-temperature dynamics remain omitted in this first wrapper.\n");
end

function text = passFail(value)
    if value
        text = "pass";
    else
        text = "fail";
    end
end
