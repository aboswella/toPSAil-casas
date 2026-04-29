# 08 - Codex task cards from dissertation deltas

Each card is scoped so a future agent can work without reading the whole dissertation. Humanity may yet recover.

## Card 1 - Add dissertation-backed boundary, tank, and product ledgers

| Field | Content |
|---|---|
| Context files required | Existing pack `02`, `03`, `05`, `06`; delta `03`, `05`, `06`, `09`. |
| Objective | Export per-step, per-bed, per-component transfers across adsorber boundaries, tanks, external products, wastes, compressors, and vacuum pump. |
| Source sections to use | Diss p. 137-140 (PDF p. 172-175), §3.2.5; Diss p. 204 and 207 (PDF p. 239 and 242), §4.2.4; Diss p. 216 (PDF p. 251), §4.2.6. |
| Files likely to inspect | `defineRhsFunc.m`, `getColCuMolBal*`, `getFeTaCuMolBal*`, `getRaTaCuMolBal*`, `getExTaCuMolBal*`, `getRaWaCuMolBal*`, `getExWaCuMolBal*`, `savePsaSimulationResults.m`, `getPerformanceMetrics.m`. |
| Implementation constraints | Label dimensional vs dimensionless units; separate tank inventory, column boundary product, external product, and waste. Do not use native metrics as source-paper metrics. |
| Required tests | Component conservation per cycle; HP product enters intended sink; purge source identity; external product differs from tank inventory when BPR closed; ledger CSV schema test. |
| Stop conditions | Stop if required cumulative states are unavailable or if dimensional scaling cannot be verified. |
| Expected deliverables | `step_boundary_ledger.csv`, `tank_history.csv`, `product_tank_vs_external_product.csv`, `mass_balance_residuals.csv`, tests. |

## Card 2 - Verify fixed-composition stream, MFC, tank, and valve semantics for Schell

| Field | Content |
|---|---|
| Context files required | Existing pack `02`, `03`, `04`, `06`; delta `03`, `05`, `06`, `09`. |
| Objective | Decide whether Schell fixed-composition feed/purge streams can be represented with native feed/product tanks or require a custom source/PFD extension. |
| Source sections to use | Diss p. 133-140 (PDF p. 168-175), §3.2.4-§3.2.5; Diss p. 145-147 (PDF p. 180-182), §3.3.4; Diss p. 193-196 (PDF p. 228-231), §4.1.1. |
| Files likely to inspect | `getFlowSheetValves.m`, `getVolFlowFuncHandle.m`, `makeFeedTank.m`, `makeRaffTank.m`, `makeExtrTank.m`, valve/BPR helper functions, Schell adapter/build scripts. |
| Implementation constraints | A seeded tank is not a fixed-composition reservoir. A plain BPR is not necessarily a check valve. Feed tank MFC maintains pressure, not arbitrary literature flow composition semantics. |
| Required tests | Fixed feed tank pressure MFC balance; product tank outlet check/BPR closed-below-setpoint; purge source remains fixed only if implemented as fixed source; tank composition evolves under native cycle. |
| Stop conditions | Stop if Schell purge requires a PFD element absent from native toPSAil; document limitation rather than patching silently. |
| Expected deliverables | `schell_stream_semantics_audit.md`, failing/passing tests, source/sink manifest update. |

## Card 3 - Add CSS convergence and event diagnostics

| Field | Content |
|---|---|
| Context files required | Existing pack `04`, `08`; delta `03`, `05`, `07`. |
| Objective | Implement/export CSS error, CSS state mask, event trigger data, and event-priority metadata. |
| Source sections to use | Diss p. 201 (PDF p. 236), §4.2.2; Diss p. 213-216 (PDF p. 248-251), §4.2.5; Diss p. 234-236 (PDF p. 269-271), §5.5.3. |
| Files likely to inspect | `runPsaCycle.m`, `getEventFuncs.m`, event helper functions, `getPerformanceMetrics.m`, plotting/save functions. |
| Implementation constraints | CSS formula is normalized squared L2 difference. Multi-bed events require explicit priority policy. Event acceleration is not guaranteed, especially pressure-driven. |
| Required tests | CSS formula regression; full-state vs adsorber-only mask; event location/type export; conflicting events require policy; pressure-driven caveat field. |
| Stop conditions | Stop if current event functions are hardcoded to two adsorbers and task requires bed 3/4 events. |
| Expected deliverables | `css_convergence.csv`, `css_state_mask.json`, `event_diagnostics.csv`, `event_priority_policy.json`, plots/tests. |

## Card 4 - Preserve and expose numerical performance diagnostics

| Field | Content |
|---|---|
| Context files required | Delta `03`, `05`, `06`; existing pack `04`. |
| Objective | Add diagnostics for LP recourse fraction, flow-reversal episodes, JPattern availability, and solver mode. |
| Source sections to use | Diss p. 226-228 (PDF p. 261-263), §5.4; Diss p. 229-230 (PDF p. 264-265), §5.5.1; Diss p. 210-211 (PDF p. 245-246), §4.2.4. |
| Files likely to inspect | `getVolFlowFuncHandle.m`, no-pressure-drop volumetric-flow functions, Ergun/Kozeny-Carman flow functions, `odeset` option builders. |
| Implementation constraints | Do not remove guess-and-check fast path. Do not replace sign-agnostic pseudo-flow balances with fixed-sign balances. Preserve/provide sparse Jacobian patterns. |
| Required tests | LP fallback on forced reversal; fast-path matches LP result on small case; flow reversal logged; JPattern dimensions and RHS-output equivalence. |
| Stop conditions | Stop if an optimisation changes numerical results without a conservation/accuracy explanation. |
| Expected deliverables | `lp_recourse_by_step.csv`, `flow_reversal_diagnostics.csv`, JPattern tests, benchmark summary. |

## Card 5 - Build non-Excel manifest bridge without breaking Excel workflow

| Field | Content |
|---|---|
| Context files required | Delta `06`, `09`; existing pack `08`. |
| Objective | Add machine-readable manifests for source parameters, pressures, connectivity, metrics, and diagnostics while preserving current `.xlsm` import. |
| Source sections to use | Diss p. 198-204 (PDF p. 233-239), §4.2.1-§4.2.3; Diss p. 270-277 (PDF p. 305-312), Appendix E §E.3-§E.4.1. |
| Files likely to inspect | `getSimParams.m`, `getExcelParams.m`, `definePath2SourceFolders.m`, example folders, input spreadsheets, Schell adapter. |
| Implementation constraints | Non-Excel manifests must feed the same `params` structure or a tested equivalent. Do not bypass dimensionless scaling/precomputations. |
| Required tests | Manifest-to-params round trip; Excel-to-params parity for a small case; missing/type mismatch errors; path setup with manifest folder. |
| Stop conditions | Stop if manifest loader cannot reproduce current Excel-imported params. |
| Expected deliverables | `manifests/` folder convention, loader, parity tests, `run_manifest.json`. |

## Card 6 - Audit adsorption submodels and unsupported emerging models

| Field | Content |
|---|---|
| Context files required | Delta `02`, `03`, `09`; existing pack `01` only if comparing base model assumptions. |
| Objective | Produce a code-backed catalogue of native isotherm/rate models and explicit unsupported-model gates for gL, MS-LDF, S-shaped/hysteresis models. |
| Source sections to use | Diss p. 24 (PDF p. 59), §1.3.2; Diss p. 240-241 (PDF p. 275-276), §6.2.2; Diss p. 259-268 (PDF p. 294-303), Appendix D. |
| Files likely to inspect | `getSubModels.m`, isotherm function folder, rate-model function folder, parameter import/validation code. |
| Implementation constraints | Verify code before claiming support. Do not alias gL/MS-LDF to existing explicit models. New models need dimensional/dimensionless tests. |
| Required tests | Parameter-count validation per model; pure-component limits; dimensionless round trip; unsupported-model raises clear error; fsolve/implicit model convergence if multi-site Langmuir exists. |
| Stop conditions | Stop if source paper requires an unsupported model and task is validation rather than model implementation. |
| Expected deliverables | `adsorption_model_capability_manifest.json`, tests, unsupported-model errors. |

## Card 7 - Four-bed capability audit and explicit feature gates

| Field | Content |
|---|---|
| Context files required | Delta `07`, `03`, `05`, `06`, `09`; existing pack `07`, `08`. |
| Objective | Determine which code paths can support four adsorbers and add fail-fast gates for unsupported paths. |
| Source sections to use | Diss p. 192 (PDF p. 227), §4.1; Diss p. 201 (PDF p. 236), §4.2.2; Diss p. 239 (PDF p. 274), §6.1; Diss p. 243 (PDF p. 278), §6.2.4. |
| Files likely to inspect | State-vector builders, `getStringParams.m`, `getFlowSheetValves.m`, `getVolFlowFuncHandle.m`, `getEventFuncs.m`, plotting code, `getPerformanceMetrics.m`. |
| Implementation constraints | Current version is dissertation-described as not supporting >2 adsorbers. Do not enable `nAds=4` until audit/tests pass. |
| Required tests | Four-bed initialization or explicit rejection; event parser bed 3/4 behavior; valve matrix dimensions; plotting disabled path; metrics sum over all adsorbers. |
| Stop conditions | Stop if any two-bed hardcoding affects state, event, valve, metric, or plotting behavior. |
| Expected deliverables | `four_bed_capability_audit.md`, feature gates, tests. |

## Card 8 - Four-bed scheduler and event-conflict policy prototype

| Field | Content |
|---|---|
| Context files required | Delta `07`, `03`, `05`; existing pack `03`, `07`, `08`. |
| Objective | Build a global schedule representation for four-bed cycles with explicit equalisation pairs, shared-tank usage, and event priority. |
| Source sections to use | Diss p. 193 and 195 (PDF p. 228 and 230), §4.1.1; Diss p. 235-236 (PDF p. 270-271), §5.5.3; Diss p. 243 (PDF p. 278), §6.2.4. |
| Files likely to inspect | Adapter/scheduler scripts, cycle organization parser, event-function builder, valve-matrix builder. |
| Implementation constraints | One active connection per adsorber end. Equalisation is bidirectional. Event priority is source/case data, not hardcoded. |
| Required tests | No negative durations; one-end-one-connection; equalisation pair map; conflicting events require policy; shared tank ledger by bed/component. |
| Stop conditions | Stop if native cycle organization cannot represent required pairings without extension. |
| Expected deliverables | `global_cycle_manifest.csv`, `equalization_pair_map.csv`, `event_priority_policy.json`, scheduler tests. |

## Card 9 - Build dissertation-backed visual diagnostics

| Field | Content |
|---|---|
| Context files required | Delta `05`, `06`, `07`; existing pack `05`, `08`. |
| Objective | Produce static and CSV-driven visual diagnostics for tank histories, axial profiles, CSS, events, product accounting, and four-bed timeline. |
| Source sections to use | Diss p. 216 (PDF p. 251), §4.2.6; Diss p. 245 (PDF p. 280), §6.2.5; Diss p. 272-273 (PDF p. 307-308), Appendix E §E.3.2. |
| Files likely to inspect | `plotPsaSimulationResults.m`, `savePsaSimulationResults.m`, output CSV writers, `4 additional plots` scripts. |
| Implementation constraints | Use CSV trajectories as the common substrate. Keep plotting optional for first four-bed simulation. Label native vs reconstructed metrics. |
| Required tests | Output files exist; plots do not block simulation; CSV schema stable; four-bed plotting optional. |
| Stop conditions | Stop if CSV exports are incomplete for required units/components. |
| Expected deliverables | Diagnostic plots, animation script prototype, `run_manifest.json`, tests. |

## Card 10 - Post-validation design/control harness

| Field | Content |
|---|---|
| Context files required | Delta `04`, `01`, `03`, `05`; existing pack `05`, `08`. |
| Objective | Build a reproducible design/control run harness after Schell or other validation passes. |
| Source sections to use | Diss p. 241-242 (PDF p. 276-277), §6.2.3; Diss p. 231-234 (PDF p. 266-269), §5.5.2; Diss p. 252-258 (PDF p. 287-293), Appendix C. |
| Files likely to inspect | Case builders, event configuration, metrics exporters, run database/export tools. |
| Implementation constraints | No optimisation before ledgers and metric basis pass. Valve-free policy and surrogates are research-only unless scoped separately. |
| Required tests | Reproducible sweep manifest; validation gate check; event-controlled run outputs; no unsupported model use. |
| Stop conditions | Stop if source fidelity is unproven or if optimisation objective uses native metrics incompatible with literature basis. |
| Expected deliverables | `design_sweep_manifest.json`, run database, validation gate, controlled-run report. |
