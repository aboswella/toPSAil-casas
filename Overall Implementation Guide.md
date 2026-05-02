# Fast Ribeiro implementation plan for fresh Codex agents

## Decision: build Ribeiro from fresh native toPSAil, not from the Yang branch

Use a fresh branch from `develop`. Treat the current `codex/ribeiro` / Yang branch as a reference archive only.

The fastest path is **not** to port the Yang four-bed wrapper layer. Ribeiro’s cycle is compatible enough with native toPSAil that the first implementation should be a **direct native four-column schedule** with a thin programmatic parameter builder and a small postprocessing layer.

The Ribeiro paper uses a four-column PSA arrangement with continuous feed and an eight-step per-column cycle: feed, pressure equalization depressurization 1, pressure equalization depressurization 2, blowdown, purge, pressure equalization pressurization 1, pressure equalization pressurization 2, and pressurization. The paper’s Fig. 2 and Fig. 3 define this cycle and the four-column timing relationships, including `tcycle = 4*tfeed`, `tD1 = tD2 = tP1 = tP2 = tpres = tfeed/2`, and `tblowd = tpurge = tfeed/4` .

That timing means the logical cycle is eight steps per bed, but the native global schedule should be split into **16 native time slots** so that feed, equalization, blowdown, purge, and pressurization transitions line up across four beds.

## Local source inventory and bootstrap consistency

The local `sources/` folder currently contains:

```text
sources/Ribeiro 2008.pdf
sources/Yang 2009 4-bed 10-step relevant.pdf
sources/Yang Scripts FOR REFERENCE ONLY/
```

Use `sources/Ribeiro 2008.pdf` as the source of truth for the Ribeiro cycle, baseline operating conditions, feed composition, performance equations, and activated-carbon H2/CO2 adsorption parameters used by this minimal surrogate. Use `sources/Yang 2009 4-bed 10-step relevant.pdf` and `sources/Yang Scripts FOR REFERENCE ONLY/` only as reference-only examples for native toPSAil schedule/runtime patterns and Yang-specific cautionary ideas. Do not import Yang cycle labels, adapters, ledgers, diagnostics, or wrapper architecture into the Ribeiro implementation.

This branch is intentionally minimal and does not yet contain the `docs/`, `params/`, `scripts/ribeiro_surrogate/`, `cases/`, `validation/`, or `tests/` project folders. Batch 0 should create only the active Ribeiro folders named below. The older project-control docs referenced by prior Yang guidance are not present on this branch, so this guide and the local source files are the active bootstrap context until those docs are recreated.

The source-backed Ribeiro baseline values available in the local PDF are:

```text
Ribeiro source: sources/Ribeiro 2008.pdf, Fig. 2, Fig. 3, Table 4, Table 5, and Eqs. 2-4
Cycle: 4 columns, 8 logical steps per column, tcycle = 4*tfeed
Durations: tD1 = tD2 = tP1 = tP2 = tpres = tfeed/2; tblowd = tpurge = tfeed/4
Full source feed: H2/CO2/CH4/CO/N2 = 73.3/16.6/3.5/2.9/3.7 mol %
Binary H2/CO2 renormalized feed for this surrogate: [0.8153503893; 0.1846496107]
Discarded impurity fraction from the full feed: 0.101
Feed flow: 12.2 N m^3/h, about 0.1513 mol/s at 1 atm and 273.15 K
Feed pressure: 7 bar_abs
Purge/low pressure: 1 bar_abs
Feed temperature: 303 K
Column length: 1 m
Column diameter: 0.2 m
Bed porosity: 0.38
Activated-carbon particle density: 842 kg/m^3
Activated-carbon particle radius: 1.17e-3 m
Activated-carbon particle porosity: 0.566
```

Values formerly listed here as `[0.7048; 0.2952]`, `0.489 mol/s`, and `10 bara` are not supported by the current `sources/Ribeiro 2008.pdf` text extraction and are therefore not valid defaults for this branch. If those values come from another Ribeiro case, optimization run, notebook, table extraction, or user decision, add that evidence under `sources/ribeiro_surrogate/` before using them.

Missing source artifacts to add if the implementation should rely on them:

```text
sources/ribeiro_surrogate/alternate_basis_10bar_0489mols.md
  Required only if the intended default is still [0.7048; 0.2952], 0.489 mol/s, and 10 bar_abs.
  Include the source table/page, derivation, units, and whether pressure is bar_abs or barg.

sources/ribeiro_surrogate/source_table_extracts/
  Optional but recommended. Add machine-readable extracts of Ribeiro Table 4, Table 5, and Eqs. 2-4
  as CSV/Markdown if future agents should not re-extract values from the PDF.

sources/yang_h2co2_ac_surrogate/
  Required only if a future implementation deliberately uses prior Yang H2/CO2 AC constants or parameter
  builder/finalizer files. Expected files would include yangH2Co2AcSurrogateConstants.m,
  buildYangH2Co2AcTemplateParams.m, and finalizeYangH2Co2AcTemplateParams.m.
```

## Non-negotiable implementation strategy

Do this:

```text
fresh develop branch
programmatic Ribeiro params
native four-column toPSAil schedule
native runPsaCycle call
minimal Ribeiro summary script
minimal metrics postprocessor
```

Do not do this:

```text
no Yang PP/PU adapter
no Yang AD&PP/BF adapter
no Yang ten-step manifest
no Yang diagnostics
no generated test suite
no native toPSAil source rewrite unless absolutely blocked
```

The local Yang reference files are useful only for these concepts:

| Reuse idea                           | Local reference                                                                                 | How to reuse                                                          |
| ------------------------------------ | ----------------------------------------------------------------------------------------------- | --------------------------------------------------------------------- |
| Runtime readiness checks             | `sources/Yang Scripts FOR REFERENCE ONLY/assertYangRuntimeTemplateReady.m`                       | Copy the idea of explicit required runtime fields, not Yang metadata  |
| Native step grammar                  | `sources/Yang Scripts FOR REFERENCE ONLY/prepareYangNativeLocalRunParams.m` and `translateYangNativeOperation.m` | Reuse mapping knowledge only                                          |
| Runtime time/schedule setup sequence | `sources/Yang Scripts FOR REFERENCE ONLY/prepareYangNativeLocalRunParams.m`                      | Reuse the downstream native setup-call order only                     |
| Metrics caution                      | `sources/Yang Scripts FOR REFERENCE ONLY/computeYangPerformanceMetrics.m`                        | Reuse external-feed / external-product caution, not Yang ledger code  |
| State persistence caution            | `sources/Yang Scripts FOR REFERENCE ONLY/writeBackYangFourBedStates.m`                           | Reference only if native schedule fallback becomes necessary          |

The prior Yang H2/CO2 AC parameter files named in older notes are **not** present locally. Do not depend on `params/yang_h2co2_ac_surrogate/buildYangH2Co2AcTemplateParams.m`, `finalizeYangH2Co2AcTemplateParams.m`, or `yangH2Co2AcSurrogateConstants.m` unless they are supplied under `sources/yang_h2co2_ac_surrogate/`.

Do not reuse old cycle driver files unless the direct native schedule fails.

---

# Target implementation shape

## Active file tree

Create only these active files:

```text
AGENTS.md

docs/ribeiro_surrogate/
  IMPLEMENTATION_NOTES.md

params/ribeiro_surrogate/
  ribeiroSurrogateConstants.m
  buildRibeiroSurrogateTemplateParams.m
  finalizeRibeiroSurrogateTemplateParams.m

scripts/ribeiro_surrogate/
  buildRibeiroNativeSchedule.m
  applyRibeiroNativeSchedule.m
  runRibeiroSurrogate.m
  summarizeRibeiroRun.m
  computeRibeiroExternalMetrics.m
```

Optional only if needed:

```text
scripts/ribeiro_surrogate/debugRibeiroSchedule.m
```

Do **not** create `tests/`. Do **not** port the Yang tests.

## Canonical user command after implementation

The target usage should be:

```matlab
addpath(genpath(pwd));
out = runRibeiroSurrogate("NCycles", 20, "NVols", 8, "TFeedSec", 40);
disp(out.summary)
```

The first run can be small and crude. The goal is a working surrogate, not exact paper reproduction.

---

# Model scope for first implementation

## Included

```text
4 columns
8 logical steps per column
16 native global schedule slots
binary H2/CO2
feed y = [0.8153503893; 0.1846496107]  % H2/CO2 renormalized from Ribeiro Table 5
feed total molar flow = about 0.1513 mol/s from 12.2 N m^3/h
P_high = 7 bar_abs
P_low = 1 bara
activated carbon only
isothermal first
native toPSAil CSTR-in-series adsorber model
native toPSAil tanks
native toPSAil equalization
native toPSAil performance output plus explicit Ribeiro summary
```

## Excluded

```text
Yang 10-step cycle
AD&PP/BF live product splitting
PP/PU direct purge adapter
layered AC/zeolite bed
five-component feed
humid feed
water
full five-component multisite Langmuir model
full Ribeiro transport model
paper-exact validation
large test suite
```

Ribeiro’s paper studies a full five-component layered AC/zeolite PSA, but the first surrogate intentionally does not reproduce that. The paper states the full process involves H2/CO2/CH4/CO/N2, layered activated carbon/zeolite beds, and complete dynamic modeling, while this implementation is a simplified binary dry activated-carbon surrogate. The binary feed is explicitly the H2/CO2-only renormalization of the full Table 5 feed, not a paper-reported binary case.

---

# Batch 0 — Fresh branch setup and Yang quarantine

## Goal

Start from clean native toPSAil and prevent accidental continuation of Yang.

## Fresh Codex agent prompt

```text
You are implementing the simplified Ribeiro surrogate. Start from clean develop. Do not continue Yang. Do not port Yang tests. Do not modify native toPSAil core unless blocked.
```

## Commands

```bash
git switch develop
git pull --ff-only
git switch -c ribero-clean-minimal

git branch legacy/yang-wrapper-attempt codex/ribeiro || true
```

## Files to create or edit

```text
AGENTS.md
docs/ribeiro_surrogate/IMPLEMENTATION_NOTES.md
```

## Required `AGENTS.md` content

Keep it short:

```markdown
# Active task

Implement a minimal Ribeiro-style H2/CO2 PSA surrogate on native toPSAil.

## Rules

- Use native toPSAil machinery wherever possible.
- Do not implement Yang 2009.
- Do not port Yang custom adapters.
- Do not write tests unless explicitly requested.
- Do not modify native toPSAil core directories unless a blocker is proven.
- Native core directories are `1_config/`, `2_run/`, `3_source/`, `4_example/`, `5_reference/`, and `6_publication/`.
- New active Ribeiro files live under `params/ribeiro_surrogate/` and `scripts/ribeiro_surrogate/`.

## Target

- 4 columns.
- 8 logical steps per column.
- 16 native schedule slots.
- Binary H2/CO2.
- Feed composition `[0.8153503893; 0.1846496107]`, the H2/CO2-only renormalization of Ribeiro Table 5.
- Total molar feed flow about `0.1513 mol/s`, derived from Ribeiro Table 5 `12.2 N m^3/h`.
- Pressure basis `bara`.
- High pressure `7 bara`.
- Low pressure `1 bara`.
- Pure activated-carbon surrogate.
```

## Do not do

Do not move or clean the whole old branch in this batch. Starting fresh is the cleanup.

## Manual validation

Run:

```bash
git diff --name-status develop...HEAD
```

Expected new implementation changes after the source-prep commit should be tiny: `AGENTS.md` and one docs folder. The root implementation guide, `sources/`, and `.gitignore` source exceptions are prerequisite source-control context, not implementation code.

---

# Batch 1 — Ribeiro constants and source scope

## Goal

Create the source-of-truth constants for the simplified surrogate.

## Files to create

```text
params/ribeiro_surrogate/ribeiroSurrogateConstants.m
docs/ribeiro_surrogate/IMPLEMENTATION_NOTES.md
```

## Function: `ribeiroSurrogateConstants.m`

Signature:

```matlab
function basis = ribeiroSurrogateConstants()
```

Return a scalar struct with these fields:

```matlab
basis.version = "Ribeiro2008-H2CO2-AC-surrogate-constants-v1";
basis.sourceName = "Ribeiro et al. 2008, Chemical Engineering Science 63, 5258-5273";
basis.surrogateName = "simplified_ribeiro_h2co2_ac_surrogate";

basis.componentNames = ["H2"; "CO2"];
basis.componentOrder = ["H2"; "CO2"];
basis.nComs = 2;
basis.productComponent = "H2";

basis.feed.fullSourceComponentOrder = ["H2"; "CO2"; "CH4"; "CO"; "N2"];
basis.feed.fullSourceMoleFractions = [0.733; 0.166; 0.035; 0.029; 0.037];
basis.feed.discardedImpurityFraction = 0.101;
basis.feed.moleFractions = [0.8153503893; 0.1846496107];
basis.feed.moleFractionBasis = ...
    "H2/CO2 renormalized from Ribeiro Table 5 full five-component feed";
basis.feed.sourceFlowNm3Hr = 12.2;
basis.feed.totalMolarFlowMolSec = 0.1513;  % 12.2 N m^3/h at 1 atm and 273.15 K
basis.feed.pressureBarAbs = 7.0;
basis.feed.temperatureK = 303.0;

basis.pressure.basis = "bar_abs";
basis.pressure.highBarAbs = 7.0;
basis.pressure.lowBarAbs = 1.0;

basis.target.h2Purity = 0.9999;

basis.cycle.nBeds = 4;
basis.cycle.logicalStepLabels = [
    "FEED"
    "EQ_D1"
    "EQ_D2"
    "BLOWDOWN"
    "PURGE"
    "EQ_P1"
    "EQ_P2"
    "PRESSURIZATION"
];
basis.cycle.tFeedDefaultSec = 40.0;
basis.cycle.nativeSlotPolicy = "16_slots_using_tfeed_over_4_base_slot";
basis.cycle.nativeSlotDefaultSec = basis.cycle.tFeedDefaultSec / 4;

basis.adsorbent.name = "activated_carbon_surrogate";
basis.adsorbent.layeredBed = false;
basis.adsorbent.zeoliteIncluded = false;

basis.scope.binaryOnly = true;
basis.scope.humidFeed = false;
basis.scope.fullFiveComponentMultisiteLangmuirModel = false;
basis.scope.fullRibeiroReproduction = false;
```

## Adsorbent/isotherm parameters

Prefer source-backed Ribeiro Table 4 activated-carbon H2/CO2 values over old Yang surrogate constants. Native toPSAil has a multisite Langmuir isotherm path (`modSp(1) == 3`), so the first attempt should use the Ribeiro activated-carbon subset directly if it runs.

In `basis.adsorbent`, add:

```matlab
basis.adsorbent.parameterBasis = ...
    "Ribeiro Table 4 activated-carbon H2/CO2 subset; binary AC-only surrogate, not full layered five-component reproduction";
basis.adsorbent.source = "sources/Ribeiro 2008.pdf Table 4 and Table 5";
basis.adsorbent.multisiteLangmuir.componentOrder = ["H2"; "CO2"];
basis.adsorbent.multisiteLangmuir.qMaxMolKg = [23.565; 7.8550];
basis.adsorbent.multisiteLangmuir.a = [1.0; 3.0];
basis.adsorbent.multisiteLangmuir.kInfPaInv = [7.233e-11; 2.125e-11];
basis.adsorbent.multisiteLangmuir.heatOfAdsorptionKJMol = [12.843; 29.084];
basis.adsorbent.particlePorosity = 0.566;
basis.adsorbent.particleDensityKgM3 = 842;
basis.adsorbent.particleRadiusM = 1.17e-3;
```

Use old Yang H2/CO2 AC parameter values only if the source-backed Ribeiro multisite Langmuir path is blocked and the old Yang parameter pack has been added under `sources/yang_h2co2_ac_surrogate/`. Do not claim Yang constants are Ribeiro constants.

If a fallback Yang parameter pack is later supplied, salvage only:

```matlab
qSat values
affinity pre-exponentials
affinity exponents
heat of adsorption
bed porosity
particle density
bulk density
pellet size
gas constant
reference temperature pattern
```

Replace all source identity and operating-condition fields:

```text
sourceName
feed composition
pressure values
geometry comments
Yang-specific omitted-component notes
```

## Implementation notes document

Add a short note:

```markdown
This is not a full Ribeiro reproduction. Ribeiro’s full paper uses a five-component H2/CO2/CH4/CO/N2 feed, layered AC/zeolite beds, and a full dynamic non-isothermal model. This branch starts with a dry binary H2/CO2 activated-carbon surrogate for speed.
```

Cite in prose that the paper’s objective is high-purity hydrogen and the full study uses a five-component mixture and layered beds .

## Do not do

Do not build schedule yet.

## Manual validation

In MATLAB:

```matlab
addpath(genpath(pwd));
basis = ribeiroSurrogateConstants();
disp(basis.feed.moleFractions)
disp(sum(basis.feed.moleFractions))
disp(basis.pressure)
```

Expected:

```text
0.8153503893
0.1846496107
sum = 1
basis = bar_abs
high = 7
low = 1
```

---

# Batch 2 — Programmatic Ribeiro parameter builder

## Goal

Create an Excel-free native toPSAil parameter struct for the binary AC surrogate.

## Files to create

```text
params/ribeiro_surrogate/buildRibeiroSurrogateTemplateParams.m
params/ribeiro_surrogate/finalizeRibeiroSurrogateTemplateParams.m
```

## Reference from local sources

Use these as structural references only:

```text
sources/Yang Scripts FOR REFERENCE ONLY/assertYangRuntimeTemplateReady.m
sources/Yang Scripts FOR REFERENCE ONLY/prepareYangNativeLocalRunParams.m
sources/Yang Scripts FOR REFERENCE ONLY/translateYangNativeOperation.m
```

The old Yang parameter builder/finalizer/constants files are not present locally. Do not reference them unless they are added under `sources/yang_h2co2_ac_surrogate/`. Do not copy Yang names, source claims, cycle defaults, direct-coupling adapters, or ledger code.

## Function: `buildRibeiroSurrogateTemplateParams.m`

Signature:

```matlab
function params = buildRibeiroSurrogateTemplateParams(varargin)
```

Supported name-value inputs:

```matlab
"NVols"                 default 8
"NCols"                 default 4
"NCycles"               default 10
"NTimePoints"           default 2
"TFeedSec"              default 40
"Isothermal"            default true
"FinalizeForRuntime"    default true
"NativeValveCoefficient" default 1e-6
"LdfMassTransferPerSec" default 0.05
```

Set:

```matlab
basis = ribeiroSurrogateConstants();

params.parameterPackVersion = "Ribeiro2008-H2CO2-AC-surrogate-params-v1";
params.parameterPackName = "ribeiro_h2co2_ac_surrogate";
params.ribeiroBasis = basis;

params.nComs = 2;
params.componentNames = basis.componentNames;
params.componentOrder = basis.componentOrder;
params.nLKs = 1;

params.yFeC = basis.feed.moleFractions;
params.yRaC = [1; 0];     % H2-rich raffinate/product tank source
params.yExC = [0; 1];     % CO2-heavy extract convention

params.nVols = NVols;
params.nCols = 4;
params.nCycles = NCycles;
params.nSteps = 16;       % native global slots, not logical per-bed steps
params.nTiPts = NTimePoints;
```

## Feed flow conversion

Native toPSAil commonly uses volumetric flow in `cm^3/s`. Convert total molar feed flow to volumetric feed flow using absolute pressure.

Use:

```matlab
R = 83.14;        % cm^3 bar / mol / K
T = basis.feed.temperatureK;
P = basis.feed.pressureBarAbs;
ndot = basis.feed.totalMolarFlowMolSec;

basis.feed.totalVolumetricFlowCm3Sec = ndot * R * T / P;
```

For `0.1513 mol/s`, `303 K`, `7 bar_abs`, this is about:

```text
~545 cm^3/s
```

Set:

```matlab
params.volFlowFeed = basis.feed.totalVolumetricFlowCm3Sec;
params.ribeiroBasis = basis;  % keep derived feed-flow metadata with params
```

If native expects superficial flow through `volFlowFeed`, this is the direct feed tank/source volumetric flow. Do not interpret 7 bar_abs as 7 barg.

## Geometry

Use a simple, small geometry to avoid slow runs. Do not try to reproduce full paper geometry at first.

Recommended first values:

```matlab
params.radInCol = 10.0;      % cm, gives diameter 0.2 m like Ribeiro Table 5
params.radOutCol = 10.5;     % cm
params.heightCol = 100.0;    % cm
```

This aligns roughly with the paper’s single-column baseline of 1 m length and 0.2 m diameter, but the surrogate is not a full reproduction. The paper’s Table 5 lists a 1 m column and 0.2 m diameter for the detailed study .

Set:

```matlab
params.voidFracBed = 0.38;   % Ribeiro Table 5 value
params.overVoid = params.voidFracBed;
params.maTrRes = 0;
```

Particle/adsorbent values should initially come from Ribeiro Table 5 for the activated-carbon layer: particle porosity `0.566`, particle density `842 kg/m^3`, and particle radius `1.17e-3 m`. Convert units to the native toPSAil convention in the parameter builder and record those conversions in `docs/ribeiro_surrogate/IMPLEMENTATION_NOTES.md`.

## Isotherm model

Use existing native multisite Langmuir machinery because Ribeiro Table 4 supplies multisite Langmuir parameters for activated carbon. If this path fails for a native runtime reason, stop and record the blocker before falling back to a supplied Yang DSL/Freundlich parameter pack.

Set:

```matlab
params.modSp = [3; 1; 1; 1; 0; 0; 0];
params.qSatC = basis.adsorbent.multisiteLangmuir.qMaxMolKg;
params.aC = basis.adsorbent.multisiteLangmuir.a;
params.KC = basis.adsorbent.multisiteLangmuir.kInfPaInv;
params.isoStHtC = 1000 * basis.adsorbent.multisiteLangmuir.heatOfAdsorptionKJMol;
params.funcIso = @(paramsIn, states, nAds) calcIsothermMultiSiteLang(paramsIn, states, nAds);
```

Keep a caveat field:

```matlab
params.isothermCaveat = ...
    "Ribeiro Table 4 activated-carbon H2/CO2 subset only; excludes zeolite and CH4/CO/N2";
```

## Function: `finalizeRibeiroSurrogateTemplateParams.m`

Signature:

```matlab
function params = finalizeRibeiroSurrogateTemplateParams(params, varargin)
```

This should mirror the old finalizer pattern:

1. Set pressures and tank defaults:

```matlab
params.presColHigh = 7.0;
params.presColLow = 1.0;
params.presFeTa = params.presColHigh;
params.presRaTa = params.presColHigh;
params.presExTa = params.presColLow;
params.presAmbi = params.presColLow;
params.presDoSt = params.presColLow;
params = getPresRats(params);
```

2. Set temperatures:

```matlab
params.tempAmbi = 303.0;
params.tempCol = 303.0;
params.tempFeed = 303.0;
params.tempRefIso = 303.0;
params.tempAmbiNorm = 1;
params.tempColNorm = 1;
params.tempFeedNorm = 1;
params.tempRefNorm = 1;
params = getTempRats(params);
```

3. Set column/tank geometry:

```matlab
params = getColumnParams(params);
params.radInFeTa = params.radInCol;
params.radInRaTa = params.radInCol;
params.radInExTa = params.radInCol;
params.radOutFeTa = params.radOutCol;
params.radOutRaTa = params.radOutCol;
params.radOutExTa = params.radOutCol;
params.heightFeTa = params.heightCol;
params.heightRaTa = params.heightCol;
params.heightExTa = params.heightCol;
params = getTankParams(params);
```

4. Set solver/runtime:

```matlab
params.numZero = 1e-10;
params.numIntSolv = "ode15s";
params.odeRelTol = 3e-4;
params.odeAbsTol = 1e-5;
params.nRows = 1;
params.bool = zeros(12,1);
params.bool(1) = double(params.nCols > 1);
params.bool(3) = 0;
params.bool(5) = 0;  % isothermal
```

5. Set mass transfer and gas properties:

```matlab
params.ldfMtc = 0.05 * ones(params.nComs,1);
params.compFacC = ones(params.nComs,1);
params.htCapCpC = [28.84; 37.14];
params.htCapCvC = params.htCapCpC - (params.gasCons / 10);
```

6. Call native setup:

```matlab
[models, subModels] = getSubModels(params);
params.funcIso = models{1};
params.funcRat = models{2};
params.funcEos = models{3};
params.funcVal = models{4};
params.funcVol = models{6};
params.funcVolUnits = subModels{6};
params.funcCss = models{7};

params = getSolverOpts(params);
params = getStatesParams(params);
params = getStreamParams(params);
params = getScaleFacs(params);
params = getDimLessParams(params);
```

7. Initialize default schedule placeholders:

```matlab
params.sStepCol = repmat({'RT-XXX-XXX'}, params.nCols, params.nSteps);
params.typeDaeModel = ones(params.nCols, params.nSteps);
params.flowDirCol = zeros(params.nCols, params.nSteps);
params.numAdsEqPrEnd = zeros(params.nCols, params.nSteps);
params.numAdsEqFeEnd = zeros(params.nCols, params.nSteps);
params.valFeedCol = 1e-6 * ones(params.nCols, params.nSteps);
params.valProdCol = 1e-6 * ones(params.nCols, params.nSteps);
params.eveVal = NaN(1, params.nSteps);
params.eveUnit = repmat({'None'}, 1, params.nSteps);
params.eveLoc = repmat({'None'}, 1, params.nSteps);
params.funcEve = repmat({[]}, 1, params.nSteps);
```

Do **not** call `getInitialStates` until after the Ribeiro schedule is applied, unless needed for placeholder validation.

## Do not do

Do not create a four-bed wrapper. The params should be native four-column params.

## Manual validation

In MATLAB:

```matlab
addpath(genpath(pwd));
params = buildRibeiroSurrogateTemplateParams("NCycles", 1, "NVols", 4);
disp(params.nCols)
disp(params.nSteps)
disp(params.componentNames)
disp(params.volFlowFeed)
```

Expected:

```text
4
16
H2, CO2
positive volumetric feed flow
```

---

# Batch 3 — Native Ribeiro schedule builder

## Goal

Build the direct native four-column schedule with 16 global slots.

## Files to create

```text
scripts/ribeiro_surrogate/buildRibeiroNativeSchedule.m
scripts/ribeiro_surrogate/applyRibeiroNativeSchedule.m
```

## Core concept

Logical per-bed cycle:

```text
FEED              4 base slots
EQ_D1             2 base slots
EQ_D2             2 base slots
BLOWDOWN          1 base slot
PURGE             1 base slot
EQ_P1             2 base slots
EQ_P2             2 base slots
PRESSURIZATION    2 base slots
```

Base slot:

```matlab
baseSlotSec = tFeedSec / 4;
```

Native schedule has:

```matlab
nSteps = 16;
durStep = baseSlotSec * ones(1,16);
```

This is intentionally different from the logical eight steps because native toPSAil needs one global duration per schedule column.

## Function: `buildRibeiroNativeSchedule.m`

Signature:

```matlab
function schedule = buildRibeiroNativeSchedule(varargin)
```

Inputs:

```matlab
"TFeedSec" default 40
"PressurizationSource" default "RAF"
```

Return fields:

```matlab
schedule.version
schedule.nCols = 4
schedule.nNativeSteps = 16
schedule.nLogicalSteps = 8
schedule.baseSlotSec
schedule.durStep
schedule.logicalLabelsByCol   % 4x16 string
schedule.nativeStepCol        % 4x16 cellstr
schedule.flowDirCol           % 4x16 numeric
schedule.typeDaeModel         % 4x16 numeric
schedule.numAdsEqPrEnd        % 4x16 numeric
schedule.numAdsEqFeEnd        % 4x16 numeric zeros
schedule.eqRoleByCol          % donor/receiver/none metadata
```

## Build logical labels

Define phase over 16 slots:

```matlab
phase = [
    "FEED"
    "FEED"
    "FEED"
    "FEED"
    "EQ_D1"
    "EQ_D1"
    "EQ_D2"
    "EQ_D2"
    "BLOWDOWN"
    "PURGE"
    "EQ_P1"
    "EQ_P1"
    "EQ_P2"
    "EQ_P2"
    "PRESSURIZATION"
    "PRESSURIZATION"
];
```

Column offsets in base slots:

```matlab
offsets = [0; 4; 8; 12];   % A, B, C, D
```

For global slot `s` and column `c`:

```matlab
phaseIndex = mod((s - 1) - offsets(c), 16) + 1;
logicalLabelsByCol(c,s) = phase(phaseIndex);
```

This creates continuous feed: A feeds in slots 1–4, B in 5–8, C in 9–12, D in 13–16.

## Native mapping

```matlab
FEED              -> HP-FEE-RAF
EQ_D1             -> EQ-XXX-APR
EQ_D2             -> EQ-XXX-APR
BLOWDOWN          -> DP-ATM-XXX
PURGE             -> LP-ATM-RAF
EQ_P1             -> EQ-XXX-APR
EQ_P2             -> EQ-XXX-APR
PRESSURIZATION    -> RP-XXX-RAF
```

Use `RP-XXX-RAF` for fastest implementation. It represents product-end pressurization using raffinate/product tank gas. This is closer to Ribeiro’s “less adsorbed compound” pressurization than feed pressurization.

## Equalization pair matrix

For every native slot, exactly two columns should be in `EQ-XXX-APR`.

Set `numAdsEqPrEnd(i,s) = j` for the equalization pair.

The schedule should produce these pairs:

| Native slot | Pair | Meaning                   |
| ----------: | ---- | ------------------------- |
|           1 | B-D  | D donor D1, B receiver P2 |
|           2 | B-D  | D donor D1, B receiver P2 |
|           3 | C-D  | D donor D2, C receiver P1 |
|           4 | C-D  | D donor D2, C receiver P1 |
|           5 | A-C  | A donor D1, C receiver P2 |
|           6 | A-C  | A donor D1, C receiver P2 |
|           7 | A-D  | A donor D2, D receiver P1 |
|           8 | A-D  | A donor D2, D receiver P1 |
|           9 | B-D  | B donor D1, D receiver P2 |
|          10 | B-D  | B donor D1, D receiver P2 |
|          11 | A-B  | B donor D2, A receiver P1 |
|          12 | A-B  | B donor D2, A receiver P1 |
|          13 | A-C  | C donor D1, A receiver P2 |
|          14 | A-C  | C donor D1, A receiver P2 |
|          15 | B-C  | C donor D2, B receiver P1 |
|          16 | B-C  | C donor D2, B receiver P1 |

Do not rely on native `getStringParams` to infer equalization direction. Since equalization phases last two base slots, the native “next step is RP or HP” heuristic can misclassify the first sub-slot. Build `flowDirCol` explicitly:

```matlab
FEED:              0
EQ_D1 donor:       0
EQ_D2 donor:       0
EQ_P1 receiver:    1
EQ_P2 receiver:    1
BLOWDOWN:          1
PURGE:             1
PRESSURIZATION:    1
```

This follows the old Yang native local runner pattern: receiver equalization uses counter-current/product-end pressurization direction.

## Type DAE model

Set:

```matlab
typeDaeModel = ones(4,16);
typeDaeModel(nativeStepCol == "HP-FEE-RAF") = 0;
```

Keep all pressure-changing steps as varying pressure.

## Function: `applyRibeiroNativeSchedule.m`

Signature:

```matlab
function params = applyRibeiroNativeSchedule(params, schedule, varargin)
```

This function sets:

```matlab
params.nCols = 4;
params.nSteps = 16;
params.durStep = schedule.durStep;
params.sStepCol = cellstr(schedule.nativeStepCol);
params.typeDaeModel = schedule.typeDaeModel;
params.flowDirCol = schedule.flowDirCol;
params.numAdsEqPrEnd = schedule.numAdsEqPrEnd;
params.numAdsEqFeEnd = zeros(4,16);
params.eveVal = NaN(1,16);
params.eveUnit = repmat({'None'}, 1, 16);
params.eveLoc = repmat({'None'}, 1, 16);
params.funcEve = repmat({[]}, 1, 16);
```

Then call:

```matlab
params = getFlowSheetValves(params);
params = getColBoundConds(params);
params = getTimeSpan(params);
params = getEventParams(params);
params = getNumParams(params);
params.initStates = getInitialStates(params);
```

Do **not** call `getStringParams` because this implementation constructs numeric schedule matrices directly.

## Do not do

Do not create a Yang-style manifest table unless absolutely needed. Use a small struct.

## Manual validation

In MATLAB:

```matlab
schedule = buildRibeiroNativeSchedule("TFeedSec", 40);
disp(schedule.logicalLabelsByCol)
disp(schedule.nativeStepCol)
disp(schedule.numAdsEqPrEnd)
```

Manually inspect:

* 4 rows.
* 16 columns.
* Each column has one feed bed.
* Each equalization slot has exactly two paired equalization beds.
* No Yang labels appear.

---

# Batch 4 — Single-command Ribeiro runner

## Goal

Create the top-level function that builds params, applies schedule, runs native toPSAil, and returns a compact output struct.

## File to create

```text
scripts/ribeiro_surrogate/runRibeiroSurrogate.m
```

## Function signature

```matlab
function out = runRibeiroSurrogate(varargin)
```

Supported options:

```matlab
"NCycles"                default 20
"NVols"                  default 8
"TFeedSec"               default 40
"NTimePoints"            default 2
"NativeValveCoefficient" default 1e-6
"LdfMassTransferPerSec"  default 0.05
"StopAfterBuild"         default false
```

## Implementation sequence

```matlab
basis = ribeiroSurrogateConstants();

params = buildRibeiroSurrogateTemplateParams( ...
    "NCycles", opts.NCycles, ...
    "NVols", opts.NVols, ...
    "NTimePoints", opts.NTimePoints, ...
    "TFeedSec", opts.TFeedSec, ...
    "NativeValveCoefficient", opts.NativeValveCoefficient, ...
    "LdfMassTransferPerSec", opts.LdfMassTransferPerSec, ...
    "FinalizeForRuntime", true);

schedule = buildRibeiroNativeSchedule("TFeedSec", opts.TFeedSec);

params = applyRibeiroNativeSchedule(params, schedule);

if opts.StopAfterBuild
    sol = [];
else
    sol = runPsaCycle(params);
end

summary = summarizeRibeiroRun(params, schedule, sol);

out = struct();
out.version = "Ribeiro2008-surrogate-run-v1";
out.basis = basis;
out.params = params;
out.schedule = schedule;
out.sol = sol;
out.summary = summary;
```

## Important

Call `runPsaCycle(params)` directly. Do not call `runPsaProcessSimulation`, because that expects Excel example folders and writes plots/data.

## Runtime knobs for speed

Default small run:

```matlab
NCycles = 5
NVols = 4
NTimePoints = 2
```

User-facing default can be:

```matlab
NCycles = 20
NVols = 8
```

For debugging:

```matlab
out = runRibeiroSurrogate("NCycles", 1, "NVols", 3, "StopAfterBuild", false);
```

## Do not do

Do not implement plotting in this batch. Do not save files automatically.

## Manual validation

Run:

```matlab
addpath(genpath(pwd));
out = runRibeiroSurrogate("NCycles", 1, "NVols", 3, "TFeedSec", 40);
disp(out.summary)
```

Expected:

* It builds params.
* It enters native `runPsaCycle`.
* It returns a struct.
* It may not yet produce meaningful purity/recovery, but should not fail due to schedule structure.

---

# Batch 5 — Minimal Ribeiro summary and metrics

## Goal

Report usable H2 purity/recovery numbers while being explicit about basis.

## Files to create

```text
scripts/ribeiro_surrogate/summarizeRibeiroRun.m
scripts/ribeiro_surrogate/computeRibeiroExternalMetrics.m
```

## Why this matters

Ribeiro’s paper defines purity over the H2-rich product during the feed step, while recovery subtracts H2 used for pressurization and purge from the produced amount before dividing by H2 fed .

Native toPSAil’s internal `sol.perMet` uses raffinate/extract tank counters. That may not match Ribeiro’s exact equations. The first implementation should report both:

```text
native_toPSAil_purity
native_toPSAil_recovery
ribeiro_surrogate_purity
ribeiro_surrogate_recovery
basis notes
```

## Function: `summarizeRibeiroRun.m`

Signature:

```matlab
function summary = summarizeRibeiroRun(params, schedule, sol)
```

Return:

```matlab
summary.version
summary.caseName
summary.componentNames
summary.feedMoleFractions
summary.feedTotalMolarFlowMolSec
summary.pressureBasis
summary.highPressureBarAbs
summary.lowPressureBarAbs
summary.nCols
summary.nNativeSteps
summary.nCycles
summary.tFeedSec
summary.nativeSlotSec
summary.nativeProductPurityH2
summary.nativeProductRecoveryH2
summary.ribeiroProductPurityH2
summary.ribeiroProductRecoveryH2
summary.cssLast
summary.metricBasisNote
summary.warnings
```

If `sol` is empty because `StopAfterBuild` was true, return `NaN` metrics and a warning.

## Native metrics extraction

If `sol.perMet` exists:

```matlab
lastCycle = params.nCycles;
nativeProductPurityH2 = sol.perMet.productPurity(lastCycle, 1);
nativeProductRecoveryH2 = sol.perMet.productRecovery(lastCycle, 1);
```

This assumes H2 is the first component and raffinate is H2-rich.

## Ribeiro surrogate metrics

Function:

```matlab
function metrics = computeRibeiroExternalMetrics(params, schedule, sol)
```

Fast implementation:

1. Use native final cycle counters from `sol.Step*`.
2. External feed denominator:

```matlab
feedMol = getFeedMolCycle(params, sol, [], lastCycle);
h2Feed = feedMol(1);
```

3. Native raffinate product:

```matlab
[raffProd, raffWaste] = getRaffMoleCycle(params, sol, [], lastCycle);
```

4. Start with:

```matlab
externalProduct = raffProd;
```

5. Compute purity:

```matlab
purityH2 = externalProduct(1) / sum(externalProduct);
```

6. Compute recovery:

```matlab
recoveryH2 = externalProduct(1) / h2Feed;
```

7. Add caveat:

```matlab
metrics.basisNote = [
  "Ribeiro surrogate external metrics currently use native raffinate product counters. "
  "They do not yet explicitly subtract purge/pressurization withdrawals from product "
  "unless native tank product counters already exclude internal reuse."
];
```

This is acceptable for first implementation. The critical requirement is not to silently claim exact Ribeiro recovery.

## Optional better metric in same batch

If easy, subtract internal raffinate tank withdrawals used in `LP-ATM-RAF` and `RP-XXX-RAF`.

Look in each final-cycle step:

```matlab
step = sol.StepN;
```

Inspect available fields under:

```matlab
step.raTa.n1.cumMol
```

If there is a counter for tank-to-column withdrawal, subtract those moles from produced product for recovery. Do not spend a long time here. If the field is not obvious, leave the caveat and move on.

## Do not do

Do not port Yang ledger.

Do not create tables with dozens of row types.

Do not use `appendYangNativeAdFeedClosureRows.m`.

## Manual validation

Run:

```matlab
out = runRibeiroSurrogate("NCycles", 1, "NVols", 3);
disp(out.summary.nativeProductPurityH2)
disp(out.summary.nativeProductRecoveryH2)
disp(out.summary.metricBasisNote)
```

Expected:

* Numbers are finite or explicitly `NaN`.
* Basis note is visible.
* No hidden claim of exact Ribeiro metric reproduction.

---

# Batch 6 — Make the run robust enough for deadline use

## Goal

Fix only the failures that prevent the demo from running.

## Files likely involved

```text
params/ribeiro_surrogate/finalizeRibeiroSurrogateTemplateParams.m
scripts/ribeiro_surrogate/applyRibeiroNativeSchedule.m
scripts/ribeiro_surrogate/runRibeiroSurrogate.m
```

## Common native failure modes and direct fixes

### Failure: missing runtime field

Symptom:

```text
Reference to non-existent field ...
```

Fix:

Look first at `sources/Yang Scripts FOR REFERENCE ONLY/assertYangRuntimeTemplateReady.m` for the required runtime field checklist and `sources/Yang Scripts FOR REFERENCE ONLY/prepareYangNativeLocalRunParams.m` for the downstream native setup sequence. If the old Yang finalizer is later supplied under `sources/yang_h2co2_ac_surrogate/`, use it only as an additional structural reference. Do not redesign.

Likely fields:

```matlab
isEntEffFeComp
isEntEffExComp
isEntEffPump
compFacC
htCapCpC
htCapCvC
inConBed
inConFeTa
inConRaTa
inConExTa
valFeedCol
valProdCol
```

### Failure: valve coefficient equals 1

Native uses `1` as a non-Cv flag in some paths. Use small positive Cv:

```matlab
1e-6
```

Follow the old Yang finalizer’s warning that `1` is unsafe as a generic Cv value.

### Failure: equalization pairing odd/even error

Because this implementation does not call `getStringParams`, this should not happen. If native internals still complain, inspect `params.sStepCol(:,slot)` and ensure exactly two `EQ-XXX-APR` entries per slot.

### Failure: wrong flow direction in equalization

Do not rely on native inference. Override `params.flowDirCol` after applying schedule.

### Failure: tank pressure/inventory issue

Use conservative initial tank settings:

```matlab
params.presRaTa = params.presColHigh;
params.yRaC = [1; 0];
```

This gives the purge/pressurization source a valid H2-rich basis.

### Failure: run too slow

Use:

```matlab
NVols = 3
NCycles = 1
NTimePoints = 2
```

Then increase only after it runs.

## Do not do

Do not start implementing the old sequential wrapper unless direct native full schedule is truly blocked.

## Manual validation

Run:

```matlab
out = runRibeiroSurrogate("NCycles", 1, "NVols", 3, "NTimePoints", 2);
```

Then:

```matlab
out = runRibeiroSurrogate("NCycles", 5, "NVols", 4, "NTimePoints", 2);
```

---

# Batch 7 — Add optional lightweight plotting/output only after the run works

## Goal

Give the user something readable without creating diagnostics sprawl.

## File to create only if time remains

```text
scripts/ribeiro_surrogate/writeRibeiroRunSummary.m
```

## Function

```matlab
function writeRibeiroRunSummary(out, outputDir)
```

Write only:

```text
summary.md
summary.mat
```

Optional CSV:

```text
cycle_metrics.csv
```

No zip files. No massive validation folders.

## `summary.md` should include

```markdown
# Ribeiro surrogate run summary

- Components: H2/CO2
- Feed: 81.535 mol% H2, 18.465 mol% CO2, renormalized from Ribeiro Table 5 H2/CO2 entries
- Source feed: H2/CO2/CH4/CO/N2 = 73.3/16.6/3.5/2.9/3.7 mol %
- Feed flow: 12.2 N m^3/h source basis, about 0.1513 mol/s
- Pressure: 7 to 1 bar_abs
- Beds: 4
- Logical cycle: 8 steps
- Native schedule slots: 16
- Adsorbent: activated-carbon surrogate
- Native H2 purity:
- Native H2 recovery:
- Ribeiro-surrogate H2 purity:
- Ribeiro-surrogate H2 recovery:
- Metric basis caveat:
```

## Do not do

Do not create plots unless user explicitly asks. Plots cost time and are not needed for the minimal deliverable.

---

# Fallback plan only if direct native four-column schedule fails

Do **not** implement this unless Batch 4 cannot be made to run.

## Fallback architecture

Use old Yang temporary native runner concepts, but simplify heavily:

```text
persistent four bed states
single native step runner
pair native equalization runner
sequential cycle application
no custom adapters
no Yang labels
```

## Files to adapt from old branch

| New file                       | Old reference                                                 |
| ------------------------------ | ------------------------------------------------------------- |
| `makeFourBedStateContainer.m`  | `makeYangFourBedStateContainer.m`                             |
| `extractPhysicalBedState.m`    | `extractYangPhysicalBedState.m`                               |
| `runTemporaryNativeStep.m`     | `runYangTemporaryCase.m`, `prepareYangNativeLocalRunParams.m` |
| `extractTerminalLocalStates.m` | `extractYangTerminalLocalStates.m`                            |
| `writeBackFourBedStates.m`     | `writeBackYangFourBedStates.m`                                |

## Keep fallback tiny

Do not implement:

```text
operation plan table
pair map table
ledger table
adapter reports
diagnostics
validation suite
```

Only implement enough to apply:

```text
FEED
EQ_D1/EQ_P?
EQ_D2/EQ_P?
BLOWDOWN
PURGE
PRESSURIZATION
```

But the preferred path is still the direct native full-cycle implementation.

---

# Batch ownership summary

## Batch 0: fresh branch and instructions

Deliver:

```text
AGENTS.md
docs/ribeiro_surrogate/IMPLEMENTATION_NOTES.md
```

## Batch 1: constants

Deliver:

```text
params/ribeiro_surrogate/ribeiroSurrogateConstants.m
```

## Batch 2: params

Deliver:

```text
buildRibeiroSurrogateTemplateParams.m
finalizeRibeiroSurrogateTemplateParams.m
```

## Batch 3: native schedule

Deliver:

```text
buildRibeiroNativeSchedule.m
applyRibeiroNativeSchedule.m
```

## Batch 4: runner

Deliver:

```text
runRibeiroSurrogate.m
```

## Batch 5: summary/metrics

Deliver:

```text
summarizeRibeiroRun.m
computeRibeiroExternalMetrics.m
```

## Batch 6: robustness fixes

Deliver:

```text
small fixes only
no new framework
```

## Batch 7: optional output

Deliver only if time remains:

```text
writeRibeiroRunSummary.m
```

---

# Critical implementation details for Codex

## 1. Use 16 native slots, not 8 native slots

The logical Ribeiro cycle is eight steps per bed. Native toPSAil needs a global schedule. Because blowdown and purge are `tfeed/4` while feed is `tfeed`, the clean native representation is 16 base slots.

## 2. Do not call `getStringParams` for the Ribeiro schedule

Build these directly:

```matlab
params.sStepCol
params.typeDaeModel
params.flowDirCol
params.numAdsEqPrEnd
params.numAdsEqFeEnd
```

Then call downstream native setup:

```matlab
getFlowSheetValves
getColBoundConds
getTimeSpan
getEventParams
getNumParams
getInitialStates
```

## 3. Equalization receivers must have explicit flow direction

Set receiver `flowDirCol = 1` for `EQ_P1` and `EQ_P2`.

Do not rely on native “next step RP/HP” inference, because each equalization lasts two base slots and the first sub-slot may otherwise be misclassified.

## 4. First pressurization source should be raffinate/product tank

Use:

```text
RP-XXX-RAF
```

Do not use feed pressurization unless this fails.

## 5. Product metrics are provisional

The paper’s recovery formula subtracts H2 used in pressurization and purge from H2 product before dividing by feed H2 . Native toPSAil metrics may not exactly match that. The first version must expose the metric basis caveat.

## 6. Keep generated files out of git

Add or preserve ignore rules for:

```text
*.mat
*.zip
CW*.txt
2_simulation_outputs/
diagnostic_outputs/
validation/reports/
.DS_Store
~$*
```

Do not globally ignore source evidence that lives under `sources/`. This branch should allow `sources/**/*.pdf` and `sources/**/*.csv` so the Ribeiro/Yang literature artifacts and any source-table extracts can be staged deliberately.

---

# First command for the first Codex agent

If already on `ribero-clean-minimal`, do not recreate the branch. Otherwise:

```bash
git switch develop
git pull --ff-only
git switch -c ribero-clean-minimal
mkdir -p docs/ribeiro_surrogate params/ribeiro_surrogate scripts/ribeiro_surrogate
cat > /tmp/ribeiro_scope.txt <<'EOF'
Implement minimal Ribeiro H2/CO2 AC surrogate.
Fresh native toPSAil branch.
No Yang.
No tests.
Direct native four-column schedule.
16 native slots for 8 logical per-bed steps.
EOF
git status --short
```

Then implement Batch 0 and Batch 1 only.
