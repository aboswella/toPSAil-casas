# Ribeiro soft-validation fast-fix batches after Boundary Batches 10/11

## Diagnosis to give the next Codex agent

The four-bed / sixteen-slot schedule is not the current validation blocker. The current blocker is pressure realization after the Batch 10/11 boundary overlay.

The latest `ribeiro_fixed_non_eq` run has source-feed and purge accounting fixed by construction, but the final-cycle pressure profile is still not Ribeiro-like:

- feed/high steps end around `6.19 bar`, not `7 bar`;
- blowdown and purge end around `3.56 bar`, not `1 bar`;
- pressurization also ends around `6.19 bar`, not `7 bar`;
- equalization is still weak and does not stage the bed through the expected high/intermediate/low pressure sequence.

Ribeiro's pressure sequence is the thing to match first: feed at high pressure, two depressurizing equalizations, blowdown to low pressure, purge at low pressure, two pressurizing equalizations, and final pressurization to high pressure. Do not tune purity/recovery until pressure gates pass.

The most likely implementation mistakes are:

1. `ribeiro_fixed_non_eq` leaves equalization native, but the current equalization valve coefficient remains the fallback `1e-6`. That is effectively closed for the Ribeiro timing. Native `EQ-XXX-APR` therefore cannot create the D1/D2/P1/P2 pressure staging.
2. In `ribeiro_fixed_non_eq`, `BlowdownValveCoefficient` and `PressurizationValveCoefficient` are mostly irrelevant because Batch 10 overrides the non-equalization boundary handles. The active knobs are `BlowdownGainMolSecBar`, `PressurizationGainMolSecBar`, and `MaxBoundaryMolarFlowMolSec`, but the defaults `0.05/0.05/Inf` are too weak or too uncontrolled for fast pressure endpoint matching.
3. Batch 11 currently labels the fixed feed denominator as achieved feed in boundary mode. That is acceptable as an accounting denominator, but it hides whether the column feed-end cumulative counter actually matches the prescribed feed. Add a raw column-boundary feed audit so a broken boundary handle cannot silently pass.

Keep changes surgical. Do not add a test suite, plots, calibration framework, Yang code, or native-core rewrite. After each batch run one smoke test and inspect only the summary/pressure fields.

---

## Batch 12 — Open native equalization enough to make D1/D2/P1/P2 real

### Goal

Make the retained native `EQ-XXX-APR` steps actually transfer gas during the two-slot equalization windows. This should move the pressure trace toward the Ribeiro sequence before touching purity/recovery.

### Files to edit

```text
params/ribeiro_surrogate/ribeiroSurrogateConstants.m
params/ribeiro_surrogate/buildRibeiroSurrogateTemplateParams.m
scripts/ribeiro_surrogate/applyRibeiroNativeSchedule.m   # only if needed for option propagation; avoid otherwise
docs/ribeiro_surrogate/IMPLEMENTATION_NOTES.md
```

### Surgical changes

1. In `ribeiroSurrogateConstants.m`, change the equalization default from the fallback native valve to a pressure-staging value:

```matlab
basis.valves.equalizationValveCoefficientDefault = 2.0e-5;
```

Keep this text clear: this is a native calibration knob, not a Ribeiro paper constant.

2. In `buildRibeiroSurrogateTemplateParams.m`, stop ignoring the basis default for equalization. The current pattern uses the native fallback for equalization. Change only the equalization default resolution to:

```matlab
equalizationValveCoefficient = resolveValveCoefficientDefault( ...
    opts.EqualizationValveCoefficient, basis.valves.equalizationValveCoefficientDefault);
```

Leave `FeedValveCoefficient` and `PurgeValveCoefficient` as they are. In `ribeiro_fixed_non_eq`, leave blowdown and pressurization valve coefficients as diagnostics/fallbacks because the fixed boundary functions use gains instead.

3. Confirm `applyRibeiroNativeSchedule.m` still writes:

```matlab
params.valProdCol(strcmp(params.sStepCol, 'EQ-XXX-APR')) = equalizationValveCoefficient;
params.valProdColNorm = params.valProdCol .* params.valScaleFac;
```

Do not add a manifest or new diagnostic file.

4. Add one short implementation-note paragraph:

```markdown
Batch 12 opens native product-end equalization from the old fallback `1e-6` to `2e-5` by default. Equalization remains native `EQ-XXX-APR`; this coefficient is a pressure-staging knob for the binary surrogate, not a Ribeiro source constant.
```

### Smoke test after Batch 12

Run exactly:

```matlab
addpath(genpath(pwd));
out = runRibeiroSurrogate("BoundaryMode", "ribeiro_fixed_non_eq", ...
    "NCycles", 1, "NVols", 3, "NTimePoints", 2, "TFeedSec", 40);
disp(out.summary.pressureAudit)
disp(out.summary)
```

Expected qualitative result: equalization pressures should move much more than the prior `1e-6` run. Do not tune purity/recovery. Do not run a sweep. If MATLAB fails, stop and fix only the immediate runtime error.

---

## Batch 13 — Make fixed blowdown/pressurization hit pressure endpoints

### Goal

Use the active fixed-boundary pressure controller knobs, not native blowdown/press valve coefficients, to make the final-cycle pressure gates plausible:

- feed and final pressurization near `7 bar`;
- blowdown and purge near `1 bar`;
- equalization staged between them.

### Files to edit

```text
params/ribeiro_surrogate/buildRibeiroSurrogateTemplateParams.m
scripts/ribeiro_surrogate/applyRibeiroBoundaryConditions.m
docs/ribeiro_surrogate/IMPLEMENTATION_NOTES.md
```

### Surgical changes

1. Change the validation-facing default boundary gains in both `makeRibeiroBoundaryOptions` and `defaultBoundaryOptions`:

```matlab
boundary.blowdownGainMolSecBar = resolveBoundaryGain(opts.BlowdownGainMolSecBar, 0.15);
boundary.pressurizationGainMolSecBar = resolveBoundaryGain(opts.PressurizationGainMolSecBar, 0.12);
```

and in `defaultBoundaryOptions`:

```matlab
boundary.blowdownGainMolSecBar = 0.15;
boundary.pressurizationGainMolSecBar = 0.12;
```

2. Replace the `MaxBoundaryMolarFlowMolSec` default of `Inf` with a finite safety cap:

```matlab
addParameter(parser, 'MaxBoundaryMolarFlowMolSec', 0.5, @mustBeNonnegativeNumericScalar);
```

and in `defaultBoundaryOptions`:

```matlab
boundary.maxBoundaryMolarFlowMolSec = 0.5;
```

Do not cap feed or purge source flows. This cap applies only through the blowdown and pressurization controller functions because feed and purge use prescribed source molar flows.

3. Add this note to the docs:

```markdown
Batch 13 changes only active fixed-boundary pressure controller defaults. In `ribeiro_fixed_non_eq`, blowdown and pressurization valve coefficients are not the active pressure knobs; `BlowdownGainMolSecBar`, `PressurizationGainMolSecBar`, and `MaxBoundaryMolarFlowMolSec` are.
```

4. Do not change the source feed flow, purge flow, isotherm, LDF values, or schedule.

### Smoke test after Batch 13

Run exactly:

```matlab
addpath(genpath(pwd));
out = runRibeiroSurrogate("BoundaryMode", "ribeiro_fixed_non_eq", ...
    "NCycles", 3, "NVols", 3, "NTimePoints", 2, "TFeedSec", 40);
disp(out.summary.softValidationStatus)
disp(out.summary.pressureAudit.maxFeedPressureErrorBar)
disp(out.summary.pressureAudit.maxLowPressureErrorBar)
disp(out.summary.pressureAudit.maxPressurizationErrorBar)
disp(out.summary.ribeiroEq2PurityH2)
disp(out.summary.ribeiroEq3RecoveryH2)
```

Expected result: pressure errors should be much smaller than the old `0.81 / 2.56 / 0.81 bar` failure. The target is all pressure errors below `0.5 bar`. If the low-pressure error is still clearly high, make one adjustment only: set `BlowdownGainMolSecBar` default to `0.25` and rerun the same smoke. If high-pressure/pressurization is still clearly low, make one adjustment only: set `PressurizationGainMolSecBar` default to `0.18` and rerun the same smoke. Do not sweep.

---

## Batch 14 — Add real column-boundary feed audit in fixed boundary mode

### Goal

Keep the Ribeiro Eq. 2/Eq. 3 denominator as the prescribed Table 5 source feed, but report the actual column feed-end cumulative counter too. This prevents the current boundary accounting from declaring feed flow correct merely because it used the analytical denominator.

### Files to edit

```text
scripts/ribeiro_surrogate/computeRibeiroBoundaryMetrics.m
scripts/ribeiro_surrogate/summarizeRibeiroRun.m
scripts/ribeiro_surrogate/writeRibeiroRunSummary.m
docs/ribeiro_surrogate/IMPLEMENTATION_NOTES.md
```

### Surgical changes

1. In `computeRibeiroBoundaryMetrics.m`, after the existing final-cycle counter extraction, also extract the feed-end counter during feed slots:

```matlab
feedBoundarySigned = getRibeiroColumnStepCounterMoles(params, sol, ...
    metrics.lastCompleteCycle, "HP-FEE-RAF", "feed");
feedBoundaryDelivered = -cleanNearZero(feedBoundarySigned, params.numZero);
```

The sign is intentional: native column `cumMol.feed` is positive for gas leaving the feed end and negative for gas entering from the feed end during `HP-FEE-RAF`.

2. Add fields:

```matlab
metrics.feedBoundarySignedMolesFinalCycle = feedBoundarySigned;
metrics.feedBoundaryDeliveredMolesFinalCycle = feedBoundaryDelivered;
metrics.feedBoundaryDeliveredTotalMolesFinalCycle = sum(feedBoundaryDelivered);
metrics.feedBoundaryDeliveredBinaryH2MolesFinalCycle = feedBoundaryDelivered(1);
metrics.feedBoundaryDeliveredRelativeError = relativeError(feedBoundaryDelivered, expectedFeed);
metrics.feedBoundaryDeliveredTotalRelativeError = relativeError(sum(feedBoundaryDelivered), expectedTotalFeed);
```

3. In boundary mode, keep these as validation-facing achieved feed fields:

```matlab
metrics.achievedTotalFeedMolesFinalCycle = metrics.feedBoundaryDeliveredTotalMolesFinalCycle;
metrics.achievedBinaryH2FeedMolesFinalCycle = metrics.feedBoundaryDeliveredBinaryH2MolesFinalCycle;
metrics.feedMolesRelativeError = metrics.feedBoundaryDeliveredRelativeError;
metrics.totalFeedMolesRelativeError = metrics.feedBoundaryDeliveredTotalRelativeError;
```

Do **not** change `metrics.accountingFeedMolesFinalCycle` or the Eq. 3 denominator; those should remain prescribed Ribeiro source-feed values.

4. Add warnings:

```matlab
if isfinite(metrics.feedBoundaryDeliveredTotalRelativeError) && ...
        metrics.feedBoundaryDeliveredTotalRelativeError > 0.05
    metrics.warnings(end+1, 1) = sprintf( ...
        'Column feed-end boundary counter differs from prescribed Ribeiro feed by %.3g relative error.', ...
        metrics.feedBoundaryDeliveredTotalRelativeError);
end
```

5. Surface these fields in `summarizeRibeiroRun.m` and `writeRibeiroRunSummary.m`:

```text
- Column feed-boundary delivered total feed, final cycle:
- Column feed-boundary delivered H2 feed, final cycle:
- Column feed-boundary total relative error:
```

6. Add a short note that the source-feed denominator and actual boundary counter are now reported separately.

### Smoke test after Batch 14

Run exactly:

```matlab
addpath(genpath(pwd));
out = runRibeiroSurrogate("BoundaryMode", "ribeiro_fixed_non_eq", ...
    "NCycles", 3, "NVols", 3, "NTimePoints", 2, "TFeedSec", 40);
disp(out.summary.achievedTotalFeedMolesFinalCycle)
disp(out.summary.expectedTotalFeedMolesFinalCycle)
disp(out.summary.totalFeedMolesRelativeError)
disp(out.summary.pressureAudit)
```

Expected result: the actual column feed-boundary counter should match the prescribed `24.208 mol` total feed within the existing `5%` gate. If it does not, stop and fix the feed boundary function/sign convention only. Do not change purity/recovery or source constants.

---

## Stop condition after these batches

After Batches 12--14, the first acceptable soft-validation gate is:

```text
summary.softValidationStatus == "PASS_PRESSURE_FLOW_AUDIT"
pressureAudit.maxFeedPressureErrorBar <= 0.5
pressureAudit.maxLowPressureErrorBar <= 0.5
pressureAudit.maxPressurizationErrorBar <= 0.5
totalFeedMolesRelativeError <= 0.05
purgeH2RelativeError <= 0.05
ribeiroEq2PurityH2 and ribeiroEq3RecoveryH2 finite and in [0, 1]
```

Only after that should anyone interpret purity/recovery. A binary activated-carbon surrogate still should not be tuned to exactly reproduce Ribeiro's full five-component layered AC/zeolite multicolumn purity/recovery.

## Do not do in these batches

- Do not change the four-bed / sixteen-slot schedule.
- Do not port Yang wrappers, ledgers, adapters, or tests.
- Do not tune against H2 purity or recovery.
- Do not change Ribeiro Table 5 feed or purge source values.
- Do not modify native toPSAil core.
- Do not create plots, validation folders, or test scripts.
