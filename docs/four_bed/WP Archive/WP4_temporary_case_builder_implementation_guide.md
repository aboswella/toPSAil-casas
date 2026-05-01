# WP4 Implementation Guide: Temporary Two-Bed / Single-Step Case Builder

## Task card

**Task ID:** `WP4-YANG-TEMPORARY-CASE-BUILDER`

**Goal:** implement the wrapper-level case-builder layer that makes selected Yang four-bed states look like ordinary local toPSAil single-bed or paired-bed work, without building a four-bed solver. Yes, the whole point is to avoid inventing a new process simulator inside a process simulator. Apparently this needs saying.

**Work-package scope:** WP4 from `docs/workflow/four_bed_work_packages.csv`.

**Core question:** how does the wrapper make toPSAil see a normal paired or single-bed problem?

**Required deliverables:**

1. Case-builder functions for paired direct-transfer selections and single-bed/external selections.
2. A local/global bed mapping carried through every temporary case.
3. A native-step translation layer that prevents raw Yang labels from being passed unexamined into core toPSAil machinery.
4. Boundary/end metadata for direct-pair operations, especially product-end equalization and product-end-to-product-end purge/backfill families.
5. Programmatic tests for `T-CASE-01`, `T-CASE-02`, `T-STATIC-03`, and the WP4 portions of `T-PAIR-01`, `T-PAIR-02`, `T-PAIR-03`, `T-STATE-02`, and `T-STATE-03`.
6. Regression protection showing WP4 wrapper work did not edit core adsorber physics or native two-bed behaviour.
7. A short WP4 documentation page under `docs/four_bed/`.

**Main constraint:** WP4 is an adapter. It may construct temporary local cases, translate labels, inject selected persistent bed states, call existing toPSAil-compatible machinery where the native machinery can actually represent the requested operation, and return terminal local states in WP3 order. WP4 must not modify core adsorber equations, assemble `[A,B,C,D]` into one RHS, create dynamic internal tanks, or pretend unsupported native semantics are supported because optimism is cheaper than debugging.

---

## Required pre-reading before edits

Read these files first, in this order:

```text
AGENTS.md
docs/CODEX_PROJECT_MAP.md
docs/PROJECT_CHARTER.md
docs/MODEL_SCOPE.md
docs/SOURCE_LEDGER.md
docs/source_reference/00_source_reference_index.md
docs/VALIDATION_STRATEGY.md
docs/TEST_POLICY.md
docs/BOUNDARY_CONDITION_POLICY.md
docs/THERMAL_MODEL_POLICY.md
docs/TASK_PROTOCOL.md
docs/KNOWN_UNCERTAINTIES.md
docs/REPORT_POSITIONING.md
docs/GIT_WORKFLOW.md

docs/workflow/four_bed_project_context_file_map.txt
docs/workflow/four_bed_work_packages.csv
docs/workflow/four_bed_architecture_map.csv
docs/workflow/four_bed_issue_register.csv
docs/workflow/four_bed_test_matrix.csv
docs/workflow/four_bed_stage_gates.csv
docs/workflow/four_bed_evidence_notes.csv
docs/workflow/four_bed_yang_manifest.csv

docs/four_bed/WP1_yang_schedule_manifest.md
docs/four_bed/WP2_direct_transfer_pair_map.md
docs/four_bed/WP3_persistent_four_bed_state_container.md
```

Inspect these implementation files before writing new code:

```text
scripts/four_bed/getYangFourBedScheduleManifest.m
scripts/four_bed/getYangDirectTransferPairMap.m
scripts/four_bed/selectYangFourBedPairStates.m
scripts/four_bed/selectYangFourBedSingleState.m
scripts/four_bed/writeBackYangFourBedStates.m
scripts/four_bed/validateYangFourBedStateContainer.m

tests/four_bed/testYangManifestIntegrity.m
tests/four_bed/testYangPairMapCompleteness.m
tests/four_bed/testYangFourBedStateContainerShape.m
tests/four_bed/testYangFourBedWritebackOnlyParticipants.m
tests/four_bed/testYangFourBedCrossedPairRoundTrip.m

3_source/5_cycle/1_simulateCycle/runPsaCycleStep.m
3_source/4_rhs/2_rightHandSideFunctions/defineRhsFunc.m
3_source/7_helper/6_grabber/grabParams4Step.m
3_source/1_parameters/getStringParams.m
3_source/4_rhs/1_volumetricFlowRates/4_pre_computations/getVolFlowFuncHandle.m
3_source/4_rhs/1_volumetricFlowRates/1_adsorber_boundaries/1_linear_valves/calcVolFlowEqualProdEnd.m
3_source/4_rhs/1_volumetricFlowRates/1_adsorber_boundaries/1_linear_valves/calcVolFlowEqualFeedEnd.m
3_source/7_helper/2_converter/convert2TermStates.m
3_source/7_helper/2_converter/convert2ColStates.m
3_source/7_helper/5_maker/makeColumns.m
3_source/7_helper/5_maker/makeCol2Interact.m
```

Do not edit the `3_source/` files while doing this reading. They are listed so you understand the native grammar and state layout, not so you can go spelunking through core physics with a wrench.

---

## Baseline checks before WP4 edits

From the repository root, run the existing lightweight checks:

```matlab
addpath(genpath(pwd));
run("scripts/run_source_tests.m");
run("scripts/run_sanity_tests.m");
```

Expected existing coverage:

```text
T-STATIC-01  Yang manifest integrity
T-PARAM-01   Layered-bed capability audit
T-STATIC-02  Pairing map completeness
T-STATE-01   Persistent state container shape
T-STATE-02   Writeback only participants
T-STATE-03   Crossed-pair round trip
```

Stop and report if these fail. WP4 depends on WP1/WP2/WP3. Building a case adapter on a bad pair map is not “incremental progress”; it is just a more organized wrong answer.

---

## Allowed files to create or edit

Prefer these project-level files:

```text
scripts/four_bed/translateYangNativeOperation.m
scripts/four_bed/makeYangTemporaryCase.m
scripts/four_bed/makeYangTemporaryPairedCase.m
scripts/four_bed/makeYangTemporarySingleCase.m
scripts/four_bed/validateYangTemporaryCase.m
scripts/four_bed/assertNoYangInternalTankInventory.m
scripts/four_bed/injectYangLocalStatesIntoTemplateParams.m
scripts/four_bed/extractYangTerminalLocalStates.m
scripts/four_bed/runYangTemporaryCase.m
scripts/four_bed/makeYangTemporaryCaseRunnerSpy.m
scripts/four_bed/buildYangTemporaryTemplateParams.m        % optional, only if a safe lightweight template is possible

tests/four_bed/testYangNativeTranslationCoverage.m
tests/four_bed/testYangTemporaryTwoBedCaseBuilder.m
tests/four_bed/testYangTemporarySingleBedCaseBuilder.m
tests/four_bed/testYangNoDynamicTankInventoryGuard.m
tests/four_bed/testYangTemporaryCaseRunnerSpy.m
tests/four_bed/testYangDirectPairEndpointMetadata.m
tests/four_bed/testYangEqDirectPairNativeSmoke.m           % optional and not default unless genuinely < 30 s

scripts/run_case_builder_tests.m
scripts/run_sanity_tests.m

docs/four_bed/WP4_temporary_case_builder.md
scripts/README.md
tests/README.md
```

Optional, only if a real ambiguity appears:

```text
docs/KNOWN_UNCERTAINTIES.md
```

Do not edit canonical workflow CSVs:

```text
docs/workflow/*.csv
```

Do not edit source PDFs. If a source conflict blocks the task, stop and report it.

---

## Forbidden changes

Do not edit these toPSAil core folders for WP4:

```text
1_config/
2_run/
3_source/
4_example/
5_reference/
6_publication/
```

Do not add or sneak in:

```text
- dynamic internal tanks for Yang EQI/EQII/PP/PU/AD&PP/BF transfers;
- shared header inventory;
- a global four-bed RHS/DAE;
- new adsorber material, mass, energy, pressure-flow, or momentum equations;
- event-based Yang scheduling;
- physical Yang phase-offset initialization;
- ledger, CSS, purity, recovery, or productivity reconstruction;
- changes to validation numbers;
- a generic four-bed GUI path;
- silent tuning of valve constants to force agreement.
```

WP4 may use native toPSAil external tank fields if a native one-bed or two-bed template requires them structurally. That is not the same thing as a Yang internal transfer tank. The prohibited object is persistent or dynamic inventory mediating an internal Yang transfer. Core templates may still contain inert `feTa`, `raTa`, or `exTa` state segments because toPSAil’s RHS expects them. Do not write those segments back to `state_A/state_B/state_C/state_D`, and do not count them as internal transfer inventory. The distinction is tedious but important, much like most useful engineering details.

---

## Relevant WP4 planning constraints

From `four_bed_work_packages.csv`, WP4 owns:

```text
Temporary two-bed/single-step case builder
Case-builder functions
Local/global bed mapping
Native step translation
Boundary/end setup
Regression protection
```

WP4 non-goals are explicit:

```text
Do not modify core adsorber equations.
Do not assemble [A,B,C,D] into one RHS.
```

From `four_bed_architecture_map.csv`, the wrapper execution sequence is:

1. Read the current Yang manifest group.
2. Select paired and single operations using the explicit pair map.
3. Build a temporary toPSAil-compatible paired/single case.
4. Invoke existing toPSAil machinery.
5. Write terminal states back to participating global beds.

WP4 owns step 3 and the wrapper-facing part of step 4. WP3 owns state storage and writeback. WP5 owns ledgers, CSS, and metrics.

From the issue register, WP4 must mainly defend against:

| Issue | Failure mode | WP4 defence |
|---|---|---|
| `ARCH-01` | Dynamic internal tanks retained | No internal tank/header inventory in temporary direct-transfer cases |
| `ARCH-02` | Wrapper becomes global four-bed RHS | Temporary cases are one or two local beds only |
| `ARCH-03` | Core adsorber physics modified | Project files only; no `3_source/` edits |
| `PAIR-02` | Donor/receiver direction inverted | Use `selection.localMap`; donor is local 1, receiver is local 2 |
| `PAIR-04` | `PP -> PU` endpoint mapping wrong | Preserve product-end donor to product-end receiver, receiver waste at feed end |
| `STATE-01` | Wrong writeback target | Return terminal states in WP3 local order only |
| `STATE-02` | Non-participants overwritten | Temporary case never sees non-participating states |
| `CASE-01` | Temporary cases leak state/params | Deep-copy or reconstruct case structs; validate no stale local state |
| `CASE-02` | Raw Yang label reaches native parser | Translate every label to core grammar or documented wrapper-only status |
| `CASE-03` | Local indices obscure global identity | Carry global bed, local index, source column, Yang label, and pair id in metadata |
| `FLOW-01` | Fixed-duration direct coupling misses pressure endpoints | Store pressure classes; do not invent numeric `P1/P2/P3/P5/P6` |
| `FLOW-02` | Flow reversals not logged | Add flow-sign fields where available; leave numerical audit to optional tests |
| `IO-01` | Excel/GUI paths remain two-bed oriented | Use programmatic cases and tests; do not depend on Excel macros |

The stage-gate target is Stage 3/4: state and case-builder bench, then direct-coupling toy pilot. WP4 should exit with structural case-builder tests passing and a clear path to numerical direct-pair smoke tests.

---

## Critical native toPSAil facts WP4 must respect

### 1. Native step names are not Yang labels

The toPSAil core step grammar uses names such as:

```text
HP-FEE-RAF
HP-FEE-ATM
LP-ATM-RAF
DP-ATM-XXX
DP-XXX-ATM
RP-XXX-RAF
EQ-XXX-APR
EQ-AFE-XXX
RT-XXX-XXX
```

Yang labels are:

```text
AD
AD&PP
EQI-BD
PP
EQII-BD
BD
PU
EQII-PR
EQI-PR
BF
```

A raw Yang label must never be handed to a native parser or RHS setup field as if it were a native step. If the implementation does that, `CASE-02` has failed and the computer is only pretending to cooperate.

### 2. Product-end equalization is natively representable

The native code has `EQ-XXX-APR`, with partner identification through `params.numAdsEqPrEnd`. It is appropriate for Yang `EQI` and `EQII` direct product-end equalizations, provided the case builder explicitly supplies the local partner map and keeps `EQI`/`EQII` stage metadata separate.

For Yang purposes:

```text
EQI-BD  -> EQI-PR   => native product-end paired equalization, stage = EQI
EQII-BD -> EQII-PR  => native product-end paired equalization, stage = EQII
```

Both may use the same native step name `EQ-XXX-APR`, but the wrapper metadata must still distinguish `EQI` and `EQII`. Collapsing the metadata would pass numerically while failing diagnostically, which is exactly the sort of bug that waits until a thesis deadline to become visible.

### 3. Native parser row-order pairing is not acceptable for Yang

`getStringParams.m` identifies native equalization partners by scanning rows of `sStepCol` and pairing equalization rows in encountered order. WP2 exists precisely because Yang pair identities must not be inferred from row order.

Therefore WP4 must not use `getStringParams` as the source of Yang pair identity. If a temporary native `params` struct is used, explicitly set:

```matlab
params.numAdsEqPrEnd = [2; 1];   % for a two-local-bed product-end pair
params.numAdsEqFeEnd = [0; 0];
```

or construct the initialized params from a safe two-bed template and overwrite the pair map before running.

### 4. Single-step equalization has a parser trap

The native `getStringParams.m` attempts to infer equalization flow direction by looking at the next step. A one-step temporary equalization case can therefore be fragile if it is sent through the full string parser.

Preferred WP4 rule:

```text
Do not build native direct-pair params by re-parsing one-step equalization strings.
Build or copy a safe two-bed template, then explicitly overwrite local step fields, flow directions, and pair maps.
```

If that is not possible, stop and document the blocker instead of editing core parser logic.

### 5. `PP -> PU` and `AD&PP -> BF` are not ordinary equalizations

The source semantics are directional:

```text
PP donor:      cocurrent depressurization from product end; gas purges a companion bed.
PU receiver:   countercurrent purge; receiver waste exits feed end.
AD&PP donor:   external adsorption/product continues while part of product-side gas backfills companion bed.
BF receiver:   final pressurization from product-side gas supplied by AD&PP donor.
```

The native grammar does not obviously contain a single built-in step that simultaneously represents all of those endpoint and split semantics without using a product tank/header. WP4 must therefore distinguish:

```text
- native-runnable translations, such as EQI/EQII product-end equalization;
- wrapper-only direct-transfer specifications, such as PP_PU and ADPP_BF, pending a safe adapter;
- external single-bed translations, such as AD and BD.
```

Do not “map” `PP -> PU` to a generic equalization just because both involve product-end gas. That would be conceptually lazy and physically suspect, an unusually bad combination.

---

## The WP4 architecture to implement

### Overview

WP4 should introduce a temporary-case struct with this conceptual shape:

```matlab
tempCase = struct();
tempCase.version = "WP4-Yang2009-temporary-case-v1";
tempCase.caseType = "paired_direct_transfer";       % or "single_bed_operation"
tempCase.selectionVersion = selection.version;
tempCase.selectionType = selection.selectionType;
tempCase.pairId = selection.pairId;
tempCase.directTransferFamily = selection.directTransferFamily;
tempCase.localMap = selection.localMap;
tempCase.localStates = selection.localStates(:);
tempCase.yang = ...;        % source labels, records, pressure classes, endpoints
tempCase.native = ...;      % translated native/wrapper operation spec
tempCase.template = ...;    % optional template params status, not required for dry-run tests
tempCase.execution = ...;   % duration, runner mode, native run status
tempCase.architecture = ...;% guardrail flags
tempCase.validation = ...;  % construction checks and warnings
tempCase.metadata = ...;    % source notes, implementation policy
```

A temporary case must contain only the selected local bed states. It may contain metadata about global bed labels, but it must not contain unselected persistent bed payloads.

### Local order contract

WP3 already defines local order:

```text
Paired direct transfer:
  local index 1 = donor
  local index 2 = receiver

Single-bed operation:
  local index 1 = selected bed
```

WP4 must preserve that order in:

```text
localStates
localMap
native.localOperations
terminalLocalStates
run reports
```

A later call to `writeBackYangFourBedStates(container, selection, terminalLocalStates)` must work without remapping.

### Duration contract

WP1 preserved raw Yang durations and normalized displayed-cycle fractions. WP4 must not infer executable duration from only the donor source column or only the receiver source column.

For executable temporary cases, require the caller to provide either:

```matlab
"DurationSeconds", value
```

or:

```matlab
"DurationDimless", value
```

Store source duration labels from `selection.localMap` for traceability, but do not silently choose one if the donor and receiver source columns differ. If no duration is supplied, the case may be valid structurally but `runYangTemporaryCase(..., "Runner", "native")` must error with a clear message.

---

## Translation table to implement

Create `scripts/four_bed/translateYangNativeOperation.m`.

### Suggested signature

```matlab
function translation = translateYangNativeOperation(selection, varargin)
```

Name-value options:

```matlab
"OperationPolicy"   % default "fixed_duration_direct_coupling"
"ExternalProductSink" % default "RAF" for AD
"ExternalWasteSink"   % default "ATM" for BD/PU waste metadata
```

### Required return fields

```matlab
translation.version
translation.selectionType
translation.directTransferFamily
translation.nativeRunnable          % true/false
translation.nativeRunnableScope     % "core_step", "wrapper_adapter", "not_runnable_yet"
translation.nativeStepNames         % string array, one per local bed, or "not_applicable"
translation.wrapperOperation        % wrapper operation family
translation.localOperations         % table, one row per local bed
translation.endpointPolicy
translation.pressureClassPolicy
translation.accountingPolicy
translation.warnings
translation.unsupportedReason
```

### Paired direct-transfer translations

Use this table:

| Yang pair family | Yang donor | Yang receiver | Local roles | Native/core status | Required endpoint metadata |
|---|---|---|---|---|---|
| `EQI` | `EQI-BD` | `EQI-PR` | donor -> receiver | `nativeRunnable = true`, `nativeStepNames = ["EQ-XXX-APR"; "EQ-XXX-APR"]` | donor outlet `product_end`; receiver inlet `product_end`; no receiver waste |
| `EQII` | `EQII-BD` | `EQII-PR` | donor -> receiver | `nativeRunnable = true`, `nativeStepNames = ["EQ-XXX-APR"; "EQ-XXX-APR"]` | donor outlet `product_end`; receiver inlet `product_end`; no receiver waste |
| `PP_PU` | `PP` | `PU` | donor -> receiver_with_external_waste | `nativeRunnable = false` unless a safe wrapper adapter is implemented | donor outlet `product_end`; receiver inlet `product_end`; receiver waste `feed_end` |
| `ADPP_BF` | `AD&PP` | `BF` | compound_donor -> receiver | `nativeRunnable = false` unless a safe split/backfill adapter is implemented | donor product-side gas; receiver inlet `product_end`; external product kept separate |

For `PP_PU` and `ADPP_BF`, return a complete wrapper specification, but do not pass a fake native step name into core toPSAil. Use:

```matlab
nativeStepNames = ["not_applicable"; "not_applicable"];
nativeRunnable = false;
nativeRunnableScope = "wrapper_adapter_required";
unsupportedReason = "Native core grammar lacks this exact direct-transfer endpoint/split combination without a custom wrapper adapter.";
```

This is not giving up. It is refusing to encode wrong physics as a convenience feature, which humans keep forgetting is not the same thing.

### Single-bed translations

Use this table for `selection.selectionType == "single_bed_operation"`:

| Yang label | Role | Native/core status | Suggested native step | Notes |
|---|---|---|---|---|
| `AD` | external_single | runnable if template params supplied | `HP-FEE-RAF` | external feed from feed tank, external product to raffinate tank |
| `BD` | external_waste_single | runnable if template params supplied | `DP-ATM-XXX` | countercurrent depressurization from feed end to waste/atmosphere |
| `AD&PP` | compound_donor | not a pure single-bed op | `not_applicable` | belongs to `ADPP_BF`; external product and internal BF split must be separated later |
| `PP` | donor | paired direct transfer | `not_applicable` | belongs to `PP_PU` |
| `PU` | receiver_with_external_waste | paired direct transfer | `not_applicable` | belongs to `PP_PU` |
| `EQI-BD` | donor | paired direct transfer | `not_applicable` as single | belongs to `EQI` |
| `EQI-PR` | receiver | paired direct transfer | `not_applicable` as single | belongs to `EQI` |
| `EQII-BD` | donor | paired direct transfer | `not_applicable` as single | belongs to `EQII` |
| `EQII-PR` | receiver | paired direct transfer | `not_applicable` as single | belongs to `EQII` |
| `BF` | receiver | paired direct transfer | `not_applicable` as single | belongs to `ADPP_BF` |

The translation coverage test must exercise every label in `manifest.labelGlossary`.

---

## Temporary case builders

### Function: `makeYangTemporaryCase.m`

Purpose: dispatch to paired or single builder.

Suggested signature:

```matlab
function tempCase = makeYangTemporaryCase(selection, varargin)
```

Options:

```matlab
"TemplateParams"      % initialized toPSAil params struct or []
"DurationSeconds"     % optional numeric scalar
"DurationDimless"     % optional numeric scalar
"RunnerMode"          % "dry_run", "spy", "native"; default "dry_run"
"CaseNote"            % string scalar
```

Dispatch rule:

```matlab
switch string(selection.selectionType)
    case "paired_direct_transfer"
        tempCase = makeYangTemporaryPairedCase(selection, varargin{:});
    case "single_bed_operation"
        tempCase = makeYangTemporarySingleCase(selection, varargin{:});
    otherwise
        error('WP4:UnknownSelectionType', ...)
end
```

### Function: `makeYangTemporaryPairedCase.m`

Purpose: build a two-local-bed temporary case from `selectYangFourBedPairStates` output.

Required checks:

```text
- selection is a struct returned by WP3;
- selection.selectionType == "paired_direct_transfer";
- height(selection.localMap) == 2;
- selection.localStates has exactly 2 cells;
- local index 1 role is donor;
- local index 2 role is receiver;
- global beds are distinct;
- directTransferFamily is one of ADPP_BF, EQI, EQII, PP_PU;
- endpoint metadata exists and agrees with pair map;
- no unselected global state is present.
```

Required construction:

```matlab
tempCase.caseType = "paired_direct_transfer";
tempCase.nLocalBeds = 2;
tempCase.localStates = selection.localStates(:);
tempCase.localMap = selection.localMap;
tempCase.yang.sourceLabels = selection.localMap.yang_label;
tempCase.yang.sourceCols = selection.localMap.source_col;
tempCase.yang.recordIds = selection.localMap.record_id;
tempCase.yang.pressureClasses = selection.localMap(:, ["p_start_class", "p_end_class"]);
tempCase.native = translateYangNativeOperation(selection, ...);
tempCase.architecture.noDynamicInternalTanks = true;
tempCase.architecture.noSharedHeaderInventory = true;
tempCase.architecture.noFourBedRhsDae = true;
tempCase.architecture.noCoreAdsorberPhysicsRewrite = true;
tempCase.architecture.caseBuilderOnlySeesSelectedBeds = true;
```

For `EQI` and `EQII`, include native equalization fields:

```matlab
tempCase.native.nCols = 2;
tempCase.native.sStepCol = {"EQ-XXX-APR"; "EQ-XXX-APR"};
tempCase.native.typeDaeModel = [1; 1];          % varying pressure
tempCase.native.numAdsEqPrEnd = [2; 1];
tempCase.native.numAdsEqFeEnd = [0; 0];
tempCase.native.localPartnerIndex = [2; 1];
tempCase.native.equalizationEnd = "product_end";
tempCase.native.stageLabel = string(selection.directTransferFamily); % EQI or EQII
```

Do not infer `numAdsEqPrEnd` by row order. Set it from the two-bed local case itself.

For `PP_PU`, include wrapper endpoint fields:

```matlab
tempCase.native.nCols = 2;
tempCase.native.nativeRunnable = false;
tempCase.native.wrapperOperation = "direct_provide_purge";
tempCase.native.donorOutletEndpoint = "product_end";
tempCase.native.receiverInletEndpoint = "product_end";
tempCase.native.receiverWasteEndpoint = "feed_end";
```

For `ADPP_BF`, include wrapper split fields:

```matlab
tempCase.native.nCols = 2;
tempCase.native.nativeRunnable = false;
tempCase.native.wrapperOperation = "compound_adsorption_and_backfill";
tempCase.native.donorExternalOperation = "adsorption_product";
tempCase.native.receiverInternalOperation = "backfill";
tempCase.native.externalProductMustRemainSeparate = true;
```

### Function: `makeYangTemporarySingleCase.m`

Purpose: build a one-local-bed temporary case from `selectYangFourBedSingleState` output.

Required checks:

```text
- selection.selectionType == "single_bed_operation";
- height(selection.localMap) == 1;
- selection.localStates has exactly 1 cell;
- local index is 1;
- global bed is one of A/B/C/D;
- native translation exists.
```

For `AD`, include native fields:

```matlab
tempCase.native.nCols = 1;
tempCase.native.sStepCol = {"HP-FEE-RAF"};
tempCase.native.typeDaeModel = 0;      % constant-pressure native step
tempCase.native.externalFeed = true;
tempCase.native.externalProduct = true;
tempCase.native.externalWaste = false;
```

For `BD`, include native fields:

```matlab
tempCase.native.nCols = 1;
tempCase.native.sStepCol = {"DP-ATM-XXX"};
tempCase.native.typeDaeModel = 1;      % varying-pressure native step
tempCase.native.externalFeed = false;
tempCase.native.externalProduct = false;
tempCase.native.externalWaste = true;
```

For labels that are not pure single-bed operations, the builder may still construct a diagnostic case only if requested, but it must mark it not runnable:

```matlab
tempCase.native.nativeRunnable = false;
tempCase.native.unsupportedReason = "This Yang label belongs to a paired direct-transfer family.";
```

Default behaviour should error for paired labels passed to the single-bed builder unless `"AllowDiagnosticOnly", true` is supplied. Otherwise someone will eventually simulate `BF` as a single-bed step and call the output “close enough”. It will not be.

---

## Template params, state injection, and terminal extraction

WP4 should separate structural case building from numerical running. The structural builders must work with sentinel payloads and no initialized `params`. Native running requires a valid toPSAil template.

### Payload policy

WP3 treats state payloads as opaque. WP4 may inspect them only when it is about to inject them into native toPSAil params.

Support at least these payload forms:

1. **Dry-run/sentinel payloads:** any MATLAB value, stored and returned without interpretation.
2. **Native adsorber-state payloads:** either a numeric row vector of length `params.nColStT`, or a struct with:

```matlab
payload.payloadType = "toPSAil_adsorber_state_v1";
payload.stateVector = <1 x params.nColStT numeric row vector>;
payload.metadata = <optional struct>;
```

Do not require WP3 to create this payload schema. WP4 can accept it when native execution is requested.

### Function: `injectYangLocalStatesIntoTemplateParams.m`

Suggested signature:

```matlab
function [params, injectionReport] = injectYangLocalStatesIntoTemplateParams(templateParams, tempCase)
```

Required behaviour:

```text
- validate tempCase.nLocalBeds equals templateParams.nCols;
- deep-copy templateParams into params;
- set params.nCycles = 1 and params.nSteps = 1 for a single temporary call unless caller explicitly supplies another safe mode;
- inject each local adsorber state vector into the corresponding local column state segment;
- reset cumulative column boundary-flow states to zero;
- leave auxiliary tank states as template placeholders unless the native step explicitly uses external feed/product/waste;
- set native step fields from tempCase.native, not from Yang labels;
- set explicit equalization partner arrays for EQI/EQII;
- do not add non-participating beds.
```

Column state segment injection:

```matlab
nColStT = params.nColStT;
for i = 1:tempCase.nLocalBeds
    colState = extractLocalAdsorberVector(tempCase.localStates{i}, params);
    idx = (i-1)*nColStT + (1:nColStT);
    params.initStates(idx) = colState;
end
```

Reset cumulative boundary states inside each local column:

```matlab
nComs = params.nComs;
for i = 1:tempCase.nLocalBeds
    idx0 = i*params.nColStT - 2*nComs + 1;
    idxf = i*params.nColStT;
    params.initStates(idx0:idxf) = 0;
end
```

If `templateParams.nCols` does not match the local case size, do not silently resize it. Recomputing `nStatesT`, `inShFeTa`, `inShRaTa`, and other index fields by hand is a fine way to generate a bug farm. Either use a correct one-bed/two-bed template or implement a dedicated `buildYangTemporaryTemplateParams` with tests.

### Function: `extractYangTerminalLocalStates.m`

Suggested signature:

```matlab
function [terminalLocalStates, extractionReport] = extractYangTerminalLocalStates(tempCase, params, stStates)
```

Required behaviour:

```text
- call convert2TermStates(params, stStates) to reset cumulative flow/work states;
- slice each local column state vector in local index order;
- preserve metadata linking local index to global bed;
- return a cell array suitable for writeBackYangFourBedStates;
- do not return auxiliary tank states as bed states.
```

Recommended payload return form:

```matlab
terminalLocalStates{i} = struct( ...
    "payloadType", "toPSAil_adsorber_state_v1", ...
    "stateVector", termState(idx), ...
    "metadata", struct( ...
        "source", "WP4 temporary case", ...
        "globalBed", string(tempCase.localMap.global_bed(i)), ...
        "localIndex", tempCase.localMap.local_index(i), ...
        "yangLabel", string(tempCase.localMap.yang_label(i)), ...
        "pairId", string(tempCase.pairId), ...
        "directTransferFamily", string(tempCase.directTransferFamily) ...
    ) ...
);
```

For dry-run tests with sentinel payloads, return transformed sentinel states only through `runYangTemporaryCase(..., "Runner", "spy")`, not through the native extraction helper.

---

## Running temporary cases

### Function: `runYangTemporaryCase.m`

Suggested signature:

```matlab
function [terminalLocalStates, runReport] = runYangTemporaryCase(tempCase, varargin)
```

Name-value options:

```matlab
"Runner"          % "dry_run", "spy", "native"; default "dry_run"
"RunnerFunction"  % function handle for spy tests
"TemplateParams"  % optional override
"DurationSeconds" % optional override
"DurationDimless" % optional override
```

### Runner modes

#### `dry_run`

Does not invoke solver. Returns original local states unchanged and reports `didInvokeNative = false`.

Use this only for structural tests. Do not claim numerical pass from dry-run results, because words still mean things.

#### `spy`

Calls a supplied runner function once:

```matlab
[terminalLocalStates, spyReport] = runnerFunction(tempCase);
```

Use this to verify that the WP4 adapter invokes the runner exactly once and preserves local order. This is useful for `T-CASE-01`, `T-CASE-02`, and state writeback interaction tests without requiring a numerically valid PSA template.

#### `native`

Requires:

```text
- tempCase.native.nativeRunnable == true;
- initialized TemplateParams supplied;
- native adsorber-state payloads supplied;
- duration supplied;
- no unsupported wrapper operation;
- local bed count matches template params.
```

Then:

1. Inject selected local states into params.
2. Set the one-step native operation fields.
3. Use `runPsaCycleStep(params, params.initStates, tDom, 1, 1)` or a similarly narrow existing call.
4. Extract terminal local adsorber states.
5. Return terminal local states in WP3 local order.

Native execution should be attempted first for `EQI`, `EQII`, `AD`, and `BD` only, and only when a known-safe template exists. `PP_PU` and `ADPP_BF` should remain wrapper-only/not-runnable unless the implementation adds a safe adapter without core physics edits and tests it thoroughly.

---

## Validation helpers

### Function: `validateYangTemporaryCase.m`

Suggested signature:

```matlab
function result = validateYangTemporaryCase(tempCase, varargin)
```

Checks should return a struct like WP1/WP2/WP3 validators:

```matlab
result.pass
result.failures
result.warnings
result.checks
```

Required checks:

```text
- tempCase is a struct;
- version is nonempty;
- caseType is paired_direct_transfer or single_bed_operation;
- nLocalBeds is 1 or 2;
- localMap is a table with required WP3 columns;
- localStates count equals nLocalBeds;
- localMap.local_index is 1:nLocalBeds;
- global beds are known A/B/C/D;
- paired cases have distinct donor/receiver beds;
- paired donor is local 1 and receiver is local 2;
- native translation exists;
- raw Yang labels do not appear in fields intended for core native step names;
- unsupported translations are explicitly marked not runnable and have a reason;
- architecture flags are present and true;
- no dynamic internal tank/header inventory fields exist;
- no four-bed RHS/DAE fields exist;
- no unselected persistent state fields appear in tempCase.
```

### Function: `assertNoYangInternalTankInventory.m`

Purpose: guard `T-STATIC-03`.

It should scan a temporary case for forbidden internal inventory fields/tokens such as:

```text
tank_state
internal_tank
dynamic_tank
header_inventory
shared_header
shared_header_inventory
four_bed_rhs
four_bed_dae
state_A
state_B
state_C
state_D
```

Be precise: the temporary case may contain strings like `externalProductSink = "RAF"` or `nativeUsesExternalFeedTank = true` for native external operations. That is not a Yang internal transfer tank. The guard should fail on persistent/internal transfer inventory fields, not on every occurrence of the word `tank` in a source note. Computers are bad at context; write the test like you know that.

---

## Tests to add

### 1. `testYangNativeTranslationCoverage.m`

**Maps to:** `T-CASE-01`, `T-CASE-02`, `CASE-02`, `SCHED-03`, `PAIR-04`.

**Purpose:** every Yang label/family must have an explicit translation status.

Test outline:

```matlab
function testYangNativeTranslationCoverage()
    manifest = getYangFourBedScheduleManifest();
    pairMap = getYangDirectTransferPairMap(manifest);
    container = buildSentinelContainer(manifest, pairMap);

    labels = manifest.labelGlossary.yang_label;
    for i = 1:numel(labels)
        row = manifest.bedSteps(manifest.bedSteps.yang_label == labels(i), :);
        row = row(1, :);
        selection = selectYangFourBedSingleState(container, row);
        translation = translateYangNativeOperation(selection, 'AllowDiagnosticOnly', true);
        assert(isfield(translation, 'nativeRunnable'));
        assert(isfield(translation, 'nativeStepNames'));
        assert(isfield(translation, 'unsupportedReason'));
    end

    pairs = pairMap.transferPairs;
    for i = 1:height(pairs)
        selection = selectYangFourBedPairStates(container, pairs(i,:));
        translation = translateYangNativeOperation(selection);
        assert(isfield(translation, 'directTransferFamily'));
        assert(translation.directTransferFamily == pairs.direct_transfer_family(i));
    end

    fprintf('T-CASE translation coverage passed.\n');
end
```

Specific assertions:

```text
- AD maps to HP-FEE-RAF;
- BD maps to DP-ATM-XXX;
- EQI maps to EQ-XXX-APR with stage EQI;
- EQII maps to EQ-XXX-APR with stage EQII;
- PP_PU has product_end -> product_end and receiver waste feed_end;
- ADPP_BF is compound and not collapsed to AD or PP.
```

### 2. `testYangTemporaryTwoBedCaseBuilder.m`

**Maps to:** `T-CASE-01`, `CASE-01`, `CASE-02`, `STATE-03`.

Use a crossed EQI pair, such as `B -> D`, because adjacency-based assumptions deserve no mercy.

Test outline:

```matlab
function testYangTemporaryTwoBedCaseBuilder()
    [manifest, pairMap, container] = buildWp4SentinelContext();
    pair = pairMap.transferPairs( ...
        pairMap.transferPairs.direct_transfer_family == "EQI" & ...
        pairMap.transferPairs.donor_bed == "B" & ...
        pairMap.transferPairs.receiver_bed == "D", :);

    selection = selectYangFourBedPairStates(container, pair);
    tempCase = makeYangTemporaryPairedCase(selection, ...
        'DurationSeconds', 1, ...
        'RunnerMode', "dry_run", ...
        'CaseNote', "T-CASE-01 crossed EQI pair");

    result = validateYangTemporaryCase(tempCase);
    assert(result.pass);
    assert(tempCase.caseType == "paired_direct_transfer");
    assert(tempCase.nLocalBeds == 2);
    assert(isequal(tempCase.localMap.global_bed, ["B"; "D"]));
    assert(isequal(tempCase.localMap.local_index, [1; 2]));
    assert(tempCase.localMap.local_role(1) == "donor");
    assert(tempCase.localMap.local_role(2) == "receiver");
    assert(all(tempCase.native.nativeStepNames == "EQ-XXX-APR"));
    assert(isequal(tempCase.native.numAdsEqPrEnd, [2; 1]));
    assert(tempCase.native.stageLabel == "EQI");
    assert(tempCase.architecture.noDynamicInternalTanks);
    assert(tempCase.architecture.noFourBedRhsDae);

    fprintf('T-CASE-01 passed: temporary two-bed case builder preserves crossed pair identity.\n');
end
```

Add a back-to-back isolation check:

```matlab
case1 = makeYangTemporaryPairedCase(selectionBD, ...);
case2 = makeYangTemporaryPairedCase(selectionCA, ...);
assert(~isequal(case1.localStates, case2.localStates));
assert(case1.pairId ~= case2.pairId);
```

This catches stale state leakage. Software often remembers things it should not. So do people, but at least software can be tested.

### 3. `testYangTemporarySingleBedCaseBuilder.m`

**Maps to:** `T-CASE-02`, `CASE-01`, `CASE-03`.

Use one `AD` row and one `BD` row.

Assertions for `AD`:

```text
- nLocalBeds == 1;
- native step is HP-FEE-RAF;
- externalFeed == true;
- externalProduct == true;
- no fake companion bed;
- global bed metadata preserved.
```

Assertions for `BD`:

```text
- nLocalBeds == 1;
- native step is DP-ATM-XXX;
- externalWaste == true;
- no fake companion bed;
- global bed metadata preserved.
```

### 4. `testYangNoDynamicTankInventoryGuard.m`

**Maps to:** `T-STATIC-03`, `ARCH-01`.

Build cases for:

```text
EQI
EQII
PP_PU
ADPP_BF
AD
BD
```

Run:

```matlab
result = assertNoYangInternalTankInventory(tempCase);
assert(result.pass);
```

Also assert:

```matlab
assert(tempCase.architecture.noDynamicInternalTanks);
assert(tempCase.architecture.noSharedHeaderInventory);
assert(tempCase.architecture.noFourBedRhsDae);
```

### 5. `testYangDirectPairEndpointMetadata.m`

**Maps to:** `T-PAIR-01`, `T-PAIR-02`, `T-PAIR-03`, `PAIR-02`, `PAIR-04`.

Test EQI:

```text
- donor local 1 outlet product_end;
- receiver local 2 inlet product_end;
- native stage EQI;
- native equalization partner [2; 1].
```

Test EQII:

```text
- same product-end native equalization;
- native stage EQII, not EQI.
```

Test PP_PU:

```text
- donor outlet product_end;
- receiver inlet product_end;
- receiver waste feed_end;
- nativeRunnable == false unless a safe adapter was actually implemented;
- unsupportedReason is nonempty.
```

Test ADPP_BF:

```text
- compound donor preserved;
- receiver backfill preserved;
- external product separation flag is true;
- nativeRunnable == false unless a safe adapter was actually implemented.
```

### 6. `testYangTemporaryCaseRunnerSpy.m`

**Maps to:** `T-CASE-01`, `T-CASE-02`, `STATE-01`, `STATE-02`, `STATE-03`.

Purpose: prove `runYangTemporaryCase` invokes a runner exactly once and returns terminal local states in the same local order.

Use a spy function like:

```matlab
function [terminalLocalStates, report] = spyRunner(tempCase)
    terminalLocalStates = cell(tempCase.nLocalBeds, 1);
    for i = 1:tempCase.nLocalBeds
        terminalLocalStates{i} = struct( ...
            "terminalMarker", "terminal_local_" + string(i), ...
            "globalBed", string(tempCase.localMap.global_bed(i)), ...
            "localIndex", tempCase.localMap.local_index(i));
    end
    report = struct("callCount", 1, "didInvokeNative", false);
end
```

Then write back using WP3:

```matlab
[terminalLocalStates, runReport] = runYangTemporaryCase(tempCase, ...
    'Runner', "spy", ...
    'RunnerFunction', @spyRunner);
[updated, wbReport] = writeBackYangFourBedStates(container, selection, terminalLocalStates);
```

Assert only selected beds changed.

### 7. Optional: `testYangEqDirectPairNativeSmoke.m`

**Maps to:** `T-PAIR-01`, `T-PAIR-02`, maybe `T-NUM-02` if flow signs are inspected.

This test is optional unless a lightweight, reliable native params template exists. Do not include it in default smoke if it takes minutes, requires Excel/GUI macros, or requires physical parameter tuning.

Minimum acceptable native smoke:

```text
- use a known-safe two-local-bed template params struct;
- inject two numeric adsorber-state payloads;
- run a short EQI or EQII product-end equalization;
- assert no MATLAB exception;
- assert finite terminal states;
- assert terminalLocalStates has two entries in local order;
- assert no non-participant states exist;
- log pressure direction if pressure extraction is available.
```

If this cannot be implemented without editing `3_source/`, leave it out and document the blocker in `docs/four_bed/WP4_temporary_case_builder.md`.

---

## Test runner updates

Add a new runner:

```text
scripts/run_case_builder_tests.m
```

Suggested contents:

```matlab
%RUN_CASE_BUILDER_TESTS Run WP4 temporary-case builder tests.
%
% Default smoke inclusion: yes for structural WP4 tests only. Do not include
% long numerical sensitivity, optimization, event-policy, or Yang pilot runs.

fprintf('Running WP4 case-builder tests...\n');

testYangNativeTranslationCoverage();
testYangTemporaryTwoBedCaseBuilder();
testYangTemporarySingleBedCaseBuilder();
testYangNoDynamicTankInventoryGuard();
testYangDirectPairEndpointMetadata();
testYangTemporaryCaseRunnerSpy();

fprintf('All WP4 case-builder tests passed.\n');
```

Update `scripts/run_sanity_tests.m` to call it after WP3 state tests:

```matlab
run("scripts/run_case_builder_tests.m");
```

Do not add optional numerical smoke, `T-NUM-01`, `T-NUM-02`, full Yang skeleton, sensitivity, or events to default sanity. Humanity’s urge to hide slow tests inside “quick” runners is how trust dies in small increments.

---

## Documentation to add

Create:

```text
docs/four_bed/WP4_temporary_case_builder.md
```

It should document:

1. WP4 purpose and scope.
2. The temporary case schema.
3. The local/global mapping rule.
4. The Yang-to-native translation table.
5. Which operations are currently native-runnable and which are wrapper-only/not-runnable.
6. The no-dynamic-internal-tank rule.
7. How terminal local states are returned to WP3.
8. Test mapping and commands.
9. Unresolved blockers, especially if no lightweight native params template exists.
10. A warning that Yang validation is not claimed by WP4.

Use language like:

```text
WP4 proves that selected named Yang bed states can be wrapped into isolated local single-bed or paired-bed case specifications. It does not prove Yang performance, CSS convergence, ledger correctness, or physical fidelity to layered activated-carbon/zeolite beds.
```

---

## Implementation sequence

Follow this order. Skipping steps will make debugging worse and provide the illusion of speed, the most dangerous kind of speed.

### Step 1: Add translation function and tests

Implement `translateYangNativeOperation.m` and `testYangNativeTranslationCoverage.m`.

Run:

```matlab
addpath(genpath(pwd));
testYangNativeTranslationCoverage();
```

Stop if any Yang label has no explicit status.

### Step 2: Add structural temporary case builders

Implement:

```text
makeYangTemporaryCase.m
makeYangTemporaryPairedCase.m
makeYangTemporarySingleCase.m
validateYangTemporaryCase.m
assertNoYangInternalTankInventory.m
```

Run:

```matlab
testYangTemporaryTwoBedCaseBuilder();
testYangTemporarySingleBedCaseBuilder();
testYangNoDynamicTankInventoryGuard();
testYangDirectPairEndpointMetadata();
```

At this point no solver invocation is required.

### Step 3: Add runner abstraction with dry-run and spy modes

Implement `runYangTemporaryCase.m` with `dry_run` and `spy` first.

Run:

```matlab
testYangTemporaryCaseRunnerSpy();
```

Confirm terminal states remain in local order and WP3 writeback updates only participating beds.

### Step 4: Add native injection/extraction helpers

Implement:

```text
injectYangLocalStatesIntoTemplateParams.m
extractYangTerminalLocalStates.m
```

Do not include these in default smoke until a safe native template exists.

Unit-test with a small fake params struct only if possible without lying about physics. At minimum, validate vector lengths and indexing.

### Step 5: Native smoke for EQI/EQII only, if safe

Try only if an initialized two-bed template params struct is available programmatically.

Do not depend on Excel/GUI macros.

Do not edit `3_source/`.

Do not run a full Yang cycle.

If blocked, document:

```text
Native EQI/EQII smoke deferred because no safe programmatic two-bed template params builder exists without editing core/input code.
```

That is an acceptable WP4 outcome if structural adapters and runner contracts are correct.

### Step 6: Update docs and runners

Create the WP4 doc page and `scripts/run_case_builder_tests.m`. Update `run_sanity_tests.m` only after the WP4 structural tests pass individually.

Final check:

```matlab
addpath(genpath(pwd));
run("scripts/run_source_tests.m");
run("scripts/run_sanity_tests.m");
```

---

## Suggested helper patterns

### Common sentinel context for tests

Use a local helper in each test file or a shared test helper if project style permits:

```matlab
function [manifest, pairMap, container] = buildWp4SentinelContext()
    manifest = getYangFourBedScheduleManifest();
    pairMap = getYangDirectTransferPairMap(manifest);

    initialStates = struct();
    initialStates.state_A = struct("bed", "A", "payload", 101, "marker", "sentinel_A");
    initialStates.state_B = struct("bed", "B", "payload", 202, "marker", "sentinel_B");
    initialStates.state_C = struct("bed", "C", "payload", 303, "marker", "sentinel_C");
    initialStates.state_D = struct("bed", "D", "payload", 404, "marker", "sentinel_D");

    container = makeYangFourBedStateContainer(initialStates, ...
        'Manifest', manifest, ...
        'PairMap', pairMap, ...
        'InitializationPolicy', "unit_test_distinguishable_sentinel_states", ...
        'SourceNote', "WP4 temporary-case builder sentinel states");
end
```

### Paired pair selection helper

```matlab
function selection = selectPair(container, pairMap, family, donor, receiver)
    pair = pairMap.transferPairs( ...
        pairMap.transferPairs.direct_transfer_family == string(family) & ...
        pairMap.transferPairs.donor_bed == string(donor) & ...
        pairMap.transferPairs.receiver_bed == string(receiver), :);
    assert(height(pair) == 1);
    selection = selectYangFourBedPairStates(container, pair);
end
```

### Single bed selection helper

```matlab
function selection = selectSingle(container, manifest, bed, yangLabel)
    row = manifest.bedSteps( ...
        manifest.bedSteps.bed == string(bed) & ...
        manifest.bedSteps.yang_label == string(yangLabel), :);
    assert(height(row) >= 1);
    selection = selectYangFourBedSingleState(container, row(1,:));
end
```

---

## Acceptance criteria

WP4 is acceptable when:

```text
- source/static tests still pass;
- WP3 state tests still pass;
- translation coverage test passes;
- temporary paired case builder test passes;
- temporary single case builder test passes;
- no-dynamic-internal-tank guard passes;
- endpoint metadata test passes;
- runner spy/writeback interaction test passes;
- optional native smoke is either passing or explicitly deferred with a documented blocker;
- no core toPSAil files changed;
- no workflow CSVs changed;
- WP4 doc page exists;
- run_sanity_tests includes only lightweight default WP4 tests;
- report states exactly which operations are native-runnable and which are wrapper-only pending adapter work.
```

A good WP4 implementation should make WP5 easier by preserving metadata, but it must not implement WP5. No ledgers. No CSS. No Yang recovery claims. Leave some mess for the next work package, as civilization apparently requires division of labour.

---

## Required final task report format for the Codex agent

End the implementation with this report:

```text
Task objective:

Files inspected:

Files changed:

Commands run:

Tests passed:

Tests failed:

Native operations currently runnable:

Operations marked wrapper-only/not-runnable:

Unresolved uncertainties or blockers:

Core toPSAil files changed? yes/no

Workflow CSVs changed? yes/no

Validation numbers changed? yes/no

Next smallest recommended task:
```

If MATLAB cannot run, say so plainly and provide the exact command attempted. Do not write “tests pass” unless they actually ran. The universe already contains enough unearned confidence.
