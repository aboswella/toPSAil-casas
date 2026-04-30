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
- scaffold only; no MATLAB scripts have been added in this documentation pass.
