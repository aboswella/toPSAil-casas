function c = build_casas_lite_breakthrough_case(varargin)
%BUILD_CASAS_LITE_BREAKTHROUGH_CASE Build the Casas-lite one-column case.

    p = load_casas2012_ap360_sips_binary();

    opts = struct();
    opts.n_cells = 60;
    opts.final_time_s = 700;
    opts.n_time_points = 351;
    opts.relative_tolerance = 1e-5;
    opts.absolute_tolerance = 1e-8;
    opts.max_step_s = 2;

    opts = parseNameValue(opts, varargin{:});

    c = struct();
    c.case_name = "casas_lite_breakthrough";
    c.case_spec = "cases/casas_lite_breakthrough/case_spec.md";
    c.parameter_pack = p;
    c.model_mode = p.model_mode;
    c.model_mode_requested = p.model_mode_requested;
    c.source_reference_file = p.source_reference_file;

    c.grid.n_cells = opts.n_cells;
    c.grid.z_m = linspace( ...
        p.geometry.L_m / (2 * opts.n_cells), ...
        p.geometry.L_m - p.geometry.L_m / (2 * opts.n_cells), ...
        opts.n_cells);
    c.grid.dz_m = p.geometry.L_m / opts.n_cells;

    c.time.final_time_s = opts.final_time_s;
    c.time.n_time_points = opts.n_time_points;
    c.time.output_time_s = linspace(0, opts.final_time_s, opts.n_time_points);

    c.solver.relative_tolerance = opts.relative_tolerance;
    c.solver.absolute_tolerance = opts.absolute_tolerance;
    c.solver.max_step_s = opts.max_step_s;
    c.solver.name = "ode15s";

    c.geometry.cross_section_area_m2 = pi * p.geometry.Ri_m^2;
    c.flow.feed_flow_m3_s = p.operating.feed_flow_m3_s;
    c.flow.superficial_velocity_m_s = c.flow.feed_flow_m3_s ...
                                    / c.geometry.cross_section_area_m2;
    c.flow.interstitial_velocity_m_s = c.flow.superficial_velocity_m_s ...
                                     / p.adsorbent.eps_b;
    c.flow.mapping = p.approximations.flow_mapping;

    c.operating.feed_y = p.operating.feed_y;
    c.operating.T_feed_K = p.operating.T_feed_K;
    c.operating.P_feed_Pa = p.operating.P_feed_Pa;
    c.operating.P_feed_bar = p.operating.P_feed_bar;
    c.operating.initial_gas = p.operating.initial_gas;
    c.operating.initial_tracked_y = p.initial.tracked_binary_y;

    wallVolumeRatio = (p.geometry.Ro_m^2 - p.geometry.Ri_m^2) ...
                    / p.geometry.Ri_m^2;
    c.thermal.mode = p.thermal.mode;
    c.thermal.wall_volume_per_bed_volume = wallVolumeRatio;
    c.thermal.effective_heat_capacity_J_m3_K = ...
        p.adsorbent.rho_b_kg_m3 * p.thermal.Cs_J_kg_K ...
        + wallVolumeRatio * p.thermal.Cw_J_m3_K;
    c.thermal.heat_transfer_area_per_bed_volume_1_m = 2 / p.geometry.Ri_m;
    c.thermal.ambient_temperature_K = p.operating.T_feed_K;
    c.thermal.wall_temperature_output = "not separate; same lumped temperature";

    c.approximations = p.approximations;
    c.approximations.binary_he_handling = p.initial.approximation;
end

function opts = parseNameValue(opts, varargin)
    if mod(numel(varargin), 2) ~= 0
        error("build_casas_lite_breakthrough_case:BadInputs", ...
              "Options must be name-value pairs.");
    end

    for i = 1:2:numel(varargin)
        name = string(varargin{i});
        value = varargin{i + 1};
        if ~isfield(opts, name)
            error("build_casas_lite_breakthrough_case:UnknownOption", ...
                  "Unknown option: %s", name);
        end
        opts.(name) = value;
    end
end
