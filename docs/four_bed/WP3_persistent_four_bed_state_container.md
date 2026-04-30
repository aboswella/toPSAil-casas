# WP3 Persistent Four-Bed State Container

## Purpose

WP3 implements the wrapper-level persistent state container for the Yang
four-bed workflow. It stores opaque terminal-state payloads for named beds
`A`, `B`, `C`, and `D`, selects participating states for later temporary
toPSAil-compatible calls, and writes returned terminal states back to the
correct named beds.

WP3 is a state-management layer only. It does not build temporary cases, call
the solver, create dynamic internal tanks, create shared header inventory,
assemble a global four-bed RHS/DAE, compute ledgers, compute CSS, or claim
Yang validation.

## Container Schema

`makeYangFourBedStateContainer(initialStates, ...)` returns a plain MATLAB
struct with:

- `state_A`, `state_B`, `state_C`, and `state_D` as top-level persistent
  payload fields.
- `bedLabels = ["A", "B", "C", "D"]`.
- `stateFields = ["state_A", "state_B", "state_C", "state_D"]`.
- `manifestVersion` and `pairMapVersion` metadata when WP1/WP2 artifacts are
  supplied.
- architecture flags stating no dynamic internal tanks, no shared header
  inventory, no four-bed RHS/DAE, no core adsorber-physics rewrite, no WP3
  case building, no WP3 solver invocation, and no WP3 ledger or metric logic.
- `stateMetadata`, one row per named bed.
- `writebackLog`, a metadata-only table for state replacement events.

The bed payloads are opaque. WP3 stores, selects, and replaces payloads, but
does not inspect fields such as composition, loading, temperature, pressure,
or any toPSAil-specific state layout.

## Pair Selection Contract

`selectYangFourBedPairStates(container, pairRow)` consumes one row from
`pairMap.transferPairs`.

The local order is deterministic:

- local index 1 is the WP2 donor bed.
- local index 2 is the WP2 receiver bed.

The selector uses `pairRow.donor_bed` and `pairRow.receiver_bed`. It does not
sort bed labels, infer adjacency, infer row order, or rely on native two-bed
defaults. The returned `selection.localMap` carries both local indices and
global bed labels so later WP4 calls can return terminal states in the same
local order.

## Single-Bed Selection Contract

`selectYangFourBedSingleState(container, bedStepRow)` consumes one row from
`manifest.bedSteps`.

The local order is:

- local index 1 is the selected `bedStepRow.bed`.

The returned `selection.localMap` uses the same column shape as pair
selection. WP4 can therefore consume one selection contract for both future
single-bed and paired-bed temporary cases.

## Writeback Contract

`writeBackYangFourBedStates(container, selection, terminalLocalStates, ...)`
replaces only the participating state fields listed in
`selection.localMap.state_field`.

The terminal states must be supplied in local selection order. For example,
if `selection.localMap` maps local 1 to `state_B` and local 2 to `state_D`,
then terminal local state 1 replaces `state_B` and terminal local state 2
replaces `state_D`. Non-participating named bed states are not reconstructed
or reset.

Writeback updates `stateMetadata.writeback_count` for participating beds and
appends metadata rows to `writebackLog`. The log does not store full state
payloads.

## Initialization Policy

WP3 requires the caller to supply all four initial state payloads explicitly.
The container records `initializationPolicy`, such as
`explicit_four_bed_payloads_supplied_by_caller` or
`unit_test_distinguishable_sentinel_states`.

WP3 does not claim physical Yang phase-offset initialization. A later task
must implement and validate any manifest-driven phase-offset initializer
before multi-cycle Yang startup states can be interpreted physically.

## Validation Tests

- `T-STATE-01` -> `tests/four_bed/testYangFourBedStateContainerShape.m`
- `T-STATE-02` -> `tests/four_bed/testYangFourBedWritebackOnlyParticipants.m`
- `T-STATE-03` -> `tests/four_bed/testYangFourBedCrossedPairRoundTrip.m`

Run:

```matlab
addpath(genpath(pwd));
run("scripts/run_source_tests.m");
run("scripts/run_sanity_tests.m");
```

## Handoff To WP4

WP4 should consume `selection.localStates` and `selection.localMap` to build
temporary toPSAil-compatible single-bed or paired-bed cases. WP4 should
return terminal local states in the same local order, and must preserve the
global bed identity metadata for writeback.

WP4 owns case construction, native step translation, boundary/end setup, and
solver invocation. WP3 does not perform those actions.

## Handoff To WP5

WP5 can later use selection metadata and writeback logs for ledger
attribution. WP3 does not compute external/internal ledgers, product metrics,
recovery, purity, CSS residuals, or validation numbers.
