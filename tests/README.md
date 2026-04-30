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
- WP1 static/source tests are under `tests/four_bed/`.
- `testYangManifestIntegrity.m` maps to `T-STATIC-01`.
- `testYangLayeredBedCapability.m` maps to `T-PARAM-01`.
- `testYangPairMapCompleteness.m` maps to `T-STATIC-02`.
- WP3 unit tests are under `tests/four_bed/`.
- `testYangFourBedStateContainerShape.m` maps to `T-STATE-01`.
- `testYangFourBedWritebackOnlyParticipants.m` maps to `T-STATE-02`.
- `testYangFourBedCrossedPairRoundTrip.m` maps to `T-STATE-03`.
- WP4 structural case-builder tests are under `tests/four_bed/`.
- WP5 ledger/CSS/reporting tests are under `tests/four_bed/`.
- `testYangFourBedLedgerSchema.m` maps to `T-DOC-01` and `LEDGER-01`.
- `testYangPairLocalConservation.m` maps to `T-CONS-01`.
- `testYangEqStageLedgerSeparation.m` maps to `T-PAIR-02`.
- `testYangAdppBfLedgerSplit.m` maps to `T-PAIR-04`.
- `testYangFullSlotLedgerBalance.m` maps to `T-CONS-02`.
- `testYangCssResidualsAllBeds.m` maps to `T-CSS-01`.
- `testYangMetricsExternalBasis.m` maps to `T-MET-01`.
- `testYangRunMetadataAssumptions.m` maps to `T-DOC-01`.
