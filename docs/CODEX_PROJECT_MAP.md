# Codex Project Map

## Purpose

This repository is a fork of toPSAil used to develop a Yang 2009 four-bed PSA workflow in MATLAB.

The implementation must proceed in controlled stages:

1. Confirm unmodified toPSAil examples run.
2. Lock the four-bed wrapper architecture.
3. Build WP1: Yang schedule manifest and static validation.
4. Build WP2: explicit direct-transfer pair map.
5. Build WP3: persistent named bed state container.
6. Build WP4: temporary single-bed and paired-bed case builders.
7. Build WP5: ledgers, all-bed CSS, and reporting.
8. Add later event, optimization, or generalized-PFD extensions only after the fixed-duration wrapper is stable.

Do not skip stages without recording the reason in the task report.

## Current Source Roles

### Yang 2009

Role:

- four-bed ten-step schedule source;
- operation-label source;
- duration-label source;
- layered-bed and physical-model caveat source;
- eventual comparison basis after wrapper correctness is established.

Not role:

- reason to rewrite toPSAil core physics;
- permission to introduce dynamic internal tanks;
- proof of validation merely because a manifest has been transcribed.

### toPSAil

Role:

- numerical engine for existing single-bed and paired-bed behaviour;
- pressure-flow, boundary-condition, cycle, and metrics framework to preserve unless explicitly authorised otherwise.

Not role:

- automatic support guarantee for four persistent beds;
- automatic Yang metric basis without wrapper ledgers.

## Project Folders

### `docs/`

Human and Codex-facing project instructions.

Required instruction files:

- `docs/PROJECT_CHARTER.md`
- `docs/MODEL_SCOPE.md`
- `docs/SOURCE_LEDGER.md`
- `docs/VALIDATION_STRATEGY.md`
- `docs/TEST_POLICY.md`
- `docs/BOUNDARY_CONDITION_POLICY.md`
- `docs/THERMAL_MODEL_POLICY.md`
- `docs/TASK_PROTOCOL.md`
- `docs/KNOWN_UNCERTAINTIES.md`
- `docs/REPORT_POSITIONING.md`
- `docs/GIT_WORKFLOW.md`

### `docs/workflow/`

Canonical branch planning inputs.

Read in this order unless the task says otherwise:

- `four_bed_project_context_file_map.txt`
- `four_bed_executive_summary.csv`
- `four_bed_work_packages.csv`
- `four_bed_architecture_map.csv`
- `four_bed_test_matrix.csv`
- `four_bed_issue_register.csv`
- `four_bed_yang_manifest.csv`
- `four_bed_stage_gates.csv`
- `four_bed_evidence_notes.csv`

For WP1, also read:

- `Work package guidance docs/WP1_yang_schedule_manifest_guidance.md`

### `sources/`

Local literature artifacts. PDFs are ignored by Git by default, so source availability must also be recorded in `docs/SOURCE_LEDGER.md`.

### `cases/`

Project-specific case definitions and run scripts. Add a case only after the relevant work-package scope and case spec are clear.

### `params/`

Project-specific parameter packs. Keep values source-specific and traceable.

### `validation/`

Validation manifests, expected targets, ledgers, and generated reports. Raw source data and generated reports must be kept separate.

### `tests/`

Small test suite mapped to `docs/workflow/four_bed_test_matrix.csv`.

### `scripts/`

Convenience scripts for running tests and validation.

### `.codex/`

Codex configuration and reusable prompts.

## Required Reading For Codex

Before editing, read:

1. `AGENTS.md`
2. `docs/CODEX_PROJECT_MAP.md`
3. `docs/PROJECT_CHARTER.md`
4. `docs/MODEL_SCOPE.md`
5. `docs/SOURCE_LEDGER.md`
6. `docs/VALIDATION_STRATEGY.md`
7. `docs/TEST_POLICY.md`
8. `docs/BOUNDARY_CONDITION_POLICY.md`
9. `docs/THERMAL_MODEL_POLICY.md`
10. `docs/TASK_PROTOCOL.md`
11. `docs/KNOWN_UNCERTAINTIES.md`
12. `docs/REPORT_POSITIONING.md`
13. `docs/GIT_WORKFLOW.md`
14. The relevant workflow CSVs and work-package guidance.
15. The relevant case spec, if editing a case.

## Default Task Order

The next task should always be the smallest task that advances the current work package or stage gate.

Never combine:

- new physics;
- new metrics;
- new validation thresholds;
- new plotting;
- new optimization;
- unrelated work-package ownership.

## Stop And Report If

- a source or workflow file is ambiguous;
- a required parameter, pair, or mapping is missing;
- a change would touch toPSAil core internals;
- a direct-transfer or ledger mismatch has multiple plausible causes;
- MATLAB cannot run the required test;
- a task would skip a project stage;
- a test threshold would need changing.
