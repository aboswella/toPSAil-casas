# Casas-Lite Breakthrough Validation Report

source_reference_file = docs/source_reference/01_casas_2012_breakthrough_validation.md

parameter_pack = params/casas2012_ap360_sips_binary

model_mode = topsail_native_wrapper

source_values_changed = no

validation_thresholds_changed = no

grid/cell count = 24

run time = 1.609 s

solver status = completed

known_omissions = detector piping, exact axial dispersion/front shape, adsorbing He or He gas-property model, separate wall-temperature state

flow_mapping = 10 cm3/s used directly as actual inlet volumetric flow in the Casas-lite wrapper

initial_gas_handling = He is a nonadsorbing void-gas state; adsorption remains binary CO2/H2

## Hard Checks

- no_nan = pass
- no_inf = pass
- positive_pressure = pass
- positive_temperature = pass
- valid_mole_fractions = pass
- mole_fraction_sum_sensible = pass
- nonnegative_loadings = pass
- co2_retention_relative_to_h2 = pass
- co2_loads_more_strongly = pass
- temperature_response_exists = pass
- flow_direction_sensible = pass
- mass_balance_reported = pass
- all_hard_pass = pass

## Soft Target Comparison

- H2 breakthrough time, y >= 0.05 = 55.2 s; source approximate target is about 110 s.
- H2 outlet y >= 0.50 = 56.8 s; source plot rise window is about 110-130 s.
- CO2 breakthrough time, y >= 0.05 = 433 s; source plot-read beginning is roughly 430-460 s.
- CO2 outlet y >= 0.50 = NaN s; no hard target is applied.
- Final outlet y_CO2/y_H2 = 0.4987 / 0.5013; source trend approaches 0.5 / 0.5 after the front and tail settle.
- Maximum temperature rise = 8.6299 K; source expectation is a small H2 front followed by a larger CO2 heat front.

## Mass-Balance Diagnostic

- component residual mol = [-3.49386e-07, -0.000197036]
- component relative residual = [-1.64974e-07, -9.30369e-05]

## Interpretation

The hard health checks pass for the project-local Casas-lite wrapper. Soft timing comparisons are reported without tuning source constants or changing thresholds. Detector piping, exact axial dispersion, adsorbing He or He-specific gas properties, and separate wall-temperature dynamics remain omitted in this first wrapper.
