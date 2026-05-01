# Validation Manifests

Manifests define validation intent before validation runs are interpreted.

Each manifest should state:

- case name and final implementation item or batch;
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

- H2/CO2 renormalization basis;
- homogeneous activated-carbon surrogate status;
- direct-coupling assumption;
- no dynamic internal tank/header assumption;
- event policy;
- external/internal ledger basis;
- all-bed CSS basis.

Legacy WP labels may be included only for traceability. They do not define active
validation scope.

Do not change validation targets or thresholds in the same task as physics, numerics, metrics, or parameter changes.

Machine-readable source target tables should live under `validation/targets/` and be referenced from manifests rather than duplicated by hand.
