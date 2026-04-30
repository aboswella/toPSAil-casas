# Source Reference Router

## Purpose

This branch uses `docs/workflow/` as the canonical source-reference and planning pack for Yang four-bed implementation work.

Use this file as a lightweight router so future agents do not look for retired staged-validation sheets when the relevant context now lives in the workflow CSVs and WP guidance.

## Current Branch Sources

| Source | Main Use |
|---|---|
| `sources/Yang 2009 4-bed 10-step relevant.pdf` | Local literature artifact for the four-bed schedule, operation semantics, and physical-model caveats. |
| `docs/workflow/four_bed_project_context_file_map.txt` | Entry point for branch planning context and lookup order. |
| `docs/workflow/four_bed_executive_summary.csv` | High-level corrected architecture summary. |
| `docs/workflow/four_bed_work_packages.csv` | WP1-WP5 scope, deliverables, non-goals, dependencies, and handoff tests. |
| `docs/workflow/four_bed_architecture_map.csv` | Architecture constraints and wrapper execution sequence. |
| `docs/workflow/four_bed_yang_manifest.csv` | Source schedule skeleton and operation labels. |
| `docs/workflow/four_bed_issue_register.csv` | Known risks, diagnostics, and clean pass criteria. |
| `docs/workflow/four_bed_test_matrix.csv` | Required tests, owners, runtimes, and default-smoke status. |
| `docs/workflow/four_bed_stage_gates.csv` | Development sequence and go/no-go criteria. |
| `docs/workflow/four_bed_evidence_notes.csv` | Source anchors and rationale. |
| `docs/workflow/Work package guidance docs/WP1_yang_schedule_manifest_guidance.md` | Detailed WP1 implementation guide. |

## Lookup Order

For implementation or review tasks:

1. Read `docs/workflow/four_bed_project_context_file_map.txt`.
2. Read `docs/workflow/four_bed_executive_summary.csv`.
3. Read `docs/workflow/four_bed_work_packages.csv`.
4. Read `docs/workflow/four_bed_architecture_map.csv`.
5. Read work-package-specific rows in `docs/workflow/four_bed_test_matrix.csv` and `docs/workflow/four_bed_issue_register.csv`.
6. Read `docs/workflow/four_bed_yang_manifest.csv` if schedule, labels, durations, or bed roles are involved.
7. Read `docs/workflow/four_bed_evidence_notes.csv` to support or challenge assumptions.
8. Open the Yang PDF only when a task explicitly asks for source confirmation or when the workflow files are inconsistent or incomplete.

## Source Handling Policy

- Treat workflow files as planning inputs, not infallible truth.
- Preserve source labels and duration labels exactly when building manifests.
- Record contradictions in `docs/KNOWN_UNCERTAINTIES.md`.
- Do not invent missing pair identities, intermediate pressures, thermal parameters, or layered-bed support.
