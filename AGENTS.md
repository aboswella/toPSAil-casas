# AGENTS.md

## Project purpose

This repository is a fork of toPSAil used to build and validate a MATLAB pressure swing adsorption model for H2/CO2 separation.

The project sequence is:

1. Confirm unmodified toPSAil runs.
2. Build a Casas-lite breakthrough sanity case.
3. Validate a Schell-style two-bed H2/CO2 PSA case.
4. Add a Delgado-inspired layered-bed / contaminant-polishing extension if time permits.
5. Add sensitivity and optimisation wrappers only after validation cases are stable.

Correctness means:

1. source traceability,
2. physical sanity,
3. numerical health,
4. validation agreement,
5. optimisation performance.

Validation agreement alone is not proof of correctness.

## Required reading before edits

Before editing code or project-control files, read:

- docs/PROJECT_CHARTER.md
- docs/CODEX_PROJECT_MAP.md
- docs/MODEL_SCOPE.md
- docs/SOURCE_LEDGER.md
- docs/source_reference/00_source_reference_index.md
- docs/VALIDATION_STRATEGY.md
- docs/TEST_POLICY.md
- docs/BOUNDARY_CONDITION_POLICY.md
- docs/THERMAL_MODEL_POLICY.md
- docs/TASK_PROTOCOL.md
- docs/KNOWN_UNCERTAINTIES.md
- docs/REPORT_POSITIONING.md
- docs/GIT_WORKFLOW.md

Before editing any case, also read that case's `case_spec.md`.

Before editing any reusable Codex prompt, also read `docs/TASK_PROTOCOL.md`.

Before transcribing source parameters or source-derived validation targets, read the relevant file under `docs/source_reference/`.

## Non-negotiable rules

- Do not modify toPSAil core files unless the task explicitly allows it.
- Prefer wrappers, case files, parameter files, and tests over solver changes.
- Do not change boundary-condition machinery unless a task explicitly authorises it.
- Do not mix Schell-specific validation approximations into the default toPSAil-native model.
- Do not tune physical constants to improve validation agreement.
- Do not change physics, numerics, metrics, plotting, and validation thresholds in the same task.
- Do not weaken tests or tolerances to make a run pass.
- Do not silently resolve literature ambiguities. Record them in `docs/KNOWN_UNCERTAINTIES.md`.
- Do not bypass `docs/source_reference/` when a source-derived value is already documented there.
- Do not add broad diagnostic clutter. Every new test must state what failure mode it catches.
- Do not make full validation or optimisation runs part of the default smoke suite.
- Do not create new parameter packs by blending constants from different sources unless the task explicitly asks for a labelled exploratory pack.
- Do not treat Delgado simulation agreement as experimental validation.
- Do not change generated validation numbers without saying which manifest/report changed and why.

## Core file boundary

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

## Model policy

The base model should use toPSAil-native pressure-flow and boundary-condition handling.

Schell is used as an experimental validation target, not as a mandate to rewrite toPSAil internals.

Casas breakthrough is a sanity validation. Exact front shape is not the target.

Delgado is used for layered-bed and contaminant-polishing extension work. It is not the primary experimental validation target.

Keep parameter packs separate:

- `params/casas2012_ap360_sips_binary/`
- `params/schell2013_ap360_sips_binary/`
- `params/delgado2014_bpl13x_lf_four_component/`

## Source reference policy

Use `docs/source_reference/` as the first source of truth for literature-derived parameters, source notes, and validation targets.

Read:

- `docs/source_reference/01_casas_2012_breakthrough_validation.md` for Casas-lite breakthrough work.
- `docs/source_reference/02_schell_2013_two_bed_psa_validation.md` for Schell two-bed validation work.
- `docs/source_reference/03_delgado_2014_layered_bed_extension.md` for Delgado layered-bed or contaminant-polishing extension work.
- `docs/source_reference/04_casas_thesis_sensitivity_optimisation.md` for later sensitivity and optimisation framing.
- `docs/source_reference/05_transcription_audit_and_guardrails.md` when transcribing, auditing, or correcting source-derived values.

Open original PDFs only when a value is absent, internally inconsistent, or the task explicitly permits source lookup or source-reference correction.

## Thermal policy

Do not assume adiabatic operation by default for small-column validation.

Thermal behaviour must be treated explicitly in Schell validation and later sensitivity analysis.

Allowed thermal modes:

- finite wall heat transfer,
- adiabatic sensitivity case,
- isothermal or fixed-wall approximation if explicitly documented.

## Testing policy

Use the smallest meaningful test.

Test tiers:

- Tier 0: unchanged toPSAil baseline examples.
- Tier 1: source/parameter transcription tests.
- Tier 2: equation-local tests.
- Tier 3: one-step physical sanity tests.
- Tier 4: validation cases.
- Tier 5: sensitivity/optimisation.

Default test command must not run Tier 4 or Tier 5.

## Required report after every task

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

## Stop conditions

Stop and report instead of editing if:

- a source is ambiguous,
- a parameter is missing,
- a proposed change touches toPSAil core internals without explicit authorisation,
- validation mismatch has multiple plausible causes,
- a test threshold would need to change,
- the task requires full optimisation,
- MATLAB cannot run the required test,
- the change would mix validation modes.

## MATLAB commands

Use these commands when available:

```matlab
addpath(genpath(pwd));
run("scripts/run_smoke.m");
run("scripts/run_source_tests.m");
run("scripts/run_equation_tests.m");
run("scripts/run_sanity_tests.m");
```

Do not make Tier 4 validation or Tier 5 sensitivity/optimisation part of the default smoke command.
