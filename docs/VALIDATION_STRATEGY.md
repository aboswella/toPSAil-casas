# Validation Strategy

## Validation Order

1. Baseline unchanged toPSAil examples.
2. Static Yang manifest validation.
3. Explicit pair-map validation.
4. Persistent state writeback validation.
5. Temporary case-builder validation.
6. Direct-coupling toy and one-slot conservation checks.
7. Fixed-duration Yang skeleton with all-bed CSS diagnostics.
8. Yang-basis ledger and metric reporting.
9. Later numerical sensitivity, event policy, or optimization only after the wrapper path is stable.

Do not skip stages without recording the reason in the relevant task report.

## Manifest Objective

The manifest stage checks:

- source schedule transcription;
- bed `A/B/C/D` ten-step sequences;
- raw and normalized duration handling;
- label glossary completeness;
- pressure-class metadata;
- architecture flags;
- layered-bed support status or surrogate label.

The manifest is not a numerical validation result.

## Pair And State Objective

Pair and state tests check:

- every direct-transfer role has one explicit compatible partner;
- donor/receiver direction is correct;
- `EQI` and `EQII` remain distinct;
- `AD&PP` remains compound;
- temporary local bed indices write back to the correct persistent named beds;
- non-participating beds are not overwritten.

## Ledger Objective

Ledger tests check:

- external feed/product/waste streams are separated from internal transfers;
- internal direct transfers cancel in external-product accounting;
- component balances close by slot and by cycle;
- CSS residuals are reported over all persistent beds.

## Yang Comparison Objective

Do not claim Yang validation until:

- manifest, pair-map, state, case-builder, and conservation gates have passed;
- layered-bed and thermal assumptions are stated;
- model mismatches are documented;
- report metadata states wrapper mode, event policy, direct-coupling assumption, and metric basis.

## Validation Reporting

Every validation report must say:

- model mode;
- manifest version;
- pair-map version, if applicable;
- parameter set;
- source basis;
- grid/cell count;
- cycle count;
- CSS residual;
- runtime;
- hard failures;
- soft discrepancies;
- model limitations;
- interpretation.

## Validation Numbers Policy

Validation numbers may change only in tasks that explicitly allow validation outputs or manifests to change.

When validation numbers change, report:

- which manifest/report changed;
- whether the change came from parameters, physics, numerics, metrics, ledgers, or reporting;
- whether any threshold changed;
- why the change is physically and numerically defensible.

Do not tune physical constants or weaken thresholds to improve agreement.
