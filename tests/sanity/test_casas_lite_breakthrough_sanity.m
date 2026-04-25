% Tier 3 one-column physical sanity checks.
% Failure mode caught: invalid inventories, mole fractions, or breakthrough order.

result = run_casas_lite_breakthrough_sanity();
p = load_casas2012_ap360_sips_binary();

assert(result.health.no_nan);
assert(result.health.no_inf);
assert(result.health.positive_pressure);
assert(result.health.positive_temperature);
assert(result.health.valid_mole_fractions);
assert(result.health.mole_fraction_sum_sensible);
assert(result.health.nonnegative_loadings);
assert(result.health.flow_direction_sensible);
assert(result.health.co2_loads_more_strongly);
assert(result.health.co2_retention_relative_to_h2);
assert(result.health.temperature_response_exists);
assert(result.health.mass_balance_reported);

assert(result.breakthrough.H2_y05_s > 0);
assert(isnan(result.breakthrough.CO2_y05_s) ...
    || result.breakthrough.H2_y05_s <= result.breakthrough.CO2_y05_s);
assert(result.reference_equilibrium_loading_mol_kg(p.component_order.CO2) ...
    > result.reference_equilibrium_loading_mol_kg(p.component_order.H2));

fprintf("Tier 3 Casas-lite physical sanity tests passed.\n");
