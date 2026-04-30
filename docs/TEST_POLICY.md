# Test Policy

## Philosophy

Use a small number of discriminating tests.

Do not add diagnostics unless they catch a named failure mode from `docs/workflow/four_bed_issue_register.csv` or a task-specific risk.

## Test Tiers

### Tier 0: toPSAil Baseline Smoke

Purpose:

- confirm the fork still runs before wrapper modifications.

Pass criteria:

- selected original examples complete;
- no uncaught MATLAB error;
- no NaN or Inf in final outputs where outputs are accessible.

### Static/Source: Manifest And Metadata

Purpose:

- ensure Yang schedule metadata is transcribed and represented correctly.

Examples:

- manifest row counts;
- bed `A/B/C/D` sequences;
- operation labels;
- duration parsing and normalization;
- pressure classes;
- architecture flags;
- layered-bed capability audit.

### Unit: Pair, State, And Case-Builder Checks

Purpose:

- ensure wrapper mechanics behave before full-cycle runs.

Examples:

- direct-transfer pair completeness;
- donor/receiver direction;
- persistent state writeback;
- non-participant state preservation;
- temporary case isolation;
- endpoint and flow-direction checks.

### Sanity/Integration: Conservation And Ledgers

Purpose:

- catch accounting, inventory, and boundary failures before full Yang pilots.

Examples:

- pair-local conservation;
- slot-level component balance;
- external/internal ledger separation;
- CSS residual shape;
- finite pressure, temperature, flow, and composition outputs.

### Pilot Validation: Yang Skeleton

Purpose:

- compare fixed-duration wrapper behaviour to the source schedule only after earlier gates pass.

These are not default smoke tests unless explicitly lightweight and listed as default in `docs/workflow/four_bed_test_matrix.csv`.

### Later Extensions

Purpose:

- sensitivity, optimization, event policy, tank/header variants, or generalized-PFD work only after the fixed-duration wrapper is stable.

Never run by default.

## Default Commands

When the corresponding scripts exist, use:

```matlab
addpath(genpath(pwd));
run("scripts/run_smoke.m");
run("scripts/run_source_tests.m");
run("scripts/run_equation_tests.m");
run("scripts/run_sanity_tests.m");
```

The default smoke command must not hide long validation, sensitivity, optimization, or event-policy runs.

## Hard Failures

Hard failures include:

- MATLAB exception;
- NaN or Inf;
- negative absolute pressure;
- negative absolute temperature;
- invalid mole fractions;
- mole fractions not summing to acceptable tolerance;
- source transcription mismatch;
- state writeback to the wrong named bed;
- non-participant bed state mutation;
- missing direct-transfer partner;
- internal transfer counted as external product;
- non-conservation in closed systems beyond tolerance.

## Soft Validation Failures

Soft failures include:

- source-performance mismatch;
- temperature profile mismatch;
- productivity mismatch;
- pressure endpoint mismatch when assumptions are documented.

Soft failures should be reported, not automatically patched by changing physics.

## New Test Rule

Every new test must state:

- test tier;
- named failure mode caught;
- source or policy basis;
- required runtime class;
- whether it is included in default smoke.
