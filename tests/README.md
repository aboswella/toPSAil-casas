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

Source runner:
- `scripts/run_source_tests.m`: Tier 1; runs source/parameter transcription checks; runtime class is seconds; not included in default smoke.

Equation runner:
- `scripts/run_equation_tests.m`: Tier 2; runs isolated equation-local checks; runtime class is seconds; not included in default smoke.

Sanity runner:
- `scripts/run_sanity_tests.m`: Tier 3; runs one-step or inspectable case-scaffold checks; runtime class is seconds; not included in default smoke.

Tier 1 tests:
- `tests/test_schell_source_pack.m`: Tier 1; catches Schell source-pack or validation-target drift, text-encoded numeric constants, flow-conversion unit mistakes, missing unresolved-assumption guardrails, and accidental YAML source-of-truth duplication; runtime class is seconds; not included in default smoke.

Tier 2 tests:
- `tests/test_schell_sips_reference.m`: Tier 2; catches Schell Sips equation mistakes, Pa/bar unit errors, component cross-talk in pure-gas anchors, incorrect temperature or pressure trends, and optional core isotherm dispatch drift; runtime class is seconds; not included in default smoke.

Tier 3 tests:
- `tests/test_schell_case_scaffold.m`: Tier 3; catches Schell route-B scaffold drift before a health run by requiring traceable source-pack mapping, optional core Sips selector readiness, and explicit run-readiness blocking; runtime class is seconds; not included in default smoke.

Fixtures:
- `fixtures/schell_2013_sips_anchor_cases.json` contains independent numerical anchors for Tier 2 Schell Sips equation tests.

Status:
- Tier 0 smoke runner added.
- Tier 1 Schell source-pack tests added.
- Tier 2 Schell Sips equation-local tests added.
- Tier 3 Schell case-scaffold sanity tests added.
- No validation, sensitivity, or optimisation tests have been added.
