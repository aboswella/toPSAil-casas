# Validation

This folder separates validation intent from validation outputs.

- `manifests/` records targets, checks, and interpretation rules before validation runs are judged.
- `targets/` stores small machine-readable source-derived validation target tables.
- `reports/` is reserved for generated validation reports.

For active Yang four-bed work, validation targets the H2/CO2 homogeneous
activated-carbon surrogate described in
`docs/four_bed/FINAL_IMPLEMENTATION_CONTEXT.md`. The old WP1-WP5 workflow files
are legacy context and should not define new validation scope.

Do not change validation thresholds in the same task as physics, numerics, metrics, plotting, or parameter transcription.
