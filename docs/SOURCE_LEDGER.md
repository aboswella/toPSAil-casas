# Source Ledger

## Ledger Policy

This ledger records branch-relevant source roles and local artifact status. It does not resolve missing or ambiguous parameters. Unresolved source, modelling, and workflow issues belong in `docs/KNOWN_UNCERTAINTIES.md`.

## Yang 2009

Role:

- four-bed ten-step PSA schedule source;
- operation-label and duration-label source;
- source basis for the WP1 manifest;
- physical-model caveat source for layered beds, thermal behaviour, and later validation positioning.

Use:

- Table 2 schedule labels and duration labels;
- process-description semantics for `AD`, `AD&PP`, `EQI-BD`, `PP`, `EQII-BD`, `BD`, `PU`, `EQII-PR`, `EQI-PR`, and `BF`;
- layered-bed requirement as a capability-audit trigger;
- pressure anchors only where explicitly stated by the source or workflow guidance.

Not used for:

- permission to rewrite toPSAil core physics;
- implicit bed-pair inference from table row order;
- dynamic internal tank or shared-header modelling;
- unlabelled validation claims before wrapper correctness, ledgers, and model limitations are documented.

Local artifact status:

- `sources/Yang 2009 4-bed 10-step relevant.pdf` is present locally.

## Workflow Planning Files

Role:

- canonical branch planning source for work-package scope, architecture constraints, test mapping, stage gates, issue register, and evidence notes.

Primary files:

- `docs/workflow/four_bed_project_context_file_map.txt`
- `docs/workflow/four_bed_executive_summary.csv`
- `docs/workflow/four_bed_work_packages.csv`
- `docs/workflow/four_bed_architecture_map.csv`
- `docs/workflow/four_bed_issue_register.csv`
- `docs/workflow/four_bed_test_matrix.csv`
- `docs/workflow/four_bed_yang_manifest.csv`
- `docs/workflow/four_bed_stage_gates.csv`
- `docs/workflow/four_bed_evidence_notes.csv`
- `docs/workflow/Work package guidance docs/WP1_yang_schedule_manifest_guidance.md`

Policy:

- treat these files as canonical planning inputs;
- assess them critically if contradictions appear;
- report contradictions instead of silently choosing the convenient interpretation.

## toPSAil

Role:

- base MATLAB PSA simulator and numerical engine;
- source of existing single-bed and paired-bed behaviour;
- regression target when adding wrapper-level functionality.

Use:

- native pressure-flow, boundary-condition, cycle, and auxiliary-unit machinery wherever practical;
- original examples for Tier 0 smoke/regression checks;
- project wrappers to adapt Yang schedule/state orchestration around existing behaviour.

Not used for:

- assuming four persistent beds are already supported by the GUI or existing examples;
- bypassing wrapper ledgers for Yang external/internal metric reconstruction.
