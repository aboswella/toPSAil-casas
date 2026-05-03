# Ribeiro 4-bed surrogate soft-verification work plan

This note is intended for fresh Codex agents working on the current `toPSAil` Ribeiro surrogate repository. It is a static/code-and-diagnostic review of the uploaded repository and stored diagnostics; no new MATLAB run was executed in this environment. The goal is not to force the surrogate to match the full Ribeiro paper immediately. The goal is to remove implementation and accounting blockers so that any remaining purity/recovery gap is attributable to the intended surrogate simplifications.

## Reference baseline to keep in view

Ribeiro et al. use a layered activated-carbon/zeolite PSA bed and a five-component feed. The paper baseline is:

- Bed: 1 m length, 0.2 m diameter, 0.5 m activated carbon + 0.5 m zeolite.
- Feed pressure: 7 bar. Low/purge pressure: 1 bar.
- Feed: CO2/H2/CH4/CO/N2 = 16.6/73.3/3.5/2.9/3.7 mol%.
- Feed flow: 12.2 Nm3/h. Purge flow: 3.5 Nm3/h.
- Cycle: 4 columns, 8 logical steps, 16 ten-second schedule slots when `tfeed = 40 s`.
- Step timings: `tcycle = 4*tfeed`; `tD1 = tD2 = tP1 = tP2 = tpress = tfeed/2`; `tblowdown = tpurge = tfeed/4`.
- Ribeiro reported 4-column full-model performance: H2 purity 99.9958%, recovery 52.11%, productivity 59.9 mol H2/kg ads/day.

The current surrogate is intentionally narrower:

- Binary H2/CO2 only.
- Activated-carbon-only bed in the active implementation.
- Isothermal / native toPSAil CSTR-style discretization.
- Native equalization, but fixed feed/purge/blowdown/pressurization boundary overrides in `ribeiro_fixed_non_eq` mode.

Because of those simplifications, the full Ribeiro purity/recovery values are **soft references**, not exact pass/fail targets. The immediate implementation gates are: correct schedule, correct source/feed/purge amounts, correct high/low pressure realization, physically meaningful Eq. 2/Eq. 3 accounting, and numerical convergence.

## Current mismatch fingerprint from stored diagnostics

The most relevant stored run is `diagnostic_outputs/ribeiro_surrogate_boundary_20cycle/summary.md`, because it uses the fixed non-equalization boundary mode rather than the older native-only flow path.

In that run:

- Boundary mode: `ribeiro_fixed_non_eq`.
- H2 purity on the Ribeiro Eq. 2 boundary basis: about 0.88486.
- H2 recovery on the Ribeiro Eq. 3 boundary basis: about 0.57092.
- Feed accounting is essentially correct for the active binary basis: expected total feed in the final cycle about 24.208 mol; delivered feed about 24.208 mol.
- Purge H2 debit is close to the active binary-basis expectation: about 1.735 mol.
- Feed-step product contains about 19.053 mol H2 and 2.479 mol CO2, so the purity miss is direct CO2 breakthrough.
- Pressurization H2 debit is about 6.049 mol, which is large enough to dominate recovery accounting.
- Pressure realization is not Ribeiro-like: feed/high steps are around 6.19 bar, while blowdown/purge low steps are around 3.56 bar. The low-pressure error is therefore about 2.56 bar.

Older diagnostics are less reliable for current diagnosis:

- `ribeiro_surrogate_pilot_30cycle` delivered roughly 32.5 times the expected feed and did not have valid source-controlled boundary amounts.
- `ribeiro_surrogate_batch10_default_1cycle` had acceptable first-cycle feed/purge totals but did not blow down to 1 bar.
- `ribeiro_surrogate_batch10_combined_pressure_probe` reached low pressure but exploded the feed amount and failed high-pressure behavior.

Treat any stored diagnostic that predates `ribeiro_fixed_non_eq` as historical context only.

## Priority-ranked diagnosis

| Priority | Issue | Likely contribution | Evidence / reason | First action |
|---:|---|---:|---|---|
| P0 | The pressure cycle still fails. | Very high | The best fixed-boundary run spends blowdown/purge near 3.56 bar, not 1 bar, and high steps near 6.19 bar, not 7 bar. Poor regeneration explains CO2 slip and product-end contamination. | Make pressure endpoints pass before interpreting purity/recovery. |
| P0 | Validation defaults are drifting and stale. | Very high | `buildRibeiroSurrogateTemplateParams.m` defaults the boundary cap to 0.5 mol/s, but `runRibeiroSurrogate.m` currently defaults `MaxBoundaryMolarFlowMolSec` to `Inf` and passes it explicitly. Stored diagnostics also show older gains/valve settings. | Unify defaults and create one current canonical run artifact. |
| P0 | Recovery is sensitive to pressurization H2 debit. | High | In the fixed-boundary run, pressurization consumes about 6.049 mol H2 per final cycle. Eq. 3 subtracts pressurization and purge H2, so a sign, endpoint, or flow-cap error can swing recovery. | Audit pressurization counters, sign, composition, and endpoint pressure together. |
| P1 | Binary feed basis inflates H2/CO2 partial flows relative to the full paper. | Medium-high | The active binary fraction `[0.81535; 0.18465]` with the full 12.2 Nm3/h total feed replaces CH4/CO/N2 flow with extra H2/CO2. That lowers the purge-to-H2-feed ratio from Ribeiro's ~0.098 to about 0.088 on the binary denominator and changes recovery comparability. | Add an explicit feed-basis mode and report which basis each run uses. |
| P1 | The 4-column schedule appears structurally right, but equalization staging is not yet proven. | Medium-high | The 16-slot schedule pairs D1 with P2 and D2 with P1 as expected, but diagnostics only report a coarse equalization range. Bad equalization valve strength can affect high/low endpoints and pressurization debits. | Add per-role equalization pressure and transfer audits. |
| P1 | The active surrogate is AC-only and binary; Ribeiro target is layered and five-component. | Medium | Even a perfectly implemented binary AC surrogate should not be tuned to the 99.9958%/52.11% full-model target. The missing zeolite and CH4/CO/N2 are structural differences. | Mark full Ribeiro target as non-comparable until layer/component support exists. |
| P1 | Discretization is too coarse for purity work. | Medium | Current defaults include `NVols=3`; Ribeiro used 180 axial intervals. Three CSTR volumes can smear fronts and distort breakthrough. | Run pressure-gated convergence with NVols 3, 8, 16, 32. |
| P2 | CSS / cycle convergence is not a robust validation gate yet. | Medium | Ribeiro notes CSS can take hundreds of cycles in the thermal model. Binary isothermal may converge faster, but one-cycle and short-cycle summaries are not validation. | Gate on final-cycle metric drift, not just one summary value. |
| P2 | Isotherm and unit conversion need a direct source audit. | Medium | The active code converts Ribeiro `K_inf` from Pa^-1 to bar^-1 and applies the multisite Langmuir expression through native functions. A small unit error would strongly affect CO2 capacity. | Add a standalone MSL audit comparing direct Eq. (1) to native output. |
| P2 | Thermal simplification can shift fronts. | Low-medium for current huge gap | Ribeiro's recommended reduced model still includes gas-solid thermal equilibrium and wall heat transfer. The current isothermal surrogate is simpler. | Only investigate after pressure/flow/discretization gates pass. |
| P3 | Minor cleanup bugs and summary ambiguity. | Low | Duplicate warning string in `computeRibeiroBoundaryMetrics.m`; duplicate native recovery assignment in `summarizeRibeiroRun.m`; old docs can mislead agents. | Clean after gates are stable. |

## Batch 0 — Create a current canonical baseline artifact

**Goal:** Produce one fresh diagnostic run from the current code so agents stop reasoning from stale artifacts.

**Files to touch:** Prefer no code changes unless the run summary lacks required fields. If needed, update:

- `scripts/ribeiro_surrogate/writeRibeiroRunSummary.m`
- `scripts/ribeiro_surrogate/summarizeRibeiroRun.m`
- `docs/ribeiro_surrogate/IMPLEMENTATION_NOTES.md`

**Implementation steps:**

1. Work from the repository root.
2. Run a tiny current gate case with fixed non-equalization boundaries:

   ```matlab
   addpath(genpath(pwd));
   out = runRibeiroSurrogate( ...
       "BoundaryMode", "ribeiro_fixed_non_eq", ...
       "NVols", 3, ...
       "NCycles", 3, ...
       "NTimePoints", 2, ...
       "TFeedSec", 40);
   writeRibeiroRunSummary(out, fullfile("diagnostic_outputs", "ribeiro_surrogate_current_gate"));
   ```

3. The summary must print the active values of:
   - Boundary mode.
   - Feed basis and binary mole fractions.
   - Feed total mol/s and purge mol/s.
   - Blowdown and pressurization gains.
   - Boundary molar-flow cap.
   - Equalization valve coefficient.
   - Pressure-audit fields.
   - Eq. 2 purity and Eq. 3 recovery on the boundary basis.
   - Feed, product, pressurization, and purge molar ledger.

**Acceptance:** A new `diagnostic_outputs/ribeiro_surrogate_current_gate/summary.md` exists and is self-contained. It may fail the soft gate; this batch is only for freshness and reproducibility.

**Do not do:** Do not tune purity or recovery in this batch. Do not compare directly to 99.9958% until pressure and flow gates pass.

## Batch 1 — Fix default drift and boundary-cap propagation

**Goal:** Make the active default behavior deterministic. The runner must not silently override builder/boundary defaults.

**Files to touch:**

- `scripts/ribeiro_surrogate/runRibeiroSurrogate.m`
- `params/ribeiro_surrogate/buildRibeiroSurrogateTemplateParams.m`
- `scripts/ribeiro_surrogate/applyRibeiroBoundaryConditions.m`
- `docs/ribeiro_surrogate/IMPLEMENTATION_NOTES.md`

**Problem to fix:** `buildRibeiroSurrogateTemplateParams.m` and boundary defaults use a finite `MaxBoundaryMolarFlowMolSec` default of 0.5 mol/s, but `runRibeiroSurrogate.m` defaults that option to `Inf` and passes it through. This makes the apparent default different depending on entry point.

**Implementation steps:**

1. Change `runRibeiroSurrogate.m` so `MaxBoundaryMolarFlowMolSec` defaults to empty `[]`, not `Inf`.
2. Resolve `[]` in one place only, preferably in `makeRibeiroBoundaryOptions` or the existing boundary-default resolver.
3. Keep a deliberate way to request `Inf`, but only when the caller explicitly passes `Inf`.
4. Ensure the summary prints both:
   - `maxBoundaryMolarFlowMolSecRequested`
   - `maxBoundaryMolarFlowMolSecEffective`
5. Document the effective default in `IMPLEMENTATION_NOTES.md`.

**Acceptance:**

- Calling `runRibeiroSurrogate()` and calling `buildRibeiroSurrogateTemplateParams()` through the normal path produce the same effective boundary cap.
- The current gate summary no longer has an implicit `Inf` cap unless `Inf` was explicitly requested.

**Do not do:** Do not change native toPSAil core. Do not solve pressure mismatch by uncapping all flows; uncapped flows already caused feed explosions in older diagnostics.

## Batch 2 — Make pressure realization a hard gate

**Goal:** Ensure the 4-bed cycle actually visits Ribeiro-like pressures before any purity/recovery claim is made.

**Files to touch:**

- `scripts/ribeiro_surrogate/calcRibeiroBlowdownBoundaryFlow.m`
- `scripts/ribeiro_surrogate/calcRibeiroPressurizationBoundaryFlow.m`
- `scripts/ribeiro_surrogate/applyRibeiroBoundaryConditions.m`
- `scripts/ribeiro_surrogate/getRibeiroPressureAudit.m`
- `scripts/ribeiro_surrogate/summarizeRibeiroRun.m`
- `scripts/ribeiro_surrogate/writeRibeiroRunSummary.m`

**Implementation steps:**

1. Preserve fixed feed and fixed purge amounts. Do not let pressure control change the source feed or purge amount.
2. For blowdown, tune only the pressure-relief boundary at the feed end (`DP-ATM-XXX`) so the final blowdown/purge pressure reaches 1 bar within tolerance.
3. For pressurization, tune only the product-end pressurization boundary (`RP-XXX-RAF`) so the next feed/high step starts near 7 bar.
4. Keep finite flow caps. If the cap is active, the summary must report how often it was active.
5. Extend `getRibeiroPressureAudit.m` to report per-family values, at minimum:
   - `feedMeanPressureBar`, `feedEndPressureBar`, `feedPressureErrorBar`
   - `blowdownEndPressureBar`, `purgeMeanPressureBar`, `lowPressureErrorBar`
   - `pressurizationEndPressureBar`, `pressurizationPressureErrorBar`
   - `maxFeedPressureErrorBar`, `maxLowPressureErrorBar`, `maxPressurizationErrorBar`
6. Keep the soft gate strict:
   - feed/high pressure error <= 0.5 bar
   - low/purge pressure error <= 0.5 bar
   - pressurization endpoint error <= 0.5 bar

**Suggested smoke command:**

```matlab
addpath(genpath(pwd));
out = runRibeiroSurrogate( ...
    "BoundaryMode", "ribeiro_fixed_non_eq", ...
    "NVols", 3, ...
    "NCycles", 5, ...
    "NTimePoints", 2, ...
    "TFeedSec", 40);
writeRibeiroRunSummary(out, fullfile("diagnostic_outputs", "ribeiro_surrogate_pressure_gate"));
```

**Acceptance:**

- Feed/high steps are within 0.5 bar of 7 bar.
- Blowdown/purge low steps are within 0.5 bar of 1 bar.
- Pressurization endpoints are within 0.5 bar of 7 bar.
- Feed total and purge H2 amounts still pass their amount gates.

**Do not do:** Do not tune equalization or purity first. If pressures fail, purity/recovery are not interpretable.

## Batch 3 — Audit equalization staging and pairing

**Goal:** Prove that D1/D2/P1/P2 are paired and staged correctly in the 16-slot schedule.

**Files to touch:**

- `scripts/ribeiro_surrogate/buildRibeiroNativeSchedule.m`
- `scripts/ribeiro_surrogate/applyRibeiroNativeSchedule.m`
- `scripts/ribeiro_surrogate/getRibeiroPressureAudit.m`
- `scripts/ribeiro_surrogate/writeRibeiroRunSummary.m`

**Implementation steps:**

1. Add a schedule metadata table that records, for every slot:
   - slot index
   - logical role for each bed
   - equalization pair, if present
   - which bed is depressurizing and which is pressurizing
2. Confirm the intended pairing remains:
   - D1 bed connects to P2 bed.
   - D2 bed connects to P1 bed.
3. Add equalization transfer diagnostics:
   - pressure before and after each equalization role
   - signed molar transfer per pair
   - product-end valve coefficient used for each pair
4. Add monotonic pressure-level checks:
   - `high > after_D1 > after_D2 > low`
   - `low < after_P1 < after_P2 < high`

**Acceptance:**

- Equalization transfers are nonzero.
- The monotonic pressure ordering passes for all beds in the final cycle.
- The summary shows the active `equalizationValveCoefficientDefault` and any override.

**Do not do:** Do not replace native equalization unless the audit proves it cannot realize ordered pressure stages. If native equalization is replaced, document the blocker and keep the change isolated to Ribeiro surrogate boundary code.

## Batch 4 — Harden the Ribeiro Eq. 2 / Eq. 3 material ledger

**Goal:** Make the boundary-basis purity and recovery unambiguous and sign-safe.

**Files to touch:**

- `scripts/ribeiro_surrogate/computeRibeiroBoundaryMetrics.m`
- `scripts/ribeiro_surrogate/summarizeRibeiroRun.m`
- `scripts/ribeiro_surrogate/writeRibeiroRunSummary.m`

**Implementation steps:**

1. In fixed-boundary mode, `achievedTotalFeedMolesFinalCycle` must be the actual feed-boundary delivered amount, not an analytical expected value.
2. Print a ledger like this for the final cycle:

   ```text
   Feed boundary delivered: H2, CO2, total
   Product during feed:     H2, CO2, total
   Pressurization debit:    H2, CO2, total
   Purge debit:             H2, CO2, total
   Eq3 numerator:           H2_product_feed - H2_press - H2_purge
   Eq3 denominator:         H2_feed_boundary_delivered
   Eq2 denominator:         total_product_during_feed
   ```

3. Expose raw signed counters and interpreted positive debits/deliveries. Most mistakes here are sign mistakes.
4. Add physical warnings:
   - Eq. 2 purity outside `[0,1]`.
   - Eq. 3 recovery outside `[0,1]`.
   - negative feed delivery.
   - negative product during feed.
   - nonzero CO2 inflow during pure-H2 purge or pure-H2 final pressurization.
5. Keep native tank-based metrics, but label them diagnostic only in fixed-boundary mode.

**Acceptance:**

- The final-cycle ledger reproduces Eq. 2 and Eq. 3 exactly from printed numbers.
- Feed and purge amount errors are <= 5% in the pressure-gated run.
- Eq. 2 and Eq. 3 are finite and within `[0,1]`.

**Do not do:** Do not hide a bad recovery by changing the formula. Ribeiro Eq. 3 subtracts H2 used in pressurization and purge.

## Batch 5 — Make feed-basis comparability explicit

**Goal:** Separate implementation errors from the current binary-feed modeling choice.

**Files to touch:**

- `params/ribeiro_surrogate/ribeiroSurrogateConstants.m`
- `params/ribeiro_surrogate/buildRibeiroSurrogateTemplateParams.m`
- `scripts/ribeiro_surrogate/runRibeiroSurrogate.m`
- `scripts/ribeiro_surrogate/writeRibeiroRunSummary.m`
- `docs/ribeiro_surrogate/IMPLEMENTATION_NOTES.md`

**Problem to surface:** The active binary surrogate uses H2/CO2 mole fractions renormalized from the full feed but keeps the full 12.2 Nm3/h feed total. That preserves nominal hydraulic feed flow, but it inflates H2 and CO2 partial molar flows by replacing CH4/CO/N2 with extra H2/CO2. It also changes the purge-to-H2-feed ratio on the active binary denominator.

**Implementation steps:**

1. Add a `FeedBasisMode` option with at least two modes:
   - `full_total_renormalized_binary` — current behavior: full total feed flow, binary mole fractions renormalized from H2/CO2.
   - `source_h2co2_partial_flow` — keep Ribeiro H2 and CO2 partial molar flows, drop CH4/CO/N2 total flow, and use renormalized binary mole fractions.
2. Keep current behavior as default if required by project instructions, but print the mode loudly.
3. Print both ratios:
   - purge H2 / active binary H2 feed
   - purge H2 / original Ribeiro full-feed H2
4. Add summary fields:
   - `isFullRibeiroTargetComparable = false` for binary modes.
   - `fullRibeiroTargetPurityH2 = 0.999958`
   - `fullRibeiroTargetRecoveryH2 = 0.5211`
   - `activeSurrogateFeedBasis = <mode>`

**Acceptance:**

- Two pressure-gated runs can be produced, one for each feed basis.
- The summary states which basis is being used and why recovery should not be compared directly to the full paper unless the chosen basis matches the intended comparison.

**Do not do:** Do not silently change the default feed basis without updating docs and stored summaries.

## Batch 6 — Run numerical convergence only after pressure/flow gates pass

**Goal:** Quantify discretization error instead of confusing it with physics or boundary errors.

**Files to touch:** Prefer a diagnostic script or summary helper only:

- optional: `scripts/ribeiro_surrogate/runRibeiroConvergenceSweep.m`
- `scripts/ribeiro_surrogate/writeRibeiroRunSummary.m`
- `docs/ribeiro_surrogate/IMPLEMENTATION_NOTES.md`

**Implementation steps:**

1. Use the pressure-gated boundary settings from Batches 1-4.
2. Run the same case at `NVols = [3, 8, 16, 32]`.
3. Use enough cycles for final-cycle stability. Start with `NCycles=20`; increase if the last-cycle drift remains large.
4. Record for each `NVols`:
   - pressure errors
   - feed and purge amount errors
   - Eq. 2 purity
   - Eq. 3 recovery
   - final-cycle CO2 product amount
   - last-cycle CSS residual and metric drift

**Acceptance:**

- Pressure and amount gates pass at all reported `NVols`.
- If Eq. 2/Eq. 3 change by more than 2 absolute percentage points between `NVols=16` and `NVols=32`, mark the surrogate as numerically unconverged and do not interpret the paper gap.

**Do not do:** Do not tune parameters separately at each `NVols`. This is a convergence sweep, not a calibration sweep.

## Batch 7 — Audit the multisite Langmuir and LDF basis directly

**Goal:** Rule out a silent unit/convention error in adsorption capacity and mass transfer.

**Files to touch:**

- optional: `scripts/ribeiro_surrogate/auditRibeiroIsothermBasis.m`
- `params/ribeiro_surrogate/ribeiroSurrogateConstants.m`
- `params/ribeiro_surrogate/buildRibeiroSurrogateTemplateParams.m`
- `docs/ribeiro_surrogate/IMPLEMENTATION_NOTES.md`

**Implementation steps:**

1. Build a standalone direct implementation of Ribeiro Eq. (1) for binary H2/CO2 activated carbon at 303 K.
2. Compare direct results to native `funcMultiSiteLang` results at:
   - 7 bar and active binary feed composition
   - 1 bar and pure H2
   - 1 bar and representative purge-tail composition
   - pure-component H2 and CO2 checks
3. Confirm the conversion from `K_inf` in Pa^-1 to the native pressure basis is correct:
   - `K_bar = K_inf_PaInv * 1e5 * exp(deltaH/(R*T))`
4. Confirm component ordering is H2 first and CO2 second everywhere in the surrogate.
5. Confirm LDF rates are assigned in the same component order:
   - H2: `8.89e-2 s^-1`
   - CO2: `1.24e-2 s^-1`

**Acceptance:**

- Direct and native isotherm results agree to tight numerical tolerance.
- Any mismatch is fixed before running more purity/recovery studies.

**Do not do:** Do not tune capacities to match Ribeiro performance. Use Ribeiro Table 4 values for the declared surrogate.

## Batch 8 — Declare the surrogate-vs-paper model gap and add optional extension gates

**Goal:** Prevent accidental over-calibration of a binary AC-only model against a five-component layered-bed target.

**Files to touch:**

- `docs/ribeiro_surrogate/IMPLEMENTATION_NOTES.md`
- `scripts/ribeiro_surrogate/writeRibeiroRunSummary.m`
- optional capability-audit helper: `scripts/ribeiro_surrogate/auditRibeiroLayerCapability.m`

**Implementation steps:**

1. Add a summary section named `Comparison scope`.
2. State that the current surrogate omits:
   - zeolite layer
   - CH4, CO, N2 impurities
   - five-component competitive adsorption
   - non-isothermal wall/solid/gas energy behavior
3. Mark the full Ribeiro target as non-comparable unless all of these are implemented or an explicit correction is defined.
4. Add a capability audit for layered support:
   - Can native toPSAil use different adsorbent parameters by axial volume?
   - Can it support 5 components without native changes?
   - Can it assign AC parameters to the first 0.5 m and zeolite parameters to the last 0.5 m?
5. If native support exists, create a future `ribeiro_layered_5comp` mode with source Table 4/Table 5 parameters. If it does not, document the blocker and do not hack it into the binary surrogate.

**Acceptance:**

- No summary presents 99.9958% purity / 52.11% recovery as a hard target for the binary AC-only surrogate.
- The code can tell a user whether the active run is `binary_ac_surrogate` or `layered_5comp_ribeiro_like`.

**Do not do:** Do not import or rely on Yang scripts. The project instructions explicitly keep the Ribeiro surrogate native to toPSAil.

## Batch 9 — CSS and final-cycle stability gate

**Goal:** Ensure the final-cycle numbers are not transient artifacts.

**Files to touch:**

- `scripts/ribeiro_surrogate/summarizeRibeiroRun.m`
- `scripts/ribeiro_surrogate/writeRibeiroRunSummary.m`

**Implementation steps:**

1. Compute Eq. 2 purity and Eq. 3 recovery for at least the last three cycles, not only the last cycle.
2. Add fields:
   - `purityH2LastCycle`
   - `purityH2PreviousCycle`
   - `recoveryH2LastCycle`
   - `recoveryH2PreviousCycle`
   - `purityH2AbsDriftLastCycle`
   - `recoveryH2AbsDriftLastCycle`
3. Add a CSS metric gate:
   - pressure gates pass
   - feed/purge amount gates pass
   - purity drift <= 0.001 absolute
   - recovery drift <= 0.005 absolute
4. If the run is isothermal and binary, use this gate before claiming any trend. If a thermal model is later enabled, expect more cycles.

**Acceptance:**

- The summary clearly says whether CSS is passed.
- If CSS fails, the summary still prints values but labels them transient.

**Do not do:** Do not raise `NCycles` blindly in all default runs. Keep quick smoke runs possible, but separate smoke runs from validation runs.

## Batch 10 — Only after gates: investigate thermal simplification and productivity

**Goal:** Move from implementation verification to model-form verification once the surrogate is internally consistent.

**Files to touch:**

- `params/ribeiro_surrogate/buildRibeiroSurrogateTemplateParams.m`
- `params/ribeiro_surrogate/finalizeRibeiroSurrogateTemplateParams.m`
- `scripts/ribeiro_surrogate/summarizeRibeiroRun.m`
- `docs/ribeiro_surrogate/IMPLEMENTATION_NOTES.md`

**Implementation steps:**

1. Confirm the active run is intentionally isothermal. `finalizeRibeiroSurrogateTemplateParams.m` currently sets isothermal behavior and disables pressure drop.
2. If native toPSAil can enable energy balances without violating project constraints, add an optional `Isothermal=false` exploratory mode.
3. Add productivity calculation only after feed/pressure/accounting gates pass:
   - use final-cycle net H2 product from Eq. 3 numerator
   - divide by adsorbent mass and total cycle time
   - document that AC-only adsorbent mass differs from Ribeiro layered AC/zeolite mass
4. Do not judge thermal/productivity differences until numerical convergence is acceptable.

**Acceptance:**

- The summary reports whether productivity is comparable to Ribeiro or AC-only surrogate-specific.
- Thermal mode, if present, is opt-in and does not break the pressure-gated isothermal baseline.

**Do not do:** Do not use a thermal/productivity change to mask pressure or feed-basis failures.

## Batch 11 — Low-risk cleanup

**Goal:** Remove small code smells that make diagnostics harder to trust.

**Files to touch:**

- `scripts/ribeiro_surrogate/computeRibeiroBoundaryMetrics.m`
- `scripts/ribeiro_surrogate/summarizeRibeiroRun.m`
- `docs/ribeiro_surrogate/IMPLEMENTATION_NOTES.md`

**Implementation steps:**

1. Remove the duplicate warning string line in the Eq. 2 physical-gate warning block in `computeRibeiroBoundaryMetrics.m`.
2. Remove duplicate assignment of `recoveryH2` in `summarizeRibeiroRun.m` if it is still present.
3. In docs, mark old diagnostic outputs as pre-boundary-fix or stale where applicable.
4. Add a short checklist at the top of `IMPLEMENTATION_NOTES.md`:
   - current canonical run artifact
   - pressure gate status
   - feed/purge gate status
   - CSS gate status
   - comparison scope

**Acceptance:** The cleanup changes do not change numerical results except for printed summary fields and warnings.

## Expected order of work

Recommended assignment order:

1. Batch 0 and Batch 1 together.
2. Batch 2 immediately after Batch 1.
3. Batch 4 in parallel with Batch 2, because pressure and accounting must be read together.
4. Batch 3 once pressure endpoints are close enough to make equalization stages meaningful.
5. Batch 5 before any paper-facing discussion of recovery.
6. Batch 6 and Batch 9 together for validation-grade runs.
7. Batch 7 if CO2 slip remains unexpectedly high after pressure and convergence pass.
8. Batch 8 before any attempt to match the full Ribeiro paper target.
9. Batch 10 and Batch 11 last.

## Most likely explanation of the current purity/recovery mismatch

The current dominant issue is not zeolite, methane, or thermal physics. The strongest evidence points to a pressure-cycle implementation problem: the best fixed-boundary run is not regenerating at 1 bar and is not fully returning to 7 bar. That leaves CO2 in the bed and produces about 2.48 mol CO2 in the final-cycle feed-product window, which directly explains the 88.5% H2 purity. Recovery is additionally being shaped by a large H2 pressurization debit, so it cannot be interpreted until pressurization endpoint, sign, composition, and amount are audited.

Once pressure and accounting gates pass, the next likely contributors are feed-basis comparability, coarse axial discretization, and the intentional binary AC-only simplification. Only after those are separated should anyone discuss whether the surrogate is close to Ribeiro's 99.9958% purity and 52.11% recovery.
