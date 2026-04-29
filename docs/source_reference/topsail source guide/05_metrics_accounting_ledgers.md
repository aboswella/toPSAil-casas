# 05 - Metrics, accounting basis, and diagnostic ledgers

Primary source: Taehun Kim and Joseph K. Scott, *Dynamic modeling and simulation of pressure swing adsorption processes using toPSAil*, Computers and Chemical Engineering 176, 108309, 2023.

This is a split-out Codex context file derived from `topsail_paper_source_extraction_schell_4bed.md`. Use it only for tasks where its scope is relevant. Yes, context discipline: the thrilling frontier of not making the next agent read a small novella.

---

## 6. Native performance metrics versus Schell reporting

### 6.1 Native toPSAil metrics

Paper facts:

Native metrics are calculated for each complete cycle and include:

- product purity: species mole fraction in total raffinate or extract product generated during that cycle;
- throughput: total moles of raffinate or extract product;
- recovery: species moles in the native product stream divided by species moles fed;
- productivity: throughput divided by cycle time;
- energy consumption.

Current code anchor:

- `getPerformanceMetrics.m` calculates native raffinate product moles and native extract product moles, then divides by feed moles.
- Light-key purity/recovery is based on native raffinate product.
- Heavy-key purity/recovery is based on native extract product.

### 6.2 Schell reporting basis

Existing Schell source reference states:

- H2-rich product is computed directly from adsorption product flow and composition.
- CO2-rich product is computed by subtraction from component input inventory.
- Mean values are taken over both columns and three cycles.

Development consequences:

- Do not compare native extract recovery directly to Schell CO2 recovery unless a report explicitly states the basis and reconstructs the same accounting.
- A native CO2 recovery above 100% is not automatically a thermodynamic or isotherm failure. It can be an accounting-basis or stream-routing symptom.
- The Schell validation extractor should emit both:
  - native direct metrics;
  - Schell-basis metrics.

Required Schell metric extractor fields:

```text
cycle_index
column_index
feed_input_moles_by_component
pressurisation_input_moles_by_component
adsorption_feed_input_moles_by_component
purge_input_moles_by_component
H2_rich_adsorption_product_moles_by_component
native_raffinate_external_product_moles_by_component
native_extract_external_product_moles_by_component
Schell_basis_CO2_product_by_subtraction
native_direct_purity_recovery
Schell_basis_purity_recovery
mass_balance_residual_by_component
```

---

### 6.3 Dissertation metric-basis refinements

The dissertation refines the native-metric warning:

| Issue | Dissertation evidence summary | Development consequence |
|---|---|---|
| Product purity may be tank-state based in the dissertation formula. | Purity is expressed using product-tank composition at final time for the relevant product stream. | Verify current `getPerformanceMetrics.m`; reconstruct source metrics from ledgers regardless of the native label. |
| Product recovery uses the stream after the product tank. | Recovery is based on cumulative moles in the stream after the product tank divided by feed cumulative moles. | Export column boundary, tank inventory, and external outlet ledgers separately. |
| Native energy terms may include feed compression and vacuum/extract work. | Feed compression can be skipped if feed is already above `P_f`; vacuum work can be skipped if `P_l >= P_a`. | Literature comparisons must state which native energy terms are included or excluded. |
| Native metrics are insufficient for non-ideal or unsupported models. | The dissertation warns existing simulators may not calculate reliable metrics for unsupported models. | Add model-capability status to validation reports and avoid comparing unsupported-model outputs as if they were validated. |

### 6.4 Required dissertation-backed plots, ledgers, and reports

| Required output | Why it matters | Suggested file/function names |
|---|---|---|
| Per-step boundary and tank transfer ledger | Shows whether HP product enters the intended sink, whether purge consumes raffinate material, and whether extract/waste/product accounting is separated. | `exportStepBoundaryLedger.m`, `write_step_boundary_ledger_csv.m`, `step_boundary_ledger.csv` |
| Tank pressure/composition histories for T-1, T-2, T-3 | Catches dynamic tank misuse, especially treating seeded raffinate or extract tanks as fixed-composition reservoirs. | `plotTankHistories.m`, `tank_history.csv`, `plot_tank_composition_pressure.py` |
| External product outlet vs internal product-tank inventory report | Prevents comparing tank inventory, column outlet, and external product stream as if they were the same product. | `exportProductOutletLedger.m`, `product_tank_vs_external_product.csv` |
| Axial pressure, composition, and temperature profiles by adsorber and step | Reveals breakthrough, reversal symptoms, pressure inconsistency, and bed-state mismatch across cycles. | `plotAxialProfilesByStep.m`, `axial_profile_cycle_step_col.csv` |
| Flow-reversal and LP-recourse diagnostics | Distinguishes acceptable brief reversals from persistent wrong connectivity. | `exportFlowReversalDiagnostics.m`, `lp_recourse_by_step.csv`, `plot_flow_signs_by_node.py` |
| CSS convergence plot | Confirms cycle convergence and exposes fixed-duration/event-driven differences without relying only on final-cycle metrics. | `plotCssConvergence.m`, `css_convergence.csv`, `css_state_mask.json` |
| Event diagnostics report | Shows whether steps ended by duration or event, where the event occurred, and what target was actually met. | `exportEventDiagnostics.m`, `event_diagnostics.csv` |
| Native plus reconstructed literature metric dashboard | Keeps source-paper accounting separate from native direct product metrics. | `exportMetricBasisDashboard.m`, `native_metrics.csv`, `literature_reconstructed_metrics.csv` |
| Four-bed global timeline/Gantt chart | Makes simultaneous steps, idle slots, equalisation pairs, and event-priority conflicts visible. | `plotGlobalCycleTimeline.m`, `four_bed_timeline.csv`, `equalization_pair_map.csv` |
| Shared-tank Sankey or component-flow ledger | Prevents accidental use of a product tank as a hidden source while another bed fills it. | `exportSharedTankLedger.m`, `plot_shared_tank_sankey.py` |
| CSV-driven animation of cycle dynamics | Supports downstream diagnostics and comparison of dynamic PSA cycles, especially multi-bed schedules. | `animatePsaCycleFromCsv.py`, `make_population_pyramid_cycle_animation.py` |
| Output/run manifest | Ties plots, CSVs, source references, and input manifests together for reproducible Codex work. | `writeRunManifest.m`, `run_manifest.json` |

Output-processing rules:

- CSV trajectories are the canonical diagnostic substrate. Use them for Python dashboards and animations rather than scraping MATLAB plots.
- Plot generation must be optional for the first four-bed validation path; simulation correctness should not depend on plotting.
- Every report should label dimensional versus dimensionless quantities.
- Multi-bed event plots must show both selected and suppressed objectives so event-priority decisions can be audited.
