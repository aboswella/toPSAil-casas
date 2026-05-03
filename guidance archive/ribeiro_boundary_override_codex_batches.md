# Ribeiro boundary-condition override and Ribeiro accounting batches

## Decision

Keep the current four-bed, sixteen-slot scheduler. It is not the present validation blocker. The blocker is that the Ribeiro schedule is being driven through native toPSAil dynamic header tanks and generic valve coefficients, while the Ribeiro validation basis uses prescribed feed/purge operating conditions and step-specific boundary conditions. The next work should therefore be a small Ribeiro-only boundary overlay and a matching Ribeiro-only accounting layer.

Do **not** remove native tanks from the state vector. Do **not** rewrite native toPSAil. Do **not** port Yang wrappers, ledgers, adapters, tests, or plotting. Keep equalization native. Override only the non-equalization boundary behaviour needed to stop dynamic tanks becoming the validation basis.

---

## Batch 10 — Ribeiro boundary-condition overlay for all non-equalization stages

### Goal

Add a Ribeiro-specific boundary mode that leaves the existing 4-bed/16-slot native schedule intact but overrides the boundary flow/composition source for:

- `HP-FEE-RAF` feed step
- `DP-ATM-XXX` blowdown step
- `LP-ATM-RAF` purge step
- `RP-XXX-RAF` pressurization step

Leave `EQ-XXX-APR` exactly as currently implemented. Equalization remains native column-to-column transfer.

### Why this is needed

The current native valve/tank method can report Ribeiro source values in metadata while delivering a different actual feed/purge amount. The latest run shows this directly: final-cycle feed target is `24.208 mol`, but the achieved value is about `811.202 mol`. That is a boundary realization failure, not a schedule failure.

### Files to create

```text
scripts/ribeiro_surrogate/applyRibeiroBoundaryConditions.m
scripts/ribeiro_surrogate/calcRibeiroVolFlowsWithFixedBoundaries.m
scripts/ribeiro_surrogate/applyRibeiroBoundaryCompositionOverrides.m
scripts/ribeiro_surrogate/calcRibeiroFixedFeedBoundaryFlow.m
scripts/ribeiro_surrogate/calcRibeiroFixedPurgeBoundaryFlow.m
scripts/ribeiro_surrogate/calcRibeiroBlowdownBoundaryFlow.m
scripts/ribeiro_surrogate/calcRibeiroPressurizationBoundaryFlow.m
```

### Files to edit

```text
params/ribeiro_surrogate/buildRibeiroSurrogateTemplateParams.m
scripts/ribeiro_surrogate/runRibeiroSurrogate.m
scripts/ribeiro_surrogate/applyRibeiroNativeSchedule.m
docs/ribeiro_surrogate/IMPLEMENTATION_NOTES.md
```

### New runner/builder options

Add these options to `runRibeiroSurrogate` and pass them through to the builder/schedule applier:

```matlab
"BoundaryMode"                    default "ribeiro_fixed_non_eq"
"BlowdownGainMolSecBar"            default []
"PressurizationGainMolSecBar"      default []
"MaxBoundaryMolarFlowMolSec"       default Inf
```

Allowed `BoundaryMode` values:

```matlab
"native_valves"          % current behaviour, retained for comparison only
"ribeiro_fixed_non_eq"   % new validation-facing default
```

Store these in `params.ribeiroBoundary`. Do not treat the blowdown/pressurization gains as source constants. They are numerical controller gains used only to hit the Ribeiro pressure endpoints.

Recommended initial controller defaults:

```matlab
params.ribeiroBoundary.blowdownGainMolSecBar = 0.05;
params.ribeiroBoundary.pressurizationGainMolSecBar = 0.05;
params.ribeiroBoundary.maxBoundaryMolarFlowMolSec = Inf;
```

These may need a small pressure-first sensitivity sweep. Do not tune purity/recovery with them.

### Boundary-flow sign convention

Use native toPSAil’s boundary sign convention consistently:

```text
feed-end inflow during HP-FEE-RAF:                 positive volumetric boundary flow
feed-end outflow during DP-ATM-XXX:                negative volumetric boundary flow
product-end inflow during LP-ATM-RAF purge:        negative volumetric boundary flow
product-end inflow during RP-XXX-RAF pressurize:   negative volumetric boundary flow
```

The helper used by all new boundary functions should convert a dimensional molar flow into the dimensionless boundary volumetric flow expected by native `volFlBo` functions:

```matlab
function volFlowNorm = molarFlowToBoundaryVolFlowNorm(params, molFlowMolSec, gasConTotBoundaryNorm, signValue)
    molFlowNorm = molFlowMolSec ./ (params.gConScaleFac .* params.volScaleFac);
    volFlowNorm = signValue .* molFlowNorm ./ max(gasConTotBoundaryNorm, params.numZero);
end
```

This is preferred over fixed volumetric flow because it enforces the source molar feed/purge basis even if local boundary concentration drifts.

### `applyRibeiroBoundaryConditions.m`

Signature:

```matlab
function params = applyRibeiroBoundaryConditions(params, schedule, varargin)
```

Behaviour:

1. Return immediately when `params.ribeiroBoundary.mode == "native_valves"`.
2. Save native handles for audit:

```matlab
params.ribeiroBoundary.nativeFuncVol = params.funcVol;
params.ribeiroBoundary.nativeFuncVolUnits = params.funcVolUnits;
params.ribeiroBoundary.nativeVolFlBo = params.volFlBo;
params.ribeiroBoundary.nativeVolFlBoFree = params.volFlBoFree;
```

3. Override `params.volFlBo` by native step label:

```matlab
for step = 1:params.nSteps
    for col = 1:params.nCols
        label = string(params.sStepCol{col, step});
        switch label
            case "HP-FEE-RAF"
                params.volFlBo{2,col,step} = @(p,c,f,r,e,nS,nCo) calcRibeiroFixedFeedBoundaryFlow(p,c,f,r,e,nS,nCo);
                params.volFlBoFree(col,step) = 1;  % constant-pressure DAE feed-end BC
            case "DP-ATM-XXX"
                params.volFlBo{2,col,step} = @(p,c,f,r,e,nS,nCo) calcRibeiroBlowdownBoundaryFlow(p,c,f,r,e,nS,nCo);
            case "LP-ATM-RAF"
                params.volFlBo{1,col,step} = @(p,c,f,r,e,nS,nCo) calcRibeiroFixedPurgeBoundaryFlow(p,c,f,r,e,nS,nCo);
                params.volFlBoFree(col,step) = 0;  % constant-pressure DAE product-end BC
            case "RP-XXX-RAF"
                params.volFlBo{1,col,step} = @(p,c,f,r,e,nS,nCo) calcRibeiroPressurizationBoundaryFlow(p,c,f,r,e,nS,nCo);
            case "EQ-XXX-APR"
                % Leave native equalization untouched.
        end
    end
end
```

4. Replace `params.funcVol` with a Ribeiro wrapper:

```matlab
params.funcVol = @(p, units, nS) calcRibeiroVolFlowsWithFixedBoundaries(p, units, nS);
```

Call this function in `applyRibeiroNativeSchedule.m` immediately after `getColBoundConds(params)` and before `getTimeSpan`, `getEventParams`, `getNumParams`, and `getInitialStates`.

### `calcRibeiroVolFlowsWithFixedBoundaries.m`

Signature:

```matlab
function units = calcRibeiroVolFlowsWithFixedBoundaries(params, units, nS)
```

Behaviour:

1. Call `applyRibeiroBoundaryCompositionOverrides(params, units, nS)` before native volumetric-flow calculation.
2. Call the saved native volumetric-flow model:

```matlab
units = params.ribeiroBoundary.nativeFuncVol(params, units, nS);
```

This avoids editing native `defineRhsFunc` or `makeCol2Interact` while still ensuring column boundary compositions for feed, purge, and pressurization are not taken from dynamic tanks.

### `applyRibeiroBoundaryCompositionOverrides.m`

Signature:

```matlab
function units = applyRibeiroBoundaryCompositionOverrides(params, units, nS)
```

For each column/slot:

- `HP-FEE-RAF`: impose feed-end composition `params.yFeC` and feed temperature. Set species concentrations as `yFeC(j) * col.nX.gasConsTot(:,1)` and temperature as `params.tempFeedNorm`.
- `LP-ATM-RAF`: impose product-end pure H2 purge composition `[1;0]` and `params.tempFeedNorm` or `params.tempColNorm`.
- `RP-XXX-RAF`: impose product-end pure H2 pressurization composition `[1;0]` and `params.tempFeedNorm` or `params.tempColNorm`.
- `DP-ATM-XXX`: make the feed-end boundary inert against accidental reverse-flow by setting feed-end composition equal to the local first-CSTR composition and temperature equal to the first-CSTR temperature.
- `EQ-XXX-APR`: do nothing.

Do not alter column-to-column equalization boundary compositions.

### `calcRibeiroFixedFeedBoundaryFlow.m`

Use the source feed molar flow directly:

```matlab
feedMolSec = params.ribeiroBasis.feed.totalMolarFlowMolSec;
gasConTot = col.(params.sColNums{nCo}).gasConsTot(:,1);
volFlowRat = molarFlowToBoundaryVolFlowNorm(params, feedMolSec, gasConTot, +1);
```

Expected effect for `TFeedSec = 40`: one global four-bed cycle processes `0.1513 mol/s * 160 s = 24.208 mol` total feed.

### `calcRibeiroFixedPurgeBoundaryFlow.m`

Convert Ribeiro Table 5 purge flow to mol/s and impose it as pure H2 at the product end:

```matlab
normalMolarVolM3PerKmol = 22.414;
purgeMolSec = params.ribeiroBasis.purge.sourceFlowNm3Hr / 3600 / normalMolarVolM3PerKmol * 1000;
gasConTot = col.(params.sColNums{nCo}).gasConsTot(:,params.nVols);
volFlowRat = molarFlowToBoundaryVolFlowNorm(params, purgeMolSec, gasConTot, -1);
```

Expected effect for `TFeedSec = 40`: total purge duration over the four-bed global cycle is `40 s`, so source purge H2 is about `1.735 mol` per final cycle.

### `calcRibeiroBlowdownBoundaryFlow.m`

Use a fixed low-pressure sink, not a dynamic tank:

```matlab
gasConTot = col.(params.sColNums{nCo}).gasConsTot(:,1);
tempNorm = col.(params.sColNums{nCo}).temps.cstr(:,1);
pressureBar = gasConTot .* tempNorm .* params.presColHigh;
deltaBar = max(0, pressureBar - params.presColLow);
reliefMolSec = params.ribeiroBoundary.blowdownGainMolSecBar .* deltaBar;
reliefMolSec = min(reliefMolSec, params.ribeiroBoundary.maxBoundaryMolarFlowMolSec);
volFlowRat = molarFlowToBoundaryVolFlowNorm(params, reliefMolSec, gasConTot, -1);
```

This is a pressure-relief boundary to a 1 bar sink. It is not a source constant. Select the gain by pressure endpoints only.

### `calcRibeiroPressurizationBoundaryFlow.m`

Use a fixed pure-H2 source and a high-pressure target, not the raffinate tank pressure/composition:

```matlab
gasConTot = col.(params.sColNums{nCo}).gasConsTot(:,params.nVols);
tempNorm = col.(params.sColNums{nCo}).temps.cstr(:,params.nVols);
pressureBar = gasConTot .* tempNorm .* params.presColHigh;
deltaBar = max(0, params.presColHigh - pressureBar);
pressMolSec = params.ribeiroBoundary.pressurizationGainMolSecBar .* deltaBar;
pressMolSec = min(pressMolSec, params.ribeiroBoundary.maxBoundaryMolarFlowMolSec);
volFlowRat = molarFlowToBoundaryVolFlowNorm(params, pressMolSec, gasConTot, -1);
```

Again, select the gain by pressure endpoints only. Do not use product purity/recovery as the tuning target.

### Required summary fields after Batch 10

Add these to `summary`:

```text
boundaryMode
boundaryModeBasis
feedBoundaryBasis
purgeBoundaryBasis
blowdownBoundaryBasis
pressurizationBoundaryBasis
equalizationBoundaryBasis
```

Expected values:

```text
boundaryMode = ribeiro_fixed_non_eq
equalizationBoundaryBasis = native column-to-column EQ-XXX-APR retained
```

### Minimal run after Batch 10

```matlab
addpath(genpath(pwd));
out = runRibeiroSurrogate("BoundaryMode", "ribeiro_fixed_non_eq", ...
    "NCycles", 1, "NVols", 3, "NTimePoints", 2, "TFeedSec", 40);
disp(out.summary)
```

Then:

```matlab
out = runRibeiroSurrogate("BoundaryMode", "ribeiro_fixed_non_eq", ...
    "NCycles", 5, "NVols", 4, "NTimePoints", 2, "TFeedSec", 40);
disp(out.summary)
```

Stop after this batch if the run fails. Do not add plots, tests, or a new driver.

### Tiny pressure-first sensitivity, only if needed

If blowdown does not approach 1 bar or pressurization does not approach 7 bar, run only this small sweep:

```matlab
bdVals = [0.02, 0.05, 0.10];
prVals = [0.02, 0.05, 0.10];
for bd = bdVals
    for pr = prVals
        out = runRibeiroSurrogate("BoundaryMode", "ribeiro_fixed_non_eq", ...
            "BlowdownGainMolSecBar", bd, ...
            "PressurizationGainMolSecBar", pr, ...
            "NCycles", 5, "NVols", 3, "NTimePoints", 2, "TFeedSec", 40);
        disp([bd, pr, out.summary.pressureAudit.maxFeedPressureErrorBar, ...
            out.summary.pressureAudit.maxLowPressureErrorBar, ...
            out.summary.pressureAudit.maxPressurizationErrorBar]);
    end
end
```

Pick the smallest gains that make the pressure endpoints plausible. Do not tune purity/recovery.

---

## Batch 11 — Ribeiro boundary-accounting metrics and pressure gates

### Goal

Replace validation-facing accounting with a Ribeiro Eq. 2/Eq. 3 boundary basis. Do not use native dynamic tank feed/product counters as the validation basis when `BoundaryMode = "ribeiro_fixed_non_eq"`.

### Files to create

```text
scripts/ribeiro_surrogate/computeRibeiroBoundaryMetrics.m
scripts/ribeiro_surrogate/getRibeiroColumnStepCounterMoles.m
scripts/ribeiro_surrogate/getRibeiroPressureAudit.m
```

### Files to edit

```text
scripts/ribeiro_surrogate/computeRibeiroExternalMetrics.m
scripts/ribeiro_surrogate/summarizeRibeiroRun.m
scripts/ribeiro_surrogate/writeRibeiroRunSummary.m
docs/ribeiro_surrogate/IMPLEMENTATION_NOTES.md
```

### Accounting basis

When `BoundaryMode = "ribeiro_fixed_non_eq"`, compute validation-facing metrics as:

```text
feed denominator = prescribed Ribeiro Table 5 feed molar flow * 4*tfeed * binary H2/CO2 composition
purity numerator = H2 leaving product end during HP-FEE-RAF slots
purity denominator = total gas leaving product end during HP-FEE-RAF slots
recovery numerator = H2 leaving product end during HP-FEE-RAF slots
                   - H2 entering product end during RP-XXX-RAF pressurization
                   - H2 entering product end during LP-ATM-RAF purge
recovery denominator = prescribed binary H2 feed in the global cycle
```

This implements the Eq. 2/Eq. 3 accounting basis without treating toPSAil tanks as source truth.

### `computeRibeiroBoundaryMetrics.m`

Signature:

```matlab
function metrics = computeRibeiroBoundaryMetrics(params, schedule, sol)
```

Required output fields:

```matlab
metrics.version = "Ribeiro2008-boundary-accounting-v1";
metrics.boundaryMode
metrics.lastCompleteCycle
metrics.feedMolesFinalCycleExpected
metrics.feedH2MolesFinalCycleExpected
metrics.feedCO2MolesFinalCycleExpected
metrics.feedStepProductMolesFinalCycle
metrics.pressurizationProductEndMolesSignedFinalCycle
metrics.purgeProductEndMolesSignedFinalCycle
metrics.h2ProductDuringFeedFinalCycle
metrics.h2UsedForPressurizationFinalCycle
metrics.h2UsedForPurgeFinalCycle
metrics.expectedSourcePurgeH2MolesFinalCycle
metrics.purgeH2RelativeError
metrics.ribeiroEq2PurityH2
metrics.ribeiroEq3RecoveryH2
metrics.pressureAudit
metrics.warnings
metrics.metricBasisNote
```

Use analytical prescribed feed as the feed denominator:

```matlab
cycleTimeSec = 4 * params.tFeedSec;
expectedTotalFeed = params.ribeiroBasis.feed.totalMolarFlowMolSec * cycleTimeSec;
expectedFeed = expectedTotalFeed * params.ribeiroBasis.feed.moleFractions(:).';
```

Use analytical prescribed purge only as a check; use the column product-end counter for the actual debited purge H2:

```matlab
expectedPurgeH2 = nm3hrToMolSec(params.ribeiroBasis.purge.sourceFlowNm3Hr) * params.tFeedSec;
```

### Counter extraction

Use a small helper:

```matlab
function moles = getRibeiroColumnStepCounterMoles(params, sol, lastCycle, stepLabel, endName)
```

Supported `endName` values:

```matlab
"prod"
"feed"
```

Use existing final-cycle `sol.Step*.col.n*.cumMol.prod(end,:)` or `.feed(end,:)` and dimensionalize by `params.nScaleFac`. This is already the most useful counter path in the current implementation.

For product during feed:

```matlab
feedProduct = getRibeiroColumnStepCounterMoles(params, sol, lastCycle, "HP-FEE-RAF", "prod");
```

For pressurization H2 debit:

```matlab
pressSigned = getRibeiroColumnStepCounterMoles(params, sol, lastCycle, "RP-XXX-RAF", "prod");
h2Press = abs(pressSigned(1));
```

For purge H2 debit:

```matlab
purgeSigned = getRibeiroColumnStepCounterMoles(params, sol, lastCycle, "LP-ATM-RAF", "prod");
h2Purge = abs(purgeSigned(1));
```

Then:

```matlab
purity = feedProduct(1) / sum(feedProduct);
recovery = (feedProduct(1) - h2Press - h2Purge) / expectedFeed(1);
```

Do not use `getFeedMolCycle` or `getRaffMoleCycle` as the validation basis in this mode. They may still be reported as native diagnostic counters, but they are not Ribeiro truth.

### Pressure audit

Add `getRibeiroPressureAudit(params, schedule, sol, lastCycle)`.

For each final-cycle slot/column, compute average column pressure from gas concentration and temperature using the same basis as native plotting:

```matlab
pressureBar = mean(step.col.nX.gasConsTot(end, :), 2) ...
    .* params.gConScaleFac ...
    .* params.gasCons ...
    .* mean(step.col.nX.temps.cstr(end, :), 2) ...
    .* params.teScaleFac;
```

Report at least:

```matlab
pressureAudit.feedEndPressureBarByColumn
pressureAudit.blowdownEndPressureBarByColumn
pressureAudit.purgeEndPressureBarByColumn
pressureAudit.pressurizationEndPressureBarByColumn
pressureAudit.maxFeedPressureErrorBar
pressureAudit.maxLowPressureErrorBar
pressureAudit.maxPressurizationErrorBar
```

Gate warnings:

```matlab
feed steps not within 0.5 bar of 7 bar
blowdown/purge steps not within 0.5 bar of 1 bar
pressurization steps not within 0.5 bar of 7 bar
```

Use these as first-pass gates only.

### Summary output

`summary.md` should include:

```text
- Boundary mode:
- Boundary basis:
- Equalization basis:
- Expected total feed, final cycle:
- Accounting total feed, final cycle:
- Expected binary H2 feed, final cycle:
- Accounting binary H2 feed, final cycle:
- Expected source purge H2, final cycle:
- Boundary-counter purge H2, final cycle:
- Purge H2 relative error:
- H2 used for pressurization, final cycle:
- Ribeiro Eq. 2 boundary-basis H2 purity:
- Ribeiro Eq. 3 boundary-basis H2 recovery:
- Pressure audit, feed/high/low/pressurization:
- Metric basis note:
```

Retain old native purity/recovery as diagnostics, but label them explicitly:

```text
Native toPSAil tank metrics are diagnostic only in ribeiro_fixed_non_eq mode.
```

### Acceptance checks after Batch 11

For `TFeedSec = 40`:

```text
Accounting total feed = 24.208 mol by construction
Accounting binary H2 feed = about 19.738 mol by construction
Expected purge H2 = about 1.735 mol
Boundary-counter purge H2 should be close to 1.735 mol
Eq. 2 H2 purity finite and in [0, 1]
Eq. 3 H2 recovery finite and in [0, 1]
Feed/high-pressure steps near 7 bar
Blowdown/purge steps near 1 bar
Pressurization end near 7 bar
```

A run passing these gates can be described as source-basis soft verification of the binary H2/CO2 activated-carbon surrogate. It still cannot be described as a full reproduction of Ribeiro’s five-component, layered AC/zeolite, non-isothermal model.

### Minimal run after Batch 11

```matlab
addpath(genpath(pwd));
out = runRibeiroSurrogate("BoundaryMode", "ribeiro_fixed_non_eq", ...
    "NCycles", 20, "NVols", 4, "NTimePoints", 2, "TFeedSec", 40);
disp(out.summary)
writeRibeiroRunSummary(out, "diagnostic_outputs/ribeiro_surrogate_boundary_20cycle");
```

Do not add plots, generated tests, validation reports, or a large sweep. Only run the small pressure-gain sensitivity if pressure gates fail.

---

## Codex stop conditions

Stop and report immediately if any of these occur:

1. The boundary wrapper requires editing native `defineRhsFunc`, `makeCol2Interact`, or state-vector sizing. That would expand scope beyond the deadline path.
2. `BoundaryMode = "ribeiro_fixed_non_eq"` cannot complete a 1-cycle run.
3. Product-end feed-step counters are negative after the boundary override; that indicates sign convention or endpoint mapping is wrong.
4. Purge counter does not match the analytical source purge after fixed purge is applied; that indicates the product-end boundary sign or concentration override is wrong.

Do not proceed to tune purity/recovery until feed/purge/pressure gates are sane.
