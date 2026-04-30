# Tests

This folder is reserved for small project-specific tests.

Test tiers:

- Tier 0: unchanged toPSAil baseline examples.
- Static/source: Yang manifest, duration, label, pressure-class, architecture-flag, and layered-bed audit checks.
- Unit: pair mapping, direct-transfer role, persistent state, and temporary case-builder checks.
- Sanity/integration: conservation, external/internal ledgers, flow direction, and one-slot checks.
- Pilot validation: fixed-duration Yang skeleton, all-bed CSS, and Yang-basis metrics after earlier gates pass.
- Later extensions: sensitivity, optimization, event control, tank/header variants, or generalized PFD work.

Every new test must map to `docs/workflow/four_bed_test_matrix.csv` and state the named failure mode it catches.

Status:
- scaffold only; no tests have been added in this documentation pass.
