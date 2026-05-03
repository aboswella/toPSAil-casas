# Ribeiro Surrogate Soft-Validation Gap Assessment — dynamic-header and accounting basis

**Assessment target:** static repository extracted from `Ribeiro soft validation gap.zip`, plus included `diagnostic_outputs/ribeiro_surrogate_pilot_30cycle/summary.md` and `summary.mat`.

**Assessment mode:** static code review, implementation-note review, source cross-check, and direct inspection of the included MATLAB `summary.mat` artifact with Python. I did **not** rerun MATLAB/toPSAil in this environment.

**Primary basis reviewed:** `Ribeiro 2008.pdf`, `Overall Implementation Guide.md`, uploaded `IMPLEMENTATION_NOTES.md`, prior static assessments, and the active files under `params/ribeiro_surrogate/` and `scripts/ribeiro_surrogate/`.

## Bottom line

The implementation has moved past the earlier source-basis issues. The active Ribeiro code now includes the effective isothermal Ribeiro Table 4 multisite-Langmuir coefficient, the Ribeiro Table 6 H2/CO2 LDF values, Eq. 2/Eq. 3-style final-cycle counters, expected-vs-achieved feed/purge flow checks, and operation-specific feed/purge valve knobs.

However, the current 30-cycle result is **not soft-validated against Ribeiro** and should not be interpreted physically yet. The current result is dominated by a native toPSAil dynamic-header / valve-flow mismatch:

- Expected final-cycle source feed: `24.208 mol`.
- Achieved final-cycle feed: `811.202 mol`, i.e. `33.51x` the expected scale.
- Expected binary H2 feed: `19.738 mol`.
- Achieved binary H2 feed: `661.414 mol`.
- Expected source purge H2: `1.735 mol`.
- Achieved purge H2 crossing the product end: `29.989 mol`.
- Reported H2 purity: `~0.81517`, essentially the binary feed H2 mole fraction.
- Reported H2 recovery: `~0.95448`, much higher than the Ribeiro reported multicolumn recovery, but on a flow/accounting basis that is currently not comparable.

The most important additional finding from `summary.mat` is that the pressure cycle appears collapsed. In the final cycle, the columns sit around `P/P_high ≈ 0.835–0.847`, or roughly `5.85–5.93 bar` if `P_high = 7 bar`. Feed, blowdown, purge, equalization, and pressurization do **not** show a 7-to-1 bar cycle. The low-pressure steps are not near `1 bar`; they are still near `6 bar`.

That means the observed low purity / high recovery does **not** imply a Ribeiro-like PSA with a different tradeoff. It implies a system that is mostly passing feed-like gas through a native dynamic-header/valve arrangement that is not enforcing the Ribeiro flow and pressure basis.

## Can the current purity/recovery be defensibly said to be Ribeiro-equivalent?

No. There are two separate non-equivalences.

First, the intended model is already a simplified binary H2/CO2 activated-carbon surrogate, while Ribeiro's published multicolumn result is for a five-component H2/CO2/CH4/CO/N2 layered activated-carbon/zeolite system with a more complete dynamic model. Even after soft validation, this surrogate should only be claimed as a source-basis-consistent binary AC native surrogate, not a reproduction of the full paper result.

Second, the current run is not even operating on the intended surrogate basis. The flow audit and pressure audit fail hard. A product purity of `~0.815` is essentially feed composition, and the product-end feed-step moles are almost the same as the feed moles. The reported recovery is therefore a gross-throughput recovery of H2 that largely slips through, not a Ribeiro Eq. 3 process recovery for a correctly regenerated PSA cycle.

A high recovery paired with feed-composition purity usually means one or more of the following in PSA terms:

- the bed is overloaded or insufficiently regenerated;
- the purge/blowdown/equalization pressure history is wrong;
- the feed flow is much too high for the bed and time scale;
- the model is counting internal/header flows on a basis different from the source definition;
- product-end gas during feed is being treated as useful product even when it is not separated product.

In this case, the included diagnostics point most strongly to the second, third, and fourth items.

## Gate status

| Gate | Status | Assessment |
|---|---:|---|
| Active Ribeiro architecture | Pass | Direct native four-column implementation; no Yang wrapper detected in active `params/` or `scripts/`. |
| Yang quarantine | Pass with noise | Active code does not import Yang constants/adapters. Yang files remain under `sources/Yang Scripts FOR REFERENCE ONLY/`, and old Yang diagnostics remain under ignored output folders. |
| Source constants | Pass with caveat | Feed, pressure, geometry, Table 4 AC H2/CO2 parameters, Table 6 LDF, and purge source reference are present. The surrogate remains binary AC only, not full Ribeiro. |
| Effective isothermal MSL `KC` | Pass for current surrogate | `KC = a_i * k_inf * 1e5 * exp(deltaH/RT)` is implemented locally in the Ribeiro builder, which is the right non-native-core adaptation for the isothermal path. |
| LDF values | Pass | Default H2/CO2 order is `[8.89e-2; 1.24e-2] s^-1`. |
| 16-slot schedule | Pass structurally | The slot sequence and equalization pair sequence match the guide. |
| Eq. 2/Eq. 3-style counters | Present but not validation-ready | Counters exist and are useful, but they are being applied to a failed flow/pressure realization. |
| Final-cycle feed-flow realization | **Fail** | Achieved feed is `811.2 mol` vs expected `24.208 mol`. |
| Final-cycle purge-flow realization | **Fail** | Achieved purge H2 is `29.99 mol` vs expected `1.735 mol`. The achieved purge/H2-feed ratio is low only because the feed denominator is hugely inflated. |
| Pressure-cycle realization | **Fail** | Final-cycle columns are around `5.85–5.93 bar`, not 7-to-1 bar. |
| Dynamic-header accounting basis | **Fail / unresolved** | Native feed/product header tanks are flow-controlled reservoirs; current metrics do not yet prove equivalence to Ribeiro's boundary-integral definitions. |
| Soft-verification readiness | **Not ready** | Fix pressure and dynamic-header flow realization before interpreting purity/recovery. |

## Evidence from the included 30-cycle run

### Published summary values

The included `summary.md` reports:

| Quantity | Expected/source basis | Achieved/current run |
|---|---:|---:|
| Native H2 purity | — | `0.815171134883` |
| Native H2 recovery | — | `0.954478970111` |
| Ribeiro Eq. 2 surrogate H2 purity | — | `0.815171363949` |
| Ribeiro Eq. 3 surrogate H2 recovery | — | `0.954479074669` |
| Total feed, final cycle | `24.208 mol` | `811.201815382 mol` |
| Binary H2 feed, final cycle | `19.7380022242 mol` | `661.413715972 mol` |
| Source purge H2, final cycle | `1.73502671941 mol` | `29.9890197613 mol` |
| Binary-denominator purge/H2-feed ratio | `0.0879028536` | `0.0453407890` |

The feed and purge values alone are sufficient to reject the run for soft validation.

### Additional audit from `summary.mat`

I inspected the included `summary.mat`. The one-cycle feed-valve calibration initially looks good, but it is not stable as the beds/header tanks evolve:

| Cycle | Total feed processed, mol | H2 feed, mol | Purge H2, mol | Purge/H2-feed ratio |
|---:|---:|---:|---:|---:|
| 1 | `24.186` | `19.720` | `1.655` | `0.08395` |
| 2 | `68.253` | `55.650` | `3.981` | `0.07154` |
| 3 | `118.910` | `96.953` | `5.544` | `0.05718` |
| 5 | `201.352` | `164.172` | `8.334` | `0.05077` |
| 10 | `363.200` | `296.135` | `14.089` | `0.04757` |
| 20 | `619.941` | `505.469` | `23.217` | `0.04593` |
| 30 | `811.202` | `661.414` | `29.989` | `0.04534` |

This shows that Batch 9 calibrated the **first cycle**, not the near-CSS/final-cycle source flow. The final-cycle source flow is not controlled.

The pressure trace inferred from final-cycle column `gasConsTot` and `temps.cstr` is also not source-plausible:

| Final-cycle step family | Approx. normalized pressure, `P/P_high` | Approx. pressure if `P_high = 7 bar` |
|---|---:|---:|
| Feed slots | `0.843–0.845` | `5.90–5.92 bar` |
| Blowdown slots | `0.835–0.847` | `5.85–5.93 bar` |
| Purge slots | `0.835–0.837` | `5.85–5.86 bar` |
| Equalization slots | `0.835–0.847` | `5.85–5.93 bar` |
| Pressurization slots | `0.838–0.845` | `5.87–5.92 bar` |

The cycle is not moving between `7 bar` and `1 bar`. Blowdown/purge are not regenerating the bed at low pressure, equalization cannot meaningfully transfer pressure because all beds are already near the same pressure, and pressurization is nearly irrelevant.

## Static implementation findings

### 1. Feed flow is still valve/header-driven, not source-flow-controlled

`params.volFlowFeed` is set correctly from the source molar feed, but in native toPSAil this is primarily a scaling basis. The actual feed enters through `calcVolFlowFeTa2ValTwo`, which computes flow from the feed tank / column concentration-pressure difference and `params.valFeedColNorm`.

The feed header is then replenished dynamically. In `calcVolFlows4UnitsFlowCtrlDT0.m`, the feed tank inlet is set to the sum of the feed tank outflows:

```matlab
vFlFeTa(:,(nCols+1)) = max(0,sum(vFlFeTa(:,1:nCols),2));
```

`getFeTaCuMolBal.m` then counts that replenishment as processed feed. Therefore, native feed moles follow whatever the column/header valves demand. They are not locked to Ribeiro Table 5 feed flow.

This is why a first-cycle valve calibration can look correct and then drift to a 33.5x final-cycle feed error.

### 2. The pressure cycle is not realized

The current `applyRibeiroNativeSchedule.m` only overrides feed and purge valves:

```matlab
params.valFeedCol(strcmp(params.sStepCol, 'HP-FEE-RAF')) = feedValveCoefficient;
params.valProdCol(strcmp(params.sStepCol, 'LP-ATM-RAF')) = purgeValveCoefficient;
```

All other operation valves, including blowdown, equalization, and pressurization, remain at the fallback `NativeValveCoefficient = 1e-6`. This is not enough to create the Ribeiro 7-to-1 bar pressure history in the included run.

The low-pressure purge workaround is also still risky. `LP-ATM-RAF` exists under the constant-pressure branch in `getVolFlowFuncHandle.m`, but it is not obvious from static inspection that it pins the column to `presColLow`. The included pressure trace says it does not.

### 3. Eq. 2/Eq. 3 counters are present but currently applied to a failed operating point

`computeRibeiroExternalMetrics.m` now uses feed-step product-end gas for Eq. 2 and subtracts H2 crossing the product end during pressurization and purge for Eq. 3. That is a reasonable counter scaffold. The problem is not the existence of these counters. The problem is that the counters are being applied to a non-Ribeiro pressure/flow realization.

In the final cycle:

- Feed H2: `661.414 mol`.
- Feed-step product H2: `661.367 mol`.
- Pressurization H2 used: `0.072 mol`.
- Purge H2 used: `29.989 mol`.

The feed-step product H2 is almost the feed H2. That is not separation; it is feed-like gas passing out the product end.

### 4. Native and Ribeiro-surrogate metrics agreeing is not evidence of validation

Native H2 purity/recovery and Eq. 2/Eq. 3 H2 purity/recovery agree closely in the included summary. In this case that agreement is not comforting; it means both accounting paths are seeing the same gross product-like stream. Agreement between two counters does not validate the physical cycle when the feed, purge, and pressure gates fail.

### 5. No active Yang parameter use detected

A search of active `params/` and `scripts/` found no Yang constants, adapters, ledgers, or wrapper code. The only Yang mentions in active control files are warnings/instructions not to import Yang. Yang scripts remain in the reference-only source folder. This is acceptable as long as they remain quarantined and are not used for Ribeiro parameter defaults.

## Interpretation of the low purity / high recovery result

The current product purity is essentially the binary feed H2 fraction. This strongly suggests that the system is not enriching H2. CO2 is not being removed sufficiently from the product stream, and the product stream is best interpreted as feed-like gas exiting the feed step.

The high recovery is not the Ribeiro physical achievement. It is high because the run processes an enormous amount of feed and sends almost all H2 out the product end. The Eq. 3 subtractors are small relative to the inflated gross feed/product throughput:

```text
Eq. 3 numerator ≈ feed-step product H2 - pressurization H2 - purge H2
                ≈ 661.367 - 0.072 - 29.989
                ≈ 631.306 mol

Eq. 3 denominator ≈ achieved H2 feed
                  ≈ 661.414 mol

recovery ≈ 0.9545
```

That is a gross slip-through recovery under a failed pressure/flow cycle, not a defensible Ribeiro recovery.

## Minimal next Codex work before soft verification

Do **not** switch to Yang. Do **not** create tests, plots, or a validation framework. Do **not** tune purity/recovery. The next work should only make the pressure and flow basis auditable and source-like.

### Patch 1 — Add a final-cycle pressure audit to the summary

Add a small function, for example:

```text
scripts/ribeiro_surrogate/computeRibeiroPressureAudit.m
```

or keep it inside `summarizeRibeiroRun.m` if faster.

Report, for the last complete cycle:

- `pressureBySlotByColumnStartBar`
- `pressureBySlotByColumnEndBar`
- `pressureByStepFamilyMinMeanMaxBar`
- `feedPressureMeanBar`
- `blowdownEndPressureMeanBar`
- `purgePressureMeanBar`
- `equalizationPressureRangeBar`
- `pressurizationEndPressureMeanBar`

Use existing `sol.Step*.col.n*.gasConsTot`, `temps.cstr`, and `params.gasConsNormEq`. Add hard warnings:

```text
HP-FEE-RAF final-cycle pressure not near 7 bar.
DP-ATM-XXX / LP-ATM-RAF final-cycle pressure not near 1 bar.
Equalization pressure spread is too small or not staged.
```

This is the fastest way to stop false validation from a collapsed pressure cycle.

### Patch 2 — Add operation-specific pressure-valve knobs, but only for pressure realization

Do not replace the architecture. Extend the existing valve override pattern minimally:

- `BlowdownValveCoefficient` for `DP-ATM-XXX` feed-end waste valves.
- `EqualizationValveCoefficient` for `EQ-XXX-APR` paired product-end equalization valves.
- `PressurizationValveCoefficient` for `RP-XXX-RAF` product-end pressurization valves.
- Keep `FeedValveCoefficient` and `PurgeValveCoefficient` but do not recalibrate them until pressure passes.

The current single fallback `1e-6` leaves blowdown/equalization/pressurization effectively too closed for the source pressure cycle.

### Patch 3 — Run a pressure-first sensitivity analysis

This is the required parameter refinement. Keep it small and source-basis oriented.

Run only coarse log sweeps first:

```text
BlowdownValveCoefficient:       1e-6, 1e-5, 1e-4, 1e-3, 1e-2
EqualizationValveCoefficient:   1e-6, 1e-5, 1e-4, 1e-3
PressurizationValveCoefficient: 1e-6, 1e-5, 1e-4, 1e-3
```

Do not tune against purity/recovery. Tune only to these gates:

- feed step is near `7 bar`;
- blowdown/purge reach near `1 bar`;
- equalization slots create staged intermediate pressures;
- pressurization approaches the high-pressure basis before feed;
- solver remains stable.

A run that matches feed moles but has a collapsed pressure cycle should be rejected.

### Patch 4 — Then run a final-cycle flow sensitivity analysis

After pressure is source-plausible, sweep only:

```text
FeedValveCoefficient
PurgeValveCoefficient
```

against final-cycle flow targets:

- total feed per 160 s global cycle: `24.208 mol`;
- binary H2 feed: `19.738 mol`;
- source purge H2: `1.735 mol`;
- binary-denominator purge/H2-feed ratio: `0.0879`.

Do this at `NCycles = 10` or `20` first. The Batch 9 one-cycle calibration must not be used as validation because the final-cycle flow drift is the central failure.

### Patch 5 — Add dynamic-header inventory deltas

Add a tiny inventory audit, not a Yang ledger. For the last complete cycle report:

- feed tank start/end total moles and component moles;
- raffinate tank start/end total moles and component moles;
- extract tank start/end total moles and component moles;
- column inventory delta if cheap to compute;
- net external feed/product/waste after tank inventory change.

The goal is not a full balance framework. The goal is to make sure dynamic header tanks are not hiding or creating the apparent recovery.

### Patch 6 — Rename the validation-facing result fields until pressure/flow pass

Keep the fields for continuity, but the Markdown summary should state:

```text
Ribeiro Eq. 2/Eq. 3 surrogate metrics are reported for audit only.
Soft-validation status: FAIL until pressure, feed-flow, and purge-flow gates pass.
```

This prevents the current `0.815 / 0.954` pair from being mistaken for a valid Ribeiro comparison.

## Soft-verification gates after the next patch

A run can proceed to first soft verification only when all of these pass:

| Gate | Required behavior |
|---|---|
| Feed scale | Final-cycle total feed near `24.208 mol` for `TFeedSec = 40`. |
| Binary H2 feed | Final-cycle H2 feed near `19.738 mol`. |
| Purge amount | Final-cycle H2 purge near `1.735 mol`, or clearly justified binary-surrogate equivalent. |
| Purge ratio | Binary-denominator purge/H2-feed ratio near `0.0879`; full-source denominator reported near `0.0978`. |
| High-pressure feed | Feed beds near `7 bar`. |
| Low-pressure regeneration | Blowdown/purge beds near `1 bar` after blowdown. |
| Equalization | Intermediate pressures are actually staged between high and low. |
| Pressurization | Beds approach the intended high-pressure basis before feed. |
| Metrics | Eq. 2 purity and Eq. 3 recovery finite and in `[0,1]`. |
| Accounting | Header-tank inventory deltas do not dominate the apparent product/recovery. |

Only then should the current binary AC surrogate be compared to Ribeiro-derived trends.

## What should not be done now

- Do not import Yang parameters or scripts.
- Do not add a Yang wrapper, ledger, diagnostics suite, or test suite.
- Do not tune the model to Ribeiro's published full five-component purity/recovery.
- Do not tune feed/purge valves to purity/recovery before the pressure cycle is correct.
- Do not claim the current native/toPSAil recovery is Ribeiro Eq. 3 recovery until the dynamic-header basis passes the inventory audit.

## Items I cannot retrieve or determine without input

1. **Git diff against `develop`.** The zip has no `.git` history, so I cannot prove no native core edits relative to the true base branch.
2. **MATLAB rerun behavior.** I inspected the static repo and included `summary.mat`, but I did not rerun MATLAB/toPSAil here.
3. **Whether a native toPSAil mode already exists that cleanly enforces Ribeiro's prescribed feed/purge flows while preserving this schedule.** Static inspection suggests the current flow-controlled header mode is not doing that, but a quick native-mode experiment would be needed to prove the best minimal patch.
4. **Whether the intended validation target has changed from binary H2/CO2 AC soft validation to full Ribeiro reproduction.** The provided guide and notes still define the target as the binary activated-carbon surrogate. Full-paper reproduction would require a different model scope.
5. **Whether there is project-specific evidence overriding the Table 4 temperature convention.** The current effective-isothermal `KC` adaptation is defensible from the visible source/code basis, but any external source-table extract should be added if it contradicts this convention.

## Recommended decision

Keep the direct-native architecture and the current source constants. The immediate blocker is **not Yang contamination** and not the Eq. 2/Eq. 3 counter scaffold. The immediate blocker is that native dynamic header tanks and valve-driven boundary conditions are not enforcing Ribeiro's pressure and source-flow basis.

The next Codex instruction should be limited to:

```text
Add final-cycle pressure audit, add minimal operation-specific pressure valve knobs, run pressure-first sensitivity, then run final-cycle feed/purge flow sensitivity. Do not tune purity/recovery and do not add Yang/test/plot frameworks.
```

Until that passes, the current purity/recovery pair should be labeled as a failed flow/pressure audit result, not as a Ribeiro soft-verification result.

## Codex batch 10 addendum - 2026-05-03

I implemented the first part of the recommended next work in native Ribeiro-owned files:

- Added `scripts/ribeiro_surrogate/computeRibeiroPressureAudit.m`.
- Added operation-specific native valve knobs for blowdown, equalization, and pressurization.
- Added `softValidationStatus` and an audit-only caveat for Eq. 2/Eq. 3 metrics in the generated summary.
- Reprocessed the stored 30-cycle pilot into `diagnostic_outputs/ribeiro_surrogate_pilot_30cycle_reaudit/summary.md`.

The re-audited 30-cycle pilot remains `FAIL_PRESSURE_FLOW_AUDIT`: feed pressure mean `5.91 bar`, blowdown end pressure mean `5.85 bar`, purge pressure mean `5.85 bar`, equalization pressure range `0.0846 bar`, and pressurization end pressure mean `5.90 bar`.

A one-cycle default native run still matches the first-cycle feed scale (`24.08 mol`) but does not regenerate at low pressure (`6.91 bar` blowdown/purge). A small blowdown-only micro-sweep showed that increasing blowdown Cv can reach low pressure (`1.018 bar` at `1e-2`), but it inflates one-cycle feed throughput to `1794 mol` and leaves high-pressure feed/pressurization too low. A combined pressure probe with blowdown/pressurization opened still fails high-pressure feed/pressurization and feed scale. The current evidence therefore supports the same next decision: continue pressure-first sensitivity, then recalibrate feed/purge flow only after pressure gates pass.
