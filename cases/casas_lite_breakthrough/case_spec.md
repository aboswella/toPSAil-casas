# Casas-Lite Breakthrough Case Spec

## Role

Casas-lite is a breakthrough sanity validation for H2/CO2 adsorption behaviour on AP3-60-style activated carbon. It is not an exact breakthrough-front reproduction target.

## Source basis

- `docs/SOURCE_LEDGER.md`
- `sources/Casas 2012.pdf`
- `sources/Casas thesis 2012.pdf` for later contextual scheduling/optimisation discussion only

## Required model posture

- Use toPSAil-native pressure-flow and boundary-condition machinery.
- Prefer wrappers, case files, and parameter packs over core edits.
- Treat axial dispersion, detector piping, and exact front shape as out of scope for this case.

## Parameter pack

Expected parameter folder:

- `params/casas2012_ap360_sips_binary/`

Do not mix Schell or Delgado constants into this parameter pack.

## Thermal mode

Finite wall heat transfer or another documented non-adiabatic mode is preferred when source information permits. If a required thermal parameter is missing, record it in `docs/KNOWN_UNCERTAINTIES.md`.

## Validation targets

Hard checks:

- MATLAB run completes;
- no NaN or Inf;
- positive absolute pressure;
- positive absolute temperature;
- valid mole fractions.

Soft checks:

- breakthrough timing is roughly credible;
- temperature response is physically plausible;
- solver health is acceptable.

## Stop conditions

Stop instead of editing if:

- a required source parameter is missing;
- implementing the case would require toPSAil core boundary-condition edits;
- a validation threshold would need to be invented without manifest support;
- the task would also change Schell or Delgado validation logic.
