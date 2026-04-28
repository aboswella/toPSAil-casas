# Schell Case-Input Strategy Decision

Task: `SCHELL-05`

## Decision

Chosen route: `B`

- A: wrapper around `runPsaProcessSimulation` or an existing native example/params output
- B: JSON-to-params MATLAB builder that calls `runPsaCycle(params)`
- C: JSON-to-Excel generator
- D: native Excel case under `4_example`
- blocked: missing prerequisite prevents decision

Recommendation: use a project-specific JSON-to-`params` builder that consumes
`params/schell2013_ap360_sips_binary/schell_2013_source_pack.json`, constructs a
toPSAil `params` struct, and calls `runPsaCycle(params)` directly for later
health and validation runs.

This route preserves the toPSAil-native cycle, boundary-condition,
equalisation, auxiliary-unit, and solver machinery while avoiding new files
under the toPSAil core example tree. Optional Schell Sips integration remains a
separate intentional core-model task and must not be hidden in the case-input
builder.

## Options Evaluated

| Route | Assessment | Decision |
|---|---|---|
| A: wrapper around `runPsaProcessSimulation` or existing native example/params output | `runPsaProcessSimulation(folderName)` resolves cases under `4_example`, calls `getSimParams`, then runs plotting/saving side effects. Wrapping an existing example would either require non-Schell Excel inputs or a hidden overlay of many parameters from another case. This weakens source traceability. | Reject for Schell implementation. Useful only as a baseline smoke path. |
| B: JSON-to-params builder calling `runPsaCycle(params)` | `runPsaCycle(params)` is the native simulator entry point after parameter construction. A project builder can load the canonical Schell JSON, derive required fields, record the source-pack hash, and avoid adding or editing core files. | Select. |
| C: JSON-to-Excel generator | Keeps the Excel-oriented native input path, but creates duplicated source data and likely requires generated workbooks under `4_example` for `definePath2SourceFolders`/`getSimParams`. It also adds workbook-generation fragility before model health is known. | Reject for first Schell route. Reconsider only if direct `params` construction proves unmaintainable. |
| D: native Excel case under `4_example` | Most similar to original toPSAil examples, but `4_example` is project-defined core and adding a Schell case there requires explicit authorisation. It would also make the JSON source pack secondary unless tightly generated. | Reject without explicit authorisation. |

## Repo Facts Inspected

- Native entry point: `2_run/runPsaProcessSimulation.m` accepts an example folder name, calls `definePath2SourceFolders`, calls `getSimParams(exampleFolder)`, then calls `runPsaCycle(params)`.
- Parameter loading path: `3_source/1_parameters/getSimParams.m` reads a fixed list of 17 Excel workbooks from `1_simulation_inputs`, merges their structs, derives model functions and dimensionless parameters, then returns `params`/`fullParams`.
- Excel files required: `0.1_simulation_configurations.xlsm`, `0.2_numerical_methods.xlsm`, `0.3_simulation_outputs.xlsm`, `1.1_natural_constants.xlsm`, `1.2_adsorbate_properties.xlsm`, `1.3_adsorbent_properties.xlsm`, `2.1_feed_stream_properties.xlsm`, `2.2_raffinate_stream_properties.xlsm`, `2.3_extract_stream_properties.xlsm`, `3.1_adsorber_properties.xlsm`, `3.2_feed_tank_properties.xlsm`, `3.3_raffinate_tank_properties.xlsm`, `3.4_extract_tank_properties.xlsm`, `3.5_feed_compressor_properties.xlsm`, `3.6_extract_compressor_properties.xlsm`, `3.7_vacuum_pump_properties.xlsm`, and `4.1_cycle_organization.xlsm`.
- Platform constraints: `3_source/1_parameters/getExcelParams.m` errors with `Platform not supported` on Unix-like MATLAB, and reads workbook sheets named `Data(Transposed)` and `Data(Test)` on supported platforms.
- Existing examples available: `4_example/case_study_1.0` plus archived examples under `4_example/0_archive`; adding a Schell case under `4_example` is not authorised by this task.
- Existing tests/runners available: Tier 0 smoke, Tier 1 Schell source-pack tests, and Tier 2 Schell Sips equation-local tests under `scripts/` and `tests/`.

## Compatibility With Project Rules

Does the route touch toPSAil core? `no`

The selected route should add project-specific scripts/tests only. It may call
core functions such as `runPsaCycle` and existing parameter helper functions,
but it must not edit files under `1_config/`, `2_run/`, `3_source/`,
`4_example/`, `5_reference/`, or `6_publication/`.

Future optional Schell Sips integration is separate. If the builder reaches the
point where native core isotherm registration is required, stop before editing
core and use the dedicated Sips integration planning step.

## Source Traceability

How the route consumes `schell_2013_source_pack.json`:

- Load the canonical JSON source pack with MATLAB `jsondecode`.
- Select the target case by `case_id`, beginning with `schell_20bar_tads40_performance_central`.
- Populate project-specific raw inputs and derived `params` fields from JSON values, not from copied Excel constants.
- Preserve unresolved assumptions from the JSON in the run summary warnings.

How source-pack hash is recorded in outputs:

- Compute SHA256 for `params/schell2013_ap360_sips_binary/schell_2013_source_pack.json`.
- Store it in the summary field `source_pack_sha256`.
- Current SHA256: `b50eef14ce62bbe509c235e98f68983319bc0abe94fe2400d40f8c07d22ae0e7`.

## Smallest First Runnable Case

Case ID: `schell_20bar_tads40_performance_central`

Cycles: `1` for the first health run; CSS validation remains later.

Expected runtime: target under 60 minutes for the first health run; scaffold
field-presence tests should run in seconds.

Expected hard checks:

- MATLAB completes without exception.
- No NaN or Inf in summary metrics or sampled states.
- Positive absolute pressure.
- Positive absolute temperature.
- Mole fractions finite and within tolerance of `[0, 1]`.
- Boundary-flow and stream-accounting fields exist.
- CSS residual or explicit not-yet-CSS status is reported.
- Source-pack SHA256 and model mode are recorded.

Expected output summary path:

`validation/reports/schell_2013/health/schell_20bar_tads40_performance_central_summary.json`

## Risks

| Risk | Mitigation |
|---|---|
| Flow-rate basis | Use the canonical actual-volumetric-at-step-pressure conversion first. Carry `FLOW_BASIS` into the summary warnings and report large inventory, thermal, pressure, or product-metric evidence before any sensitivity branch. |
| Optional core Sips integration | Stop before core edits. Remind the project owner that Schell Sips is an intentional optional non-default core isotherm addition requiring a dedicated plan. Do not substitute native extended Langmuir-Freundlich as if equivalent. |
| Pressure equalization | Use toPSAil-native equalisation first. Do not invent `p_peq` or implement Schell/Casas pressure-changing formulas in the default route. Report equalisation endpoint diagnostics when available. |
| MATLAB/Excel platform | Avoid relying on generated Excel workbooks for the Schell case. Use MATLAB R2026a and direct JSON/`params` construction. |
| Output extraction | Emit a schema-aligned summary JSON matching `docs/workflow/schell_2013_implementation/schell_2013_output_summary.schema.json`; do not rely only on plots or native CSV files. |
| Hidden template leakage | Do not seed Schell values by copying an existing example case unless every inherited value is explicitly justified or overwritten from the source pack. |

## Recommendation

Proceed with route `B`: add the smallest JSON-to-`params` scaffold that can be inspected and tested without running full CSS. The scaffold should preserve source-pack traceability, call `runPsaCycle(params)` only after required fields and the isotherm route are valid, and produce a schema-aligned health summary for the central 20 bar, 40 s adsorption case. Do not implement this route inside `SCHELL-05`; the next task should add only the first inspectable scaffold and stop before any unauthorised core change.
