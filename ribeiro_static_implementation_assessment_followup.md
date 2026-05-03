# Ribeiro Surrogate Static Implementation Assessment — soft-verification gate

**Assessment target:** static repository extracted from `Ribeiro partial completion.zip`  
**Assessment mode:** source/notes/code review only. I did not rerun MATLAB/toPSAil in this environment.  
**Primary basis reviewed:** `Ribeiro 2008.pdf`, `Overall Implementation Guide.md`, uploaded `IMPLEMENTATION_NOTES.md`, prior `ribeiro_static_implementation_assessment.md`, and the active Ribeiro files under `params/ribeiro_surrogate/` and `scripts/ribeiro_surrogate/`.

## Bottom line

The branch is much closer than the prior static assessment. The earlier critical source-basis problems have mostly been patched: the builder now uses an effective isothermal multisite-Langmuir `KC`, the constants now include the Ribeiro Table 6 H2/CO2 activated-carbon LDF values, and `computeRibeiroExternalMetrics.m` now reports final-cycle Eq. 2/Eq. 3-style counters instead of only native/fallback product metrics.

I would keep the current direct-native four-column architecture. Do **not** switch to a Yang wrapper, do **not** create a test suite, and do **not** add plotting or diagnostics sprawl.

The remaining likely reason the results are still not in line with the soft-validation requirements is not the schedule and probably not the patched isotherm/kinetics. The highest-risk gap is that the source feed and purge flows are **stored and reported as Ribeiro basis values, but not yet proven to be the actual flows processed by the native simulation**. The native run is valve-driven. The default single `NativeValveCoefficient = 1e-6` is applied broadly to feed, purge, pressurization, and equalization positions, so the model can run while still processing the wrong feed moles and the wrong purge/feed ratio.

The next Codex work should be a narrow flow-accounting patch and, only if the reported achieved flows are off, a narrow per-operation valve-coefficient patch. Nothing else is needed before the first soft-verification attempt.

---

## Gate status

| Gate | Status | Static assessment |
|---|---:|---|
| Active Ribeiro file set | Pass | The active code is limited to the intended `params/ribeiro_surrogate/` and `scripts/ribeiro_surrogate/` files, plus optional `writeRibeiroRunSummary.m`. |
| Yang quarantine | Pass with noise caveat | Yang scripts remain under `sources/Yang Scripts FOR REFERENCE ONLY/`; no active Ribeiro wrapper/adapters/tests are present. Old Yang diagnostics exist under `diagnostic_outputs/`, but they are ignored/noise. |
| Source-backed constants | Pass | Feed composition, pressure, geometry, Table 4 AC H2/CO2 MSL values, Table 5 particle values, Table 6 H2/CO2 LDF values, and Table 5 purge-flow reference are present. |
| Effective isothermal MSL `KC` | Pass, with formula caveat | `buildRibeiroSurrogateTemplateParams.m` now computes `KC = a_i * k_inf(Pa^-1) * 1e5 * exp(deltaH_i/(R*T))`. This addresses the earlier under-adsorption risk without editing native core. |
| LDF source values | Pass | Default LDF now resolves to `[8.89e-2; 1.24e-2] s^-1` in H2/CO2 order unless intentionally overridden. |
| 16-slot native schedule | Pass | The schedule structure, column offsets, equalization pair sequence, and explicit donor/receiver flow directions match the implementation guide. |
| Direct native runner | Pass | `runRibeiroSurrogate.m` builds params, applies schedule, and calls `runPsaCycle(params)` directly unless `StopAfterBuild` is true. |
| Eq. 2/Eq. 3-style metrics | Mostly pass | The code now computes final-cycle feed-step product, pressurization H2 use, purge H2 use, purity, recovery, and raw signed counters. It still needs expected-vs-achieved source-flow checks before validation-facing interpretation. |
| Feed-flow realization | **Fail / unverified** | `params.volFlowFeed` is set to the source-converted `~544.5 cm^3/s`, but the actual feed into columns is valve-driven. The summary does not yet report achieved feed moles against the expected source moles. |
| Purge-flow realization | **Fail / unverified** | Ribeiro Table 5 purge flow and ratio are stored, but purge is also valve-driven with the same broad CV. The summary reports achieved `purgeToFeedH2Ratio` but not the expected binary/full-source reference values or mismatch. |
| Runtime artifact evidence | Fail / stale | The included `diagnostic_outputs/ribeiro_surrogate_smoke/summary.md` is a build-only run with `NaN` metrics and an older fallback-metric caveat. It is not evidence of current Batch 8 non-build behavior. |
| Soft-verification readiness | Not yet | Ready after the small flow-accounting patch and a non-build summary showing finite, physical, source-scale final-cycle counters. |

---

## What is now correct enough to keep

### 1. Source-basis constants

`ribeiroSurrogateConstants.m` is now in good shape for the intended binary activated-carbon surrogate:

- H2/CO2 order is explicit.
- Full source feed is stored as H2/CO2/CH4/CO/N2 = `0.733/0.166/0.035/0.029/0.037`.
- Binary feed is the H2/CO2 renormalization: `[0.8153503893; 0.1846496107]`.
- Feed flow is stored as `12.2 N m^3/h` and `0.1513 mol/s`.
- Pressure basis is `bar_abs`, with `7` high and `1` low.
- Activated-carbon Table 4 H2/CO2 values are in H2/CO2 order.
- Activated-carbon Table 6 LDF values are now in H2/CO2 order.
- Purge source reference is present: `3.5 N m^3/h`, source purge/full-feed H2 ratio `0.097`.

No source-basis rework is needed here unless the project target changes from the binary AC surrogate to Ribeiro's full five-component layered-bed model.

### 2. Effective isothermal MSL coefficient

The previous assessment flagged that using `K_inf` directly in isothermal native mode would under-apply Ribeiro Table 4, especially for CO2. The current builder now does the right local adaptation for this surrogate:

```matlab
params.KCSourceKInfBarInv = basis.adsorbent.multisiteLangmuir.kInfPaInv * 1e5;
params.KC = calcEffectiveIsothermalKCBasis(basis);
...
kEffBarInv = aFactor .* kInfBarInv .* heatFactor;
```

Approximate current effective values are:

| Component | Effective `KC` at 303 K, bar^-1 |
|---|---:|
| H2 | `1.18e-3` |
| CO2 | `6.58e-1` |

This is the patch the prior assessment requested. Do not edit native `funcMultiSiteLang.m`; keeping the adaptation local to the Ribeiro builder is the right deadline choice.

### 3. Schedule

`buildRibeiroNativeSchedule.m` remains one of the strongest parts of the implementation. It uses:

```text
FEED x4, EQ_D1 x2, EQ_D2 x2, BLOWDOWN x1, PURGE x1,
EQ_P1 x2, EQ_P2 x2, PRESSURIZATION x2
```

with offsets `[0; 4; 8; 12]`. It validates exactly one feed bed per native slot and exactly two equalizing columns in each equalization slot. The equalization pair sequence is the guide sequence:

```text
B-D, B-D, C-D, C-D, A-C, A-C, A-D, A-D,
B-D, B-D, A-B, A-B, A-C, A-C, B-C, B-C
```

The mapping also correctly avoids native `getStringParams` inference and explicitly sets receiver equalizations to product-end/counter-current direction.

Do not spend time replacing this with a sequential four-bed wrapper.

### 4. Metrics scaffolding

`computeRibeiroExternalMetrics.m` now computes the intended final-cycle counter groups:

- `feedMolesFinalCycle`
- `feedStepProductMolesFinalCycle`
- `h2UsedForPressurizationFinalCycle`
- `h2UsedForPurgeFinalCycle`
- signed raw pressurization and purge product-end counters
- `ribeiroEq2PurityH2`
- `ribeiroEq3RecoveryH2`
- `purgeToFeedH2Ratio`

This is a major improvement over the old fallback product-counter metric. Keep it. The missing piece is not a new metric framework; it is an expected-vs-achieved source-flow gate.

---

## Remaining high-priority issues

### RIB-FLOW-01 — Source feed flow is not yet proven as actual feed processed

The builder computes and stores the Ribeiro feed flow correctly:

```matlab
params.volFlowFeed = basis.feed.totalVolumetricFlowCm3Sec;
```

For `0.1513 mol/s`, `303 K`, and `7 bar_abs`, this is about `544.5 cm^3/s`. However, in native toPSAil this value is also used as a scaling basis. It is not, by itself, a hard feed-flow controller for the `HP-FEE-RAF` column boundary.

The native route is valve-driven:

- `HP-FEE-RAF` uses `calcVolFlowFeTa2ValTwo` at the feed end.
- `calcVolFlowFeTa2ValTwo` computes flow from the feed-tank/column concentration-pressure difference and `params.valFeedColNorm`.
- `applyRibeiroNativeSchedule.m` sets `params.valFeedCol = nativeValveCoefficient * ones(4,16)` and `params.valProdCol = nativeValveCoefficient * ones(4,16)`.
- The feed tank is replenished to maintain pressure; `getFeedMolCycle` then reports actual feed delivered to the system.

Therefore, the branch can report the source feed flow in metadata and still process a materially different amount of feed in the final cycle.

**Why this matters:** every purity/recovery comparison becomes misleading if the final-cycle feed moles are not close to the source-scale feed moles.

For the default `TFeedSec = 40`, one four-bed global cycle is `160 s`. The expected source-scale final-cycle feed is:

| Quantity | Expected value |
|---|---:|
| Total feed per global cycle | `24.208 mol` |
| Binary-surrogate H2 feed per global cycle | `19.7380 mol` |
| Full-source H2 feed per global cycle | `17.7445 mol` |

`summary.feedMolesFinalCycle` must be compared against `[19.7380, 4.4700] mol` in H2/CO2 order for the binary surrogate. If it is not close, the results are not ready for soft verification.

### RIB-PURGE-02 — Purge source basis is stored, but purge is not source-calibrated

Ribeiro Table 5 uses a purge flow of `3.5 N m^3/h` and reports purge/feed ratio `0.097` using the full five-component feed's H2 denominator. In the binary-renormalized surrogate, the expected ratio under the current `purgeToFeedH2Ratio = h2UsedPurge / binaryH2Feed` definition is different.

For `TFeedSec = 40`, four purge slots total `40 s` of pure H2 purge over one global cycle. The expected source purge amount is about:

```text
3.5 N m^3/h -> 0.04338 mol/s H2
0.04338 mol/s * 40 s -> 1.735 mol H2 per global cycle
```

That gives:

| Denominator | Expected purge/H2-feed ratio |
|---|---:|
| Full-source H2 feed denominator | `0.0978`, matching the Table 5 `0.097` basis |
| Binary-surrogate H2 feed denominator | `0.0879` |

The current summary reports only the achieved binary-style ratio. It should also report the expected binary and source-reference ratios so the comparison is not confused.

**Why this matters:** if the achieved purge/feed ratio is too high, recovery will be depressed; if it is too low, purity will be depressed. A single all-purpose valve coefficient cannot reliably satisfy feed, purge, pressurization, and equalization behavior simultaneously.

### RIB-METRIC-03 — Eq. 3 recovery is now present, but still needs hard validation flags

The Eq. 3-style recovery now subtracts:

```matlab
abs(pressurizationSigned(1)) + abs(purgeSigned(1))
```

from feed-step product H2. That is reasonable for the native sign convention because native column `cumMol.prod` is signed at the product end. The code also reports the raw signed counters, which is good.

However, for soft verification, this should be treated as a hard gate, not just a warning:

- Eq. 2 purity must be finite and in `[0,1]`.
- Eq. 3 recovery must be finite and in `[0,1]`.
- Feed moles must be close to expected source-scale feed moles.
- Purge/feed ratio must be reported against both binary and full-source reference bases.

Do not add a ledger. Just add the source-scale expected values, relative errors, and warning strings to the existing summary.

### RIB-ARTIFACT-04 — Included diagnostic summary is stale and build-only

The included `diagnostic_outputs/ribeiro_surrogate_smoke/summary.md` says:

```text
StopAfterBuild was true; no native simulation was run.
```

and all metrics are `NaN`. It also contains the old fallback-metric caveat, not the current Eq. 2/Eq. 3 metric basis. This artifact should not be used as evidence of current model behavior.

The next generated summary should be a non-build run summary after the flow-accounting patch. It does not need plots, CSVs, or a validation folder.

### RIB-IC-05 — Initial states remain a scaffold

`finalizeRibeiroSurrogateTemplateParams.m` still sets:

```matlab
params.inConBed = ones(params.nCols, 1);
```

Native `getInitialStates` interprets this as feed-saturated high-pressure beds. Ribeiro's four-column setup starts columns filled with hydrogen at feed temperature and at the zero-time pressure of each column's first step. This does not block long CSS-oriented soft verification, but it does mean early-cycle results should not be interpreted. If a short run is used only for runtime smoke, label it as such.

### RIB-PURGE-DAE-06 — Purge constant-pressure workaround should be monitored

The schedule sets `LP-ATM-RAF` purge to `typeDaeModel = 0`, while most pressure-changing steps remain varying-pressure. The notes explain this as a native compatibility workaround. It is acceptable for now, but soft verification should inspect whether purge slots actually sit near the low-pressure basis after blowdown.

Do not change this unless pressure traces show purge is materially wrong.

---

## Minimal Codex patch before soft verification

Keep this patch narrow. No Yang code, no tests, no plots, no new validation framework.

### Patch 1 — Add expected source-flow counters to `computeRibeiroExternalMetrics.m`

Add fields like:

```matlab
metrics.expectedFeedMolesFinalCycle = NaN(1, params.nComs);
metrics.expectedTotalFeedMolesFinalCycle = NaN;
metrics.expectedBinaryH2FeedMolesFinalCycle = NaN;
metrics.expectedFullSourceH2FeedMolesFinalCycle = NaN;
metrics.feedMolesRelativeError = NaN(1, params.nComs);
metrics.totalFeedMolesRelativeError = NaN;
metrics.expectedSourcePurgeH2MolesFinalCycle = NaN;
metrics.expectedPurgeToBinaryFeedH2Ratio = NaN;
metrics.expectedPurgeToFullSourceFeedH2Ratio = NaN;
metrics.purgeToBinaryFeedH2RatioError = NaN;
```

Compute them with the source basis already in `params.ribeiroBasis`:

```matlab
cycleTimeSec = 4 * params.tFeedSec;
expectedTotalFeed = params.ribeiroBasis.feed.totalMolarFlowMolSec * cycleTimeSec;
expectedBinaryFeed = expectedTotalFeed * params.ribeiroBasis.feed.moleFractions(:).';
expectedBinaryH2Feed = expectedBinaryFeed(1);
expectedFullSourceH2Feed = expectedTotalFeed * params.ribeiroBasis.feed.fullSourceMoleFractions(1);

normalMolarVolM3PerKmol = 22.414; % consistent with source Nm3/h conversion
sourcePurgeMolSec = params.ribeiroBasis.purge.sourceFlowNm3Hr ...
    / 3600 / normalMolarVolM3PerKmol * 1000;
expectedSourcePurgeH2 = sourcePurgeMolSec * params.tFeedSec; % four purge slots total tFeedSec

expectedPurgeToBinary = expectedSourcePurgeH2 / expectedBinaryH2Feed;
expectedPurgeToFullSource = expectedSourcePurgeH2 / expectedFullSourceH2Feed;
```

Add warnings when:

```matlab
abs(sum(feedMol) - expectedTotalFeed) / expectedTotalFeed > 0.05
abs(feedMol(1) - expectedBinaryH2Feed) / expectedBinaryH2Feed > 0.05
abs(metrics.purgeToFeedH2Ratio - expectedPurgeToBinary) > 0.02
```

Use tolerances as gates for the first soft-verification attempt, not as permanent scientific criteria.

### Patch 2 — Surface those fields in `summarizeRibeiroRun.m` and `writeRibeiroRunSummary.m`

Add the expected/achieved values to the summary. The Markdown summary should include at least:

```text
- Expected total feed, final cycle:
- Achieved total feed, final cycle:
- Total feed relative error:
- Expected binary H2 feed, final cycle:
- Achieved binary H2 feed, final cycle:
- Expected source purge H2, final cycle:
- Achieved purge H2, final cycle:
- Expected purge/H2-feed ratio, binary denominator:
- Achieved purge/H2-feed ratio, binary denominator:
- Source Table 5 purge/H2-feed ratio, full-source denominator:
```

This is the fastest way to determine whether the results are off because the physics/model are wrong or simply because the native valve flows do not match the Ribeiro basis.

### Patch 3 — Only if flow mismatch is confirmed, add operation-specific valve knobs

If achieved feed or purge is materially wrong, do not overhaul the model. Add only a small valve patch:

- Keep `NativeValveCoefficient` as the default fallback.
- Add optional `FeedValveCoefficient` and `PurgeValveCoefficient` inputs.
- In `applyRibeiroNativeSchedule.m`, after creating the 4x16 valve matrices, override:
  - feed-end valves for `HP-FEE-RAF` slots with `FeedValveCoefficient`
  - product-end valves for `LP-ATM-RAF` slots with `PurgeValveCoefficient`

Do not add a full calibration framework. A two-scalar sweep/adjustment is enough for this checkpoint. Equalization and pressurization coefficients can remain at the existing default unless pressure traces show a specific issue.

---

## Soft-verification acceptance checks after the patch

### Static/source checks

- `basis.feed.moleFractions = [0.8153503893; 0.1846496107]` and sums to one.
- `basis.feed.totalMolarFlowMolSec = 0.1513`.
- `params.volFlowFeed ≈ 544.5 cm^3/s` at 7 bar and 303 K.
- `params.presColHigh = 7`, `params.presColLow = 1`.
- `params.radInCol = 10 cm`, `params.heightCol = 100 cm`, `params.voidFracBed = 0.38`.
- `params.qSatC`, `params.aC`, and effective `params.KC` are documented in H2/CO2 order.
- `params.ldfMtc = [0.0889; 0.0124]` unless intentionally overridden.

### Schedule checks

- Four columns and sixteen native slots.
- Exactly one feed bed in every slot.
- Equalization slots have exactly two paired columns.
- Equalization pair sequence remains `B-D, B-D, C-D, C-D, A-C, A-C, A-D, A-D, B-D, B-D, A-B, A-B, A-C, A-C, B-C, B-C`.
- `getStringParams` remains intentionally skipped.

### Runtime source-scale checks

For `TFeedSec = 40`:

- Achieved total final-cycle feed is near `24.208 mol`.
- Achieved final-cycle binary H2 feed is near `19.738 mol`.
- Achieved final-cycle purge H2 is reported; if source-calibrated, it should be near `1.735 mol`.
- Achieved binary-denominator purge/H2-feed ratio is reported and compared to `~0.0879`.
- Source-reference full-feed purge/H2-feed ratio is reported and compared to `~0.0978` / Table 5 `0.097`.

### Metric checks

- `ribeiroEq2PurityH2` is finite and in `[0,1]`.
- `ribeiroEq3RecoveryH2` is finite and in `[0,1]`.
- No fallback recovery greater than one is used or reported as validation evidence.
- Raw signed product-end counters remain visible for audit.

### Interpretation limit

Passing these checks means only:

> the binary H2/CO2 activated-carbon native surrogate is source-basis consistent, flow-scale checked, and stable enough for first soft verification.

It does **not** mean the code reproduces Ribeiro's full five-component layered activated-carbon/zeolite, non-isothermal multicolumn result.

---

## Items I cannot retrieve or determine from the static repo

1. **Current non-build numerical results.** The ZIP includes only a build-only Ribeiro summary with `NaN` metrics. I cannot verify the user's current run results, achieved feed moles, achieved purge ratio, pressure traces, or final recovery from the included artifacts.
2. **Git diff against `develop`.** The ZIP has no `.git` history, so I cannot prove no native core files changed relative to the true base branch. I can only say I found no active Ribeiro-named code under native core and the active implementation file set is scoped correctly.
3. **Whether the intended soft-verification target has changed.** The guide and notes define the target as a binary H2/CO2 activated-carbon surrogate, not full Ribeiro paper reproduction. If the target is now numerical closeness to the full five-component layered AC/zeolite result, the current model scope is insufficient by design.
4. **Whether there is project-specific evidence overriding the Table 4 temperature convention.** Based on the visible paper equation and native code, the current effective-isothermal `KC` adaptation is the right local patch. If another source-table extract or project note says otherwise, that source should be added.

---

## Recommended decision

Proceed with the current architecture. Make only the flow-accounting patch first. If the achieved source feed and purge flows are off, add only operation-specific feed/purge valve coefficients and adjust those two values. Then regenerate one non-build `summary.md`/`summary.mat` with final-cycle Eq. 2/Eq. 3 counters and expected-vs-achieved flow checks.

Do not spend time on Yang wrappers, test suites, plotting, native core rewrites, or full-paper reproduction before this checkpoint.
