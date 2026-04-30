# AGENTS.md

## Project Purpose

This repository is a fork of toPSAil used to implement and validate a MATLAB four-bed PSA workflow based on the Yang 2009 ten-step cycle.

The current branch objective is a minimally invasive four-bed orchestration layer around existing toPSAil bed-step behaviour. It is not a rewrite of the adsorber physics or a new four-bed process-network solver.

The project sequence is:

1. Confirm unmodified toPSAil examples still run.
2. Lock the four-bed architecture: no dynamic internal tanks, no shared header inventory, no global four-bed RHS/DAE, and no core adsorber-physics rewrite.
3. Build WP1: the Yang schedule manifest, duration normalization, label glossary, pressure-class metadata, and layered-bed capability audit.
4. Build WP2: explicit direct-transfer pair mapping.
5. Build WP3: persistent named bed state storage for beds A, B, C, and D.
6. Build WP4: temporary two-bed or single-bed case builders that invoke existing toPSAil machinery.
7. Build WP5: external/internal ledgers, all-bed CSS reporting, and Yang-basis metrics.
8. Consider event control, optimization, generalized PFD work, or tank/header extensions only after the fixed-duration direct-coupling path is stable.

Correctness means:

1. source traceability,
2. architecture discipline,
3. schedule and pair-map integrity,
4. persistent state writeback correctness,
5. conservation and ledger consistency,
6. numerical health,
7. clear validation positioning.

Validation agreement alone is not proof of correctness.

## Required Reading Before Edits

Before editing code or project-control files, read:

- `docs/PROJECT_CHARTER.md`
- `docs/CODEX_PROJECT_MAP.md`
- `docs/MODEL_SCOPE.md`
- `docs/SOURCE_LEDGER.md`
- `docs/source_reference/00_source_reference_index.md`
- `docs/VALIDATION_STRATEGY.md`
- `docs/TEST_POLICY.md`
- `docs/BOUNDARY_CONDITION_POLICY.md`
- `docs/THERMAL_MODEL_POLICY.md`
- `docs/TASK_PROTOCOL.md`
- `docs/KNOWN_UNCERTAINTIES.md`
- `docs/REPORT_POSITIONING.md`
- `docs/GIT_WORKFLOW.md`

For Yang four-bed work, also read:

- `docs/workflow/four_bed_project_context_file_map.txt`
- `docs/workflow/four_bed_executive_summary.csv`
- `docs/workflow/four_bed_work_packages.csv`
- `docs/workflow/four_bed_architecture_map.csv`
- `docs/workflow/four_bed_test_matrix.csv`
- `docs/workflow/four_bed_issue_register.csv`
- `docs/workflow/four_bed_yang_manifest.csv`
- `docs/workflow/four_bed_stage_gates.csv`
- `docs/workflow/four_bed_evidence_notes.csv`

For WP1 implementation, additionally read:

- `docs/workflow/Work package guidance docs/WP1_yang_schedule_manifest_guidance.md`

Before editing any case, also read that case's `case_spec.md`.

Before editing any reusable Codex prompt, also read `docs/TASK_PROTOCOL.md`.

Before transcribing source parameters or source-derived validation targets, read the relevant workflow file under `docs/workflow/` and the source ledger.

## Non-Negotiable Rules

- Do not modify toPSAil core files unless the task explicitly allows it.
- Prefer wrappers, manifests, case files, parameter files, ledgers, and tests over solver changes.
- Do not create dynamic internal tanks or shared header inventory for Yang internal transfers.
- Do not assemble a global four-bed RHS/DAE state vector.
- Do not rewrite adsorption, energy, pressure-flow, momentum, or valve equations for schedule work.
- Do not infer bed pairings from source table row order, bed adjacency, or native two-bed assumptions.
- Do not collapse `EQI` and `EQII` into one unlabelled equalization category.
- Do not treat `AD&PP` as ordinary adsorption.
- Do not count internal direct-transfer gas as external product.
- Do not silently rescale Yang duration labels; expose both raw and normalized duration interpretations.
- Do not invent numeric values for symbolic intermediate pressure classes.
- Do not add event-based scheduling before the fixed-duration direct-coupling path passes its gates.
- Do not claim Yang validation merely because the manifest or wrapper exists.
- Do not tune physical constants to improve agreement.
- Do not change physics, numerics, metrics, plotting, and validation thresholds in the same task.
- Do not weaken tests or tolerances to make a run pass.
- Do not silently resolve literature or planning ambiguities. Record them in `docs/KNOWN_UNCERTAINTIES.md`.
- Do not add broad diagnostic clutter. Every new test must state what failure mode it catches.
- Do not make long numerical sensitivity or optimization runs part of the default smoke suite.
- Do not change generated validation numbers without saying which manifest/report changed and why.

## Core File Boundary

Treat these as toPSAil core unless a task explicitly authorises edits:

- `1_config/`
- `2_run/`
- `3_source/`
- `4_example/`
- `5_reference/`
- `6_publication/`

Project-specific work should normally stay in:

- `cases/`
- `params/`
- `validation/`
- `scripts/`
- `tests/`
- `docs/`
- `.codex/`

## Model Policy

The Yang four-bed implementation should be a thin orchestration layer around toPSAil-native bed-step behaviour.

The wrapper should maintain four persistent named bed states:

- `A`
- `B`
- `C`
- `D`

For each cycle slot, the wrapper should select the relevant single bed or explicitly paired beds, invoke existing toPSAil-compatible machinery on those temporary local states, then write terminal states back only to the participating named beds.

Internal Yang transfers are direct bed-to-bed couplings. They are not dynamic tanks, shared headers, external product streams, or global flowsheet inventory.

Keep work-package boundaries clear:

- WP1 owns schedule manifest metadata, label semantics, duration handling, pressure classes, and capability audit.
- WP2 owns pair identities.
- WP3 owns persistent state storage and writeback.
- WP4 owns temporary case construction around existing toPSAil machinery.
- WP5 owns ledgers, CSS, metrics, and reporting.

## Source and Workflow Policy

Use `docs/workflow/` as the first source of truth for branch planning, architecture, work packages, tests, stage gates, and issue registers.

Use `sources/Yang 2009 4-bed 10-step relevant.pdf` as the local literature artifact for source checks when a task explicitly requires source confirmation.

Start with:

- `docs/workflow/four_bed_project_context_file_map.txt` for routing.
- `docs/workflow/four_bed_executive_summary.csv` for the high-level architecture summary.
- `docs/workflow/four_bed_work_packages.csv` for work-package scope.
- `docs/workflow/four_bed_architecture_map.csv` for architecture constraints.
- `docs/workflow/four_bed_issue_register.csv` before proposing fixes.
- `docs/workflow/four_bed_test_matrix.csv` for required tests.
- `docs/workflow/four_bed_yang_manifest.csv` for the source schedule skeleton.
- `docs/workflow/four_bed_stage_gates.csv` for development order.
- `docs/workflow/four_bed_evidence_notes.csv` for source anchors and rationale.

Open original PDFs only when a value is absent, internally inconsistent, or the task explicitly permits source lookup or source-reference correction.

## Thermal and Layered-Bed Policy

Yang uses non-isothermal layered beds. Do not claim a physically faithful Yang reproduction until layered-bed capability and thermal assumptions have been audited and documented.

Allowed near-term positions:

- layered-bed support confirmed,
- homogeneous surrogate explicitly labelled,
- thermal mode explicitly documented,
- missing thermal or material parameters recorded as uncertainties.

WP1 may audit layered-bed support but must not implement layered-bed physics.

## Testing Policy

Use the smallest meaningful test.

Test tiers:

- Tier 0: unchanged toPSAil baseline examples.
- Static/source: Yang manifest, duration, label, pressure-class, architecture-flag, and layered-bed audit checks.
- Unit: pair mapping, direct-transfer role, persistent state, and temporary case-builder checks.
- Sanity/integration: conservation, external/internal ledgers, flow direction, and one-slot checks.
- Pilot validation: fixed-duration Yang skeleton, all-bed CSS, and Yang-basis metrics after earlier gates pass.
- Later extensions: sensitivity, optimization, event control, tank/header variants, or generalized PFD work.

Default test commands must not hide long validation, sensitivity, optimization, or event-policy runs.

Use these commands when available:

```matlab
addpath(genpath(pwd));
run("scripts/run_smoke.m");
run("scripts/run_source_tests.m");
run("scripts/run_equation_tests.m");
run("scripts/run_sanity_tests.m");
```

Map new tests to `docs/workflow/four_bed_test_matrix.csv` and state which failure mode each test catches.

## Required Report After Every Task

Every Codex task must end with:

- task objective,
- files changed,
- files inspected,
- commands run,
- tests passed,
- tests failed,
- unresolved uncertainties,
- whether any toPSAil core files changed,
- whether any validation numbers changed,
- next smallest recommended task.

## Stop Conditions

Stop and report instead of editing if:

- a source or planning file is ambiguous,
- a required parameter or mapping is missing,
- a proposed change touches toPSAil core internals without explicit authorisation,
- a direct-transfer mismatch has multiple plausible causes,
- a test threshold would need to change,
- MATLAB cannot run the required test,
- the task requires full optimization,
- the change would mix work-package responsibilities in a way that obscures review.

## MATLAB Commands

Use MATLAB R2026a for this repository when launching MATLAB from the shell:

```powershell
& 'C:\Program Files\MATLAB\R2026a\bin\matlab.exe' -batch "<matlab command>"
```

The bare `matlab` command may still resolve to R2025b on this machine, which previously lacked visible Optimization Toolbox functions needed by toPSAil (`linprog`, `fsolve`).

## Search Commands

`rg` is available and working on this machine. Use `rg` and `rg --files` as the first-choice repository search commands.
