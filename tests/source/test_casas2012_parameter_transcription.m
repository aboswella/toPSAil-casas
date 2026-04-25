% Tier 1 source-transcription checks.
% Failure mode caught: Casas source values, units, or component order drift.

p = load_casas2012_ap360_sips_binary();

assert(p.source_reference_file == "docs/source_reference/01_casas_2012_breakthrough_validation.md");
assert(p.parameter_pack == "params/casas2012_ap360_sips_binary");
assert(p.model_mode == "topsail_native_wrapper");
assert(isequal(p.components, ["CO2", "H2"]));
assert(p.component_order.CO2 == 1);
assert(p.component_order.H2 == 2);

assertClose(p.geometry.L_m, 1.20, 0);
assertClose(p.geometry.Ri_m, 0.0125, 0);
assertClose(p.geometry.Ro_m, 0.020, 0);
assertClose(p.geometry.R0_m, 0.020, 0);
assertClose(p.adsorbent.eps_b, 0.403, 0);
assertClose(p.adsorbent.eps_t, 0.742, 0);
assertClose(p.adsorbent.rho_b_kg_m3, 507, 0);
assertClose(p.adsorbent.rho_p_kg_m3, 850, 0);
assertClose(p.adsorbent.dp_m, 0.003, 0);
assertClose(p.adsorbent.a_p_m2_m3, 8.5e8, 0);
assertClose(p.thermal.Cs_J_kg_K, 1000, 0);
assertClose(p.thermal.Cw_J_m3_K, 4.0e6, 0);
assertClose(p.gas.Dm_m2_s, 4.3e-6, 0);
assertClose(p.thermal.DeltaH_CO2_J_mol, -26000, 0);
assertClose(p.thermal.DeltaH_H2_J_mol, -9800, 0);
assertClose(p.kinetics.k_CO2_s, 0.15, 0);
assertClose(p.kinetics.k_H2_s, 1.0, 0);
assertClose(p.thermal.hW_J_m2_s_K, 5, 0);
assertClose(p.dispersion.gamma1, 0.7, 0);
assertClose(p.dispersion.gamma2, 0.5, 0);

assertClose(p.operating.feed_y, [0.5, 0.5], 0);
assertClose(sum(p.operating.feed_y), 1, 10 * eps);
assertClose(p.operating.T_feed_K, 298.15, 0);
assertClose(p.operating.P_feed_bar, 15, 0);
assertClose(p.operating.P_feed_Pa, 15e5, 0);
assertClose(p.operating.feed_flow_cm3_s, 10, 0);
assertClose(p.operating.feed_flow_m3_s, 10e-6, 1e-15);
assert(p.operating.initial_gas == "He");
assert(p.operating.P_feed_Pa > 0);
assert(p.operating.T_feed_K > 0);

assertClose(p.isotherm.omega_mol_kg, [1.38, 6.66], 0);
assertClose(p.isotherm.theta_J_mol, [-5628, 0], 0);
assertClose(p.isotherm.Omega_1_Pa, [16.80e-9, 0.70e-9], 0);
assertClose(p.isotherm.Theta_J_mol, [-9159, -9826], 0);
assertClose(p.isotherm.s1, [0.072, 0], 0);
assertClose(p.isotherm.s2_1_K, [0.106, 0], 0);
assertClose(p.isotherm.sref, [0.827, 0.9556], 0);
assertClose(p.isotherm.Tref_K, [329, 273], 0);

assert(~p.isotherm.langmuir_optional.used_by_default);
assert(~p.approximations.detector_piping_enabled);
assert(~p.approximations.axial_dispersion_enabled);
assert(p.thermal.DeltaH_CO2_J_mol == -26000);
assert(p.thermal.DeltaH_CO2_J_mol ~= -21000);
assert(p.initial.gas == "He");

assert(isfield(p.units, "geometry"));
assert(isfield(p.units, "pressure"));
assert(isfield(p.units, "temperature"));
assert(isfield(p.units, "feed_flow"));
assert(isfield(p.units, "loading"));

fprintf("Tier 1 Casas source-transcription tests passed.\n");

function assertClose(actual, expected, tol)
    if tol == 0
        assert(isequal(actual, expected), "Expected exact equality.");
    else
        assert(all(abs(actual - expected) <= tol, "all"), "Values differ beyond tolerance.");
    end
end
