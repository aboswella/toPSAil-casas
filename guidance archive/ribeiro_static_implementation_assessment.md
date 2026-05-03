# Ribeiro Surrogate Static Implementation Assessment

**Assessment target:** Codex autonomous batch implementation in `Batches partial complete.zip`  
**Assessment mode:** Static repository review plus source/notes cross-check. I did **not** rerun MATLAB/toPSAil because no MATLAB/Octave runtime is available in this environment.  
**Primary source basis:** `sources/Ribeiro 2008.pdf`, `Overall Implementation Guide.md`, and `docs/ribeiro_surrogate/IMPLEMENTATION_NOTES.md` / uploaded `IMPLEMENTATION_NOTES.md`.

## Bottom line

The implementation is on the intended architectural path: a minimal, direct-native four-column H2/CO2 activated-carbon surrogate, not a Yang wrapper. The active Ribeiro file set is small, the source-backed feed/pressure/geometry constants are mostly correct, the 16-slot schedule shape matches the guide, and the runner calls native `runPsaCycle(params)` directly.

However, I would **not proceed to soft validation against Ribeiro-derived data using the current output metrics or current adsorption constants exactly as implemented**. The code can be treated as a smoke-run scaffold, but there are three high-priority issues that should be fixed before interpreting purity/recovery trends:

1. **The Ribeiro metrics are not yet Ribeiro Eq. 2/Eq. 3 metrics.** The fallback can produce recovery greater than one and does not subtract H2 consumed in purge/pressurization.
2. **The multisite Langmuir constants are likely under-applied in the native isothermal path.** The code uses Table 4 `K_inf` converted from Pa^-1 to bar^-1, but does not apply the source heat-of-adsorption temperature factor in isothermal mode. It also does not appear to include Ribeiro Eq. (1)'s multiplicative `a_i` factor in native `KC`.
3. **The LDF mass-transfer coefficients are commissioning defaults, not Ribeiro Table 6 values.** For H2/CO2 on activated carbon, the paper provides usable values at the feed inlet condition.

The minimum next step is not a new framework, not a Yang fallback, not tests, and not plots. It is a small source-basis patch plus a final-cycle metrics audit/output patch.

---

## Evidence inspected

### User-provided and repository files

- `Overall Implementation Guide.md`
- `IMPLEMENTATION_NOTES.md` uploaded by user
- `Ribeiro 2008.pdf`
- Extracted repo from `Batches partial complete.zip`
- Active Ribeiro files:
  - `AGENTS.md`
  - `docs/ribeiro_surrogate/IMPLEMENTATION_NOTES.md`
  - `params/ribeiro_surrogate/ribeiroSurrogateConstants.m`
  - `params/ribeiro_surrogate/buildRibeiroSurrogateTemplateParams.m`
  - `params/ribeiro_surrogate/finalizeRibeiroSurrogateTemplateParams.m`
  - `scripts/ribeiro_surrogate/buildRibeiroNativeSchedule.m`
  - `scripts/ribeiro_surrogate/applyRibeiroNativeSchedule.m`
  - `scripts/ribeiro_surrogate/runRibeiroSurrogate.m`
  - `scripts/ribeiro_surrogate/summarizeRibeiroRun.m`
  - `scripts/ribeiro_surrogate/computeRibeiroExternalMetrics.m`
  - `scripts/ribeiro_surrogate/writeRibeiroRunSummary.m`
- Included diagnostic output:
  - `diagnostic_outputs/ribeiro_surrogate_smoke/summary.md`
  - `diagnostic_outputs/ribeiro_surrogate_smoke/summary.mat`

### Limitations of this assessment

I could not verify runtime behavior independently because there is no MATLAB/Octave runtime available here. I also cannot prove the branch diff against `develop` because the zip does not include git history. I can inspect files present in the static repo, but I cannot verify “no native core edits” by diff without the base branch.

The included `diagnostic_outputs/ribeiro_surrogate_smoke/summary.md` is a `StopAfterBuild` summary with all metrics `NaN`. Therefore, I cannot independently verify the implementation notes' reported non-build smoke results of one complete native cycle or five complete cycles from the included artifacts alone.

---

## Gate status

| Gate | Status | Assessment |
|---|---:|---|
| Minimal active file set | Pass, with caveat | Active Ribeiro files match the guide, plus optional `writeRibeiroRunSummary.m`. No active Yang wrapper files were added under `params/` or `scripts/`. |
| Yang quarantine | Mostly pass | Yang scripts remain under `sources/Yang Scripts FOR REFERENCE ONLY/`, which the guide allowed. Old Yang diagnostic CSVs are present under `diagnostic_outputs/`, but `.gitignore` ignores that folder. They are noise in the zip, not active runtime code. |
| Source-backed constants | Mostly pass | Feed composition, pressure, temperature, geometry, activated-carbon Table 4 values, and Table 5 particle values are present and in the right H2/CO2 order. |
| 16-slot native schedule | Pass | The logical phase offsets, feed coverage, equalization pair sequence, and explicit receiver/donor flow directions match the guide. |
| Direct native runner | Pass | `runRibeiroSurrogate.m` builds params, applies schedule, and calls `runPsaCycle(params)` directly. |
| Runtime evidence | Unverified | Notes report successful runs, but included `summary.md`/`summary.mat` are build-only with `StopAfterBuild=true`. |
| Ribeiro metric validity | Fail for validation | Current external metrics are provisional and do not implement Ribeiro recovery Eq. 3. The one-cycle note even reports fallback recovery about `1.0007`, which is a clear sign the fallback is a smoke counter only. |
| Isotherm source fidelity | High risk | Native multisite Langmuir usage appears to omit the Table 4 heat factor in isothermal mode and likely omits the source equation's multiplicative `a_i` factor. |
| Kinetics source fidelity | Medium/high risk | `ldfMtc = 0.05` for both species is a commissioning value; Table 6 gives source values for H2 and CO2 on activated carbon. |
| Soft validation readiness | Not yet | Good scaffold; patch metrics/isotherm/kinetics before interpreting results against Ribeiro data. |

---

## Source-basis checks

### Ribeiro baseline values

The code correctly uses the intended surrogate basis in `ribeiroSurrogateConstants.m`:

- Components: H2/CO2 in H2-first order.
- Full source feed order and mole fractions: H2/CO2/CH4/CO/N2 = 0.733/0.166/0.035/0.029/0.037.
- Binary renormalized H2/CO2 feed: `[0.8153503893; 0.1846496107]`.
- Feed flow: `0.1513 mol/s` from `12.2 N m^3/h`.
- Pressure: 7 bar_abs high, 1 bar_abs low.
- Temperature: 303 K.
- Cycle: 4 beds, 8 logical steps, 40 s feed default, 16 native slots.
- Activated-carbon Table 4 H2/CO2 MSL data in H2/CO2 order:
  - `qMaxMolKg = [23.565; 7.8550]`
  - `a = [1.0; 3.0]`
  - `kInfPaInv = [7.233e-11; 2.125e-11]`
  - `heatOfAdsorptionKJMol = [12.843; 29.084]`
- Activated-carbon Table 5 particle data:
  - `particlePorosity = 0.566`
  - `particleDensityKgM3 = 842`
  - `particleRadiusM = 1.17e-3`

These values align with the implementation guide and the Ribeiro PDF tables. The constants are a solid basis for a source-backed H2/CO2 AC surrogate.

### Feed-flow conversion

`buildRibeiroSurrogateTemplateParams.m` converts the feed molar flow to native volumetric flow using:

```matlab
volFlowCm3Sec = molarFlowMolSec * 83.14 * temperatureK / pressureBarAbs;
```

For `0.1513 mol/s`, `303 K`, and `7 bar_abs`, this gives approximately `545 cm^3/s`. That is consistent with the guide and is using absolute pressure, not gauge pressure.

### Geometry and particle units

The builder uses:

```matlab
params.radInCol = 10.0;      % cm
params.radOutCol = 10.5;     % cm
params.heightCol = 100.0;    % cm
params.voidFracBed = 0.38;
params.pellDens = 842 / 1e6; % kg/cm^3
params.diamPellet = 2 * 1.17e-3 * 100; % cm
```

These conversions are correct for the intended native unit basis. The code also stores particle porosity, but because `maTrRes = 0`, the current material balance uses the bed void fraction as the overall void. This is already called out in the implementation notes and is acceptable for a first native CSTR-in-series surrogate, provided it is not described as Ribeiro's full particle model.

---

## Schedule assessment

`buildRibeiroNativeSchedule.m` is one of the stronger parts of the implementation.

### Correct aspects

The phase vector is:

```text
FEED x4, EQ_D1 x2, EQ_D2 x2, BLOWDOWN x1, PURGE x1,
EQ_P1 x2, EQ_P2 x2, PRESSURIZATION x2
```

with offsets `[0; 4; 8; 12]`, so the four columns are staggered by one feed duration. This gives continuous feed over the 16 native slots.

The native mapping is:

| Logical label | Native step |
|---|---|
| FEED | `HP-FEE-RAF` |
| EQ_D1 / EQ_D2 | `EQ-XXX-APR` |
| BLOWDOWN | `DP-ATM-XXX` |
| PURGE | `LP-ATM-RAF` |
| EQ_P1 / EQ_P2 | `EQ-XXX-APR` |
| PRESSURIZATION | `RP-XXX-RAF` |

The equalization pair sequence is explicitly validated against the guide's expected 16-slot pair table. Receiver equalizations get `flowDirCol = 1`; donor equalizations get `flowDirCol = 0`. This correctly avoids relying on native `getStringParams` heuristics.

### Runtime compatibility caveat

The implementation sets purge `LP-ATM-RAF` to `typeDaeModel = 0` while most pressure-changing steps remain varying-pressure. The notes explain this as a native compatibility workaround because varying-pressure `LP-ATM-RAF` is not available in native `getVolFlowFuncHandle`. This is acceptable for getting the model running, but it is not a Ribeiro source claim and should be validated by checking final-cycle purge-step pressure behavior.

### No need to change now

Do not replace this with a Yang-style sequential wrapper. The direct native schedule is structurally consistent with the guide and should remain the path for soft validation.

---

## Parameter builder/finalizer assessment

### Correct aspects

The builder/finalizer does the important native runtime work:

- Initializes component names and `sComNums`.
- Sets `yFeC`, `yRaC`, and `yExC` sensibly for an H2-rich raffinate product.
- Sets native dimensions: `nCols = 4`, `nSteps = 16`, `nVols`, `nTiPts`, and `nCycles`.
- Seeds pressure, temperature, tank, standard-condition, isentropic-efficiency, and initial-condition fields needed by native routines.
- Initializes default valve arrays before `getDimLessParams`, which is needed because native dimensionless setup reads valve coefficients.
- Calls the downstream native setup sequence and then lets `applyRibeiroNativeSchedule.m` rebuild schedule-dependent parameters and initial states.

### Initial-condition caveat

`finalizeRibeiroSurrogateTemplateParams.m` sets:

```matlab
params.inConBed = ones(params.nCols, 1);
```

Native `getInitialStates` interprets this as feed-saturated high-pressure beds. Ribeiro's four-column simulation description instead starts each column filled with hydrogen at feed temperature and at the zero-time pressure of that column's first step. The implementation notes correctly identify this as scaffolding.

This does not necessarily block a long cyclic run if CSS convergence is reached, but it does matter for early-cycle smoke results and can distort short runs. The current reported five-cycle CSS residual of `3.34e-05` is not enough by itself to claim source-like CSS because native `numZero` is `1e-10`, and Ribeiro's full model required many cycles for full CSS in the published single-column case.

---

## High-priority issues before soft verification

### RIB-01 — Current Ribeiro metrics are not Ribeiro Eq. 2/Eq. 3 metrics

`computeRibeiroExternalMetrics.m` currently does this:

1. Gets native feed moles with `getFeedMolCycle`.
2. Gets native raffinate product/waste counters with `getRaffMoleCycle`.
3. Uses raffinate product counters if nonzero.
4. Falls back to column product-end counters during `HP-FEE-RAF` if raffinate product counters are zero.
5. Computes:

```matlab
purityH2 = externalProduct(1) / sum(externalProduct);
recoveryH2 = externalProduct(1) / h2Feed;
```

This is explicitly not Ribeiro recovery. Ribeiro recovery subtracts hydrogen used in pressurization and purge from produced hydrogen before dividing by feed hydrogen. The implementation notes acknowledge this caveat, and the one-cycle note reports fallback recovery about `1.0007`, which is physically and validation-wise a red flag.

**Why this matters:** Without an Eq. 3-like recovery counter, the model cannot be soft-validated against Ribeiro recovery trends. Native toPSAil `sol.perMet` can remain useful as a smoke metric, but the report must not treat current `ribeiroProductRecoveryH2` as a Ribeiro recovery.

**Minimum required change:** Add a final-cycle counter report that explicitly exposes:

- `feedMolesFinalCycle`
- `feedStepProductMolesFinalCycle`
- `h2UsedForPressurizationFinalCycle`
- `h2UsedForPurgeFinalCycle`
- `ribeiroEq2PurityH2`
- `ribeiroEq3RecoveryH2`
- `purgeToFeedH2Ratio`
- raw counter signs/basis, so sign conventions are auditable

This can be done from existing `sol.Step*` cumulative mole counters. It does not require a Yang ledger, plots, tests, or a new framework.

### RIB-02 — Multisite Langmuir source equation is probably not faithfully represented in native isothermal mode

The builder sets:

```matlab
params.modSp = [3; 1; 1; 1; 0; 0; 0];
params.qSatC = basis.adsorbent.multisiteLangmuir.qMaxMolKg;
params.aC = basis.adsorbent.multisiteLangmuir.a;
params.KC = basis.adsorbent.multisiteLangmuir.kInfPaInv * 1e5;
params.isoStHtC = 1000 * basis.adsorbent.multisiteLangmuir.heatOfAdsorptionKJMol;
```

The Pa^-1 to bar^-1 conversion is correct for native pressure/concentration scaling. The problem is that native `calcIsothermMultiSiteLang` uses `aC` as the exponent in `(1 - sumTheta)^a_i`, but native `funcMultiSiteLang.m` does not appear to multiply the right-hand side by `a_i`. Ribeiro Eq. (1) is:

```text
theta_i = a_i K_i P_i (1 - sum(theta))^a_i
```

Native appears to implement:

```text
theta_i = K_i P_i (1 - sum(theta))^a_i
```

For H2, `a_i = 1`, so this does not matter. For CO2, `a_i = 3`, so the current native input underweights CO2 affinity by a factor of about three if `KC` is passed directly.

There is a second, larger issue. Ribeiro Table 4 labels the affinity value as `K_inf`, and the paper supplies heat of adsorption. Native only applies the heat-of-adsorption exponential inside `calcIsothermMultiSiteLang` when `bool(5) == 1` (non-isothermal mode). This implementation is isothermal with `bool(5) = 0`, so `isoStHtC` is stored but not used by the native MSL isotherm.

At 303 K, the effective 303 K source coefficient for the current isothermal surrogate should likely be precomputed as:

```matlab
K_eff_bar_inv = a_i .* K_inf_Pa_inv .* 1e5 .* exp((1000 * heat_kJ_mol) ./ (R_J_mol_K * 303.0));
```

Using that convention, approximate effective native coefficients would be:

| Component | Current code `KC` bar^-1 | Approx. source `a_i*K(303K)` bar^-1 |
|---|---:|---:|
| H2 | `7.233e-6` | `1.18e-3` |
| CO2 | `2.125e-6` | `6.58e-1` |

That is not a small difference. If the current code is using `K_inf` directly, the source adsorption capacity is badly underrepresented, especially for CO2. This can materially change purity, recovery, pressure behavior, and CSS.

**Minimum required change:** Do not modify native core. For the isothermal Ribeiro soft-validation run, precompute an effective 303 K `params.KC` that includes the source heat factor and the source multiplicative `a_i` term required by Ribeiro Eq. (1), and document the exact basis in `params.KCBasis` and implementation notes. If the project has another source formula for Table 4 `K_i(T)`, use that instead; otherwise the above is the source-consistent direction.

### RIB-03 — LDF mass transfer should use source H2/CO2 values for soft verification

The builder default is:

```matlab
LdfMassTransferPerSec = 0.05
params.ldfMtc = 0.05 * ones(params.nComs, 1)
```

The notes correctly say this is a commissioning value. Ribeiro Table 6 provides activated-carbon micropore LDF values at feed inlet conditions:

- CO2: `1.24e-2 s^-1`
- H2: `8.89e-2 s^-1`

For H2/CO2 order, the source-backed vector is:

```matlab
[8.89e-2; 1.24e-2]
```

**Minimum required change:** Add these values to `ribeiroSurrogateConstants.m`, allow `LdfMassTransferPerSec` to be a scalar or a two-element vector, and default to the Table 6 vector for soft verification. This is a small source-basis correction and is more appropriate than keeping `0.05` for both species when comparing against Ribeiro-derived behavior.

### RIB-04 — Purge-flow and purge/feed ratio are not source-backed

Ribeiro Table 5 uses purge flow `3.5 N m^3/h` and reports purge/feed ratio `0.097`, defined as hydrogen used in purge divided by hydrogen in the full feed. The current surrogate uses a generic native valve coefficient `1e-6` for all positions and does not directly set or report purge flow.

Because the surrogate is binary-renormalized, the same source purge amount would correspond to a different ratio if divided by binary H2 feed rather than full-source H2 feed. Over one 160 s global cycle:

- Total source feed: `0.1513 mol/s * 160 s = 24.208 mol`
- Full-source H2 feed: `24.208 * 0.733 = 17.744 mol`
- Binary H2 feed: `24.208 * 0.8153503893 = 19.738 mol`
- Source purge flow: `3.5 N m^3/h ≈ 0.04338 mol/s`
- Four purge slots per global cycle: `40 s`, giving `~1.735 mol H2` purge per global cycle
- Purge/full-source-feed-H2 ratio: `~0.0978`
- Purge/binary-feed-H2 ratio: `~0.0879`

**Minimum required change:** Do not tune valves yet. First report achieved purge/feed H2 ratio in the summary. If the achieved ratio is grossly far from the source basis, then valve/source-flow treatment becomes the next focused calibration item.

### RIB-05 — Runtime smoke claims are not independently verifiable from the zip

Implementation notes report:

- One-cycle native run completed all 16 slots; native tank H2 purity `NaN`, recovery `0`, fallback purity about `0.8159`, fallback recovery about `1.0007`.
- Five-cycle run completed; native and Ribeiro-surrogate H2 purity about `0.9964`, recovery about `0.2171`, final CSS about `3.34e-05`.

The included `diagnostic_outputs/ribeiro_surrogate_smoke/summary.md` says `StopAfterBuild was true; no native simulation was run`, and all metrics are `NaN`. The included `summary.mat` also shows `lastCompleteCycle = 0` and `NaN` metrics.

**Impact:** I can believe the notes as implementation notes, but I cannot independently audit those numeric smoke results from the packaged artifacts. This does not block code review, but it blocks independent confirmation of runtime results.

---

## Medium-priority issues and caveats

### Initial beds are not Ribeiro initial beds

The implementation starts all beds as high-pressure feed-saturated beds. Ribeiro's multicolumn setup started columns as hydrogen-filled at the feed temperature and at the zero-time pressure of the corresponding first step.

For long CSS-oriented runs this may wash out. For short smoke runs it can strongly bias product purity/recovery and pressure transients. Do not use early-cycle values as validation evidence.

### Product-end pressurization is a surrogate assumption

`RP-XXX-RAF` uses H2-rich raffinate/product tank gas for product-end pressurization. This is consistent with the guide's first-pass choice, but it is not proven Ribeiro-equivalent. It is acceptable for soft validation if clearly labeled as a native surrogate.

### Tank volumes are placeholders

The tanks reuse column dimensions. No source-backed tank volumes were recovered. This is acceptable for a runnable native scaffold, but tank inventory can affect raffinate counters, purge/pressurization supply, and apparent recovery.

### Native metric sign conventions still need audit

`computeRibeiroExternalMetrics.m` warns on negative component moles, but the fallback logic does not yet normalize or reconcile sign conventions. Native `getPerformanceMetrics` has its own handling of product/waste counters. Before treating external product moles as physical, the final-cycle counter report should show raw signs and endpoint basis.

### `.gitignore` and packaged diagnostics

`.gitignore` ignores `*.mat`, `*.zip`, `*.csv`, `*.pdf`, `diagnostic_outputs/`, and then unignores `sources/**/*.csv` and `sources/**/*.pdf`. That matches the project-control intent for source PDFs/CSVs. The zip nevertheless contains old Yang diagnostic CSVs under `diagnostic_outputs/yang_recovery_accounting/`; those should not matter if they remain untracked/ignored.

---

## Minimal work needed before soft validation

Only these changes are necessary before a first soft validation run:

### 1. Patch the source isotherm basis in the Ribeiro builder

For the current isothermal surrogate, make `params.KC` an effective 303 K native coefficient. The patch should either:

- precompute `a_i * K_inf * exp(H/RT)` in bar^-1 in the builder, or
- otherwise prove and document the exact Table 4 `K_i(T)` formula being used.

Do not edit native toPSAil core for this unless absolutely unavoidable. The local builder can adapt Ribeiro constants to native MSL conventions.

### 2. Default the LDF vector to Ribeiro Table 6 H2/CO2 values

Use H2/CO2 order:

```matlab
[8.89e-2; 1.24e-2]  % s^-1
```

Keep the option override, but allow vector input.

### 3. Replace validation-facing metrics with Eq. 2/Eq. 3-style counters

Keep native purity/recovery in the summary, but add a clearly named Ribeiro Eq. 2/Eq. 3 surrogate metric. For final-cycle counters:

```text
purity = H2 out at product end during FEED / total gas out at product end during FEED
recovery = (H2 out at product end during FEED - H2 used in PRESSURIZATION - H2 used in PURGE) / H2 fed during FEED
```

The patch should print the raw counter basis so sign mistakes are visible. It should also report achieved purge/feed H2 ratio. No plots, no generated validation folders, no Yang ledger, and no tests are necessary for this deadline.

### 4. Run only small source-basis checks after the patch

Recommended sequence:

```matlab
addpath(genpath(pwd));
out = runRibeiroSurrogate("NCycles", 1, "NVols", 3, "NTimePoints", 2, "TFeedSec", 40);
disp(out.summary)

out = runRibeiroSurrogate("NCycles", 20, "NVols", 4, "NTimePoints", 2, "TFeedSec", 40);
disp(out.summary)
```

The 20-cycle run is not meant to reproduce the full paper. It is a soft check that the source-backed binary AC surrogate remains stable and produces finite, physically bounded metrics.

---

## Soft verification acceptance criteria

Do not compare the binary AC surrogate directly to the paper's full five-component layered-bed multicolumn result as if it were the same model. The full paper includes CH4/CO/N2, a zeolite layer, non-isothermal effects, and more detailed transport modeling. The first soft validation should instead check that the source-backed surrogate behaves consistently with the intended reduced basis.

Use these acceptance checks:

### Static/source checks

- `basis.feed.moleFractions = [0.8153503893; 0.1846496107]` and sums to one.
- `basis.feed.totalMolarFlowMolSec = 0.1513`.
- `params.volFlowFeed ≈ 545 cm^3/s`.
- `params.presColHigh = 7`, `params.presColLow = 1`.
- `params.radInCol = 10 cm`, `heightCol = 100 cm`, `voidFracBed = 0.38`.
- `params.qSatC`, `params.aC`, and effective `params.KC` are documented in H2/CO2 order.
- `params.ldfMtc = [0.0889; 0.0124]` unless intentionally overridden.

### Schedule checks

- Four columns and sixteen native slots.
- Exactly one feed bed in every slot.
- Equalization slots have exactly two paired columns.
- Equalization pair sequence remains:
  - B-D, B-D, C-D, C-D, A-C, A-C, A-D, A-D, B-D, B-D, A-B, A-B, A-C, A-C, B-C, B-C.
- No `getStringParams` dependency for Ribeiro schedule direction.

### Runtime sanity checks

- Run completes without solver failure for `NCycles=1, NVols=3, NTimePoints=2`.
- Run completes for a small multi-cycle case, e.g. `NCycles=20, NVols=4, NTimePoints=2`.
- Metrics are finite and physical:
  - H2 purity in `[0, 1]`.
  - H2 recovery in `[0, 1]` after subtracting purge/pressurization H2.
  - No fallback recovery above one.
- Final-cycle feed moles are near expected scale:
  - total feed per 160 s global cycle about `24.208 mol`
  - binary H2 feed about `19.738 mol`
- Purge/feed H2 ratio is reported, not hidden.
- Pressure traces are source-plausible:
  - feed near 7 bar
  - blowdown/purge near 1 bar after blowdown
  - equalization steps stage between high and low pressure

### Interpretation limits

A successful soft verification means: “the binary H2/CO2 activated-carbon native surrogate is source-basis consistent and stable.” It does **not** mean the code reproduces Ribeiro's full published purity of `99.9958%` and recovery of `52.11%` for the full five-component layered multicolumn model.

---

## Items I cannot retrieve or determine without input

1. **Exact non-build runtime result artifacts.** The non-StopAfterBuild one-cycle and five-cycle results reported in the notes are not included as runnable summaries in the zip. The included Ribeiro diagnostic summary is build-only.
2. **Git diff against `develop`.** The zip does not include git history, so I cannot prove no native core files were modified relative to `develop`. I can only say the active Ribeiro implementation files are scoped correctly and I saw no Ribeiro-named code under native core.
3. **The exact intended Table 4 temperature-dependence convention if there is project-specific evidence outside the PDF.** From the visible Ribeiro equation/table and native code, the current isothermal `K_inf` handling looks wrong. If you have a source-table extract or note saying Table 4 `K_inf` should be used differently, that is the one piece of source input I need.
4. **Whether the soft-validation target is numerical closeness to the full Ribeiro five-component layered result or only binary AC source-basis stability.** The current guide clearly points to the latter. If the intended target has changed, the surrogate scope needs to be changed before validation.

---

## Recommended decision

Proceed with the current direct-native architecture, but do not validate the reported purity/recovery yet. Make the three minimal patches: effective isothermal MSL `KC`, Table 6 H2/CO2 LDF defaults, and Eq. 2/Eq. 3-style final-cycle metrics with raw counter basis. Then run the smallest soft-verification sequence and compare only source-basis checks and physically bounded H2/CO2 surrogate behavior.

Do not spend time on Yang wrappers, test suites, plotting, or exact paper reproduction at this stage.
