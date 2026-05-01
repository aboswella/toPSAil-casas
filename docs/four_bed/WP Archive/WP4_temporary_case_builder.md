# WP4 Temporary Case Builder

## Purpose

WP4 proves that selected named Yang bed states can be wrapped into isolated
local single-bed or paired-bed case specifications. It does not prove Yang
performance, CSS convergence, ledger correctness, or physical fidelity to
layered activated-carbon/zeolite beds.

The adapter consumes WP3 selections and preserves the local order contract:

- paired direct transfer: local 1 is the WP2 donor, local 2 is the receiver;
- single-bed operation: local 1 is the selected bed;
- returned terminal states must be passed to WP3 writeback in the same local
  order.

## Temporary Case Schema

`makeYangTemporaryCase`, `makeYangTemporaryPairedCase`, and
`makeYangTemporarySingleCase` create a struct with:

- `localMap` and `localStates` containing only selected local beds;
- `yang` metadata for source labels, record IDs, source columns, pressure
  classes, and endpoints;
- `native` translation metadata, including native step names only where a
  native toPSAil representation is explicit;
- `execution` duration metadata supplied by the caller, never inferred from
  donor or receiver source columns;
- `architecture` guardrails confirming no dynamic Yang internal tanks, no
  shared header inventory, no four-bed RHS/DAE, and no core physics rewrite.

The temporary case may store global bed labels as metadata. It must not store
`state_A`, `state_B`, `state_C`, or `state_D` payload fields.

## Translation Table

| Yang operation | WP4 status | Native step metadata |
|---|---|---|
| `EQI-BD -> EQI-PR` | native-runnable when a safe template is supplied | `EQ-XXX-APR`, stage `EQI`, `numAdsEqPrEnd = [2; 1]` |
| `EQII-BD -> EQII-PR` | native-runnable when a safe template is supplied | `EQ-XXX-APR`, stage `EQII`, `numAdsEqPrEnd = [2; 1]` |
| `AD` | native-runnable when a safe template is supplied | `HP-FEE-RAF` |
| `BD` | native-runnable when a safe template is supplied | `DP-ATM-XXX` |
| `PP -> PU` | wrapper-only/not native-runnable yet | product end to product end, receiver waste at feed end |
| `AD&PP -> BF` | wrapper-only/not native-runnable yet | product-side internal backfill separated from external product |

Raw Yang labels are never emitted as native step names. Direct-transfer roles
selected as single-bed operations are marked as requiring the explicit WP2 pair
selection.

## Runner Modes

`runYangTemporaryCase` supports:

- `dry_run`: returns local states unchanged and invokes no solver;
- `spy`: calls a supplied function once and verifies local-order return shape;
- `native`: requires a native-runnable translation, initialized template
  params, native adsorber-state payloads, and an explicit duration.

Native execution is not included in the default WP4 smoke suite. A lightweight
EQI/EQII native smoke remains deferred until a safe programmatic initialized
two-bed template params struct is available without editing `3_source/` or
depending on Excel/GUI paths.

## Guards And Tests

`validateYangTemporaryCase` checks schema, local/global mapping, native
translation status, architecture flags, and raw-label leakage into native step
fields.

`assertNoYangInternalTankInventory` checks that temporary cases do not create
Yang internal tank/header inventory, persistent named state fields, or four-bed
RHS/DAE fields.

Run:

```matlab
addpath(genpath(pwd));
run("scripts/run_case_builder_tests.m");
```

The WP4 runner is also included in:

```matlab
run("scripts/run_sanity_tests.m");
```

Current structural coverage maps to `T-CASE-01`, `T-CASE-02`, `T-STATIC-03`,
the WP4 metadata portions of `T-PAIR-01`, `T-PAIR-02`, `T-PAIR-03`,
`T-STATE-02`, and `T-STATE-03`.

## Validation Position

WP4 is an adapter and contract test layer. It does not create ledgers, compute
CSS, reconstruct Yang purity/recovery, assign numeric intermediate pressure
classes, add event scheduling, or claim Yang validation.
