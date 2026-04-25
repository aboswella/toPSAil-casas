function result = simulate_casas_lite_breakthrough(c)
%SIMULATE_CASAS_LITE_BREAKTHROUGH Run the Casas-lite one-column wrapper.

    p = c.parameter_pack;
    nCells = c.grid.n_cells;
    nComps = numel(p.components);
    nGasComps = nComps + 1;
    inertIndex = nGasComps;
    nGas = nCells * nGasComps;
    nAds = nCells * nComps;

    R = 8.31446261815324;
    cTotFeed = p.operating.P_feed_Pa / (R * p.operating.T_feed_K);

    gas0 = zeros(nCells, nGasComps);
    gas0(:, inertIndex) = cTotFeed;
    ads0 = zeros(nCells, nComps);
    temp0 = p.operating.T_feed_K * ones(nCells, 1);
    x0 = [gas0(:); ads0(:); temp0(:)];

    options = odeset( ...
        "RelTol", c.solver.relative_tolerance, ...
        "AbsTol", c.solver.absolute_tolerance, ...
        "MaxStep", c.solver.max_step_s, ...
        "NonNegative", 1:numel(x0));

    rhs = @(t, x) casasLiteRhs(t, x, c);
    [time_s, states] = ode15s(rhs, c.time.output_time_s, x0, options);

    [gasConcAll, adsLoading, temperatureK] = unpackStates(states, nCells, nComps, nGasComps);

    gasConc = gasConcAll(:, :, 1:nComps);
    inertConc = gasConcAll(:, :, inertIndex);
    totalGasConc = max(sum(gasConcAll, 3), eps);
    moleFrac = max(gasConc ./ totalGasConc, 0);
    inertMoleFrac = max(inertConc ./ totalGasConc, 0);

    outlet_y = squeeze(moleFrac(:, nCells, :));
    if isvector(outlet_y)
        outlet_y = reshape(outlet_y, [], nComps);
    end
    outlet_y_sum = sum(outlet_y, 2);
    outlet_inert_y = inertMoleFrac(:, nCells);

    result = struct();
    result.case_name = c.case_name;
    result.source_reference_file = p.source_reference_file;
    result.parameter_pack = p.parameter_pack;
    result.model_mode = c.model_mode;
    result.known_omissions = [ ...
        "detector piping", ...
        "exact axial dispersion/front shape", ...
        "adsorbing He or He gas-property model", ...
        "separate wall-temperature state"];
    result.time_s = time_s;
    result.z_m = c.grid.z_m;
    result.components = p.components;
    result.inert_component = "He";
    result.gas_concentration_all_mol_m3 = gasConcAll;
    result.gas_concentration_mol_m3 = gasConc;
    result.gas_mole_fraction = moleFrac;
    result.inert_concentration_mol_m3 = inertConc;
    result.inert_mole_fraction = inertMoleFrac;
    result.adsorbed_loading_mol_kg = adsLoading;
    result.temperature_K = temperatureK;
    result.wall_temperature_K = temperatureK;
    result.outlet_y = outlet_y;
    result.outlet_y_sum = outlet_y_sum;
    result.outlet_inert_y = outlet_inert_y;
    result.outlet_untracked_inert_y = outlet_inert_y;
    result.grid_cells = nCells;
    result.solver_status = "completed";
    result.flow_mapping = c.flow.mapping;
    result.initial_gas_handling = p.initial.approximation;

    result.breakthrough.H2_y05_s = firstCrossing(time_s, outlet_y(:, p.component_order.H2), 0.05);
    result.breakthrough.H2_y50_s = firstCrossing(time_s, outlet_y(:, p.component_order.H2), 0.50);
    result.breakthrough.CO2_y05_s = firstCrossing(time_s, outlet_y(:, p.component_order.CO2), 0.05);
    result.breakthrough.CO2_y50_s = firstCrossing(time_s, outlet_y(:, p.component_order.CO2), 0.50);

    result.temperature.max_K = max(temperatureK, [], "all");
    result.temperature.max_rise_K = result.temperature.max_K - p.operating.T_feed_K;
    result.temperature.outlet_K = temperatureK(:, end);

    result.mass_balance = computeMassBalance(c, result);
    result.reference_equilibrium_loading_mol_kg = eval_casas2012_sips( ...
        p, p.operating.P_feed_Pa .* p.operating.feed_y, p.operating.T_feed_K);
    result.health = evaluateHealth(c, result);
end

function dxdt = casasLiteRhs(~, x, c)
    p = c.parameter_pack;
    nCells = c.grid.n_cells;
    nComps = numel(p.components);
    nGasComps = nComps + 1;
    inertIndex = nGasComps;
    nGas = nCells * nGasComps;
    nAds = nCells * nComps;

    gasConcAll = reshape(x(1:nGas), nCells, nGasComps);
    gasConc = gasConcAll(:, 1:nComps);
    adsLoading = reshape(x(nGas + 1:nGas + nAds), nCells, nComps);
    temperatureK = x(nGas + nAds + 1:end);

    pressurePa = p.operating.P_feed_Pa;
    temperatureSafe = max(temperatureK, 1);
    totalGasConc = max(sum(gasConcAll, 2), eps);
    moleFrac = max(gasConc ./ totalGasConc, 0);
    partialPressurePa = pressurePa .* moleFrac;

    qStar = eval_casas2012_sips(p, partialPressurePa, temperatureSafe);
    dqdt = eval_casas2012_ldf(p, adsLoading, qStar);

    R = 8.31446261815324;
    cTotFeed = pressurePa / (R * p.operating.T_feed_K);
    feedConc = p.operating.feed_y .* cTotFeed;

    dGasdt = zeros(nCells, nGasComps);
    for j = 1:nComps
        upstream = [feedConc(j); gasConcAll(1:end - 1, j)];
        dGasdt(:, j) = -c.flow.interstitial_velocity_m_s ...
                     .* (gasConcAll(:, j) - upstream) ./ c.grid.dz_m ...
                     - (p.adsorbent.rho_b_kg_m3 / p.adsorbent.eps_b) ...
                     .* dqdt(:, j);
    end

    upstreamInert = [0; gasConcAll(1:end - 1, inertIndex)];
    dGasdt(:, inertIndex) = -c.flow.interstitial_velocity_m_s ...
                          .* (gasConcAll(:, inertIndex) - upstreamInert) ...
                          ./ c.grid.dz_m;

    heatRelease_J_m3_s = p.adsorbent.rho_b_kg_m3 ...
        .* sum((-p.thermal.DeltaH_J_mol) .* dqdt, 2);
    heatLoss_J_m3_s = p.thermal.hW_J_m2_s_K ...
        .* c.thermal.heat_transfer_area_per_bed_volume_1_m ...
        .* (temperatureK - c.thermal.ambient_temperature_K);
    dTdt = (heatRelease_J_m3_s - heatLoss_J_m3_s) ...
         ./ c.thermal.effective_heat_capacity_J_m3_K;

    dxdt = [dGasdt(:); dqdt(:); dTdt(:)];
end

function [gasConcAll, adsLoading, temperatureK] = unpackStates(states, nCells, nComps, nGasComps)
    nTimes = size(states, 1);
    nGas = nCells * nGasComps;
    nAds = nCells * nComps;

    gasConcAll = zeros(nTimes, nCells, nGasComps);
    adsLoading = zeros(nTimes, nCells, nComps);
    temperatureK = zeros(nTimes, nCells);

    for i = 1:nTimes
        gasConcAll(i, :, :) = reshape(states(i, 1:nGas), nCells, nGasComps);
        adsLoading(i, :, :) = reshape(states(i, nGas + 1:nGas + nAds), nCells, nComps);
        temperatureK(i, :) = states(i, nGas + nAds + 1:end);
    end
end

function tBreak = firstCrossing(time_s, values, threshold)
    idx = find(values >= threshold, 1, "first");
    if isempty(idx)
        tBreak = NaN;
    elseif idx == 1
        tBreak = time_s(1);
    else
        t0 = time_s(idx - 1);
        t1 = time_s(idx);
        y0 = values(idx - 1);
        y1 = values(idx);
        if abs(y1 - y0) < eps
            tBreak = t1;
        else
            tBreak = t0 + (threshold - y0) * (t1 - t0) / (y1 - y0);
        end
    end
end

function mb = computeMassBalance(c, result)
    p = c.parameter_pack;
    R = 8.31446261815324;
    nComps = numel(p.components);
    t = result.time_s;
    area = c.geometry.cross_section_area_m2;
    dz = c.grid.dz_m;
    qVol = c.flow.feed_flow_m3_s;
    cTotFeed = p.operating.P_feed_Pa / (R * p.operating.T_feed_K);
    feedConc = p.operating.feed_y .* cTotFeed;

    mb = struct();
    mb.component_mol_in = qVol .* feedConc .* t(end);
    mb.component_mol_out = zeros(1, nComps);
    mb.component_mol_gas_final = zeros(1, nComps);
    mb.component_mol_ads_final = zeros(1, nComps);

    for j = 1:nComps
        outletConc = squeeze(result.gas_concentration_mol_m3(:, end, j));
        mb.component_mol_out(j) = trapz(t, qVol .* outletConc);
        mb.component_mol_gas_final(j) = p.adsorbent.eps_b * area * dz ...
            * sum(squeeze(result.gas_concentration_mol_m3(end, :, j)));
        mb.component_mol_ads_final(j) = p.adsorbent.rho_b_kg_m3 * area * dz ...
            * sum(squeeze(result.adsorbed_loading_mol_kg(end, :, j)));
    end

    mb.component_residual_mol = mb.component_mol_in ...
                              - mb.component_mol_out ...
                              - mb.component_mol_gas_final ...
                              - mb.component_mol_ads_final;
    mb.component_relative_residual = mb.component_residual_mol ...
        ./ max(mb.component_mol_in, eps);
end

function health = evaluateHealth(c, result)
    p = c.parameter_pack;
    tol = 1e-7;
    trackedSum = sum(result.gas_mole_fraction, 3);
    refQ = result.reference_equilibrium_loading_mol_kg;

    health = struct();
    health.no_nan = ~any(isnan(result.outlet_y), "all") ...
                 && ~any(isnan(result.temperature_K), "all") ...
                 && ~any(isnan(result.adsorbed_loading_mol_kg), "all");
    health.no_inf = ~any(isinf(result.outlet_y), "all") ...
                 && ~any(isinf(result.temperature_K), "all") ...
                 && ~any(isinf(result.adsorbed_loading_mol_kg), "all");
    health.positive_pressure = p.operating.P_feed_Pa > 0;
    health.positive_temperature = all(result.temperature_K > 0, "all");
    health.valid_mole_fractions = all(result.gas_mole_fraction >= -tol, "all") ...
        && all(result.gas_mole_fraction <= 1 + tol, "all") ...
        && all(result.inert_mole_fraction >= -tol, "all") ...
        && all(result.inert_mole_fraction <= 1 + tol, "all") ...
        && all(trackedSum <= 1 + 5e-4, "all");
    health.mole_fraction_sum_sensible = all(result.outlet_y_sum <= 1 + 5e-4) ...
        && all(result.outlet_y_sum >= -tol);
    health.nonnegative_loadings = all(result.adsorbed_loading_mol_kg >= -tol, "all");
    health.co2_retention_relative_to_h2 = ...
        result.outlet_y(end, p.component_order.H2) >= result.outlet_y(end, p.component_order.CO2) ...
        || result.breakthrough.H2_y05_s <= result.breakthrough.CO2_y05_s;
    health.co2_loads_more_strongly = refQ(p.component_order.CO2) > refQ(p.component_order.H2);
    health.temperature_response_exists = result.temperature.max_rise_K > 0;
    health.flow_direction_sensible = c.flow.superficial_velocity_m_s > 0;
    health.mass_balance_reported = isfield(result, "mass_balance");

    health.all_hard_pass = health.no_nan ...
        && health.no_inf ...
        && health.positive_pressure ...
        && health.positive_temperature ...
        && health.valid_mole_fractions ...
        && health.mole_fraction_sum_sensible ...
        && health.nonnegative_loadings ...
        && health.co2_retention_relative_to_h2 ...
        && health.co2_loads_more_strongly ...
        && health.temperature_response_exists ...
        && health.flow_direction_sensible;
end
