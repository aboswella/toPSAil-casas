# WP5 Implementation Guide: Ledger, CSS, and Reporting Layer

## Task card

**Task ID:** `WP5-YANG-LEDGER-CSS-REPORTING`

**Goal:** implement the wrapper-level accounting, cyclic-steady-state, and reporting layer for the Yang four-bed toPSAil workflow, while preserving the WP1-WP4 architecture: four persistent named bed states, explicit direct-transfer pair maps, temporary one-bed or two-bed local cases, no dynamic internal tanks, no shared header inventory, no global four-bed RHS/DAE, and no core adsorber-physics rewrite.

**Work-package scope:** WP5 from `docs/workflow/four_bed_work_packages.csv`.

**Core question:** how are external metrics and CSS reconstructed across the whole four-bed cycle?

**Required deliverables:**

1. A component-resolved external/internal ledger for Yang wrapper operations.
2. Clear separation of external feed, external product, external waste, internal direct transfers, and bed inventory changes.
3. Yang-basis product purity and recovery calculations reconstructed from the external ledger basis.
4. All-bed CSS residual calculations across `state_A`, `state_B`, `state_C`, and `state_D`.
5. Run-output metadata stating the wrapper assumptions, manifest/pair-map versions, event policy, metric basis, and physical-model caveats.
6. Tests mapped to `T-CONS-01`, `T-CONS-02`, `T-CSS-01`, `T-MET-01`, and `T-DOC-01`; also cover the ledger portions of `T-PAIR-02` and `T-PAIR-04`.
7. A short WP5 documentation page under `docs/four_bed/`.

**Main constraint:** WP5 is an accounting and reporting layer. It must not repair missing numerical physics by silently adding tanks, headers, event policies, native step names, guessed pressures, or new adsorber equations. Internal direct-transfer gas is not external product. Native two-bed toPSAil metrics are useful diagnostics only; they are not automatically the Yang external-product basis.

---

## Current repo status and WP4 handoff caveat

The repo supplied as `WP4 complete.zip` contains WP1-WP4 wrapper infrastructure. WP4 appears structurally consistent with the CSV architecture: it provides manifest, pair map, persistent state selection/writeback, temporary case builders, native-translation metadata, and dry-run/spy/native runner modes.

However, WP4 should be treated as **structurally complete, not numerically commissioned**. The implemented smoke suite covers structural case-builder tests, but the full WP4 handoff list in `four_bed_work_packages.csv` also includes numerical sensitivity, flow-reversal audit, and regression protection items that are not fully present as runnable numerical tests. WP5 must not pretend these have passed.

Important WP4 limitations to preserve:

- `EQI` and `EQII` are marked native-runnable through generic product-end equalization metadata when a safe initialized template is supplied.
- `AD` and `BD` are marked native-runnable when a safe initialized template is supplied.
- `PP -> PU` remains wrapper-only/not native-runnable.
- `AD&PP -> BF` remains wrapper-only/not native-runnable.
- The default WP4 tests use structural and spy paths, not a full Yang numerical pilot.

This means the first WP5 implementation should be ledger-first and test-first. Use deterministic synthetic or spy stream packets for ledger/CSS tests before attempting any full native Yang run.

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
docs/four_bed/WP4_temporary_case_builder.md
```

Inspect these implementation files before writing new code:

```text
scripts/four_bed/getYangFourBedScheduleManifest.m
scripts/four_bed/getYangLabelGlossary.m
scripts/four_bed/getYangPressureClassMap.m
scripts/four_bed/getYangDirectTransferPairMap.m
scripts/four_bed/selectYangFourBedPairStates.m
scripts/four_bed/selectYangFourBedSingleState.m
scripts/four_bed/makeYangFourBedStateContainer.m
scripts/four_bed/writeBackYangFourBedStates.m
scripts/four_bed/makeYangTemporaryCase.m
scripts/four_bed/makeYangTemporaryPairedCase.m
scripts/four_bed/makeYangTemporarySingleCase.m
scripts/four_bed/translateYangNativeOperation.m
scripts/four_bed/validateYangTemporaryCase.m
scripts/four_bed/runYangTemporaryCase.m
scripts/four_bed/makeYangTemporaryCaseRunnerSpy.m
scripts/four_bed/injectYangLocalStatesIntoTemplateParams.m
scripts/four_bed/extractYangTerminalLocalStates.m
```

For native state layout and cumulative-flow meaning, inspect but do not edit:

```text
3_source/1_parameters/getStatesParams.m
3_source/7_helper/2_converter/convert2ColStates.m
3_source/7_helper/2_converter/convert2ColGasConc.m
3_source/7_helper/2_converter/convert2ColAdsConc.m
3_source/7_helper/2_converter/convert2TermStates.m
3_source/4_rhs/2_rightHandSideFunctions/getColCuMolBal.m
3_source/5_cycle/3_performanceMetrics/getPerformanceMetrics.m
3_source/5_cycle/3_performanceMetrics/getFeedMolCycle.m
3_source/5_cycle/3_performanceMetrics/getRaffMoleCycle.m
3_source/5_cycle/3_performanceMetrics/getExtrMoleCycle.m
```

Do not edit `3_source/` for WP5. Those files are listed so the ledger layer can interpret native output cautiously.

---

## Baseline checks before WP5 edits

From the repository root, run:

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
T-CASE-01    Temporary two-bed case builder
T-CASE-02    Temporary single-bed case builder
T-STATIC-03  No dynamic-tank inventory guard
WP4 endpoint/translation/spy checks
```

Stop and report if these fail. WP5 depends on WP1-WP4 schema contracts. A ledger over an invalid manifest or pair map cannot be interpreted reliably.

---

## Allowed files to create or edit

Prefer creating project-level wrapper files only:

```text
scripts/four_bed/makeYangFourBedLedger.m
scripts/four_bed/validateYangFourBedLedger.m
scripts/four_bed/appendYangLedgerStreamRows.m
scripts/four_bed/classifyYangLedgerOperation.m
scripts/four_bed/summarizeYangFourBedLedger.m
scripts/four_bed/computeYangLedgerBalances.m
scripts/four_bed/computeYangPerformanceMetrics.m
scripts/four_bed/extractYangStateVector.m
scripts/four_bed/computeYangStateFamilyResiduals.m
scripts/four_bed/computeYangFourBedCssResiduals.m
scripts/four_bed/makeYangFourBedRunMetadata.m
scripts/four_bed/validateYangFourBedRunMetadata.m
scripts/four_bed/extractYangNativeLedgerRows.m          % optional, only if safe and well-tested
scripts/four_bed/runYangLedgeredTemporaryCase.m         % optional adapter around WP4 runner

tests/four_bed/testYangFourBedLedgerSchema.m
tests/four_bed/testYangPairLocalConservation.m
tests/four_bed/testYangFullSlotLedgerBalance.m
tests/four_bed/testYangCssResidualsAllBeds.m
tests/four_bed/testYangMetricsExternalBasis.m
tests/four_bed/testYangRunMetadataAssumptions.m
tests/four_bed/testYangAdppBfLedgerSplit.m              % recommended, maps to T-PAIR-04/T-CONS-02
tests/four_bed/testYangEqStageLedgerSeparation.m         % recommended, maps to T-PAIR-02

scripts/run_ledger_tests.m
scripts/run_sanity_tests.m

docs/four_bed/WP5_ledger_css_reporting.md
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

Do not edit these toPSAil core folders for WP5:

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
- new adsorber material, mass, energy, pressure-flow, momentum, or valve equations;
- event-based Yang scheduling;
- invented numeric intermediate pressures P1, P2, P3, P5, or P6;
- a generalized four-bed PFD or GUI path;
- tuning constants to improve Yang agreement;
- a claim that the homogeneous surrogate is physically faithful to Yang layered beds;
- a claim that internal transfers are product;
- a change to native two-bed performance metric code.
```

Native toPSAil templates may structurally contain feed, raffinate, or extract tanks. That is not the prohibited object. The prohibited object is a persistent or dynamic Yang internal-transfer tank/header used to mediate `EQI`, `EQII`, `PP -> PU`, or `AD&PP -> BF`. WP5 may read native cumulative-flow diagnostics if present, but must not write native tank inventory into the persistent Yang bed-state container.

---

## WP5 planning constraints to enforce

### From `four_bed_work_packages.csv`

WP5 owns:

```text
Ledger, CSS, and reporting layer
External/internal component ledger
Yang-style purity/recovery definitions
All-bed CSS residuals
Output metadata
```

WP5 non-goals:

```text
Do not count internal transfers as product.
Do not claim Yang validation before the mismatch register is complete.
```

### From `four_bed_architecture_map.csv`

The accounting rules are:

| Pairing rule | Donor role | Receiver role | Accounting rule |
|---|---|---|---|
| EQI direct equalization | `EQI-BD` | `EQI-PR` | Internal transfer only |
| EQII direct equalization | `EQII-BD` | `EQII-PR` | Internal transfer only |
| Provide purge | `PP` | `PU` | Internal transfer; receiver waste remains external waste |
| Backfill | `AD&PP` | `BF` | Internal BF transfer separated from product |

The wrapper execution sequence says ledger handling occurs after temporary case invocation, before/while terminal states are written back. The ledger must receive enough local/global metadata to tie rows to named beds, local indices, source records, pair IDs, and direct-transfer families.

### From `four_bed_issue_register.csv`

WP5 must defend especially against:

| Issue | Failure mode | WP5 defence |
|---|---|---|
| `ARCH-01` | Dynamic tanks accidentally retained | Metadata and tests must state no Yang internal tank/header inventory. |
| `ARCH-03` | Core adsorber physics modified | Keep changes under `scripts/`, `tests/`, `docs/`. |
| `SCHED-03` | `AD&PP` confused with ordinary AD or PP | Ledger classification must split external adsorption/product from internal BF transfer. |
| `PAIR-03` | EQI and EQII collapsed | Ledger rows and summaries must preserve `stage_label`/`direct_transfer_family`. |
| `CASE-03` | Local bed identity obscures outputs | Every ledger row carries `global_bed`, `local_index`, `local_role`, `yang_label`, and `record_id`. |
| `LEDGER-01` | Internal direct transfers counted as product | Metric functions only use `external_product` rows. |
| `LEDGER-02` | `AD&PP/BF` split mishandled | Dedicated synthetic split test. |
| `LEDGER-03` | Slot-level balance does not close | Per-slot and per-cycle balance functions with residuals. |
| `CSS-01` | CSS checked on one bed/local case | CSS helper must aggregate all four persistent beds. |
| `CSS-02` | Thermal CSS slower than composition CSS | CSS helper reports gas concentration, adsorbed loading, gas temperature, and wall temperature residual families separately where possible. |
| `PARAM-02` | Model mismatch blamed on scheduling | Metadata states homogeneous/layered and thermal assumptions. |
| `EVENT-01` | Event control added too early | Metadata and docs state fixed-duration policy. |
| `DOC-01` | Output assumptions invisible | Metadata test verifies assumptions are present. |

### From `four_bed_test_matrix.csv`

WP5 handoff tests:

```text
T-CONS-01  Pair-local conservation
T-CONS-02  Full-slot ledger balance
T-CSS-01   All-bed CSS residual
T-MET-01   Yang purity/recovery reconstruction
T-DOC-01   Run metadata assumptions
```

Also cover, because they overlap WP5 accounting:

```text
T-PAIR-02  EQII direct pair call: stage-specific ledger row
T-PAIR-04  AD&PP -> BF split audit
T-NUM-01   nVol/tolerance sensitivity, non-default and later-stage only
```

`T-NUM-01` is not a default smoke test. Do not hide it in `run_sanity_tests.m`.

---

## Core design

### 1. Ledger row model

Use one table row per component per stream event. Avoid storing a vector in a single table cell for the default ledger. Component-long rows are easier to aggregate, print, and test.

Recommended ledger structure:

```matlab
ledger = struct();
ledger.version = "WP5-Yang2009-four-bed-ledger-v1";
ledger.componentNames = componentNames(:);
ledger.streamRows = <table>;
ledger.balanceRows = <table>;
ledger.metricRows = <table>;
ledger.cssRows = <table>;
ledger.metadata = metadata;
```

Recommended `ledger.streamRows` variables:

```text
cycle_index                 double scalar
slot_index                  double scalar
operation_group_id          string
source_col                  double scalar or NaN
record_id                   string
pair_id                     string
stage_label                 string, e.g. AD, BD, EQI, EQII, PP_PU, ADPP_BF
direct_transfer_family      string, e.g. none, EQI, EQII, PP_PU, ADPP_BF
yang_label                  string
global_bed                  string, A/B/C/D or none
local_index                 double scalar or NaN
local_role                  string, donor/receiver/external_single/etc.
stream_scope                string, see below
stream_direction            string, in/out/out_of_donor/into_receiver/delta
endpoint                    string, feed_end/product_end/none/not_applicable
component                   string, e.g. H2, CO2, CO, CH4
moles                       double, nonnegative except inventory delta rows
basis                       string, synthetic/spy/native/caller_supplied/computed_inventory
units                       string, usually mol
notes                       string
```

Allowed `stream_scope` values:

```text
external_feed
external_product
external_waste
internal_transfer
bed_inventory_delta
```

Allowed `stream_direction` values:

```text
in
out
out_of_donor
into_receiver
delta
```

Rules:

- `external_feed`, `external_product`, `external_waste`, and `internal_transfer` rows should normally have nonnegative `moles`.
- `bed_inventory_delta` rows may be signed because `delta = terminal_inventory - initial_inventory`.
- Internal transfer rows are ledger diagnostics and conservation aids. They must not contribute to product purity or recovery.
- Every row must carry the local/global identity metadata, even when it looks redundant. Output ambiguity is how projects develop folklore instead of diagnostics.

### 2. Ledger sign conventions

Use these equations by component.

External balance for a slot or cycle:

```text
external_feed - external_product - external_waste - bed_inventory_delta = residual
```

where:

```text
bed_inventory_delta = terminal_bed_inventory - initial_bed_inventory
```

Internal transfer cancellation:

```text
internal_transfer_into_receiver - internal_transfer_out_of_donor = residual
```

Interpretation:

- Equalization pair with no external streams: total bed inventory delta should be approximately zero, and internal transfer in/out should cancel.
- `PP -> PU`: internal transfer cancels, but receiver purge waste is external waste and must appear in the external balance.
- `AD&PP -> BF`: donor external product and internal backfill are separate. The BF internal stream must not increase external product.

### 3. Operation classification

Implement `classifyYangLedgerOperation(tempCase)` or equivalent. It should return expected stream categories, not quantities. Quantity extraction is a separate concern.

Recommended behavior:

| Case | Expected ledger categories |
|---|---|
| single `AD` | `external_feed`, `external_product` |
| single `BD` | `external_waste` |
| pair `EQI` | `internal_transfer` out of donor and into receiver, stage `EQI` |
| pair `EQII` | `internal_transfer` out of donor and into receiver, stage `EQII` |
| pair `PP_PU` | `internal_transfer` out of donor and into receiver; receiver `external_waste` |
| pair `ADPP_BF` | donor `external_feed`, donor `external_product`, donor/receiver `internal_transfer` |
| single `AD&PP`, `EQI-BD`, `EQI-PR`, `EQII-BD`, `EQII-PR`, `PP`, `PU`, `BF` | throw or report `paired_selection_required` |

Use `tempCase.native.stageLabel`, `tempCase.directTransferFamily`, `tempCase.localMap`, and `tempCase.native.endpointPolicy` rather than re-parsing source labels from scratch. The manifest and pair map already did that work.

### 4. Source of quantities

WP5 should support three quantity sources, in this order of implementation:

1. **Synthetic/caller-supplied quantities** for tests and deterministic ledger commissioning.
2. **Spy-run quantities** for wrapper-order tests, if a spy report supplies stream packets.
3. **Native quantities** extracted from `runReport.stStates` and `TemplateParams`, only when the operation is native-runnable and the extractor is tested.

Do not make native extraction a prerequisite for the WP5 unit tests. The point of WP5 is to make the accounting basis unambiguous before numerical output arrives. Otherwise a failed numerical run will not localize the cause among mapping, accounting, numerical, or physical-model issues.

Recommended optional native extractor:

```matlab
rows = extractYangNativeLedgerRows(params, tempCase, runReport, varargin)
```

Conservative requirements for this optional helper:

- require `runReport.didInvokeNative == true`;
- require numeric `runReport.stStates`;
- require initialized `params` with `nComs`, `nScaleFac`, `nColStT`, `nFeTaStT`, `nRaTaStT`, `nExTaStT`, `inShFeTa`, `inShRaTa`, `inShExTa`, and component names;
- extract cumulative moles from the final row before `convert2TermStates` zeroes them;
- state exactly whether the quantities came from feed tank, raffinate tank, extract tank, column feed boundary, or column product boundary;
- do not infer unsupported `PP_PU` or `ADPP_BF` native quantities.

Native cumulative-flow notes from current toPSAil internals:

- A column state vector has CSTR states followed by `2*nComs` cumulative boundary entries.
- The first `nComs` of those trailing entries are feed-end cumulative moles.
- The second `nComs` are product-end cumulative moles.
- `convert2TermStates` zeroes cumulative flow counters in terminal states; therefore read cumulative quantities from `runReport.stStates`, not from terminal local states.
- Native toPSAil performance functions aggregate feed, raffinate product/waste, and extract product/waste through tank cumulative fields. These functions are informative, but WP5 must reconstruct Yang-basis metrics from ledger rows.

### 5. Inventory delta handling

For synthetic and spy tests, allow the caller to append explicit `bed_inventory_delta` rows. This avoids making ledger tests depend on native physical parameters.

For numeric state payloads, implement a helper:

```matlab
stateVector = extractYangStateVector(statePayload)
```

Accepted payloads:

```text
numeric vector
struct with numeric field stateVector
```

For CSS residuals, no physical units are required; compare state vectors directly.

For physical inventory, be more cautious. Implement only if all required `params` fields are present and the unit convention is clear. A safe helper signature is:

```matlab
inventoryRows = computeYangBedInventory(params, statePayload, componentNames, bedLabel, varargin)
```

Guardrails:

- throw a clear error if required scale or geometry fields are missing;
- state in the output whether inventory is `computed_from_state_vector` or `caller_supplied`;
- do not invent adsorbent density or layer-specific inventory fields;
- do not claim layered-bed inventory if the run is a homogeneous surrogate.

For the first WP5 pass, it is acceptable to implement `bed_inventory_delta` as caller-supplied rows for ledger tests, and to implement state-vector residuals for CSS. Full physical inventory extraction can be a later task if native numerical runs become available.

### 6. CSS residuals

Implement all-bed CSS on the persistent four-bed container, not on a temporary local case.

Recommended helper:

```matlab
css = computeYangFourBedCssResiduals(initialContainer, finalContainer, varargin)
```

Recommended options:

```text
Params              optional toPSAil params struct for family-specific splitting
AbsTol              default 1e-8 for synthetic tests unless project policy says otherwise
RelTol              default 1e-6 for synthetic tests unless project policy says otherwise
NormType            "rms_relative" or "max_abs"
CycleIndex          optional
```

Recommended output:

```matlab
css = struct();
css.version = "WP5-Yang2009-css-residual-v1";
css.pass = logical(...);
css.aggregateResidual = ...;
css.controllingBed = "A";
css.controllingFamily = "gas_concentration";
css.rows = <table>;
css.tolerances = struct(...);
css.notes = ...;
```

Recommended `css.rows` variables:

```text
cycle_index
bed
state_field
family
n_values
max_abs
rms_abs
relative_norm
pass
notes
```

Families:

```text
all_state
state_vector
boundary_cumulative_flow_excluded
gas_concentration
adsorbed_loading
gas_temperature
wall_temperature
unsupported_payload
```

If `params` is not supplied, compute only `state_vector`/`all_state`. If `params` is supplied, split family indices using the current toPSAil state layout:

```text
nStates = 2*nComs + 2
for each CSTR:
  gas concentrations:      positions 1:nComs
  adsorbed concentrations: positions nComs+1:2*nComs
  gas temperature:         position 2*nComs+1
  wall temperature:        position 2*nComs+2
trailing boundary cumulative flows: last 2*nComs entries of column vector
```

Exclude trailing cumulative-flow counters from CSS residuals, because toPSAil resets them at step/cycle boundaries and they are accounting diagnostics rather than persistent bed thermodynamic state.

### 7. Yang-basis metrics

Implement:

```matlab
metrics = computeYangPerformanceMetrics(ledger, varargin)
```

Recommended options:

```text
TargetProductComponent    default "H2" if present, otherwise first component
CycleIndex                optional, default all cycles
MetricBasis               default "external_ledger_only_internal_transfers_excluded"
```

Definitions:

```text
H2 product purity = H2 moles in external_product / total moles in external_product
H2 recovery       = H2 moles in external_product / H2 moles in external_feed
```

For a Yang hydrogen PSA comparison, the target product is the raffinate/external product stream. Do not include `internal_transfer` rows in either numerator or denominator.

Recommended metric rows:

```text
cycle_index
metric_name
component
value
numerator_moles
denominator_moles
basis
pass
notes
```

NaN policy:

- If denominator is zero, return `NaN` and a warning note.
- Do not silently replace `NaN` with zero.
- Do not compare to Yang recovery/purity targets unless model mismatch and numerical commissioning are documented.

### 8. Run metadata

Implement:

```matlab
metadata = makeYangFourBedRunMetadata(manifest, pairMap, varargin)
```

Required fields:

```text
version
createdBy
manifestVersion
pairMapVersion
wrapperMode
holdupPolicy
internalTransferPolicy
statePolicy
caseBuilderPolicy
eventPolicy
metricBasis
cssBasis
nativeMetricPolicy
layeredBedPolicy
thermalPolicy
modelMismatchPolicy
validationClaim
runnerMode
numericalCommissioningStatus
notes
```

Required values or equivalents:

```text
wrapperMode                  = "thin_four_bed_orchestration_layer"
holdupPolicy                 = "zero_holdup_direct_bed_to_bed_internal_transfers"
internalTransferPolicy       = "not_external_product"
statePolicy                  = "persistent_named_bed_states_A_B_C_D_only"
caseBuilderPolicy            = "temporary_single_or_two_local_bed_cases"
eventPolicy                  = "fixed_duration_only"
metricBasis                  = "external_feed_product_waste_ledger_internal_transfers_excluded"
nativeMetricPolicy           = "native_metrics_diagnostic_not_yang_basis"
layeredBedPolicy             = value from manifest.layeredBedAudit if present, otherwise "not_confirmed"
modelMismatchPolicy          = "do_not_claim_yang_validation_before_mismatch_register_complete"
validationClaim              = "ledger_css_reporting_commissioning_only"
```

Implement `validateYangFourBedRunMetadata(metadata)` and make `T-DOC-01` fail if any of these assumptions are absent.

---

## Implementation steps

### Step 0: Start clean

From the repo root:

```bash
git status --short
```

Do not revert unrelated dirty files. Report them.

Run baseline tests:

```matlab
addpath(genpath(pwd));
run("scripts/run_source_tests.m");
run("scripts/run_sanity_tests.m");
```

### Step 1: Create the empty ledger constructor

Create:

```text
scripts/four_bed/makeYangFourBedLedger.m
scripts/four_bed/validateYangFourBedLedger.m
```

Suggested signature:

```matlab
function ledger = makeYangFourBedLedger(componentNames, varargin)
```

Options:

```text
Manifest
PairMap
Metadata
LedgerNote
```

Minimum behavior:

- require nonempty component names;
- create empty stream, balance, metric, and CSS tables with the expected variables;
- attach metadata from `makeYangFourBedRunMetadata` when manifest/pair map are supplied;
- include architecture flags: no dynamic internal tanks, no shared header inventory, no four-bed RHS/DAE, no core physics rewrite.

Validation should check:

- required top-level fields exist;
- stream table has required variables;
- stream scopes are from the allowed set;
- moles are finite except where explicitly allowed for diagnostic NaN rows;
- internal transfers are not marked as external product;
- metadata contains the required assumptions.

### Step 2: Add stream-row appending

Create:

```text
scripts/four_bed/appendYangLedgerStreamRows.m
```

Suggested signature:

```matlab
function ledger = appendYangLedgerStreamRows(ledger, componentNames, moles, varargin)
```

Options should include every required metadata column, with safe defaults:

```text
CycleIndex
SlotIndex
OperationGroupId
SourceCol
RecordId
PairId
StageLabel
DirectTransferFamily
YangLabel
GlobalBed
LocalIndex
LocalRole
StreamScope
StreamDirection
Endpoint
Basis
Units
Notes
AllowSignedMoles
```

Behavior:

- expand one vector of component moles into one row per component;
- require `numel(moles) == numel(componentNames)`;
- require nonnegative moles unless `StreamScope == "bed_inventory_delta"` or `AllowSignedMoles == true`;
- call `validateYangFourBedLedger` before returning if practical.

This helper should remain deliberately simple and deterministic.

### Step 3: Add operation classification

Create:

```text
scripts/four_bed/classifyYangLedgerOperation.m
```

Suggested signature:

```matlab
function spec = classifyYangLedgerOperation(tempCase)
```

Output should include:

```text
stage_label
direct_transfer_family
expected_stream_scopes
external_stream_scopes
internal_stream_scopes
requires_caller_quantities
notes
```

Use this in tests to ensure:

- `EQI` and `EQII` produce distinct stage labels;
- `ADPP_BF` exposes both `external_product` and `internal_transfer` expectations;
- `PP_PU` exposes `internal_transfer` and receiver `external_waste` expectations;
- single direct-transfer roles throw or report `paired_selection_required`.

### Step 4: Add ledger summarization and balance calculations

Create:

```text
scripts/four_bed/summarizeYangFourBedLedger.m
scripts/four_bed/computeYangLedgerBalances.m
```

`computeYangLedgerBalances` should produce at least:

1. Slot-level external balances.
2. Cycle-level external balances.
3. Internal transfer cancellation balances by slot, family, and component.
4. Pass/fail residuals against a caller-supplied tolerance.

Suggested signature:

```matlab
function [balanceRows, summary] = computeYangLedgerBalances(ledger, varargin)
```

Options:

```text
CycleIndex
SlotIndex
ComponentNames
AbsTol        default 1e-9 for synthetic tests
RelTol        default 1e-9 for synthetic tests
```

External residual equation:

```matlab
residual = externalFeed - externalProduct - externalWaste - bedInventoryDelta;
```

Internal cancellation equation:

```matlab
residual = internalIntoReceiver - internalOutOfDonor;
```

Store residual rows, not just a scalar. The whole point is to know which component and slot failed.

### Step 5: Add Yang metrics

Create:

```text
scripts/four_bed/computeYangPerformanceMetrics.m
```

Suggested signature:

```matlab
function metrics = computeYangPerformanceMetrics(ledger, varargin)
```

Options:

```text
TargetProductComponent    default "H2" if present
CycleIndex
```

Output should include `product_purity` and `product_recovery` rows for the target component.

Metric formulas:

```matlab
productPurity = externalProductTarget / totalExternalProduct;
productRecovery = externalProductTarget / externalFeedTarget;
```

Tests must prove that adding internal transfer rows does not change either metric.

### Step 6: Add CSS residual helpers

Create:

```text
scripts/four_bed/extractYangStateVector.m
scripts/four_bed/computeYangStateFamilyResiduals.m
scripts/four_bed/computeYangFourBedCssResiduals.m
```

`extractYangStateVector` should accept:

```text
numeric vector
struct with numeric stateVector field
```

It should reject arbitrary sentinel structs for numerical CSS and report `unsupported_payload` rather than pretending every struct is a state vector.

`computeYangFourBedCssResiduals` should:

- validate both containers with `validateYangFourBedStateContainer`;
- compare `state_A`, `state_B`, `state_C`, `state_D`;
- report per-bed/per-family rows;
- compute aggregate maximum relative residual;
- report controlling bed and controlling family;
- avoid comparing non-participant temporary local states.

Synthetic CSS test idea:

```text
initial A = [1 2 3 ...]
final A   = initial A + 1e-10
initial B = [10 20 30 ...]
final B   = initial B + 1e-7
...
```

The helper should identify the controlling bed/family and pass/fail according to supplied tolerances.

### Step 7: Add metadata helpers

Create:

```text
scripts/four_bed/makeYangFourBedRunMetadata.m
scripts/four_bed/validateYangFourBedRunMetadata.m
```

The metadata validator should fail if the output does not state:

```text
manifest version
pair-map version
no dynamic internal tanks
no shared header inventory
no global four-bed RHS/DAE
fixed-duration event policy
zero-holdup direct internal transfer policy
internal transfers excluded from product/recovery
native metrics are diagnostic, not Yang-basis
layered-bed/homogeneous surrogate status
no Yang validation claim before mismatch register is complete
```

This is `T-DOC-01`.

### Step 8: Optional runner adapter

Only after the ledger functions and tests pass, create an adapter if useful:

```text
scripts/four_bed/runYangLedgeredTemporaryCase.m
```

Possible signature:

```matlab
function [updatedContainer, ledger, report] = runYangLedgeredTemporaryCase(container, selection, tempCase, ledger, varargin)
```

This helper should:

1. run the WP4 temporary case through `runYangTemporaryCase`;
2. append caller-supplied or extracted stream rows;
3. compute and append bed inventory delta rows if possible;
4. write terminal states back with `writeBackYangFourBedStates`;
5. return a report containing run mode, ledger rows appended, and writeback report.

Do not make this required for the first WP5 smoke tests. It is useful glue, but the ledger logic should be independently testable.

### Step 9: Add runners and docs

Create:

```text
scripts/run_ledger_tests.m
```

It should run only fast WP5 tests:

```matlab
fprintf('Running WP5 ledger/CSS/reporting tests...\n');

testYangFourBedLedgerSchema();
testYangPairLocalConservation();
testYangEqStageLedgerSeparation();
testYangAdppBfLedgerSplit();
testYangFullSlotLedgerBalance();
testYangCssResidualsAllBeds();
testYangMetricsExternalBasis();
testYangRunMetadataAssumptions();

fprintf('All WP5 ledger/CSS/reporting tests passed.\n');
```

Update `scripts/run_sanity_tests.m` to call `run_ledger_tests.m` after existing WP3/WP4 sanity tests, provided the tests remain fast and synthetic. Do not add long numerical pilots to default sanity.

Update:

```text
docs/four_bed/WP5_ledger_css_reporting.md
scripts/README.md
tests/README.md
```

The WP5 doc should state:

- ledger schema;
- balance equations;
- metric basis;
- CSS residual basis;
- metadata assumptions;
- current limitation: no full Yang validation claim.

---

## Required tests in detail

### `testYangFourBedLedgerSchema.m`

Maps to: `T-DOC-01`, `LEDGER-01`, `DOC-01`.

Purpose:

- constructor creates required tables and metadata;
- validator rejects missing required assumptions;
- internal transfer rows are not product rows.

Suggested setup:

```matlab
manifest = getYangFourBedScheduleManifest();
pairMap = getYangDirectTransferPairMap(manifest);
ledger = makeYangFourBedLedger(["H2"; "CO2"; "CO"; "CH4"], ...
    'Manifest', manifest, 'PairMap', pairMap);
result = validateYangFourBedLedger(ledger);
assert(result.pass);
```

### `testYangPairLocalConservation.m`

Maps to: `T-CONS-01`, `LEDGER-03`, `PAIR-02`.

Purpose:

- closed direct pair with no external streams balances by inventory delta;
- internal transfer out/in cancels;
- EQI/EQII stage labels are carried.

Synthetic example:

```text
componentNames = ["H2", "CO2"]
internal out of donor = [1.0, 0.1]
internal into receiver = [1.0, 0.1]
total bed inventory delta = [0.0, 0.0]
```

Expected:

```text
external residual = 0
internal cancellation residual = 0
```

### `testYangEqStageLedgerSeparation.m`

Maps to: `T-PAIR-02`, `PAIR-03`.

Purpose:

- `EQI` and `EQII` ledger rows remain distinguishable;
- summaries do not collapse both into generic `EQ`.

Suggested setup:

- create one synthetic EQI pair row and one synthetic EQII pair row;
- assert `stage_label` contains both `EQI` and `EQII`;
- assert summaries by stage have two distinct groups.

### `testYangAdppBfLedgerSplit.m`

Maps to: `T-PAIR-04`, `LEDGER-02`, `SCHED-03`.

Purpose:

- `AD&PP -> BF` splits external product from internal backfill;
- product purity/recovery ignores internal backfill;
- internal BF transfer cancels.

Synthetic example:

```text
external feed:       H2 = 10.0, CO2 = 2.0
external product:    H2 =  7.0, CO2 = 0.01
internal BF out:     H2 =  1.0, CO2 = 0.00
internal BF in:      H2 =  1.0, CO2 = 0.00
external waste:      H2 =  0.0, CO2 = 0.00
total bed delta:     H2 =  3.0, CO2 = 1.99
```

Expected:

```text
external balance residual = 0
internal cancellation residual = 0
product purity = 7.0 / 7.01
H2 recovery = 7.0 / 10.0
```

Then add a deliberately large internal BF transfer and assert purity/recovery remain unchanged as long as external product/feed rows are unchanged.

### `testYangFullSlotLedgerBalance.m`

Maps to: `T-CONS-02`, `LEDGER-01`, `LEDGER-02`, `LEDGER-03`.

Purpose:

- one operation group containing external and internal streams closes;
- internal transfers cancel in external-product basis.

Use either the `ADPP_BF` example above or a `PP_PU` synthetic example:

```text
internal PP out:     H2 = 1.0, CO2 = 0.10
internal PU in:      H2 = 1.0, CO2 = 0.10
external waste:      H2 = 0.2, CO2 = 0.05
total bed delta:     H2 = -0.2, CO2 = -0.05
```

Expected external equation:

```text
0 - 0 - waste - delta = 0
```

### `testYangCssResidualsAllBeds.m`

Maps to: `T-CSS-01`, `CSS-01`, `CSS-02`.

Purpose:

- CSS helper checks all four named beds;
- reports controlling bed/family;
- fails if one bed exceeds tolerance;
- does not accept one temporary local pair as a full CSS check.

Synthetic setup:

- create initial/final containers with numeric `stateVector` fields for A/B/C/D;
- set one bed to exceed tolerance;
- assert `css.pass == false` and controlling bed is the modified bed;
- reduce perturbation and assert pass.

If `Params` is supplied in the test, use a minimal synthetic `params` with:

```text
nComs
nVols
nStates = 2*nComs + 2
nColStT = nStates*nVols + 2*nComs
```

Then assert rows exist for gas concentration, adsorbed loading, gas temperature, and wall temperature.

### `testYangMetricsExternalBasis.m`

Maps to: `T-MET-01`, `LEDGER-01`, `METRIC BASIS`.

Purpose:

- metrics are reconstructed from external ledger rows;
- internal transfers are excluded;
- definitions are visible in metric rows.

Synthetic setup:

```text
external feed:       H2 = 100, CO2 = 20
external product:    H2 =  75, CO2 = 0.001
internal transfer:   H2 = 500, CO2 = 10  out and in
```

Expected:

```text
H2 purity = 75 / (75 + 0.001)
H2 recovery = 75 / 100
```

Changing the internal transfer amount must not change either metric.

### `testYangRunMetadataAssumptions.m`

Maps to: `T-DOC-01`, `DOC-01`.

Purpose:

- metadata states simplified architecture and metric basis;
- metadata carries manifest and pair-map versions;
- missing assumptions fail validation.

Assertions:

```matlab
assert(metadata.eventPolicy == "fixed_duration_only");
assert(contains(metadata.internalTransferPolicy, "not_external_product"));
assert(contains(metadata.metricBasis, "external"));
assert(contains(metadata.validationClaim, "commissioning"));
```

Also remove or alter one required field and assert `validateYangFourBedRunMetadata` fails.

---

## Acceptance criteria

WP5 is complete enough to hand off when all of the following are true:

1. `run_source_tests.m` passes before and after WP5 edits.
2. `run_sanity_tests.m` passes and includes fast WP5 ledger/CSS/reporting tests.
3. `run_ledger_tests.m` passes independently.
4. Ledger rows preserve global bed labels, local indices, Yang labels, record IDs, pair IDs, direct-transfer families, stream scopes, and component names.
5. Internal transfer rows never contribute to product purity or recovery.
6. `AD&PP -> BF` has a dedicated split test that separates external product from internal backfill.
7. EQI and EQII remain distinct in ledger metadata and summaries.
8. Slot/cycle balance functions report component-level residuals.
9. CSS residuals use all four persistent bed states and report the controlling bed/family.
10. Output metadata states the no-tank, no-header, no-four-bed-RHS, fixed-duration, metric-basis, and model-mismatch assumptions.
11. No files under `1_config/`, `2_run/`, `3_source/`, `4_example/`, `5_reference/`, or `6_publication/` are changed.
12. No Yang validation or source-performance agreement claim is made.

---

## Stop conditions

Stop and report instead of editing if:

- required WP1-WP4 baseline tests fail;
- the task appears to require modifying toPSAil core internals;
- a ledger calculation would require inventing missing stream quantities;
- a physical inventory calculation would require unknown density, scale, or layer parameters;
- a metric denominator is zero and the task would require hiding the `NaN`;
- a test threshold would need to be weakened to pass;
- MATLAB cannot run the required tests;
- the implementation would mix WP5 ledger/CSS work with event scheduling, optimization, physical parameter tuning, or layered-bed physics.

---

## Final task report format for the Codex agent

When finished, report:

```text
Task objective
Files inspected
Files changed
Commands run
Tests passed
Tests failed
Unresolved uncertainties
Whether any toPSAil core files changed
Whether any validation numbers changed
Whether internal transfers are excluded from metrics
Whether all-bed CSS uses A/B/C/D or only a temporary case
Next smallest task
```

The next smallest task after WP5 should probably be either:

1. a safe numerical extractor for native `AD`, `BD`, `EQI`, and `EQII` cumulative quantities, or
2. a fixed-duration Yang skeleton pilot that uses the WP5 ledger but labels unsupported `PP_PU` and `ADPP_BF` operations honestly.

Do not jump directly to Yang performance comparison. A result with the wrong accounting basis is not a validation result.
