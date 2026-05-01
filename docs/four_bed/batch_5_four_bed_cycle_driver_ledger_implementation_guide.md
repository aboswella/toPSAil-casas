# Batch 5 implementation guide: four-bed cycle driver and wrapper ledger

## Assignment

You are implementing **Batch 5** of the final four-bed toPSAil implementation. This batch covers:

- **FI-6 Four-bed cycle driver**: execute the normalised Yang-inspired cycle over persistent named bed states `A/B/C/D`.
- **FI-7 Ledger extraction and audit output**: reconstruct Yang-basis stream accounting and H2 purity/recovery from wrapper-owned ledger rows, not from native toPSAil product metrics.

This guide is for a fresh Codex agent working from the most recent repository snapshot after Batch 4 has landed. Treat previous implementation guides and code as useful but fallible. Verify every contract before leaning on it.

Place this guide in the repository at:

```text
docs/four_bed/batch_5_four_bed_cycle_driver_ledger_implementation_guide.md
```

## Critical assessment of the prior Batch 5 summary

The prior high-level summary was directionally correct:

- The previous completed batch is Batch 4, implementing the AD&PP→BF adapter.
- The next batch is Batch 5, implementing the full four-bed cycle driver plus wrapper ledger/audit extraction.
- Batch 5 must preserve the thin-wrapper architecture, physical-state-only persistence, adapter-level direct coupling, and external-basis metrics.

However, the summary under-specified several important risks visible in the current repository snapshot. Do not carry those omissions forward.

### Corrections and added cautions

1. **Static review is not dynamic proof.** Batch 4 appears structurally consistent, but there is no evidence that MATLAB/Octave dynamic runs were executed in this environment. Batch 5 must preserve validation-only and spy-run modes for tests, while clearly marking outputs from those modes as non-physical.

2. **The existing ledger balance helper appears to need a preflight fix.** Inspect `scripts/four_bed/computeYangLedgerBalances.m` before adding new ledger code. In the current snapshot, `appendBalanceRow` appears to pass `feed` twice into the balance-row table, which risks a column-count or column-shift failure. Run the ledger tests. If they fail, fix this before building Batch 5 on top of it.

3. **Native temporary-state injection may still reject physical-only persistent states.** `injectYangLocalStatesIntoTemplateParams.m` currently expects local states of length `params.nColStT`. Persistent Yang bed states should be physical-only payloads of length `params.nColSt`. Batch 5 must either harden this helper or add a narrow wrapper so native calls can append zero counter tails for temporary execution only. Counter tails must still not be persisted.

4. **Pair source columns can differ.** `getYangDirectTransferPairMap.m` explicitly records that pair source columns may differ. Batch 5 therefore needs an explicit operation plan, not a casual loop over source-column rows pretending every displayed column is a clean simultaneous execution group. The operation plan must record donor and receiver source columns, duration policy, and any source-column mismatch warnings.

5. **Adapter report flow basis must be normalised by the ledger extractor.** Batch 4 reports typically set `adapterReport.flows = flowReport.native`, while physical moles may live under `adapterReport.flowReport.moles` only when `params.nScaleFac` is available. Batch 5 must choose the best available basis deliberately and write that basis into ledger rows. It must not assume all adapter reports already contain physical moles.

6. **Batch 5 should not become Batch 6.** Add focused tests for cycle-driver contracts, ledger extraction, audit writing, and CSS-loop plumbing. Do not absorb the full commissioning ladder, valve-sensitivity campaign, or optimisation-readiness acceptance suite. That belongs to Batch 6.

## Active source of truth

Read these files before editing anything:

1. `AGENTS.md`
2. `docs/four_bed/README.md`
3. `docs/four_bed/FINAL_IMPLEMENTATION_CONTEXT.md`
4. `docs/four_bed/batch_1_schedule_state_persistence_implementation_guide.md`
5. `docs/four_bed/batch_2_h2co2_ac_parameter_pack_implementation_guide.md`
6. `docs/four_bed/batch_3_pp_pu_direct_coupling_adapter_implementation_guide.md`
7. `docs/four_bed/batch_4_adpp_bf_direct_coupling_adapter_implementation_guide.md`
8. `docs/BOUNDARY_CONDITION_POLICY.md`
9. `docs/KNOWN_UNCERTAINTIES.md`
10. `docs/TEST_POLICY.md`
11. `docs/CODEX_PROJECT_MAP.md`

The old WP1-WP5 docs and `docs/workflow/*.csv` files are legacy. Use them only for old risk IDs, historical rationale, or contradiction checks. They do not define this batch.

## Current repository baseline

Expected existing files from earlier batches include:

```text
scripts/four_bed/getYangFourBedScheduleManifest.m
scripts/four_bed/getYangNormalizedSlotDurations.m
scripts/four_bed/getYangDirectTransferPairMap.m
scripts/four_bed/makeYangFourBedStateContainer.m
scripts/four_bed/selectYangFourBedSingleState.m
scripts/four_bed/selectYangFourBedPairStates.m
scripts/four_bed/writeBackYangFourBedStates.m
scripts/four_bed/makeYangTemporarySingleCase.m
scripts/four_bed/makeYangTemporaryPairedCase.m
scripts/four_bed/runYangTemporaryCase.m
scripts/four_bed/runYangDirectCouplingAdapter.m
scripts/four_bed/runYangPpPuAdapter.m
scripts/four_bed/runYangAdppBfAdapter.m
scripts/four_bed/makeYangFourBedLedger.m
scripts/four_bed/appendYangLedgerStreamRows.m
scripts/four_bed/computeYangLedgerBalances.m
scripts/four_bed/computeYangPerformanceMetrics.m
scripts/four_bed/computeYangFourBedCssResiduals.m
params/yang_h2co2_ac_surrogate/buildYangH2Co2AcTemplateParams.m
```

The following Batch 5 files are expected to be missing and should be implemented:

```text
scripts/four_bed/runYangFourBedCycle.m
scripts/four_bed/runYangFourBedSimulation.m
scripts/four_bed/extractYangNativeLedgerRows.m
scripts/four_bed/writeYangAdapterAuditReport.m
```

Recommended additional helper files:

```text
scripts/four_bed/buildYangFourBedOperationPlan.m
scripts/four_bed/validateYangFourBedOperationPlan.m
scripts/four_bed/normalizeYangFourBedControls.m
scripts/four_bed/extractYangAdapterLedgerRows.m
scripts/four_bed/appendYangBedInventoryDeltaRows.m
scripts/four_bed/chooseYangAdapterFlowBasis.m
```

Use additional helpers only where they reduce ambiguity. Do not create a new framework for the aesthetic thrill of naming abstractions.

## Scope boundaries

### You own

Primary implementation:

- Full-cycle driver for the fixed-duration Yang surrogate.
- Operation planning for single-bed and paired calls.
- Native/adapted call dispatch from the cycle driver.
- Local/global writeback orchestration.
- Wrapper-owned stream-ledger extraction for native and adapter calls.
- Adapter audit writing.
- CSS loop plumbing over physical bed states.
- Focused Batch 5 tests and a small Batch 5 test runner.

### You may make narrow interface hooks

You may make small, documented edits to existing wrapper helpers when necessary:

- `scripts/four_bed/injectYangLocalStatesIntoTemplateParams.m`  
  Allow physical-only local states of length `params.nColSt` by appending `zeros(2*params.nComs, 1)` for temporary native execution. Continue accepting native-length states of length `params.nColStT`. Report which happened.

- `scripts/four_bed/computeYangLedgerBalances.m`  
  Fix row-construction or balance-row schema bugs if existing ledger tests reveal them.

- `scripts/four_bed/validateYangFourBedLedger.m`  
  Only extend validation if new Batch 5 rows require harmless schema additions. Prefer preserving the current ledger schema.

- `scripts/four_bed/runYangTemporaryCase.m`  
  Only if needed to expose enough in-memory native-run data for `extractYangNativeLedgerRows.m`. Do not change native toPSAil core behaviour.

### You must not own

Do not implement or materially change:

- Core toPSAil adsorber mass, energy, pressure-flow, momentum, isotherm, valve, or solver equations in `3_source/`.
- Dynamic internal tanks or shared headers for Yang internal transfers.
- A global four-bed RHS/DAE.
- Event-based Yang scheduling.
- New physics for layered beds, zeolite 5A, CO, CH4, pseudo-components, or a full Yang reproduction.
- Optimisation or broad valve-sensitivity studies.
- Batch 6 commissioning acceptance gates beyond small Batch 5 smoke tests.

## Non-negotiable architecture

Batch 5 must preserve these rules:

1. The wrapper owns four persistent named physical bed states: `A`, `B`, `C`, `D`.
2. Every operation call uses a temporary one-bed or two-bed local case.
3. Local bed indices are solver conveniences only. They are never persistent physical identities.
4. Terminal local states are written back only to the participating global beds named in `selection.localMap`.
5. Non-participating beds remain unchanged after each operation group.
6. Counter tails are accounting data only. They are never persistent bed state.
7. Internal transfers are direct bed-to-bed streams with zero holdup.
8. Internal transfers never count as external product or H2 recovery numerator.
9. Wrapper ledger rows, not native toPSAil product metrics, define final Yang-basis H2 purity and recovery.
10. Pressure, flow-sign, sanity, and conservation diagnostics are reported per operation group where available.

## Batch 5 deliverables

At the end of this batch, the repository should contain:

1. A full-cycle driver that executes all expected Yang operation groups over `A/B/C/D` persistent states.
2. A simulation wrapper that repeats cycles and computes CSS residuals over physical bed states only.
3. Ledger extraction for adapter calls and native calls.
4. Compact adapter audit output.
5. Updated or new tests proving the Batch 5 contracts without pretending to complete Batch 6.
6. A short handoff note in the task report describing unresolved dynamic-run limitations, if any.

## Control structure

Implement or harden:

```text
scripts/four_bed/normalizeYangFourBedControls.m
```

Recommended signature:

```matlab
function controls = normalizeYangFourBedControls(controlsIn, templateParams)
```

The returned `controls` struct should contain stable field names so future sensitivity and optimisation wrappers can vary parameters without editing scheduler code.

Required fields, with defaults where safe:

```matlab
controls = struct();
controls.cycleTimeSec = getFieldOrDefault(controlsIn, 'cycleTimeSec', 240.0);
controls.feedVelocityCmSec = getFieldOrDefault(controlsIn, 'feedVelocityCmSec', NaN);

controls.Cv_EQI = getFieldOrDefault(controlsIn, 'Cv_EQI', NaN);
controls.Cv_EQII = getFieldOrDefault(controlsIn, 'Cv_EQII', NaN);
controls.Cv_PP_PU_internal = getFieldOrDefault(controlsIn, 'Cv_PP_PU_internal', NaN);
controls.Cv_PU_waste = getFieldOrDefault(controlsIn, 'Cv_PU_waste', NaN);
controls.Cv_ADPP_feed = getFieldOrDefault(controlsIn, 'Cv_ADPP_feed', NaN);
controls.Cv_ADPP_product = getFieldOrDefault(controlsIn, 'Cv_ADPP_product', NaN);
controls.Cv_ADPP_BF_internal = getFieldOrDefault(controlsIn, 'Cv_ADPP_BF_internal', NaN);
controls.Cv_BD_waste = getFieldOrDefault(controlsIn, 'Cv_BD_waste', NaN);

controls.nVols = getFieldOrDefault(controlsIn, 'nVols', getFieldOrDefault(templateParams, 'nVols', NaN));
controls.solverTolerances = getFieldOrDefault(controlsIn, 'solverTolerances', struct());
controls.componentNames = getFieldOrDefault(controlsIn, 'componentNames', {'H2'; 'CO2'});

controls.nativeRunner = getFieldOrDefault(controlsIn, 'nativeRunner', @runYangTemporaryCase);
controls.adapterValidationOnly = getFieldOrDefault(controlsIn, 'adapterValidationOnly', false);
controls.debugKeepStateHistory = getFieldOrDefault(controlsIn, 'debugKeepStateHistory', false);
controls.auditOutputMode = getFieldOrDefault(controlsIn, 'auditOutputMode', 'compact');

controls.operationPlanPolicy = getFieldOrDefault(controlsIn, 'operationPlanPolicy', 'topological_per_bed_sequence');
controls.pairedDurationPolicy = getFieldOrDefault(controlsIn, 'pairedDurationPolicy', 'donor_source_col');

controls.balanceAbsTol = getFieldOrDefault(controlsIn, 'balanceAbsTol', 1e-8);
controls.balanceRelTol = getFieldOrDefault(controlsIn, 'balanceRelTol', 1e-6);
controls.cssAbsTol = getFieldOrDefault(controlsIn, 'cssAbsTol', 1e-8);
controls.cssRelTol = getFieldOrDefault(controlsIn, 'cssRelTol', 1e-6);
```

Do not silently invent valve coefficients for production runs. It is acceptable to provide benign finite defaults for validation-only tests, but production runs should report missing valve controls as warnings or errors depending on the route.

Suggested helper:

```matlab
function value = getFieldOrDefault(s, name, defaultValue)
    if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
        value = s.(name);
    else
        value = defaultValue;
    end
end
```

Keep this helper local if it is only used in one file.

## Operation planning

### Why an operation plan is required

Do not implement the cycle by simply looping over the ten displayed manifest columns and running all labels in that column. The direct-pair map explicitly notes that pair source columns may differ. Some paired operations have a donor label and receiver label that appear in different source columns in the displayed Yang table.

The driver therefore needs a deterministic **operation plan** that turns the manifest and explicit pair map into executable operation groups while preserving each bed's source-column sequence.

Implement:

```text
scripts/four_bed/buildYangFourBedOperationPlan.m
scripts/four_bed/validateYangFourBedOperationPlan.m
```

Recommended signature:

```matlab
function plan = buildYangFourBedOperationPlan(manifest, pairMap, durations, varargin)
```

Options:

```matlab
'Policy'                         % default: 'topological_per_bed_sequence'
'PairedDurationPolicy'            % default: 'donor_source_col'
'AllowSourceColumnMismatchWarnings' % default: true
```

### Required plan contents

The returned `plan` should be a struct with at least:

```matlab
plan.policy
plan.pairedDurationPolicy
plan.durationUnits
plan.durationFractions
plan.durationSeconds
plan.operationGroups
plan.perBedSequences
plan.warnings
plan.source = 'manifest_plus_explicit_pair_map'
```

`plan.operationGroups` may be a struct array or table. Use whichever style is most consistent with existing code, but every operation group must expose these fields or equivalent columns:

```text
operationGroupId
operationFamily            % AD, BD, EQI, EQII, PP_PU, ADPP_BF
route                      % native_single, native_pair, adapter
stageLabel                 % source label such as AD, AD&PP, EQI-BD, EQII-PR, etc.
directTransferFamily       % empty for AD/BD; EQI/EQII/PP_PU/ADPP_BF for paired groups
sourceCol                  % primary executable source column, usually donor source column
durationSec
sourceDurationSec
sourceDurationFraction
participants               % cellstr of global beds
primaryBed                 % single-bed participant or donor bed
donorBed
receiverBed
receiverSourceCol
receiverDurationSec
pairId
localMap                   % mapping from local 1/2 to global bed labels
nativeStepSpec             % output from translateYangNativeOperation or equivalent
adapterFamily              % PP_PU or ADPP_BF for adapters
ledgerHints                % expected ledger stream scopes
notes
warnings
```

### Required operation inventory

A complete cycle plan should contain:

- 4 `AD` native single-bed groups.
- 4 `BD` native single-bed groups.
- 4 `EQI` native paired groups.
- 4 `EQII` native paired groups.
- 4 `PP_PU` adapter groups.
- 4 `ADPP_BF` adapter groups.

That is **24 operation groups** and **40 bed-step participations**.

Validate this explicitly. A missing operation group is not a small detail. It is a cycle that has wandered off into the bushes.

### Required per-bed sequence preservation

For each global bed, the ordered labels must match the manifest:

```text
A: AD, AD&PP, EQI-BD, PP, EQII-BD, BD, PU, EQII-PR, EQI-PR, BF
B: EQI-PR, BF, AD, AD&PP, EQI-BD, PP, EQII-BD, BD, PU, EQII-PR
C: BD, PU, EQII-PR, EQI-PR, BF, AD, AD&PP, EQI-BD, PP, EQII-BD
D: EQI-BD, PP, EQII-BD, BD, PU, EQII-PR, EQI-PR, BF, AD, AD&PP
```

The operation plan should topologically order operation groups so that each bed observes its own sequence. A simple way to do this:

1. Build one node for each single-bed operation and one node for each explicit pair-map row.
2. For each bed, convert its manifest labels into the corresponding node sequence.
3. Add directed edges between consecutive nodes in each bed sequence.
4. Topologically sort the resulting DAG using deterministic tie-breaking, for example by earliest primary source column, then operation-family rank, then donor/bed label.
5. Validate that all per-bed sequences are preserved in the sorted result.

If the graph is cyclic, fail with a targeted error:

```matlab
error('FI6:OperationPlanCycle', 'Unable to build a per-bed topological Yang operation plan.');
```

### Duration policy for paired groups

Single-bed operations use their own source-column duration.

For paired groups, use this default policy unless the user later supplies a more detailed atomic-time model:

```text
pairedDurationPolicy = 'donor_source_col'
```

This means:

- `durationSec` comes from the donor source column.
- `sourceCol` is the donor source column.
- `receiverSourceCol` and `receiverDurationSec` are recorded separately.
- If donor and receiver source columns or durations differ, record a warning in both the operation group and the cycle report.

Do **not** average donor and receiver durations, silently choose the longer duration, or create an overlap model. That would be a new scheduling assumption, not implementation of the agreed design basis.

## Cycle driver API

Implement:

```text
scripts/four_bed/runYangFourBedCycle.m
```

Recommended signature:

```matlab
function [nextContainer, cycleReport] = runYangFourBedCycle(container, templateParams, controls, varargin)
```

Required inputs:

- `container`: physical-state-only named bed container for `A/B/C/D`.
- `templateParams`: H2/CO2 activated-carbon surrogate params template.
- `controls`: struct normalised by `normalizeYangFourBedControls` or normalisable by it.

Recommended name-value options:

```matlab
'Manifest'
'PairMap'
'OperationPlan'
'CycleIndex'
'Ledger'
'AuditDir'
'WriteAdapterAudit'
'NativeRunner'
'AdapterValidationOnly'
'BalanceAbsTol'
'BalanceRelTol'
'StopOnOperationWarning'
```

Required outputs:

```matlab
nextContainer                 % physical-state-only A/B/C/D container
cycleReport                   % struct with fields below
```

`cycleReport` should include:

```matlab
cycleReport.cycleIndex
cycleReport.initialContainerChecksum
cycleReport.finalContainerChecksum
cycleReport.operationPlan
cycleReport.operationReports
cycleReport.ledger
cycleReport.balanceSummary
cycleReport.performanceMetrics
cycleReport.warnings
cycleReport.errors
cycleReport.architecture
```

The `architecture` field should state the invariants that were preserved:

```matlab
cycleReport.architecture.noDynamicInternalTanks = true;
cycleReport.architecture.noSharedHeaderInventory = true;
cycleReport.architecture.noGlobalFourBedRhs = true;
cycleReport.architecture.persistentStateBasis = 'physical_adsorber_state_only';
cycleReport.architecture.metricsBasis = 'wrapper_external_stream_ledger';
```

Do not make these flags decorative. Tests should assert them.

## Cycle driver algorithm

The core algorithm should be close to this:

```matlab
controls = normalizeYangFourBedControls(controls, templateParams);
manifest = getOrBuildManifest(varargin);
pairMap = getOrBuildPairMap(varargin);
durations = getYangNormalizedSlotDurations(controls.cycleTimeSec);
plan = getOrBuildOperationPlan(manifest, pairMap, durations, controls);
ledger = getOrCreateLedger(varargin);

currentContainer = container;
operationReports = [];

for k = 1:numel(plan.operationGroups)
    group = plan.operationGroups(k);

    initialSnapshot = currentContainer;
    initialInventory = inventoryForParticipants(currentContainer, group, templateParams);
    initialPressure = pressureForParticipants(currentContainer, group, templateParams);

    switch group.route
        case 'native_single'
            selection = selectYangFourBedSingleState(currentContainer, group.primaryBed, ...);
            tempCase = makeYangTemporarySingleCase(selection, group, templateParams, controls);
            [terminalLocalStates, nativeReport] = runNativeGroup(tempCase, templateParams, controls, group);
            streamRows = extractYangNativeLedgerRows(nativeReport, group, initialInventory, templateParams, controls);

        case 'native_pair'
            selection = selectYangFourBedPairStates(currentContainer, group.donorBed, group.receiverBed, ...);
            tempCase = makeYangTemporaryPairedCase(selection, group, templateParams, controls);
            [terminalLocalStates, nativeReport] = runNativeGroup(tempCase, templateParams, controls, group);
            streamRows = extractYangNativeLedgerRows(nativeReport, group, initialInventory, templateParams, controls);

        case 'adapter'
            selection = selectYangFourBedPairStates(currentContainer, group.donorBed, group.receiverBed, ...);
            tempCase = makeYangTemporaryPairedCase(selection, group, templateParams, controls);
            adapterConfig = makeAdapterConfigFromGroup(group, controls);
            [terminalLocalStates, adapterReport] = runYangDirectCouplingAdapter(tempCase, templateParams, adapterConfig);
            streamRows = extractYangAdapterLedgerRows(adapterReport, group, initialInventory, templateParams, controls);
            maybeWriteYangAdapterAuditReport(adapterReport, group, controls, varargin{:});

        otherwise
            error('FI6:UnknownOperationRoute', 'Unknown operation route: %s', group.route);
    end

    currentContainer = writeBackYangFourBedStates(currentContainer, selection, terminalLocalStates, ...);

    terminalInventory = inventoryForParticipants(currentContainer, group, templateParams);
    inventoryRows = appendYangBedInventoryDeltaRows(group, initialInventory, terminalInventory, controls);
    ledger = appendYangLedgerStreamRows(ledger, [streamRows; inventoryRows]);

    operationReports(k) = makeOperationReport(group, initialSnapshot, currentContainer, streamRows, inventoryRows, ...);
end

balanceSummary = computeYangLedgerBalances(ledger, ...);
performanceMetrics = computeYangPerformanceMetrics(ledger, ...);
nextContainer = currentContainer;
```

Important details:

- Write back after each operation group, not after the whole cycle.
- Do not let local states from one temporary case leak into another except through the named persistent container.
- Always map local outputs back through `selection.localMap` or equivalent. Never assume local bed 1 is always a particular global bed across the full cycle.
- Always append inventory-delta rows for the participating beds so conservation can be audited.
- Keep pressure diagnostics and warnings even when validation-only mode is used.


## Native operation route

Native-run candidates are:

| Operation family | Expected native route | Ledger meaning |
|---|---|---|
| `AD` | single-bed high-pressure feed/raffinate step, e.g. `HP-FEE-RAF` | external feed plus external H2-rich product |
| `BD` | single-bed depressurisation/waste step, e.g. `DP-ATM-XXX` | external waste |
| `EQI` | paired product-end equalisation if existing grammar supports it | internal transfer only |
| `EQII` | paired product-end equalisation if existing grammar supports it | internal transfer only |

Use `translateYangNativeOperation.m` where possible. Preserve `EQI` and `EQII` as separate stage identities even if they map to similar native mechanics. Downstream diagnostics need to distinguish them.

Recommended helper inside `runYangFourBedCycle.m` or separate file:

```matlab
function [terminalLocalStates, nativeReport] = runNativeGroup(tempCase, templateParams, controls, group)
    nativeRunner = controls.nativeRunner;
    [terminalLocalStates, nativeReport] = nativeRunner(tempCase, templateParams, group.nativeStepSpec, ...);
end
```

Match the actual `runYangTemporaryCase.m` signature in the repository. Do not reshape its API unless a small hook is unavoidable.

### Required native state-injection fix

Before implementing real native cycle calls, inspect:

```text
scripts/four_bed/injectYangLocalStatesIntoTemplateParams.m
```

It should accept both:

- physical-only local states of length `params.nColSt`, and
- native-length local states of length `params.nColStT`.

If the incoming state is physical-only, append zero counter tails only for the temporary native run:

```matlab
if numel(localState) == params.nColSt
    counterTail = zeros(params.nColStT - params.nColSt, 1);
    nativeState = [localState(:); counterTail];
elseif numel(localState) == params.nColStT
    nativeState = localState(:);
else
    error('FI3:InvalidYangLocalStateLength', ...);
end
```

Also verify the expected counter-tail length:

```matlab
assert(params.nColStT - params.nColSt == 2 * params.nComs);
```

If this assertion fails, do not guess. Raise a targeted error and document the actual dimensions.

This is a temporary execution hook, not a change in persistence policy. Terminal states written back to `A/B/C/D` must remain physical-only.

## Native ledger extraction

Implement:

```text
scripts/four_bed/extractYangNativeLedgerRows.m
```

Recommended signature:

```matlab
function [rows, nativeLedgerReport] = extractYangNativeLedgerRows(nativeReport, group, templateParams, controls, varargin)
```

Options:

```matlab
'InitialInventory'
'TerminalInventory'
'CycleIndex'
'OperationGroupId'
'ComponentNames'
'CounterSignPolicy'
```

The function should return stream rows compatible with `appendYangLedgerStreamRows.m`.

### Required stream mapping

| Operation family | Required stream rows |
|---|---|
| `AD` | `external_feed`, `external_product` |
| `BD` | `external_waste` |
| `EQI` | `internal_transfer` donor-out and receiver-in |
| `EQII` | `internal_transfer` donor-out and receiver-in |

Inventory deltas may be appended by a shared helper rather than `extractYangNativeLedgerRows.m`; either is acceptable, but do it consistently.

### Counter-tail extraction policy

For native calls, extract stream flow deltas in memory immediately after the call. The likely tail layout is:

```text
state(params.nColSt + 1 : params.nColSt + params.nComs)       % one boundary counter family
state(params.nColSt + params.nComs + 1 : params.nColStT)       % second boundary counter family
```

Do not assume the first family is feed-end and the second is product-end without checking the existing native code and tests. Add a small targeted test using synthetic state vectors to prove the mapping.

The extractor should:

1. Read initial and terminal counter tails where available.
2. Compute deltas.
3. Map deltas to expected stream rows based on operation family and boundary direction.
4. Validate signs against expected operation direction.
5. Attach `basis`, `units`, and `notes` fields to the rows or report.

Do not use `abs(delta)` as a casual cure for sign confusion. That is how software turns a leak into a “product stream.”

If the required native counters are unavailable, fail explicitly:

```matlab
error('FI7:NativeCounterTailUnavailable', ...);
```

Do not silently create zero stream rows for missing native flow data. Zero is a physical statement, not a placeholder for “I did not find the field.”

## Adapter ledger extraction

Implement:

```text
scripts/four_bed/extractYangAdapterLedgerRows.m
scripts/four_bed/chooseYangAdapterFlowBasis.m
```

Recommended signature:

```matlab
function [rows, adapterLedgerReport] = extractYangAdapterLedgerRows(adapterReport, group, templateParams, controls, varargin)
```

The adapter ledger extractor should normalise the report formats produced by both adapters.

### Flow basis chooser

`chooseYangAdapterFlowBasis.m` should choose the best available integrated branch flows in this order:

1. `adapterReport.flowReport.moles`, when present, complete, finite, and nonempty.
2. `adapterReport.flowReport.native`, when present and explicitly labelled as native/nondimensional or scaled basis.
3. `adapterReport.flows`, when present, with a warning if the basis is ambiguous.

Return:

```matlab
flowBasis.values
flowBasis.basis              % e.g. 'physical_moles', 'native_counter_units', 'unknown_adapter_units'
flowBasis.units
flowBasis.warning
flowBasis.sourceField
```

Ledger rows should carry this basis. If the final performance metric function requires physical moles, it must reject nonphysical basis rows or clearly mark the metric as unavailable.

### PP→PU adapter mapping

For `PP_PU`, create rows for:

- donor internal transfer out, `streamScope = 'internal_transfer'`, direction `out_of_donor`;
- receiver internal transfer in, `streamScope = 'internal_transfer'`, direction `into_receiver`;
- receiver waste, `streamScope = 'external_waste'`, direction `out`.

There must be **no** `external_product` row for PP→PU.

### AD&PP→BF adapter mapping

For `ADPP_BF`, create rows for:

- donor external feed, `streamScope = 'external_feed'`, direction `in`;
- donor external product, `streamScope = 'external_product'`, direction `out`;
- donor internal BF transfer out, `streamScope = 'internal_transfer'`, direction `out_of_donor`;
- receiver internal BF transfer in, `streamScope = 'internal_transfer'`, direction `into_receiver`.

There must be **no** external waste row unless the adapter report explicitly records a nonzero waste branch. In the current Batch 4 implementation, receiver waste is expected to be absent/zero.

The ledger extractor should copy effective split information from `adapterReport.effectiveSplit` or `adapterReport.flowReport.effectiveSplit` into the operation report, not into external product rows.

## Inventory delta rows

Implement:

```text
scripts/four_bed/appendYangBedInventoryDeltaRows.m
```

Recommended signature:

```matlab
function rows = appendYangBedInventoryDeltaRows(group, initialInventory, terminalInventory, controls, varargin)
```

For every participating bed and component, append a row with:

```text
streamScope = 'bed_inventory_delta'
direction = 'delta'
bed = global bed label
component = component name
amount = terminalInventory(component) - initialInventory(component)
basis = physical inventory basis
```

Use `computeYangBedComponentInventory.m` if already available. Do not invent a second inventory calculator unless the existing one is demonstrably insufficient.

## Ledger balance helper preflight

Before relying on `computeYangLedgerBalances.m`, run the existing ledger tests and inspect `appendBalanceRow`.

The balance-row constructor should produce exactly the table schema advertised by the helper. The intended row variables are expected to be close to:

```matlab
row = table( ...
    double(cycleIndex), ...
    double(slotIndex), ...
    string(balanceScope), ...
    string(operationGroupId), ...
    string(stageLabel), ...
    string(directTransferFamily), ...
    string(component), ...
    double(feed), ...
    double(product), ...
    double(waste), ...
    double(delta), ...
    double(internalOut), ...
    double(internalInto), ...
    double(residual), ...
    double(tol), ...
    logical(pass), ...
    string(basis), ...
    string(notes), ...
    'VariableNames', { ...
        'cycleIndex', 'slotIndex', 'balanceScope', 'operationGroupId', ...
        'stageLabel', 'directTransferFamily', 'component', ...
        'feed', 'product', 'waste', 'delta', ...
        'internalOut', 'internalInto', 'residual', 'tol', 'pass', ...
        'basis', 'notes'});
```

If the current implementation passes `feed` twice or shifts column positions, fix it and add a regression test. Batch 5 depends on this helper. Building a cycle ledger over a broken balance table would be the computational equivalent of carefully weighing smoke.

## Performance metrics

Use the existing `computeYangPerformanceMetrics.m` if it already satisfies these requirements:

- H2 purity uses only `external_product` rows.
- H2 recovery numerator uses only `external_product` rows.
- H2 recovery denominator uses only `external_feed` rows.
- `internal_transfer`, `external_waste`, and `bed_inventory_delta` are excluded from product/recovery numerator.
- Basis mismatches are rejected or reported.

If the helper does not enforce these requirements, patch it narrowly and add tests. Do not use native toPSAil product metrics for final Yang-basis output.


## Adapter audit output

Implement:

```text
scripts/four_bed/writeYangAdapterAuditReport.m
```

Recommended signature:

```matlab
function auditStatus = writeYangAdapterAuditReport(adapterReport, auditDir, varargin)
```

Options:

```matlab
'CycleIndex'
'SlotIndex'
'OperationGroupId'
'OperationFamily'
'DonorBed'
'ReceiverBed'
'LocalMap'
'OutputMode'          % default: 'compact'
'IncludeStateHistory' % default: false
'FileStem'
```

Required behaviour:

1. Create `auditDir` if it does not exist.
2. Write one compact artifact per adapter call.
3. Prefer JSON for compact scalar/vector diagnostics where supported. Use MAT only if the MATLAB version lacks adequate JSON support or if the report contains fields that cannot be safely serialised.
4. Do not dump full `stStates`, solver histories, or large state arrays unless `IncludeStateHistory` is explicitly true.
5. Return a status struct containing path, bytes written, output mode, warnings, and pass/fail state.

Required audit contents:

```text
cycleIndex
slotIndex
operationGroupId
operationFamily
directTransferFamily
donorBed
receiverBed
localMap
durationSec
valveCoefficients
initialPressureSummary
terminalPressureSummary
flowBasis
integratedFlowsByComponent
effectiveSplit
conservationResiduals
sanityDiagnostics
warnings
architectureFlags
surrogateBasis
```

The audit report is for debugging and reproducibility. It is not the primary source of ledger truth; the in-memory ledger is.

## Simulation loop API

Implement:

```text
scripts/four_bed/runYangFourBedSimulation.m
```

Recommended signature:

```matlab
function simReport = runYangFourBedSimulation(initialContainer, templateParams, controls, varargin)
```

Recommended options:

```matlab
'MaxCycles'       % default: 1 or 5 for smoke tests
'StopAtCss'       % default: false for smoke tests
'CssAbsTol'
'CssRelTol'
'Ledger'
'AuditDir'
'Manifest'
'PairMap'
'OperationPlan'
'WriteAdapterAudit'
'NativeRunner'
'AdapterValidationOnly'
'KeepCycleReports'
```

Required output fields:

```matlab
simReport.initialContainer
simReport.finalContainer
simReport.ledger
simReport.cycleReports
simReport.cssHistory
simReport.metrics
simReport.balanceSummary
simReport.stopReason
simReport.pass
simReport.warnings
simReport.architecture
```

Algorithm:

1. Normalise controls.
2. Initialise `ledger` and `cssHistory`.
3. For `cycleIndex = 1:MaxCycles`:
   - store previous physical container;
   - call `runYangFourBedCycle`;
   - compute CSS residuals with `computeYangFourBedCssResiduals(previousContainer, currentContainer, templateParams, ...)`;
   - append CSS summary row;
   - stop if `StopAtCss` and CSS tolerances are satisfied.
4. Compute final ledger balances and performance metrics.
5. Return final report.

CSS residuals must use physical bed states only. Validation-only runs may report numerical state changes from mocked or spy routes, but must not claim physical CSS unless all dynamic operations were actually run on physical/native data.

## Focused Batch 5 tests

Create tests under:

```text
tests/four_bed/
```

Recommended test files:

```text
testYangFourBedOperationPlanCompleteness.m
testYangNativeLedgerRowsSynthetic.m
testYangAdapterLedgerRowsFromReports.m
testYangAdapterAuditReportWrite.m
testYangFourBedCycleDriverSpyWriteback.m
testYangFourBedCycleLedgerSmoke.m
testYangFourBedSimulationCssPlumbing.m
```

Create or update a small runner:

```text
scripts/run_cycle_tests.m
```

### Test: operation plan completeness

`testYangFourBedOperationPlanCompleteness.m` should verify:

- exactly 24 operation groups;
- exactly four groups for each of `AD`, `BD`, `EQI`, `EQII`, `PP_PU`, `ADPP_BF`;
- exactly 40 bed-step participations;
- every global bed has the correct manifest label sequence;
- every pair operation comes from `getYangDirectTransferPairMap.m`, not inferred from row order;
- donor/receiver source-column mismatch warnings are present where expected;
- no operation group has an undefined route or duration.

### Test: native ledger rows, synthetic

`testYangNativeLedgerRowsSynthetic.m` should avoid requiring a full dynamic run. Use synthetic native reports or terminal state vectors with known counter-tail deltas to verify:

- AD produces external feed/product rows;
- BD produces external waste rows;
- EQI/EQII produce internal transfer rows;
- EQI and EQII remain separately labelled;
- sign conventions are checked;
- missing counters throw `FI7:NativeCounterTailUnavailable`.

### Test: adapter ledger rows from reports

`testYangAdapterLedgerRowsFromReports.m` should construct synthetic adapter reports for both adapters and verify:

- PP→PU has internal transfer plus external waste, no external product;
- AD&PP→BF has external feed, external product, internal BF transfer, no unintended waste;
- effective split is carried into the adapter ledger report;
- physical-mole basis is preferred when present;
- ambiguous/native basis is labelled and warned about.

### Test: adapter audit report write

`testYangAdapterAuditReportWrite.m` should verify:

- the writer creates a file under a temporary directory;
- the file includes identity, valve, flow, pressure, conservation, and architecture fields;
- full state histories are not included in compact mode;
- the returned status includes path and pass flag.

### Test: cycle driver spy writeback

`testYangFourBedCycleDriverSpyWriteback.m` should use a fake native runner and validation-only adapter mode or a fake adapter shim to avoid requiring full physical simulation. Verify:

- writeback occurs only for participating beds per operation group;
- local/global mapping is respected;
- non-participating beds remain unchanged after each group;
- terminal states remain physical-only length `params.nColSt`;
- operation reports contain expected identity metadata;
- no dynamic tank/header architecture flags are present.

### Test: cycle ledger smoke

`testYangFourBedCycleLedgerSmoke.m` should run one cycle in spy/validation mode and verify:

- ledger rows exist for external feed, external product, external waste, internal transfer, and bed inventory deltas;
- performance metrics exclude internal transfers;
- balance summary can be computed without schema errors;
- missing physical dynamic data is clearly marked if the run is spy/validation only.

### Test: simulation CSS plumbing

`testYangFourBedSimulationCssPlumbing.m` should verify:

- multiple cycles can be invoked in sequence;
- CSS residual rows are generated over physical states;
- `StopAtCss` stops when a fake runner returns unchanged states;
- `StopAtCss` does not falsely pass when fake states change beyond tolerance.

## Existing tests to run before and after

Before editing Batch 5 files, run the narrow preflight tests that already exist:

```matlab
scripts/run_sanity_tests
scripts/run_case_builder_tests
scripts/run_adapter_tests
scripts/run_ledger_tests
```

Then run the new Batch 5 runner:

```matlab
scripts/run_cycle_tests
```

Finally rerun the full relevant four-bed suite if the repository provides one. If MATLAB is unavailable in the implementation environment, record this explicitly in the handoff and provide static evidence plus test code. Do not claim tests passed if they were not executed. This is software, not wishful metallurgy.

## Expected file edits

### New files

```text
scripts/four_bed/runYangFourBedCycle.m
scripts/four_bed/runYangFourBedSimulation.m
scripts/four_bed/buildYangFourBedOperationPlan.m
scripts/four_bed/validateYangFourBedOperationPlan.m
scripts/four_bed/normalizeYangFourBedControls.m
scripts/four_bed/extractYangNativeLedgerRows.m
scripts/four_bed/extractYangAdapterLedgerRows.m
scripts/four_bed/chooseYangAdapterFlowBasis.m
scripts/four_bed/appendYangBedInventoryDeltaRows.m
scripts/four_bed/writeYangAdapterAuditReport.m
scripts/run_cycle_tests.m
```

### Possible narrow edits

```text
scripts/four_bed/injectYangLocalStatesIntoTemplateParams.m
scripts/four_bed/computeYangLedgerBalances.m
scripts/four_bed/computeYangPerformanceMetrics.m
scripts/four_bed/runYangTemporaryCase.m
scripts/four_bed/validateYangFourBedLedger.m
```

Every narrow edit should be described in the handoff note. If the change affects another batch's contract, include the before/after API and why it was unavoidable.

## Acceptance criteria

Batch 5 is acceptable when all of the following are true:

1. `runYangFourBedCycle.m` executes a full planned cycle over `A/B/C/D` in at least spy/validation mode.
2. The cycle driver can route all six operation families: `AD`, `BD`, `EQI`, `EQII`, `PP_PU`, and `ADPP_BF`.
3. Operation planning validates 24 groups and 40 bed-step participations.
4. Per-bed manifest order is preserved.
5. Persistent bed states after each operation and cycle are physical-only.
6. Counter tails are used for ledgers only and are not written back as persistent bed state.
7. Non-participating beds remain unchanged during each operation group.
8. Adapter outputs are converted into wrapper ledger rows with correct external/internal categories.
9. Native outputs are converted into wrapper ledger rows or fail with explicit targeted errors when required counters are unavailable.
10. H2 purity and recovery are reconstructed from external stream rows only.
11. Internal transfers are excluded from external product and recovery numerator.
12. Adapter audit reports are compact, identity-rich, and optional by configuration.
13. CSS loop plumbing computes residuals over physical states only.
14. No dynamic internal tanks, shared headers, global four-bed RHS/DAE, or core adsorber physics rewrites are introduced.
15. New Batch 5 tests pass in the available MATLAB environment, or the handoff clearly states that tests could not be executed and provides static evidence.

## Common traps and correct responses

| Trap | Correct response |
|---|---|
| Looping directly over manifest columns as if they are independent simultaneous slots | Build an explicit operation plan from manifest plus pair map. |
| Persisting `nColStT` native states | Persist only `nColSt` physical states. |
| Counting AD&PP internal BF gas as product | Keep external product and internal transfer in separate ledger rows. |
| Using native toPSAil product metrics as final Yang metrics | Recompute from wrapper ledger rows. |
| Treating validation-only adapter runs as physical performance | Mark basis and prevent false physical claims. |
| Losing EQI/EQII distinction | Preserve stage identity in operation groups, reports, ledgers, and audit files. |
| Using `abs(counterDelta)` to hide sign mistakes | Validate sign convention and fail or warn explicitly. |
| Dumping huge state histories into every audit report | Write compact diagnostics by default. |
| Creating dynamic tanks or shared headers for internal Yang transfers | Use direct coupling adapters and native paired calls only. |
| Implementing optimisation in Batch 5 | Stop at controls, sensitivity-ready metadata, and finite metrics. Optimisation belongs later. |

## Batch 6 boundary

Leave the following to Batch 6:

- full staged commissioning suite;
- adversarial acceptance tests across all implemented files;
- valve coefficient sensitivity sweeps;
- longer CSS smoke studies with real native dynamic runs;
- optimisation-readiness acceptance beyond finite hooks and correct metadata;
- broad regression tests against all legacy four-bed issues.

Batch 5 should make those tests possible. It should not try to become the final auditor of its own work.

## Handoff note required from the Codex agent

At the end of implementation, include a concise handoff note containing:

1. Files added and files modified.
2. Exact tests run and pass/fail status.
3. Whether MATLAB dynamic native runs were executed.
4. Whether adapter runs were real dynamic runs, validation-only runs, or synthetic report tests.
5. Any native state-injection hook added.
6. Any ledger balance/schema fix added.
7. Operation-plan duration policy used for paired source-column mismatches.
8. Known limitations or targeted errors that remain.
9. Confirmation that no dynamic internal tank/header, global four-bed RHS, or core physics rewrite was introduced.

The handoff should be factual. Do not write “should work” where the truth is “not run.” Future agents already have enough mysteries without inheriting optimism in a trench coat.
