% Plot SCHELL-09 central run outputs for human inspection.
% This is a reporting helper only; it does not alter model inputs, metrics,
% validation thresholds, or source-derived values.

plotSchellCentralOutputs();

function plotSchellCentralOutputs()
    scriptDir = fileparts(mfilename("fullpath"));
    repoRoot = fileparts(scriptDir);
    reportDir = fullfile(repoRoot, "validation", "reports", ...
        "schell_2013", "central");
    rawPath = fullfile(reportDir, "raw.mat");
    plotDir = fullfile(reportDir, "plots");

    if ~isfile(rawPath)
        error("plot_schell_central_outputs:missingRaw", ...
            "Missing SCHELL-09 raw output: %s", rawPath);
    end
    if ~isfolder(plotDir)
        mkdir(plotDir);
    end

    raw = load(rawPath, "sol");
    sol = raw.sol;
    [~, fullParams, ~, scaffold] = build_schell_runnable_params( ...
        "schell_20bar_tads40_performance_central", 5, ...
        struct("thermal_mode", "isothermal_bounded_css_attempt"));

    timeSeries = collectTimeSeries(fullParams, sol);
    finalProfiles = collectFinalProfiles(fullParams, sol, scaffold);

    makeOverviewPlot(plotDir, fullParams, sol, timeSeries, finalProfiles);
    makeCssPlot(plotDir, sol);
    makePerformancePlot(plotDir, sol);
    makePressureTrajectoryPlot(plotDir, fullParams, timeSeries);
    makeFinalProfilePlot(plotDir, finalProfiles);

    fprintf("Schell central plots written to %s\n", plotDir);
end

function makeOverviewPlot(plotDir, params, sol, timeSeries, finalProfiles)
    fig = newFigure([100, 100, 1200, 800]);
    layout = tiledlayout(fig, 2, 2, "TileSpacing", "compact", ...
        "Padding", "compact");
    layoutTitle = title(layout, ...
        "Schell 2013 Central Run: SCHELL-09 Native Output", ...
        "Interpreter", "none");
    layoutTitle.Color = "k";

    nexttile(layout);
    plotCss(sol);

    nexttile(layout);
    plotPerformance(sol);

    nexttile(layout);
    plotPressureTrajectory(params, timeSeries);

    nexttile(layout);
    plotFinalTemperatureProfile(finalProfiles);

    savePlot(fig, plotDir, "overview");
end

function makeCssPlot(plotDir, sol)
    fig = newFigure([100, 100, 900, 550]);
    plotCss(sol);
    savePlot(fig, plotDir, "css_convergence");
end

function makePerformancePlot(plotDir, sol)
    fig = newFigure([100, 100, 900, 550]);
    plotPerformance(sol);
    savePlot(fig, plotDir, "native_performance_by_cycle");
end

function makePressureTrajectoryPlot(plotDir, params, timeSeries)
    fig = newFigure([100, 100, 950, 550]);
    plotPressureTrajectory(params, timeSeries);
    savePlot(fig, plotDir, "column_mean_pressure_trajectory");
end

function makeFinalProfilePlot(plotDir, finalProfiles)
    fig = newFigure([100, 100, 1050, 500]);
    layout = tiledlayout(fig, 1, 2, "TileSpacing", "compact", ...
        "Padding", "compact");

    nexttile(layout);
    plotFinalPressureProfile(finalProfiles);

    nexttile(layout);
    plotFinalTemperatureProfile(finalProfiles);

    savePlot(fig, plotDir, "final_column_profiles");
end

function plotCss(sol)
    cyclesCompleted = floor(sol.lastStep / 10);
    cycleNums = 1:cyclesCompleted;
    cssAfterCycle = sol.css(2:cyclesCompleted + 1);
    semilogy(cycleNums, cssAfterCycle, "-o", "LineWidth", 1.5);
    grid on;
    xlabel("Cycle");
    ylabel("CSS residual");
    title("Native CSS Convergence");
    styleAxes(gca);
end

function plotPerformance(sol)
    cycles = 1:size(sol.perMet.productPurity, 1);
    h2Purity = 100 .* sol.perMet.productPurity(:, 1);
    h2Recovery = 100 .* sol.perMet.productRecovery(:, 1);
    co2Purity = 100 .* sol.perMet.productPurity(:, 2);
    co2Recovery = 100 .* sol.perMet.productRecovery(:, 2);

    plot(cycles, h2Purity, "-o", "LineWidth", 1.3); hold on;
    plot(cycles, h2Recovery, "-o", "LineWidth", 1.3);
    plot(cycles, co2Purity, "-s", "LineWidth", 1.3);
    plot(cycles, co2Recovery, "-s", "LineWidth", 1.3);
    hold off;
    grid on;
    xlabel("Cycle");
    ylabel("Percent");
    title("Direct Native Metrics (Not Yet Schell-Validated)");
    legend(["H2 purity", "H2 recovery", "CO2 purity", "CO2 recovery"], ...
        "Location", "best");
    styleAxes(gca);
end

function plotPressureTrajectory(params, timeSeries)
    plot(timeSeries.time_s, timeSeries.pressure_mean_bar(:, 1), ...
        "LineWidth", 1.2); hold on;
    plot(timeSeries.time_s, timeSeries.pressure_mean_bar(:, 2), ...
        "LineWidth", 1.2);
    lowLine = yline(params.presColLow, "--", "p low", ...
        "LabelHorizontalAlignment", "left");
    highLine = yline(params.presColHigh, "--", "p high", ...
        "LabelHorizontalAlignment", "left");
    lowLine.Color = [0.45, 0.45, 0.45];
    highLine.Color = [0.45, 0.45, 0.45];
    hold off;
    grid on;
    xlabel("Time (s)");
    ylabel("Column mean pressure (bar)");
    title("Column Mean Pressure Trajectory");
    legend(["Column 1", "Column 2"], "Location", "best");
    styleAxes(gca);
end

function plotFinalPressureProfile(finalProfiles)
    plot(finalProfiles.z_m, finalProfiles.pressure_bar(:, 1), ...
        "LineWidth", 1.4); hold on;
    plot(finalProfiles.z_m, finalProfiles.pressure_bar(:, 2), ...
        "LineWidth", 1.4);
    hold off;
    grid on;
    xlabel("Axial position from bottom (m)");
    ylabel("Pressure (bar)");
    title("Final-Step Pressure Profile");
    legend(["Column 1", "Column 2"], "Location", "best");
    styleAxes(gca);
end

function plotFinalTemperatureProfile(finalProfiles)
    plot(finalProfiles.z_m, finalProfiles.temperature_K(:, 1), ...
        "LineWidth", 1.4); hold on;
    plot(finalProfiles.z_m, finalProfiles.temperature_K(:, 2), ...
        "LineWidth", 1.4);
    firstTc = xline(finalProfiles.thermocouple_positions_m(1), ":", ...
        "Thermocouples", "LabelOrientation", "horizontal", ...
        "LabelVerticalAlignment", "bottom");
    firstTc.Color = [0.45, 0.45, 0.45];
    for i = 2:numel(finalProfiles.thermocouple_positions_m)
        tcLine = xline(finalProfiles.thermocouple_positions_m(i), ":");
        tcLine.Color = [0.45, 0.45, 0.45];
    end
    hold off;
    grid on;
    xlabel("Axial position from bottom (m)");
    ylabel("Temperature (K)");
    title("Final-Step Temperature Profile");
    legend(["Column 1", "Column 2"], "Location", "best");
    styleAxes(gca);
end

function timeSeries = collectTimeSeries(params, sol)
    totalRows = 0;
    for i = 1:sol.lastStep
        totalRows = totalRows + numel(sol.("Step" + i).timePts);
    end

    timeSeries.time_s = zeros(totalRows, 1);
    timeSeries.pressure_mean_bar = zeros(totalRows, params.nCols);
    row0 = 1;

    for i = 1:sol.lastStep
        step = sol.("Step" + i);
        rowCount = numel(step.timePts);
        rows = row0:(row0 + rowCount - 1);
        timeSeries.time_s(rows) = step.timePts(:) .* params.tiScaleFac;

        for j = 1:params.nCols
            colName = params.sColNums{j};
            pressureBar = pressureBarForUnit(params, step.col.(colName));
            timeSeries.pressure_mean_bar(rows, j) = mean(pressureBar, 2);
        end

        row0 = row0 + rowCount;
    end
end

function finalProfiles = collectFinalProfiles(params, sol, scaffold)
    finalStep = sol.("Step" + sol.lastStep);
    finalProfiles.z_m = ((1:params.nVols).' - 0.5) ...
        ./ params.nVols .* (params.heightCol / 100);
    finalProfiles.pressure_bar = zeros(params.nVols, params.nCols);
    finalProfiles.temperature_K = zeros(params.nVols, params.nCols);
    finalProfiles.thermocouple_positions_m = scaffold.params.geometry ...
        .thermocouple_positions_m_from_bottom(:).';

    for j = 1:params.nCols
        colName = params.sColNums{j};
        unit = finalStep.col.(colName);
        pressureBar = pressureBarForUnit(params, unit);
        finalProfiles.pressure_bar(:, j) = pressureBar(end, :).';
        finalProfiles.temperature_K(:, j) = unit.temps.cstr(end, :).' ...
            .* params.teScaleFac;
    end
end

function pressureBar = pressureBarForUnit(params, unit)
    pressureBar = unit.gasConsTot .* unit.temps.cstr ...
        .* params.gasConsNormEq .* params.presColHigh;
end

function fig = newFigure(position)
    fig = figure("Visible", "off", "Color", "w", "Position", position);
    set(fig, "DefaultAxesColor", "w", ...
        "DefaultAxesXColor", "k", ...
        "DefaultAxesYColor", "k", ...
        "DefaultAxesZColor", "k", ...
        "DefaultTextColor", "k", ...
        "DefaultLegendTextColor", "k", ...
        "DefaultLegendColor", "w", ...
        "DefaultLegendEdgeColor", [0.35, 0.35, 0.35]);
end

function styleAxes(ax)
    ax.Color = "w";
    ax.XColor = "k";
    ax.YColor = "k";
    ax.GridColor = [0.75, 0.75, 0.75];
    ax.MinorGridColor = [0.86, 0.86, 0.86];
    ax.Title.Color = "k";
    ax.XLabel.Color = "k";
    ax.YLabel.Color = "k";
    legends = findobj(ancestor(ax, "figure"), "Type", "Legend");
    for i = 1:numel(legends)
        legends(i).Color = "w";
        legends(i).TextColor = "k";
        legends(i).EdgeColor = [0.35, 0.35, 0.35];
    end
end

function savePlot(fig, plotDir, baseName)
    pngPath = fullfile(plotDir, baseName + ".png");
    figPath = fullfile(plotDir, baseName + ".fig");
    exportgraphics(fig, pngPath, "Resolution", 160);
    savefig(fig, figPath);
    close(fig);
end
