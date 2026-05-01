# Codex Project Map

## Purpose

This repository is a fork of toPSAil used to develop a Yang-inspired four-bed
PSA workflow in MATLAB.

The active implementation target is a four-bed H2/CO2 homogeneous
activated-carbon surrogate. It is not a full Yang layered four-component
reproduction.

## Active Sequence

The old WP1-WP5 implementation sequence is complete or superseded. Treat old
work-package documents, old prompts, and the `docs/workflow/` CSV pack as legacy
context unless a task explicitly asks for legacy review.

Current implementation proceeds by final items and batches:

1. Preserve the unchanged toPSAil baseline.
2. Preserve the no-tank, no-header, no-global-RHS wrapper architecture.
3. Batch 1 / FI-1 and FI-3: normalized schedule execution and physical-state-only persistence.
4. Batch 2 / FI-2: H2/CO2 activated-carbon surrogate parameter and case package.
5. Batch 3 / FI-4: PP->PU direct-coupling adapter.
6. Batch 4 / FI-5: AD&PP->BF direct-coupling adapter.
7. Batch 5 / FI-6 and FI-7: full four-bed cycle driver and wrapper ledger/audit extraction.
8. Batch 6 / FI-8: commissioning and acceptance tests.
9. Later event, optimization, generalized-PFD, or tank/header extensions only
   after the fixed-duration direct-coupling surrogate is stable.

Do not generate new work from the old WP1-WP5 structure unless the user asks for
legacy analysis.

## Current Source Roles

### Final Implementation Context

Role:

- active source of truth for remaining final implementation work;
- active target definition for the H2/CO2 homogeneous activated-carbon surrogate;
- FI-1 through FI-8 and Batch 1 through Batch 6 routing;
- active state, adapter, ledger, and commissioning contracts.

Primary file:

- `docs/four_bed/FINAL_IMPLEMENTATION_CONTEXT.md`

### Yang 2009

Role:

- four-bed ten-step schedule source;
- operation-label and duration-label source;
- process-semantics source for direct transfer families;
- physical-model caveat source for validation positioning.

Not role:

- permission to add zeolite, CO, CH4, layered beds, or Yang/Aspen valve details
  to the first final surrogate;
- reason to rewrite toPSAil core physics;
- permission to introduce dynamic internal tanks;
- proof of validation merely because a schedule or wrapper exists.

### toPSAil

Role:

- numerical engine for existing single-bed and paired-bed behaviour;
- pressure-flow, boundary-condition, cycle, and metrics framework to preserve
  unless a narrow documented interface hook is explicitly needed.

Not role:

- automatic support guarantee for four persistent beds;
- automatic Yang external-basis metric reconstruction.

### Legacy Workflow Pack

Role:

- historical architecture rationale;
- old issue/test IDs;
- source anchors and risk cross-checking.

Not role:

- active implementation sequence;
- authority over final batch scope when it conflicts with
  `docs/four_bed/FINAL_IMPLEMENTATION_CONTEXT.md`.

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

### `docs/four_bed/`

Active four-bed routing and implementation guidance.

Read in this order:

- `README.md`
- `FINAL_IMPLEMENTATION_CONTEXT.md`
- the relevant active batch guide, if it exists.

The `WP Archive/` subfolder is legacy.

### `docs/workflow/`

Legacy branch planning inputs. Use these only for historical rationale,
contradiction checks, old test IDs, or source provenance.

### `sources/`

Local literature artifacts. PDFs are ignored by Git by default, so source
availability must also be recorded in `docs/SOURCE_LEDGER.md`.

### `cases/`

Project-specific case definitions and run scripts. Every case needs a
`case_spec.md` before implementation.

### `params/`

Project-specific parameter packs. Keep values source-specific and traceable.

### `validation/`

Validation manifests, expected targets, ledgers, and generated reports. Raw
source data and generated reports must stay separate.

### `tests/`

Small test suite for final implementation batches and legacy-risk regression
checks.

### `scripts/`

Convenience scripts for running tests and validation.

### `.codex/`

Codex configuration and reusable prompts. Retired prompts must say so clearly.

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
14. `docs/four_bed/README.md`
15. `docs/four_bed/FINAL_IMPLEMENTATION_CONTEXT.md`
16. The relevant active batch guide, if one exists.
17. The relevant case spec, if editing a case.

Read legacy `docs/workflow/` files only when a task requires historical source
context, old test IDs, or contradiction checks.

## Default Task Order

The next task should always be the smallest task that advances the current final
implementation batch or removes a documented blocker.

Never combine:

- new physics;
- new metrics;
- new validation thresholds;
- new plotting;
- new optimization;
- unrelated final batch ownership.

## Stop And Report If

- a source, final-context, or legacy workflow contradiction blocks the task;
- a required parameter, pair, mapping, or adapter contract is missing;
- a change would touch toPSAil core internals without explicit authorization;
- a direct-transfer or ledger mismatch has multiple plausible causes;
- MATLAB cannot run the required test;
- a task would skip the current final batch dependency;
- a test threshold would need changing.
