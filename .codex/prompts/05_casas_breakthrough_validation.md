Codex Task 02: Casas 2012 Breakthrough Validation
Objective

Implement the Casas 2012 AP3-60 CO2/H2 breakthrough validation as a project-specific validation case, using native toPSAil machinery wherever possible.

This task is Phase 2 only.

Do not begin this task unless the Phase 1 baseline toPSAil smoke test has passed.

Required reading before doing anything

Read these files first:

AGENTS.md
docs/workflow/codex_baseline_and_casas_execution_plan.md
docs/source_reference/00_source_reference_index.md
docs/source_reference/01_casas_2012_breakthrough_validation.md
docs/source_reference/05_transcription_audit_and_guardrails.md
docs/MODEL_SCOPE.md
docs/BOUNDARY_CONDITION_POLICY.md
docs/THERMAL_MODEL_POLICY.md
docs/VALIDATION_STRATEGY.md
docs/TEST_POLICY.md
docs/KNOWN_UNCERTAINTIES.md

Follow the principles, gates, and stop conditions in those files.

Scope

You may:

add a Casas 2012 AP3-60 parameter pack;
add source-transcription tests;
add equation-local tests for the Casas competitive Sips isotherm and LDF kinetics;
add a one-column Casas-lite breakthrough case wrapper;
add physical sanity checks;
add a Casas-lite breakthrough validation runner;
produce a validation report.

You may not:

begin Schell PSA validation;
begin Delgado layered-bed work;
begin optimisation;
begin sensitivity studies;
tune Casas source constants to improve agreement;
weaken validation thresholds to force a pass;
silently replace native toPSAil physics with new physics;
alter toPSAil solver internals unless the audit proves there is no wrapper-level route and the reason is documented first.
Required preflight checks

Before editing anything, report the output of these commands:

git status --short
git branch --show-current
git remote -v

Confirm that the Phase 1 smoke runner exists:

scripts/run_smoke.m

Run or inspect the latest baseline result. If the original toPSAil baseline has not passed, stop.

Source basis

Use this as the controlling source-reference file:

docs/source_reference/01_casas_2012_breakthrough_validation.md

Use this as the controlling audit and ambiguity file:

docs/source_reference/05_transcription_audit_and_guardrails.md

Do not search the PDFs directly unless explicitly required by one of the source-reference files or unless a transcription ambiguity blocks implementation.

If PDF lookup is required, document exactly what was checked and why.

Required implementation sequence

Proceed in this order.

Step 1: Casas implementation audit

Before writing code, identify:

where toPSAil defines adsorbent and material parameters;
where gas and component definitions are configured;
where isotherms are implemented;
where mass-transfer kinetics are implemented;
where column geometry is configured;
where feed and boundary conditions are configured;
where breakthrough or one-column simulations can be represented;
where outputs are generated;
whether native toPSAil can represent the Casas case without solver edits.

Stop and report if native toPSAil cannot represent the case without major core modification.

Step 2: Add Casas parameter pack

Create a project-specific parameter pack under:

params/casas2012_ap360_sips_binary/

The pack must contain the Casas AP3-60 values from:

docs/source_reference/01_casas_2012_breakthrough_validation.md

The parameter pack must clearly separate:

geometry;
adsorbent properties;
gas properties;
isotherm parameters;
kinetic parameters;
thermal parameters;
operating conditions;
initial conditions;
validation targets;
known approximations.

Do not hard-code these values directly inside solver logic.

Step 3: Add Tier 1 source-transcription tests

Create source-transcription tests under:

tests/source/

These tests must verify that loaded Casas parameters match the source-reference values exactly or within explicit unit-conversion tolerance.

Include checks for:

L
Ri
Ro
eps_b
eps_t
rho_b
rho_p
dp
a_p
Cs
Cw
Dm
DeltaH_CO2
DeltaH_H2
k_CO2
k_H2
hW
eta1
eta2
feed composition
temperature
pressure
feed flow
initial gas

Add a runner if needed:

scripts/run_source_tests.m
Step 4: Add Tier 2 equation-local tests

Create equation-local tests under:

tests/equations/

Test the Casas competitive Sips isotherm and LDF kinetics independently from the full column simulation.

The tests must check:

finite outputs;
non-negative loadings;
CO2 loads more strongly than H2 under reference conditions;
loading increases with pressure at fixed composition and temperature;
loading changes sensibly with temperature;
LDF rate has the correct sign;
LDF rate is zero at equilibrium.

Add or extend a runner if needed:

scripts/run_equation_tests.m
Step 5: Add Casas-lite breakthrough case

Create the case under:

cases/casas_lite_breakthrough/

The first case should represent the reference breakthrough experiment:

adsorbent: AP3-60 activated carbon
feed: 50 mol% CO2 / 50 mol% H2
temperature: 298.15 K
pressure: 15 bar
feed flow: 10 cm3/s
initial gas: He
model mode: topsail_native

Use native toPSAil pressure-flow, boundary-condition, thermal, and solver machinery wherever possible.

If He initialisation cannot be represented natively, document the approximation before proceeding.

Step 6: Add Tier 3 physical sanity tests

Create sanity tests under:

tests/sanity/

The sanity tests must check:

no NaN values;
no Inf values;
positive pressure;
positive temperature;
valid mole fractions between 0 and 1;
component mole fractions sum sensibly;
non-negative adsorbed loadings;
physically plausible breakthrough ordering;
CO2 retention relative to H2;
mass-balance diagnostics if available.

Add a runner if needed:

scripts/run_sanity_tests.m
Step 7: Add Tier 4 Casas-lite validation runner

Create:

scripts/run_casas_lite_breakthrough_validation.m

The validation runner must:

load the Casas parameter pack;
build the Casas-lite one-column case;
run the simulation;
collect outlet composition and relevant temperature outputs;
compare against the validation targets in the source-reference file;
classify checks as hard checks or soft validation checks;
write a validation report.

The validation report should go under:

validation/reports/

The validation manifest should go under:

validation/manifests/casas_lite_breakthrough.md
Validation philosophy

Hard checks fail the task:

NaN values;
Inf values;
negative pressure;
negative temperature;
invalid mole fractions;
negative loadings;
simulation crash;
obvious broken breakthrough direction.

Soft validation checks should report agreement or mismatch without forcing parameter tuning:

breakthrough timing;
front shape;
CO2/H2 ordering;
temperature excursion;
qualitative trend against Casas reference case.

Do not tune source constants to improve agreement.

Do not weaken checks to make the validation pass.

Required final report

At the end, report:

files changed;
tests added;
commands run;
source-reference files used;
assumptions made;
approximations introduced;
whether toPSAil core files were edited;
validation result;
remaining blockers or uncertainties.
Required final checks

Before finishing, run:

git status --short

Then report all changed files.

Stop condition

Stop after the Casas-lite breakthrough validation runner and report exist, or after a blocker has been documented.

Do not continue into Schell, Delgado, sensitivity, or optimisation work.