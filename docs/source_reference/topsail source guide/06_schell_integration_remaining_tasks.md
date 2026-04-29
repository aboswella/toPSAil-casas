# 06 - Schell integration: remaining tasks and likely failure mode

Primary source: Taehun Kim and Joseph K. Scott, *Dynamic modeling and simulation of pressure swing adsorption processes using toPSAil*, Computers and Chemical Engineering 176, 108309, 2023.

This is a split-out Codex context file derived from `topsail_paper_source_extraction_schell_4bed.md`. Use it only for tasks where its scope is relevant. Yes, context discipline: the thrilling frontier of not making the next agent read a small novella.

---

## 7. Consequences for the remaining Schell integration

### 7.1 Do not keep debugging Sips first

Current evidence says Sips is likely sound. The paper extraction points to a different class of problem: boundary and product accounting semantics. Future Codex agents should spend their first effort on step connectivity and ledgers, not on tuning isotherm constants. The isotherm can still be audited, but not used as the default scapegoat. Scapegoats are popular because they do not require reading `getFlowSheetValves.m`.

### 7.2 Immediate Schell issue hypothesis

The current central run symptom is:

```text
feed moles roughly equimolar
raffinate product almost zero
extract product large and roughly equimolar
CO2 recovery greater than 100 percent
```

Most likely source-consistent diagnosis:

1. `HP-FEE-RAF` may generate H2-rich material at the column product end or inside the raffinate tank.
2. `LP-EXT-RAF` then uses the dynamic raffinate tank as low-pressure purge source.
3. That material exits via the extract side.
4. Native external product accounting reports almost nothing as raffinate product and most material as extract product.
5. The Schell-basis CO2-by-subtraction comparison becomes meaningless unless reconstructed from the right streams.

The ledger must prove or falsify this sequence.

### 7.3 Schell purge is probably not representable by existing native steps

Schell requires low-pressure purge with equimolar feed source and extract-side collection.

Native `LP-EXT-RAF` supplies purge from dynamic raffinate tank.

Native `FEE` is a single feed tank normally maintained at highest PFD pressure, so simply creating a `LP-EXT-FEE` step may still be wrong unless the source pressure/composition and pressure control are handled deliberately.

Viable implementation options:

| Option | Description | Pros | Cons | Recommendation |
|---|---|---|---|---|
| A | Add a dedicated fixed purge-source tank or controlled source with equimolar composition and low-pressure setpoint. | Closest to Schell purge semantics. Keeps raffinate product tank separate. | Requires PFD extension or adapter-level source injection. | Preferred if the default native PFD cannot express Schell purge. |
| B | Add a labelled Schell reproduction mode with custom boundary source for purge, bypassing native raffinate tank as purge source. | Clear separation from native toPSAil. | More custom code. Must not contaminate default route. | Acceptable with explicit label and tests. |
| C | Use existing `LP-EXT-RAF` and seed raffinate tank with feed. | Easy. | Semantically wrong after the first dynamic interaction. | Do not use for validation. Only use as a diagnostic negative control. |
| D | Reinterpret feed tank as purge source during low-pressure purge. | Might preserve composition. | Violates paper PFD where feed tank is highest pressure, unless carefully controlled in no-pressure-drop mode. | Risky. Use only if fully documented and tested. |

### 7.4 Current central-case schedule is fragile

Current code anchor:

- `build_schell_runnable_params.m` constructs 10 substeps for the central case and computes durations using expressions such as `t_blow - t_press` and `t_ads - (t_blow - t_press)`.

Schell implication:

- That schedule is central-case-specific.
- It will fail or produce negative durations for some Schell cases, especially different adsorption times.
- It approximates overlapping two-column timings rather than deriving them from a general source-backed global schedule.

Required replacement:

Build a source-backed cycle scheduler that emits a global timeline manifest:

```text
global_step_index
start_time_s
end_time_s
duration_s
column_1_step
column_2_step
column_3_step_if_any
column_4_step_if_any
source_step_label_per_column
intended_pressure_class_per_column
intended_flow_direction_per_column
source_sink_manifest_per_column
reason_for_idle_or_split
```

Validation rules:

- No negative or zero durations unless source explicitly has a zero-duration switching event.
- The sum of each column's source step durations must match the source case.
- Any split of a source step into multiple native global slots must preserve source intent and be documented.
- The scheduler must work for all Schell performance cases, not only `20 bar, t_ads = 40 s`.

### 7.5 Schell pressure handling must be explicit

Before changing pressure constants, add this manifest:

```text
source_p_high_bar
source_p_low_bar
native_presColHigh
native_presColLow
native_presFeTa
native_presRaTa
native_presExTa
BPR_setpoints
step_start_pressure_by_column
step_end_pressure_by_column
type_VII_steps_and_initial_pressure
```

Assertions:

- `HP-FEE-RAF` starts at intended `P_col_high` if Type VII is used.
- `LP-EXT-RAF` or its replacement starts at intended `P_col_low` if Type VII is used.
- The feed tank pressure choice is documented as either source-based, control-driving, or temporary diagnostic.
- Do not use `presFeTa = 1.1 * presColHigh` in validation without a source/control rationale.

### 7.6 Schell validation must be staged

Recommended sequence:

1. Add per-step, per-column boundary and tank ledger.
2. Run current central case as a negative-control diagnostic and confirm where H2 product goes.
3. Replace or label the purge source semantics. Do not tune valves first.
4. Add pressure manifest and Type VII start-pressure assertions.
5. Build Schell-basis metric extractor and report native metrics separately.
6. Replace central-only schedule with a source-backed scheduler that supports all performance cases.
7. Run central case again.
8. Add adsorption-time series at 20 bar.
9. Add 10 bar and 30 bar profile cases only after central accounting is credible.

---

### 7.7 Dissertation-backed refinements for Schell tasks

The dissertation adds stricter stop conditions and diagnostics for the current Schell path:

| Refinement | Schell consequence | Required handling |
|---|---|---|
| Fixed-composition literature streams are source/sink semantics. | A seeded raffinate or extract tank is not a fixed equimolar purge source once the cycle evolves. | Audit native tank composition during purge; if native PFD cannot represent the stream, stop or create a labelled extension/reproduction mode. |
| Feed-tank MFC maintains feed-tank pressure. | Reusing the feed tank as a low-pressure fixed purge source may violate native PFD semantics unless deliberately controlled. | Manifest the source pressure, composition, and control basis before using any feed-tank workaround. |
| Product outlet is after the product tank and may be closed by BPR/check behaviour. | Schell H2-rich product may correspond to column/tank material that native external product accounting does not expose directly. | Export column boundary, raffinate tank, and external raffinate outlet ledgers separately. |
| Native recovery/purity basis may not match literature basis. | Schell SI subtraction-basis CO2 metrics must not be compared directly to native extract recovery. | Emit both native metrics and Schell-reconstructed metrics with mass-balance residuals. |
| CSS and events must be reported explicitly. | A final-cycle performance number is insufficient if CSS mask, error, and event termination are unknown. | Export `css_convergence.csv`, `css_state_mask.json`, and `event_diagnostics.csv` for any validation-like run. |
| Flow reversal and LP recourse are diagnostics, not automatic failures. | Wrong purge routing and acceptable transient reversal can look superficially similar. | Pair reversal diagnostics with boundary/source ledgers before changing physics or valves. |
| Node count affects numerical diffusion. | Front-shape or thermal mismatch should not be patched before checking `n_c` basis. | Record node count and any MTZ/node sensitivity before claiming model mismatch. |

Immediate Schell task cards, in order:

1. Add dissertation-backed boundary, tank, and product ledgers. Deliver `step_boundary_ledger.csv`, `tank_history.csv`, `product_tank_vs_external_product.csv`, and conservation residuals.
2. Verify fixed-composition stream, MFC, tank, and valve semantics for Schell. Deliver `schell_stream_semantics_audit.md` and source/sink manifest updates.
3. Add CSS convergence and event diagnostics. Deliver `css_convergence.csv`, `css_state_mask.json`, `event_diagnostics.csv`, and any required `event_priority_policy.json`.
4. Preserve numerical performance diagnostics. Deliver LP recourse, flow-reversal, solver-mode, and JPattern reports before performance tuning.
5. Build any non-Excel manifest bridge only after parity with the Excel/import/scaling path is tested.

Stop instead of editing if the Schell purge requires a PFD element absent from native toPSAil, if dimensional scaling cannot be verified, or if a validation mismatch has multiple plausible causes that ledgers cannot yet distinguish.
