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

Smoke runner:
- `scripts/run_smoke.m`: Tier 0; catches failure of the unchanged toPSAil `case_study_1.0` example to initialize/run or emit finite final values in key CSV outputs; runtime class is several minutes on local MATLAB; included in default smoke.

Fixtures:
- `fixtures/schell_2013_sips_anchor_cases.json` contains independent numerical anchors for future Tier 2 Schell Sips equation tests.

Status:
- Tier 0 smoke runner added; no source, equation, sanity, validation, sensitivity, or optimisation tests have been added.
