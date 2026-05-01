# Test Policy

## Philosophy

Use a small number of discriminating tests.

Do not add diagnostics unless they catch a named final-implementation risk, a
legacy issue-register failure mode that still applies, or a task-specific risk.

## Active Test Tiers

### Tier 0: toPSAil Baseline Smoke

Purpose:

- confirm the fork still runs before wrapper or adapter modifications.

Pass criteria:

- selected original examples complete;
- no uncaught MATLAB error;
- no NaN or Inf in final outputs where outputs are accessible.

### Static/Source: Manifest And Metadata

Purpose:

- ensure Yang schedule metadata and final executable timing policy are represented
  correctly.

Examples:

- manifest row counts;
- bed `A/B/C/D` sequences;
- operation labels;
- raw duration labels preserved;
- normalized slot duration helper;
- pressure classes;
- architecture flags;
- no dynamic tank/header inventory guard.

### Parameter: H2/CO2 AC Surrogate

Purpose:

- ensure the final surrogate parameter pack matches the active model basis.

Examples:

- component order `[H2; CO2]`;
- binary-renormalized feed;
- activated-carbon-only homogeneous basis;
- native DSL mapping smoke tests;
- explicit exclusion of zeolite, CO, CH4, pseudo-components, and layered beds.

### Unit: Pair, State, Case-Builder, And Adapter Checks

Purpose:

- ensure wrapper mechanics behave before full-cycle runs.

Examples:

- direct-transfer pair completeness;
- donor/receiver direction;
- physical-state-only writeback;
- counter-tail extraction;
- non-participant state preservation;
- temporary case isolation;
- endpoint and flow-direction checks;
- PP->PU and AD&PP->BF adapter conservation.

### Sanity/Integration: Conservation And Ledgers

Purpose:

- catch accounting, inventory, pressure, and boundary failures before full
  surrogate pilots.

Examples:

- pair-local conservation;
- slot-level component balance;
- external/internal ledger separation;
- pressure endpoint diagnostics;
- all-bed physical-state CSS residual shape;
- finite pressure, temperature, flow, and composition outputs.

### Pilot Validation: Normalized Yang Surrogate

Purpose:

- exercise the fixed-duration H2/CO2 AC surrogate after earlier gates pass.

These are not default smoke tests unless explicitly lightweight.

### Later Extensions

Purpose:

- sensitivity, optimization, event policy, tank/header variants, or generalized
  PFD work only after the fixed-duration wrapper is stable.

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

The default smoke command must not hide long validation, sensitivity,
optimization, or event-policy runs.

## Hard Failures

Hard failures include:

- MATLAB exception;
- NaN or Inf;
- negative absolute pressure;
- negative absolute temperature;
- invalid mole fractions;
- mole fractions not summing to acceptable tolerance;
- source transcription mismatch;
- executable duration fractions not summing to one;
- state writeback to the wrong named bed;
- non-participant bed state mutation;
- cumulative counter tails persisted as bed physical state;
- missing direct-transfer partner;
- PP->PU or AD&PP->BF adapter conservation failure;
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
- final implementation item or batch protected;
- named failure mode caught;
- source or policy basis;
- required runtime class;
- whether it is included in default smoke.

Legacy test IDs from `docs/workflow/four_bed_test_matrix.csv` may be retained for
traceability when they still match the active failure mode. They do not define
new active scope by themselves.
