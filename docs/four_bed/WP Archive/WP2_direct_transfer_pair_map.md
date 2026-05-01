# WP2 Direct-Transfer Pair Map

## Purpose

WP2 adds explicit Yang direct-transfer pair identities on top of the WP1
schedule manifest. It is a static metadata layer for later wrapper work. It
does not invoke the solver, create persistent bed states, create tanks or
headers, add event logic, or reconstruct ledgers.

## Pair Map

The map consumes `manifest.bedSteps` rows where `requires_pair_map == true`.
Pair identities are explicit and are not inferred from source table row order,
bed adjacency, or native two-bed defaults.

| Family | Donor -> receiver pairs |
|---|---|
| `ADPP_BF` | A->B, B->C, C->D, D->A |
| `EQI` | A->C, B->D, C->A, D->B |
| `EQII` | A->D, B->A, C->B, D->C |
| `PP_PU` | A->D, B->A, C->B, D->C |

`PP_PU` follows the workflow decision `PP -> PU`. The Yang prose
cross-reference ambiguity remains recorded in `docs/KNOWN_UNCERTAINTIES.md`.

## Schema

`getYangDirectTransferPairMap.m` returns a versioned `pairMap` struct with:

- `pairingPolicy`, `holdupPolicy`, `eventPolicy`, source notes, architecture
  flags, and the consumed WP1 manifest version.
- `endpointMetadata` for donor outlet, receiver inlet, receiver waste endpoint,
  and internal accounting category by transfer family.
- `transferPairs`, a 16-row table with donor and receiver bed, record id,
  source column, Yang label, role class, pressure classes, internal transfer
  category, endpoint metadata, and source-basis notes.

Some donor and receiver source columns differ because WP1 preserves the
displayed Yang schedule spans. WP2 stores those columns as traceability
metadata but uses the explicit cyclic pair identities for partner selection.

## Validation

- `T-STATIC-02`: `tests/four_bed/testYangPairMapCompleteness.m`

Run:

```matlab
addpath(genpath(pwd));
run("scripts/run_source_tests.m");
```

The validator checks that every direct-transfer manifest row appears exactly
once as donor or receiver, that labels and roles match the transfer family,
that `EQI` and `EQII` remain distinct, that `AD&PP` remains compound, and
that endpoint metadata exists for the later WP4/WP5 tests.

## Handoff

WP3 should use the named bed labels without changing pair identities. WP4
should use `transferPairs` to select temporary paired-bed local states. WP5
should use `transferAccountingCategory` and endpoint metadata to separate
internal transfers from external product and waste.
