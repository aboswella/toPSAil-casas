# Schell 2013 implementation task cards

These task cards are ordered. Codex must execute one task at a time and stop after the required report. Do not combine tasks unless explicitly instructed by a human maintainer.

Use PowerShell-safe commands. Prefer `rg`, `rg --files`, `git status --short`, and MATLAB R2026a commands from `AGENTS.md`. Do not use Unix-only `find` as a required command.

## Global stop conditions

Stop and report instead of editing if:

- the working tree has unexplained changes;
- source values conflict;
- a required parameter is missing;
- the task would touch toPSAil core files without explicit authorisation;
- MATLAB cannot run the required test;
- a validation mismatch has multiple plausible causes;
- a test threshold would need weakening;
- the task would mix source transcription, model physics, output metrics, and validation tuning.

## Required report format

Every task must end with:

- task objective;
- files inspected;
- files changed;
- commands run;
- tests passed;
- tests failed;
- unresolved uncertainties;
- whether any toPSAil core files changed;
- whether any validation numbers changed;
- next smallest recommended task.

---

## SCHELL-PRE - Planning bundle acceptance

### Goal

Ensure the repository state is intentionally clean before readiness checks.

### Allowed files

- None, unless the human explicitly asks you to copy this implementation pack into the repo.

### Forbidden files

- All toPSAil core files.
- All source, parameter, validation, and test files unless explicitly asked to copy the pack.

### Source basis

- This implementation pack.
- `docs/GIT_WORKFLOW.md`.
- `AGENTS.md`.

### Preconditions

- Repository is open at its root.

### Required commands

```powershell
git status --short
git branch --show-current
git log -1 --oneline
rg --files docs/workflow/schell_2013_implementation params/schell2013_ap360_sips_binary validation/targets validation/manifests tests/fixtures
```

If `docs/workflow/schell_2013_implementation` does not exist yet, report that the pack has not been copied and stop.

### Runtime limit

5 minutes.

### Stop conditions

- Unexplained dirty files exist.
- Pack files are untracked and the human has not accepted, committed, or whitelisted them.

### Deliverable

A repo-state report. Do not implement Schell work.

---

## SCHELL-00 - Readiness audit, no edits

### Goal

Audit repo controls, branch, baseline scaffolds, and Schell-relevant files without editing.

### Allowed files

- None.

### Forbidden files

- All files.

### Source basis

- `AGENTS.md`.
- `docs/TASK_PROTOCOL.md`.
- `docs/TEST_POLICY.md`.
- `docs/VALIDATION_STRATEGY.md`.
- `docs/source_reference/02_schell_2013_two_bed_psa_validation.md`.

### Preconditions

- `SCHELL-PRE` accepted or clean.

### Required commands

```powershell
git status --short
git branch --show-current
rg --files | Select-String "^(scripts|tests|params/schell2013|cases/schell_2bed_validation|validation/manifests|docs/source_reference|docs/workflow)"
Get-Content AGENTS.md
Get-Content docs/TASK_PROTOCOL.md
Get-Content docs/TEST_POLICY.md
Get-Content docs/VALIDATION_STRATEGY.md
Get-Content docs/source_reference/02_schell_2013_two_bed_psa_validation.md
```

### Runtime limit

15 minutes.

### Stop conditions

- Any required control document is missing.
- Working tree is unexpectedly dirty.

### Deliverable

Readiness report with blockers and the exact next task. No edits.

---

## SCHELL-00B - Baseline smoke harness or accepted baseline-status report

### Goal

Establish baseline toPSAil run status before Schell modifications.

### Allowed files

- `scripts/run_smoke.m`
- `tests/README.md`
- `docs/workflow/schell_2013_implementation/baseline_status.md`

### Forbidden files

- `1_config/`
- `2_run/`
- `3_source/`
- `4_example/`
- validation target files
- Schell parameter values

### Source basis

- `AGENTS.md` Tier 0 requirement.
- `docs/TEST_POLICY.md`.
- Existing `.codex/prompts/03_post_audit_baseline_smoke_task.md` and `.codex/prompts/04_baseline_topsail_smoke.md`.

### Preconditions

- `SCHELL-00` complete.

### Required commands

```powershell
rg --files 4_example
rg --files scripts tests
& 'C:\Program Files\MATLAB\R2026a\bin\matlab.exe' -batch "addpath(genpath(pwd)); run('scripts/run_smoke.m');"
```

If MATLAB or a usable baseline example is unavailable, create `docs/workflow/schell_2013_implementation/baseline_status.md` explaining why baseline is blocked. Do not fake a pass.

### Runtime limit

30 minutes.

### Stop conditions

- Requires editing toPSAil core.
- No baseline example can be identified.
- MATLAB cannot run.

### Deliverable

Either a passing Tier 0 smoke harness or a documented accepted blocker. No Schell source values changed.

---

## SCHELL-01 - Correct Schell source-reference semantics

### Goal

Make existing Schell source-reference documentation implementation-safe.

### Allowed files

- `docs/source_reference/02_schell_2013_two_bed_psa_validation.md`
- `docs/KNOWN_UNCERTAINTIES.md`

### Forbidden files

- toPSAil core files
- `params/`
- `validation/targets/`
- test files

### Source basis

- `docs/workflow/schell_2013_implementation/source_extraction_audit.md`
- `sources/Schell 2013.pdf`
- `sources/Schell 2013 SI.pdf`

### Preconditions

- `SCHELL-00B` complete or accepted as blocked.

### Required edits

- Distinguish LDF `k_i [1/s]` from Sips affinity `k_i [1/Pa]`.
- Rename/clarify `K_L = 0.04 W/(m K)` as fluid thermal conductivity used for heat-transfer correlation.
- Add flow-rate conversion warning and example molar flows.
- Mark `p_peq` as unresolved/not table-given.
- State detector piping/stagnant tank is diagnostic-only by default.
- State JSON source pack is canonical once added.

### Required tests

```powershell
rg "fluid thermal conductivity|FLOW_BASIS|p_peq|Sips affinity|LDF" docs/source_reference/02_schell_2013_two_bed_psa_validation.md docs/KNOWN_UNCERTAINTIES.md
git diff -- docs/source_reference/02_schell_2013_two_bed_psa_validation.md docs/KNOWN_UNCERTAINTIES.md
```

### Runtime limit

20 minutes.

### Stop conditions

- Source conflict requires original PDF review beyond the audit.
- Edit would alter numeric validation targets.

### Deliverable

Semantic corrections only. No parameters or tests added.

---

## SCHELL-02 - Populate Schell validation manifest

### Goal

Replace the scaffold Schell validation manifest with concrete hard checks, soft targets, and first-case definition.

### Allowed files

- `validation/manifests/schell_2bed_validation.md`

### Forbidden files

- toPSAil core files
- source-reference docs
- source pack JSON
- tests

### Source basis

- `validation/manifests/schell_2bed_validation_PROPOSED.md`
- `docs/source_reference/02_schell_2013_two_bed_psa_validation.md`
- `validation/targets/schell_2013_validation_targets.csv` once present

### Preconditions

- `SCHELL-01` complete.

### Required edits

Use the proposed manifest content, adjusted only for paths that exist in the repo.

### Required tests

```powershell
rg "schell_20bar_tads40_performance_central|JSON is canonical|in_band|near_band|out_of_band|not included in default smoke" validation/manifests/schell_2bed_validation.md
git diff -- validation/manifests/schell_2bed_validation.md
```

### Runtime limit

15 minutes.

### Stop conditions

- Validation target CSV does not exist and the task was not authorised to add it.
- Numeric targets conflict with source reference.

### Deliverable

Populated manifest. No simulator changes.

---

## SCHELL-03A - Add canonical source-pack schema and typed source pack

### Goal

Add the canonical Schell source pack, schema, validation target CSV, and anchor fixture files.

### Allowed files

- `params/schell2013_ap360_sips_binary/schell_2013_source_pack.json`
- `params/schell2013_ap360_sips_binary/schell_2013_source_pack.schema.json`
- `params/schell2013_ap360_sips_binary/schell_2013_sips_anchor_cases.json`
- `params/schell2013_ap360_sips_binary/schell_2013_sips_anchor_cases.csv`
- `params/schell2013_ap360_sips_binary/README.md`
- `validation/targets/schell_2013_validation_targets.csv`
- `tests/fixtures/schell_2013_sips_anchor_cases.json`

### Forbidden files

- toPSAil core files
- MATLAB model files
- validation reports

### Source basis

- This implementation pack's `repo_overlay/params/schell2013_ap360_sips_binary/` files.
- `docs/source_reference/02_schell_2013_two_bed_psa_validation.md`.

### Preconditions

- `SCHELL-02` complete.

### Required tests

```powershell
python -m json.tool params/schell2013_ap360_sips_binary/schell_2013_source_pack.json > $null
python -m json.tool params/schell2013_ap360_sips_binary/schell_2013_source_pack.schema.json > $null
python -m json.tool params/schell2013_ap360_sips_binary/schell_2013_sips_anchor_cases.json > $null
rg "flow_rate_conversion_basis|unresolved_assumptions|schell_20bar_tads40_performance_central|competitive_temperature_dependent_sips" params/schell2013_ap360_sips_binary validation/targets tests/fixtures
```

### Runtime limit

20 minutes.

### Stop conditions

- Any numeric value must be stored as a string.
- YAML is introduced as a second hand-edited source of truth.
- Source pack lacks `flow_rate_conversion_basis` or `unresolved_assumptions`.

### Deliverable

Canonical typed source pack. No tests yet beyond parse/sanity commands.

---

## SCHELL-03B - Add Tier 1 source-pack tests

### Goal

Add MATLAB tests that verify the source pack and validation targets load correctly and catch transcription/unit mistakes.

### Allowed files

- `tests/test_schell_source_pack.m`
- `scripts/run_source_tests.m`
- `tests/README.md`

### Forbidden files

- toPSAil core files
- source pack values
- validation targets, unless the test reveals an actual transcription error and the human authorises correction

### Source basis

- `params/schell2013_ap360_sips_binary/schell_2013_source_pack.json`
- `params/schell2013_ap360_sips_binary/schell_2013_source_pack.schema.json`
- `validation/targets/schell_2013_validation_targets.csv`

### Preconditions

- `SCHELL-03A` complete.

### Required test coverage

The test must check:

- JSON loads with `jsondecode`.
- `canonical == true`.
- all required top-level fields exist.
- numeric values are numeric, not char/string.
- Table 1 values match expected constants.
- Table 2 central target values match expected constants.
- flow conversion examples exist and central 20 bar conversion is approximately `0.01614 mol/s`.
- unresolved assumptions include required IDs.
- no YAML canonical file exists.

### Required commands

```powershell
& 'C:\Program Files\MATLAB\R2026a\bin\matlab.exe' -batch "addpath(genpath(pwd)); run('scripts/run_source_tests.m');"
```

If MATLAB is unavailable, also run and report:

```powershell
python -m json.tool params/schell2013_ap360_sips_binary/schell_2013_source_pack.json > $null
```

### Runtime limit

20 minutes.

### Stop conditions

- Test requires changing source values to pass.
- MATLAB cannot read JSON on the installed version.

### Deliverable

Passing Tier 1 source tests or a precise blocker.

---

## SCHELL-04 - Add equation-local Schell Sips tests

### Goal

Add isolated Schell Sips equation tests using independent numerical anchors without touching toPSAil core.

### Allowed files

- `tests/test_schell_sips_reference.m`
- `scripts/run_equation_tests.m`
- `tests/fixtures/schell_2013_sips_anchor_cases.json`
- `tests/README.md`

### Forbidden files

- `3_source/`
- native isotherm dispatch files
- source pack values, unless a human authorises correction

### Source basis

- `params/schell2013_ap360_sips_binary/schell_2013_source_pack.json`
- `tests/fixtures/schell_2013_sips_anchor_cases.json`

### Preconditions

- `SCHELL-03B` complete.

### Required test coverage

- Recompute Sips loading from source-pack parameters.
- Compare to all anchor cases with relative tolerance `1e-8` and absolute tolerance `1e-10 mol/kg`.
- Pure CO2 case gives zero H2 loading.
- Pure H2 case gives zero CO2 loading.
- Pure CO2 loading increases from 1 bar to 20 bar.
- Binary 323.15 K CO2 loading is lower than binary 298.15 K CO2 loading at same pressure/composition.

### Required commands

```powershell
& 'C:\Program Files\MATLAB\R2026a\bin\matlab.exe' -batch "addpath(genpath(pwd)); run('scripts/run_equation_tests.m');"
```

### Runtime limit

20 minutes.

### Stop conditions

- Test implementation disagrees with anchors and the reason is not obvious.
- Any core file edit appears necessary.

### Deliverable

Passing Tier 2 Sips tests. No default behaviour change.

---

## SCHELL-05 - Case-input strategy review

### Goal

Decide how Schell JSON/source-pack inputs will become a runnable toPSAil case, preferring wrappers around simulator entry points wherever practical.

### Allowed files

- `docs/workflow/schell_2013_implementation/case_input_strategy.md`

### Forbidden files

- toPSAil core files
- scripts that implement the route
- tests that depend on the route

### Source basis

- `docs/workflow/schell_2013_implementation/case_input_strategy_template.md`
- `2_run/runPsaProcessSimulation.m`
- `3_source/1_parameters/getSimParams.m`
- `3_source/1_parameters/getExcelParams.m`
- `AGENTS.md`

### Preconditions

- `SCHELL-04` complete.

### Required commands

```powershell
rg "function runPsaProcessSimulation|function params = getExcelParams|Platform not supported|readtable|Data\(Transposed\)" 2_run 3_source scripts tests 4_example
rg --files 4_example scripts tests params/schell2013_ap360_sips_binary
```

### Required decision options

Evaluate:

- A: wrapper around `runPsaProcessSimulation` or an existing native example/params output;
- B: JSON-to-params MATLAB builder calling `runPsaCycle(params)`;
- C: JSON-to-Excel generator;
- D: native Excel case under `4_example`.

Recommend exactly one route or `blocked`.

### Runtime limit

30 minutes.

### Stop conditions

- The route would require core edits other than the separately planned optional Sips isotherm integration.
- Existing example structure cannot be inspected.

### Deliverable

A decision record only. No implementation.

---

## SCHELL-06 - Add chosen input scaffold

### Goal

Create the smallest project-specific scaffold for the route selected in `SCHELL-05`.

### Allowed files

Allowed files depend on `SCHELL-05`. Default allowed files if route C is selected:

- `scripts/build_schell_params_from_source_pack.m`
- `scripts/run_schell_case_health.m`
- `tests/test_schell_case_scaffold.m`
- `scripts/run_sanity_tests.m`
- `docs/workflow/schell_2013_implementation/case_input_strategy.md`

If route A requires `4_example`, stop unless the human explicitly authorises editing/adding under `4_example`.

### Forbidden files

- toPSAil core files unless the human explicitly authorises them.
- Sips core registration files.
- validation reports.

### Source basis

- `SCHELL-05` decision record.
- source pack JSON.

### Preconditions

- `SCHELL-05` complete with a non-blocked route.

### Required tests

```powershell
& 'C:\Program Files\MATLAB\R2026a\bin\matlab.exe' -batch "addpath(genpath(pwd)); run('scripts/run_sanity_tests.m');"
```

The test may verify scaffold creation and parameter-field presence without running full CSS.

### Runtime limit

45 minutes.

### Stop conditions

- Chosen route requires core edits without authorisation.
- Scaffold cannot preserve source-pack traceability.
- More than one route is being implemented.

### Deliverable

Smallest runnable or inspectable scaffold, not full validation.

---

## SCHELL-07 - Plan and integrate optional core Sips isotherm

### Goal

Plan, then implement, the optional non-default Schell Sips core isotherm route required before the first central health run.

### Allowed files

- `docs/workflow/schell_2013_implementation/schell_sips_integration_plan.md`, if a written plan note is useful.
- `3_source/3_models/1_adsEquilibrium/calcIsothermSchellSips.m`
- `3_source/1_parameters/getSubModels.m`
- `3_source/1_parameters/getAdsEquilParams.m`, only if Schell Sips needs explicit dimensionless/normalisation handling there.
- `scripts/build_schell_params_from_source_pack.m`
- `tests/test_schell_sips_reference.m`
- `tests/test_schell_case_scaffold.m`
- `scripts/run_equation_tests.m`
- `scripts/run_sanity_tests.m`
- `tests/README.md`

### Forbidden files

- toPSAil core files outside the explicit allowed list above.
- Boundary-condition, pressure-flow, cycle, solver, and output/plotting core files.
- Validation thresholds.
- Source pack values.
- Validation targets.
- Validation reports.

### Source basis

- `SCHELL-04` equation-local tests.
- `SCHELL-05` route-B decision record.
- `SCHELL-06` Schell case scaffold.
- `params/schell2013_ap360_sips_binary/schell_2013_source_pack.json`
- Project-owner decision that adding Schell Sips as an optional non-default core isotherm is intentional.

### Preconditions

- `SCHELL-04` passing.
- `SCHELL-06` complete.
- Project owner has confirmed that `SCHELL-07` is the plan + integration stage, not merely a no-edit reminder.

### Required first step

Before editing core files, state the implementation plan in chat or in
`docs/workflow/schell_2013_implementation/schell_sips_integration_plan.md`.
The plan must say:

- Schell Sips integration is an intentional optional core-model addition.
- It must not change default toPSAil behaviour.
- Existing extended Langmuir-Freundlich must not be treated as equivalent to Schell Sips.
- The intended optional isotherm selector is `modSp(1) == 7`, using an existing TBD slot and leaving selectors `1` through `6` unchanged.
- The initial implementation scope is isotherm dispatch/equilibrium support only; it must not change boundary conditions, cycle logic, pressure-flow handling, validation targets, or source values.

### Required implementation

- Add a Schell Sips isotherm function whose equation matches the `SCHELL-04` reference calculation and anchor cases:

```text
n_i_star = n_inf_i * (k_i * y_i * p)^s_i / (1 + sum_j (k_j * y_j * p)^s_j)
n_inf_i = a_i * exp(-b_i / (R*T))
k_i = A_i * exp(-B_i / (R*T))
s_i = alpha_i * atan(beta_i * (T - Tref_i)) + sref_i
```

- Register that function as an optional non-default model in `getSubModels.m` using `modSp(1) == 7`.
- Keep all existing isotherm selectors and default examples behaviour unchanged.
- Update the route-B scaffold so `SIPS_CORE_INTEGRATION` no longer blocks run readiness only after the optional core route passes tests.
- Extend the Tier 2/Tier 3 tests so the core route is checked against the independent Sips anchors and the scaffold confirms the required isotherm route works.

### Required tests

```powershell
& 'C:\Program Files\MATLAB\R2026a\bin\matlab.exe' -batch "addpath(genpath(pwd)); run('scripts/run_source_tests.m'); run('scripts/run_equation_tests.m'); run('scripts/run_sanity_tests.m');"
& 'C:\Program Files\MATLAB\R2026a\bin\matlab.exe' -batch "addpath(genpath(pwd)); run('scripts/run_smoke.m');"
```

Test expectations:

- Tier 1 source-pack tests still pass.
- Tier 2 Schell Sips equation tests compare the optional core isotherm route to all independent anchors.
- Tier 3 scaffold test confirms the required isotherm route works for the central case scaffold.
- Tier 0 smoke still passes, proving default toPSAil behaviour was not broken.

### Runtime limit

90 minutes.

### Stop conditions

- The implementation would require core edits outside the explicitly allowed files.
- The implementation would change default toPSAil behaviour or existing isotherm selector meanings.
- Existing extended Langmuir-Freundlich is being treated as equivalent to Schell Sips.
- A source-pack value, validation target, or validation threshold would need to change.
- Boundary-condition, pressure-flow, cycle, or solver changes appear necessary.
- MATLAB cannot run the required tests.
- The task drifts into the `SCHELL-08` health run or any validation-number generation.

### Deliverable

Passing optional Schell Sips core isotherm route, documented as non-default, with default toPSAil smoke still passing. No health run and no validation-number changes.

---

## SCHELL-08 - First central health run

### Goal

Run one minimal health simulation for `schell_20bar_tads40_performance_central` before CSS validation.

### Allowed files

- `scripts/run_schell_case_health.m`
- `validation/reports/schell_2013/health/*`
- test runner updates needed for Tier 3

### Forbidden files

- source pack values
- validation targets
- core files unless previously authorised

### Source basis

- source pack central case.
- `schell_2013_output_summary.schema.json`.

### Preconditions

- Input scaffold exists.
- Required isotherm route works.
- `SCHELL-07` complete.
- Tier 1 and Tier 2 tests pass.

### Required checks

- Simulation starts and completes requested minimal run.
- Pressures positive.
- Temperatures positive.
- Mole fractions valid.
- No NaN/Inf.
- Summary JSON emitted.

### Required commands

```powershell
& 'C:\Program Files\MATLAB\R2026a\bin\matlab.exe' -batch "addpath(genpath(pwd)); run('scripts/run_source_tests.m'); run('scripts/run_equation_tests.m'); run('scripts/run_sanity_tests.m'); run('scripts/run_schell_case_health.m');"
python -m json.tool validation/reports/schell_2013/health/schell_20bar_tads40_performance_central_summary.json > $null
```

### Runtime limit

60 minutes.

### Stop conditions

- Health failure has multiple plausible causes.
- Fix would require changing source values or validation targets.

### Deliverable

Health summary and next diagnostic, not CSS validation.

---

## SCHELL-09 - CSS run and output extractor for central case

### Goal

Run the central case to CSS or accepted cycle limit and extract a schema-compliant summary.

### Allowed files

- `scripts/run_schell_central_css.m`
- `scripts/extract_schell_summary.m`
- `scripts/build_schell_runnable_params.m`
- limited update to `scripts/run_schell_case_health.m` only to reuse the shared runnable-param builder
- `validation/reports/schell_2013/central/*`
- `docs/workflow/schell_2013_implementation/output_mapping.md`

### Forbidden files

- source pack values
- validation targets
- core files unless already authorised
- tuning physical constants, solver tolerances, metrics, or validation thresholds to improve agreement

### Source basis

- `schell_2013_output_summary.schema.json`.
- source pack central case.

### Preconditions

- `SCHELL-08` health run succeeds and its summary JSON hard checks are all true.
- Carry forward the current known warnings instead of treating them as fixed: `FLOW_BASIS`, unresolved `P_PEQ`, native equalization, purge approximation, and the health-run thermal-mode limitation.
- Treat the optional Schell Sips route as a likely runtime/stiffness amplifier based on the reduced diagnostic; do not infer that native receiver-tank pressure messages are Sips-specific.

### Implementation notes

- Factor shared JSON-to-runnable-`params` construction out of `scripts/run_schell_case_health.m` before adding the CSS runner so SCHELL-09 does not duplicate the Schell cycle/tank/valve/component mapping setup.
- Keep the run mode `topsail_native`; do not add Schell/Casas pressure-time boundary functions or validation tuning in this task.
- The first CSS attempt must be bounded: default to a 5-cycle cap unless the caller explicitly overrides it, and report whether the run reached CSS or stopped at the cap.

### Required extractor fields

- source pack SHA256;
- model mode;
- cycles requested/completed;
- CSS residual;
- hard-check booleans;
- performance metrics if available;
- stream accounting residuals;
- thermocouple-position temperatures;
- pressure history summary;
- raw output paths;
- warnings.
- accepted cycle cap and stop reason.

### Required commands

```powershell
& 'C:\Program Files\MATLAB\R2026a\bin\matlab.exe' -batch "addpath(genpath(pwd)); run('scripts/run_schell_central_css.m');"
python -m json.tool validation/reports/schell_2013/central/summary.json > $null
```

### Runtime limit

Human-approved. The default first attempt is capped at 5 cycles; a higher cap requires an explicit caller override and must not be hidden in default smoke.

### Stop conditions

- CSS does not converge and cause is unclear.
- Extractor cannot map raw outputs unambiguously.
- The run exceeds the approved cycle/runtime budget.
- The next fix would require source-value, validation-target, pressure-boundary, solver, or metric changes.

### Deliverable

Schema-compliant summary with model mode, accepted cycle cap, stop reason, carried warnings, and raw output paths. No validation tuning.

---

## SCHELL-10 - Central soft-validation report

### Goal

Compare central case summary to published Table 2 metrics and produce a report without tuning.

### Allowed files

- `scripts/report_schell_validation.m` or project-specific equivalent
- `validation/reports/schell_2013/central/*`

### Forbidden files

- source pack values
- validation targets
- physics/model files
- thresholds, unless a separate manifest task authorises them

### Source basis

- `validation/targets/schell_2013_validation_targets.csv`.
- `validation/manifests/schell_2bed_validation.md`.

### Preconditions

- `SCHELL-09` summary exists.

### Required behaviour

If mismatch exceeds provisional tolerance:

- produce the report anyway;
- classify as `near_band` or `out_of_band`;
- list plausible causes;
- do not tune parameters;
- do not edit model files;
- propose the next smallest diagnostic task.

### Required commands

```powershell
& 'C:\Program Files\MATLAB\R2026a\bin\matlab.exe' -batch "addpath(genpath(pwd)); run('scripts/report_schell_validation.m');"
```

### Runtime limit

20 minutes after summary exists.

### Stop conditions

- Report would require changing targets.
- Summary schema is invalid.

### Deliverable

Central validation report, even if the model is wrong. Especially if the model is wrong.

---

## SCHELL-11 - Remaining 20 bar performance cases

### Goal

Run and report the 20 bar performance series at `t_ads = 20, 60, 100, 100 s` using the same model and extractor.

### Allowed files

- `scripts/run_schell_20bar_series.m`
- `validation/reports/schell_2013/20bar_series/*`

### Forbidden files

- source values
- model tuning
- validation thresholds

### Source basis

- `validation/targets/schell_2013_validation_targets.csv`.

### Preconditions

- `SCHELL-10` central report exists.
- Any central blocker accepted or resolved in a separate diagnostic task.

### Required behaviour

Use identical physical parameters across all 20 bar cases. Do not tune per adsorption time.

### Required commands

```powershell
& 'C:\Program Files\MATLAB\R2026a\bin\matlab.exe' -batch "addpath(genpath(pwd)); run('scripts/run_schell_20bar_series.m');"
```

### Runtime limit

Human-approved. Not default smoke.

### Stop conditions

- A run failure has multiple plausible causes.
- Per-case tuning is proposed.

### Deliverable

Series summary and trend report.

---

## SCHELL-12 - 10 and 30 bar profile cases

### Goal

Run the 10 bar and 30 bar Schell profile cases and report pressure/temperature plausibility.

### Allowed files

- `scripts/run_schell_pressure_profile_cases.m`
- `validation/reports/schell_2013/profile_cases/*`

### Forbidden files

- source values
- model tuning
- validation thresholds without explicit human-supplied source targets

### Source basis

- source pack cycle cases 1 and 3.
- Schell paper temperature-profile discussion.

### Preconditions

- 20 bar central health and validation reports exist.

### Required behaviour

Treat these as pressure/temperature profile cases, not scalar performance cases. Do not fabricate purity/recovery targets.

### Required outputs

- per-thermocouple temperature traces or sampled summaries;
- peak temperature by thermocouple;
- time of peak;
- pressure equalization endpoint estimate;
- qualitative profile agreement note;
- warnings that source profile comparison remains manual/qualitative.

### Required commands

```powershell
& 'C:\Program Files\MATLAB\R2026a\bin\matlab.exe' -batch "addpath(genpath(pwd)); run('scripts/run_schell_pressure_profile_cases.m');"
```

### Runtime limit

Human-approved. Not default smoke.

### Stop conditions

- The task tries to create scalar targets from figures without explicit human instruction.

### Deliverable

Profile-case report.

---

## SCHELL-13 - Optional detector/piping diagnostic mode

### Goal

Only if needed, add a labelled diagnostic model for piping/MS effects to interpret concentration traces.

### Allowed files

To be defined by a new task after central validation.

### Forbidden files

- default model path
- default validation report metrics
- source performance targets

### Source basis

- Schell 2013 Table 4 and Figure 8 discussion.

### Preconditions

- Central and profile reports exist.
- Human explicitly asks for detector/composition-profile diagnostics.

### Stop conditions

- Diagnostic is being mixed into default validation.
- Stagnant tank is being used to tune performance metrics.

### Deliverable

Separate diagnostic report only.
