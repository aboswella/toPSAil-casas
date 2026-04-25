# Validation Strategy

## Validation order

1. Baseline toPSAil examples.
2. Casas-lite breakthrough sanity.
3. Schell two-bed H2/CO2 PSA validation.
4. Delgado layered-bed simulation reproduction.
5. Sensitivity.
6. Optimisation.

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