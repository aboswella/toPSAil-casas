# Ribeiro Surrogate Implementation Notes

## Current Soft-Verification State

- Current canonical smoke artifact: `diagnostic_outputs/ribeiro_surrogate_current_gate/summary.md` generated with `BoundaryMode = ribeiro_fixed_non_eq`, `NVols = 3`, `NCycles = 3`, `NTimePoints = 2`, and `TFeedSec = 40`.
- Pressure gate status: passing in that smoke artifact. The final-cycle max pressure errors are about `0.152 bar` for feed/high, `0.447 bar` for blowdown/purge low, and `0.338 bar` for pressurization.
- Feed/purge gate status: passing in that smoke artifact. The active binary feed boundary delivers `24.208 mol/cycle`, and the pure-H2 purge boundary delivers `1.7350 mol/cycle`.
- CSS gate status: not passed in the three-cycle smoke artifact. Purity drift is still about `0.0178` absolute from cycle 2 to cycle 3, so the values are transient smoke results, not validation-grade performance.
- Comparison scope: the active model form is `binary_ac_surrogate`. It is not directly comparable to Ribeiro's full five-component, layered, non-isothermal target of `0.999958` H2 purity and `0.5211` H2 recovery.
- Productivity scope: the summary reports an AC-only productivity diagnostic from the Eq. 3 net H2 product and the four-bed activated-carbon mass. It is marked non-comparable to Ribeiro's layered AC/zeolite productivity target.

The active boundary-cap default is now resolved in the boundary options: callers may request `Inf` explicitly, but leaving `MaxBoundaryMolarFlowMolSec` empty uses the finite effective default of `0.5 mol/s`. Summaries print both `maxBoundaryMolarFlowMolSecRequested` and `maxBoundaryMolarFlowMolSecEffective`.

The active feed basis defaults to `full_total_renormalized_binary`, which keeps the full `12.2 N m^3/h` total source flow and uses renormalized H2/CO2 mole fractions. The alternate `source_h2co2_partial_flow` mode keeps only Ribeiro's H2 and CO2 partial molar flows while dropping CH4/CO/N2 from the active binary total.

Two lightweight follow-up helpers are available but were not used for a long validation run in the current smoke pass:

- `scripts/ribeiro_surrogate/runRibeiroConvergenceSweep.m` runs the pressure-gated `NVols = [3, 8, 16, 32]` sweep when explicitly requested.
- `scripts/ribeiro_surrogate/auditRibeiroIsothermBasis.m` checks H2/CO2 ordering, LDF ordering, and the Ribeiro Table 4 `K_inf` to native effective `KC` conversion.

## Batch 0 Bootstrap

- Active guide: `Overall Implementation Guide.md`.
- Active source of truth for Ribeiro values: `sources/Ribeiro 2008.pdf`.
- Yang paper and scripts under `sources/` are reference-only material for native toPSAil patterns.
- Do not import Yang cycle labels, adapters, diagnostics, ledgers, wrapper architecture, or tests.
- Batch 0 creates only repository instructions and this notes file.

## Baseline Scope

- Minimal binary H2/CO2 activated-carbon surrogate.
- Native toPSAil machinery wherever possible.
- Four columns, eight logical steps per column, and sixteen native schedule slots.
- Feed composition `[0.8153503893; 0.1846496107]`.
- Feed flow about `0.1513 mol/s`, from Ribeiro Table 5 `12.2 N m^3/h`.
- Pressure basis `bara`, with `7 bara` high pressure and `1 bara` low pressure.

## Batch 1 Constants

`params/ribeiro_surrogate/ribeiroSurrogateConstants.m` defines the source-backed constants for the first Ribeiro surrogate. This is not a full Ribeiro reproduction. Ribeiro's full paper uses a five-component H2/CO2/CH4/CO/N2 feed, layered activated-carbon/zeolite beds, and a full dynamic non-isothermal model. This branch starts with a dry binary H2/CO2 activated-carbon surrogate for speed.

The source paper's objective is high-purity hydrogen production. The constants keep that target context while limiting the first implementation to the H2/CO2 activated-carbon subset, the Table 5 feed renormalization, and the pressure basis recorded in the active guide.

No native schedule was built in batch 1.

## Batch 2 Parameter Builder

`params/ribeiro_surrogate/buildRibeiroSurrogateTemplateParams.m` and `params/ribeiro_surrogate/finalizeRibeiroSurrogateTemplateParams.m` create an Excel-free native four-column parameter struct for the binary activated-carbon surrogate.

The builder converts Ribeiro Table 5 `12.2 N m^3/h` through the batch 1 molar-flow basis, using `R = 83.14 cm^3 bar mol^-1 K^-1`, `T = 303 K`, `P = 7 bar_abs`, and `n = 0.1513 mol/s`, which gives a native feed flow of about `545 cm^3/s`.

Particle values are stored in native-compatible units for later runtime use: particle density `842 kg/m^3` becomes `8.42e-4 kg/cm^3` as `params.pellDens`, and particle radius `1.17e-3 m` becomes pellet diameter `0.234 cm` as `params.diamPellet`. Particle porosity `0.566` is retained as a dimensionless particle-porosity field; the current batch uses `maTrRes = 0`, so the material-balance overall void remains the bed void fraction `0.38`.

Ribeiro Table 4 multisite Langmuir `k_inf` values are stored in the basis as `Pa^-1`. The original batch only converted `k_inf` to `bar^-1`; Batch 8 supersedes that with the effective isothermal native coefficient documented below.

The finalizer initializes the default valve placeholders before calling `getDimLessParams` because native toPSAil reads `valFeedCol` and `valProdCol` during dimensionless setup. These are placeholders only; no Ribeiro native schedule is built in batch 2.

## Later Notes

## Batch 3 Native Schedule

`scripts/ribeiro_surrogate/buildRibeiroNativeSchedule.m` builds the direct native 4-column, 16-slot schedule. The slot size is `tfeed/4`; feed and pressurization occupy four and two base slots respectively, while blowdown and purge occupy one base slot each. Product-end equalizations are represented with native `EQ-XXX-APR` pairs and explicit donor/receiver flow directions instead of relying on `getStringParams`.

`scripts/ribeiro_surrogate/applyRibeiroNativeSchedule.m` writes the schedule directly into `params.sStepCol`, `params.typeDaeModel`, `params.flowDirCol`, `params.numAdsEqPrEnd`, and `params.numAdsEqFeEnd`, then calls the downstream native setup sequence.

## Batch 4 Runner

`scripts/ribeiro_surrogate/runRibeiroSurrogate.m` is the single-command entry point. It builds params, builds the schedule, applies it, and calls native `runPsaCycle(params)` unless `StopAfterBuild` is true.

## Batch 5 Metrics

`scripts/ribeiro_surrogate/summarizeRibeiroRun.m` reports native toPSAil H2 purity/recovery plus Ribeiro-surrogate final-cycle H2 purity/recovery counters. The original batch used provisional external product counters and could fall back to feed-step product-end counters when the native external product counter was zero.

## Batch 6 Robustness Fixes

The Batch 2 runtime finalizer now seeds native column names, initial-condition selectors, standard pressure/temperature, and ideal isentropic efficiencies because those fields are needed once native cycle execution reaches `getInitialStates`, compressor work, vacuum work, and boundary-flow calculations.

Native toPSAil does not define a varying-pressure `getVolFlowFuncHandle` branch for `LP-ATM-RAF`; that branch exists under the constant-pressure DAE path. The Ribeiro purge slots therefore use native `LP-ATM-RAF` with `typeDaeModel = 0` while the other pressure-changing slots remain varying-pressure. This is a native-runtime compatibility choice, not a Ribeiro source claim.

## Batch 7 Optional Output

`scripts/ribeiro_surrogate/writeRibeiroRunSummary.m` writes only `summary.md` and `summary.mat` to a requested output directory. It does not create validation reports or plots.

## Batch 8 Source-Basis And Metrics Fixes

`params/ribeiro_surrogate/ribeiroSurrogateConstants.m` now includes Ribeiro Table 6 activated-carbon LDF coefficients in H2/CO2 order, `[8.89e-2; 1.24e-2] 1/s`, and the Table 5 purge-flow reference basis.

`params/ribeiro_surrogate/buildRibeiroSurrogateTemplateParams.m` now adapts Ribeiro Table 4 multisite Langmuir constants to the native isothermal path as an effective 303 K coefficient:

```matlab
KC = a_i * k_inf(Pa^-1) * 1e5 * exp(deltaH_i / (R * T))
```

This keeps native `funcMultiSiteLang` unchanged. The `a_i` multiplier is included in `KC` because native toPSAil uses `aC` as the vacancy exponent but does not otherwise multiply by Ribeiro Eq. (1)'s `a_i`. The heat factor is included because the current surrogate runs with `bool(5) = 0`, so native non-isothermal temperature scaling is not applied at runtime. Approximate H2/CO2 effective values are `1.18e-3` and `6.58e-1 bar^-1`.

`LdfMassTransferPerSec` may now be empty, scalar, or a two-element H2/CO2 vector. Empty/default uses Ribeiro Table 6; scalar overrides are expanded to both components for commissioning-style runs.

`scripts/ribeiro_surrogate/computeRibeiroExternalMetrics.m` now reports final-cycle Ribeiro Eq. 2/Eq. 3-style counters. Eq. 3 subtracts the magnitude of H2 crossing the product end during pressurization and purge because native column cumulative-flow signs can differ across DAE paths; the signed raw counters are retained for audit.

- `feedMolesFinalCycle`
- `feedStepProductMolesFinalCycle`
- `h2UsedForPressurizationFinalCycle`
- `h2UsedForPurgeFinalCycle`
- `ribeiroEq2PurityH2`
- `ribeiroEq3RecoveryH2`
- `purgeToFeedH2Ratio`
- signed raw product-end counters for pressurization and purge

The older summary fields `ribeiroProductPurityH2` and `ribeiroProductRecoveryH2` are retained as aliases to the Eq. 2/Eq. 3 surrogate metrics.

## Batch 9 Flow-Scale Audit And Valve Knobs

`scripts/ribeiro_surrogate/computeRibeiroExternalMetrics.m` now adds expected-vs-achieved final-cycle source-flow counters before interpreting validation-facing metrics. The expected feed scale uses the Ribeiro Table 5 molar feed flow, `tcycle = 4*tfeed`, and the binary H2/CO2 renormalized composition. The expected purge scale uses the Ribeiro Table 5 `3.5 N m^3/h` H2 purge reference and reports both the binary-denominator purge/H2-feed ratio and the full-source-denominator ratio used by Table 5.

The summary now reports:

- expected and achieved total feed moles in the final cycle
- expected and achieved binary H2 feed moles in the final cycle
- component feed relative errors
- expected and achieved purge H2 moles in the final cycle
- expected and achieved purge/H2-feed ratio on the binary denominator
- expected/source Table 5 purge/H2-feed ratio on the full-source denominator

Warnings are added when the achieved total feed or binary H2 feed differs from source scale by more than `5%`, or when the achieved binary-denominator purge/H2-feed ratio differs from the source reference by more than `0.02` absolute ratio points. These are first soft-verification gates, not permanent scientific tolerances.

`NativeValveCoefficient` remains the fallback valve coefficient. `FeedValveCoefficient` and `PurgeValveCoefficient` are scalar knobs for the source-flow checkpoint: `FeedValveCoefficient` applies only to feed-end valves on `HP-FEE-RAF` slots, while `PurgeValveCoefficient` applies only to product-end valves on `LP-ATM-RAF` slots. Equalization and pressurization valves remain on the fallback coefficient unless a later pressure-trace audit proves a separate need.

The default source-flow calibration values are `FeedValveCoefficient = 4.65e-3` and `PurgeValveCoefficient = 8.0e-4`, with `NativeValveCoefficient = 1e-6` retained for the remaining valves. These Cv values are native calibration knobs, not Ribeiro paper constants. A one-cycle `NCycles=1`, `NVols=3`, `NTimePoints=2`, `TFeedSec=40` smoke run with those defaults processed about `24.08 mol` total feed versus the `24.208 mol` source-scale target, and reported a binary-denominator purge/H2-feed ratio about `0.0843` versus the `0.0879` source reference.

## Historical Smoke Runs

- Before the Batch 8 source-basis and metric fixes, `runRibeiroSurrogate("NCycles", 1, "NVols", 3, "NTimePoints", 2, "TFeedSec", 40)` completed all 16 native slots. Native tank H2 purity was `NaN` and recovery was `0` because the external raffinate product counter was zero; the old fallback purity was about `0.8159` and recovery about `1.0007`.
- Before the Batch 8 source-basis and metric fixes, `runRibeiroSurrogate("NCycles", 5, "NVols", 4, "NTimePoints", 2, "TFeedSec", 40)` completed all 5 cycles. Native and old Ribeiro-surrogate H2 purity were both about `0.9964`, recovery was about `0.2171`, and final CSS was about `3.34e-05`.
- These runs are smoke checks only. They are not paper validation and should not be interpreted as reproduction of Ribeiro's full five-component layered model.

## Audit Gaps And Uncertainties

- Initial bed states are placeholders: all beds start as high-pressure feed-saturated columns. This is native-runnable scaffolding, not a paper-derived four-bed cyclic state.
- Product-end pressurization uses `RP-XXX-RAF`, meaning H2-rich raffinate tank gas. This matches the guide's first-pass surrogate choice but is not a proven Ribeiro-equivalent pressurization model.
- The fallback native valve coefficient remains `1e-6`, while feed and purge use calibrated source-flow defaults. No source-backed valve sizing has been recovered; these are native calibration knobs.
- LDF mass transfer now defaults to Ribeiro Table 6 H2/CO2 values. A scalar commissioning override is still accepted when intentionally requested.
- Tank dimensions reuse the column dimensions for a minimal native runtime. Source-backed tank volumes have not been recovered.
- External Ribeiro metrics are now final-cycle Eq. 2/Eq. 3-style counters with signed raw product-end counter output. The native sign convention is still an audit item if future schedule changes alter counter signs.
- The surrogate is binary H2/CO2 activated carbon only. It deliberately omits Ribeiro's CH4/CO/N2, zeolite layer, water, and full non-isothermal model.

## Batch 10 Boundary-Condition Overlay

Batch 10 adds a Ribeiro-specific boundary mode, `ribeiro_fixed_non_eq`, while keeping the native four-bed, sixteen-slot schedule intact. The prior native valve mode is retained as `native_valves` for comparisons.

`scripts/ribeiro_surrogate/applyRibeiroBoundaryConditions.m` is called immediately after `getColBoundConds(params)` in `applyRibeiroNativeSchedule.m`. It saves the native `funcVol`, `funcVolUnits`, `volFlBo`, and `volFlBoFree` handles for audit, then overrides only non-equalization boundary flow handles:

- `HP-FEE-RAF`: fixed Ribeiro Table 5 feed molar flow at the feed end.
- `DP-ATM-XXX`: fixed 1 bar sink with a pressure-relief controller gain.
- `LP-ATM-RAF`: fixed Ribeiro Table 5 pure-H2 purge molar flow at the product end.
- `RP-XXX-RAF`: fixed pure-H2 product-end pressurization source with a high-pressure controller gain.
- `EQ-XXX-APR`: unchanged native column-to-column equalization.

`calcRibeiroVolFlowsWithFixedBoundaries.m` wraps the saved native volumetric-flow model. Before native flow calculation it calls `applyRibeiroBoundaryCompositionOverrides.m`, which imposes fixed feed, pure-H2 purge, pure-H2 pressurization, and local inert blowdown boundary compositions without altering equalization compositions.

The new runner/builder options are:

- `BoundaryMode`, default `ribeiro_fixed_non_eq`.
- `BlowdownGainMolSecBar`, current default `0.30` when empty.
- `PressurizationGainMolSecBar`, current default `0.18` when empty.
- `MaxBoundaryMolarFlowMolSec`, superseded by the current resolver described above: empty means an effective finite cap of `0.5 mol/s`; explicit `Inf` remains available for diagnostics only.

The blowdown and pressurization gains are numerical pressure-endpoint controller gains only. They are not Ribeiro source constants and should not be tuned against purity or recovery.

The summary now records `boundaryMode`, `boundaryModeBasis`, `feedBoundaryBasis`, `purgeBoundaryBasis`, `blowdownBoundaryBasis`, `pressurizationBoundaryBasis`, and `equalizationBoundaryBasis`. For the validation-facing default, `equalizationBoundaryBasis` is `native column-to-column EQ-XXX-APR retained`.

The pre-existing pressure audit scaffold remains available as `scripts/ribeiro_surrogate/computeRibeiroPressureAudit.m`; its earlier native-valve findings are historical diagnostics for why this boundary override was needed.

## Batch 11 Boundary Accounting And Pressure Gates

Batch 11 adds validation-facing Ribeiro boundary accounting for `BoundaryMode = ribeiro_fixed_non_eq`. The old native tank counters are no longer used as the Ribeiro Eq. 2/Eq. 3 feed/product basis in that mode; they remain diagnostic only.

`scripts/ribeiro_surrogate/computeRibeiroBoundaryMetrics.m` computes the final-cycle accounting denominator from the prescribed Ribeiro Table 5 binary feed:

```matlab
expectedFeed = feed.totalMolarFlowMolSec * (4*tfeed) * feed.moleFractions(:).'
```

Ribeiro Eq. 2 H2 purity uses H2 divided by total gas leaving the product end during `HP-FEE-RAF` slots. Ribeiro Eq. 3 H2 recovery subtracts the absolute H2 crossing the product end during `RP-XXX-RAF` pressurization and `LP-ATM-RAF` purge from the feed-step H2 product, then divides by prescribed binary H2 feed.

`scripts/ribeiro_surrogate/getRibeiroColumnStepCounterMoles.m` is the shared final-cycle counter extractor. It reads `sol.Step*.col.n*.cumMol.prod(end,:)` or `.feed(end,:)`, groups by native step label, and dimensionalizes with `params.nScaleFac`.

`scripts/ribeiro_surrogate/getRibeiroPressureAudit.m` reports first-pass pressure gates on final-cycle endpoint pressures:

- feed/high-pressure steps near `7 bara`
- blowdown and purge steps near `1 bara`
- pressurization endpoint near `7 bara`

The audit reports per-column endpoint pressures and max gate errors as `maxFeedPressureErrorBar`, `maxLowPressureErrorBar`, and `maxPressurizationErrorBar`. These gates are pressure/source-basis soft verification checks only; passing them does not make the binary activated-carbon surrogate a reproduction of Ribeiro's full five-component, layered, non-isothermal model.

`writeRibeiroRunSummary.m` now labels the source-feed denominator as accounting feed, reports boundary-counter purge H2 with its relative error against the analytical source purge, and states that native toPSAil tank metrics are diagnostic only under the fixed Ribeiro boundary mode.

## Batch 12 Native Equalization Opening

Batch 12 opens native product-end equalization from the old fallback `1e-6` to `2e-5` by default. Equalization remains native `EQ-XXX-APR`; this coefficient is a pressure-staging knob for the binary surrogate, not a Ribeiro source constant.

## Batch 13 Fixed-Boundary Pressure Defaults

Batch 13 changes only active fixed-boundary pressure controller defaults. In `ribeiro_fixed_non_eq`, blowdown and pressurization valve coefficients are not the active pressure knobs; `BlowdownGainMolSecBar`, `PressurizationGainMolSecBar`, and `MaxBoundaryMolarFlowMolSec` are.

The initial `0.15` blowdown-gain smoke still left the low-pressure gate high, so the Batch 13 follow-up set the default blowdown gain to `0.25`. A subsequent local adjustment moved the default blowdown gain to `0.30` to clear the remaining low-pressure gate. The follow-up pressurization smoke still left the high-pressure gate low, so the default pressurization gain is `0.18`; the controller cap remains `0.5 mol/s`.

## Batch 14 Column Feed-Boundary Audit

Batch 14 reports the prescribed Ribeiro source-feed denominator separately from the actual native column feed-end boundary counter. The Eq. 3 accounting denominator remains the prescribed Table 5 binary source feed, while validation-facing achieved-feed fields now use the final-cycle `HP-FEE-RAF` feed-end counter with native sign convention corrected for gas entering the bed.

## Runtime Defaults

After the Batch 11 pressure-gain sweep proved slow, the Ribeiro runner and builder defaults were reduced to smoke-run settings:

- `NCycles = 1`
- `NVols = 3`
- `NTimePoints = 2`

Longer soft-verification cases should be requested explicitly, for example `NCycles = 20, NVols = 4`. The smaller defaults are intended to keep future iteration from accidentally launching a multi-cycle validation run.
