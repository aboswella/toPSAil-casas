function p = load_casas2012_ap360_sips_binary()
%LOAD_CASAS2012_AP360_SIPS_BINARY Source-transcribed Casas AP3-60 pack.

    p = struct();

    p.source_reference_file = "docs/source_reference/01_casas_2012_breakthrough_validation.md";
    p.audit_reference_file = "docs/source_reference/05_transcription_audit_and_guardrails.md";
    p.parameter_pack = "params/casas2012_ap360_sips_binary";
    p.model_mode_requested = "topsail_native";
    p.model_mode = "topsail_native_wrapper";
    p.source_values_changed = false;
    p.validation_thresholds_changed = false;

    p.components = ["CO2", "H2"];
    p.component_order.CO2 = 1;
    p.component_order.H2 = 2;

    p.geometry.L_m = 1.20;
    p.geometry.Ri_m = 0.0125;
    p.geometry.Ro_m = 0.020;
    p.geometry.R0_m = p.geometry.Ro_m;
    p.geometry.thermocouple_z_m = [0.10, 0.35, 0.60, 0.85, 1.10];

    p.adsorbent.name = "AP3-60 activated carbon";
    p.adsorbent.eps_b = 0.403;
    p.adsorbent.eps_t = 0.742;
    p.adsorbent.rho_b_kg_m3 = 507;
    p.adsorbent.rho_p_kg_m3 = 850;
    p.adsorbent.dp_m = 0.003;
    p.adsorbent.a_p_m2_m3 = 8.5e8;
    p.adsorbent.skeletal_density_g_cm3 = 1.97;

    p.gas.Dm_m2_s = 4.3e-6;

    p.thermal.Cs_J_kg_K = 1000;
    p.thermal.Cw_J_m3_K = 4.0e6;
    p.thermal.DeltaH_J_mol = [-26000, -9800];
    p.thermal.DeltaH_CO2_J_mol = p.thermal.DeltaH_J_mol(1);
    p.thermal.DeltaH_H2_J_mol = p.thermal.DeltaH_J_mol(2);
    p.thermal.hW_J_m2_s_K = 5;
    p.thermal.mode = "finite_wall_lumped_project_wrapper";

    p.kinetics.k_LDF_s = [0.15, 1.0];
    p.kinetics.k_CO2_s = p.kinetics.k_LDF_s(1);
    p.kinetics.k_H2_s = p.kinetics.k_LDF_s(2);
    p.kinetics.parameter_set = "fitted_to_reference_experiment";

    p.dispersion.D_L_correlation = "D_L = gamma1 * D_m + gamma2 * dp * u / eps";
    p.dispersion.gamma1 = 0.7;
    p.dispersion.gamma2 = 0.5;
    p.dispersion.active_by_default = false;

    p.isotherm.model = "competitive_sips";
    p.isotherm.pressure_unit = "Pa";
    p.isotherm.temperature_unit = "K";
    p.isotherm.loading_unit = "mol/kg";
    p.isotherm.omega_mol_kg = [1.38, 6.66];
    p.isotherm.theta_J_mol = [-5628, 0];
    p.isotherm.Omega_1_Pa = [16.80e-9, 0.70e-9];
    p.isotherm.Theta_J_mol = [-9159, -9826];
    p.isotherm.s1 = [0.072, 0];
    p.isotherm.s2_1_K = [0.106, 0];
    p.isotherm.sref = [0.827, 0.9556];
    p.isotherm.Tref_K = [329, 273];

    p.isotherm.langmuir_optional.used_by_default = false;
    p.isotherm.langmuir_optional.omega_mol_kg = [2.07, 5.35];
    p.isotherm.langmuir_optional.theta_J_mol = [-4174, 0];
    p.isotherm.langmuir_optional.Omega_1_Pa = [5.59e-9, 0.88e-9];
    p.isotherm.langmuir_optional.Theta_J_mol = [-13133, -10162];

    p.operating.feed_y = [0.5, 0.5];
    p.operating.T_feed_K = 298.15;
    p.operating.P_feed_bar = 15;
    p.operating.P_feed_Pa = p.operating.P_feed_bar * 1e5;
    p.operating.feed_flow_cm3_s = 10;
    p.operating.feed_flow_m3_s = p.operating.feed_flow_cm3_s * 1e-6;
    p.operating.initial_gas = "He";
    p.operating.regeneration_context = "vacuum 45 min; not a default simulation boundary";

    p.initial.gas = "He";
    p.initial.tracked_binary_y = [0, 0];
    p.initial.approximation = "He is a nonadsorbing void-gas state; adsorption remains binary CO2/H2";

    p.validation.targets.H2_breakthrough_time_s_approx = 110;
    p.validation.targets.H2_outlet_rise_window_s = [110, 130];
    p.validation.targets.CO2_breakthrough_window_s_plot_read = [430, 460];
    p.validation.targets.final_outlet_y = [0.5, 0.5];
    p.validation.targets.thermocouple_z_m = p.geometry.thermocouple_z_m;
    p.validation.targets.temperature_front_order = "small H2 front first, larger CO2 front later";

    p.approximations.flow_mapping = "10 cm3/s used directly as actual inlet volumetric flow in the Casas-lite wrapper";
    p.approximations.initial_gas = p.initial.approximation;
    p.approximations.detector_piping_enabled = false;
    p.approximations.axial_dispersion_enabled = false;
    p.approximations.wall_model = "simplified finite wall lump using hW and Cw";
    p.approximations.custom_isotherm_reason = "toPSAil custom isotherm path raises an unsupported-model error, so exact Casas Sips is project-local";

    p.units.geometry = "m";
    p.units.pressure = "bar and Pa fields are both explicit";
    p.units.temperature = "K";
    p.units.feed_flow = "cm3/s source value, m3/s direct conversion";
    p.units.loading = "mol/kg";
    p.units.heat_of_adsorption = "J/mol";
end
