# Yang-Style Run Diagnostic Handoff

Prepared: 2026-05-02

This file summarizes the recent full Yang-style surrogate run and the two ledger fixes that preceded it. It is written for a diagnostic AI that can inspect the codebase but cannot run MATLAB.

## Executive Summary

The current wrapper can execute the fixed-duration Yang-inspired four-bed cycle with real native routes and real adapter routes. After the latest ledger fixes:

- All 24 operation groups execute.
- Physical-mole ledger basis checks pass.
- Slot and cycle material ledger balances close.
- External-basis H2 purity/recovery metrics compute without internal-transfer overcount.
- A 30-cycle pilot completes and trends toward CSS, but does not meet the current CSS tolerance.
- The late-cycle physical result is not Yang-like purification. Product composition is essentially the binary feed composition.

The run validates wrapper orchestration and accounting health. It does not validate the surrogate against Yang 2009 performance.

## Codebase State Relevant To This Handoff

Preexisting dirty worktree items from the previous agent are still present:

- `scripts/four_bed/checkYangLedgerPhysicalMoleCompatibility.m`
- `scripts/four_bed/extractYangNativeLedgerRows.m`
- `scripts/run_four_bed_commissioning.m`
- several tests under `tests/four_bed/`
- untracked `Batch 6 complete.zip`

New files added by the latest fix:

- `scripts/four_bed/appendYangNativeAdFeedClosureRows.m`
- `tests/four_bed/testYangNativeAdFeedClosureCycleBalance.m`

Latest fix also edited:

- `scripts/four_bed/runYangFourBedCycle.m`

No toPSAil core files were intentionally changed by these fixes.

## Previous Agent Fix: Native Counter Rows Converted To Physical Moles

Original issue context said the previous blocker was incompatible ledger bases: native counter-tail rows were being summed with physical inventory rows.

The previous agent appears to have made these changes:

1. `extractYangNativeLedgerRows.m`
   - Requires `templateParams.nScaleFac`.
   - Converts native counter-tail deltas to physical moles with:
     - `moles = abs(native counter delta) * params.nScaleFac`
   - Emits native rows with:
     - `basis = "physical_moles_from_native_counter_tail_delta_using_params.nScaleFac"`
     - `units = "mol"`
   - Adds report metadata:
     - raw native counter-tail deltas,
     - counter magnitude policy,
     - `nativeMoleScaleFactor`,
     - conversion policy,
     - converted moles by row.

2. `checkYangLedgerPhysicalMoleCompatibility.m`
   - Allows the specific converted-native basis above despite containing the word `native`.
   - Continues to reject incompatible native, unknown, not-available, validation-only, or dimensionless bases.

3. Tests updated
   - Synthetic native ledger tests now set `params.nScaleFac` and assert converted physical-mole amounts.
   - Basis safety tests now verify converted native physical-mole rows can participate in balances/metrics.
   - Spy cycle tests set `params.nScaleFac = 1.0` to keep their synthetic counter rows compatible.
   - `scripts/run_four_bed_commissioning.m` now includes `testYangNativeLedgerRowsSynthetic()`.

State after that previous fix:

- `run('scripts/run_four_bed_commissioning.m')` passed.
- A short real one-cycle health run completed all 24 operation groups.
- It reported:
  - `operation_groups = 24`
  - `invalid_basis_rows = 0`
  - `metric_pass = 1`
  - `balance_pass = 0`

Conclusion from that state: the mixed-unit/basis blocker was fixed, but a real physical-mole balance residual remained.

## Diagnosis Of Remaining Balance Failure

A short real one-cycle diagnostic sorted `report.ledger.balanceRows` by absolute residual.

Observed failing rows before the latest fix:

- All failing slot rows were `stage_label = "AD"`, `component = "H2"`.
- The failing cycle row was `cycle_external`, `component = "H2"`, equal to the sum of AD slot residuals.
- PP/PU, ADPP/BF, EQI, EQII, BD, and CO2 rows were within tolerance.

Representative pre-fix short-run balance summary:

- `operation_groups = 24`
- `invalid_basis_rows = 0`
- `metric_pass = 1`
- `balance_pass = 0`
- `max_abs_residual = 6.51078773855e-05 mol`

For `AD-A-col01`, the native AD diagnostic showed the shape of the issue:

- Native column counter feed-side H2 was near zero.
- Native column counter product-side H2 was about `1.13e-05 mol`.
- Bed inventory H2 increased by about `1.13e-05 mol`.
- The slot balance therefore needed an external-feed H2 row that the native column counter did not provide.

The external balance equation in `computeYangLedgerBalances.m` was not the issue:

```text
residual = external_feed - external_product - external_waste - bed_inventory_delta
```

The ledger was missing external AD feed input for native `HP-FEE-RAF` accounting.

## Latest Fix: Native AD Feed Closure Rows

The latest fix is wrapper-level only.

### New helper

File:

```text
scripts/four_bed/appendYangNativeAdFeedClosureRows.m
```

Behavior:

- Runs only for `operationFamily == "AD"` when called.
- Computes, per component:

```text
missing_feed = external_product + external_waste + bed_inventory_delta - existing_external_feed
```

- If `missing_feed > tolerance`, appends an `external_feed` row.
- If `missing_feed < -tolerance`, errors rather than appending negative feed.
- Uses:
  - `stream_scope = "external_feed"`
  - `stream_direction = "in"`
  - `endpoint = "feed_end"`
  - `basis = "physical_moles_reconstructed_from_ad_slot_balance"`
  - `units = "mol"`

This is an accounting reconstruction. It is not a physics change.

### Cycle-driver integration

File:

```text
scripts/four_bed/runYangFourBedCycle.m
```

The cycle driver now:

1. Extracts native or adapter ledger rows.
2. Writes terminal local states back to named beds.
3. Computes and appends bed inventory delta rows.
4. For real native AD only, calls `appendYangNativeAdFeedClosureRows`.
5. Appends rows to the ledger and computes balances/metrics later as before.

The gate is intentionally narrow:

```text
string(group.operationFamily) == "AD"
isfield(runReport, "didInvokeNative")
runReport.didInvokeNative == true
```

So spy tests are not silently "fixed" by this closure path.

### New regression

File:

```text
tests/four_bed/testYangNativeAdFeedClosureCycleBalance.m
```

It runs a real one-cycle path and asserts:

- four `AD` H2 slot balance rows exist,
- all those rows pass,
- the H2 cycle external balance passes,
- no invalid basis rows exist,
- all 24 operation groups execute,
- at least one `physical_moles_reconstructed_from_ad_slot_balance` external-feed row exists.

The test failed before the latest fix and passed after the helper was wired in.

## Verification Commands Recently Run

These commands were executed successfully after the latest fix:

```matlab
addpath(genpath(pwd));
testYangNativeAdFeedClosureCycleBalance();
```

```matlab
addpath(genpath(pwd));
testYangNativeLedgerRowsSynthetic();
testYangAdapterLedgerRowsFromReports();
testYangFullSlotLedgerBalance();
testYangFourBedCycleLedgerSmoke();
```

```matlab
addpath(genpath(pwd));
testYangFourBedCycleDriverSpyWriteback();
testYangFourBedSimulationCssPlumbing();
```

```matlab
addpath(genpath(pwd));
run('scripts/run_four_bed_commissioning.m');
```

The original one-cycle diagnostic after the latest fix reported:

- `operation_groups = 24`
- `invalid_basis_rows = 0`
- `metric_pass = 1`
- `balance_pass = 1`
- `max_abs_residual = 2.69402555819e-15 mol`
- `ad_closure_rows = 4`

## Full Yang-Style Pilot Run Configuration

The longest run performed was a 30-cycle pilot, intended as a Yang-style wrapper exercise rather than a calibrated Yang validation case.

Configuration:

- Parameter builder:
  - `buildYangH2Co2AcTemplateParams('NVols', 2, 'NCols', 2, 'NSteps', 1, 'FeedVelocityCmSec', 5.2, 'FinalizeForRuntime', true)`
- Cycle time:
  - `240 s`
- Schedule:
  - normalized Yang displayed-duration fractions `[1, 6, 1, 4, 1, 1, 4, 1, 1, 5] / 25`
- Components:
  - `[H2; CO2]`
- Feed basis:
  - Yang H2/CO2 subset renormalized to `[0.7697228145; 0.2302771855]`
- Adsorbent:
  - homogeneous activated carbon over the full model bed
- Excluded:
  - CO, CH4, zeolite 5A, layered-bed physics, pseudo-components
- Thermal mode:
  - current finalized runtime surrogate path, not a demonstrated Yang non-isothermal reproduction
- Initial state:
  - synthetic commissioning physical states, not a source-derived CSS state
- Adapter controls:
  - `Cv_PP_PU_internal = 1e-6`
  - `Cv_PU_waste = 1e-6`
  - `Cv_ADPP_feed = 1e-6`
  - `Cv_ADPP_product = 1e-6`
  - `Cv_ADPP_BF_internal = 1e-6`
- Max cycles:
  - `30`
- CSS:
  - `StopAtCss = false`
  - `KeepCycleReports = false`

Run skeleton:

```matlab
params = buildYangH2Co2AcTemplateParams( ...
    'NVols', 2, 'NCols', 2, 'NSteps', 1, ...
    'FeedVelocityCmSec', 5.2, ...
    'FinalizeForRuntime', true);

manifest = getYangFourBedScheduleManifest();
pairMap = getYangDirectTransferPairMap(manifest);

% Synthetic initial state used for all four beds:
% bed i vector repeated over params.nVols:
% [0.76 - 0.01*i; 0.24 + 0.01*i; 0.01; 0.02; 1.0; 1.0]

controls = struct( ...
    'cycleTimeSec', 240, ...
    'adapterValidationOnly', false, ...
    'Cv_PP_PU_internal', 1e-6, ...
    'Cv_PU_waste', 1e-6, ...
    'Cv_ADPP_feed', 1e-6, ...
    'Cv_ADPP_product', 1e-6, ...
    'Cv_ADPP_BF_internal', 1e-6);

sim = runYangFourBedSimulation(initial, params, controls, ...
    'MaxCycles', 30, ...
    'StopAtCss', false, ...
    'KeepCycleReports', false);
```

## Full Yang-Style Pilot Results

30-cycle pilot summary:

```text
elapsed_sec = 556.962
feed_velocity_cm_s = 5.2
cycle_time_sec = 240
run_completed = 1
cycles_completed = 30
css_pass = 0
final_css_residual = 4.84627265358e-05
final_css_controlling_bed = A
final_css_controlling_family = gas_concentration
balance_pass = 1
invalid_basis_rows = 0
max_abs_balance_residual_mol = 1.22070417663e-09
metrics_pass = 1
acceptance_pass = 0
```

Late-cycle metrics:

| Cycle | Product purity H2 | Product recovery H2 | H2 product mol | Product denominator mol | H2 feed denominator mol |
|---:|---:|---:|---:|---:|---:|
| 26 | 0.76972 | 0.99999 | 0.23058 | 0.29957 | 0.23059 |
| 27 | 0.76972 | 0.99999 | 0.23059 | 0.29958 | 0.23059 |
| 28 | 0.76972 | 0.99999 | 0.23060 | 0.29958 | 0.23060 |
| 29 | 0.76972 | 0.99999 | 0.23060 | 0.29959 | 0.23060 |
| 30 | 0.76972 | 0.99999 | 0.23060 | 0.29959 | 0.23060 |

CSS residual tail:

| Cycle | Aggregate residual | Pass | Controlling bed | Controlling family |
|---:|---:|---:|---|---|
| 21 | 0.0012928 | false | A | gas_concentration |
| 22 | 0.00089833 | false | A | gas_concentration |
| 23 | 0.00062397 | false | A | gas_concentration |
| 24 | 0.00043328 | false | A | gas_concentration |
| 25 | 0.00030082 | false | A | gas_concentration |
| 26 | 0.00020882 | false | A | gas_concentration |
| 27 | 0.00014494 | false | A | gas_concentration |
| 28 | 0.00010059 | false | A | gas_concentration |
| 29 | 0.000069822 | false | A | gas_concentration |
| 30 | 0.000048463 | false | A | gas_concentration |

Cycle 30 stream totals:

| Stream scope | H2 mol | CO2 mol |
|---|---:|---:|
| external_feed | 0.230603088250 | 0.0689892895591 |
| external_product | 0.230600365626 | 0.0689886122427 |
| external_waste | 0.00000863175772 | 0.00000258235618 |

Interpretation:

- The wrapper accounting is healthy.
- The run is not yet accepted because CSS tolerance did not pass.
- The late-cycle product is essentially the H2/CO2 feed composition.
- Recovery is near 100 percent because almost all H2 exits through external product, but this is not useful purification.

## Comparison To Yang 2009

Yang 2009 source facts observed from the local PDF:

- Process:
  - four-bed, ten-step PSA.
  - layered beds of activated carbon and zeolite 5A.
  - non-isothermal dynamic model.
  - feed contains H2, CO2, CO, CH4, and small amounts of water.
- Reported target/product behavior:
  - high-purity product discussed at `99.999%` H2.
  - for `5.2 cm/s`, high-purity recovery is reported around `66.36%`.
  - conclusion states it was possible to obtain hydrogen of `99.999%` purity with about `75%` recovery.
  - experiments discussed 20 to 30 cycles for cyclic steady behavior in some runs.

Current surrogate versus Yang:

| Quantity | Current 30-cycle surrogate | Yang 2009 context | Comparison |
|---|---:|---:|---|
| H2 product purity | ~76.972% | 99.999% target/high-purity product | Very far below Yang |
| H2 recovery | ~99.999% | ~66.36% at 5.2 cm/s high purity, ~75% in conclusion | Numerically higher, but misleading because product is not purified |
| CSS | Not passed at 30 cycles, residual ~4.85e-05 | Yang discusses CSS behavior around 20 to 30 cycles for some runs | Current run trends down but is not accepted |
| Feed/components | Binary H2/CO2 only | H2/CO2/CO/CH4 plus water traces | Not comparable as full Yang reproduction |
| Bed | Homogeneous activated carbon | Layered activated carbon + zeolite 5A | Not comparable as full Yang reproduction |
| Thermal model | Current surrogate runtime path | Non-isothermal layered model | Not comparable as full Yang reproduction |

Bottom line: the current run is a valid wrapper/accounting pilot but a poor physical match to Yang. It behaves like feed passthrough in the late cycles.

## Diagnostic Questions For A Static Code Review

The next diagnostic AI should inspect these areas:

1. Why does the late-cycle product composition remain essentially equal to feed?
   - Inspect native AD route setup in `translateYangNativeOperation.m` and `prepareYangNativeLocalRunParams.m`.
   - Inspect runtime pressures/valves in `finalizeYangH2Co2AcTemplateParams.m`.
   - Inspect whether `HP-FEE-RAF` at constant pressure with the current valve/default tank settings is actually producing meaningful separation in this temporary wrapper context.

2. Is the AD feed-closure helper masking a deeper native boundary accounting problem?
   - Inspect `appendYangNativeAdFeedClosureRows.m`.
   - Inspect native counter sign/layout in `getColCuMolBal.m` and `getRhsFuncVals.m`.
   - The helper is deliberately accounting-only; it should not be treated as proof that the native AD boundary counters are fully understood.

3. Are adapter valve coefficients too small or ineffective?
   - Inspect `runYangPpPuAdapter.m`, `runYangAdppBfAdapter.m`, and flow integration helpers.
   - The 30-cycle run used all adapter Cv values at `1e-6`.
   - External waste in cycle 30 is nearly zero, suggesting the cycle may not reject much CO2 by the end of the pilot.

4. Is the physical model too reduced for any Yang-like performance?
   - Binary H2/CO2 without CO/CH4 and without zeolite may be unable to reproduce the source purification behavior.
   - Current repo docs explicitly warn not to claim full Yang validation.

5. Does CSS tolerance need more cycles or is the fixed point physically unhelpful?
   - CSS residual dropped monotonically from `0.0012928` at cycle 21 to `4.846e-05` at cycle 30.
   - More cycles may pass CSS, but the late-cycle purity is already close to feed composition.

## Files To Inspect First

Primary execution path:

- `scripts/four_bed/runYangFourBedSimulation.m`
- `scripts/four_bed/runYangFourBedCycle.m`
- `scripts/four_bed/buildYangFourBedOperationPlan.m`
- `scripts/four_bed/normalizeYangFourBedControls.m`

Native route and ledger:

- `scripts/four_bed/runYangTemporaryCase.m`
- `scripts/four_bed/prepareYangNativeLocalRunParams.m`
- `scripts/four_bed/extractYangNativeLedgerRows.m`
- `scripts/four_bed/appendYangNativeAdFeedClosureRows.m`
- `scripts/four_bed/appendYangBedInventoryDeltaRows.m`
- `scripts/four_bed/computeYangLedgerBalances.m`
- `scripts/four_bed/computeYangPerformanceMetrics.m`

Adapter route:

- `scripts/four_bed/runYangDirectCouplingAdapter.m`
- `scripts/four_bed/runYangPpPuAdapter.m`
- `scripts/four_bed/runYangAdppBfAdapter.m`
- `scripts/four_bed/integrateYangPpPuAdapterFlows.m`
- `scripts/four_bed/integrateYangAdppBfAdapterFlows.m`

Parameter/runtime basis:

- `params/yang_h2co2_ac_surrogate/buildYangH2Co2AcTemplateParams.m`
- `params/yang_h2co2_ac_surrogate/finalizeYangH2Co2AcTemplateParams.m`
- `params/yang_h2co2_ac_surrogate/yangH2Co2AcSurrogateConstants.m`
- `cases/yang_h2co2_ac_surrogate/case_spec.md`

Policy/context:

- `docs/four_bed/FINAL_IMPLEMENTATION_CONTEXT.md`
- `docs/KNOWN_UNCERTAINTIES.md`
- `docs/REPORT_POSITIONING.md`
- `docs/VALIDATION_STRATEGY.md`

## Cautions

- Do not weaken CSS or balance tolerances to make the run pass.
- Do not treat near-100 percent H2 recovery as positive validation while H2 purity is near feed composition.
- Do not tune physical constants to improve Yang agreement.
- Do not add zeolite 5A, CO, CH4, layered beds, or event scheduling unless the task explicitly changes the active target.
- Do not turn the AD feed-closure ledger helper into a solver or physics change.

## Suggested Next Smallest Static Diagnostic Task

Trace why the full-cycle fixed point behaves like feed passthrough:

1. Inspect the native AD `HP-FEE-RAF` local-run preparation and boundary-condition fields.
2. Inspect whether external product rows during AD and ADPP/BF are dominated by unchanged feed composition.
3. Inspect adapter flow magnitudes and split logic at the late-cycle state.
4. Decide whether the issue is:
   - expected behavior for the deliberately reduced H2/CO2 AC surrogate,
   - a valve/control setup problem,
   - a temporary native-case boundary setup problem,
   - or an accounting artifact despite ledger closure.
