# Casas-Lite Breakthrough Manifest

## Status

Initial Casas-lite wrapper implemented. Hard health checks are defined;
soft timing comparisons remain narrative and are not pass/fail thresholds.

## Case

- `cases/casas_lite_breakthrough/`

## Parameter pack

- `params/casas2012_ap360_sips_binary/`

## Model mode

- requested posture: toPSAil-native pressure-flow and boundary-condition handling.
- implemented first wrapper: `topsail_native_wrapper`.
- reason: exact Casas competitive Sips is not available through the public
  toPSAil custom-isotherm path without editing core files, so the exact
  Casas Sips/LDF breakthrough equations are kept in project-specific files.

## Hard checks

- MATLAB completes without exception.
- No NaN or Inf.
- Positive absolute pressure.
- Positive absolute temperature.
- Valid mole fractions.

## Soft targets

- H2 breakthrough time about 110 s.
- H2 outlet mole fraction rises near 110-130 s.
- CO2 breakthrough begins roughly 430-460 s by plot-read.
- Final outlet composition approaches 50/50 feed.
- Small H2 heat front precedes larger CO2 front.

These are soft comparisons only. No source constants or validation
thresholds may be tuned to force agreement.

## Explicit non-targets

- Exact front shape.
- Detector/piping reproduction.
- Axial-dispersion validation.
- Adsorbing He or He-specific gas properties in the first binary adsorption
  wrapper.
- Separate wall-temperature validation in the first wrapper.

## Source Values

- source_reference_file = `docs/source_reference/01_casas_2012_breakthrough_validation.md`
- parameter_pack = `params/casas2012_ap360_sips_binary`
- source_values_changed = no
- validation_thresholds_changed = no

## Known Approximations

- `10 cm3/s` is used directly as inlet volumetric flow; no standard-state
  conversion is applied.
- Initial `He` is transported as nonadsorbing void gas while adsorption
  remains binary CO2/H2.
- Thermal mode is a simplified single lumped bed/wall temperature using
  source `hW` and `C_w`.

## Default smoke inclusion

Not included in default smoke once implemented unless a later task defines a very small Tier 3 proxy.
