# Batch 6 commissioning implementation guide, with mandatory Batch 5 remediation

Prepared for a fresh Codex agent working on the Yang-inspired four-bed H2/CO2 activated-carbon toPSAil surrogate.

This guide is based on static inspection of the repository snapshot supplied as `Batch 5 complete.zip`. MATLAB/Octave execution was not available during this assessment. Do not treat the static review as a numerical pass. The unpleasant little truth is that several Batch 5 paths are shaped correctly but are only proven by spy or validation-only tests. Batch 6 exists to remove that ambiguity.

## 0. Current source of truth

Read these before editing code:

1. `four_bed_final_implementation_basis.docx`
2. `four_bed_final_batching_context.md`
3. `docs/four_bed/FINAL_IMPLEMENTATION_CONTEXT.md`, if present in the repo
4. `docs/four_bed/README.md`, if present in the repo
5. Existing tests under `tests/four_bed/`

The final implementation target is the Yang-inspired four-bed H2/CO2 homogeneous activated-carbon surrogate. It is not a full Yang reproduction with H2/CO2/CO/CH4, zeolite 5A, layered beds, or Aspen Adsim valve details.

The architecture remains:

- four persistent named physical bed states: `A`, `B`, `C`, `D`;
- wrapper-level orchestration around existing toPSAil adsorber machinery;
- direct bed-to-bed internal transfers;
- no dynamic internal tanks or shared header inventory for Yang internal transfers;
- no global four-bed RHS/DAE;
- no core adsorber mass, energy, momentum, isotherm, or solver rewrite, except for a very small documented interface hook if absolutely unavoidable;
- wrapper-owned ledger and audit accounting;
- final H2 purity/recovery reconstructed from wrapper external stream rows only.

## 1. Assignment scope

You are implementing Batch 6, FI-8, and repairing Batch 5 defects that block commissioning.

Batch 6 primary purpose: prove the four-bed implementation before optimisation. That means adding staged tests and enough minimal fixes that real native and adapter paths can be run, inspected, and rejected honestly when they fail.

Your work includes:

1. Fix Batch 5 integration defects identified below.
2. Add staged commissioning tests.
3. Add a single top-level commissioning test runner if the repository does not already have one.
4. Record a handoff note summarising what passed, what failed, what remains numerical tuning, and what remains architectural risk.

Your work does not include:

- adding CO, CH4, pseudo-components, zeolite, or layered-bed behaviour;
- replacing toPSAil adsorber physics;
- implementing a monolithic four-bed DAE;
- adding tanks/headers to represent Yang internal transfers;
- performing optimisation;
- weakening existing tests to make the implementation look healthier than it is.

## 2. Static Batch 5 assessment

The Batch 5 implementation is directionally consistent with the final basis. It has the expected cycle driver, simulation loop, operation planning, local/global mapping, wrapper ledger, adapter audit writer, and metric reconstruction layer. However, static inspection found several blockers or high-risk gaps.

Treat the following as mandatory preflight issues. Some are direct defects; some are "prove or fix" items because static review cannot determine whether the native runtime path is fully initialised.

### 2.1 What Batch 5 implemented correctly

The following files exist and are structurally aligned with Batch 5:

- `scripts/four_bed/runYangFourBedCycle.m`
- `scripts/four_bed/runYangFourBedSimulation.m`
- `scripts/four_bed/buildYangFourBedOperationPlan.m`
- `scripts/four_bed/extractYangNativeLedgerRows.m`
- `scripts/four_bed/extractYangAdapterLedgerRows.m`
- `scripts/four_bed/computeYangLedgerBalances.m`
- `scripts/four_bed/computeYangPerformanceMetrics.m`
- `scripts/four_bed/writeYangAdapterAuditReport.m`

Positive observations:

- `runYangFourBedCycle.m` builds a normalised schedule, builds/validates the operation plan, selects single-bed or paired temporary cases, routes operations through native or adapter paths, writes terminal local states back to persistent A/B/C/D states, appends inventory deltas, computes balances, and computes performance metrics.
- `buildYangFourBedOperationPlan.m` generates 24 operation groups and supports 40 bed-step participations, preserving native/adapted routes:
  - `AD`, `BD`, `EQI`, `EQII` are native candidates.
  - `PP_PU` and `ADPP_BF` are adapter routes.
- Physical-only persistence is present through `extractYangPhysicalBedState.m`, `extractYangStateVector.m`, and `writeBackYangFourBedStates.m`.
- Non-participant bed preservation is explicitly checked in the cycle report.
- Adapter reports separate PP->PU internal transfer/waste and AD&PP->BF feed/product/internal-transfer categories.
- Wrapper performance metrics exclude `internal_transfer` rows by scope.

These are good foundations. Naturally, several of them are still held together by tests that politely avoid the hardest paths.

### 2.2 Confirmed Batch 5 defects and risks

#### B5-01. Native run reports do not expose the data required by native ledger extraction

Location:

- `scripts/four_bed/runYangTemporaryCase.m`, native path around lines 70-84.
- `scripts/four_bed/extractYangNativeLedgerRows.m`, `resolveCounterDeltas`, around lines 100-122.

Problem:

`runYangTemporaryCase.m` calls:

```matlab
[stTime, stStates, flags] = runPsaCycleStep(params, params.initStates, tDom, 1, 1);
```

It then stores `stTime`, `flags`, and `counterTailReport`, but not `stStates` and not top-level `counterTailDeltas`.

`extractYangNativeLedgerRows.m` accepts only:

```matlab
nativeReport.counterTailDeltas
```

or:

```matlab
nativeReport.stStates
```

Without one of those fields, real native AD/BD/EQI/EQII routes fail with `FI7:NativeCounterTailUnavailable`.

Why existing tests missed it:

`testYangFourBedCycleLedgerSmoke.m` and `testYangFourBedSimulationCssPlumbing.m` use spy native runners that inject `counterTailDeltas`. They do not exercise the real native report path.

Required fix:

- In `runYangTemporaryCase.m`, after `extractYangTerminalLocalStates`, expose both:
  - `runReport.stStates = stStates;`
  - `runReport.counterTailDeltas = ...;`
- Compute `counterTailDeltas` from `stStates` using the same indexing assumed by `extractYangNativeLedgerRows.m`:

```matlab
counterDeltas = cell(tempCase.nLocalBeds, 1);
for i = 1:tempCase.nLocalBeds
    idx = ((i-1)*params.nColStT + params.nColSt + 1):(i*params.nColStT);
    counterDeltas{i} = stStates(end, idx).' - stStates(1, idx).';
end
runReport.counterTailDeltas = counterDeltas;
```

- Also add explicit report metadata:

```matlab
runReport.counterTailBasis = "native_counter_tail_delta_from_stStates";
runReport.counterTailLayout = "first_nComs_feed_end_second_nComs_product_end";
```

Acceptance test:

Create `tests/four_bed/testYangNativeTemporaryCaseReportCounters.m`.

It must prove that a native report returned by `runYangTemporaryCase` has either real `counterTailDeltas` or `stStates`, and that `extractYangNativeLedgerRows` can consume it. If a real native run cannot yet be performed because of runtime-template readiness, include a minimal synthetic fallback test for the extraction logic, but the commissioning suite must still include a real native smoke later.

#### B5-02. Single-bed native temporary cases are likely incompatible with a two-column template

Location:

- `scripts/four_bed/injectYangLocalStatesIntoTemplateParams.m`, around lines 33-36.
- `scripts/four_bed/runYangFourBedCycle.m`, native invocation around lines 180-186.

Problem:

`injectYangLocalStatesIntoTemplateParams.m` requires:

```matlab
templateParams.nCols == tempCase.nLocalBeds
```

But Batch 5 commonly uses one template for all operation groups. Tests build a two-column template with:

```matlab
buildYangH2Co2AcTemplateParams('NVols', 2, 'NCols', 2, 'NSteps', 1)
```

Single-bed native operations such as `AD` and `BD` have `tempCase.nLocalBeds == 1`. A real native single-bed call with a two-column template will therefore throw:

```matlab
WP4:TemplateColumnCountMismatch
```

Why existing tests missed it:

They use spy native runners, so `injectYangLocalStatesIntoTemplateParams` is not exercised for real AD/BD native groups.

Required fix:

Add a wrapper-level native local-run preparation helper, for example:

```matlab
scripts/four_bed/prepareYangNativeLocalRunParams.m
```

This helper should:

1. Clone `templateParams`.
2. Set local execution fields to match `tempCase.nLocalBeds`.
3. Preserve physical parameter values.
4. Recompute state-size and initial-state layout through existing toPSAil helper functions wherever possible.
5. Inject local physical states with zero counter tails.
6. Set `params.sStepCol`, `params.nSteps`, `params.numAdsEqPrEnd`, and `params.numAdsEqFeEnd` from `tempCase.native`.
7. Return a `prepReport` stating:
   - source `templateParams.nCols`;
   - local `params.nCols`;
   - `nColSt`, `nColStT`, `nStatesT`;
   - counter-tail policy;
   - duration basis.

Do not manually invent low-level toPSAil layout unless no existing helper exists. If manual construction is unavoidable, document the exact fields and prove one-bed and two-bed local cases by test.

Then change `runYangTemporaryCase.m` native path to call this helper instead of directly calling `injectYangLocalStatesIntoTemplateParams`.

Acceptance tests:

- One-bed AD temp case can prepare local params from a two-bed template.
- One-bed BD temp case can prepare local params from a two-bed template.
- Two-bed EQI/EQII temp cases still prepare correctly.
- Existing physical-state persistence tests still pass.

#### B5-03. Native duration uses seconds as dimensionless integration time

Location:

- `scripts/four_bed/runYangFourBedCycle.m`, `invokeNativeRunner`, line around 185 passes `DurationSeconds`.
- `scripts/four_bed/runYangTemporaryCase.m`, `pickDuration`, around lines 118-128.
- `scripts/four_bed/runYangPpPuAdapter.m`, `resolveTimeDomain`, around lines 144-160.
- `scripts/four_bed/runYangAdppBfAdapter.m`, `resolveTimeDomain`, around lines 153-169.

Problem:

The adapter paths convert seconds to dimensionless time:

```matlab
durationDimless = config.durationSeconds ./ params.tiScaleFac;
```

The native path does not. `runYangTemporaryCase.m` currently picks `DurationSeconds` directly and uses:

```matlab
tDom = [0, durationValue];
```

`runPsaCycleStep.m` comments and native toPSAil usage indicate `tDom` is dimensionless time. Passing physical seconds directly is inconsistent with the adapter path and likely wrong.

Required fix:

In the native local-run preparation/time-domain helper:

- If `DurationDimless` is supplied, use it directly.
- Else if `DurationSeconds` is supplied and `params.tiScaleFac` exists, convert:

```matlab
durationDimless = durationSeconds ./ params.tiScaleFac;
timeBasis = "seconds_converted_to_dimensionless_using_tiScaleFac";
```

- Else if seconds are supplied but `tiScaleFac` is missing, throw a clear error. Do not silently treat seconds as dimensionless.
- Store both physical seconds and dimensionless duration in the run report.

Acceptance tests:

- Native AD smoke report must include `durationSeconds`, `durationDimless`, and `timeBasis`.
- Adapter and native reports must use the same time-basis convention.
- A test with `DurationSeconds` and no `tiScaleFac` must fail clearly.

#### B5-04. Runtime readiness of the H2/CO2 AC template is not proven

Location:

- `params/yang_h2co2_ac_surrogate/buildYangH2Co2AcTemplateParams.m`
- Adapter preparation functions require runtime fields:
  - `initStates`
  - `bool`
  - `numZero`
  - `numIntSolv`
  - `funcRat`
  - `funcIso`
  - `coefMat`
  - `cstrHt`
  - `partCoefHp`
  - `nFeTaStT`
  - `nRaTaStT`
  - `nExTaStT`
  - `inShFeTa`
  - `inShRaTa`
  - `inShExTa`
  - `inShComp`
  - `inShVac`
  - `feTaVolNorm`
  - `raTaVolNorm`
  - `exTaVolNorm`
  - `gasConsNormEq`
  - `tempFeedNorm`
  - `pRatFe`
  - `yFeC`

Problem:

The parameter builder sets many physical, state-size, and isotherm fields, but static inspection cannot confirm that it produces a fully runnable `params` struct accepted by `runPsaCycleStep`.

Required fix:

Add or complete a runtime-finalisation path. Preferred options:

1. Add an option to the existing builder:

```matlab
params = buildYangH2Co2AcTemplateParams(..., 'FinalizeForRuntime', true)
```

2. Or add a separate helper:

```matlab
params = finalizeYangH2Co2AcTemplateParams(params)
```

Rules:

- Use existing toPSAil parameter initialisation functions where possible.
- Do not edit core adsorber balances.
- Do not invent fake runtime fields just to placate tests.
- Preserve the H2/CO2, AC-only, homogeneous-bed basis.
- Record a report or metadata field stating that runtime finalisation has occurred.

Acceptance test:

Create `tests/four_bed/testYangRuntimeTemplateReadiness.m`.

It should verify that:

- required runtime fields exist;
- `params.initStates` length matches `params.nStatesT`;
- one-bed and two-bed local native preparation produce valid `params.initStates`;
- no CO, CH4, zeolite, or layered-bed flags appear in the finalised params.

#### B5-05. Ledger balances and metrics silently mix incompatible bases and units

Location:

- `scripts/four_bed/computeYangPerformanceMetrics.m`, around lines 41-47.
- `scripts/four_bed/computeYangLedgerBalances.m`, especially `sumScope` and `sumDirection`, around lines 132-137.
- `scripts/four_bed/extractYangNativeLedgerRows.m`, rows use basis `native_counter_tail_delta` and units `native_integrated_units`.
- `scripts/four_bed/appendYangBedInventoryDeltaRows.m`, rows may use either physical `mol` or `native_inventory_units`.
- `scripts/four_bed/extractYangAdapterLedgerRows.m`, rows may use physical moles, native counter units, or unknown adapter units depending on report contents.

Problem:

`computeYangPerformanceMetrics.m` computes external product/feed totals using stream scope only. It ignores row `basis` and `units`.

`computeYangLedgerBalances.m` sums scopes and directions using `rows.moles` without checking unit compatibility.

This can produce purity, recovery, and balance residuals that look meaningful while summing `mol`, `native_integrated_units`, `native_inventory_units`, and `unknown_adapter_units`. That is not accounting. That is numerology with a table schema.

Required fix:

Introduce basis/unit compatibility filtering.

Recommended helper:

```matlab
[rowsOut, basisReport] = selectYangLedgerRowsByCompatibleBasis(rows, varargin)
```

Minimum behaviour:

- For final metrics, count only rows that are physically meaningful external stream moles.
- Preferred acceptable rows:
  - `units == "mol"`;
  - basis strings clearly indicating physical moles, for example `physical_moles_from_available_scale_factors`, `physical_moles`, or adapter `flowReport.moles` rows if present.
- Reject, or mark unavailable, rows with:
  - `native_integrated_units`;
  - `native_inventory_units`;
  - `unknown_adapter_units`;
  - mixed `units`;
  - mixed incompatible `basis`.
- Metric rows must use `pass=false` and `value=NaN` when physical external stream basis is unavailable.
- Do not silently compute final H2 purity/recovery from native unit rows.

For balances:

- Either compute only within compatible unit groups or mark the balance row as failed/unavailable.
- Do not sum native counter-tail stream rows with physical inventory deltas unless a documented conversion exists.
- Add `basis`/`notes` fields that explicitly state whether the balance was physical, native-only diagnostic, or unavailable due to incompatible units.

Optional acceptable conversion:

If native counter tails can be converted to physical moles using a defensible scale factor, implement that conversion as a wrapper-level utility, document the factor, test it, and set rows to `units="mol"`. Do not hide the conversion.

Acceptance tests:

Create `tests/four_bed/testYangLedgerBasisCompatibility.m` proving:

- internal transfer rows are excluded from product/recovery;
- metrics pass for compatible physical mole external rows;
- metrics fail with `NaN` for native-only external rows;
- metrics fail or warn for mixed physical/native basis;
- balance rows do not pass silently when incompatible units are mixed.

#### B5-06. Adapter audit schema is close but incomplete

Location:

- `scripts/four_bed/writeYangAdapterAuditReport.m`
- `inferFlowBasis`, around lines 110-130.

Problem:

The writer records useful identity, pressure, flow, conservation, sanity, warning, and architecture fields. It does not obviously include terminal physical-state checksums. It also records a generic surrogate basis string but does not explicitly encode all final-basis flags.

A further precision issue: `inferFlowBasis` can record native units as the primary basis whenever `flowReport.native.unitBasis` exists, even if `flowReport.moles` is also present and ledger extraction prefers physical moles.

Required fix:

Add these audit fields:

```matlab
audit.terminalPhysicalStateChecksums
audit.surrogateFlags.h2Co2Only = true
audit.surrogateFlags.feedRenormalizedOverH2Co2 = true
audit.surrogateFlags.activatedCarbonOnly = true
audit.surrogateFlags.homogeneousBed = true
audit.surrogateFlags.noZeolite5A = true
audit.surrogateFlags.noCO = true
audit.surrogateFlags.noCH4 = true
audit.runnerBasis = "wrapper_direct_coupling_adapter"
```

If adapter reports do not contain terminal states, add a compact terminal-state checksum to the adapter reports before writeback, not full state histories in compact audit mode.

Fix `inferFlowBasis`:

- Prefer physical moles if `flowReport.moles.unitBasis` is present and usable.
- Record native basis as secondary diagnostic when both physical and native reports exist.
- Do not label the audit’s primary flow basis as native if the ledger used physical mole rows.

Acceptance test:

Extend `tests/four_bed/testYangAdapterAuditReportWrite.m` to assert the new audit fields exist and compact mode still omits full `debugStateHistory`.

#### B5-07. Native valve coefficients are exposed but not visibly wired

Location:

- `scripts/four_bed/normalizeYangFourBedControls.m` exposes:
  - `Cv_EQI`
  - `Cv_EQII`
  - `Cv_BD_waste`
  - adapter coefficients
- `runYangFourBedCycle.m` only visibly passes adapter coefficients into adapter configs.

Problem:

The final basis treats valve coefficients as optimisation/sensitivity variables. Adapter valve coefficients are wired. Native route coefficients are not obviously applied to native temporary cases.

Required fix:

For native routes, either:

1. Wire `Cv_EQI`, `Cv_EQII`, `Cv_BD_waste`, and any AD feed/product controls into the local native params using wrapper-level temporary-case configuration; or
2. Explicitly mark these controls as not yet wired and make commissioning sensitivity tests fail or skip with a clear diagnostic.

Preferred fix is option 1 if a narrow native-step valve hook already exists. Do not rewrite core pressure-flow logic. Do not add tanks or headers.

Acceptance test:

In the valve sensitivity smoke, perturb each wired valve coefficient and confirm that at least one relevant endpoint diagnostic or stream total changes finitely. If a native valve coefficient is intentionally not wired, the test must report it as a known failed commissioning item, not silently pass.

#### B5-08. Existing Batch 5 tests are not commissioning tests

Location:

- `tests/four_bed/testYangFourBedCycleLedgerSmoke.m`
- `tests/four_bed/testYangFourBedSimulationCssPlumbing.m`
- adapter contract tests

Problem:

The current tests are useful, but many use spy native runners or `adapterValidationOnly=true`. They prove schema, routing, and writeback contracts, not real native/adapted dynamics.

Required fix:

Do not remove these tests. Add Batch 6 tests that run real native/adapted paths with finite controls.


#### B5-09. Compact cycle-level ledger export is not obvious

Location:

- Static search found `writeYangAdapterAuditReport.m` but did not find a wrapper-level ledger export helper such as `writeYangFourBedLedgerArtifacts.m`.
- Existing native toPSAil `savePsaSimulationResults.m` is not a Yang wrapper-ledger export.

Problem:

The final basis asks for wrapper-level audit/output artifacts. Adapter JSON audit exists, but a compact cycle/simulation ledger artifact is not obvious. Returning the ledger in memory is necessary, but not sufficient if final commissioning expects reproducible file artifacts.

Required fix:

Add a small wrapper-level export helper if not already present under another name:

```matlab
scripts/four_bed/writeYangFourBedLedgerArtifacts.m
```

It should write, at minimum:

- `streamRows`;
- `balanceRows`;
- `metricRows`;
- `cssRows`, when present;
- compact metadata JSON or MAT summary.

Do not depend on native toPSAil output files as the primary Yang ledger. The wrapper ledger is authoritative.

Acceptance test:

In the one-cycle smoke, write artifacts to a temp directory and assert the files exist, are non-empty, and include stream rows and metric rows.

#### B5-10. Simulation pass semantics may conflate "ran" with "CSS reached"

Location:

- `scripts/four_bed/runYangFourBedSimulation.m`

Problem:

Static inspection found that simulation pass semantics appear CSS-centric. A one-cycle smoke can run successfully while not satisfying CSS. That should not be reported as a failed numerical run.

Required fix:

Split status flags if not already split:

```matlab
simReport.runCompleted
simReport.cssPass
simReport.acceptancePass
simReport.stopReason
```

`runCompleted` should mean the requested cycles executed without fatal numerical/schema failure. `cssPass` should mean the CSS tolerance was met. `acceptancePass` can be stricter for commissioning.

Acceptance test:

CSS smoke must distinguish a finite `max_cycles_reached` run from a broken run.


## 3. Implementation sequence

Follow this order. It is designed so failures surface early instead of hiding under later cycle tests.

### Step 1. Add preflight runtime checker

Create:

```matlab
scripts/four_bed/assertYangRuntimeTemplateReady.m
```

or equivalent.

It should check:

- H2/CO2-only component names and order.
- AC-only/homogeneous surrogate metadata.
- required native runtime fields.
- `nColSt`, `nColStT`, `nComs`, `nVols`, `nStates`, `nStatesT`.
- `nColStT - nColSt == 2*nComs`.
- `params.initStates` shape and length.
- `params.tiScaleFac` exists for second-to-dimensionless conversion.
- no CO/CH4/zeolite/layered-bed active flags.

Return a report struct with `pass`, `failures`, `warnings`.

### Step 2. Fix native temporary run preparation and report propagation

Modify:

```matlab
scripts/four_bed/runYangTemporaryCase.m
```

Add or refactor through:

```matlab
scripts/four_bed/prepareYangNativeLocalRunParams.m
```

The native path should become conceptually:

```matlab
[params, prepReport] = prepareYangNativeLocalRunParams( ...
    opts.TemplateParams, tempCase, ...
    'DurationSeconds', opts.DurationSeconds, ...
    'DurationDimless', opts.DurationDimless);

[tDom, timeReport] = resolveYangNativeTimeDomain(params, opts, tempCase);

[stTime, stStates, flags] = runPsaCycleStep(params, params.initStates, tDom, 1, 1);

[terminalLocalStates, counterTailReport] = extractYangTerminalLocalStates(params, stStates, tempCase);

runReport = baseReport(tempCase, "native");
runReport.didInvokeNative = true;
runReport.localRunPreparation = prepReport;
runReport.durationSeconds = timeReport.durationSeconds;
runReport.durationDimless = timeReport.durationDimless;
runReport.timeBasis = timeReport.timeBasis;
runReport.timeDomain = tDom;
runReport.stTime = stTime;
runReport.stStates = stStates;
runReport.flags = flags;
runReport.counterTailReport = counterTailReport;
runReport.counterTailDeltas = computeCounterTailDeltas(params, stStates, tempCase.nLocalBeds);
```

This is wrapper-level plumbing. It must not alter core adsorber balances.

### Step 3. Make runtime template finalisation explicit

Modify or add:

```matlab
params/yang_h2co2_ac_surrogate/buildYangH2Co2AcTemplateParams.m
params/yang_h2co2_ac_surrogate/finalizeYangH2Co2AcTemplateParams.m
```

Use existing toPSAil helper functions. If the builder already has enough fields once called with certain options, document those options in a test and in a short case note.

Add metadata:

```matlab
params.yangRuntimeFinalization = struct( ...
    "finalized", true, ...
    "basis", "H2_CO2_homogeneous_activated_carbon_surrogate", ...
    "usesExistingToPSAilAdsorberPhysics", true);
```

### Step 4. Make ledgers and metrics basis-safe

Modify:

```matlab
scripts/four_bed/computeYangPerformanceMetrics.m
scripts/four_bed/computeYangLedgerBalances.m
```

Potential new helper:

```matlab
scripts/four_bed/classifyYangLedgerRowBasis.m
scripts/four_bed/selectYangCompatibleLedgerRows.m
```

Minimum required metric behaviour:

```matlab
productRows = compatibleRows(cycleRows, "external_product", "mol");
feedRows = compatibleRows(cycleRows, "external_feed", "mol");

if unavailable or mixed incompatible
    value = NaN;
    pass = false;
    notes = "external physical-mole basis unavailable or mixed";
end
```

Do not break tests proving internal transfers are excluded. Extend them to include basis compatibility.

### Step 5. Improve adapter audit schema

Modify:

```matlab
scripts/four_bed/writeYangAdapterAuditReport.m
```

Also modify adapter reports if needed:

```matlab
scripts/four_bed/runYangPpPuAdapter.m
scripts/four_bed/runYangAdppBfAdapter.m
```

Add terminal checksums and surrogate flags. Keep compact audit compact. Full state histories only belong under debug modes.

### Step 6. Add commissioning tests

Add tests in the staged order below.

## 4. Batch 6 commissioning test ladder

Create or extend a runner:

```matlab
scripts/run_four_bed_commissioning_tests.m
```

The runner should execute the stages below in order, print clear pass/fail results, and stop at the first stage by default. Provide an option to continue after failures for diagnostic sweeps.

Do not rely on spy native runners for commissioning stages 3 and above. Spy tests may remain as unit tests.

### Stage 0: static architecture and manifest gates

Tests:

```matlab
tests/four_bed/testYangBatch6StaticArchitectureGate.m
```

Must check:

- normalised schedule duration units `[1,6,1,4,1,1,4,1,1,5] / 25`;
- operation plan has expected 24 groups and 40 bed-step participations;
- all four beds A/B/C/D appear;
- native/adapted route classification is correct;
- no files under four-bed wrapper introduce a global four-bed RHS/DAE;
- no dynamic internal tank/header inventory is used for Yang transfers;
- no CO, CH4, zeolite, or layered-bed behaviour is active in the surrogate path;
- raw Yang labels remain metadata, not executable timing.

Suggested static searches:

- fail on wrapper production use of strings like `internalTank`, `sharedHeader`, `fourBedRhs`, `globalRhs`, unless they appear in guard tests, documentation, or explicit negative checks;
- fail on active component names `CO`, `CH4` in surrogate execution paths, while allowing mentions in documentation/tests that assert exclusion.

### Stage 1: state persistence gates

Tests:

```matlab
tests/four_bed/testYangBatch6StatePersistenceGate.m
```

Must check:

- persistent bed state vectors have length `params.nColSt`, not `params.nColStT`;
- counter tails are not persisted;
- counter tails are zero-initialised only for temporary native execution;
- local/global writeback maps correctly for all bed-pair combinations;
- non-participating beds remain bitwise or `isequaln` unchanged;
- CSS residuals use physical states only.

Reuse existing tests where possible, but add a single integrated gate that runs them or duplicates the important assertions.

### Stage 2: runtime template readiness

Tests:

```matlab
tests/four_bed/testYangRuntimeTemplateReadiness.m
```

Must check:

- finalised template passes `assertYangRuntimeTemplateReady`;
- one-bed native local params can be prepared from the standard template;
- two-bed native local params can be prepared from the standard template;
- `DurationSeconds` is converted to dimensionless using `tiScaleFac`;
- missing `tiScaleFac` fails clearly;
- `params.initStates` length matches `params.nStatesT`.

### Stage 3: real native smoke tests

Tests:

```matlab
tests/four_bed/testYangNativeSinglePairSmoke.m
```

Required smokes:

1. AD single-bed native run.
2. BD single-bed native run.
3. EQI two-bed native pair run.
4. EQII two-bed native pair run.

For each:

- use finite short duration;
- use finalised H2/CO2 AC template;
- do not use spy runner;
- assert `didInvokeNative == true`;
- assert `stStates` exists;
- assert `counterTailDeltas` exists;
- assert terminal local states are physical-only;
- assert `extractYangNativeLedgerRows` returns rows with correct scope/category;
- assert no NaNs, negative absolute pressures, or invalid mole fractions in terminal physical states.

If a native smoke fails because runtime template finalisation is incomplete, fix the finalisation. Do not replace the smoke with a spy.

### Stage 4: dynamic adapter smoke tests

Tests:

```matlab
tests/four_bed/testYangAdapterDynamicSmoke.m
```

Required smokes:

1. PP->PU adapter with finite `Cv_PP_PU_internal` and `Cv_PU_waste`.
2. AD&PP->BF adapter with finite `Cv_ADPP_feed`, `Cv_ADPP_product`, and `Cv_ADPP_BF_internal`.

For each:

- set `validationOnly=false`;
- assert `didInvokeNative == true`;
- assert time basis is seconds converted to dimensionless or explicit dimensionless;
- assert pressure diagnostics exist for donor and receiver;
- assert flow report exists;
- assert conservation diagnostics exist;
- assert sanity diagnostics pass or report finite residuals;
- assert no NaNs and no negative absolute pressures.

For PP->PU:

- donor product-end internal outflow and receiver product-end internal inflow must be present;
- receiver feed-end waste must be present;
- internal transfer must not be counted as external product.

For AD&PP->BF:

- external feed, external product, and internal BF transfer must be separate branches;
- effective split must be finite when product plus BF flow is nonzero;
- changing `Cv_ADPP_BF_internal` must change the effective split or explicitly produce a known zero-flow diagnostic.

### Stage 5: ledger and metrics gates

Tests:

```matlab
tests/four_bed/testYangLedgerBasisCompatibility.m
tests/four_bed/testYangBatch6MetricsGate.m
```

Must check:

- external feed denominator uses only `external_feed`;
- external product numerator uses only `external_product`;
- `internal_transfer` is never counted in external product/recovery;
- AD&PP->BF internal BF stream is not double-counted as product;
- metrics pass only for physical mole rows or a documented compatible physical basis;
- metrics fail with `NaN` and explanatory notes for native-only or mixed-basis rows;
- balances do not pass silently when unit bases are incompatible;
- balance summaries include basis compatibility diagnostics.

### Stage 6: full one-cycle smoke

Tests:

```matlab
tests/four_bed/testYangOneCycleH2Co2AcSmoke.m
```

Must execute one full normalised Yang cycle with:

- finalised H2/CO2 AC template;
- persistent A/B/C/D container;
- real native route, not spy;
- dynamic adapters, not validation-only;
- finite valve coefficients;
- wrapper ledger enabled;
- adapter audit enabled to a temp directory.

Assertions:

- all 24 operation groups executed;
- all four beds remain physical-only persistent states;
- non-participant preservation checks pass per operation;
- adapter audit files exist for adapter operations;
- no dynamic internal tank/header inventory flags are violated;
- ledger rows include all expected scopes;
- final metrics are either physically computed from compatible `mol` rows or explicitly unavailable with `pass=false`;
- no silent mixed-basis metric pass.

### Stage 7: CSS smoke

Tests:

```matlab
tests/four_bed/testYangCssSmokeH2Co2Ac.m
```

Run a short simulation:

- 2-3 cycles maximum;
- finite valve coefficients;
- real native/adapted paths;
- no claim of full Yang reproduction.

Assertions:

- `cssHistory` exists;
- each row uses physical bed states;
- residual values are finite;
- stop reason is clear:
  - `css_tolerance_satisfied`, or
  - `max_cycles_reached`;
- `simReport.pass` semantics are clear.

Recommended improvement:

Split report flags if not already done:

```matlab
simReport.runCompleted
simReport.cssPass
simReport.acceptancePass
```

Do not let a one-cycle numerical smoke be reported as a CSS failure in a way that obscures whether the cycle actually ran. Humans already invented enough ambiguous booleans.

### Stage 8: valve-coefficient sensitivity smoke

Tests:

```matlab
tests/four_bed/testYangValveCoefficientSensitivitySmoke.m
```

Perturb at least:

- `Cv_PP_PU_internal`
- `Cv_PU_waste`
- `Cv_ADPP_product`
- `Cv_ADPP_BF_internal`

If native coefficients are wired, also perturb:

- `Cv_EQI`
- `Cv_EQII`
- `Cv_BD_waste`

Assertions:

- perturbations produce finite runs;
- at least one relevant diagnostic changes:
  - pressure endpoint;
  - stream total;
  - effective split;
  - balance residual;
  - external-basis H2 metric, if physical metrics are available;
- unchanged diagnostics must be reported as sensitivity failure unless there is a documented zero-flow or saturated-control condition.

Keep this test small. It is not optimisation.

## 5. Expected files to edit or add

Likely edits:

```text
scripts/four_bed/runYangTemporaryCase.m
scripts/four_bed/injectYangLocalStatesIntoTemplateParams.m
scripts/four_bed/extractYangNativeLedgerRows.m
scripts/four_bed/computeYangPerformanceMetrics.m
scripts/four_bed/computeYangLedgerBalances.m
scripts/four_bed/writeYangAdapterAuditReport.m
scripts/four_bed/runYangPpPuAdapter.m
scripts/four_bed/runYangAdppBfAdapter.m
scripts/four_bed/normalizeYangFourBedControls.m
params/yang_h2co2_ac_surrogate/buildYangH2Co2AcTemplateParams.m
```

Likely new files:

```text
scripts/four_bed/assertYangRuntimeTemplateReady.m
scripts/four_bed/prepareYangNativeLocalRunParams.m
scripts/four_bed/resolveYangNativeTimeDomain.m
scripts/four_bed/computeYangCounterTailDeltasFromStates.m
scripts/four_bed/classifyYangLedgerRowBasis.m
scripts/four_bed/selectYangCompatibleLedgerRows.m
scripts/run_four_bed_commissioning_tests.m

tests/four_bed/testYangNativeTemporaryCaseReportCounters.m
tests/four_bed/testYangRuntimeTemplateReadiness.m
tests/four_bed/testYangNativeSinglePairSmoke.m
tests/four_bed/testYangAdapterDynamicSmoke.m
tests/four_bed/testYangLedgerBasisCompatibility.m
tests/four_bed/testYangBatch6StaticArchitectureGate.m
tests/four_bed/testYangBatch6StatePersistenceGate.m
tests/four_bed/testYangBatch6MetricsGate.m
tests/four_bed/testYangOneCycleH2Co2AcSmoke.m
tests/four_bed/testYangCssSmokeH2Co2Ac.m
tests/four_bed/testYangValveCoefficientSensitivitySmoke.m
```

Add fewer files if cleanly integrating into existing helpers is simpler. Do not add a sprawling second abstraction layer just because software always dreams of becoming a filing cabinet.

## 6. Test runner expectations

A reasonable commissioning runner should look like this in spirit:

```matlab
function results = run_four_bed_commissioning_tests(varargin)
    parser = inputParser;
    addParameter(parser, 'StopOnFailure', true);
    parse(parser, varargin{:});
    opts = parser.Results;

    testNames = [
        "testYangBatch6StaticArchitectureGate"
        "testYangBatch6StatePersistenceGate"
        "testYangRuntimeTemplateReadiness"
        "testYangNativeTemporaryCaseReportCounters"
        "testYangNativeSinglePairSmoke"
        "testYangAdapterDynamicSmoke"
        "testYangLedgerBasisCompatibility"
        "testYangBatch6MetricsGate"
        "testYangOneCycleH2Co2AcSmoke"
        "testYangCssSmokeH2Co2Ac"
        "testYangValveCoefficientSensitivitySmoke"
    ];

    results = table();
    for i = 1:numel(testNames)
        name = testNames(i);
        try
            feval(name);
            status = "pass";
            message = "";
        catch err
            status = "fail";
            message = string(err.identifier) + ": " + string(err.message);
            if opts.StopOnFailure
                fprintf('%s failed: %s\n', name, message);
                rethrow(err);
            end
        end
        results = [results; table(name, status, message)]; %#ok<AGROW>
    end
end
```

The exact implementation can differ, but the runner must be deterministic and easy to execute from the repository root after `addpath(genpath(pwd))`.

## 7. Acceptance criteria

Batch 6 is accepted only if all of the following are true:

1. Existing Batch 1-5 tests still pass.
2. New Batch 6 commissioning tests pass, or fail only with clearly documented numerical blockers that are outside the assigned scope.
3. Real native AD, BD, EQI, and EQII smoke tests run without spy native runners.
4. PP->PU and AD&PP->BF dynamic adapter smoke tests run with `validationOnly=false`.
5. Native run reports expose `stStates` and/or `counterTailDeltas` usable by native ledger extraction.
6. Native duration handling is dimensionless and consistent with adapter duration handling.
7. Single-bed native temp cases can run from the standard template path.
8. Metrics do not silently pass on native-only, mixed, or unknown ledger bases.
9. Internal transfers are excluded from external product/recovery.
10. AD&PP->BF internal BF transfer is not double-counted as product.
11. Adapter audits include identity, pressure endpoints, flow basis, terminal checksum, conservation, sanity, valve coefficients, and surrogate flags.
12. No dynamic internal tanks, shared header inventory, or global four-bed RHS/DAE are introduced.
13. Persistent bed states remain physical-only.
14. Valve sensitivity smoke demonstrates finite and interpretable response for every wired optimisation-facing coefficient.

## 8. Handoff note requirements

At the end of the implementation, add or update a handoff note, for example:

```text
docs/four_bed/batch6_commissioning_handoff.md
```

It must include:

- commit or working-tree summary;
- list of files edited/added;
- exact tests run;
- pass/fail table;
- any MATLAB version/toolbox assumptions;
- unresolved failures and whether they are:
  - architecture issue,
  - parameter/runtime-initialisation issue,
  - numerical tuning issue,
  - ledger/accounting issue,
  - test harness issue;
- statement that no CO/CH4/zeolite/layered-bed expansion was added;
- statement that no dynamic internal tanks/shared headers/global four-bed RHS were added.

## 9. Notes on numerical humility

This commissioning batch proves implementation architecture and smoke-level numerical execution. It does not prove quantitative reproduction of Yang 2009. The final basis is explicit that the implemented model is a simplified H2/CO2 activated-carbon surrogate. Do not write claims that the final code reproduces Yang’s four-component layered-bed results.

If the implementation reaches CSS in a short smoke, report it. If it does not, report finite residual trends and stop reason. Do not adjust tolerances until "pass" falls out like a vending-machine snack.

## 10. Minimal order of attack

For practical work, use this order:

1. Fix native run report propagation.
2. Fix native time-domain conversion.
3. Fix local native params for one-bed and two-bed cases.
4. Finalise runtime template readiness.
5. Add native smoke tests.
6. Add adapter dynamic smoke tests.
7. Make metrics/balances basis-safe.
8. Add one-cycle smoke.
9. Add CSS smoke.
10. Add valve sensitivity smoke.
11. Add audit schema improvements and audit assertions.
12. Run the complete commissioning runner.
13. Write handoff note.

That order avoids spending three days debugging a full-cycle simulation only to discover the first AD step was never runnable. A minor mercy, but civilisation advances in small increments.
