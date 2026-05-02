# Batch 2 implementation guide: H2/CO2 activated-carbon surrogate parameter pack

## Assignment

You are implementing **Batch 2** of the final four-bed toPSAil implementation. This batch covers:

- **FI-2 H2/CO2 AC parameter pack**: create the Yang-inspired binary H2/CO2 homogeneous activated-carbon surrogate case and parameter package.

You are working in parallel with another Codex agent implementing **Batch 1**, schedule finalisation and physical-state persistence cleanup. You are not working alone in the codebase. Keep your changes narrow, and do not modify Batch 1 files unless absolutely unavoidable and explicitly justified in your final handoff.

## Important project reset

The old WP1-WP5 work-package documents are no longer the active implementation instructions. They are legacy artifacts from the previous planning phase. Existing files, tests, comments, and docs may still use names like `WP1`, `WP3`, or `WP5`, but those labels must not determine your scope.

Use this guide and `docs/four_bed/FINAL_IMPLEMENTATION_CONTEXT.md` as the authority. Do not follow older guidance files such as:

- `docs/four_bed/WP Archive/WP1_yang_schedule_manifest.md`
- `docs/four_bed/WP Archive/WP2_direct_transfer_pair_map.md`
- `docs/four_bed/WP Archive/WP3_persistent_four_bed_state_container*.md`
- `docs/four_bed/WP Archive/WP4_temporary_case_builder*.md`
- `docs/four_bed/WP Archive/WP5_ledger_css_reporting*.md`
- `.codex/prompts/05_yang_wp1_schedule_manifest.md`
- `docs/workflow/Work package guidance docs/*`

Do not delete these files just because they are old. Treat them as historical context only. Your implementation is FI-2, not a continuation of old WP1-WP5 planning.

## Scope boundaries

### You own

Create a parameter/case package for the final Yang surrogate. Recommended new paths:

- `params/yang_h2co2_ac_surrogate/buildYangH2Co2AcTemplateParams.m`
- `params/yang_h2co2_ac_surrogate/testYangAcDslMapping.m`
- `params/yang_h2co2_ac_surrogate/yangH2Co2AcSurrogateConstants.m`, optional but recommended
- `cases/yang_h2co2_ac_surrogate/case_spec.md`
- Tests under `tests/four_bed/`, for example:
  - `testYangH2Co2AcParameterPack.m`
  - `testYangAcDslMappingSmoke.m`

You may also add small README files under the new `params/yang_h2co2_ac_surrogate/` and `cases/yang_h2co2_ac_surrogate/` folders if repository style supports it.

### You must not own

Do not implement or materially change:

- `scripts/four_bed/getYangFourBedScheduleManifest.m`
- `scripts/four_bed/getYangNormalizedSlotDurations.m`
- `scripts/four_bed/extractYangPhysicalBedState.m`
- `scripts/four_bed/extractYangCounterTailDeltas.m`
- `scripts/four_bed/extractYangTerminalLocalStates.m`
- `scripts/four_bed/writeBackYangFourBedStates.m`
- `scripts/four_bed/computeYangFourBedCssResiduals.m`
- Custom PP->PU adapter code.
- Custom AD&PP->BF adapter code.
- Full four-bed cycle driver code.
- Ledger extraction, audit export, or external-basis performance metrics.
- Core toPSAil adsorber mass, energy, momentum, isotherm, or RHS files.

If you need a schedule duration in a test, use a local constant and do not depend on Batch 1. If Batch 1 has not landed yet, your batch should still be testable.

## Model target

Create a **Yang-inspired, four-bed H2/CO2 homogeneous activated-carbon surrogate**.

This is not a full Yang reproduction. The first final implementation deliberately excludes:

- Zeolite 5A.
- Layered beds.
- CO.
- CH4.
- Pseudo-impurity components.
- Inert placeholder components.
- Dynamic internal tanks or shared header inventory.
- A global four-bed RHS/DAE.
- Core adsorber-physics rewrites.

The parameter pack should make this explicit in metadata and case documentation, because otherwise someone will later compare it to Yang's 99.999% H2 layered four-component results and declare victory, as if labels and reality have ever been on speaking terms.

## Required surrogate basis

### Components

Use exactly two components in this order:

```matlab
componentNames = ["H2"; "CO2"];
componentOrder = ["H2"; "CO2"];
nComs = 2;
```

The component order is part of the handoff contract. Do not reverse it.

### Feed composition

Yang reports feed gas containing H2, CO2, CO, and CH4. For this surrogate, keep only H2 and CO2 and renormalise them:

```matlab
y_H2  = 72.2 / (72.2 + 21.6);   % 0.7697228145...
y_CO2 = 21.6 / (72.2 + 21.6);   % 0.2302771855...
feedMoleFractions = [y_H2; y_CO2];
```

Required numeric values:

```matlab
feedMoleFractions = [0.7697228145; 0.2302771855];
```

Use enough precision that the sum is one within a tight tolerance. Do not include CO or CH4 as zero components. Do not add an inert component.

### Adsorbent and bed

Use homogeneous activated carbon across the model bed.

Default geometry policy:

- Use the full Yang vessel geometry as the model bed geometry.
- Do not shorten the default model to the original activated-carbon layer length.
- Record that this is a deliberate homogeneous surrogate.

Recommended constants to encode as source metadata and defaults:

| Quantity | Value | Notes |
|---|---:|---|
| Full bed length | `170 cm` | Yang column has 100 cm activated carbon plus 70 cm zeolite; surrogate fills full vessel with AC. |
| Activated-carbon layer length | `100 cm` | Metadata only for this first implementation. |
| Inside diameter | `3.84 cm` | Yang vessel. |
| Outside diameter | `4.86 cm` | Yang vessel. |
| Activated-carbon pellet size | `1.15 mm` | Convert to repository units if needed. |
| Activated-carbon pellet density | `0.85 g/cm^3` | Convert to kg/cm^3 or kg/m^3 according to toPSAil convention. |
| Activated-carbon adsorbent bulk density | `0.482 g/cm^3` | Keep source note. |
| Activated-carbon bed/external void fraction | `0.433` | Use for `voidFracBed` unless repository conventions demand a different field. |
| Activated-carbon heat capacity | `0.25 cal/g/K` | Convert to SI if toPSAil expects SI. |
| Column heat capacity | `0.12 cal/g/K` | Convert if used. |
| Column density | `7.83 g/cm^3` | Convert if used. |
| Internal heat transfer coefficient | `0.0385 kJ/s/m^3/K` | Convert only if non-isothermal fields are populated. |
| External heat transfer coefficient | `0.0142 kJ/s/m^3/K` | Convert only if non-isothermal fields are populated. |

The exact parameter field names must match the repository's toPSAil parameter conventions. Do not invent fields that the model will ignore without also putting them under clearly named `yangBasis` or `surrogateMetadata`.

### Pressure anchors

Source pressure anchors:

```matlab
PF = 9.0;   % atm, adsorption/feed pressure
P4 = 1.3;   % atm, lowest purge/blowdown pressure
```

Intermediate pressure classes `P1`, `P2`, `P3`, `P5`, and `P6` should remain symbolic or metadata unless the repository already has a clean way to assign them. Do not fabricate numeric intermediate pressures.

### Isotherm model

Use native toPSAil extended dual-site Langmuir-Freundlich machinery where possible:

```matlab
modSp(1) = 6;
nSiteOneC = [1; 1];
nSiteTwoC = [1; 1];
```

This represents Yang-style dual-site Langmuir behaviour without Freundlich curvature.

Activated-carbon DSL parameters in source order `[H2; CO2]`:

| Component | Site 1 q_m | Site 1 B(T) | Site 2 q_m | Site 2 B(T) | Heat |
|---|---:|---:|---:|---:|---:|
| H2 | source table `2.40E-5`; active runtime `2.40E-2 mol/kg` after 1000x loading-capacity conversion | `9.0E-4 exp(1700/T) 1/atm` | source table `4.80E-4`; active runtime `4.80E-1 mol/kg` after 1000x loading-capacity conversion | `6.0E-5 exp(1915/T) 1/atm` | `1800 cal/mol` |
| CO2 | source table `8.00E-3`; active runtime `8.00 mol/kg` after 1000x loading-capacity conversion | `8.0E-6 exp(3100/T) 1/atm` | source table `1.40E-3`; active runtime `1.40 mol/kg` after 1000x loading-capacity conversion | `9.6E-7 exp(4750/T) 1/atm` | `5900 cal/mol` |

Important conversion note:

- The earlier direct mol/kg transcription made the active capacities 1000x too
  small. The parameter pack now retains the source table values as metadata
  and applies the 1000x loading-capacity conversion for runtime `mol/kg`.
- The affinity constants are given in `1/atm` with exponential factors in Kelvin.
- toPSAil may internally expect pressure in bar or dimensionless concentration scaling. Follow the existing toPSAil parameter conversion path rather than forcing dimensional DSL values directly into the isotherm evaluator.

### Temperature-dependence caveat

The native toPSAil extended dual-site LF route may not exactly reproduce Yang's site-specific temperature dependence. The first pass may be acceptable for isothermal or reference-temperature use, but you must add a point-test script that compares:

1. Direct Yang DSL loading for H2/CO2 using the source formulas.
2. The configured toPSAil native isotherm at the same pressure, temperature, and gas composition.

Do not modify core adsorber balances to fix a mapping mismatch. If the native mapping fails the agreed tolerance, add a small, isolated Yang-specific DSL equilibrium wrapper or record the mismatch for follow-up. Do not silently bury the mismatch.

## Required functions

### `buildYangH2Co2AcTemplateParams.m`

Recommended signature:

```matlab
function params = buildYangH2Co2AcTemplateParams(varargin)
```

Recommended options:

```matlab
'Isothermal', true
'PressureDropModel', "existing_default"
'NVols', 10
'NCycles', 1
'NSteps', 10
'FeedVelocityCmSec', []
'CycleTimeSec', []
'SolverTolerances', struct(...)
```

Do not let `CycleTimeSec` drive schedule duration calculation. That belongs to Batch 1. It may be stored as metadata or passed through as a run input, but this function should not call or reimplement schedule normalisation.

Required returned fields or metadata:

- `params.nComs = 2`
- Component names/order `["H2"; "CO2"]` under whatever field names are idiomatic in the repository.
- Feed composition `[0.7697228145; 0.2302771855]`.
- Homogeneous activated-carbon surrogate metadata.
- Full-vessel geometry default.
- Native DSL configuration with `modSp(1) = 6`.
- `nSiteOneC = [1;1]`, `nSiteTwoC = [1;1]`.
- Activated-carbon q-saturation, affinity, and heat-of-adsorption values in toPSAil-compatible units.
- Enough state-size fields to interoperate with Batch 1 tests and later temporary case builders: `nComs`, `nVols`, `nStates`, `nColSt`, `nColStT` after the appropriate existing parameter functions have run.
- Metadata flags:
  - `h2co2Renormalized = true`
  - `acOnlyHomogeneous = true`
  - `zeolite5AIncluded = false`
  - `layeredBedEnabled = false`
  - `coIncluded = false`
  - `ch4Included = false`
  - `pseudoImpurityIncluded = false`
  - `noDynamicInternalTanks = true`

Follow the existing toPSAil parameter construction style. If the repository normally builds params by reading spreadsheets, this builder may assemble the required fields programmatically and then call existing `get*Params` helpers. Avoid GUI or macro dependencies.

### `yangH2Co2AcSurrogateConstants.m` optional

A constants function is recommended to keep source values cleanly separated from toPSAil conversion logic:

```matlab
function basis = yangH2Co2AcSurrogateConstants()
```

Recommended contents:

- Component order.
- Raw Yang feed composition and binary-renormalised composition.
- Geometry values.
- Activated-carbon physical properties.
- DSL source parameters.
- Source notes and unit notes.

This function should not call the solver.

### `testYangAcDslMapping.m`

Recommended signature:

```matlab
function report = testYangAcDslMapping(varargin)
```

Required behaviour:

- Build or accept the parameter pack.
- Evaluate direct Yang DSL for a small grid of points.
- Evaluate native toPSAil DSL at the same points.
- Return a report struct/table with residuals.
- Fail or flag when residuals exceed tolerance.
- Clearly state whether the report validates only isothermal/reference-temperature mapping or a broader temperature range.

Suggested grid:

```matlab
temperaturesK = [293.15, 303.15, 323.15];
pressuresAtm = [1.3, 3.0, 9.0];
yGrid = [
    0.7697228145, 0.2302771855
    0.95,         0.05
    0.50,         0.50
];
```

Direct Yang DSL formula for component `i`:

```matlab
q_i = qmi1_i * B1_i(T) * P * y_i / (1 + sum_k B1_k(T) * P * y_k) + ...
      qmi2_i * B2_i(T) * P * y_i / (1 + sum_k B2_k(T) * P * y_k);
```

Use `P` in atm when applying the source formula. Convert only when evaluating native toPSAil if native expects another basis.

The point test should be deterministic and should not require a full PSA cycle.

## Case documentation

Create:

```text
cases/yang_h2co2_ac_surrogate/case_spec.md
```

It should state:

- This is a Yang-inspired H2/CO2 homogeneous activated-carbon surrogate.
- It is not a full Yang reproduction.
- Feed is renormalised over H2/CO2 only.
- Full Yang vessel geometry is used by default with homogeneous AC.
- Zeolite 5A, CO, CH4, pseudo-impurity components, and layering are excluded.
- Native DSL is used with site exponents set to one.
- The DSL temperature-dependence caveat and point-test requirement.
- The schedule duration policy is owned by Batch 1 and not implemented here.
- Direct coupling adapters are owned by later batches and not implemented here.

Keep this documentation factual. Do not put old WP sequencing language into the new case spec.

## Tests to add or update

Add a parameter-pack static test, for example:

```matlab
function testYangH2Co2AcParameterPack()
    params = buildYangH2Co2AcTemplateParams('NVols', 2);
    assert(params.nComs == 2);
    assert(params.modSp(1) == 6);
    assert(isequal(params.nSiteOneC(:), [1; 1]));
    assert(isequal(params.nSiteTwoC(:), [1; 1]));
    assert(abs(sum(params.feedMoleFractions) - 1) < 1e-12);
    assert(abs(params.feedMoleFractions(1) - 0.7697228145) < 1e-10);
    assert(abs(params.feedMoleFractions(2) - 0.2302771855) < 1e-10);
    assert(params.yangBasis.h2co2Renormalized);
    assert(params.yangBasis.acOnlyHomogeneous);
    assert(~params.yangBasis.zeolite5AIncluded);
    assert(~params.yangBasis.layeredBedEnabled);
end
```

Adjust field names to match the builder. The test should verify the contract, not a particular private implementation detail.

Add a DSL point-test smoke test, for example:

```matlab
function testYangAcDslMappingSmoke()
    report = testYangAcDslMapping('Tolerance', 1e-8);
    assert(isfield(report, 'pass'));
    assert(report.pass || isfield(report, 'maxResidual'));
end
```

Name the test differently from the parameter-pack point-test function so MATLAB does not have to guess which identical function name humans meant this time.

If native mapping cannot meet a strict tolerance because of toPSAil's temperature-dependence structure, do not fake a pass. Make the report explicit, and choose a conservative acceptance for the isothermal/reference-temperature first surrogate. A report that honestly fails a non-isothermal comparison is more useful than a false green light.

## Parallel coordination with Batch 1

Batch 1 owns schedule and state persistence. You should not depend on those changes.

Shared assumptions you may use:

- Component order is `[H2; CO2]`.
- Persistent bed state length will eventually be `params.nColSt`, not `params.nColStT`.
- Later direct-coupling and cycle-driver work will consume a two-bed or single-bed template params structure.

Your deliverable should make it easy for Batch 1 and later batches to do this:

```matlab
params = buildYangH2Co2AcTemplateParams('NVols', 10);
assert(params.nComs == 2);
assert(params.nColSt < params.nColStT);
```

Do not call Batch 1 schedule helpers. Do not change Batch 1 tests.

## Handoff requirements

At the end of your work, provide a concise handoff containing:

1. Files changed or added.
2. How to build the parameter pack.
3. Exact component order.
4. Exact feed composition.
5. Geometry and adsorbent assumptions.
6. Native DSL mapping details and any unit conversions.
7. DSL point-test results and tolerance.
8. Whether native toPSAil DSL mapping is accepted for isothermal/reference-temperature use.
9. Any known mismatch that should be tracked before non-isothermal claims.
10. Tests run and their results.

## Acceptance criteria

This batch is complete only if:

- A programmatic H2/CO2 AC surrogate params builder exists.
- The builder does not depend on the Excel GUI or macros.
- Feed composition is exactly the binary-renormalised H2/CO2 basis.
- No CO, CH4, pseudo-impurity, zeolite 5A, or layered-bed default is introduced.
- Full Yang vessel geometry with homogeneous AC is the default.
- Native DSL configuration uses `modSp(1) = 6` and unit site exponents.
- A direct Yang DSL versus native mapping point-test exists.
- Case documentation states the surrogate limitations clearly.
- No Batch 1 schedule/state files are modified.
- No custom adapters, full cycle driver, ledger, dynamic tanks, global four-bed RHS/DAE, or core adsorber-balance edits are introduced.
