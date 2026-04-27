# Schell 2013 implementation guidance for toPSAil-casas

## Executive summary

The Schell integration should be implemented as a staged validation benchmark, not as a heroic rewrite of toPSAil. The repository already has strict project controls: source ledgers, case specs, validation strategy, test tiers, boundary-condition policy, and thermal policy. Use them. The world has enough untraceable MATLAB.

The correct path is:

1. Establish repository cleanliness and baseline status.
2. Correct Schell source-reference semantics.
3. Populate the Schell validation manifest.
4. Add a typed canonical JSON source pack and source-pack tests.
5. Add equation-local Schell Sips tests with independent anchors.
6. Decide the case-input route before generating a native simulation case.
7. Add only the smallest simulation scaffold needed for the central 20 bar, 40 s adsorption case.
8. Run health checks before CSS validation.
9. Produce report-only soft validation before any tuning or model changes.
10. Extend to remaining 20 bar cases, then 10/30 bar profile cases.

The first implementation milestone is not "full Schell simulator runs". It is a clean, tested, source-traceable Schell benchmark definition.

## Repo-specific constraints

The fork's `AGENTS.md` treats `1_config/`, `2_run/`, `3_source/`, `4_example/`, `5_reference/`, and `6_publication/` as toPSAil core. Project work should normally stay in `cases/`, `params/`, `validation/`, `scripts/`, `tests/`, `docs/`, and `.codex/`.

The current project-specific `scripts/` and `tests/` folders are scaffold-only. That means Codex must add small runners before pretending a validation suite exists.

The native run path is Excel/example driven: `runPsaProcessSimulation(folderName)` resolves `4_example/<folderName>`, `getSimParams` reads many Excel workbooks, and `getExcelParams.m` errors on Linux. Therefore the Schell JSON source pack will not automatically run through native toPSAil. A case-input strategy decision is required before implementation.

The Schell SI Sips equation is not equivalent to the existing native extended Langmuir-Freundlich function. Do not register a core isotherm until the equation-local tests pass and a model-registration audit identifies every dispatch and nondimensionalisation point that must change.

## Best integration route

The recommended route is:

1. Keep the Schell source pack in JSON under `params/schell2013_ap360_sips_binary/`.
2. Add MATLAB Tier 1 tests that load this JSON and check source values.
3. Add MATLAB Tier 2 equation-local tests for the Schell Sips equation without touching core files.
4. Decide whether the runnable case should be:
   - a native Excel case,
   - a JSON-to-Excel generator,
   - a JSON-to-params MATLAB builder that calls `runPsaCycle(params)` directly,
   - or a minimal wrapper around existing `getSimParams` output.
5. Prefer a project-specific builder/generator over editing core machinery, unless the strategy review proves that core registration is the smaller and safer change.

Do not mix these routes. Choosing all of them is not robustness; it is indecision wearing a lab coat.

## Validation posture

Use hard tests for transcription, schema, equations, and numerical health. Use soft report-only comparison for published performance and profile agreement until the model is stable.

Hard checks:

- MATLAB completes without exception.
- No NaN or Inf.
- Positive absolute pressure.
- Positive absolute temperature.
- Valid mole fractions.
- CSS residual or equivalent convergence metric reported.
- Source pack schema and key numeric values pass.
- Sips anchor cases pass.

Soft checks:

- H2 purity.
- H2 recovery.
- CO2 purity.
- CO2 recovery/capture.
- Temperature profile shape and thermocouple positions.
- Pressure evolution and pressure equalization plausibility.
- Stream accounting sanity.

The first central performance case should be `schell_20bar_tads40_performance_central`, because Table 2 gives H2 and CO2 purity/recovery values and the SI explicitly discusses the 40 s example.

## Output-processing requirements

Every validation run must produce a machine-readable summary matching `schell_2013_output_summary.schema.json`.

At minimum, extract:

- case ID;
- source pack hash;
- model mode: `topsail_native`, `schell_reproduction`, or `diagnostic_only`;
- cycles requested and completed;
- CSS residual;
- hard-check results;
- H2 purity and recovery;
- CO2 purity and recovery/capture;
- stream accounting residuals;
- thermocouple-position temperature traces or sampled values;
- pressure traces and pressure equalization endpoint estimate;
- warnings and unresolved assumptions.

Do not rely only on plots. Plots are useful, but they are also where numbers go to hide.

## Critical assessment of the proposed approach

Your one-change, test, repeat approach is exactly right. The dangerous part is the phrase "implement this paper", because a paper is not a spec. Schell gives a strong experimental validation target, but not a drop-in toPSAil configuration. In particular:

- pressure equalization is described by reference to prior Casas work, not fully specified in one table;
- MFC flow basis is easy to misread by a factor of pressure;
- detector composition profiles are explicitly distorted by piping and possible stagnant volume;
- temperature profiles are the better validation signal;
- the source Sips equation is not native to current toPSAil;
- the native runner is Excel-centered and Windows-dependent.

The better framing is: implement a traceable Schell benchmark and then progressively close gaps between native toPSAil and the published experiment.

## Missing information and how to fill it

| Gap | Risk | Fill method |
|---|---|---|
| Clean branch base | Codex may mix planning files with implementation | `SCHELL-PRE`, then branch from clean state. |
| Baseline smoke status | Schell changes may be blamed for existing failures | `SCHELL-00B` before Schell implementation. |
| Case-input route | JSON pack may not run through native Excel path | `SCHELL-05` decision record. |
| Flow-rate basis | Factor-of-10 to factor-of-30 molar-flow error | Source-pack warning plus sensitivity report. |
| Intermediate equalization pressure | Invalid pressure schedule if invented | Native equalization first; later digitize Figure 7 or inspect prior Casas method. |
| Digitized temperature profiles | Cannot set hard profile thresholds | Begin qualitative/profile report; add digitization later. |
| MATLAB/CI availability | Tests may be impossible on Linux | PowerShell MATLAB R2026a commands and non-MATLAB JSON sanity checks. |

## Implementation rule

After every task, Codex must report whether any toPSAil core files changed and whether any validation numbers changed. If either happened without explicit authorisation, stop. This is not bureaucracy. It is the only thing standing between you and a validation result that means "the code changed somewhere".
