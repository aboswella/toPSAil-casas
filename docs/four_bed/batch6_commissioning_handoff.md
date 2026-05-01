# Batch 6 Commissioning Handoff

This note records the FI-8 commissioning layer added after the Batch 6 guide review.

## Scope

- The runtime path remains a thin four-bed wrapper around existing toPSAil bed-step behavior.
- No dynamic internal tanks, shared header inventory, global four-bed RHS/DAE, or core adsorber-physics rewrite was added.
- The runtime case remains the H2/CO2 homogeneous activated-carbon surrogate, not a full Yang layered four-component reproduction.

## Implemented Gates

- Runtime-finalized H2/CO2 AC template fields required by native `runPsaCycleStep`.
- One-bed native temporary case preparation from a two-bed runtime template.
- Native duration conversion from seconds through `tiScaleFac`.
- Native reports exposing `stStates` and `counterTailDeltas`.
- Physical-mole compatibility checks before external metrics and ledger balances are claimed.
- Adapter audit terminal physical-state checksums and explicit surrogate flags.
- Split simulation status fields: `runCompleted`, `cssPass`, `metricsPass`, and `acceptancePass`.
- Compact ledger artifact writer for stream, balance, metric, and summary outputs.

## Commissioning Command

```matlab
addpath(genpath(pwd));
run("scripts/run_four_bed_commissioning.m");
```

Use MATLAB R2026a on this machine:

```powershell
& 'C:\Program Files\MATLAB\R2026a\bin\matlab.exe' -batch "addpath(genpath(pwd)); run('scripts/run_four_bed_commissioning.m');"
```

## Remaining Positioning

The native and adapter smoke tests prove that the wrapper can reach the existing toPSAil runtime path on short H2/CO2 surrogate cases and that reports are auditable. They do not establish Yang validation agreement, cyclic steady state, sensitivity readiness, or optimized performance.
