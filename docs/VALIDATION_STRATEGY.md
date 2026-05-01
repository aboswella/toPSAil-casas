# Validation Strategy

## Validation Target

The active target is a Yang-inspired H2/CO2 homogeneous activated-carbon
surrogate. Validation agreement with Yang 2009 is not claimed for the full
layered four-component process.

Validation should prove that the wrapper, adapters, state persistence, ledgers,
pressure diagnostics, and H2/CO2 external-basis metrics behave correctly.

## Validation Order

1. Baseline unchanged toPSAil examples.
2. Static schedule, pair-map, architecture, and no-tank checks.
3. H2/CO2 activated-carbon parameter-pack and DSL mapping checks.
4. Physical-state-only persistence and local/global writeback checks.
5. Native AD, BD, EQI, and EQII smoke tests where native machinery is suitable.
6. PP->PU and AD&PP->BF adapter unit checks.
7. One-slot conservation, pressure-diagnostic, and external/internal ledger
   checks.
8. One full normalized four-bed cycle.
9. CSS or max-cycle smoke with all-bed physical-state residual trends.
10. Valve-coefficient sensitivity sanity checks for optimization readiness.
11. Later numerical sensitivity, event policy, optimization, tank/header variants,
    or generalized-PFD work only after the wrapper path is stable.

Do not skip stages without recording the reason in the relevant task report.

## Schedule Objective

The schedule stage checks:

- source schedule transcription and labels;
- bed `A/B/C/D` ten-step sequences;
- raw duration labels preserved as metadata;
- executable normalized duration fractions `[1,6,1,4,1,1,4,1,1,5]/25`;
- label glossary and pressure-class metadata;
- architecture flags and no-tank/no-header/no-global-RHS guardrails.

The manifest is not a numerical validation result.

## Parameter Objective

The H2/CO2 AC parameter stage checks:

- component order `[H2; CO2]`;
- binary feed renormalization;
- activated-carbon-only homogeneous basis;
- excluded zeolite, CO, CH4, and pseudo-component behaviour;
- native DSL mapping at selected pressures, temperatures, and compositions.

If native DSL temperature dependence is not adequate for the intended thermal
mode, document the mismatch before adding any submodel hook.

## State And Adapter Objective

State and adapter tests check:

- only physical adsorber state persists between slots;
- cumulative counter tails are available for ledgers but not written back as bed
  state;
- temporary local bed indices write back to the correct persistent named beds;
- non-participating beds are not overwritten;
- PP->PU donor/receiver endpoints and waste outlet are correct;
- AD&PP->BF external product and internal BF branches are separated;
- adapter pressure endpoints, flow signs, valve coefficients, and conservation
  residuals are recorded.

## Ledger Objective

Ledger tests check:

- external feed/product/waste streams are separated from internal transfers;
- internal direct transfers cancel in external-product accounting;
- component balances close by slot and by cycle;
- final H2 purity and recovery use wrapper external-basis rows, not native
  metrics alone;
- CSS residuals are reported over all persistent physical bed states.

## Reporting Objective

Every validation or commissioning report must say:

- model mode;
- manifest and pair-map version, when applicable;
- parameter set;
- H2/CO2 renormalization basis;
- activated-carbon-only homogeneous basis;
- direct-coupling and no-dynamic-tank assumptions;
- event policy;
- grid/cell count;
- cycle count;
- CSS residual;
- runtime;
- hard failures;
- soft discrepancies;
- model limitations;
- interpretation.

## Validation Numbers Policy

Validation numbers may change only in tasks that explicitly allow validation
outputs, parameter packs, manifests, adapters, or metrics to change.

When validation numbers change, report:

- which manifest/report changed;
- whether the change came from parameters, physics, numerics, metrics, ledgers,
  adapters, or reporting;
- whether any threshold changed;
- why the change is physically and numerically defensible.

Do not tune physical constants or weaken thresholds to improve agreement.
