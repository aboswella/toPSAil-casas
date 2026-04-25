# Codex Execution Plan: Baseline toPSAil Run and Casas Breakthrough Validation

## Executive summary

This plan has two controlled phases.

First, Codex must prove that the unmodified toPSAil core runs. This is not a literature-validation task. Codex must run an original toPSAil example exactly as provided, then add only a small Tier 0 wrapper under `scripts/run_smoke.m` so that the same baseline check can be repeated. No files under `1_config/`, `2_run/`, `3_source/`, `4_example/`, `5_reference/`, or `6_publication/` may be edited. If the original example cannot run, Codex stops and reports the failure instead of “fixing” the simulator, because debugging by vandalism remains a poor civilisation-level habit.

Second, Codex must build the Casas 2012 breakthrough validation as a project-specific case, not as a solver rewrite. The required source values come from `docs/source_reference/01_casas_2012_breakthrough_validation.md` and `docs/source_reference/05_transcription_audit_and_guardrails.md`, not from fresh PDF searching. The implementation must proceed through parameter transcription, source tests, equation-local tests, a one-column Casas wrapper, then a Tier 4 validation run. The default mode is `topsail_native`: use toPSAil's native pressure-flow, boundary-condition, and solver machinery wherever possible. Core edits are forbidden unless a later task explicitly authorises a narrow adapter after Codex proves wrappers cannot work.

The intended sequence is:

1. Read-only audit of the actual toPSAil working tree.
2. Manual run of one original toPSAil example.
3. Add `scripts/run_smoke.m` as the repeatable Tier 0 baseline check.
4. Commit the baseline-smoke wrapper and tag/preserve the unmodified core baseline.
5. Read-only Casas implementation audit against the source-reference pack and actual toPSAil interfaces.
6. Add the Casas AP3-60 source parameter pack and Tier 1 transcription tests.
7. Add equation-local Sips, LDF, unit-conversion, and physical-sanity tests.
8. Add the one-column Casas-lite breakthrough case wrapper.
9. Run the Casas-lite validation and write a validation report.
10. Stop before tuning, threshold weakening, detector-piping reproduction, Schell work, Delgado work, sensitivity, or optimisation.

## Governing design principles

Codex must obey these project rules throughout:

- Do not edit toPSAil core folders unless a task explicitly authorises that exact core edit.
- Prefer project wrappers, case files, parameter files, validation manifests, scripts, and tests.
- Do not change physics, numerics, metrics, plotting, and validation thresholds in the same task.
- Do not tune physical constants to improve validation agreement.
- Do not mix Casas, Schell, Delgado, or thesis optimisation parameters.
- Use Casas 2012 as a breakthrough sanity validation, not as a mandate to reproduce detector piping, exact axial dispersion, or the exact breakthrough-front shape.
- Keep Tier 4 validation and Tier 5 sensitivity/optimisation out of the default smoke suite.
- If a required parameter is missing or ambiguous, stop and report it.
- If MATLAB cannot run the required check, stop and report it.

## Files Codex must read before any edit

Codex must read these in this order:

```text
AGENTS.md
docs/CODEX_PROJECT_MAP.md
docs/PROJECT_CHARTER.md
docs/MODEL_SCOPE.md
docs/SOURCE_LEDGER.md
docs/VALIDATION_STRATEGY.md
docs/TEST_POLICY.md
docs/BOUNDARY_CONDITION_POLICY.md
docs/THERMAL_MODEL_POLICY.md
docs/TASK_PROTOCOL.md
docs/KNOWN_UNCERTAINTIES.md
docs/REPORT_POSITIONING.md
docs/GIT_WORKFLOW.md
```

For the Casas phase, Codex must also read:

```text
cases/casas_lite_breakthrough/case_spec.md
params/casas2012_ap360_sips_binary/README.md
validation/manifests/casas_lite_breakthrough.md
docs/source_reference/00_source_reference_index.md
docs/source_reference/01_casas_2012_breakthrough_validation.md
docs/source_reference/05_transcription_audit_and_guardrails.md
```

Codex should not open the PDFs unless the task explicitly says that the source-reference pack is being audited or corrected.

---

# Phase 1: Ensure toPSAil works without edits

## Task 1.1: Read-only baseline audit

### Task ID

`baseline-readonly-audit`

### Goal

Confirm that the actual toPSAil core is present, map the original runnable examples, and identify the smallest reliable original example for a Tier 0 baseline smoke test.

### Allowed files

None. This is read-only.

### Forbidden files

All files are forbidden for editing.

### Required preflight commands

Run these before inspecting implementation details:

```bash
git status --short
git branch --show-current
git remote -v
```

Confirm these directories exist:

```text
1_config/
2_run/
3_source/
4_example/
5_reference/
6_publication/
```

If any are missing, stop. Do not infer anything from memory or from the scaffold.

### Required audit questions

Find and report:

1. Which original example is the smallest credible baseline run.
2. The exact MATLAB command or script path used to run it.
3. Whether the example writes `.mat`, `.csv`, figures, or other generated files.
4. Where isotherms are implemented.
5. Where LDF or other kinetic terms are implemented.
6. Where cycle steps and connections are defined.
7. Where boundary conditions are implemented.
8. Where CSS convergence is checked.
9. Where performance metrics are computed.
10. Whether the code appears to support single-column breakthrough runs.
11. Whether the code appears to support competitive Sips equilibrium.
12. Whether the code appears to support inert or non-adsorbing initial gas, relevant to the Casas `initial gas = He` detail.
13. Whether the code appears to support finite wall heat transfer.

### Required output

Return a report containing:

```text
task objective = baseline-readonly-audit
files inspected = <list>
commands run = <list>
selected baseline example = <path and command>
core directories present = yes/no
core edits made = no
risks and uncertainties = <list>
recommended next smallest task = manual-baseline-run
```

### Stop conditions

Stop if:

- any core directory is missing;
- the working tree has unrelated dirty files that make audit results ambiguous;
- no original example can be identified;
- MATLAB availability cannot be determined and the next task requires execution.

## Task 1.2: Manual original-example run, still no edits

### Task ID

`manual-baseline-run`

### Goal

Run one original toPSAil example without editing any file, proving the fork can execute before project-specific wrappers or Casas work are added.

### Allowed files

None. This is still no-edit execution.

### Forbidden files

All files are forbidden for editing.

### Preconditions

- Task `baseline-readonly-audit` completed.
- A specific original example command has been identified.
- MATLAB is available.

### Required command pattern

Use the exact example command identified in Task 1.1. The general form should be:

```matlab
addpath(genpath(pwd));
% run the selected original toPSAil example exactly as identified by audit
```

Do not run Casas, Schell, Delgado, sensitivity, or optimisation.

### Pass criteria

The original example passes if:

- MATLAB completes without an uncaught exception;
- no obvious NaN or Inf appears in final reported outputs, if outputs are accessible;
- generated outputs are understood and either ignored by Git or reported.

### Required output

Return:

```text
task objective = manual-baseline-run
files inspected = <list>
files changed = none
commands run = <exact MATLAB command>
tests passed = original example completed / not completed
tests failed = <list>
core files changed = no
validation numbers changed = no
next smallest task = baseline-smoke-runner
```

### Stop conditions

Stop if:

- the original example fails;
- fixing the failure would require editing toPSAil core;
- the example requires unavailable proprietary/toolbox features not already part of the environment.

## Task 1.3: Add repeatable Tier 0 smoke runner

### Task ID

`baseline-smoke-runner`

### Goal

Create the smallest repeatable smoke runner that exercises the original toPSAil example selected in the audit.

### Allowed files

```text
scripts/run_smoke.m
scripts/README.md
tests/README.md
docs/KNOWN_UNCERTAINTIES.md only if a blocker must be recorded
```

### Forbidden files

```text
1_config/
2_run/
3_source/
4_example/
5_reference/
6_publication/
params/
cases/
validation/manifests/
docs/source_reference/
```

### Required implementation

`scripts/run_smoke.m` must:

1. Save the current working directory and restore it on exit.
2. Add the repository to the MATLAB path using `addpath(genpath(repoRoot))` or equivalent.
3. Run exactly the selected original toPSAil example.
4. Avoid Casas, Schell, Delgado, source transcription, sensitivity, or optimisation work.
5. Catch failures only to print useful context and then rethrow, so smoke failures remain real failures.
6. Avoid committing generated outputs.
7. Report enough information to prove which original example ran.

A safe MATLAB structure is:

```matlab
function run_smoke()
    repoRoot = fileparts(fileparts(mfilename('fullpath')));
    oldDir = pwd;
    cleanupObj = onCleanup(@() cd(oldDir));
    addpath(genpath(repoRoot));

    fprintf('Running Tier 0 toPSAil baseline smoke test...\n');
    fprintf('Repository root: %s\n', repoRoot);

    try
        % Replace this with the exact original example command from the audit.
        % Example placeholder only:
        % run(fullfile(repoRoot, '4_example', '<selected_example>.m'));
    catch ME
        fprintf(2, 'Tier 0 smoke failed: %s\n', ME.message);
        rethrow(ME);
    end

    fprintf('Tier 0 baseline smoke test completed.\n');
end
```

If the repository convention requires script-style rather than function-style runners, Codex may use a script, but it must still restore path/cwd where practical.

### Required tests

Run:

```matlab
addpath(genpath(pwd));
run("scripts/run_smoke.m");
```

This is a Tier 0 test.

### Pass criteria

- `scripts/run_smoke.m` completes.
- No toPSAil core files are changed.
- No validation cases run.
- No Tier 4 or Tier 5 tasks are added to smoke.

### Commit/report

After passing, Codex should recommend a commit like:

```bash
git add scripts/run_smoke.m scripts/README.md tests/README.md docs/KNOWN_UNCERTAINTIES.md
git commit -m "Add Tier 0 toPSAil baseline smoke runner"
```

If no prior clean baseline tag exists, Codex should recommend preserving the unmodified core baseline with a tag or branch. The tag should refer to the commit that still has unmodified toPSAil core; the scaffold and wrapper may exist, but the core folders must be unchanged.

Suggested tag:

```bash
git tag baseline-topsail-unmodified
```

### Stop conditions

Stop if:

- the audit did not identify a reliable original example;
- MATLAB cannot run;
- creating the runner would require editing toPSAil core;
- the runner needs Casas, Schell, Delgado, sensitivity, or optimisation code.

---

# Phase 2: Modify project code for Casas breakthrough validation

## Casas implementation principle

The Casas task is not “make the plot look right.” It is:

```text
Build a one-column AP3-60 CO2/H2 breakthrough sanity case using source-transcribed Casas 2012 parameters, running through toPSAil-native machinery where possible, and reporting hard physical health plus approximate breakthrough timing and thermal-response behaviour.
```

The default model mode is:

```text
model_mode = topsail_native
```

Detector piping, exact axial-dispersion front shape, and full reproduction of the mass-spectrometer line are non-targets for the first Casas implementation.

## Task 2.1: Read-only Casas implementation audit

### Task ID

`casas-readonly-implementation-audit`

### Goal

Map the Casas source-reference requirements onto actual toPSAil interfaces before any parameter or case files are written.

### Allowed files

None. This is read-only.

### Forbidden files

All files are forbidden for editing.

### Required reading

```text
docs/source_reference/00_source_reference_index.md
docs/source_reference/01_casas_2012_breakthrough_validation.md
docs/source_reference/05_transcription_audit_and_guardrails.md
cases/casas_lite_breakthrough/case_spec.md
params/casas2012_ap360_sips_binary/README.md
validation/manifests/casas_lite_breakthrough.md
```

### Required mapping questions

Codex must answer:

1. Can toPSAil run a one-column fixed-bed breakthrough case natively?
2. How are components declared?
3. How are adsorbent and bed parameters declared?
4. How is competitive adsorption equilibrium selected or supplied?
5. Is competitive Sips already implemented?
6. Can an external isotherm function handle be supplied without core edits?
7. How are LDF kinetic constants supplied?
8. How are heats of adsorption supplied?
9. How is wall heat transfer represented?
10. How is inlet flow specified: volumetric flow, molar flow, velocity, or valve/pressure boundary?
11. How should `10 cm3/s` be mapped without inventing an undocumented pressure basis?
12. Can the initial bed gas be He, or must Casas-lite use a documented binary approximation?
13. How are outlet mole fractions and bed temperature profiles extracted?
14. Which outputs are needed for H2 breakthrough time, approximate CO2 breakthrough time, thermocouple-position temperatures, pressure positivity, temperature positivity, mole-fraction validity, and mass-balance sanity?
15. Which implementation files can be added without touching core?
16. If core edits appear necessary, exactly why wrappers cannot work.

### Required output

Codex must return an implementation design report:

```text
task objective = casas-readonly-implementation-audit
source_reference_file = docs/source_reference/01_casas_2012_breakthrough_validation.md
model_mode = topsail_native
files inspected = <list>
proposed project files = <list>
core edits required = yes/no
if core edits required, reason = <specific interface limitation>
known omissions = detector piping, exact axial-dispersion/front-shape reproduction, optional He fallback if unsupported
next smallest task = casas-parameter-pack-and-source-tests
```

### Stop conditions

Stop if:

- the source-reference files are absent;
- toPSAil cannot support any plausible one-column breakthrough run without core edits;
- the task would require silently choosing a flow conversion basis, an initial-gas approximation, or a wall-heat approximation.

## Task 2.2: Add Casas parameter pack and Tier 1 source tests

### Task ID

`casas-parameter-pack-and-source-tests`

### Goal

Create the Casas AP3-60 binary parameter pack and tests that prove the source values were transcribed correctly.

### Allowed files

```text
params/casas2012_ap360_sips_binary/**
tests/source/**
scripts/run_source_tests.m
validation/manifests/casas_lite_breakthrough.md
docs/KNOWN_UNCERTAINTIES.md only if an ambiguity is recorded
```

### Forbidden files

```text
1_config/
2_run/
3_source/
4_example/
5_reference/
6_publication/
cases/schell_2bed_validation/
cases/delgado_layered_extension/
params/schell2013_ap360_sips_binary/
params/delgado2014_bpl13x_lf_four_component/
```

### Required source values

Codex must transcribe the following from `docs/source_reference/01_casas_2012_breakthrough_validation.md`.

Reference operating condition:

```text
feed composition = 50 mol% CO2, 50 mol% H2
pressure = 15 bar
temperature = 298.15 K
feed flow rate = 10 cm3/s
initial pressurisation gas = He
regeneration context = vacuum 45 min, not default simulation boundary
```

Column, bed, and thermal values:

```text
L = 1.20 m
Ri = 0.0125 m
R0 = 0.020 m
eps_b = 0.403
eps_t = 0.742
rho_b = 507 kg/m3
rho_p = 850 kg/m3
dp = 0.003 m
a_p = 8.5e8 m2/m3
C_s = 1000 J/(kg K)
C_w = 4.0e6 J/(m3 K)
D_m = 4.3e-6 m2/s
DeltaH_CO2 = -26000 J/mol
DeltaH_H2 = -9800 J/mol
```

Dynamic fitted values for the default Casas-lite case:

```text
k_CO2 = 0.15 s^-1
k_H2 = 1.0 s^-1
hW = 5 J/(m2 s K)
eta1 = 41.13
eta2 = 0.32
```

Axial-dispersion correlation values, recorded but not necessarily active in the first toPSAil-native run:

```text
D_L = gamma1 * D_m + gamma2 * dp * u / eps
gamma1 = 0.7
gamma2 = 0.5
```

Competitive Sips parameters:

```text
CO2: omega = 1.38 mol/kg, theta = -5628 J/mol, Omega = 16.80e-9 1/Pa, Theta = -9159 J/mol, s1 = 0.072, s2 = 0.106 1/K, sref = 0.827, Tref = 329 K
H2:  omega = 6.66 mol/kg, theta = 0 J/mol,     Omega = 0.70e-9 1/Pa,  Theta = -9826 J/mol, s1 = 0,     s2 = 0 1/K,     sref = 0.9556, Tref = 273 K
```

Validation soft targets, recorded in the manifest but not used as hard pass/fail thresholds unless explicitly authorised:

```text
H2 breakthrough time = about 110 s
H2 outlet mole fraction rises near 110-130 s
CO2 breakthrough begins roughly 430-460 s by plot-read
final outlet composition approaches 50/50 feed
temperature front order = small H2 front first, larger CO2 front later
thermocouple positions = 10, 35, 60, 85, 110 cm from inlet
```

### Required implementation

Add a parameter-loading function or script with a stable name, for example:

```text
params/casas2012_ap360_sips_binary/load_casas2012_ap360_sips_binary.m
```

The loader should return one structure, for example:

```matlab
p = struct();
p.source_reference_file = "docs/source_reference/01_casas_2012_breakthrough_validation.md";
p.parameter_pack = "params/casas2012_ap360_sips_binary";
p.model_mode = "topsail_native";
p.components = {"CO2", "H2"};
p.operating.feed_y = [0.5, 0.5];
p.operating.T_feed_K = 298.15;
p.operating.P_feed_bar = 15;
p.operating.feed_flow_cm3_s = 10;
p.operating.initial_gas = "He";
% etc.
```

Use whatever structure layout best matches toPSAil, but every source value above must be retrievable and testable.

### Required Tier 1 tests

Add tests that check:

1. Every hard-transcription value equals the source-reference value.
2. Units are explicit.
3. Feed mole fractions sum to 1.
4. Absolute pressure and temperature are positive.
5. Component order is declared and used consistently.
6. Casas CO2 heat of adsorption is `-26000 J/mol`, not Schell's `-21000 J/mol`.
7. The Langmuir optional parameters are not used by default.
8. The detector-piping model is not silently enabled.
9. The initial gas `He` is recorded even if not yet supported by the case runner.

Required command:

```matlab
addpath(genpath(pwd));
run("scripts/run_source_tests.m");
```

### Pass criteria

- Source tests pass.
- No toPSAil core files changed.
- No validation run attempted.
- No Schell or Delgado constants imported.

### Stop conditions

Stop if:

- a required value is absent from the source-reference file;
- a unit conversion would require an unstated assumption;
- Codex wants to use values from Schell, Delgado, or the Casas thesis for this parameter pack;
- the test threshold would need to be weakened.

## Task 2.3: Add equation-local tests for Casas equilibrium and kinetics

### Task ID

`casas-equation-local-tests`

### Goal

Prove the local Casas equations behave sanely before connecting them to the full toPSAil run.

### Allowed files

```text
params/casas2012_ap360_sips_binary/**
tests/equations/**
scripts/run_equation_tests.m
docs/KNOWN_UNCERTAINTIES.md only if a blocker is recorded
```

### Forbidden files

```text
1_config/
2_run/
3_source/
4_example/
5_reference/
6_publication/
cases/schell_2bed_validation/
cases/delgado_layered_extension/
```

### Required implementation

If native toPSAil already exposes a competitive Sips evaluator compatible with the Casas form, test that evaluator through the parameter pack.

If not, add a project-local evaluator such as:

```text
params/casas2012_ap360_sips_binary/eval_casas2012_sips.m
```

The evaluator must implement:

```text
q_i_star = q_s_i * (K_i * p_i)^s_i / (1 + sum_j (K_j * p_j)^s_j)
q_s_i = omega_i * exp(-theta_i / (R*T))
K_i = Omega_i * exp(-Theta_i / (R*T))
s_i = s1_i * atan(s2_i * (T - Tref_i)) + sref_i
```

Use pressure in Pa and temperature in K.

If toPSAil requires a different sign convention for heats or equilibrium parameters, Codex must document the adapter explicitly rather than silently changing source values.

### Required Tier 2 tests

Add tests that check:

1. Sips loadings are finite and non-negative at representative Casas conditions.
2. CO2 equilibrium loading increases as CO2 partial pressure increases at fixed T and H2 partial pressure.
3. H2 equilibrium loading increases as H2 partial pressure increases at fixed T and CO2 partial pressure.
4. Competitive denominator contains both components.
5. Component order does not swap CO2 and H2.
6. LDF sign is correct: `dq/dt` is positive when `q_star > q`, negative when `q_star < q`, and zero when equal.
7. Heat release sign convention is recorded; do not flip source `DeltaH` values merely to make a local test pass.
8. Wall heat coefficient and wall heat capacity are present but not tuned.

Required command:

```matlab
addpath(genpath(pwd));
run("scripts/run_equation_tests.m");
```

### Pass criteria

- Equation-local tests pass.
- No full simulation is run.
- No core files are changed.

### Stop conditions

Stop if:

- native and source Sips forms are incompatible and no wrapper/adapter can be used outside core;
- the heat sign convention cannot be mapped unambiguously;
- a core edit appears necessary to pass equation functions into the simulator.

## Task 2.4: Add one-column Casas-lite case wrapper and Tier 3 sanity run

### Task ID

`casas-one-column-sanity-wrapper`

### Goal

Create the smallest one-column Casas-lite breakthrough case that can run through toPSAil-native machinery and pass hard physical sanity checks.

### Allowed files

```text
cases/casas_lite_breakthrough/**
scripts/run_sanity_tests.m
tests/sanity/**
validation/manifests/casas_lite_breakthrough.md
docs/KNOWN_UNCERTAINTIES.md only if implementation approximations are recorded
```

### Forbidden files

```text
1_config/
2_run/
3_source/
4_example/
5_reference/
6_publication/
cases/schell_2bed_validation/
cases/delgado_layered_extension/
params/schell2013_ap360_sips_binary/
params/delgado2014_bpl13x_lf_four_component/
```

### Required implementation

Add a Casas case builder and runner, for example:

```text
cases/casas_lite_breakthrough/build_casas_lite_breakthrough_case.m
cases/casas_lite_breakthrough/run_casas_lite_breakthrough_sanity.m
```

The case builder must:

1. Load only `params/casas2012_ap360_sips_binary/`.
2. Use `model_mode = topsail_native`.
3. Configure a single AP3-60 column with `L = 1.20 m` and `Ri = 0.0125 m`.
4. Use `feed_y = [CO2 0.5, H2 0.5]`, `T = 298.15 K`, `P = 15 bar`.
5. Use the source `10 cm3/s` feed flow only through a documented toPSAil mapping.
6. Use fitted LDF constants `k_CO2 = 0.15 s^-1` and `k_H2 = 1.0 s^-1`.
7. Use the Casas Sips parameter pack.
8. Use the Casas heats of adsorption, not Schell values.
9. Set or document wall heat transfer using `hW = 5 J/(m2 s K)` and `C_w = 4.0e6 J/(m3 K)` if the toPSAil interface supports it.
10. Record whether He initial gas is represented natively, approximated, or omitted.
11. Extract outlet composition and axial bed temperature profiles if available.

The first sanity run should be deliberately short or simple enough to catch setup failures without becoming a full validation run. Examples:

- one adsorption/breakthrough step for a limited time;
- a shortened breakthrough run sufficient to see H2 begin to leave;
- a dry-run build plus one solver call if full breakthrough is too expensive.

### Required Tier 3 checks

Add sanity checks for:

1. MATLAB run completes.
2. No NaN or Inf.
3. Positive absolute pressure.
4. Positive absolute temperature.
5. Mole fractions remain within `[0, 1]` within numerical tolerance.
6. Mole fractions sum to 1 within tolerance where reported.
7. Flow direction is sensible for an adsorption feed step.
8. CO2 adsorbs more strongly than H2 under the reference mixture.
9. A temperature response exists if thermal mode is enabled.
10. Mass-balance residuals, if available, are reported but not tuned.

Required command:

```matlab
addpath(genpath(pwd));
run("scripts/run_sanity_tests.m");
```

### Pass criteria

- Tier 0 smoke still passes.
- Tier 1 source tests pass.
- Tier 2 equation tests pass.
- Tier 3 Casas sanity test passes.
- No toPSAil core files changed.
- No Tier 4 validation thresholds are changed merely to pass sanity.

### Stop conditions

Stop if:

- the case cannot be built without core edits;
- the feed-flow conversion is ambiguous and materially affects the case;
- He initialisation cannot be represented and the manifest has not authorised a binary approximation;
- pressure, temperature, or mole fractions fail hard checks;
- a Schell or Delgado parameter is required to proceed.

## Task 2.5: Run Casas-lite Tier 4 breakthrough validation and report

### Task ID

`casas-breakthrough-validation-report`

### Goal

Run the full Casas-lite reference breakthrough case and generate a validation report comparing hard health checks and approximate breakthrough/thermal behaviour to the source-reference sheet.

### Allowed files

```text
cases/casas_lite_breakthrough/**
validation/manifests/casas_lite_breakthrough.md
validation/reports/**
scripts/run_casas_lite_breakthrough_validation.m
docs/KNOWN_UNCERTAINTIES.md only if unresolved model gaps are recorded
```

### Forbidden files

```text
1_config/
2_run/
3_source/
4_example/
5_reference/
6_publication/
cases/schell_2bed_validation/
cases/delgado_layered_extension/
params/schell2013_ap360_sips_binary/
params/delgado2014_bpl13x_lf_four_component/
```

### Required implementation

Add a validation runner such as:

```text
scripts/run_casas_lite_breakthrough_validation.m
```

This runner must not be called by `scripts/run_smoke.m`.

The validation run must report:

```text
source_reference_file = docs/source_reference/01_casas_2012_breakthrough_validation.md
parameter_pack = params/casas2012_ap360_sips_binary
model_mode = topsail_native | source_reproduction | diagnostic
source_values_changed = yes/no
validation_thresholds_changed = yes/no
known_omissions = detector piping, exact axial dispersion/front shape, He handling, wall model approximation if any
grid/cell count = <value>
run time = <value>
solver status = <value>
H2 breakthrough time = <computed or unavailable>
CO2 breakthrough time = <computed or unavailable>
thermal response = <computed or unavailable>
mass-balance residual = <computed or unavailable>
hard checks = pass/fail
soft target comparison = narrative, not tuning instruction
```

### Required comparison targets

Hard checks:

- MATLAB completes.
- No NaN or Inf.
- Positive absolute pressure.
- Positive absolute temperature.
- Valid mole fractions.
- Source parameter pack matches source tests.

Soft targets:

- H2 breakthrough about 110 s.
- H2 outlet mole fraction rises near 110-130 s.
- CO2 breakthrough roughly 430-460 s by plot-read, if computed.
- Outlet composition approaches 50/50 feed after the front and thermal tail settle.
- Small H2 heat front precedes larger CO2 heat front through thermocouple positions.

### Required tests before validation report is accepted

Run, in this order:

```matlab
addpath(genpath(pwd)); run("scripts/run_smoke.m");
addpath(genpath(pwd)); run("scripts/run_source_tests.m");
addpath(genpath(pwd)); run("scripts/run_equation_tests.m");
addpath(genpath(pwd)); run("scripts/run_sanity_tests.m");
addpath(genpath(pwd)); run("scripts/run_casas_lite_breakthrough_validation.m");
```

### Pass criteria

The first Casas-lite validation is acceptable if:

- all hard checks pass;
- source tests confirm parameters were not altered;
- the report states whether soft targets are close, early, late, or unavailable;
- no source constants were tuned;
- no validation thresholds were weakened;
- no core files were changed.

The validation may still be scientifically imperfect. Imperfection is allowed. Silent curve-fitting is not.

### Stop conditions

Stop if:

- hard checks fail;
- validation mismatch has multiple plausible causes;
- Codex would need to tune source constants;
- Codex would need to change boundary-condition internals;
- Codex would need to include detector piping, exact axial dispersion, or a Schell-style boundary mode to make the result pass;
- a validation threshold would need to be invented or weakened.

## Task 2.6: Optional core-edit gate, only if wrappers cannot work

### Task ID

`casas-core-edit-gate`

### Goal

Decide whether a narrowly scoped toPSAil core adapter is genuinely required for Casas-lite.

### Allowed files

None unless a later human-approved task explicitly lists the exact core files.

### Trigger condition

This task is only reached if Task 2.1, 2.3, or 2.4 proves that toPSAil cannot accept the required Casas equilibrium, kinetics, thermal, or single-column setup through wrappers, parameter files, or case scripts.

### Required evidence before authorising any core edit

Codex must provide:

1. The exact missing interface.
2. The core file that would need a change.
3. Why a wrapper cannot solve it.
4. The smallest adapter-only change.
5. The tests that would prove existing examples still run.
6. The rollback plan.
7. Confirmation that the edit is not a boundary-condition rewrite, solver rewrite, or validation-tuning change.

### Required response

Stop and report. Do not edit core in this task.

---

# Expected branch and commit sequence

Use small branches:

```text
codex/baseline-readonly-audit          # no commit expected
codex/baseline-smoke-runner            # commit smoke runner only
codex/casas-readonly-implementation    # no commit expected
codex/casas-parameter-pack             # commit parameter pack + Tier 1 tests
codex/casas-equation-tests             # commit local equations + Tier 2 tests
codex/casas-one-column-sanity          # commit case wrapper + Tier 3 tests
codex/casas-breakthrough-validation    # commit validation runner/report only if requested
```

Suggested commits:

```text
Add Tier 0 toPSAil baseline smoke runner
Add Casas 2012 AP3-60 parameter pack and source tests
Add Casas 2012 Sips and LDF equation tests
Add Casas-lite one-column breakthrough sanity case
Add Casas-lite breakthrough validation runner and report
```

Do not combine these into one commit. Humans already invented merge conflicts; no need to feed them.

# Final Codex report template

Every task must end with:

```text
task objective =
files inspected =
files changed =
commands run =
tests passed =
tests failed =
unresolved uncertainties =
toPSAil core files changed = yes/no
validation numbers changed = yes/no
source_reference_file = <if applicable>
parameter_pack = <if applicable>
model_mode = <if applicable>
known_omissions = <if applicable>
next smallest recommended task =
```

# What success looks like

At the end of Phase 1:

- An original toPSAil example runs.
- `scripts/run_smoke.m` repeats that run.
- The default smoke suite contains only Tier 0 baseline work.
- The toPSAil core remains unchanged.

At the end of Phase 2:

- The Casas AP3-60 parameter pack exists and is source-tested.
- The Casas Sips/LDF local equations or native mappings are equation-tested.
- A Casas-lite one-column breakthrough wrapper runs through toPSAil-native machinery.
- A validation report compares hard health checks and soft breakthrough/thermal targets.
- No Schell, Delgado, or thesis optimisation assumptions have leaked into the Casas case.
- No physical constants have been tuned to rescue a plot.
