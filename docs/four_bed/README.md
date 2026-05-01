# Four-Bed Documentation Router

Start here for Yang four-bed work.

## Active Context

Read `docs/four_bed/FINAL_IMPLEMENTATION_CONTEXT.md` before using any older
four-bed planning material. The active target is the Yang-inspired H2/CO2
homogeneous activated-carbon surrogate and the active work sequence is FI-1
through FI-8, grouped into six final implementation batches.

Current detailed batch guides:

- `docs/four_bed/batch_1_schedule_state_persistence_implementation_guide.md`
- `docs/four_bed/batch_2_h2co2_ac_parameter_pack_implementation_guide.md`

Future guides should be generated for Batch 3, Batch 4, Batch 5, and Batch 6
only when those batches are assigned.

## Legacy Context

The old WP1-WP5 documents have been moved under `docs/four_bed/WP Archive/`.
They are historical context only. Do not use them as active implementation
instructions unless the user explicitly asks for legacy review.

The planning CSV files under `docs/workflow/` are also legacy context. They may
still help explain architecture guardrails, old test IDs, and issue history, but
they do not override the final implementation context or current batch guides.

## Persistent Guardrails

The final implementation remains a thin wrapper around existing toPSAil
adsorber machinery:

- no dynamic internal tanks or shared header inventory for Yang internal
  transfers;
- no global four-bed RHS/DAE;
- no core adsorber-physics rewrite;
- four persistent named bed states `A`, `B`, `C`, and `D`;
- physical-state-only persistence;
- wrapper-owned external/internal ledgers for final H2 purity and recovery.
