# Casas-Lite Breakthrough Manifest

## Status

Scaffold only. Thresholds are not yet defined.

## Case

- `cases/casas_lite_breakthrough/`

## Parameter pack

- `params/casas2012_ap360_sips_binary/`

## Model mode

- toPSAil-native pressure-flow and boundary-condition handling.

## Hard checks

- MATLAB completes without exception.
- No NaN or Inf.
- Positive absolute pressure.
- Positive absolute temperature.
- Valid mole fractions.

## Soft targets

- Rough breakthrough timing.
- Credible thermal response.
- Solver health.

## Explicit non-targets

- Exact front shape.
- Detector/piping reproduction.
- Axial-dispersion validation.

## Default smoke inclusion

Not included in default smoke once implemented unless a later task defines a very small Tier 3 proxy.
