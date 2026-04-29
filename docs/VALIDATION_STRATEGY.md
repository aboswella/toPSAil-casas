# Validation Strategy

## Validation order

1. Baseline toPSAil examples.
2. Casas-lite breakthrough sanity.
3. Schell two-bed H2/CO2 PSA validation.
4. Delgado layered-bed simulation reproduction.
5. Sensitivity.
6. Optimisation.

Do not skip stages without recording the reason in the relevant task report.

## Casas-lite objective

Casas-lite is used to check:

- breakthrough occurs at a credible time;
- thermal response is plausible;
- solver health is acceptable;
- no severe mass or boundary pathology occurs.

Exact front shape and detector-piping reproduction are not objectives.

## Schell objective

Schell is the primary experimental full-cycle validation.

Required comparisons:

- H2 purity;
- H2 recovery;
- CO2 purity/capture, where reconstructable;
- pressure evolution;
- temperature profiles;
- CSS convergence.

The default comparison should use toPSAil-native pressure-flow and boundary-condition handling. A separate Schell-reproduction mode is allowed only if it is explicitly labelled and justified.

## Delgado objective

Delgado is used for extension work involving:

- BPL activated carbon;
- 13X zeolite;
- H2/CO/CH4/CO2 contaminants;
- layered-bed polishing;
- H2 purity/recovery/productivity.

Delgado reproduction is simulation-to-simulation, not experimental validation.

## Validation reporting

Every validation report must say:

- model mode;
- parameter set;
- source;
- grid/cell count;
- cycle count;
- CSS residual;
- runtime;
- hard failures;
- soft discrepancies;
- interpretation.

## Validation numbers policy

Validation numbers may change only in tasks that explicitly allow validation outputs or manifests to change.

When validation numbers change, report:

- which case and manifest changed;
- whether the change came from parameters, physics, numerics, metrics, or reporting;
- whether any threshold changed;
- why the change is physically and numerically defensible.

Do not tune physical constants or weaken thresholds to improve agreement.
