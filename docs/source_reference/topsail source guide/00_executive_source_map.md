# 00 - Executive carry-forward and source map

Primary source: Taehun Kim and Joseph K. Scott, *Dynamic modeling and simulation of pressure swing adsorption processes using toPSAil*, Computers and Chemical Engineering 176, 108309, 2023.

Integrated secondary source: Taehun Kim, *Computational Methods for Intensifying the Design and Operation of Pressure Swing Adsorption Processes*, PhD dissertation. Dissertation deltas are integrated here only where they add implementation detail, stronger limitations, numerical conditions, workflow anchors, or future-development priorities.

This is a split-out Codex context file derived from `topsail_paper_source_extraction_schell_4bed.md`. Use it only for tasks where its scope is relevant. Yes, context discipline: the thrilling frontier of not making the next agent read a small novella.

---

## 0. Executive carry-forward for Codex

Carry these facts into every future session. Most failures in this integration will not come from the isotherm. They will come from ambiguous boundary semantics, which is depressingly on brand for PSA modelling.

1. **toPSAil uses a fixed PFD.** Step strings are not decorative labels. They define which tanks, ends, wastes, and equalisation paths are connected during a step.
2. **Tanks are dynamic well-mixed units.** A tank seeded with a composition is not a permanent fixed-composition reservoir. It evolves unless explicitly controlled or reset.
3. **`STEP-FEEDEND-PRODUCTEND` is literal.** The second token is the feed-end connection; the third token is the product-end connection.
4. **`HP-FEE-RAF` means feed tank to feed end, product end to raffinate tank.** It is the native high-pressure adsorption/product step.
5. **`LP-EXT-RAF` means raffinate tank to product end, feed end to extract side.** It is not a fixed equimolar-feed purge. For Schell, this is the chief semantic hazard.
6. **Feed tank pressure, column pressure, raffinate tank pressure, extract tank pressure, and BPR set pressures are distinct.** Do not multiply one by 1.1 and call it physics.
7. **No-axial-pressure-drop mode is flow-driven/control-oriented.** It may produce flows that violate intuitive pressure-gradient expectations. That can be allowed, but it must be documented.
8. **Type VII constant-pressure control maintains the pressure at the start of the step.** The previous step must already have reached the desired pressure.
9. **Flow reversal is supported and not automatically a bug.** Log reversals, then decide whether they are transient physical/numerical consequences or a sign of wrong connectivity.
10. **Native metrics are not automatically literature metrics.** For Schell, native direct raffinate/extract products must be separated from the Schell SI subtraction basis.
11. **Four-bed support is stronger-limited than the earlier paper-pack wording implied.** The dissertation says current toPSAil does not support bed layering, more than two adsorbers, or multiple equalisation steps. 4-bed development is a new capability task until code paths, events, equalisation pairing, plotting, and schedule representation pass audit.
12. **Multi-adsorber event control can have conflicting objectives.** The paper explicitly treats this as difficult and custom, not something to solve by optimism.
13. **Implicit adsorption models are not generally available.** A local implicit multi-site Langmuir solve does not imply support for gL, MS-LDF, S-shaped isotherms, or hysteresis.
14. **CSS and numerical diagnostics are first-class outputs.** Report the CSS state mask, normalized squared L2 cycle-initial-state error, LP recourse fraction, flow-reversal episodes, and JPattern/sparsity status where relevant.
15. **CSV-first output is the dissertation-backed diagnostic substrate.** Ledgers, dashboards, and future animations should read exported trajectories instead of scraping plots.

---

## 1. Source map

| Topic | Paper location | Use in development |
|---|---|---|
| CIS adsorber model | Section 2.1, pp. 3-7 | Establish model assumptions, flow sign conventions, LDF, ideal gas, no axial dispersion unless added. |
| Skarstrom step meanings | Section 2.2.1, pp. 7-8 | Defines feed, product, purge, repressurisation, and depressurisation roles. |
| Pressure-flow models | Sections 2.1.6-2.1.7 and 2.2.3, pp. 6-9 | Distinguish Ergun, Kozeny-Carman, and no-pressure-drop modes. |
| Boundary conditions | Section 2.2.4 and Table 2, pp. 8-9 | Defines Type I-VII boundary conditions and the special Type VII constant-pressure rule. |
| Initial and terminal conditions | Section 2.2.5, pp. 9-10 | Explains consistency requirements and event termination. |
| PFD and tanks | Section 3.1 and Figure 5, pp. 10-11 | Defines feed, adsorber network, raffinate section, extract section, and dynamic tanks. |
| Simulation inputs | Section 3.3, pp. 11-12 | Defines global pressure-drop mode, cycle strings, event syntax, and step string grammar. |
| Solution algorithm | Section 3.4, p. 12 | Explains ODE-with-inner-flow-calculation, LP recourse, and flow-direction guess/check. |
| Outputs and metrics | Sections 2.4 and 3.5, pp. 10 and 12 | Defines native product purity, recovery, productivity, and energy metrics. |
| Flow reversal | Section 4.4.1, pp. 15-16 | Explains why reversal can happen even in well-tuned cycles. |
| Controlled simulations and events | Section 4.4.2, pp. 16-17 | Explains controlled flow-driven mode and event advantages/limits. |
| CSS acceleration | Section 4.4.3, p. 17 | Explains why events can reduce cycles to CSS and why multi-bed conflicts occur. |
| Constant-pressure linear system | Appendix A, p. 18 | Implementation detail for Type VII plus no-pressure-drop mode. |
| Dimensionless model | Appendix B, pp. 18-19 | Useful if debugging scale factors or nondimensional units. |

Dissertation source map additions:

| Topic | Dissertation location | Use in development |
|---|---|---|
| Validation and edge-case roadmap | Chapter 6, pp. 240-245 | Use validation residuals and explicit unsupported-feature labels to decide extensions; do not tune before ledgers and metric basis pass. |
| Adsorption model catalogue | Appendix D, pp. 259-268 | Distinguish explicit native models from implicit or future models; add unsupported-model gates for gL, MS-LDF, S-shaped isotherms, and hysteresis. |
| Tank/MFC/valve semantics | Chapter 3, pp. 137-147 | Keep fixed-composition source semantics separate from dynamic tanks; distinguish linear valves, BPRs, check valves, and combined BPR/check outlets. |
| Native metrics and product streams | Chapter 3, pp. 161-164 | Separate column-boundary product, tank inventory, and external product after the tank outlet when reconstructing literature metrics. |
| Dimensionless scaling | Chapter 3, pp. 165-166 and pp. 189-191 | Non-Excel manifests must feed the same CIS scaling path; label dimensional versus dimensionless cumulative quantities. |
| Simulation workflow | Chapter 4, pp. 198-216 | Preserve `runPsaProcessSimulation`, `getSimParams`/`getExcelParams`, RHS construction, cycle simulation, event checks, CSS, plotting, and CSV export workflow. |
| LP recourse and flow reversals | Chapter 5, pp. 226-230 | Preserve guess-and-check fast path, log LP fallback, and treat flow reversal as diagnostic data rather than automatic failure. |
| Event-controlled CSS acceleration | Chapter 5, pp. 231-236 | Treat event acceleration as mode-dependent; pressure-driven runs did not show the same trend and multi-bed event objectives can conflict. |
| Four-bed and layering limitations | Chapter 6, pp. 239-243 | Treat more than two adsorbers, bed layering, and multiple equalisation as unsupported until implemented and tested. |
| Output and file structure | Appendix E, pp. 270-279 | Keep programmatic entry points, example folder structure, output `1 figs`/`2 data`, and `.xlsm` import compatibility unless deliberately replaced. |
| Node count and numerical diffusion | Appendix B, p. 249 | Do node-count/MTZ sensitivity before claiming model mismatch or adding axial dispersion. |

Code anchors in the current repository:

| Code path | Why Codex must inspect it |
|---|---|
| `3_source/1_parameters/getFlowSheetValves.m` | Converts step strings into PFD interaction matrices. Confirms what each step connects. |
| `3_source/4_rhs/1_volumetricFlowRates/4_pre_computations/getVolFlowFuncHandle.m` | Assigns boundary flow functions for each native elementary step and simulation mode. |
| `3_source/1_parameters/getStringParams.m` | Parses step strings, flow direction, DAE type, and equalisation pairings. |
| `3_source/5_cycle/2_eventFunctions/getEventFuncs.m` | Current event functions are hardcoded for adsorbers 1 and 2, plus tanks/streams. This matters for 4-bed work. |
| `3_source/5_cycle/3_performanceMetrics/getPerformanceMetrics.m` | Native metric basis. Must not be confused with Schell's reporting basis. |
| `scripts/build_schell_runnable_params.m` | Current Schell adapter. Contains central-case schedule, pressure choices, tank initialisation, and purge mapping. |
| `2_run/runPsaProcessSimulation.m` | Programmatic simulation entry point; must remain usable without GUI-only state. |
| `3_source/1_parameters/getSimParams.m` and `getExcelParams.m` | Import, validate, sort, scale, and precompute the `params` structure. Non-Excel manifests must not bypass this contract without parity tests. |
| `3_source/5_cycle/runPsaCycle.m` | Cycle loop: CSS check, step simulation, event check, metric calculation, and terminal-state handoff. |
| `3_source/6_output/savePsaSimulationResults.m` and plotting/output helpers | CSV trajectories, figures, and generated diagnostics should remain reproducible and tied to run manifests. |

---
