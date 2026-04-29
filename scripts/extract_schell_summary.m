function summary = extract_schell_summary(scaffold, fullParams, sol, ...
    runConfig, runtimeSeconds, summaryPath, rawOutputPath, extractionMode)
%EXTRACT_SCHELL_SUMMARY Build schema-aligned Schell run summaries.
%
% This extractor reports numerical health, native stream accounting, and
% run limits. It does not tune or classify agreement with Schell targets;
% that belongs to the later soft-validation report task.

    if nargin < 8 || isempty(extractionMode)
        extractionMode = "central_css";
    else
        extractionMode = string(extractionMode);
    end

    health = collectHealthExtrema(fullParams, sol);
    cyclesCompleted = floor(sol.lastStep / fullParams.nSteps);
    cssResidual = finalCssResidual(sol, cyclesCompleted);
    cssReached = isfinite(cssResidual) && cssResidual < fullParams.numZero;
    lastCycle = max(1, min(cyclesCompleted, ...
        size(sol.perMet.productPurity, 1)));

    summary.schema_version = "0.1.0";
    summary.case_id = scaffold.case_id;
    summary.model_mode = scaffold.model_mode;
    summary.source_pack_sha256 = scaffold.source_pack_sha256;
    summary.parameter_pack = ...
        "params/schell2013_ap360_sips_binary/schell_2013_source_pack.json";
    summary.source_reference_file = ...
        "docs/source_reference/02_schell_2013_two_bed_psa_validation.md";
    summary.component_order.source = scaffold.params.component_order.source;
    summary.component_order.topsail_native = ...
        scaffold.params.component_order.topsail_native;

    summary.run.matlab_version = string(version);
    summary.run.cycles_requested = fullParams.nCycles;
    summary.run.cycles_completed = cyclesCompleted;
    summary.run.steps_completed = sol.lastStep;
    summary.run.grid_cells = fullParams.nVols;
    summary.run.time_points_per_step = fullParams.nTiPts;
    summary.run.cycle_duration_s = runConfig.cycle_duration_s;
    summary.run.runtime_s = runtimeSeconds;
    summary.run.css_metric_name = "toPSAil overall state L2";
    summary.run.css_residual = cssResidual;
    summary.run.css_tolerance = fullParams.numZero;
    summary.run.css_reached = cssReached;
    summary.run.accepted_cycle_cap = runConfig.accepted_cycle_cap;
    summary.run.stop_reason = stopReason(cssReached, cyclesCompleted, ...
        fullParams.nCycles);
    summary.run.thermal_mode = runConfig.thermal_mode;
    summary.run.native_pressure_flow_mode = ...
        runConfig.native_pressure_flow_mode;
    summary.run.equalization_mode = runConfig.equalization_mode;
    summary.run.source_adsorption_actual_flow_cm3_per_s = ...
        runConfig.source_adsorption_actual_flow_cm3_per_s;
    summary.run.source_purge_actual_flow_cm3_per_s = ...
        runConfig.source_purge_actual_flow_cm3_per_s;
    summary.run.topsail_native_adsorption_flow_target_cm3_per_s = ...
        runConfig.topsail_native_adsorption_flow_target_cm3_per_s;
    summary.run.topsail_native_adsorption_flow_observed_cm3_per_s = ...
        runConfig.topsail_native_adsorption_flow_observed_cm3_per_s;
    summary.run.topsail_native_flow_conversion_formula = ...
        runConfig.topsail_native_flow_conversion_formula;
    summary.run.pressurization_valve_relative_to_adsorption = ...
        runConfig.pressurization_valve_relative_to_adsorption;

    summary.hard_checks.matlab_completed = true;
    summary.hard_checks.requested_cycles_completed = ...
        cyclesCompleted >= fullParams.nCycles || cssReached;
    summary.hard_checks.no_nan_inf = health.all_finite;
    summary.hard_checks.positive_pressure = health.min_pressure_bar > 0;
    summary.hard_checks.positive_temperature = health.min_temperature_K > 0;
    summary.hard_checks.mole_fractions_valid = ...
        health.min_mole_fraction >= -1e-8 ...
        && health.max_mole_fraction <= 1 + 1e-8 ...
        && health.max_mole_fraction_sum_error <= 1e-8;
    summary.hard_checks.css_metric_reported = isfinite(cssResidual);
    summary.hard_checks.summary_json_emitted = false;

    summary.performance = extractPerformance(fullParams, sol, lastCycle, ...
        extractionMode);
    summary.temperature_profiles = collectTemperatureProfiles( ...
        fullParams, sol, scaffold.params.geometry ...
        .thermocouple_positions_m_from_bottom, health);
    summary.pressure_profiles = collectPressureProfiles(fullParams, sol, health);
    summary.stream_accounting = collectStreamAccounting(fullParams, sol, ...
        lastCycle);
    summary.flow_basis_diagnostics = collectFlowBasisDiagnostics( ...
        runConfig, summary.performance);

    summary.raw_outputs = [
        relativePath(summaryPath)
        relativePath(rawOutputPath)
    ];
    summary.warnings = buildWarnings(extractionMode, summary.run.stop_reason, ...
        runConfig);
end

function diagnostics = collectFlowBasisDiagnostics(runConfig, performance)
    expectedAdsorption = configField(runConfig, ...
        "expected_source_adsorption_moles_per_component_two_beds", []);
    observedAdsorption = [];
    if isfield(performance, "schell_si") ...
            && isfield(performance.schell_si, ...
                "adsorption_feed_input_moles_by_component")
        observedAdsorption = ...
            performance.schell_si.adsorption_feed_input_moles_by_component;
    end

    diagnostics.source_adsorption_actual_flow_cm3_per_s = configField( ...
        runConfig, "source_adsorption_actual_flow_cm3_per_s", []);
    diagnostics.topsail_native_adsorption_flow_target_cm3_per_s = ...
        configField(runConfig, ...
        "topsail_native_adsorption_flow_target_cm3_per_s", []);
    diagnostics.topsail_native_adsorption_flow_observed_cm3_per_s = ...
        configField(runConfig, ...
        "topsail_native_adsorption_flow_observed_cm3_per_s", []);
    diagnostics.topsail_native_flow_conversion_formula = configField( ...
        runConfig, "topsail_native_flow_conversion_formula", "");
    diagnostics.expected_source_adsorption_inventory_basis = ...
        configField(runConfig, ...
        "expected_source_adsorption_inventory_basis", "");
    diagnostics.expected_source_adsorption_moles_per_component_two_beds = ...
        expectedAdsorption;
    diagnostics.observed_last_cycle_schell_si_adsorption_moles_by_component = ...
        observedAdsorption;

    if ~isempty(expectedAdsorption) && ~isempty(observedAdsorption)
        diagnostics.observed_minus_expected_adsorption_moles_by_component = ...
            observedAdsorption - expectedAdsorption;
        diagnostics.observed_to_expected_adsorption_inventory_ratio = ...
            observedAdsorption ./ max(abs(expectedAdsorption), eps);
        oldExpected = expectedAdsorption ...
            .* runConfig.flow_basis_old_to_converted_factor;
        diagnostics.old_unconverted_target_expected_adsorption_moles_by_component = ...
            oldExpected;
        diagnostics.old_unconverted_target_observed_to_expected_ratio = ...
            observedAdsorption ./ max(abs(oldExpected), eps);
    else
        diagnostics.observed_minus_expected_adsorption_moles_by_component = [];
        diagnostics.observed_to_expected_adsorption_inventory_ratio = [];
        diagnostics.old_unconverted_target_expected_adsorption_moles_by_component = [];
        diagnostics.old_unconverted_target_observed_to_expected_ratio = [];
    end
end

function value = configField(config, fieldName, defaultValue)
    if isfield(config, fieldName)
        value = config.(fieldName);
    else
        value = defaultValue;
    end
end

function performance = extractPerformance(params, sol, lastCycle, ...
    extractionMode)

    performance.last_cycle_index = lastCycle;
    performance.extraction_mode = extractionMode;
    performance.native_direct = nativeDirectPerformance(sol, lastCycle, ...
        extractionMode);

    if extractionMode == "health"
        performance.schell_si = emptySchellSiPerformance(lastCycle);
    else
        performance.schell_si = extract_schell_si_performance(params, sol, ...
            lastCycle);
    end

    performance.h2_purity_pct = performance.native_direct.h2_purity_pct;
    performance.h2_recovery_pct = ...
        performance.native_direct.h2_recovery_pct;
    performance.co2_purity_pct = performance.native_direct.co2_purity_pct;
    performance.co2_recovery_pct = ...
        performance.native_direct.co2_recovery_pct;
    performance.classification = performance.native_direct.classification;
    performance.metrics_basis = performance.native_direct.metrics_basis;
    performance.legacy_field_note = ...
        "legacy flat performance fields mirror native_direct diagnostic metrics";
end

function native = nativeDirectPerformance(sol, lastCycle, extractionMode)
    native.metrics_role = "diagnostic_native_direct";
    native.last_cycle_index = lastCycle;
    native.extraction_mode = extractionMode;

    if extractionMode == "health"
        native.h2_purity_pct = missing;
        native.h2_recovery_pct = missing;
        native.co2_purity_pct = missing;
        native.co2_recovery_pct = missing;
        native.classification = "not_evaluated";
        native.metrics_basis = ...
            "health run diagnostics only; native direct performance is not evaluated";
        return
    end

    native.h2_purity_pct = safePct( ...
        sol.perMet.productPurity(lastCycle, 1));
    native.h2_recovery_pct = safePct( ...
        sol.perMet.productRecovery(lastCycle, 1));
    native.co2_purity_pct = safePct( ...
        sol.perMet.productPurity(lastCycle, 2));
    native.co2_recovery_pct = safePct( ...
        sol.perMet.productRecovery(lastCycle, 2));
    native.classification = "diagnostic_only";
    native.metrics_basis = ...
        "direct toPSAil native raffinate/extract external tank product metrics";
    native.validation_note = ...
        "diagnostic only; Schell SI reports CO2-rich product by subtraction";
end

function si = emptySchellSiPerformance(lastCycle)
    si.metrics_role = "validation_basis_candidate_schell_si";
    si.classification = "not_evaluated_health_run";
    si.metrics_basis = ...
        "health run diagnostics only; Schell SI subtraction accounting is not evaluated";
    si.validation_limitation = ...
        "Purge source uses native HP-ATM-FEE feed-tank inventory in runnable Schell adapter runs.";
    si.cycle_index = lastCycle;
    si.aggregate.h2_purity_pct = missing;
    si.aggregate.h2_recovery_pct = missing;
    si.aggregate.co2_purity_pct = missing;
    si.aggregate.co2_recovery_pct = missing;
end

function stream = collectStreamAccounting(params, sol, lastCycle)
    productRaff = sol.perMet.productMolesRaff(lastCycle, :);
    productExtr = sol.perMet.productMolesExtr(lastCycle, :);
    wasteRaff = sol.perMet.wasteMolesRaff(lastCycle, :);
    wasteExtr = sol.perMet.wasteMolesExtr(lastCycle, :);
    feed = getFeedMolCycle(params, sol, params.nSteps, lastCycle);
    outletTotal = productRaff + productExtr + wasteRaff + wasteExtr;
    residual = feed - outletTotal;

    stream.last_cycle_index = lastCycle;
    stream.component_order = string(params.sCom);
    stream.feed_moles = feed;
    stream.product_moles_raffinate = productRaff;
    stream.product_moles_extract = productExtr;
    stream.waste_moles_raffinate = wasteRaff;
    stream.waste_moles_extract = wasteExtr;
    stream.outlet_stream_moles = outletTotal;
    stream.feed_minus_outlet_stream_moles = residual;
    stream.feed_minus_outlet_stream_relative = residual ...
        ./ max(abs(feed), eps);
    stream.native_last_cycle_metrics.h2_purity_pct = safePct( ...
        sol.perMet.productPurity(lastCycle, 1));
    stream.native_last_cycle_metrics.h2_recovery_pct = safePct( ...
        sol.perMet.productRecovery(lastCycle, 1));
    stream.native_last_cycle_metrics.co2_purity_pct = safePct( ...
        sol.perMet.productPurity(lastCycle, 2));
    stream.native_last_cycle_metrics.co2_recovery_pct = safePct( ...
        sol.perMet.productRecovery(lastCycle, 2));
    stream.residual_note = ...
        "stream-only residual; bed/tank inventory change is not included";
end

function profiles = collectTemperatureProfiles(params, sol, positionsM, health)
    [indices, centersM] = nearestCellIndices(params, positionsM);
    finalStep = sol.("Step" + sol.lastStep);
    nCols = params.nCols;
    sampled = zeros(numel(indices), nCols);

    for j = 1:nCols
        colName = params.sColNums{j};
        tempsK = finalStep.col.(colName).temps.cstr(end, :) ...
            .* params.teScaleFac;
        sampled(:, j) = tempsK(indices).';
    end

    profiles.min_temperature_K = health.min_temperature_K;
    profiles.max_temperature_K = health.max_temperature_K;
    profiles.thermocouple_positions_m_from_bottom = positionsM(:).';
    profiles.nearest_cell_index = indices(:).';
    profiles.nearest_cell_center_m_from_bottom = centersM(:).';
    profiles.final_step_cstr_temperature_K_by_column = sampled;
    profiles.profile_basis = ...
        "nearest axial cell at final simulated step; isothermal modes are expected to be flat";
end

function profiles = collectPressureProfiles(params, sol, health)
    finalStep = sol.("Step" + sol.lastStep);
    finalPressures = zeros(params.nCols, 3);
    columnPressure = collectColumnPressureExtrema(params, sol);

    for j = 1:params.nCols
        colName = params.sColNums{j};
        pressureBar = pressureBarForUnit(params, finalStep.col.(colName));
        lastRow = pressureBar(end, :);
        finalPressures(j, :) = [min(lastRow), mean(lastRow), max(lastRow)];
    end

    profiles.min_pressure_bar = health.min_pressure_bar;
    profiles.max_pressure_bar = health.max_pressure_bar;
    profiles.column_min_pressure_bar = columnPressure.min_pressure_bar;
    profiles.column_max_pressure_bar = columnPressure.max_pressure_bar;
    profiles.pressure_extrema_basis = ...
        "min_pressure_bar and max_pressure_bar include tanks; column_* fields exclude tanks";
    profiles.final_step_column_pressure_bar_min_mean_max = finalPressures;
    profiles.equalization_step_end_pressure_bar = ...
        collectEqualizationEndPressures(params, sol);
    profiles.equalization_policy = ...
        "toPSAil native feed-end equalization; p_peq not prescribed";
end

function pressure = collectColumnPressureExtrema(params, sol)
    pressure.min_pressure_bar = inf;
    pressure.max_pressure_bar = -inf;
    for i = 1:sol.lastStep
        step = sol.("Step" + i);
        for j = 1:params.nCols
            colName = params.sColNums{j};
            pressureBar = pressureBarForUnit(params, step.col.(colName));
            pressure.min_pressure_bar = min(pressure.min_pressure_bar, ...
                min(pressureBar, [], "all"));
            pressure.max_pressure_bar = max(pressure.max_pressure_bar, ...
                max(pressureBar, [], "all"));
        end
    end
end

function records = collectEqualizationEndPressures(params, sol)
    records = struct("step", {}, "column", {}, "step_name", {}, ...
        "min_pressure_bar", {}, "mean_pressure_bar", {}, ...
        "max_pressure_bar", {});
    for i = 1:sol.lastStep
        step = sol.("Step" + i);
        for j = 1:params.nCols
            stepName = string(step.timeFlags{end, j});
            if startsWith(stepName, "EQ-")
                colName = params.sColNums{j};
                pressureBar = pressureBarForUnit(params, step.col.(colName));
                lastRow = pressureBar(end, :);
                record.step = i;
                record.column = j;
                record.step_name = stepName;
                record.min_pressure_bar = min(lastRow);
                record.mean_pressure_bar = mean(lastRow);
                record.max_pressure_bar = max(lastRow);
                records(end + 1, 1) = record; %#ok<AGROW>
            end
        end
    end
end

function [indices, centersM] = nearestCellIndices(params, positionsM)
    columnLengthM = params.heightCol / 100;
    cellCentersM = ((1:params.nVols) - 0.5) ...
        ./ params.nVols .* columnLengthM;
    indices = zeros(numel(positionsM), 1);
    centersM = zeros(numel(positionsM), 1);
    for i = 1:numel(positionsM)
        [~, idx] = min(abs(cellCentersM - positionsM(i)));
        indices(i) = idx;
        centersM(i) = cellCentersM(idx);
    end
end

function health = collectHealthExtrema(params, sol)
    health.min_pressure_bar = inf;
    health.max_pressure_bar = -inf;
    health.min_temperature_K = inf;
    health.max_temperature_K = -inf;
    health.min_mole_fraction = inf;
    health.max_mole_fraction = -inf;
    health.max_mole_fraction_sum_error = 0;
    health.all_finite = allFiniteNumeric(sol);

    for i = 1:sol.lastStep
        step = sol.("Step" + i);
        for j = 1:params.nCols
            colName = params.sColNums{j};
            health = updateGasHealth(health, params, step.col.(colName));
        end
        health = updateGasHealth(health, params, step.feTa.n1);
        health = updateGasHealth(health, params, step.raTa.n1);
        health = updateGasHealth(health, params, step.exTa.n1);
    end
end

function health = updateGasHealth(health, params, unit)
    gasTotal = unit.gasConsTot;
    tempNorm = unit.temps.cstr;
    pressureBar = pressureBarForUnit(params, unit);
    temperatureK = tempNorm .* params.teScaleFac;

    health.min_pressure_bar = min(health.min_pressure_bar, ...
        min(pressureBar, [], "all"));
    health.max_pressure_bar = max(health.max_pressure_bar, ...
        max(pressureBar, [], "all"));
    health.min_temperature_K = min(health.min_temperature_K, ...
        min(temperatureK, [], "all"));
    health.max_temperature_K = max(health.max_temperature_K, ...
        max(temperatureK, [], "all"));

    validRows = gasTotal > eps;
    moleFractionSum = zeros(size(gasTotal));
    for k = 1:params.nComs
        component = unit.gasCons.(params.sComNums{k});
        moleFraction = component(validRows) ./ gasTotal(validRows);
        if ~isempty(moleFraction)
            health.min_mole_fraction = min(health.min_mole_fraction, ...
                min(moleFraction, [], "all"));
            health.max_mole_fraction = max(health.max_mole_fraction, ...
                max(moleFraction, [], "all"));
        end
        moleFractionSum(validRows) = moleFractionSum(validRows) ...
            + component(validRows) ./ gasTotal(validRows);
    end

    if any(validRows, "all")
        sumError = abs(moleFractionSum(validRows) - 1);
        health.max_mole_fraction_sum_error = max( ...
            health.max_mole_fraction_sum_error, max(sumError, [], "all"));
    end
end

function pressureBar = pressureBarForUnit(params, unit)
    pressureBar = unit.gasConsTot .* unit.temps.cstr ...
        .* params.gasConsNormEq .* params.presColHigh;
end

function residual = finalCssResidual(sol, cyclesCompleted)
    residualIndex = min(numel(sol.css), max(1, cyclesCompleted + 1));
    residual = sol.css(residualIndex);
end

function reason = stopReason(cssReached, cyclesCompleted, cyclesRequested)
    if cssReached
        reason = "css_reached";
    elseif cyclesCompleted >= cyclesRequested
        reason = "cycle_cap_reached_without_css";
    else
        reason = "stopped_before_cycle_cap";
    end
end

function warnings = buildWarnings(extractionMode, stopReasonText, runConfig)
    if extractionMode == "health"
        firstWarning = ...
            "SCHELL-08 is a one-cycle health run, not CSS validation.";
        performanceWarning = ...
            "Health-run performance fields are null; metric labels are present under performance.native_direct and performance.schell_si.";
    else
        firstWarning = ...
            "SCHELL-09 is a bounded central CSS attempt, not a soft-validation report.";
        performanceWarning = ...
            "Performance includes native direct diagnostics and Schell SI subtraction-basis candidate metrics; candidate metrics are not final validation until soft-validation review is complete.";
    end

    warnings = [
        firstWarning
        performanceWarning
        "FLOW_BASIS remains an explicit source uncertainty."
        "P_PEQ remains unresolved; native equalization is used without prescribing p_peq."
        runConfig.pressurization_valve_basis
        runConfig.purge_valve_basis
        "Finite-wall thermal validation is deferred; this run uses an explicitly labelled isothermal mode."
        "Optional Schell Sips remains a likely runtime/stiffness amplifier based on reduced diagnostics."
        runConfig.purge_connection_note
    ];

    if stopReasonText == "cycle_cap_reached_without_css"
        warnings(end + 1, 1) = ...
            "Run reached the accepted cycle cap before native CSS convergence.";
    end
end

function value = safePct(fraction)
    if isnumeric(fraction) && isscalar(fraction) && isfinite(fraction)
        value = 100 * fraction;
    else
        value = missing;
    end
end

function ok = allFiniteNumeric(value)
    if isnumeric(value)
        ok = all(isfinite(value), "all");
    elseif isstruct(value)
        ok = true;
        fields = fieldnames(value);
        for i = 1:numel(fields)
            ok = ok && allFiniteNumeric(value.(fields{i}));
            if ~ok
                return;
            end
        end
    elseif iscell(value)
        ok = true;
        for i = 1:numel(value)
            ok = ok && allFiniteNumeric(value{i});
            if ~ok
                return;
            end
        end
    else
        ok = true;
    end
end

function pathText = relativePath(filePath)
    parts = split(string(filePath), filesep);
    repoIndex = find(parts == "validation", 1);
    if isempty(repoIndex)
        pathText = string(filePath);
    else
        pathText = strjoin(parts(repoIndex:end), "/");
    end
end
