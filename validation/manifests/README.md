# Validation Manifests

Manifests define validation intent before validation runs are interpreted.

Each manifest should state:

- case name;
- source basis;
- model mode;
- parameter pack;
- hard checks;
- soft comparison targets;
- tolerances or qualitative expectations;
- required report fields;
- whether the case is included in default smoke.

Do not change validation targets or thresholds in the same task as physics, numerics, or parameter changes.
