# 01 - toPSAil model contract and assumptions

Primary source: Taehun Kim and Joseph K. Scott, *Dynamic modeling and simulation of pressure swing adsorption processes using toPSAil*, Computers and Chemical Engineering 176, 108309, 2023.

This is a split-out Codex context file derived from `topsail_paper_source_extraction_schell_4bed.md`. Use it only for tasks where its scope is relevant. Yes, context discipline: the thrilling frontier of not making the next agent read a small novella.

---

## 2. toPSAil model contract

### 2.1 Adsorber model

Paper facts:

- An adsorber is modelled as a sequence of well-mixed CSTRs arranged end-to-end.
- The resulting model is closely related to a first-order finite-volume/upwind discretisation of a PDE model.
- Axial dispersion is not included in the base CIS model.
- The gas phase is treated as ideal.
- Adsorption kinetics use an LDF rate form: the rate is proportional to the difference between equilibrium loading and current loading.
- The equilibrium loading function can be any supported isotherm.
- Isothermal, nonisothermal, and adiabatic-like cases are controlled through the heat model choice and heat-transfer coefficients.

Development consequences:

- Do not diagnose every mismatch as an isotherm failure. The simulator wiring and pressure-flow regime are equally important.
- If a source paper includes axial dispersion or spatial thermal conduction, classify those as unsupported, approximated, ignored, or requiring a core extension.
- For Schell, the current working assumption is nonisothermal nonequilibrium with LDF and Sips equilibrium. The Sips algebra may be sound while the cycle wiring is wrong.
- If the current health check is isothermal, report it as a health check only. Do not compare final thermal validation metrics from an isothermal run.

### 2.2 Flow sign and direction

Paper facts:

- Volumetric flows are defined so that direction can change during a step.
- The paper introduces positive and negative pseudo-volumetric flows to keep balances valid through reversals.
- The solver first assumes nominal direction for efficiency and falls back to a more general LP calculation if that assumption fails.

Current-code facts:

- `flowDirCol` uses native strings such as `0_(positive)`, `1_(negative)`, and `TBD`.
- `getStringParams.m` converts `1_(negative)` into numeric countercurrent flags.
- Equalisation flow direction is inferred from neighbouring steps, not fully specified by the source paper.

Development consequences:

- A flow reversal warning is not sufficient evidence of a broken simulation.
- A persistent or product-dominating reversal during Schell adsorption/purge is suspicious and should trigger boundary ledger inspection.
- Every step mapping must record intended flow direction, observed boundary flow direction, and whether the observed direction is transient or dominant.

---

### 2.3 Dissertation adsorption-model catalogue

Dissertation Appendix D refines the model-capability map. Verify current code before relying on any listed support.

| Model/submodel | Native status to assume for planning | Extension or caution | Minimum tests before use |
|---|---|---|---|
| Extended Langmuir isotherm | Appendix D calls it the workhorse toPSAil isotherm. It is explicit after computing temperature-dependent affinity. | Do not treat all Langmuir-like models as this one; it has one shared multicomponent denominator. | Pure-component limit, multicomponent denominator, temperature dependence, dimensional/dimensionless round trip. |
| Linear/Henry isotherm | Appears supported as an explicit Henry-law isotherm. | Do not use it for nonlinear or competitive high-loading behaviour without source justification. | Henry proportionality, zero-pressure uptake, temperature scaling. |
| Extended Langmuir-Freundlich / LRC | Appears supported as an explicit multicomponent isotherm with temperature-dependent saturation, affinity, and exponent. | Verify code before relying on the exact Appendix D equations; do not collapse it into a Sips alias unless parameters and exponents match exactly. | Parameter shape, exponent temperature scaling, denominator coupling, positive finite uptake. |
| Dual-site Langmuir-Freundlich | Appears supported in decoupled and extended forms. | Decoupled form is justified only under narrow dissertation conditions; do not use blindly for high-pressure multicomponent PSA. | Decoupled-vs-extended branch tests, two-site pure-component limit, low-pressure behaviour, parameter-count validation. |
| Multi-site Langmuir | Appendix D includes it, but it is implicit and requires solving a nonlinear system. | A local implicit equilibrium solve does not mean general implicit adsorption support exists. Verify any fsolve path and failure handling. | Solver convergence, positivity, occupancy below one, initial-guess sensitivity, clear infeasible-parameter errors. |
| Standard LDF rate | Native kinetics are scalar LDF, `r_i = k_i(q_i* - q_i)`, for supported `q_i*`. | It does not capture coupled mass-transfer overshoot or Maxwell-Stefan effects. | Adsorption/desorption sign, `Da_i` scaling, zero-driving-force, supported-isotherm coupling. |
| Maxwell-Stefan LDF | Not native according to the dissertation; future implicit-model work. | Do not fake MS-LDF by tuning scalar LDF coefficients. | Published limiting cases, mass conservation, transient overshoot benchmark, solver convergence/failure tests. |
| Generalized Langmuir with aNRTL | Not native in the Appendix D catalogue. | Requires a real implicit thermodynamic model/residual layer; do not rename Extended Langmuir parameters. | Published-case reproduction, dimensional consistency, multi-initial-guess convergence, infeasible-parameter errors. |
| S-shaped isotherms and hysteresis | Not listed as native in Appendix D. | Hysteresis may require state/history memory beyond instantaneous `q*(c,T)`. | Adsorption/desorption branch tests, cycle-history reproducibility, branch transition tests. |

Implementation rules:

- Emit an `unsupported_model` gate when a source paper requires gL, MS-LDF, S-shaped isotherms, or hysteresis and the actual model is not implemented and tested.
- Do not conflate a local nonlinear isotherm solve with a general implicit DAE framework. Multi-site Langmuir may be a local equilibrium solve; MS-LDF may require dynamic implicit residuals.
- Dimensionless scaling is part of the model contract. New submodels need dimensional and dimensionless paths or a tested conversion wrapper.
- Schell integration should not be delayed by speculative adsorption-model work unless the Schell source model is unsupported.

### 2.4 Dissertation numerical and scaling contract

Dissertation Chapters 3-5 add these implementation-facing constraints:

- The dynamic step model is a Hessenberg index-1 semi-explicit DAE, but current toPSAil solves it as an ODE with inner algebraic flow solves. Keep algebraic flow calculations inside the RHS for existing models and do not add algebraic states casually.
- DAE solvers are research/future work for implicit adsorption models. Do not modify Schell routing to chase DAE support.
- All units use CIS adsorber normalisation constants. Non-Excel manifests must supply dimensional values and call the same scaling path as Excel imports.
- Time is normalised by adsorber residence time, `tau = epsilon V_b / v_0`, not by tank volume or cycle time.
- Cumulative moles and energy have explicit scales; ledger exports must label dimensional versus dimensionless cumulative quantities.
- Numerical diffusion is tied to cell averaging and node count. Do node-count or MTZ sensitivity before claiming model mismatch or silently adding axial dispersion.
- Adequate nodes inside the mass-transfer zone are recommended, but the dissertation does not give a universal node-count rule. Record the `n_c` basis in manifests.
