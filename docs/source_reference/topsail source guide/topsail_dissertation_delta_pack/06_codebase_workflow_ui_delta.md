# 06 - Codebase workflow, UI, and file-structure delta

This file is for agents navigating toPSAil internals. It is not a user manual for clicking the GUI, because Codex does not need a motivational speech about green spreadsheet cells.

## Folder and file structure anchors

| Structure item | Dissertation source | Codex-facing meaning | Do not break |
|---|---|---|---|
| Main folders: `0 archive`, `1 config`, `2 run`, `3 source`, `4 example`, `5 reference`, `6 publication` | Diss p. 270-271 (PDF p. 305-306), Appendix E §E.3, Figure E.2 | Treat `3 source` as implementation code, `2 run` as execution wrappers, and `4 example` as case data. | Do not move code/data in ways that break path setup. |
| `2 run/definePath2SourceFolders.m` | Diss p. 271-272 (PDF p. 306-307), Appendix E §E.3.1 | Adds source/example paths. Inspect before adding new manifest folders. | Do not require GUI-only paths for programmatic runs. |
| `2 run/programProfiler.m` | Diss p. 272 (PDF p. 307), Appendix E §E.3.1 | Quick profiling and user-defined test simulation hook. | Keep usable for numerical benchmarks and smoke tests. |
| `2 run/runPsaProcessSimulation.m` | Diss p. 272 (PDF p. 307), Appendix E §E.3.1 | Programmatic simulation entry point; takes an example folder directory string. | Do not make the GUI the only entry point. |
| `2 run/runPsaProcessSimulationApp.mlapp` | Diss p. 272 and 277 (PDF p. 307 and 312), Appendix E §E.3.1 and §E.4.2 | GUI wrapper around the run flow. | Do not couple core simulation logic to GUI state. |
| Example case folder: `1 simulation inputs`, `2 simulation outputs`, `3 reference info`, `4 additional plots` | Diss p. 272-273 (PDF p. 307-308), Appendix E §E.3.2, Figure E.4 | Use examples as reproducible case folders. Source documents belong in `3 reference info`; extra diagnostics can live in `4 additional plots`. | Do not overwrite reference info or hide generated outputs outside the case folder. |
| Output subfolders: `2 simulation outputs/1 figs` and `2 simulation outputs/2 data` | Diss p. 273 (PDF p. 308), Appendix E §E.3.2 | Save plots as PDFs and solution data as CSV files by category. | Do not change output paths without a compatibility shim. |
| Input spreadsheets under `1 simulation inputs` | Diss p. 274 (PDF p. 309), Appendix E §E.4.1, Figure E.5 | The source of current parameter categories and file naming. | Do not break `.xlsm` import paths unless replacing them deliberately. |
| `3 source` | Diss p. 279 (PDF p. 314), Appendix E §E.5.2 | Location for MATLAB source modifications and new submodels. | New submodels must not break existing model selection/imports. |

## Input data categories and source-pack mapping

| toPSAil input category/file group | Dissertation source | Source-pack fields that should map here | Codex note |
|---|---|---|---|
| `0.1 simulation configurations.xlsm` | Diss p. 203 (PDF p. 238), §4.2.3; Diss p. 276 (PDF p. 311), §E.4.1 | Model assumptions, submodel IDs, product recovery mode, number of adsorbers, heat/pressure-drop mode. | Boolean/integer model selectors are converted into function handles; validate against `getSubModels`/model-selection code. |
| `0.2 numerical methods.xlsm` | Diss p. 199-200 (PDF p. 234-235), §4.2.2; Diss p. 276 (PDF p. 311), §E.4.1 | Solver options, tolerances, event settings if stored globally, JPattern settings. | Preserve ode15s options and event-function hooks. |
| `0.3 simulation outputs.xlsm` | Diss p. 276 (PDF p. 311), §E.4.1 | Plot/output toggles and requested export categories. | [INFERENCE] Add ledger/export toggles here or in a manifest wrapper. |
| `1.x physical properties` | Diss p. 200-201 (PDF p. 235-236), §4.2.2; Diss p. 276-277 (PDF p. 311-312), §E.4.1 | Adsorbate properties, adsorbent properties, constants, isotherm/rate parameters. | Match Appendix D parameter counts exactly. |
| `2.x stream properties` | Diss p. 201 (PDF p. 236), §4.2.2; Diss p. 277 (PDF p. 312), §E.4.1 | Feed stream, raffinate stream, extract stream, product/waste external conditions. | Fixed-composition literature sources should not be represented as dynamic product tanks without a manifest. |
| `3.x unit properties` | Diss p. 201 (PDF p. 236), §4.2.2; Diss p. 277 (PDF p. 312), §E.4.1 | Adsorber geometry, tank volumes/pressures, compressors, vacuum pump, valve constants, BPR setpoints. | Keep pressure names separated: feed tank, column high/low, product tank, BPR, event target. |
| `4.1 cycle organization.xlsm` | Diss p. 201-202 (PDF p. 236-237), §4.2.2; Diss p. 274-275 (PDF p. 309-310), §E.4.1 | Step strings, durations, event type/location, number of steps, number of adsorbers. | For four-bed work, do not assume this file can express unsupported schedules without extension. |

## Simulation workflow anchors

| Workflow stage | Dissertation source | Implementation details to preserve |
|---|---|---|
| Top-level run | Diss p. 198-199 (PDF p. 233-234), §4.2.1 | `runPsaProcessSimulation.m` calls initialization, cycle simulation, plotting, and saving. |
| Import and parameter synthesis | Diss p. 202-203 (PDF p. 237-238), §4.2.3 | `getSimParams.m` calls `getExcelParams.m`, uses custom sorting to build a parameter data structure with typed fields and dimensions. |
| Input validation | Diss p. 203 (PDF p. 238), §4.2.3 | Missing parameters or type mismatches are errors; dimensionless transforms occur inside `getSimParams.m`. |
| Model selection | Diss p. 203 (PDF p. 238), §4.2.3 | Boolean/integer parameters choose model equations and define submodel function handles. |
| Precomputations | Diss p. 203-204 (PDF p. 238-239), §4.2.3 | Computes scaling factors using isotherm, rate expression, equilibrium theory, MTZ theory, feed physical properties, dimensionless params, and initial vector. |
| Simulation specialisation | Diss p. 204 (PDF p. 239), §4.2.3 | Defines boundary-condition and event-function handles for all adsorbers and steps; stores valve configurations and step durations in `params`. |
| RHS evaluation | Diss p. 206-208 (PDF p. 241-243), §4.2.4, Algorithm 1 | Unpack `p` and `xt`; build `units.col`, `units.feTa`, `units.raTa`, `units.exTa`; call `makeCol2Interact`; call `funcVol`; evaluate balances; concatenate via `getRhsFuncVals`. |
| Cycle simulation | Diss p. 213-215 (PDF p. 248-250), §4.2.5, Algorithm 2 | Check CSS at cycle start; simulate each step; compute metrics only at last step; terminal state becomes next initial state; check events; update time span. |
| Output processing | Diss p. 216 (PDF p. 251), §4.2.6 | Export CSV state trajectories for all adsorbers and auxiliary units; plot pressure/temperature histories, axial profiles, and performance metrics vs cycle. |

## Suggested non-Excel manifest placement

- [INFERENCE] Put machine-readable Codex manifests under `4 example/<case>/1 simulation inputs/manifests/` so they travel with the case inputs. Source for case structure: Diss p. 272-273 (PDF p. 307-308), Appendix E §E.3.2.
- [INFERENCE] Put source PDFs, parameter tables, and literature notes under `4 example/<case>/3 reference info/`. Source: Diss p. 273 (PDF p. 308), Appendix E §E.3.2 says this folder contains original sources of simulation parameters.
- [INFERENCE] Put generated ledger plots and Python dashboards under `4 example/<case>/4 additional plots/` or `2 simulation outputs/1 figs`, depending whether they are official outputs or extra analysis. Source: Diss p. 273 (PDF p. 308), Appendix E §E.3.2.
- [INFERENCE] A future non-Excel loader should feed into the same `params` structure after validation and scaling, rather than bypassing `getSimParams.m`. Source: Diss p. 202-204 (PDF p. 237-239), §4.2.3.

## Codex must not break

1. The dimensionless scaling/precomputation path in `getSimParams.m`. Source: Diss p. 203-204 (PDF p. 238-239), §4.2.3.
2. Programmatic execution through `runPsaProcessSimulation.m`. Source: Diss p. 272 (PDF p. 307), Appendix E §E.3.1.
3. Output CSV generation in `2 simulation outputs/2 data`. Source: Diss p. 273 (PDF p. 308), Appendix E §E.3.2 and Diss p. 216 (PDF p. 251), §4.2.6.
4. LP-solver availability for no-pressure-drop fallback. Source: Diss p. 211 (PDF p. 246), §4.2.4 and Diss p. 270 (PDF p. 305), Appendix E §E.2 says the MATLAB Optimization Toolbox is needed.
5. The ability to add new submodels in `3 source` without corrupting existing model selection. Source: Diss p. 279 (PDF p. 314), Appendix E §E.5.2.
