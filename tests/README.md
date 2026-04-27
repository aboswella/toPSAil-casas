# Tests

This folder is reserved for small project-specific tests.

Test tiers:

- Tier 0: unchanged toPSAil baseline examples.
- Tier 1: source/parameter transcription.
- Tier 2: equation-local checks.
- Tier 3: one-step physical sanity checks.
- Tier 4: validation cases.
- Tier 5: sensitivity/optimisation.

Every new test must state the named failure mode it catches.

Fixtures:
- `fixtures/schell_2013_sips_anchor_cases.json` contains independent numerical anchors for future Tier 2 Schell Sips equation tests.

Status:
- no executable MATLAB tests have been added in this integration pass.
