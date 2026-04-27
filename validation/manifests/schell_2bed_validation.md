# Schell Two-Bed Validation Manifest

## Status

Ready for staged implementation after `SCHELL-PRE`, `SCHELL-00`, and `SCHELL-00B` pass or produce an accepted baseline-status report.

## Case

- `cases/schell_2bed_validation/`

## Source Basis

- `docs/source_reference/02_schell_2013_two_bed_psa_validation.md`
- `docs/workflow/schell_2013_implementation/source_extraction_audit.md`
- `validation/targets/schell_2013_validation_targets.csv`

## Parameter pack

- Canonical JSON: `params/schell2013_ap360_sips_binary/schell_2013_source_pack.json`
- Schema: `params/schell2013_ap360_sips_binary/schell_2013_source_pack.schema.json`
- Sips anchors: `params/schell2013_ap360_sips_binary/schell_2013_sips_anchor_cases.json`

JSON is canonical. Do not maintain a hand-edited YAML duplicate.

## Model mode

- Default: `topsail_native` pressure-flow, boundary-condition, cycle, equalisation, and auxiliary-unit handling.
- Optional future mode: `schell_reproduction`, only after a separate authorised task.
- Detector/piping model: `diagnostic_only`, not part of default validation.

## Hard checks

A run is invalid if any hard check fails:

- MATLAB completes without exception.
- No NaN or Inf in exported states or summary metrics.
- Positive absolute pressure.
- Positive absolute temperature.
- Mole fractions finite and within numerical tolerance of `[0, 1]`.
- Component inventories finite.
- CSS convergence metric reported.
- Source pack hash recorded.
- Model mode recorded.
- Raw output locations recorded.

## Tier 1 source checks

Required before any simulation:

- source pack JSON parses;
- required schema fields exist;
- numeric source values are numeric, not strings;
- Table 1 geometry and bed values match Schell source reference;
- Table 2 timings and performance targets match `validation/targets/schell_2013_validation_targets.csv`;
- SI Table 3 Sips parameters match source pack;
- `flow_rate_conversion_basis` exists and includes the factor-of-pressure warning;
- `unresolved_assumptions` includes `FLOW_BASIS`, `P_PEQ`, `CASE_INPUT_ROUTE`, `SIPS_CORE_REGISTRATION`, and `TEMPERATURE_DIGITIZATION`.

## Tier 2 equation checks

Required before any Sips core registration:

- independent Sips anchor cases pass;
- pure-component cases return zero loading for absent component;
- binary loading is finite and positive for both components;
- pressure monotonicity holds for pure CO2 over the tested range;
- temperature-dependence anchor passes.

## Soft validation targets

Use `validation/targets/schell_2013_validation_targets.csv`.

For performance metrics:

- `in_band`: absolute error within published `+/-` uncertainty;
- `near_band`: absolute error within two times published uncertainty;
- `out_of_band`: outside two times published uncertainty;
- `blocked`: extractor or run did not produce the metric.

These classifications are report-only during initial integration. A mismatch must produce a report; it must not trigger parameter tuning in the same task.

## Central first case

First full validation target:

```text
case_id = schell_20bar_tads40_performance_central
p_high = 20 bar
t_press = 24 s
t_ads = 40 s
t_peq = 3 s
t_blow = 50 s
t_purge = 15 s
H2 purity = 93.4 +/- 1.5 %
H2 recovery = 74.4 +/- 5.7 %
CO2 purity = 78.7 +/- 4.7 %
CO2 recovery = 94.8 +/- 5.7 %
```

## Temperature profile posture

Thermocouple positions are 0.10, 0.35, 0.60, 0.85, and 1.10 m from bottom. Temperature profile comparison is the preferred validation signal because the paper warns that concentration traces are distorted by piping and detector-volume effects.

Initial profile validation is qualitative/report-only unless digitized curve targets are added by a separate task.

## Default smoke inclusion

Not included in default smoke. Tier 4 validation runs are not default smoke tests.
