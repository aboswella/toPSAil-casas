function [ledger, ledgerTable] = extract_schell_step_ledger(params, sol, runConfig)
%EXTRACT_SCHELL_STEP_LEDGER Build a per-step Schell diagnostic ledger.
%
% Failure mode caught: pressure-program or boundary-routing defects hidden by
% cycle-level product accounting.

    if nargin < 3 || isempty(runConfig)
        runConfig = struct();
    end

    components = string(params.sCom);
    records = struct([]);
    rows = struct([]);

    for globalStep = 1:sol.lastStep
        step = sol.("Step" + globalStep);
        cycleIndex = floor((globalStep - 1) / params.nSteps) + 1;
        cycleStepIndex = mod(globalStep - 1, params.nSteps) + 1;
        durationSeconds = params.durStep(cycleStepIndex);

        tankState = collectTankState(params, step);
        externalTransfers = collectExternalTransfers(params, step);

        for columnIndex = 1:params.nCols
            columnName = params.sColNums{columnIndex};
            stepName = string(step.timeFlags{end, columnIndex});
            column = step.col.(columnName);
            pressureBar = pressureBarForUnit(params, column);

            feedBoundary = column.cumMol.feed(end, :) .* params.nScaleFac;
            productBoundary = column.cumMol.prod(end, :) .* params.nScaleFac;

            record.global_step_index = globalStep;
            record.cycle_index = cycleIndex;
            record.cycle_step_index = cycleStepIndex;
            record.column = columnIndex;
            record.step_name = stepName;
            record.duration_s = durationSeconds;
            record.pressure_start_bar = mean(pressureBar(1, :));
            record.pressure_end_bar = mean(pressureBar(end, :));
            record.pressure_min_bar = min(pressureBar, [], "all");
            record.pressure_mean_bar = mean(pressureBar, "all");
            record.pressure_max_bar = max(pressureBar, [], "all");
            record.feed_end_boundary_moles = feedBoundary;
            record.product_end_boundary_moles = productBoundary;
            record.feed_tank_external_feed_moles = externalTransfers.feed;
            record.raffinate_external_product_moles = externalTransfers.raffinateProduct;
            record.extract_external_product_moles = externalTransfers.extractProduct;
            record.raffinate_waste_moles = externalTransfers.raffinateWaste;
            record.extract_waste_moles = externalTransfers.extractWaste;
            record.feed_tank = tankState.feed;
            record.raffinate_tank = tankState.raffinate;
            record.extract_tank = tankState.extract;

            records = appendRecord(records, record);
            rows = appendRecord(rows, flattenRecord(record, components));
        end
    end

    ledger.schema_version = "0.1.0";
    ledger.description = "Schell per-step pressure, boundary, and tank ledger";
    ledger.component_order = components;
    ledger.n_steps_completed = sol.lastStep;
    ledger.n_cycles_completed = floor(sol.lastStep / params.nSteps);
    ledger.source_p_high_bar = params.presColHigh;
    ledger.source_p_low_bar = params.presColLow;
    ledger.native_presFeTa_bar = params.presFeTa;
    ledger.records = records;

    if isfield(runConfig, "pressurization_valve_relative_to_adsorption")
        ledger.pressurization_valve_relative_to_adsorption = ...
            runConfig.pressurization_valve_relative_to_adsorption;
    end

    ledgerTable = struct2table(rows);
end

function records = appendRecord(records, record)
    if isempty(records)
        records = record;
    else
        records(end + 1, 1) = record;
    end
end

function row = flattenRecord(record, components)
    row.global_step_index = record.global_step_index;
    row.cycle_index = record.cycle_index;
    row.cycle_step_index = record.cycle_step_index;
    row.column = record.column;
    row.step_name = record.step_name;
    row.duration_s = record.duration_s;
    row.pressure_start_bar = record.pressure_start_bar;
    row.pressure_end_bar = record.pressure_end_bar;
    row.pressure_min_bar = record.pressure_min_bar;
    row.pressure_mean_bar = record.pressure_mean_bar;
    row.pressure_max_bar = record.pressure_max_bar;

    for k = 1:numel(components)
        suffix = matlab.lang.makeValidName(components(k));
        row.("feed_end_boundary_moles_" + suffix) = ...
            record.feed_end_boundary_moles(k);
        row.("product_end_boundary_moles_" + suffix) = ...
            record.product_end_boundary_moles(k);
        row.("feed_tank_external_feed_moles_" + suffix) = ...
            record.feed_tank_external_feed_moles(k);
        row.("raffinate_external_product_moles_" + suffix) = ...
            record.raffinate_external_product_moles(k);
        row.("extract_external_product_moles_" + suffix) = ...
            record.extract_external_product_moles(k);
        row.("raffinate_waste_moles_" + suffix) = ...
            record.raffinate_waste_moles(k);
        row.("extract_waste_moles_" + suffix) = ...
            record.extract_waste_moles(k);
    end

    row.feed_tank_pressure_start_bar = record.feed_tank.pressure_start_bar;
    row.feed_tank_pressure_end_bar = record.feed_tank.pressure_end_bar;
    row.raffinate_tank_pressure_start_bar = ...
        record.raffinate_tank.pressure_start_bar;
    row.raffinate_tank_pressure_end_bar = ...
        record.raffinate_tank.pressure_end_bar;
    row.extract_tank_pressure_start_bar = ...
        record.extract_tank.pressure_start_bar;
    row.extract_tank_pressure_end_bar = ...
        record.extract_tank.pressure_end_bar;
end

function tankState = collectTankState(params, step)
    tankState.feed = unitState(params, step.feTa.n1);
    tankState.raffinate = unitState(params, step.raTa.n1);
    tankState.extract = unitState(params, step.exTa.n1);
end

function state = unitState(params, unit)
    pressureBar = pressureBarForUnit(params, unit);
    yStart = moleFractions(params, unit, 1);
    yEnd = moleFractions(params, unit, size(unit.gasConsTot, 1));

    state.pressure_start_bar = pressureBar(1);
    state.pressure_end_bar = pressureBar(end);
    state.mole_fraction_start = yStart;
    state.mole_fraction_end = yEnd;
end

function transfers = collectExternalTransfers(params, step)
    transfers.feed = step.feTa.n1.cumMol.feed(end, :) .* params.nScaleFac;
    transfers.raffinateProduct = step.raTa.n1.cumMol.prod(end, :) ...
        .* params.nScaleFac;
    transfers.extractProduct = step.exTa.n1.cumMol.prod(end, :) ...
        .* params.nScaleFac;
    transfers.raffinateWaste = step.raWa.n1.cumMol.waste(end, :) ...
        .* params.nScaleFac;
    transfers.extractWaste = step.exWa.n1.cumMol.waste(end, :) ...
        .* params.nScaleFac;
end

function pressureBar = pressureBarForUnit(params, unit)
    pressureBar = unit.gasConsTot .* unit.temps.cstr ...
        .* params.gasConsNormEq .* params.presColHigh;
end

function y = moleFractions(params, unit, rowIndex)
    total = unit.gasConsTot(rowIndex, :);
    if numel(total) > 1
        total = mean(total);
    end

    y = zeros(1, params.nComs);
    if total <= eps
        y(:) = NaN;
        return
    end

    for k = 1:params.nComs
        component = unit.gasCons.(params.sComNums{k});
        value = component(rowIndex, :);
        y(k) = mean(value) / total;
    end
end
