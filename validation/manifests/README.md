# Validation Manifests

Manifests define validation intent before validation runs are interpreted.

Each manifest should state:

- case or work-package name;
- source basis;
- model mode;
- manifest and pair-map version, when applicable;
- parameter pack;
- hard checks;
- soft comparison targets;
- tolerances or qualitative expectations;
- required report fields;
- whether the case is included in default smoke.

For Yang four-bed work, manifests must also state:

- direct-coupling assumption;
- no dynamic internal tank/header assumption;
- event policy;
- layered-bed support status;
- external/internal ledger basis;
- all-bed CSS basis.

Do not change validation targets or thresholds in the same task as physics, numerics, metrics, or parameter changes.

Machine-readable source target tables should live under `validation/targets/` and be referenced from manifests rather than duplicated by hand.
