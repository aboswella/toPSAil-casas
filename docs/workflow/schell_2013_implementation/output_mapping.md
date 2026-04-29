# Schell 2013 Output Mapping

Task: `SCHELL-09`

## Scope

This note maps the bounded central run outputs to the summary fields emitted
by `scripts/extract_schell_summary.m`.

The summary is a run/extraction artifact, not a soft-validation report. It
does not tune parameters, change thresholds, or classify agreement with the
published Schell Table 2 targets.

## Summary paths

Central bounded run:

```text
validation/reports/schell_2013/central/summary.json
validation/reports/schell_2013/central/raw.mat
```

Health run:

```text
validation/reports/schell_2013/health/schell_20bar_tads40_performance_central_summary.json
validation/reports/schell_2013/health/schell_20bar_tads40_performance_central_raw.mat
```

## Field mapping

| Summary field | Source |
|---|---|
| `case_id` | `build_schell_params_from_source_pack` scaffold. |
| `model_mode` | Scaffold value; default remains `topsail_native`. |
| `source_pack_sha256` | SHA256 recorded by the scaffold builder. |
| `run.cycles_requested` | `fullParams.nCycles`, equal to the accepted cycle cap for SCHELL-09. |
| `run.cycles_completed` | `floor(sol.lastStep / fullParams.nSteps)`. |
| `run.css_residual` | `sol.css(cycles_completed + 1)` when available. |
| `run.css_reached` | `run.css_residual < fullParams.numZero`. |
| `run.stop_reason` | `css_reached`, `cycle_cap_reached_without_css`, or `stopped_before_cycle_cap`. |
| `hard_checks` | Extracted from finite-state, pressure, temperature, mole-fraction, cycle-completion, and CSS-report checks. |
| `performance` | Direct toPSAil native raffinate/extract metrics from the last completed cycle. |
| `temperature_profiles` | Nearest-cell samples at Schell thermocouple positions from the final simulated step. |
| `pressure_profiles` | Min/max pressure health values plus final-step and native equalization endpoint summaries. |
| `stream_accounting` | Last-cycle feed, product, waste, and feed-minus-outlet stream totals. |
| `warnings` | Carried project uncertainties and SCHELL-09 run-limit notes. |

## Accounting notes

The `performance` fields use direct toPSAil native product-stream metrics.
They are not yet converted to the Schell SI subtraction basis. The
SCHELL-10 soft-validation report must state which accounting basis is used
before comparing H2/CO2 purity and recovery to Table 2.

The `stream_accounting.feed_minus_outlet_stream_moles` field is a stream-only
residual. It does not include bed or tank inventory change, so it should not
be read as a full component-conservation residual before CSS.

## Known limitations carried forward

- `FLOW_BASIS` remains open.
- `P_PEQ` remains open; native equalization is used without prescribed
  intermediate pressure.
- Thermal validation is deferred; the bounded central run is explicitly
  isothermal.
- The native purge connection remains an approximation recorded in warnings.
- The optional Schell Sips route may amplify runtime/stiffness.
