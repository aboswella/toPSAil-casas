# toPSAil split source-extraction bundle: context router

Primary source: Taehun Kim and Joseph K. Scott, *Dynamic modeling and simulation of pressure swing adsorption processes using toPSAil*, Computers and Chemical Engineering 176, 108309, 2023.

Integrated secondary source: Taehun Kim, *Computational Methods for Intensifying the Design and Operation of Pressure Swing Adsorption Processes*, PhD dissertation. The dissertation-only delta pack under `topsail_dissertation_delta_pack/` has been folded into this guide; future tasks should prefer these integrated files unless auditing the integration itself.

Purpose: split the long toPSAil source-extraction file into smaller task-specific files so future Codex agents can receive only the context they need.

## Which files to pass

| Agent task | Pass these files |
|---|---|
| Diagnose Schell stream placement / purge source issue | `02_pfd_tanks_pressure.md`, `03_step_strings_connectivity.md`, `04_boundary_conditions_simulation_modes.md`, `06_schell_integration_remaining_tasks.md` |
| Build or refactor Schell cycle scheduler | `03_step_strings_connectivity.md`, `06_schell_integration_remaining_tasks.md`, `08_manifests_tests.md` |
| Build boundary/tank/product ledger | `02_pfd_tanks_pressure.md`, `05_metrics_accounting_ledgers.md`, `06_schell_integration_remaining_tasks.md` |
| Implement Schell-specific performance metrics | `05_metrics_accounting_ledgers.md`, `06_schell_integration_remaining_tasks.md` |
| Extend to 4-bed cycles | `02_pfd_tanks_pressure.md`, `03_step_strings_connectivity.md`, `07_four_bed_extension.md`, `08_manifests_tests.md` |
| Audit simulator assumptions before a new literature implementation | `01_model_contract_assumptions.md`, `02_pfd_tanks_pressure.md`, `04_boundary_conditions_simulation_modes.md`, `08_manifests_tests.md` |

## Dissertation-refined routing

| Codex task type | Pass these integrated files | Why |
|---|---|---|
| Schell stream placement, fixed-composition sources, MFCs, tanks, and valves | `02_pfd_tanks_pressure.md`, `03_step_strings_connectivity.md`, `04_boundary_conditions_simulation_modes.md`, `05_metrics_accounting_ledgers.md`, `06_schell_integration_remaining_tasks.md`, `08_manifests_tests.md` | Adds tank/MFC equations, valve/BPR nuances, RHS workflow, and diagnostic outputs beyond the paper pack. |
| Translating a literature cycle with overlapping steps into native cycle organisation | `03_step_strings_connectivity.md`, `04_boundary_conditions_simulation_modes.md`, `07_four_bed_extension.md`, `08_manifests_tests.md` | Adds `runPsaCycle` workflow, event locations, CSS checks, and the stronger dissertation warning that current toPSAil is two-adsorber limited. |
| Building Schell diagnostic outputs for HP adsorption, purge, extract, and product routing | `04_boundary_conditions_simulation_modes.md`, `05_metrics_accounting_ledgers.md`, `06_schell_integration_remaining_tasks.md`, `08_manifests_tests.md` | Adds output-folder structure, standard plots, complete CSV trajectory basis, cumulative-flow/work states, event diagnostics, and LP/flow-reversal diagnostics. |
| Deciding which performance metrics to trust, reconstruct, or reject | `05_metrics_accounting_ledgers.md`, `06_schell_integration_remaining_tasks.md`, `08_manifests_tests.md` | Adds product-tank/external-product distinctions, recovery-basis nuance, and a required native-vs-literature metric split. |
| Auditing adsorption submodels or adding future isotherm/rate support | `01_model_contract_assumptions.md`, `04_boundary_conditions_simulation_modes.md`, `08_manifests_tests.md` | Adds Appendix D model catalogue, implicit-model constraints, dimensionless scaling tests, and the warning not to fake gL/MS-LDF support. |
| Numerical performance work: CSS acceleration, flow reversals, LP fallback, sparse Jacobians | `04_boundary_conditions_simulation_modes.md`, `05_metrics_accounting_ledgers.md`, `08_manifests_tests.md` | Adds speedup/recourse diagnostics, Jacobian sparsity instructions, and event-driven CSS caveats. |
| Four-bed PSA implementation or feasibility audit | `02_pfd_tanks_pressure.md`, `03_step_strings_connectivity.md`, `04_boundary_conditions_simulation_modes.md`, `07_four_bed_extension.md`, `08_manifests_tests.md` | Adds the dissertation's stronger limitation: current version does not support more than two adsorbers or multiple equalisation steps. |
| Post-validation optimisation, control, or design-intensification planning | `04_boundary_conditions_simulation_modes.md`, `05_metrics_accounting_ledgers.md`, `08_manifests_tests.md` | Adds valve-free policy, surrogate-data roadmap, design degrees of freedom, and validation gates. |
| Codebase navigation, run folders, Excel-to-MATLAB workflow, non-Excel manifests | `00_executive_source_map.md`, `05_metrics_accounting_ledgers.md`, `08_manifests_tests.md` | Adds folder trees, input-file categories, `getSimParams`/`getExcelParams`/`runPsaCycle` workflow, and suggested manifest placement. |

## Non-negotiable carry-forward facts

1. toPSAil has a fixed PFD. Step strings are connectivity commands, not friendly labels.
2. Tanks are dynamic well-mixed units. Initial seeding is not a permanent source specification.
3. Native step grammar is `STEP-FEEDEND-PRODUCTEND`.
4. `HP-FEE-RAF` means feed tank to feed end, product end to raffinate tank.
5. `LP-EXT-RAF` is dangerous for Schell because it uses the native raffinate-side path, not a fixed equimolar feed purge.
6. Feed tank pressure, adsorber pressure, raffinate tank pressure, extract tank pressure, and BPR/event pressures must be kept distinct.
7. No-axial-pressure-drop mode is control-oriented and flow-driven; it can allow flows that look odd under pressure-gradient intuition.
8. Type VII constant-pressure boundaries maintain the step-start pressure. They do not automatically drive to the intended source-paper pressure.
9. Native toPSAil product metrics are not automatically source-paper metrics. Schell needs a separate accounting basis.
10. 4-bed support must be audited rather than assumed.
11. The dissertation states current toPSAil does not support bed layering, more than two adsorbers, or multiple equalisation steps. Treat those as feature gaps until audited and implemented.
12. Fixed-composition literature streams are source/sink semantics, not initial tank compositions. A seeded tank is still dynamic.
13. Before parameter tuning, add ledgers for tanks, external products, cumulative flows, events, CSS, and metric basis.
14. Do not implement gL, MS-LDF, S-shaped isotherms, or hysteresis by aliasing an existing explicit model. Use unsupported-model gates until real model support and tests exist.
15. CSS reporting should identify the state mask and use the normalized squared L2 cycle-initial-state difference unless current code/source explicitly justifies another metric.
16. CSV trajectories are the canonical substrate for diagnostics, dashboards, and future animations.

## File list

| File | Scope |
|---|---|
| `00_README_context_router.md` | This router and minimal carry-forward facts. |
| `00_executive_source_map.md` | Original executive carry-forward plus source/code map. |
| `01_model_contract_assumptions.md` | CIS model, LDF, flow reversal, unsupported physics assumptions. |
| `02_pfd_tanks_pressure.md` | Fixed PFD, dynamic tanks, feed/raffinate/extract semantics, pressure vocabulary. |
| `03_step_strings_connectivity.md` | Step grammar, Schell-relevant native steps, `LP-EXT-RAF`, scheduler rules. |
| `04_boundary_conditions_simulation_modes.md` | Boundary types, pressure-driven versus flow-driven mode, Type VII and events. |
| `05_metrics_accounting_ledgers.md` | Native metrics, Schell reporting basis, ledgers and conservation fields. |
| `06_schell_integration_remaining_tasks.md` | Immediate Schell diagnosis and staged implementation plan. |
| `07_four_bed_extension.md` | 4-bed audit, equalisation pairing, event policy, shared tanks. |
| `08_manifests_tests.md` | Required manifests, test plan, Codex prompt preamble, priorities. |

## Minimal prompt preamble

```text
Use the attached split toPSAil source-extraction files as the semantic contract for this task. Treat step strings as literal PFD connectivity commands. Tanks are dynamic, not fixed reservoirs. Do not tune constants until source/sink wiring, pressure semantics, and metric basis are proven by manifests and ledgers.
```
