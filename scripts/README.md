# Scripts

This folder is reserved for project-specific MATLAB entry points and convenience runners.

Expected future runners:

- `run_smoke.m`
- `run_source_tests.m`
- `run_equation_tests.m`
- `run_sanity_tests.m`

Tier 4 validation and Tier 5 sensitivity/optimisation must not be part of the default smoke runner.

Status:
- `run_smoke.m` is a Tier 0 runner for the unchanged toPSAil `case_study_1.0` baseline example.
