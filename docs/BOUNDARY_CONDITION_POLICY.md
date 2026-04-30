# Boundary Condition Policy

## Default Policy

Use toPSAil-native pressure-flow and boundary-condition handling wherever practical.

The Yang four-bed work should orchestrate existing single-bed and paired-bed behaviour through wrapper-level state selection, pair metadata, and ledgers.

## Forbidden Architecture Drift

Do not introduce any of the following for Yang internal transfers unless a later task explicitly authorises a separate extension:

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

Pair identities must come from an explicit pair map. Do not infer partners from source table row order, bed adjacency, or native two-bed defaults.

## Pressure Classes

Use symbolic pressure classes until numeric values are explicitly available and authorised:

- `PF`
- `P1`
- `P2`
- `P3`
- `P4`
- `P5`
- `P6`

Do not invent intermediate pressure values to make a run proceed.

## Required Diagnostics For Pressure-Changing Steps

For pressurisation, blowdown, pressure equalisation, provide-purge, and backfill steps, report:

- initial pressure;
- final pressure;
- pressure trajectory;
- inlet/outlet flow direction;
- donor and receiver role;
- global bed labels and local temporary bed indices;
- total gas inventory change;
- component inventory change;
- boundary molar flow integrals;
- external/internal ledger category.
