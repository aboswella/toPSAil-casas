# Test Policy

## Philosophy

Use a small number of discriminating tests.

Do not add diagnostics unless they catch a named failure mode.

## Test tiers

### Tier 0: toPSAil baseline smoke

Purpose:
- confirm the fork runs before modification.

Pass criteria:
- selected original examples complete;
- no uncaught MATLAB error;
- no NaN or Inf in final outputs.

### Tier 1: source transcription

Purpose:
- ensure source parameters are loaded correctly.

Examples:
- bed dimensions;
- feed composition;
- pressure levels;
- isotherm constants;
- kinetic constants;
- heat-of-adsorption values;
- unit conversions.

### Tier 2: equation-local

Purpose:
- ensure isolated equations behave correctly.

Examples:
- isotherm monotonicity;
- LDF sign;
- mole fraction normalisation;
- adsorption heat sign.

### Tier 3: one-step physical sanity

Purpose:
- catch boundary, inventory, and solver failures before full cycles.

Examples:
- closed-bed sanity;
- one adsorption step;
- one blowdown step;
- one purge step;
- one equalisation step.

### Tier 4: validation cases

Purpose:
- compare to Casas, Schell, and Delgado.

These are not default smoke tests.

### Tier 5: sensitivity and optimisation

Purpose:
- design exploration only after validation is stable.

Never run by default.

## Default commands

When the corresponding scripts exist, use:

```matlab
addpath(genpath(pwd));
run("scripts/run_smoke.m");
run("scripts/run_source_tests.m");
run("scripts/run_equation_tests.m");
run("scripts/run_sanity_tests.m");
```

The default smoke command must not run Tier 4 validation or Tier 5 sensitivity/optimisation.

## Hard failures

Hard failures include:

- MATLAB exception;
- NaN or Inf;
- negative absolute pressure;
- negative absolute temperature;
- invalid mole fractions;
- mole fractions not summing to acceptable tolerance;
- source transcription mismatch;
- non-conservation in closed systems beyond tolerance.

## Soft validation failures

Soft failures include:

- breakthrough time mismatch;
- purity/recovery mismatch;
- temperature profile mismatch;
- productivity mismatch.

Soft failures should be reported, not automatically patched by changing physics.

## New test rule

Every new test must state:

- test tier;
- named failure mode caught;
- source or policy basis;
- required runtime class;
- whether it is included in default smoke.
