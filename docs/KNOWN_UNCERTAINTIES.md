# Known Uncertainties

This register records unresolved source, modelling, and workflow uncertainties.
Do not silently resolve these by choosing convenient values.

## Source Availability

- The local Yang PDF is present as `sources/Yang 2009 4-bed 10-step relevant.pdf`.

## Project-Control Status

- The old WP1-WP5 documents and `docs/workflow/` CSV files are legacy context.
  They may still contain useful architecture rationale and test IDs, but active
  implementation scope comes from `docs/four_bed/FINAL_IMPLEMENTATION_CONTEXT.md`
  and current batch guides.
- Legacy names such as `WP1`, `WP3`, or `WP5` may remain in function comments,
  error IDs, version strings, and historical tests. Those labels should not be
  used to define new active work.

## Yang Schedule And Manifest

- The displayed duration units in the legacy WP1 guidance sum to 25 units of
  `t_c/24`. Final implementation preserves raw duration labels as metadata and
  uses normalized executable fractions `[1,6,1,4,1,1,4,1,1,5]/25`.
- `AD&PP` combines external adsorption/product behaviour with internal
  backfill-donor behaviour. It must remain compound in metadata, adapter logic,
  and ledgers.
- `EQI` and `EQII` must remain distinct metadata and ledger families even if
  native machinery uses a generic paired-bed operation.
- Manual legacy WP1 source checking found a purge-label cross-reference ambiguity
  in the Yang PDF text: step (d) says PP effluent purges step (g), the
  boundary-condition notation uses `yi,PP` for `PG`, and the workflow maps
  `PP -> PU`, but the step (g) prose text extraction appears to say purge gas is
  obtained from a bed undergoing step (c). The project preserves the `PP_PU`
  transfer family unless a later source review changes it explicitly.

## Pairing And State

- Direct-transfer pair identities must be explicit. Do not infer them from row
  order, bed adjacency, or native two-bed assumptions.
- Initial phase offsets for the four persistent beds must be documented before
  any multi-cycle pilot can be interpreted.
- Persistent states must contain physical adsorber state only. Cumulative
  boundary-flow counters are accounting data and must not be written back as bed
  physical state.

## Physical Model

- Active final implementation is a binary H2/CO2 homogeneous activated-carbon
  surrogate. It is not a full Yang H2/CO2/CO/CH4 layered activated-carbon plus
  zeolite 5A reproduction.
- Using activated carbon over the full Yang vessel is a deliberate default
  surrogate basis. A shortened activated-carbon-layer-only bed would be a
  separate sensitivity case, not the default.
- Yang uses layered activated carbon and zeolite 5A beds. Layered-bed capability
  remains a later-extension question, not a blocker for the active surrogate.
- Intermediate pressure classes `P1`, `P2`, `P3`, `P5`, and `P6` are symbolic
  unless a task provides explicit numeric source support or calibration policy.
- Thermal mode and wall/ambient assumptions must be stated before comparing
  temperature behaviour.
- Any mismatch between Yang model assumptions and toPSAil assumptions must be
  reported as a model limitation rather than patched by tuning constants.

## Parameter And Isotherm Basis

- The binary feed basis renormalizes Yang H2 and CO2 only:
  `y_H2 = 0.7697228145`, `y_CO2 = 0.2302771855`.
- Native dual-site Langmuir-Freundlich machinery exists, but exact Yang
  site-specific temperature dependence may not map perfectly to native toPSAil
  parameters. Batch 2 point tests must justify the native mapping before
  non-isothermal claims.
- Valve coefficients for equalization, purge, backfill, product, waste, cycle
  time, and feed velocity are design or sensitivity variables. Do not treat
  missing Yang valve coefficients as source constants.

## Ledgers And Metrics

- Internal direct-transfer streams must not be counted as external product.
- Yang-basis H2 purity, recovery, productivity, and CSS metrics require wrapper
  ledgers and all-bed physical-state residuals.
- Native toPSAil metrics may be useful diagnostics but are not automatically the
  final external-product basis.
- Adapter audit output should be compact by default; full state dumps should be
  optional debug artifacts.

## Tooling

- `rg` is available and working on this machine. Use `rg` and `rg --files` as
  the first-choice search commands.
- Confirm whether Codex reads `.codex/config.toml` using `/status` before relying
  on profile settings.
