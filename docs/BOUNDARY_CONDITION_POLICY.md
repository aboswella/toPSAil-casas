# Boundary Condition Policy

## Default Policy

Use toPSAil-native pressure-flow and boundary-condition handling wherever
practical.

The Yang four-bed work should orchestrate existing single-bed and paired-bed
behaviour through wrapper-level state selection, pair metadata, adapters, and
ledgers.

## Forbidden Architecture Drift

Do not introduce any of the following for Yang internal transfers unless a later
task explicitly authorises a separate extension:

- dynamic internal tanks;
- shared header inventory;
- a global four-bed RHS/DAE;
- rewritten adsorber physics;
- hidden external product credit for internal transfer gas.

## Direct-Coupling Policy

Internal transfers are direct bed-to-bed couplings:

- `EQI-BD` to `EQI-PR`;
- `EQII-BD` to `EQII-PR`;
- `PP` to `PU`;
- `AD&PP` to `BF`.

Pair identities must come from an explicit pair map. Do not infer partners from
source table row order, bed adjacency, or native two-bed defaults.

Native AD, BD, EQI, and EQII calls may be used where suitable. PP->PU and
AD&PP->BF require wrapper-level direct-coupling adapters for the final
implementation unless a later review proves an existing native route is exact
enough without architecture drift.

## Adapter Boundary Requirements

PP->PU:

- donor product end feeds receiver product end;
- receiver waste exits the feed end;
- internal transfer and external waste are separately integrated;
- pressure endpoints, valve coefficients, flow signs, and conservation residuals
  are reported.

AD&PP->BF:

- donor receives external feed;
- product-side donor gas splits into external product and internal BF stream;
- split is controlled by valve coefficients and reported as an effective split,
  not hard-coded as the primary final result;
- external product and internal BF transfer are separately integrated.

## Pressure Classes

Use symbolic pressure classes until numeric values are explicitly available and
authorised:

- `PF`
- `P1`
- `P2`
- `P3`
- `P4`
- `P5`
- `P6`

Do not invent intermediate pressure values to make a run proceed. For the final
surrogate, intermediate pressure classes are diagnostics unless a later
calibration policy introduces explicit targets.

## Required Diagnostics For Pressure-Changing Steps

For pressurisation, blowdown, pressure equalisation, provide-purge, and backfill
steps, report:

- initial pressure;
- final pressure;
- pressure trajectory or endpoint summary;
- inlet/outlet flow direction;
- donor and receiver role;
- global bed labels and local temporary bed indices;
- total gas inventory change;
- component inventory change;
- boundary molar flow integrals;
- external/internal ledger category;
- valve coefficients or pressure-control settings when applicable.
