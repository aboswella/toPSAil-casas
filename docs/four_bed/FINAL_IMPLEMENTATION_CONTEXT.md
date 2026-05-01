# Four-Bed Final Implementation Context

## Purpose

This is the active project context for the remaining four-bed implementation work.
It condenses the final-phase guidance from:

- `four_bed_final_implementation_basis.docx`
- `four_bed_final_batching_context.md`
- `Final phase implementation guidance.txt`

The older WP1-WP5 work-package documents and `docs/workflow/` CSV planning files
are legacy context. They remain useful for historical rationale, risk
cross-checking, and issue provenance, but they are not the active implementation
sequence.

## Active Target

The active implementation target is a Yang-inspired four-bed H2/CO2 homogeneous
activated-carbon surrogate.

It is not a full Yang reproduction with H2/CO2/CO/CH4 feed, layered activated
carbon plus zeolite 5A beds, or Aspen Adsim valve details.

The final implementation should complete a wrapper-and-adapter architecture:

- existing toPSAil adsorber machinery remains the numerical engine;
- four persistent named bed states `A`, `B`, `C`, and `D` are the only physical
  process memory held by the wrapper;
- executable slot durations use normalized fractions
  `[1, 6, 1, 4, 1, 1, 4, 1, 1, 5] / 25`;
- raw Yang duration labels remain source metadata, not executable timing;
- persistent bed states contain physical adsorber state only, not cumulative
  boundary-flow counters;
- PP->PU and AD&PP->BF require custom direct-coupling adapters where native
  toPSAil step grammar cannot express the Yang operation directly;
- wrapper-owned ledgers and audit records define the final H2 purity/recovery
  basis, with internal transfers excluded from external product and recovery.

## Non-Negotiable Architecture

Do not introduce any of these for the final Yang surrogate path:

- dynamic internal tanks for Yang internal transfers;
- shared header inventory for Yang internal transfers;
- a global four-bed RHS/DAE state vector;
- core adsorber mass, energy, momentum, isotherm, or solver rewrites;
- event-driven Yang scheduling before the fixed-duration direct-coupling path is
  commissioned;
- zeolite 5A, CO, CH4, pseudo-impurity, or layered-bed behaviour in the first
  final implementation.

A small documented interface hook is allowed only if existing toPSAil machinery
cannot otherwise support a wrapper-level adapter. The hook must be narrow,
reviewable, and reported explicitly.

## Active Work Items

The active work items are FI-1 through FI-8:

| Item | Objective | Main deliverable |
|---|---|---|
| FI-1 | Schedule finalisation | Normalized duration helper and tests for `[1,6,1,4,1,1,4,1,1,5]/25`. |
| FI-2 | H2/CO2 AC parameter pack | Binary feed renormalisation, activated-carbon-only params, native DSL mapping tests. |
| FI-3 | Physical state persistence cleanup | Physical-state extraction/writeback, counter-tail separation, CSS over physical state only. |
| FI-4 | PP->PU adapter | Direct provide-purge adapter with internal transfer, waste, pressure, and conservation diagnostics. |
| FI-5 | AD&PP->BF adapter | Direct adsorption/product/backfill split adapter with separate external product and internal BF accounting. |
| FI-6 | Four-bed cycle driver | Full normalized Yang cycle over persistent `A/B/C/D` states. |
| FI-7 | Ledger extraction and audit output | External-basis Yang metrics, in-memory stream extraction, compact adapter audit artifacts. |
| FI-8 | Commissioning tests | Staged static, state, native smoke, adapter, ledger, cycle, CSS, and sensitivity checks. |

## Active Batches

Use these batches for new implementation planning:

| Batch | Includes | Scope |
|---|---|---|
| Batch 1 | FI-1 + FI-3 | Schedule finalisation and physical-state persistence cleanup. |
| Batch 2 | FI-2 | H2/CO2 activated-carbon surrogate parameter pack. |
| Batch 3 | FI-4 | PP->PU direct-coupling adapter. |
| Batch 4 | FI-5 | AD&PP->BF direct-coupling adapter. |
| Batch 5 | FI-6 + FI-7 | Full four-bed cycle driver plus wrapper ledger/audit extraction. |
| Batch 6 | FI-8 | Commissioning and acceptance tests. |

Batch 1 and Batch 2 may proceed in parallel. Batch 3 should establish the common
adapter pattern before Batch 4 extends it. Batch 5 should wait for minimally
passing foundation and adapter smoke tests. Batch 6 is last and should be
adversarial commissioning rather than new feature work.

## Active Detailed Guides

Current detailed implementation guides:

- `docs/four_bed/batch_1_schedule_state_persistence_implementation_guide.md`
- `docs/four_bed/batch_2_h2co2_ac_parameter_pack_implementation_guide.md`

Future detailed guides should be created, in order, for:

1. Batch 3: PP->PU adapter.
2. Batch 4: AD&PP->BF adapter.
3. Batch 5: four-bed cycle driver and wrapper ledger.
4. Batch 6: commissioning tests.

## Legacy Materials

The following are legacy context, not active implementation instructions:

- `docs/workflow/four_bed_project_context_file_map.txt`
- `docs/workflow/four_bed_executive_summary.csv`
- `docs/workflow/four_bed_work_packages.csv`
- `docs/workflow/four_bed_architecture_map.csv`
- `docs/workflow/four_bed_test_matrix.csv`
- `docs/workflow/four_bed_issue_register.csv`
- `docs/workflow/four_bed_yang_manifest.csv`
- `docs/workflow/four_bed_stage_gates.csv`
- `docs/workflow/four_bed_evidence_notes.csv`
- `docs/workflow/Work package guidance docs/WP1_yang_schedule_manifest_guidance.md`
- `docs/four_bed/WP Archive/`
- `.codex/prompts/05_yang_wp1_schedule_manifest.md`

Read legacy materials only when investigating history, checking a risk, or
resolving a contradiction. If legacy material conflicts with this final
implementation context or a current batch guide, use the final context and
record the contradiction in the task report.

## Final Surrogate Basis

Use component order `[H2; CO2]`.

Use the binary-renormalized feed:

- `y_H2 = 72.2 / (72.2 + 21.6) = 0.7697228145`
- `y_CO2 = 21.6 / (72.2 + 21.6) = 0.2302771855`

Use activated carbon as a homogeneous adsorbent over the model bed by default.
Do not add zeolite 5A, CO, CH4, pseudo-components, or layered-bed behaviour to
the first final implementation.

For Yang-style DSL on native toPSAil extended dual-site
Langmuir-Freundlich machinery, use `modSp(1) = 6` with site exponents set to
one where Batch 2 confirms the mapping. Native temperature-dependence mismatch
remains an uncertainty until point tests justify non-isothermal claims.

## State And Ledger Contract

Persist:

- gas-phase concentrations in each CSTR;
- adsorbed-phase loadings in each CSTR;
- gas and wall temperatures when they are physical states in the chosen thermal
  mode.

Do not persist:

- cumulative feed-end or product-end flow counters;
- temporary tank/helper-unit state;
- adapter-only accounting counters.

Extract counter deltas for ledgers before reset/discard. CSS residuals must use
physical bed states only.

Wrapper stream scopes are:

- `external_feed`
- `external_product`
- `external_waste`
- `internal_transfer`
- `bed_inventory_delta`

Only `external_product` contributes to the H2 product numerator. Internal
transfers support conservation and bed operation but do not count as external
product or recovery.

## Adapter Requirements

`PP -> PU`:

- donor product end feeds receiver product end;
- receiver waste exits the feed end;
- record internal transfer moles, waste moles, pressure endpoints, flow signs,
  valve coefficients, and conservation residuals.

`AD&PP -> BF`:

- donor receives external feed and produces product-side gas;
- product-side gas splits into external product and internal BF stream;
- split must emerge from valve coefficients, not a hard-coded final ratio;
- record effective split ratio and separate external/internal counters.

Expose valve coefficients and run controls through a stable control structure so
future sensitivity or optimization wrappers can vary them without editing
scheduler code.

## Commissioning Ladder

Final commissioning should cover:

- static manifest, pair-map, no-tank, and native-translation checks;
- physical-state-only persistence and local/global writeback checks;
- native AD, BD, EQI, and EQII smoke tests using the H2/CO2 AC surrogate;
- PP->PU and AD&PP->BF adapter conservation and endpoint tests;
- one-slot external/internal ledger balance tests;
- one full normalized four-bed cycle;
- CSS or max-cycle smoke with all-bed residual trends;
- valve-coefficient sensitivity sanity checks.

Long optimization, broad sensitivity studies, event policy, tank/header variants,
and generalized PFD work remain later extensions.
