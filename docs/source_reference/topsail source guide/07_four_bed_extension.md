# 07 - Future 4-bed system extraction

Primary source: Taehun Kim and Joseph K. Scott, *Dynamic modeling and simulation of pressure swing adsorption processes using toPSAil*, Computers and Chemical Engineering 176, 108309, 2023.

This is a split-out Codex context file derived from `topsail_paper_source_extraction_schell_4bed.md`. Use it only for tasks where its scope is relevant. Yes, context discipline: the thrilling frontier of not making the next agent read a small novella.

---

## 8. Future 4-bed system extraction

### 8.1 What the paper says and what it does not say

Paper and dissertation facts:

- The PFD figure and user-interface description focus on two adsorbers.
- The earlier paper pack left broader support ambiguous because the paper states that the code base supports multiple adsorbers while the current user interface is limited to two adsorbers.
- The dissertation is stricter: current toPSAil "does not support" bed layering, more than two adsorbers, or multiple equalisation steps.
- The dissertation also says the available step list considers up to two-adsorber interactions.
- Multi-adsorber event-based control is hard because different adsorbers can have conflicting objectives and no general approach is given.

Development consequence:

- A future 4-bed implementation must not use the GUI/Excel assumptions blindly.
- Treat 4-bed support as a new simulator capability, not merely `nCols = 4`.
- Add fail-fast gates for unsupported paths before comparing any four-bed performance metrics.

### 8.2 4-bed audit list

Before implementing any 4-bed source paper, Codex must audit these code paths:

| Area | Code anchor | Risk |
|---|---|---|
| Column state vector sizing | `getStatesParams.m`, conversion helpers | Usually generalisable, but must prove with `nCols = 4`. |
| Step string parsing | `getStringParams.m` | Generalises arrays but equalisation pairing is by row order. |
| Equalisation pairing | `getStringParams.m` | Even number required; pairs are assigned in ascending/nonzero order. Cannot express arbitrary pairs unless row ordering or code is extended. |
| Flow-sheet valve matrices | `getFlowSheetValves.m` | Matrices are `nCols x nSteps`, likely general, but test simultaneous multi-column interactions. |
| Boundary function assignment | `getVolFlowFuncHandle.m` | Step-based and likely reusable, but new step strings require explicit cases. |
| Event functions | `getEventFuncs.m` and `getAds1...`, `getAds2...` functions | Current bed-specific events are hardcoded for adsorbers 1 and 2. Needs generic event generator or Adsorber_3/4 support. |
| Product metrics | `getPerformanceMetrics.m` plus helper functions | Must confirm products sum over all columns and cycles correctly. |
| Plotting/output | plotting and report scripts | Likely two-bed assumptions. Make plotting optional for first 4-bed validation. |
| CSS convergence | CSS functions in `getSubModels.m` and cycle code | Must confirm all four column states included and normalised consistently. |
| Schedule representation | adapter/build scripts | Needs global time-slot schedule, not two-bed hand splits. |

### 8.3 Equalisation in 4-bed schedules

Current code behaviour to verify:

- In a given global step, all rows with `EQ-AFE-XXX` are collected.
- The count must be even.
- The nonzero row indices are paired sequentially: first with second, third with fourth, etc.
- The same pattern applies to `EQ-XXX-APR`.

4-bed consequence:

- A global step with beds 1 and 3 equalising, and beds 2 and 4 not equalising, is probably representable if only rows 1 and 3 contain the equalisation step.
- A global step with simultaneous pairs 1-4 and 2-3 may not be representable unless row ordering or explicit pair metadata is introduced, because sequential pairing by index would produce 1-2 and 3-4 if all four are marked.
- Add a test that verifies intended pair mapping for every 4-bed schedule slot.

Required 4-bed equalisation manifest:

```text
global_step_index
equalisation_end: feed_end | product_end
active_pair_1: column_i <-> column_j
active_pair_2: column_k <-> column_l
native_step_rows
expected_numAdsEqFeEnd_or_numAdsEqPrEnd_matrix_entries
```

### 8.4 Events in 4-bed schedules

Paper and code facts:

- The paper describes event locations for two adsorbers and tanks/streams.
- Current `getEventFuncs.m` supports `Adsorber_1_*` and `Adsorber_2_*`, not `Adsorber_3_*` or `Adsorber_4_*`.
- Event functions are one per global step.

4-bed consequence:

- Add generic event functions before relying on bed-specific events for beds 3 and 4.
- Decide how to handle simultaneous objectives. The paper gives no general solution.
- For initial 4-bed implementation, fixed-duration schedules may be more robust than event-driven schedules until the event conflict policy is explicit.

Required event policy for 4-bed:

```text
For each global step:
- Are there zero, one, or multiple candidate events?
- If one event controls the global step, which bed and why?
- If multiple events conflict, which has priority?
- Does priority damage another bed's source-step duration or product accounting?
- Is a fixed-duration fallback source-backed?
```

### 8.5 Shared tanks in 4-bed systems

The paper PFD has one feed tank, one raffinate tank, and one extract tank. With four adsorbers, simultaneous interactions can create shared-source and shared-sink effects.

4-bed required ledger:

```text
for each global step:
- number of beds drawing from feed tank
- number of beds sending to raffinate tank
- number of beds drawing from raffinate tank
- number of beds sending to extract tank
- number of beds drawing from extract tank
- net tank mole change by component
- tank pressure/composition before and after the step
```

Risk:

- A 4-bed cycle can accidentally draw purge/repressurisation material from the same product tank that another bed is filling in the same global step.
- This may be intended in some cycles, but it must be documented. Otherwise the model becomes gas accounting by assumption.

---

### 8.6 Dissertation-specific four-bed hazards

| Hazard | Consequence | Required invariant/test | Suggested task |
|---|---|---|---|
| Assuming `nAds = 4` is already supported | Hidden two-bed assumptions may corrupt states, events, valves, metrics, or plots. | `test_four_bed_requires_feature_gate_or_passes_full_audit` | Add explicit unsupported guard, then audit code paths before enabling. |
| Predefined elementary steps encode only up to two-adsorber interactions | Four-bed equalisation/pairing cannot be inferred safely from existing names. | `test_step_catalog_declares_max_adsorber_interaction_count` | Add explicit pair metadata for equalisation and cross-bed interactions. |
| Multiple equalisation steps are unsupported | Industrial four-bed cycles with staged equalisation may be unrepresentable. | `test_multiple_equalization_steps_fail_fast_until_implemented` | Implement schedule representation with pair map and stage index. |
| Combinatorial connection growth | Valve matrices and schedulers may silently connect wrong beds/tanks. | `test_four_bed_valve_matrix_matches_manifest_for_each_global_slot` | Build `global_cycle_manifest.csv` and validate all active connections. |
| Computational cost growth from more CSTRs | Four-bed high-node runs may become expensive or unstable. | `test_four_bed_state_vector_size_expected`; `test_large_nc_jpattern_available` | Add state-size and JPattern diagnostics before performance tuning. |
| Event locations are two-adsorber scoped | Bed 3/4 events may be impossible or ignored. | `test_event_location_parser_rejects_or_supports_adsorber_3_4_explicitly` | Implement generic adsorber-indexed event functions or fail clearly. |
| Multi-bed event objectives conflict | One event can terminate a global step before another bed reaches its intended state. | `test_multi_bed_event_conflict_requires_priority_manifest` | Add `event_priority_policy.json` with controlling and sacrificed objectives. |
| Simultaneous feed/purge may terminate only on feed breakthrough | Purge terminal state may be uncontrolled and misreported. | `test_simultaneous_feed_purge_reports_uncontrolled_purge_state` | Add event diagnostics for non-controlling bed terminal states. |
| Shared feed tank MFC with multiple adsorber outlets | Multiple beds drawing simultaneously change feed MFC demand. | `test_feed_tank_mfc_balances_multiple_adsorber_outlets` | Add per-bed feed-tank draw ledger and MFC inlet-flow report. |
| Shared product tanks can be both source and sink | Product from one bed may be consumed by another in the same global slot. | `test_shared_product_tank_inflow_outflow_by_bed_conserves_components` | Build shared-tank ledger by bed, component, and step. |
| External product is delayed by tank outlet check/BPR | Native external product may be zero while column/tank receives product. | `test_tank_inventory_not_equal_external_product_when_bpr_closed` | Report tank inventory and external product separately. |
| At most one valve is open at each adsorber end | One end cannot connect to two partners/sources in the same step. | `test_each_adsorber_end_has_at_most_one_active_connection` | Add scheduler validation for one-end-one-connection invariant. |
| Equalisation stream direction is state-dependent | Schedule must not impose a fixed sign unless source-backed. | `test_equalization_allows_bidirectional_flow_and_logs_sign` | Add equalisation flow-sign diagnostics. |
| Plotting may be two-bed scoped | Simulation may run but plots mislabel or omit beds. | `test_four_bed_simulation_can_run_with_plotting_disabled` | Make plotting optional; add four-bed timeline plots later. |

### 8.7 Minimum four-bed deliverables before performance comparison

1. `four_bed_capability_audit.md` with source-backed pass/fail for state vector sizing, event functions, valve matrices, product metrics, plotting, CSS, and unsupported paths.
2. `global_cycle_manifest.csv` with every global slot, bed-specific native step, source step label, duration/event, and active connections.
3. `equalization_pair_map.csv` with explicit active pairs, adsorber ends, native step rows, and stage index where needed.
4. `event_priority_policy.json` for any event-driven multi-bed global step.
5. `shared_tank_ledger.csv` with tank inflow/outflow by bed and component.
6. `four_bed_timeline.pdf` or `.png` for active steps, equalisation pairs, events, and shared-tank usage.
