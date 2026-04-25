# Schell Two-Bed Validation Manifest

## Status

Scaffold only. Numerical targets and thresholds are not yet transcribed.

## Case

- `cases/schell_2bed_validation/`

## Parameter pack

- `params/schell2013_ap360_sips_binary/`

## Model mode

- Default: toPSAil-native pressure-flow, boundary-condition, cycle, equalisation, and auxiliary-unit handling.
- Optional future mode: labelled Schell-reproduction mode, only if explicitly authorised.

## Hard checks

- MATLAB completes without exception.
- No NaN or Inf.
- Positive absolute pressure.
- Positive absolute temperature.
- Valid mole fractions.
- CSS convergence metric reported.

## Soft targets

- H2 purity.
- H2 recovery.
- CO2 purity or capture where reconstructable.
- Pressure evolution.
- Temperature profiles.
- Stream accounting sanity.

## Default smoke inclusion

Not included in default smoke.
