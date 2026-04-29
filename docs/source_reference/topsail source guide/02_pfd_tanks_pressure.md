# 02 - Fixed PFD, tanks, piping semantics, and pressure vocabulary

Primary source: Taehun Kim and Joseph K. Scott, *Dynamic modeling and simulation of pressure swing adsorption processes using toPSAil*, Computers and Chemical Engineering 176, 108309, 2023.

This is a split-out Codex context file derived from `topsail_paper_source_extraction_schell_4bed.md`. Use it only for tasks where its scope is relevant. Yes, context discipline: the thrilling frontier of not making the next agent read a small novella.

---

## 3. Fixed PFD and tank semantics

### 3.1 PFD sections

The paper divides the PFD into four sections:

| Section | Paper meaning | Development consequence |
|---|---|---|
| Feed section | Compressor, heat exchanger, pressure controller, feed tank. Feed tank pressure is maintained at `P_f`. | `P_f` is not automatically the adsorber high pressure. It is a tank/source pressure. |
| Adsorber network | Adsorbers plus feed-end/product-end valves and possible adsorber-to-adsorber equalisation. | Step strings decide which valve path is active. |
| Raffinate section | Raffinate tank, multi-way valves, and raffinate outlet BPR/check valve. | Raffinate tank can collect product and later feed material back to adsorbers. It is dynamic. |
| Extract section | Vacuum pump, extract tank, extract compressor, extract outlet BPR/check valve. | Extract tank can collect product and later act as a source for rinse. It is dynamic. |

### 3.2 Tanks are not fixed reservoirs

Paper facts:

- Tanks are modelled as well-mixed volumes, like a single CSTR without adsorbent.
- Tanks have multiple inlets and outlets.
- Tank boundary conditions use the same valve models as adsorber boundaries.
- Product tanks can collect material and later send material back to adsorbers.

Development consequences:

- Do not seed `raTa` with equimolar feed and then use it as if it remains equimolar. It will become whatever the cycle makes it become.
- Do not seed `exTa` with some convenient composition and then assume it is a fixed CO2-rich source.
- When a literature paper says a purge/rinse source is a fixed feed, a product tank, or a recycle tank, those are materially different flowsheets.
- Any implementation that uses dynamic tank material as a substitute for a fixed-composition feed must be labelled as an approximation and tested by a tank-composition ledger.

### 3.3 Pressure names must not be collapsed

Paper facts:

- The feed tank pressure `P_f` is maintained exactly and is described as the highest pressure in the PFD.
- Raffinate and extract tanks have their own pressure targets and outlet valve behaviour.
- Product tank outlet valves behave differently in pressure-driven and flow-driven regimes.

Development consequences:

Use this pressure vocabulary in code, reports, and prompts:

| Name | Meaning | Example misuse to avoid |
|---|---|---|
| `P_source` | External source pressure before feed compression. | Using it as adsorber feed pressure. |
| `P_feed_tank` or `P_f` | Pressure in toPSAil feed tank. Highest PFD pressure in paper. | Treating `1.1 * P_high` as source evidence. |
| `P_col_high` | Intended high adsorber pressure during adsorption. | Treating it as identical to feed tank pressure. |
| `P_col_low` | Intended low adsorber pressure during blowdown/purge. | Treating it as extract tank pressure. |
| `P_raff_tank` | Raffinate tank pressure/set point. | Treating tank output as final product without checking outlet valve. |
| `P_extract_tank` | Extract tank pressure/set point. | Treating direct extract stream and tank outlet as identical. |
| `P_BPR_set` | Back-pressure regulator set point. | Assuming exact pressure unless Type VII/control mode applies. |
| `P_event_target` | Step termination pressure target. | Assuming a fixed-duration step reaches it. |

For Schell, this is central: the source reports adsorber high pressure cases at 10, 20, and 30 bar. That does not itself justify `presFeTa = 1.1 * presColHigh` as a physical source value.

---

### 3.4 Dissertation tank, MFC, and valve refinements

The dissertation sharpens several PFD details that matter for Schell and future multi-bed work:

| Detail | Dissertation-backed implication | Development rule |
|---|---|---|
| Feed, raffinate, and extract tanks interact with `n_a` adsorbers. | Tank outlet/inlet flows are computed from adsorber interactions and valve models. | In multi-bed slots, report per-bed tank draw/fill terms instead of only a net tank flow. |
| Feed-tank MFC maintains tank pressure. | The MFC is a pressure-control device for the feed tank, not a magic fixed-composition source for every literature stream. | A fixed-composition purge or rinse needs explicit source semantics, not only a seeded tank. |
| Product tanks have external outlets after tank inventory. | The stream after the product tank can differ from column boundary flow and tank contents. | Always separate column-boundary product, tank inventory, and external outlet product. |
| Product outlet check/BPR can remain closed below product pressure. | Native external product can be zero even while a column or tank receives product. | Do not compare tank inventory directly to literature product without an external-outlet ledger. |
| Plain BPR is not a check valve. | A BPR may allow flow either way if upstream exceeds the set pressure; a combined BPR/check uses a directional `max` style rule. | Distinguish linear valve, BPR, check valve, and combined BPR/check in manifests and tests. |
| Extract compression can be part of the native extract section. | Native energy and stream accounting may include extract-side compressor/vacuum behaviour. | Literature metric comparisons must state whether native compressor/vacuum terms are included. |

For Schell fixed-composition streams, the key rule is simple: a source paper's fixed feed or purge stream is a source/sink boundary condition, not an initial composition in a dynamic tank. If native toPSAil cannot express that source through the existing PFD, stop and document the limitation or build a separately labelled extension.

### 3.5 Shared-tank implications for future multi-bed work

With more than two adsorbers, the one-feed-tank, one-raffinate-tank, one-extract-tank PFD can create simultaneous source/sink behaviour:

```text
- one bed can fill a product tank while another draws from it;
- multiple beds can draw from the feed tank in the same global slot;
- product from one bed can become recycle/purge material for another;
- external product can lag tank inventory because the outlet check/BPR is closed.
```

Required shared-tank ledger fields:

```text
global_step_index
tank_name
bed_index
direction: tank_to_bed | bed_to_tank | tank_to_external | external_to_tank
component_moles_dimensional
tank_pressure_before_after
tank_composition_before_after
external_outlet_open_or_closed
```
