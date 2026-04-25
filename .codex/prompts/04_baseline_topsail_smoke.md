Codex Task 01: Baseline toPSAil Smoke Test
Objective

Prove that the unmodified upstream toPSAil code works before any project-specific Casas, Schell, Delgado, sensitivity, optimisation, or solver modifications are attempted.

This task is Phase 1 only.

Required reading before doing anything

Read these files first:

AGENTS.md
docs/workflow/codex_baseline_and_casas_execution_plan.md
docs/CODEX_PROJECT_MAP.md
docs/GIT_WORKFLOW.md
docs/TEST_POLICY.md
docs/MODEL_SCOPE.md
docs/KNOWN_UNCERTAINTIES.md

Follow the principles, gates, and stop conditions in those files.

Scope

You may:

inspect the repository;
identify the smallest reliable original toPSAil example;
run the original example manually in MATLAB;
create a minimal Tier 0 smoke runner only after the original example has been identified and run;
document the baseline result.

You may not:

modify toPSAil solver internals;
modify original examples;
add Casas parameters;
add Schell, Delgado, sensitivity, or optimisation logic;
tune model parameters;
weaken checks or thresholds;
begin Phase 2.
Required preflight checks

Before running or editing anything, report the output of these commands:

git status --short
git branch --show-current
git remote -v

Then confirm that these directories exist:

1_config/
2_run/
3_source/
4_example/
5_reference/
6_publication/

If any are missing, stop and report the blocker.

Required audit

Identify and report:

the original toPSAil example chosen for the smoke test;
why it is the smallest reliable baseline;
which files it reads;
which scripts or functions it calls;
what outputs indicate successful completion;
whether MATLAB path setup is required.
Implementation rules

Only after the original example has run manually, create:

scripts/run_smoke.m

Optional documentation files:

scripts/README.md
tests/README.md
docs/KNOWN_UNCERTAINTIES.md

Only edit docs/KNOWN_UNCERTAINTIES.md if a real blocker or ambiguity must be recorded.

Do not edit:

1_config/
2_run/
3_source/
4_example/
5_reference/
6_publication/
Required MATLAB command

The smoke runner must be executable using this MATLAB command:

addpath(genpath(pwd)); run("scripts/run_smoke.m");
Required checks

After running the smoke test, verify the working tree with:

git status --short

Confirm that no core toPSAil files have changed.

Deliverables

Produce:

a short summary of the original example selected;
scripts/run_smoke.m;
the MATLAB command used;
the observed pass/fail result;
any warnings or known limitations;
confirmation that Phase 2 has not begun.
Stop condition

Stop after the Tier 0 baseline smoke test has passed or after a blocker has been documented.

Do not continue into Casas breakthrough validation.