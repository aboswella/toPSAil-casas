# Casas 2012 AP3-60 Sips Binary Pack

Purpose:
- H2/CO2 Casas-lite breakthrough sanity case.

Allowed sources:
- Casas 2012 paper;
- Casas thesis only for contextual design/optimisation notes, not parameter blending.

Do not include:
- Schell validation-specific approximations;
- Delgado BPL/13X constants;
- contaminant polishing constants.

Status:
- source-transcribed parameter loader added in
  `load_casas2012_ap360_sips_binary.m`.

Default model posture:
- `model_mode = topsail_native_wrapper`;
- exact Casas competitive Sips and the binary Casas-lite breakthrough
  equations are implemented in project-specific wrappers because the
  toPSAil public custom-isotherm path is not enabled;
- no toPSAil core files are modified by this pack.

Known approximations:
- the source initial gas `He` is recorded and transported as a
  nonadsorbing void gas in the first Casas-lite runner; adsorption remains
  binary CO2/H2;
- the reported `10 cm3/s` feed flow is used directly as the inlet
  volumetric flow for Casas-lite, with no standard-state molar conversion;
- detector piping and exact axial-dispersion/front-shape reproduction are
  not enabled by default.
