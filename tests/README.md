# Tests

This folder is reserved for small project-specific tests.

## Active Test Context

The active implementation scope is FI-1 through FI-8, routed through
`docs/four_bed/FINAL_IMPLEMENTATION_CONTEXT.md`.

Legacy WP1-WP5 labels and old `T-*` IDs may remain in test names or comments for
traceability. They do not define new active work.

## Test Tiers

- Tier 0: unchanged toPSAil baseline examples.
- Static/source: Yang manifest, normalized duration, labels, pressure classes,
  architecture flags, and no-tank checks.
- Parameter: H2/CO2 feed renormalization, activated-carbon-only basis, and DSL
  mapping smoke checks.
- Unit: pair mapping, direct-transfer role, physical-state persistence, temporary
  case-builder, and adapter checks.
- Sanity/integration: conservation, external/internal ledgers, pressure
  diagnostics, flow direction, and one-slot checks.
- Pilot validation: normalized Yang H2/CO2 AC surrogate cycle, all-bed CSS, and
  external-basis H2 metrics after earlier gates pass.
- Later extensions: broad sensitivity, optimization, event control, tank/header
  variants, or generalized PFD work.

Every new test must state the final implementation item or batch it protects and
the named failure mode it catches. Keep legacy test-matrix IDs only when they
still provide useful traceability.

## Current Status

- Static/source tests are under `tests/four_bed/`.
- State, case-builder, ledger, CSS, and metadata tests are under
  `tests/four_bed/`.
- FI-1/FI-3 tests include normalized slot durations and physical-state
  persistence cleanup.
- FI-2 tests include the H2/CO2 activated-carbon parameter pack and AC DSL
  mapping smoke checks.
- Future FI-4/FI-5 tests should cover PP->PU and AD&PP->BF adapter conservation,
  endpoints, pressure diagnostics, and ledger separation.
- Future FI-6/FI-7/FI-8 tests should cover one-cycle execution, wrapper-ledger
  metrics, CSS smoke, and valve-coefficient sensitivity sanity checks.
