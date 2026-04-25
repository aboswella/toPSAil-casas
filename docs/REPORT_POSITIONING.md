# Report Positioning

## Core report claim

Use this position unless later evidence changes the project direction:

> The simulator uses toPSAil's native pressure-flow, boundary-condition, cycle, equalisation, and auxiliary-unit framework. Schell is used to validate dominant PSA behaviour rather than to force exact solver equivalence.

## Casas language

Casas-lite is a sanity validation:

- breakthrough timing should be roughly credible;
- thermal response should be physically plausible;
- solver health should be good;
- exact front shape, axial-dispersion matching, and detector/piping reproduction are not the target.

## Schell language

Schell is the primary experimental full-cycle validation anchor:

- H2/CO2 two-bed PSA;
- pressure equalisation;
- temperature profiles;
- purity and recovery metrics.

Differences from Schell boundary-condition implementation are expected and defensible when using the default toPSAil-native model. Do not describe such differences as errors unless a dedicated validation task shows they dominate the mismatch.

## Delgado language

Delgado supports extension work:

- BPL activated carbon and 13X zeolite data;
- H2/CO/CH4/CO2 contaminant-polishing concept;
- possible layered-bed report extension.

Do not present Delgado PSA agreement as experimental validation.

## Validation caveat

Validation agreement alone is not proof of correctness. Reports must also address:

- source traceability,
- physical sanity,
- numerical health,
- validation agreement,
- optimisation performance only after validation is stable.
