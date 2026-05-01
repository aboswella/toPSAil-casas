# Scripts

This folder is reserved for project-specific MATLAB entry points and convenience
runners.

Default runners must stay small and discriminating:

- Tier 0 smoke confirms unchanged toPSAil examples still run.
- Static/source tests cover Yang manifest, normalized duration, labels,
  pressure-class metadata, architecture flags, and no-tank guards.
- Parameter tests cover the H2/CO2 activated-carbon surrogate package.
- Unit and sanity runners cover pair maps, physical-state persistence, temporary
  cases, adapters, conservation, ledgers, pressure diagnostics, and flow
  direction only after the relevant final batch exists.

Pilot validation, long numerical sensitivity, optimization, event policy,
tank/header variants, and generalized-PFD extensions must not be hidden inside
the default smoke runner.

## Current Four-Bed Context

Active implementation scope is FI-1 through FI-8, routed through
`docs/four_bed/FINAL_IMPLEMENTATION_CONTEXT.md`.

The older WP1-WP5 labels in function comments, error IDs, versions, or runner
names are legacy traceability. Do not use them to define new active scope.

Status:

- existing schedule, pair-map, state, case-builder, ledger, CSS, and metadata
  helpers live under `scripts/four_bed/`;
- Batch 1 helpers include normalized slot durations and physical-state/counter
  separation;
- Batch 2 helpers live under `params/yang_h2co2_ac_surrogate/` rather than
  `scripts/four_bed/`;
- future Batch 3-5 implementation should add adapter, cycle-driver, ledger, and
  audit helpers under `scripts/four_bed/` unless an active guide says otherwise.

Known runners:

- `run_source_tests.m` runs lightweight source/static checks.
- `run_case_builder_tests.m` runs lightweight structural case-builder checks.
- `run_ledger_tests.m` runs synthetic ledger, conservation, metric, CSS, and
  metadata checks.
- `run_sanity_tests.m` runs lightweight final-batch sanity checks.
