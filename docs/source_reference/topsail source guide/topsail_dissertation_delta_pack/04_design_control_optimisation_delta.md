# 04 - Design, control, and optimisation delta

This file is for work after source-fidelity validation. It should not be handed to an agent trying to fix Schell stream wiring unless the plan is to make the wrong answer faster, a classic human achievement.

## Validation gate before optimisation

| Gate | Source basis | Codex rule | Testable prerequisite |
|---|---|---|---|
| Do not tune before source/sink accounting is proven. | Diss p. 241 (PDF p. 276), §6.2.3: design/operation decisions are "highly coupled, have narrow feasible ranges". | Optimisation tasks must depend on passing boundary, tank, product, and metric-basis ledgers. | `test_mass_balance_per_cycle`; `test_source_sink_manifest_matches_cycle`; `test_native_vs_literature_metrics_separated`. |
| Do not treat trial-and-error as validation. | Diss p. 241 (PDF p. 276), §6.2.3: "trial-and-error procedure at best". | Validation reports must distinguish source fidelity, accounting fidelity, numerical health, and tuned performance. | `validation_report.json` with separate status fields. |
| Formal optimisation has expertise and compute costs. | Diss p. 241 (PDF p. 276), §6.2.3: "computationally intensive and require significant expertise". | Start with deterministic sweeps and manifests; delay automated optimisation until model outputs are trustworthy. | Run database with reproducible input/output manifests. |

## Future optimisation and control opportunities

| Opportunity | Dissertation source | Required model outputs | Required process degrees of freedom | Implementation implication | Priority |
|---|---|---|---|---|---|
| Controlled simulations with event termination | Diss p. 231-234 (PDF p. 266-269), §5.5.2 | Adsorber pressure, tank pressure, cumulative product composition, event time, terminal adsorbent state. | Event thresholds, event locations, step split choices, constant-pressure boundary mode. | Build event diagnostics before using events as optimisation constraints. HP feed may terminate on cumulative product purity; DP may terminate on low pressure; purge could terminate on residual heavy key. | Later for Schell, immediate for diagnostic event studies |
| Two-stage controlled repressurisation | Diss p. 233 (PDF p. 268), §5.5.2 | Pressure trajectory by step; source tank pressure; feed makeup usage. | Split repressurisation into product-tank equilibration and feed-driven pressurisation. | [INFERENCE] Useful pattern when product tank cannot reach target high pressure alone. Must be source-backed before use in literature reproduction. | Later |
| Valve-free operation policy | Diss p. 242 (PDF p. 277), §6.2.3 | Valve-free simulated state trajectories; inferred valve-based parameters; performance metrics. | Reparameterised operation variables instead of direct valve constants. | Keep as a separate planning mode. Do not contaminate normal valve-based Schell reproduction. | Research-only |
| Automated design/operation guidance | Diss p. 241 (PDF p. 276), §6.2.3 | Purity, recovery, productivity, energy, CSS cycles, feasibility flags. | Pressure ratio, feed/purge ratio, adsorber geometry/aspect ratio, step durations, event thresholds, valve/BPR parameters. | Store all design variables in a manifest so sweeps and optimisation are reproducible. | Later |
| Surrogate or correlation models from simulation data | Diss p. 242 (PDF p. 277), §6.2.3 | Run inputs, diagnostics, native metrics, reconstructed literature metrics, failure labels. | Design-parameter grid or sample plan. | Build `run_database/` exports before ML. Include failed and unsupported cases so the surrogate does not hallucinate feasibility like a committee. | Research-only |
| Equilibrium-theory normalisation for maximum product | Diss p. 254 (PDF p. 289), Appendix C §C.1 | Maximum product moles at target purity; feed/void/adsorbed inventories. | Initial/final equilibrium states and isotherm model. | [RESEARCH ONLY] Use as sanity check or normalisation, not as dynamic validation. | Research-only |
| Equilibrium-theory repressurisation requirement | Diss p. 257 (PDF p. 292), Appendix C §C.2 | Adsorbed-phase change and void-space pressure-change moles. | Low/high pressure, product composition, temperature, adsorbent mass. | [RESEARCH ONLY] Useful to sanity-check product-gas repressurisation demand. | Research-only |
| Bed layering | Diss p. 243 (PDF p. 278), §6.2.4 | Per-CSTR layer index, adsorbent/isotherm parameters, axial profiles. | Number of layers `n_l`, CSTRs per adsorber `n_c`, layer breakpoints. | Add CSTR-to-layer mapping before changing isotherm arrays. | Later |

## Required outputs for any optimisation/control task

- **Source and native metric split.** Source: Diss p. 161-164 (PDF p. 196-199), §3.6. Native purity/recovery/productivity/energy definitions are not enough for literature comparisons; preserve reconstructed metrics separately.
- **Event ledger.** Source: Diss p. 201 (PDF p. 236), §4.2.2 and Diss p. 213-215 (PDF p. 248-250), §4.2.5. Record event type, location, threshold, actual trigger time, terminal state, and any competing event not chosen.
- **Pressure/tank ledger.** Source: Diss p. 193-196 (PDF p. 228-231), §4.1.1 and Diss p. 231-234 (PDF p. 266-269), §5.5.2. Track feed/raffinate/extract tank pressures and compositions before/after each step.
- **Numerical health ledger.** Source: Diss p. 226-228 (PDF p. 261-263), §5.4. Record LP recourse fraction, failed solver steps if available, JPattern use, CSS error, and flow-reversal episodes.
- **Design-variable manifest.** Source: Diss p. 25 (PDF p. 60), §1.3.3 and Diss p. 241-242 (PDF p. 276-277), §6.2.3. Include pressure ratio, feed-to-purge ratio, aspect ratio, step durations, event thresholds, valve constants, BPR settings, and recovery mode.

## Stop conditions

- Stop optimisation if a source/sink ledger does not conserve component inventories across feed, adsorbers, tanks, products, and waste. Source: Diss p. 162 (PDF p. 197), §3.6.1.
- Stop optimisation if any required source adsorption model is unsupported or substituted. Source: Diss p. 240-241 (PDF p. 275-276), §6.2.2.
- Stop optimisation if four-bed support is being assumed rather than implemented. Source: Diss p. 243 (PDF p. 278), §6.2.4.
- Stop optimisation if event conflicts have no priority policy. Source: Diss p. 235-236 (PDF p. 270-271), §5.5.3.
