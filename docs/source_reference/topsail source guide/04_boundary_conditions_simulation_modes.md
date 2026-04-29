# 04 - Boundary conditions, pressure-flow modes, and event termination

Primary source: Taehun Kim and Joseph K. Scott, *Dynamic modeling and simulation of pressure swing adsorption processes using toPSAil*, Computers and Chemical Engineering 176, 108309, 2023.

This is a split-out Codex context file derived from `topsail_paper_source_extraction_schell_4bed.md`. Use it only for tasks where its scope is relevant. Yes, context discipline: the thrilling frontier of not making the next agent read a small novella.

---

## 5. Boundary conditions and simulation regimes

### 5.1 Boundary condition types

Paper facts from Table 2 and Section 2.2.4:

| Type | Name | Meaning | Development consequence |
|---|---|---|---|
| I | Linear valve | Flow is pressure-driven through a linear valve relation. | Valve constants need tuning in pressure-driven mode. |
| II | Constant flow | Boundary molar/volumetric flow is prescribed. | Disallowed in pressure-driven global mode according to Section 3.3.1. |
| III | Closed | Boundary flow is zero. | Used for closed ends. |
| IV | Check valve | Only permits flow in allowed direction. | Useful for preventing backflow. |
| V | Back-pressure regulator | Allows outflow above a set point with valve opening behaviour. | Does not enforce perfect pressure. |
| VI | Check plus BPR | Directional BPR-like outflow. | Used for product tank outlets and some pressure-driven boundaries. |
| VII | Constant-pressure | Manipulates outlet flow to keep adsorber pressure invariant. | Only for no-pressure-drop mode. Maintains initial step pressure. |

Boundary-condition gotcha:

- Type VII is not a magic set-point setter. It keeps the pressure equal to the pressure at the beginning of that step.
- Therefore, if a constant-pressure adsorption or purge step starts at the wrong pressure, Type VII will preserve the wrong pressure with impressive mathematical confidence and no moral compass.

### 5.2 Pressure-driven versus flow-driven regimes

| Regime | Trigger | Paper behaviour | Development consequence |
|---|---|---|---|
| Pressure-driven | Axial pressure drop included through Ergun or Kozeny-Carman. | Flow rates are determined by pressure drops and valve models. Type II and Type VII are disallowed. Product tank outlets use check/BPR behaviour. | More physically realistic but requires careful valve tuning. Pressure targets are approximate unless event-controlled. |
| Flow-driven/control-oriented | No axial pressure drop. | Boundary and product-tank flows can be controlled more exactly. Constant-pressure steps use Type VII. Product tank pressures can be held exactly after targets are reached. | Easier to control and debug, but less realistic and may produce flows against pressure gradients. Document this explicitly. |

Schell implication:

- If using no axial pressure drop as a health-check or native validation route, do not interpret pressure gradients the same way as in a pressure-driven simulation.
- If the run reaches about 22 bar when intended high column pressure is 20 bar, determine whether that comes from feed-tank pressure, prior step terminal pressure, Type VII preserving the wrong pressure, or a pressure-driven valve choice. Do not tune constants blindly.

### 5.3 Initial and terminal conditions

Paper facts:

- Isothermal and no-pressure-drop models require consistency of initial conditions.
- In a PSA cycle, each step's initial condition is the previous step's terminal condition.
- Steps may terminate by fixed duration or by events.
- Events can target pressure, temperature, or light-key mole fraction at supported locations.

Development consequences:

- Before every constant-pressure step, assert that the starting pressure is the intended pressure within tolerance.
- For pressure-changing steps, log initial and terminal pressures for every column.
- For Schell, do not assume fixed durations achieve pressure endpoints unless validated by the ledger.
- For future 4-bed work, event conflicts are a design problem, not an afterthought.

---

### 5.4 Dissertation numerical diagnostics and constraints

Dissertation Chapters 4 and 5 add the following code-facing numerical guidance:

| Area | Dissertation-backed rule | Diagnostic/test implication |
|---|---|---|
| CSS formula | Report `e_t = (1/n_x) * ||x_t - x_{t-1}||_2^2`, the normalized squared L2 difference of cycle initial states, unless current code/source explicitly justifies another metric. | `test_css_metric_matches_dissertation_formula`; export `css_error_by_cycle.csv`. |
| CSS state mask | CSS can use the full initial-condition vector or selected adsorber states. | Make the mask explicit in params/output; export `css_state_mask.json`; test full-state vs adsorber-only masks. |
| CSS trend | CSS error should generally decrease in a well-posed run. | Plot/log CSS by cycle and flag non-monotone excursions without automatically failing. |
| Event-driven CSS acceleration | Events can reduce cycles to CSS in some flow-driven cases, but pressure-driven simulations did not show the same trend. | Report the simulation mode and do not promise acceleration for pressure-driven or untested cases. |
| Multi-bed event conflict | No general approach is given for conflicting event objectives across active beds. | Require an event-priority manifest for any multi-bed event-driven global step. |
| Flow reversals | Brief reversals can occur in well-tuned cycles and can be driven by adsorption sinks, not only pressure gradients. | Log reversal episodes with adsorption-rate and boundary-flow terms; do not automatically fail only because flow changes sign. |
| Pseudo-flow balances | Simplified sign-fixed balances violate mass/energy during reversals. | Never replace sign-aware pseudo-flow logic with `v_plus = v`, `v_minus = 0` for a whole step. |
| No-pressure-drop LP fallback | Varying-pressure no-pressure-drop steps fall back to `linprog` when assumed directions fail; guess-and-check avoids most direct LP solves. | Log LP fallback reason and recourse fraction; preserve the fast path and compare against LP on small cases. |
| Pressure-driven sparsity | Pressure-driven Jacobians are sparse because adjacent CSTR flows depend only on adjacent states. | Preserve/provide `JPattern` or sparsity patterns; add dimension checks and benchmark RHS evaluations for larger `n_c`. |
| ODE with inner algebraic solve | The dynamic step model is a Hessenberg index-1 semi-explicit DAE solved as an ODE with inner flow calculations. | Keep algebraic flow calculations inside RHS for existing models; do not add algebraic states casually. |
| DAE future work | DAE solvers are proposed for implicit isotherm/rate models. | Treat DAE work as a separate feature branch; do not modify Schell routing to chase DAE support. |
| Scaling | CIS scaling normalises time by adsorber residence time `tau = epsilon V_b / v_0`; cumulative moles and energy have explicit scales. | Non-Excel manifests must use the same scaling path as Excel imports and label dimensional vs dimensionless ledgers. |
| Node count and MTZ | Numerical diffusion is tied to cell averaging and node count; adequate nodes inside the mass-transfer zone are recommended. | Record `n_c` basis, run node-count sensitivity before claiming model mismatch, and do not add axial dispersion as a silent patch. |

Suggested diagnostic outputs:

```text
css_error_by_cycle.csv
css_state_mask.json
lp_recourse_by_step.csv
flow_reversal_diagnostics.csv
event_diagnostics.csv
pressure_driven_jpattern_report.json
nc_mtz_basis_manifest.json
```
