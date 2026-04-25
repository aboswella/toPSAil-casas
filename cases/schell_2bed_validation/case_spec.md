# Schell Two-Bed Validation Case Spec

## Role

Schell 2013 is the primary experimental full-cycle validation target for H2/CO2 PSA behaviour.

## Source basis

- `docs/SOURCE_LEDGER.md`
- `sources/Schell 2013.pdf`
- `sources/Schell 2013 SI.pdf`

## Required model posture

- Use toPSAil-native pressure-flow, boundary-condition, cycle, equalisation, and auxiliary-unit machinery first.
- Do not rewrite toPSAil internals to match Schell boundary conditions unless a separate authorised task creates a labelled reproduction mode.
- Do not mix Schell-specific approximations into the default model.

## Parameter pack

Expected parameter folder:

- `params/schell2013_ap360_sips_binary/`

Do not mix Delgado BPL/13X or contaminant constants into this parameter pack.

## Thermal mode

Thermal behaviour must be explicit. Finite wall heat transfer is the preferred default for small-column validation when source parameters are available or can be defensibly bracketed. Adiabatic operation is a sensitivity case, not the default assumption.

## Validation targets

Required comparisons:

- H2 purity;
- H2 recovery;
- CO2 purity or capture where reconstructable;
- pressure evolution;
- temperature profiles;
- CSS convergence;
- stream accounting sanity.

## Stop conditions

Stop instead of editing if:

- thermal parameters are missing or ambiguous;
- pressure equalisation requires a non-native implementation;
- multiple plausible causes explain a validation mismatch;
- a threshold would need weakening;
- implementation would change physics, numerics, metrics, and plotting in one task.
