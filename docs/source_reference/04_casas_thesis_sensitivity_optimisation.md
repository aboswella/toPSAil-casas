# Stages 5-6 - Casas Thesis Sensitivity and Optimisation Sheet

## Codex task role

Use this file only after the baseline, Casas-lite, and Schell validation stages are stable. This is the source sheet for parametric studies, Pareto-style reporting, scheduling checks, cyclic steady-state criteria, and optimisation wrappers.

This is not a licence to launch an optimisation campaign during a smoke test. That way lies runtime grief and the traditional human achievement of making a slow thing slower.

## Source anchors and check status

| Item | Source anchor | Check status |
|---|---|---|
| Base PSA configuration | Casas thesis 2012, Chapter 4, Table 4.1, text lines 4369-4393 | Text extraction checked. |
| Scheduling constraints | Casas thesis 2012, text lines 4444-4466 | Text extraction checked. |
| Model simplifications | Casas thesis 2012, text lines 4495-4514 | Text extraction checked. |
| Boundary conditions | Casas thesis 2012, Table 4.2, text lines 4534-4574 | Text extraction checked. |
| CSS criteria | Casas thesis 2012, Eq. 4.1, text lines 4589-4609 | Text extraction checked. |
| Performance definitions | Casas thesis 2012, Eqs. 4.2-4.6, text lines 4625-4692 | Text extraction checked. |
| Pressure-equalisation algorithm | Casas thesis 2012, text lines 4703-4753 and Figure 4.3 text lines 4787-4830 | Text extraction checked. |
| Base Pareto representative point | Casas thesis 2012, text lines 4848-4862 and Table 4.3 lines 4878-4886 | Text extraction checked. |
| Parametric-study conclusions | Casas thesis 2012, text lines 5029-5382 | Text extraction checked. |

## Stage goal

The thesis workflow is for post-validation analysis of a pre-combustion CO2 capture PSA. It uses the AP3-60 CO2/H2 system, but shifts the purpose from reproducing the Schell lab PSA to exploring cycle design, Pareto trade-offs, and process conditions.

Use only after:

1. unchanged toPSAil examples run;
2. Casas-lite breakthrough sanity passes;
3. Schell full-cycle validation is stable and documented.

## Process concept

The thesis PSA process uses six basic steps:

1. pressurization using the feed;
2. adsorption/production at high pressure, producing H2;
3. depressurization via pressure equalization;
4. pressurization via pressure equalization;
5. blowdown collecting CO2;
6. purge/rinse at low pressure using the feed mixture.

The base case uses three pressure-equalization steps and six columns operated asynchronously.

## Base case configuration from Table 4.1

| Category | Quantity | Base case | Alternatives studied |
|---|---|---:|---|
| Process configuration | Number of pressure equalization steps | 3 | 2 and 4 |
| Process configuration | Pressurization direction | co-current | none listed |
| Process configuration | Adsorption direction | co-current | none listed |
| Process configuration | Blowdown direction | co-current | counter-current |
| Process configuration | Purge direction | counter-current | none listed |
| Process conditions | Feed temperature `Tfeed` | 35 degC | 70, 100, 120 degC |
| Process conditions | Adsorption/high pressure `p_ads` | 34 bar | 25 bar |
| Process conditions | Desorption/low pressure `p_des` | 1 bar | 2 bar |
| Process conditions | Adsorption volumetric flow `Vdot_ads` | 20e-6 m3/s | none listed |
| Process conditions | Purge volumetric flow `Vdot_purge` | 30e-6 m3/s | none listed |
| Process conditions | Feed mole fraction H2 | 0.6 | none listed |
| Process conditions | Feed mole fraction CO2 | 0.4 | none listed |

## Geometry note and conflict

The thesis text states the simulation dimensions as:

```text
L = 120 cm
Ri = 2.5 cm
```

This conflicts with Casas 2012/Schell 2013 column geometry, where an inner diameter of 2.5 cm corresponds to `Ri = 1.25 cm = 0.0125 m`. Treat the thesis geometry line as ambiguous. Do not overwrite the validated Casas/Schell geometry without a task-level decision.

Suggested implementation handling:

```text
geometry_mode = validated_lab_geometry   # L = 1.2 m, Ri = 0.0125 m
geometry_note = thesis_Ri_line_conflicts_with_Casas_Table_2
```

## Scheduling constraints

For any proposed set of adsorption, purge, blowdown, equalization, and pressurization times, enforce the thesis scheduling constraints:

```text
N_column >= N_peq + 2

t_peq + t_blow + t_purge <= t_ads * (N_column - N_peq - 1)

t_peq + t_press <= t_ads

(N_peq - 1) * t_peq <= t_ads
```

The thesis sets:

```text
N_column = N_peq + 3
```

For the base case with `N_peq = 3`, this gives:

```text
N_column = 6
```

## Model simplifications for the thesis PSA study

Relative to the experimentally validated column model, the thesis optimisation study makes two major simplifications:

| Simplification | Implementation meaning |
|---|---|
| Adiabatic operation | Set heat transfer to the wall/environment to zero and drop the wall energy balance. |
| Neglect axial diffusion and axial thermal conductivity | Drop corresponding second-order terms to reduce computation time. |

The same broad assumptions about LDF mass transfer, constant heats of adsorption, and temperature-dependent Sips equilibrium remain in force.

Do not apply these adiabatic optimisation simplifications to Schell experimental validation unless a task explicitly asks for an adiabatic comparison.

## Boundary-condition summary from Table 4.2

This is for thesis-style reproduction or analysis, not for replacing native toPSAil boundary machinery by default.

| Step | Source boundary summary |
|---|---|
| Adsorption | Outlet/high-pressure boundary `p = p_high`; inlet velocity `u = u_ads`; inlet temperature `T = T_feed`; inlet composition `y_i = y_i,feed`. |
| Blowdown | Outlet pressure prescribed as `p(t)`; zero pressure gradient at opposite end; zero temperature and composition gradients at outlet side. |
| Purge | Low-pressure boundary `p = p_low`; purge velocity at opposite end; purge/feed temperature and composition imposed at purge inlet. |
| Pressurization | Inlet temperature and feed composition imposed; pressure prescribed as `p(t)`; zero pressure gradient at opposite end. |

The thesis notes that the specific blowdown pressure profile mainly affects withdrawal rate/productivity and less strongly affects outlet composition. Do not confuse this with a universal truth for every PSA model.

## Cyclic steady-state criteria

The thesis simulates one column through all steps sequentially until cyclic steady state. At CSS, for every step, composition and temperature at the end of a cycle must no longer change materially from the previous cycle.

Use the source threshold:

```text
delta_ss = 1e-5
```

Composition residual form:

```text
sum_j sum_i (y_i,j - y_i,j_old)^2 < delta_ss
```

Temperature residual form:

```text
sum_j ((T_j_old - T_j) / T_ref)^2 < delta_ss
```

where `j` indexes grid cells and `i` indexes components.

## Pressure equalization algorithm

The thesis one-column sequential algorithm treats the final equalization pressure `p_eq` as an iterated parameter. The correct value makes the moles leaving the high-pressure column match the moles entering the low-pressure column.

Use the source mass-balance error:

```text
epsilon_eq = (n_in_eq - n_out_eq) / n_out_eq
```

Convergence threshold:

```text
delta_eq = 1e-4
```

Source update form shown in Figure 4.3:

```text
p_eq_new = p_eq * (1 - f * epsilon_eq)
```

where:

```text
0 < f < 1
```

Implementation note: this is a method description, not a mandate to replace a native toPSAil equalization solver if it already provides mass-conserving equalization.

## Performance definitions

At CSS, compute:

### CO2 capture rate / recovery

```text
r_CO2 = (CO2 out during purge + CO2 out during blowdown)
        / (CO2 in during purge + CO2 in during pressurization + CO2 in during adsorption)
```

### CO2 purity

```text
Phi_CO2 = (CO2 out during purge + CO2 out during blowdown)
          / [(CO2 + H2) out during purge + (CO2 + H2) out during blowdown]
```

### CO2 productivity

```text
P_CO2 = (CO2 out during purge + CO2 out during blowdown)
        / (t_cycle * m_ads)
```

### H2 purity

```text
Phi_H2 = H2 out during adsorption / [(H2 + CO2) out during adsorption]
```

### H2 productivity

```text
P_H2 = H2 out during adsorption / (t_cycle * m_ads)
```

Fluxes are molar flow rates, i.e. flow rate multiplied by mole fraction, integrated over the indicated step time.

## Representative base-case Pareto point

Source: thesis text and Table 4.3.

| Quantity | Value |
|---|---:|
| CO2 purity `Phi_CO2` | 93.1% |
| CO2 capture rate `r` | 90.3% |
| CO2 productivity `P_CO2` | 24.5 mol/(kg h) |
| Adsorption time `t_ads` | 40 s |
| Blowdown time `t_blow` | 50 s |
| Purge time `t_purge` | 24 s |
| Pressurization time `t_press` | 2 s |
| Pressure equalization time `t_peq` | 4 s |
| Idle time `t_idle` | 100 s |
| Total cycle time `t_cycle` | 240 s |

Use this as a known representative point for post-validation workflow tests, not as a reason to tune Schell validation constants.

## Parametric-study levers and source conclusions

| Lever | Values considered | Source conclusion |
|---|---|---|
| Blowdown/depressurization direction | co-current vs counter-current | Co-current was beneficial for CO2 purity and capture rate for this CO2-capture objective. Counter-current remixed H2 and worsened the target separation. |
| Number of pressure equalization steps | 2, 3, 4 | More equalization steps improved separation, especially CO2 purity, but reduced adsorbent productivity because more columns were required. |
| Desorption pressure | 1 bar vs 2 bar | Higher desorption pressure reduced separation performance strongly, despite possible compression-cost appeal. |
| Feed temperature | 35, 70, 100, 120 degC | Lower temperature performed better because adsorption capacity decreases with temperature; 70 and 100 degC showed small differences. |
| Adsorption pressure | 34 bar vs 25 bar | Pareto-set position changed only modestly, but lower pressure reduced productivity at the same volumetric feed flow because the mass feed flow was smaller. |

## Optimisation guardrails

1. Do not run sensitivity or optimisation inside default smoke tests.
2. Do not optimise until a validation manifest exists for the Schell case.
3. Do not change physics constants and optimisation variables in the same task.
4. Do not weaken CSS thresholds to make optimisation finish faster.
5. Report infeasible schedules rejected by the scheduling constraints.
6. Record whether productivity is normalised per adsorbent mass in one column or a whole unit; use the source definition unless a task states otherwise.
