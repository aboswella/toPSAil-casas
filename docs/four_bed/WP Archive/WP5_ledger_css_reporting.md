# WP5 Ledger, CSS, and Reporting Layer

## Purpose

WP5 adds wrapper-level accounting and reporting for the Yang four-bed path.
It does not modify toPSAil core physics, add dynamic internal tanks, create a
shared header inventory, assemble a global four-bed RHS/DAE, or add event
scheduling.

## Ledger Schema

The ledger is created by `makeYangFourBedLedger(componentNames, ...)`.
Its `streamRows` table is component-long: one row per component per stream
event.

Required identity columns include:

- `cycle_index`
- `slot_index`
- `operation_group_id`
- `record_id`
- `pair_id`
- `stage_label`
- `direct_transfer_family`
- `yang_label`
- `global_bed`
- `local_index`
- `local_role`
- `component`

Allowed stream scopes are:

- `external_feed`
- `external_product`
- `external_waste`
- `internal_transfer`
- `bed_inventory_delta`

Internal direct transfers are ledger diagnostics and conservation aids. They
are not external product.

## Balance Equations

External slot and cycle balances use, by component:

```text
external_feed - external_product - external_waste - bed_inventory_delta = residual
```

where:

```text
bed_inventory_delta = terminal_bed_inventory - initial_bed_inventory
```

Internal transfer cancellation uses:

```text
internal_transfer_into_receiver - internal_transfer_out_of_donor = residual
```

`computeYangLedgerBalances` reports residual rows by component so a failure can
be traced to a slot, operation group, direct-transfer family, and component.

## Metric Basis

`computeYangPerformanceMetrics` reconstructs Yang-basis hydrogen product
metrics from external ledger rows:

```text
product purity = target-component external_product moles / total external_product moles
product recovery = target-component external_product moles / target-component external_feed moles
```

Rows with `stream_scope == "internal_transfer"` are excluded from both
numerators and denominators. Native toPSAil metrics remain diagnostic and are
not automatically the Yang external-product basis.

## CSS Basis

`computeYangFourBedCssResiduals` compares persistent named bed states:

- `state_A`
- `state_B`
- `state_C`
- `state_D`

It does not accept a temporary local pair as a full four-bed CSS check. When a
toPSAil state layout is supplied through `Params`, CSS rows are split into:

- `gas_concentration`
- `adsorbed_loading`
- `gas_temperature`
- `wall_temperature`

Trailing cumulative boundary-flow counters are excluded from CSS residuals
when the column layout is known.

## Metadata

`makeYangFourBedRunMetadata` and `validateYangFourBedRunMetadata` require each
output artifact to state:

- manifest version;
- pair-map version;
- no dynamic internal tanks;
- no shared header inventory;
- no global four-bed RHS/DAE;
- no core adsorber-physics rewrite;
- fixed-duration event policy;
- zero-holdup direct internal transfer policy;
- internal transfers excluded from external product/recovery;
- native metrics are diagnostic, not Yang-basis;
- layered-bed and thermal caveats;
- no Yang validation claim before mismatch and numerical commissioning are
  complete.

## Tests

Run the WP5 suite with:

```matlab
addpath(genpath(pwd));
run("scripts/run_ledger_tests.m");
```

The default sanity runner also includes these fast synthetic tests:

```matlab
run("scripts/run_sanity_tests.m");
```

The WP5 tests use deterministic synthetic stream and state packets. They do
not run a full Yang numerical pilot, optimization, sensitivity study, or event
policy.

## Current Limitation

WP5 commissions the ledger, CSS, and reporting basis. It does not claim Yang
performance validation. Native cumulative-flow extraction can be added later
once a safe initialized template is available and the extractor is tested.
