# Scripts

This folder is reserved for project-specific MATLAB entry points and convenience runners.

Expected future runners:

- `run_smoke.m`
- `run_source_tests.m`
- `run_equation_tests.m`
- `run_sanity_tests.m`

Default runners must stay small and discriminating:

- Tier 0 smoke confirms unchanged toPSAil examples still run.
- Static/source tests cover Yang manifest, duration, label, pressure-class, architecture-flag, and layered-bed audit checks.
- Unit and sanity runners cover pair maps, persistent state, case builders, conservation, ledgers, and flow direction only after the relevant work package exists.

Pilot validation, long numerical sensitivity, optimization, event policy, tank/header variants, and generalized-PFD extensions must not be hidden inside the default smoke runner.

Status:
- WP1 source/static helpers are under `scripts/four_bed/`.
- WP2 direct-transfer pair-map helpers are under `scripts/four_bed/`.
- WP3 persistent state-container helpers are under `scripts/four_bed/`.
- WP4 temporary case-builder helpers are under `scripts/four_bed/`.
- WP5 ledger, CSS, metric, and run-metadata helpers are under `scripts/four_bed/`.
- `run_source_tests.m` runs the lightweight Yang manifest, layered-bed audit, and pair-map completeness checks.
- `run_case_builder_tests.m` runs the lightweight WP4 structural case-builder checks.
- `run_ledger_tests.m` runs synthetic WP5 ledger, conservation, metric, CSS, and metadata checks.
- `run_sanity_tests.m` runs the lightweight WP3, WP4, and WP5 sanity checks.
