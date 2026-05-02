# Yang H2/CO2 Activated-Carbon Surrogate Case

## Purpose

This case defines a Yang-inspired binary H2/CO2 homogeneous activated-carbon surrogate for later four-bed wrapper work.

It is not a full Yang reproduction.

## Model Basis

- Components are exactly `H2` and `CO2`, in that order.
- The feed is Yang's H2/CO2 subset renormalised over those two retained components only: `[0.7697228145; 0.2302771855]`.
- CO, CH4, pseudo-impurity components, and inert placeholders are excluded.
- The full Yang vessel length, 170 cm, is used by default and filled homogeneously with activated carbon.
- The original 100 cm activated-carbon layer and 70 cm zeolite 5A layer are preserved as metadata only.
- Zeolite 5A and axial layering are not enabled in this first surrogate.
- Pressure anchors are `PF = 9.0 atm` and `P4 = 1.3 atm`; intermediate pressure classes remain symbolic.

## Native DSL Mapping

The parameter pack uses toPSAil's native extended dual-site Langmuir-Freundlich model with:

- `modSp(1) = 6`
- `nSiteOneC = [1; 1]`
- `nSiteTwoC = [1; 1]`

Yang affinity constants are evaluated at the reference temperature for the native isothermal mapping and converted from `1/atm` to `1/bar`. The point-test script compares direct Yang DSL loading against the configured native toPSAil DSL mapping.

The activated-carbon `q_m` source-table values are retained as metadata and converted with a `1000x` loading-capacity factor for the active surrogate runtime basis. This corrects the earlier direct mol/kg transcription that made adsorbed capacities too small.

The native toPSAil temperature-dependence path has one heat parameter per component, while Yang's source formulas have site-specific exponential factors. Non-isothermal agreement is therefore a known caveat, not a validation claim.

## Scope Boundaries

Schedule duration normalisation and physical-state persistence cleanup are owned by Batch 1 and are not implemented here.

Direct-coupling adapters, custom PP-to-PU or AD&PP-to-BF adapters, full four-bed cycle drivers, ledgers, audit exports, and external-basis performance metrics are not implemented here.

This case creates no dynamic internal tanks, no shared header inventory, no global four-bed RHS/DAE, and no core adsorber-physics rewrite.
