# Validation

This folder separates validation intent from validation outputs.

- `manifests/` records targets, checks, and interpretation rules before validation runs are judged.
- `targets/` stores small machine-readable source-derived validation target tables.
- `reports/` is reserved for generated validation reports.

Do not change validation thresholds in the same task as physics, numerics, metrics, plotting, or parameter transcription.
