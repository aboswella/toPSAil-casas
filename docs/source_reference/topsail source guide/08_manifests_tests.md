# 08 - Required manifests, tests, and implementation priorities

Primary source: Taehun Kim and Joseph K. Scott, *Dynamic modeling and simulation of pressure swing adsorption processes using toPSAil*, Computers and Chemical Engineering 176, 108309, 2023.

This is a split-out Codex context file derived from `topsail_paper_source_extraction_schell_4bed.md`. Use it only for tasks where its scope is relevant. Yes, context discipline: the thrilling frontier of not making the next agent read a small novella.

---

## 9. Required manifests for every future implementation

Future Codex agents should create or update these files before running large simulations.

### 9.1 Source parameter manifest

```text
source_parameter
source_location
source_value
source_unit
native_field
native_value
native_unit
conversion_formula
assumption_tier: direct | converted | inferred | approximated | diagnostic_only
notes
```

### 9.2 Cycle connectivity manifest

```text
source_step_name
native_step_string
feed_end_connection
product_end_connection
source_reservoir
sink_reservoir
intended_flow_direction
pressure_class: constant | varying | equalisation | rest
boundary_condition_types
simulation_mode_dependency
source_evidence
implementation_notes
```

### 9.3 Pressure manifest

```text
pressure_name
source_value
native_field
value_used
role
is_setpoint
is_initial_condition
is_event_target
is_BPR_setting
is_source_pressure
notes
```

### 9.4 Metrics manifest

```text
metric_name
source_definition
native_definition
comparison_basis: direct | reconstructed | indirect | not_comparable
required_streams
required_integrals
known_mismatch
```

### 9.5 Diagnostic ledger schema

```text
cycle
step_index
step_name_by_column
column
step_start_time
step_end_time
column_pressure_min_mean_max
feed_end_flow_integral_by_component
product_end_flow_integral_by_component
feed_tank_to_column_integral_by_component
raffinate_tank_to_column_integral_by_component
extract_tank_to_column_integral_by_component
column_to_raffinate_tank_integral_by_component
column_to_extract_tank_integral_by_component
external_raffinate_product_integral_by_component
external_extract_product_integral_by_component
waste_integral_by_component
tank_pressure_and_composition_before_after
mass_balance_residual_by_component
```

---

## 10. Test plan implied by this extraction

### 10.1 Schell-specific tests

| Test | Purpose | Expected result |
|---|---|---|
| `test_schell_step_connectivity_manifest` | Verify each source step maps to intended native source/sink. | Fails for current `LP-EXT-RAF` if expected purge source is equimolar feed. |
| `test_lp_ext_raf_uses_raffinate_tank` | Lock in native semantics so no one forgets the trap. | Confirms product-end source is dynamic raffinate tank. |
| `test_schell_purge_source_fixed_equimolar` | Validate replacement purge implementation. | Purge source composition remains equimolar and independent of raffinate product tank. |
| `test_type_vii_start_pressure_assertions` | Prevent constant-pressure steps preserving wrong pressure. | All HP steps start at high pressure; all LP steps start at low pressure within tolerance. |
| `test_schell_schedule_all_cases_positive` | Ensure scheduler supports all Schell performance cases. | No negative/zero durations; source durations conserved. |
| `test_schell_native_vs_schell_basis_metrics` | Keep accounting bases separate. | Report emits both bases; source comparison uses Schell basis. |
| `test_schell_component_conservation_per_cycle` | Catch stream routing and accounting defects. | Component residuals below tolerance after including tanks/products/waste. |
| `test_h2_adsorption_product_not_consumed_unexpectedly` | Detect product eaten by purge/recycle mapping. | H2-rich adsorption product remains allocated as product or intentional recycle. |

### 10.2 4-bed tests

| Test | Purpose | Expected result |
|---|---|---|
| `test_four_bed_minimal_closed_cycle_initializes` | Prove `nCols = 4` can initialise without events. | State vector, params, and time spans created. |
| `test_four_bed_step_matrix_dimensions` | Catch two-bed assumptions in parsing. | All cycle matrices are `4 x nSteps`. |
| `test_four_bed_equalisation_pairing` | Verify intended equalisation pairs. | Pair matrix matches manifest exactly. |
| `test_four_bed_no_unsupported_events` | Prevent use of `Adsorber_3_*` before generic event support. | Either generic events exist or clear failure is raised. |
| `test_four_bed_shared_tank_ledger` | Make shared tank effects visible. | Tank inflows/outflows by bed and component are reported. |
| `test_four_bed_mass_conservation` | Catch hidden product/waste loss. | Global component residuals below tolerance. |
| `test_four_bed_metrics_sum_over_all_columns` | Ensure product accounting scales past two beds. | Metrics equal explicit sum over all beds/tanks. |
| `test_four_bed_plotting_optional` | Avoid plotting assumptions blocking simulation. | Simulation can run with plotting disabled. |

---

## 11. Recommended Codex prompt preamble

Paste this before any future Schell or 4-bed task:

```text
Read `topsail_paper_source_extraction_schell_4bed.md` before editing code. Treat toPSAil step strings as literal PFD connectivity commands, not descriptive labels. Tanks are dynamic well-mixed units and must not be used as fixed-composition reservoirs unless explicitly controlled. For Schell, do not use native `LP-EXT-RAF` as equimolar-feed purge without proving the source is fixed equimolar feed; native `LP-EXT-RAF` uses the raffinate tank as purge source. Keep native direct product metrics separate from Schell SI/subtraction-basis metrics. In no-axial-pressure-drop mode, Type VII constant-pressure control maintains the pressure present at the start of the step, so assert step-start pressures. For 4-bed systems, audit code paths for nCols > 2, especially event functions, equalisation pairing, shared tanks, and schedule construction. Do not tune constants until boundary ledgers and source/sink manifests prove the flowsheet is correct.
```

---

## 12. Bottom-line implementation priorities

For Schell:

1. Add boundary/tank/product ledger.
2. Prove current stream placement fault with the ledger.
3. Replace or label `LP-EXT-RAF` purge semantics.
4. Add pressure manifest and Type VII start-pressure assertions.
5. Build Schell-basis metric extractor.
6. Replace central-only schedule formula with source-backed scheduler.
7. Only then tune or compare performance.

For future 4-bed systems:

1. Build a generic global schedule representation.
2. Add or verify `nCols = 4` parsing and state support.
3. Extend events beyond Adsorber 1/2 or avoid bed-specific events initially.
4. Add explicit equalisation pair mapping.
5. Add shared tank ledger.
6. Validate conservation and metrics before fitting any source case.

---

## 13. Dissertation-backed manifest additions

Add these manifest/report families when the corresponding capability is used:

| Manifest/report | Required fields | Source-backed reason |
|---|---|---|
| CSS manifest | formula, state mask, tolerance, cycle-by-cycle error, convergence status | The dissertation defines CSS as a normalized squared L2 difference and allows full-state or selected adsorber-state masks. |
| Event diagnostics | event type, location, threshold, trigger time, terminal state, suppressed competing objectives | Event termination is checked after steps; multi-bed event objectives can conflict. |
| Event priority policy | controlling bed/objective, sacrificed objectives, source rationale, fixed-duration fallback | No general multi-bed conflict resolution is given; priority is case-specific. |
| LP and flow-reversal report | step, node/end, reversal duration/integral, adsorption-rate context, LP fallback reason, recourse fraction | Flow reversals can be valid, but sign-fixed balances are unsafe; no-pressure-drop fallback should be visible. |
| JPattern/sparsity report | pressure-flow mode, `n_c`, sparsity enabled, pattern dimensions, RHS equivalence check | Pressure-driven Jacobians are sparse and matter more as node count grows. |
| Run manifest | source files, input manifests, generated CSVs/figures, model mode, scaling path, code version | Appendix E ties outputs, data folders, and reference information to reproducible runs. |
| Design-variable manifest | pressure ratio, feed/purge ratio, aspect ratio, durations, event thresholds, valve constants, BPR settings, recovery mode | Optimisation/control work must expose design degrees of freedom after validation gates pass. |
| Capability manifest | supported isotherms/rates, unsupported-model gates, source-required model, implemented tests | Do not use gL, MS-LDF, S-shaped isotherms, or hysteresis by aliasing existing explicit models. |

## 14. Dissertation task cards for future Codex work

| Card | Objective | Main deliverables | Stop condition |
|---|---|---|---|
| Boundary, tank, and product ledgers | Export per-step, per-bed, per-component transfers across adsorber boundaries, tanks, external products, wastes, compressors, and vacuum pump. | `step_boundary_ledger.csv`, `tank_history.csv`, `product_tank_vs_external_product.csv`, `mass_balance_residuals.csv`, tests. | Stop if cumulative states are unavailable or dimensional scaling cannot be verified. |
| Schell stream semantics audit | Decide whether fixed-composition feed/purge streams can be represented with native tanks or need a custom source/PFD extension. | `schell_stream_semantics_audit.md`, source/sink manifest, fixed-source tests. | Stop if Schell purge needs a native-absent PFD element; document limitation instead of silently patching. |
| CSS and event diagnostics | Export CSS error, CSS mask, event trigger data, and event-priority metadata. | `css_convergence.csv`, `css_state_mask.json`, `event_diagnostics.csv`, `event_priority_policy.json`. | Stop if task requires bed 3/4 events but current event functions are two-bed hardcoded. |
| Numerical performance diagnostics | Add LP recourse, flow reversal, JPattern availability, and solver-mode diagnostics. | `lp_recourse_by_step.csv`, `flow_reversal_diagnostics.csv`, JPattern tests, benchmark summary. | Stop if an optimisation changes numerical results without conservation/accuracy explanation. |
| Non-Excel manifest bridge | Add machine-readable manifests while preserving current `.xlsm` import. | `manifests/` convention, loader, parity tests, `run_manifest.json`. | Stop if the manifest loader cannot reproduce current Excel-imported params. |
| Adsorption submodel audit | Catalogue native isotherm/rate support and add unsupported-model gates. | `adsorption_model_capability_manifest.json`, parameter-count tests, unsupported-model errors. | Stop if a validation source requires an unsupported model and the task is not model implementation. |
| Four-bed capability audit | Determine which code paths support four adsorbers and add fail-fast gates. | `four_bed_capability_audit.md`, feature gates, tests. | Stop if two-bed hardcoding affects state, event, valve, metric, or plotting behaviour. |
| Four-bed scheduler prototype | Build global schedule representation with equalisation pairs, shared-tank usage, and event priority. | `global_cycle_manifest.csv`, `equalization_pair_map.csv`, `event_priority_policy.json`. | Stop if native cycle organisation cannot represent required pairings without extension. |
| Visual diagnostics | Produce CSV-driven diagnostics for tanks, axial profiles, CSS, events, product accounting, and four-bed timeline. | Diagnostic plots, animation-script prototype, `run_manifest.json`, tests. | Stop if CSV exports are incomplete for required units/components. |
| Post-validation design/control harness | Build reproducible design/control sweeps only after validation and ledgers pass. | `design_sweep_manifest.json`, run database, validation gate, controlled-run report. | Stop if source fidelity is unproven or optimisation uses incompatible native metrics. |

## 15. Optimisation and control gate

Do not start optimisation or control-intensification tasks until these prerequisites pass:

- source/sink ledger conserves component inventories across feed, adsorbers, tanks, products, and waste;
- native and reconstructed literature metrics are separated;
- validation reports distinguish source fidelity, accounting fidelity, numerical health, and tuned performance;
- required source adsorption models are supported, not substituted;
- four-bed support is implemented and tested rather than assumed;
- multi-bed event conflicts have an explicit priority policy.

Allowed later opportunities:

| Opportunity | Required outputs | Implementation note |
|---|---|---|
| Controlled simulations with event termination | pressure/tank trajectories, cumulative product composition, event time, terminal adsorbent state | Build event diagnostics before using events as optimisation constraints. |
| Two-stage controlled repressurisation | pressure trajectory, source tank pressure, feed makeup usage | Treat as source-backed only when the literature supports product-tank equilibration plus feed-driven pressurisation. |
| Valve-free operation policy | valve-free trajectories, inferred valve parameters, performance metrics | Keep as a separate planning mode; do not contaminate normal valve-based Schell reproduction. |
| Automated sweeps/optimisation | reproducible input/output manifests, feasibility flags, source/native metrics | Start with deterministic sweeps and run databases before automated optimisation. |
| Surrogate models | run inputs, diagnostics, metrics, failure labels | Include failed and unsupported cases so the surrogate does not imply false feasibility. |
| Equilibrium-theory normalisation | feed/void/adsorbed inventories and maximum product estimates | Use as research-only sanity checks, not dynamic validation. |
| Bed layering | CSTR-to-layer map, per-layer adsorbent/isotherm parameters, axial profiles | Add layer mapping before changing isotherm arrays. |

## 16. Codebase workflow anchors from the dissertation

Preserve these workflow contracts unless a task explicitly replaces them:

| Anchor | Codex-facing meaning | Do not break |
|---|---|---|
| `2_run/definePath2SourceFolders.m` | Adds source/example paths for programmatic runs. | Do not require GUI-only paths for automated tasks. |
| `2_run/programProfiler.m` | Profiling and test-simulation hook. | Keep usable for numerical benchmarks and smoke tests. |
| `2_run/runPsaProcessSimulation.m` | Programmatic simulation entry point that takes an example folder string. | Do not make the GUI the only run path. |
| `getSimParams.m` and `getExcelParams.m` | Import, type-check, sort, scale, and precompute `params`. | Non-Excel manifests must feed the same structure or pass parity tests. |
| Example folder structure | `1 simulation inputs`, `2 simulation outputs`, `3 reference info`, `4 additional plots`. | Do not overwrite reference info or hide generated diagnostics outside the case/run record. |
| Output subfolders | `2 simulation outputs/1 figs` and `2 simulation outputs/2 data`. | Do not change output paths without a compatibility shim. |
| Input spreadsheets | Existing `.xlsm` parameter categories. | Do not break import paths unless deliberately replacing them with tests. |
| RHS workflow | `units.col`, `units.feTa`, `units.raTa`, `units.exTa`, `makeCol2Interact`, `funcVol`, balances, and concatenation. | Do not bypass cumulative-flow/work states when adding ledgers. |
| Cycle workflow | CSS check, step simulation, metrics at last step, terminal-state handoff, event checks. | Do not compute validation metrics without CSS and event context. |

Suggested non-Excel placement:

- Put machine-readable case manifests under `4 example/<case>/1 simulation inputs/manifests/`.
- Put source PDFs, parameter tables, and literature notes under `4 example/<case>/3 reference info/`.
- Put generated ledger plots and Python dashboards under `4 example/<case>/4 additional plots/` or `2 simulation outputs/1 figs`, depending on whether they are official outputs or extra analysis.
- A future non-Excel loader should feed the same `params` structure after validation and scaling rather than bypassing `getSimParams.m`.

## 17. Dissertation ambiguity register

Do not silently resolve these. Open a scoped task or record the decision in the relevant case/report.

| Ambiguity | Why it matters | Decision needed |
|---|---|---|
| Schell fixed-composition purge source versus native dynamic tanks | Native tanks evolve and product tanks can feed adsorbers; a fixed equimolar purge may need PFD extension or custom boundary logic. | Choose native approximation, custom boundary, or PFD extension, and label validation status. |
| Metric basis for publication comparison | Dissertation/native metrics may not match Schell's accounting. | Decide which reconstructed metrics are source-comparable. |
| Excel as canonical input versus manifest-first route | Current workflow imports `.xlsm`, validates types, scales, and builds `params`. | Decide whether manifests generate Excel-compatible data, feed `params` directly, or both. |
| DAE solver priority for implicit adsorption models | gL/MS-LDF need implicit procedures, but Schell/four-bed routing does not. | Decide whether implicit-model implementation is in scope before validation tasks. |
| Four-bed event priority policy | No general conflict-resolution approach is given. | Define source-specific priority, fixed-duration fallback, or multi-objective event handling. |
| Four-bed equalisation representation | Existing step list is two-adsorber scoped and multiple equalisation is unsupported. | Decide explicit pair-map schema and whether multiple equalisation stages are allowed. |
| Node-count/MTZ rule | Numerical diffusion depends on node count, but no universal rule is given beyond adequate MTZ nodes. | Define benchmark-specific node-count selection and sensitivity policy. |
| Energy accounting for feed compression/vacuum | Native energy terms can be conditionally skipped depending on feed and low-pressure levels. | Decide whether literature comparison includes or excludes native energy terms. |

Do not reopen dissertation sections for general background, broad adsorber derivations, Appendix A back-of-envelope calculations, GUI screenshots, long pressure-changer derivations, TSA/SMB discussion, or Appendix C equilibrium calculations unless the task explicitly needs them.
