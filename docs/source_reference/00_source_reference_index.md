# Source Reference Router

## Purpose

This branch now uses `docs/four_bed/FINAL_IMPLEMENTATION_CONTEXT.md` as the
active source-reference and planning router for final Yang four-bed
implementation work.

Use this file as a lightweight router so future agents do not treat retired
WP1-WP5 planning files as the current task sequence.

## Current Branch Sources

| Source | Main Use |
|---|---|
| `docs/four_bed/FINAL_IMPLEMENTATION_CONTEXT.md` | Active final implementation target, FI-1 through FI-8 scope, batch routing, state/adapter/ledger contracts. |
| `docs/four_bed/batch_1_schedule_state_persistence_implementation_guide.md` | Active Batch 1 guide for schedule finalisation and physical-state persistence cleanup. |
| `docs/four_bed/batch_2_h2co2_ac_parameter_pack_implementation_guide.md` | Active Batch 2 guide for the H2/CO2 activated-carbon surrogate parameter pack. |
| `sources/Yang 2009 4-bed 10-step relevant.pdf` | Local literature artifact for the four-bed schedule, operation semantics, duration labels, and physical-model caveats. |
| `docs/workflow/` | Legacy planning CSVs for historical rationale, old test IDs, issue history, and source anchors. |
| `docs/four_bed/WP Archive/` | Legacy WP1-WP5 docs retained for historical review only. |

## Active Lookup Order

For implementation or review tasks:

1. Read `docs/four_bed/README.md`.
2. Read `docs/four_bed/FINAL_IMPLEMENTATION_CONTEXT.md`.
3. Read the relevant active batch guide, if it exists.
4. Read the relevant case spec or parameter documentation if editing a case or
   parameter pack.
5. Use `docs/workflow/` only for historical rationale, old test IDs, or
   contradiction checks.
6. Open the Yang PDF only when a task explicitly asks for source confirmation or
   when current repo-local context is inconsistent or incomplete.

## Source Handling Policy

- Treat final implementation context as the active plan.
- Treat legacy workflow files as fallible historical inputs.
- Preserve source labels and raw duration labels as metadata.
- Use normalized displayed-cycle fractions for executable final scheduling.
- Record contradictions in `docs/KNOWN_UNCERTAINTIES.md`.
- Do not invent missing pair identities, intermediate pressures, thermal
  parameters, valve coefficients, or layered-bed support.
