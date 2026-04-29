# 03 - Step strings, native connectivity, and cycle scheduling

Primary source: Taehun Kim and Joseph K. Scott, *Dynamic modeling and simulation of pressure swing adsorption processes using toPSAil*, Computers and Chemical Engineering 176, 108309, 2023.

This is a split-out Codex context file derived from `topsail_paper_source_extraction_schell_4bed.md`. Use it only for tasks where its scope is relevant. Yes, context discipline: the thrilling frontier of not making the next agent read a small novella.

---

## 4. Step string grammar and native connectivity

### 4.1 Grammar

Paper fact:

```text
STEP-FEEDEND-PRODUCTEND
```

- `STEP` is the elementary step type, such as `HP`, `LP`, `DP`, `RP`, `EQ`, `RT`, or `HR`.
- The second token is the feed-end connectivity.
- The third token is the product-end connectivity.
- Choosing a step fixes the relevant boundary condition types and PFD valve configuration.

Common tokens:

| Token | Meaning in native semantics | Warning |
|---|---|---|
| `FEE` | Feed tank connection. | The feed tank is one dynamic unit and is normally high pressure. |
| `RAF` | Raffinate tank connection. | This is dynamic raffinate material, not pure H2 unless the cycle makes it so. |
| `EXT` | Extract side/tank connection. | This is dynamic extract-side material/sink/source depending on step. |
| `ATM` | Atmosphere/waste path. | Native waste accounting may differ from literature product accounting. |
| `XXX` | Closed/no connection. | Check whether both ends are closed in rest steps. |
| `AFE` | Adsorber feed-end equalisation. | Pairing is inferred from rows in the same global step. |
| `APR` | Adsorber product-end equalisation. | Pairing is inferred from rows in the same global step. |

### 4.2 Native steps relevant to Schell and debugging

This table combines paper semantics and current code anchors. Future Codex agents must verify current code before editing, because apparently source-code drift is humanity's other renewable resource.

| Native step | Paper/code meaning | Mode class | Current Schell relevance |
|---|---|---|---|
| `HP-FEE-RAF` | High-pressure feed from feed tank to feed end; product end to raffinate tank. | Constant-pressure step. | Intended H2-rich adsorption/product step. Needs column product-end ledger separate from tank outlet ledger. |
| `DP-EXT-XXX` | Depressurisation/blowdown from feed end to extract side; product end closed. | Varying-pressure step. | Schell blowdown candidate. Need check direction and extract product accounting. |
| `LP-EXT-RAF` | Low-pressure purge from raffinate tank to product end; feed end to extract side. | Constant-pressure step. | Not Schell's equimolar-feed purge. This is the likely stream-placement root cause. |
| `LP-ATM-RAF` | Low-pressure purge from raffinate tank to product end; feed end to atmosphere/waste. | Constant-pressure step. | Paper's basic Skarstrom example, not Schell if extract product is collected. |
| `RP-FEE-XXX` | Repressurisation from feed tank to feed end; product end closed. | Varying-pressure step. | Closer to Schell if Schell pressurises with equimolar feed. Still needs pressure and flow-basis checks. |
| `RP-XXX-RAF` | Repressurisation from raffinate tank to product end; feed end closed. | Varying-pressure step. | Native Skarstrom example. Not Schell if Schell uses equimolar feed pressurisation. |
| `EQ-AFE-XXX` | Equalisation via feed ends; product ends closed. | Varying-pressure/equalisation. | Current Schell adapter uses this. Need endpoint and pair ledger. |
| `EQ-XXX-APR` | Equalisation via product ends; feed ends closed. | Varying-pressure/equalisation. | Possible alternative if source indicates product-end equalisation. Must be source anchored. |
| `RT-XXX-XXX` | Rest/idle, both ends closed and no interactions. | Rest. | Required if source schedule has idle periods. |

### 4.3 Code-confirmed hazard: `LP-EXT-RAF`

Current code anchor:

- `getVolFlowFuncHandle.m` assigns `LP-EXT-RAF` product-end inlet using `calcVolFlowRaTa2ValFiv(...)`.
- `getFlowSheetValves.m` marks `LP-EXT-RAF` as feed-end material going to the extract tank.
- Therefore native `LP-EXT-RAF` means dynamic raffinate-tank purge into the product end, not fixed equimolar feed purge.

Schell implication:

- Schell purge is described in the existing Schell source reference as equimolar feed, not H2-rich raffinate product.
- Current adapter note says the raffinate tank is seeded with equimolar feed. That is not equivalent because the raffinate tank evolves dynamically.
- If the run shows almost no H2 in final native raffinate product and large equimolar material on the extract side, first suspect that H2 product is being recycled/purged out through the dynamic raffinate-tank path.

Required next diagnostic:

```text
For each step and column, log:
- native step string
- feed-end boundary flow, mol/s and component mol/s
- product-end boundary flow, mol/s and component mol/s
- source tank and sink tank for each active boundary
- feed tank pressure/composition
- raffinate tank pressure/composition
- extract tank pressure/composition
- cumulative column-to-tank transfers
- cumulative tank-to-column transfers
- cumulative external product and waste transfers
```

The question is not only "does H2 leave the column?" The sharper question is "does H2 leave during `HP-FEE-RAF` and then get consumed as purge source during `LP-EXT-RAF`?"

---

### 4.4 Dissertation scheduling and connectivity refinements

The dissertation adds stricter guidance for overlapping schedules and future multi-bed work:

| Topic | Dissertation refinement | Implementation consequence |
|---|---|---|
| Current step catalogue | The available step list considers up to two-adsorber interactions. | Do not infer arbitrary four-bed pairings from existing step names. Add explicit pair metadata for equalisation and cross-bed interactions. |
| Current simulator scope | The dissertation says current toPSAil does not support more than two adsorbers or multiple equalisation steps. | Treat four-bed schedules as unsupported until a capability audit and feature gates pass. |
| Event locations | Event locations are described for one of two adsorbers plus tanks/streams. | Reject or explicitly implement `Adsorber_3_*` and `Adsorber_4_*` event locations before using them. |
| Global step conflicts | Different adsorbers can have distinct event objectives in the same global slot, and no general solution is given. | Require `event_priority_policy.json` for multi-bed event-driven slots, or use fixed-duration schedules with a source-backed rationale. |
| Kayser precedence example | Repressurisation can be given precedence over feed breakthrough in one source-specific case. | Store event precedence as case data, not as a hardcoded universal rule. |
| One-end-one-connection invariant | At most one valve is open at each adsorber end. | Scheduler validation must reject slots that connect one end to multiple partners/sources. |
| Bidirectional equalisation | Equalisation streams are state-dependent and may be bidirectional. | Do not impose a fixed sign unless the source and native model justify it; log equalisation flow sign. |

For any literature cycle with overlapping column steps, build a global timeline manifest before editing solver internals:

```text
global_step_index
start_time_s
end_time_s
duration_s
column_i_native_step
column_i_source_step_label
column_i_source_sink_manifest
intended_pressure_class
intended_flow_direction
active_connections_by_end
event_type_location_or_fixed_duration
event_priority_policy_if_any
reason_for_idle_or_split
```

Validation rules:

- No negative or zero durations unless the source explicitly has a zero-duration switch.
- Every split of a source step into native global slots must preserve source intent and be documented.
- Equalisation pairs must be explicit in a pair map; sequential row-order pairing is not enough for general four-bed schedules.
- Fixed-duration four-bed schedules are safer than event-driven schedules until event conflicts have an explicit policy.
