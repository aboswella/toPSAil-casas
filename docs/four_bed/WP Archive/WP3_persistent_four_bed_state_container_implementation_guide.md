# WP3 Implementation Guide: Persistent Four-Bed State Container

## Task card

**Task ID:** `WP3-YANG-PERSISTENT-STATE-CONTAINER`

**Goal:** implement the wrapper-level persistent state container for Yang four-bed beds `A`, `B`, `C`, and `D`, plus deterministic state selection and terminal-state writeback for later temporary single-bed and paired-bed toPSAil calls.

**Work-package scope:** WP3 from `docs/workflow/four_bed_work_packages.csv`.

**Required deliverables:**

1. A named four-bed state container with persistent fields `state_A`, `state_B`, `state_C`, and `state_D`.
2. A state injection and extraction contract for paired and single-bed temporary calls.
3. Terminal-state writeback rules that replace only participating named beds.
4. An explicit initialization policy recorded as metadata, without claiming physical Yang phase-offset initialization.
5. Unit tests for `T-STATE-01`, `T-STATE-02`, and `T-STATE-03` from `docs/workflow/four_bed_test_matrix.csv`.
6. A short WP3 documentation page under `docs/four_bed/`.

**Core principle:** this is bookkeeping, not physics. WP3 must not call the solver, build a temporary case, create a tank, create a header, assemble a four-bed RHS, change an adsorber equation, compute a ledger, compute CSS, or claim Yang validation. Humanity has already invented enough ways to hide bugs behind “frameworks”; do not contribute a fresh one.

---

## Required pre-reading before edits

Read these first, in this order:

1. `AGENTS.md`
2. `docs/CODEX_PROJECT_MAP.md`
3. `docs/TASK_PROTOCOL.md`
4. `docs/TEST_POLICY.md`
5. `docs/MODEL_SCOPE.md`
6. `docs/KNOWN_UNCERTAINTIES.md`
7. `docs/workflow/four_bed_project_context_file_map.txt`
8. `docs/workflow/four_bed_work_packages.csv`
9. `docs/workflow/four_bed_architecture_map.csv`
10. `docs/workflow/four_bed_issue_register.csv`
11. `docs/workflow/four_bed_test_matrix.csv`
12. `docs/workflow/four_bed_stage_gates.csv`
13. `docs/four_bed/WP1_yang_schedule_manifest.md`
14. `docs/four_bed/WP2_direct_transfer_pair_map.md`
15. Existing WP1/WP2 MATLAB helpers in `scripts/four_bed/`
16. Existing WP1/WP2 tests in `tests/four_bed/`

Also keep in mind the literature basis:

- Yang 2009 uses a four-bed, ten-step cycle with direct companion-bed equalization, purge provision, and backfill steps.
- toPSAil is the numerical engine. Its published workflow simulates PSA cycles step by step, and the project architecture says the Yang implementation must wrap existing behaviour rather than become a new four-bed process-network solver.

Do not open or edit source PDFs unless a planning/source contradiction blocks the task.

---

## Preconditions

Before making WP3 edits, run the existing source/static tests from the repository root:

```matlab
addpath(genpath(pwd));
run("scripts/run_source_tests.m");
```

Expected current tests:

- `testYangManifestIntegrity()`
- `testYangLayeredBedCapability()`
- `testYangPairMapCompleteness()`

Stop and report if these fail. WP3 depends on WP1/WP2 metadata. Patching WP3 around a bad pair map would be the computational equivalent of installing new tyres on a car with no steering wheel.

---

## Allowed files to edit

Create or edit only these project-level files unless an explicit blocker requires a documented exception:

```text
scripts/four_bed/makeYangFourBedStateContainer.m
scripts/four_bed/validateYangFourBedStateContainer.m
scripts/four_bed/selectYangFourBedPairStates.m
scripts/four_bed/selectYangFourBedSingleState.m
scripts/four_bed/writeBackYangFourBedStates.m
scripts/run_sanity_tests.m
tests/four_bed/testYangFourBedStateContainerShape.m
tests/four_bed/testYangFourBedWritebackOnlyParticipants.m
tests/four_bed/testYangFourBedCrossedPairRoundTrip.m
docs/four_bed/WP3_persistent_four_bed_state_container.md
scripts/README.md
tests/README.md
```

Optional, only if a real ambiguity is found:

```text
docs/KNOWN_UNCERTAINTIES.md
```

---

## Forbidden files and changes

Do not edit these directories for WP3:

```text
1_config/
2_run/
3_source/
4_example/
5_reference/
6_publication/
```

Do not edit these WP1/WP2 files unless a precondition test reveals a real defect and you stop to report first:

```text
scripts/four_bed/getYangFourBedScheduleManifest.m
scripts/four_bed/getYangDirectTransferPairMap.m
scripts/four_bed/validateYangFourBedScheduleManifest.m
scripts/four_bed/validateYangDirectTransferPairMap.m
docs/four_bed/WP1_yang_schedule_manifest.md
docs/four_bed/WP2_direct_transfer_pair_map.md
```

Do not edit canonical workflow CSVs:

```text
docs/workflow/*.csv
```

Do not add:

- dynamic internal tanks;
- shared header inventory;
- a global `[state_A,state_B,state_C,state_D]` numerical solve;
- core adsorber-physics changes;
- event-based scheduling;
- physical Yang initial-condition tuning;
- ledgers, product metrics, recovery, purity, or CSS logic.

---

## Relevant planning constraints to preserve

From the architecture map, the wrapper execution sequence is:

1. Read current Yang manifest group.
2. Select paired and single operations using the explicit pair map.
3. Build a temporary toPSAil-compatible paired or single case.
4. Invoke existing toPSAil machinery.
5. Write terminal states back to participating global beds.

WP3 owns only the state part of steps 2 and 5. WP4 will own case construction and native toPSAil calls. WP5 will own ledgers and metrics.

From the issue register, WP3 is mainly defending against:

| Issue | Failure mode | WP3 defence |
|---|---|---|
| `STATE-01` | Terminal states written back to the wrong named beds | Store explicit global bed to local index mapping and use it for writeback |
| `STATE-02` | Non-participating bed states overwritten | Writeback only selected fields; test nonparticipants with sentinel states |
| `STATE-03` | Wrong initial phase offsets | Record initialization policy explicitly; do not claim physical Yang phase-offset initialization |
| `SCHED-02` | Pairing inferred from row order | Consume `pairMap.transferPairs`; never infer adjacency |
| `ARCH-01` | Dynamic tanks retained | State container stores only bed states, not tank/header inventory |
| `ARCH-02` | Wrapper becomes a global four-bed RHS/DAE | Do not assemble or solve four-bed numerical state |

The stage gate for this work is Stage 3: state and case-builder bench. WP3 should exit with state round-trip and writeback tests passing for adjacent and crossed pairs, and non-participants unchanged. WP4 will pick up the case-builder half.

---

## Handoff from WP2

Treat WP2 as the source of direct-transfer pair identities. Do not rederive pairings from the Yang table.

`getYangDirectTransferPairMap()` returns a struct with:

```text
pairMap.version
pairMap.manifestVersion
pairMap.bedLabels
pairMap.architecture
pairMap.endpointMetadata
pairMap.transferPairs
```

The important table is `pairMap.transferPairs`. It has 16 rows and includes, among other columns:

```text
pair_id
direct_transfer_family
donor_bed
receiver_bed
donor_record_id
receiver_record_id
donor_source_col
receiver_source_col
donor_yang_label
receiver_yang_label
donor_role_class
receiver_role_class
donor_p_start_class
donor_p_end_class
receiver_p_start_class
receiver_p_end_class
donor_outlet_endpoint
receiver_inlet_endpoint
receiver_waste_endpoint
transfer_accounting_category
```

Required pair families from WP2:

| Family | Explicit pairs |
|---|---|
| `ADPP_BF` | `A->B`, `B->C`, `C->D`, `D->A` |
| `EQI` | `A->C`, `B->D`, `C->A`, `D->B` |
| `EQII` | `A->D`, `B->A`, `C->B`, `D->C` |
| `PP_PU` | `A->D`, `B->A`, `C->B`, `D->C` |

The crossed EQI pairs, especially `A->C` and `B->D`, are not decoration. They are the traps that catch lazy adjacency logic.

---

## Design choice for WP3

Use a plain MATLAB `struct` for the state container. Keep each bed payload opaque.

Recommended top-level structure:

```matlab
container = struct();
container.version = "WP3-Yang2009-four-bed-state-container-v1";
container.manifestVersion = string(manifest.version);
container.pairMapVersion = string(pairMap.version);
container.bedLabels = ["A", "B", "C", "D"];
container.stateFields = ["state_A", "state_B", "state_C", "state_D"];
container.initializationPolicy = "explicit_four_bed_payloads_supplied_by_caller";
container.sourceName = "Yang et al. 2009 Table 2 wrapper state layer";
container.architecture = struct(...);
container.state_A = initialStates.state_A;
container.state_B = initialStates.state_B;
container.state_C = initialStates.state_C;
container.state_D = initialStates.state_D;
container.stateMetadata = table(...);
container.writebackLog = table(...);
```

Why top-level `state_A` fields rather than a nested array? Because the work package explicitly asks for `state_A/state_B/state_C/state_D`, and because a field-per-bed contract makes wrong writeback easier to test. Yes, apparently clarity survived one meeting.

### Opaque payload rule

The state payloads may later be numeric vectors, structs, tables, or other toPSAil state carriers. WP3 must not inspect their internal fields. The only operations WP3 performs on payloads are:

- store;
- select;
- return for temporary local calls;
- replace on writeback;
- compare in tests using `isequaln`.

Do not assume fields like `c`, `q`, `T`, `Tw`, `adsorberState`, or any toPSAil-specific internal layout.

### Initialization policy

For WP3, require the caller to supply all four initial state payloads explicitly. Record how they were produced using a string metadata field.

Accepted near-term policy examples:

```text
unit_test_distinguishable_sentinel_states
explicit_four_bed_payloads_supplied_by_caller
homogeneous_surrogate_initial_states_not_yang_phase_offset
```

Do not claim that the four initial states are physically correct Yang phase offsets unless a later task implements and validates that. WP3 can store four states. It cannot magically know the bed inventories at Yang slot boundaries. Even MATLAB has limits, though it hides them behind cheerful semicolons.

---

## Function 1: `makeYangFourBedStateContainer.m`

### Purpose

Create the persistent four-bed state container from explicit bed-state payloads and metadata.

### Signature

```matlab
function container = makeYangFourBedStateContainer(initialStates, varargin)
```

Recommended name-value inputs:

```matlab
"Manifest"              % WP1 manifest struct, optional
"PairMap"               % WP2 pairMap struct, optional
"InitializationPolicy"  % string scalar, optional
"SourceNote"            % string scalar, optional
```

Recommended call pattern:

```matlab
manifest = getYangFourBedScheduleManifest();
pairMap = getYangDirectTransferPairMap(manifest);

initialStates = struct();
initialStates.state_A = struct("bed", "A", "value", 101);
initialStates.state_B = struct("bed", "B", "value", 202);
initialStates.state_C = struct("bed", "C", "value", 303);
initialStates.state_D = struct("bed", "D", "value", 404);

container = makeYangFourBedStateContainer(initialStates, ...
    "Manifest", manifest, ...
    "PairMap", pairMap, ...
    "InitializationPolicy", "unit_test_distinguishable_sentinel_states");
```

### Required behaviour

1. Require `initialStates` to be a struct with fields:

   ```text
   state_A
   state_B
   state_C
   state_D
   ```

2. Copy those payloads into the same top-level fields in `container`.

3. Set:

   ```matlab
   container.bedLabels = ["A", "B", "C", "D"];
   container.stateFields = ["state_A", "state_B", "state_C", "state_D"];
   ```

4. If `Manifest` is supplied, copy `manifest.version` into `container.manifestVersion`. If not supplied, use `"not_supplied"`.

5. If `PairMap` is supplied, copy `pairMap.version` into `container.pairMapVersion`. If not supplied, use `"not_supplied"`.

6. Add architecture flags:

   ```matlab
   container.architecture = struct( ...
       "noDynamicInternalTanks", true, ...
       "noSharedHeaderInventory", true, ...
       "noFourBedRhsDae", true, ...
       "noCoreAdsorberPhysicsRewrite", true, ...
       "wp3StoresPersistentBedStates", true, ...
       "wp3BuildsTemporaryCases", false, ...
       "wp3InvokesSolver", false, ...
       "wp3ComputesLedgersOrMetrics", false ...
   );
   ```

7. Add a metadata table with exactly four rows. Suggested schema:

   ```text
   bed
   state_field
   initialization_policy
   source_note
   last_update_role
   last_update_pair_id
   last_update_operation
   last_update_source_col
   writeback_count
   ```

   Initial `last_update_*` values should be `"initial"`, `"none"`, or `NaN` as appropriate.

8. Add an empty writeback log. Suggested schema:

   ```text
   writeback_index
   selection_type
   pair_id
   direct_transfer_family
   local_index
   local_role
   global_bed
   state_field
   yang_label
   record_id
   source_col
   update_note
   ```

   Keep it metadata-only. Do not store complete state payloads in the log.

### Error conditions

Use explicit error IDs. Suggested examples:

```matlab
error('WP3:InvalidInitialStates', ...)
error('WP3:MissingStateField', ...)
error('WP3:InvalidManifest', ...)
error('WP3:InvalidPairMap', ...)
```

### Implementation notes

- Prefer string arrays, tables, and structs, following WP1/WP2 style.
- Use `isfield(initialStates, char(fieldName))` for dynamic fields.
- Do not validate the payload type. The payload is intentionally opaque.
- Do not create helper defaults that initialize all four states identically unless the caller explicitly passes such states and the initialization policy says so.

---

## Function 2: `validateYangFourBedStateContainer.m`

### Purpose

Static/unit-level validation of the WP3 container schema and architecture flags.

### Signature

```matlab
function result = validateYangFourBedStateContainer(container, varargin)
```

Recommended name-value inputs:

```matlab
"Manifest"  % optional
"PairMap"   % optional
```

### Required return format

Match the WP1/WP2 validator style:

```matlab
result = struct();
result.pass = isempty(failures);
result.failures = failures;
result.warnings = warnings;
result.checks = checks;
```

Where `checks` is a table with:

```text
check
passed
detail
```

### Required checks

At minimum, check:

1. `container` is a struct.
2. Required top-level fields exist:

   ```text
   version
   manifestVersion
   pairMapVersion
   bedLabels
   stateFields
   initializationPolicy
   architecture
   stateMetadata
   writebackLog
   state_A
   state_B
   state_C
   state_D
   ```

3. `bedLabels` equals `["A", "B", "C", "D"]`.
4. `stateFields` equals `["state_A", "state_B", "state_C", "state_D"]`.
5. Each state field exists and is addressable.
6. `stateMetadata` is a table with four rows and the expected columns.
7. `writebackLog` is a table, even if empty.
8. Architecture flags are true for:

   ```text
   noDynamicInternalTanks
   noSharedHeaderInventory
   noFourBedRhsDae
   noCoreAdsorberPhysicsRewrite
   wp3StoresPersistentBedStates
   ```

9. Architecture flags are false for:

   ```text
   wp3BuildsTemporaryCases
   wp3InvokesSolver
   wp3ComputesLedgersOrMetrics
   ```

10. No top-level field name suggests forbidden physical state. A conservative check can flag field names containing:

   ```text
   tank_state
   header_inventory
   shared_header_inventory
   dynamic_tank_inventory
   four_bed_rhs
   four_bed_dae
   ```

   Do not flag `architecture.noFourBedRhsDae`; it is a policy flag, not a state vector.

11. If a manifest is supplied, `container.manifestVersion` matches `manifest.version`.
12. If a pair map is supplied, `container.pairMapVersion` matches `pairMap.version`.

### Important caution

Do not test or validate internal payload layout. A sentinel struct, a numeric vector, and a future toPSAil state struct should all be valid payloads. WP3's business is identity and writeback, not chemical truth. Chemistry already has enough variables without Codex inventing some in a validator.

---

## Function 3: `selectYangFourBedPairStates.m`

### Purpose

Select two named persistent bed states for a future temporary paired-bed call, using one row of `pairMap.transferPairs`.

### Signature

```matlab
function selection = selectYangFourBedPairStates(container, pairRow)
```

### Input

`pairRow` must be a one-row table from `pairMap.transferPairs`.

### Required local order

Use deterministic local order:

```text
local index 1 = donor bed
local index 2 = receiver bed
```

Do not sort by bed label. Do not use table row order. Do not use adjacency. Use `pairRow.donor_bed` and `pairRow.receiver_bed`. The `EQI B->D` case must select `B` as local 1 and `D` as local 2. Alphabetical sorting would pass some cases and betray you in exactly the annoying cases.

### Recommended return schema

```matlab
selection = struct();
selection.version = "WP3-Yang2009-state-selection-v1";
selection.selectionType = "paired_direct_transfer";
selection.pairId = pairRow.pair_id(1);
selection.directTransferFamily = pairRow.direct_transfer_family(1);
selection.localStates = {container.(donorField); container.(receiverField)};
selection.localMap = table(...);
```

Suggested `selection.localMap` columns:

```text
local_index
local_role
global_bed
state_field
yang_label
record_id
source_col
p_start_class
p_end_class
inlet_endpoint
outlet_endpoint
waste_endpoint
transfer_accounting_category
```

For pair rows, populate as follows:

| Column | Donor local row | Receiver local row |
|---|---|---|
| `local_index` | `1` | `2` |
| `local_role` | `"donor"` | `"receiver"` |
| `global_bed` | `pairRow.donor_bed` | `pairRow.receiver_bed` |
| `state_field` | `"state_" + pairRow.donor_bed` | `"state_" + pairRow.receiver_bed` |
| `yang_label` | `pairRow.donor_yang_label` | `pairRow.receiver_yang_label` |
| `record_id` | `pairRow.donor_record_id` | `pairRow.receiver_record_id` |
| `source_col` | `pairRow.donor_source_col` | `pairRow.receiver_source_col` |
| `p_start_class` | `pairRow.donor_p_start_class` | `pairRow.receiver_p_start_class` |
| `p_end_class` | `pairRow.donor_p_end_class` | `pairRow.receiver_p_end_class` |
| `inlet_endpoint` | `"none"` or donor-side metadata if helpful | `pairRow.receiver_inlet_endpoint` |
| `outlet_endpoint` | `pairRow.donor_outlet_endpoint` | `"none"` or receiver-side metadata if helpful |
| `waste_endpoint` | `"none"` | `pairRow.receiver_waste_endpoint` |
| `transfer_accounting_category` | `pairRow.transfer_accounting_category` | `pairRow.transfer_accounting_category` |

Endpoint metadata is mainly for WP4/WP5, but carrying it now helps avoid later ambiguity.

### Required validation

Raise clear errors for:

```matlab
WP3:InvalidStateContainer
WP3:InvalidPairRow
WP3:UnknownBedLabel
WP3:MissingStateField
WP3:DuplicatePairBed
```

Check that:

- `pairRow` is a table with height 1.
- donor and receiver beds are known labels.
- donor and receiver are distinct.
- both state fields exist in `container`.

---

## Function 4: `selectYangFourBedSingleState.m`

### Purpose

Select one named persistent bed state for a future single-bed temporary call, such as `AD` or `BD`.

### Signature

```matlab
function selection = selectYangFourBedSingleState(container, bedStepRow)
```

### Input

`bedStepRow` should be a one-row table from `manifest.bedSteps`.

### Required local order

Use one local bed:

```text
local index 1 = the bed in bedStepRow.bed
```

### Recommended return schema

Use the same shape as pair selection where possible:

```matlab
selection = struct();
selection.version = "WP3-Yang2009-state-selection-v1";
selection.selectionType = "single_bed_operation";
selection.pairId = "none";
selection.directTransferFamily = bedStepRow.direct_transfer_family(1);
selection.localStates = {container.(stateField)};
selection.localMap = table(... one row ...);
```

Suggested `selection.localMap` columns should match `selectYangFourBedPairStates`, because WP4 should not need two unrelated metadata contracts just because WP3 got bored.

For single steps:

- `local_role` can be `bedStepRow.role_class` or `"single"`.
- `global_bed` is `bedStepRow.bed`.
- `state_field` is `"state_" + bedStepRow.bed`.
- `yang_label`, `record_id`, `source_col`, `p_start_class`, and `p_end_class` come from the manifest row.
- Endpoint fields may be `"none"` in WP3.

### Required validation

Raise clear errors for:

```matlab
WP3:InvalidBedStepRow
WP3:UnknownBedLabel
WP3:MissingStateField
```

Do not reject direct-transfer rows categorically. WP4 may call the pair selector for pair rows, but the single selector should primarily be used for external/single operations. If you choose to reject `requires_pair_map == true`, do it deliberately and document the rule. The safer WP3 approach is to allow selection by bed row and leave operation compatibility to WP4.

---

## Function 5: `writeBackYangFourBedStates.m`

### Purpose

Replace only participating named bed states using terminal local states returned by a future temporary call.

### Signature

```matlab
function [updatedContainer, report] = writeBackYangFourBedStates(container, selection, terminalLocalStates, varargin)
```

Recommended optional input:

```matlab
"UpdateNote"  % string scalar, optional
```

### Required behaviour

1. Validate the container and selection.
2. Convert `terminalLocalStates` into a cell row or column array.
3. Require the number of terminal states to equal `height(selection.localMap)`.
4. Require each `selection.localMap.state_field` to exist in the container.
5. Require participating state fields to be unique.
6. Return a new `updatedContainer` with only selected state fields replaced.
7. Leave all non-participating `state_*` payloads unchanged.
8. Update `stateMetadata.writeback_count` only for participating beds.
9. Append metadata rows to `writebackLog` for participating beds.
10. Return a `report` struct describing what changed.

### Recommended report schema

```matlab
report = struct();
report.updatedStateFields = selection.localMap.state_field;
report.updatedBedLabels = selection.localMap.global_bed;
report.unchangedStateFields = setdiff(container.stateFields, report.updatedStateFields, 'stable');
report.writebackIndex = nextWritebackIndex;
report.selectionType = selection.selectionType;
report.pairId = selection.pairId;
report.directTransferFamily = selection.directTransferFamily;
```

### Error conditions

Use explicit error IDs:

```matlab
WP3:InvalidSelection
WP3:InvalidTerminalStates
WP3:TerminalStateCountMismatch
WP3:DuplicateWritebackTarget
WP3:MissingWritebackTarget
```

### Terminal state input format

Require cell arrays for now:

```matlab
terminalLocalStates = {terminalLocal1, terminalLocal2};
```

You may optionally support a struct with fields `local_1`, `local_2`, but do not overbuild this. WP4 can adapt once the actual native case return shape is known.

### Non-participant immutability

In tests, check nonparticipants using:

```matlab
assert(isequaln(updatedContainer.state_B, container.state_B));
```

This catches accidental resets, global copies, and sloppy reconstruction. The state container should be boring. Boring is how we know it is working.

---

## Suggested small helper functions

You may implement these as private local functions inside the files above. Avoid creating a sprawling helper zoo unless needed.

```matlab
function fieldName = getStateFieldName(bedLabel)
    fieldName = "state_" + string(bedLabel);
end

function assertKnownBedLabel(bedLabel, bedLabels)
    if ~ismember(string(bedLabel), string(bedLabels))
        error('WP3:UnknownBedLabel', ...);
    end
end

function payload = getStatePayload(container, bedLabel)
    fieldName = getStateFieldName(bedLabel);
    payload = container.(char(fieldName));
end
```

Keep helpers narrow. The state layer should not become a shadow object model for toPSAil.

---

## Tests to add

Create three focused tests. Each should state its test ID, tier, failure modes, and runtime in comments, following existing test style.

### Test 1: `tests/four_bed/testYangFourBedStateContainerShape.m`

Maps to `T-STATE-01`.

**Purpose:** persistent state container shape and deterministic local injection order.

**Failure modes caught:** `STATE-01`, `STATE-03`.

**Test setup:**

1. Build `manifest` and `pairMap` using existing WP1/WP2 helpers.
2. Build four distinguishable sentinel states.
3. Create a container with `makeYangFourBedStateContainer`.
4. Validate it with `validateYangFourBedStateContainer`.
5. Select a crossed pair, preferably `EQI A->C`.
6. Assert local order is donor then receiver, not alphabetical or adjacency-based.

Suggested sentinel builder inside the test file:

```matlab
function states = buildSentinelStates()
    states = struct();
    states.state_A = struct("bed", "A", "payload", 101, "marker", "sentinel_A");
    states.state_B = struct("bed", "B", "payload", 202, "marker", "sentinel_B");
    states.state_C = struct("bed", "C", "payload", 303, "marker", "sentinel_C");
    states.state_D = struct("bed", "D", "payload", 404, "marker", "sentinel_D");
end
```

Minimum assertions:

```matlab
assert(result.pass);
assert(isequal(string(container.bedLabels), ["A", "B", "C", "D"]));
assert(isequal(string(container.stateFields), ["state_A", "state_B", "state_C", "state_D"]));
assert(isequaln(container.state_A, initialStates.state_A));
assert(isequaln(container.state_B, initialStates.state_B));
assert(isequaln(container.state_C, initialStates.state_C));
assert(isequaln(container.state_D, initialStates.state_D));

pair = pairMap.transferPairs( ...
    pairMap.transferPairs.direct_transfer_family == "EQI" & ...
    pairMap.transferPairs.donor_bed == "A" & ...
    pairMap.transferPairs.receiver_bed == "C", :);
selection = selectYangFourBedPairStates(container, pair);
assert(isequal(selection.localMap.global_bed, ["A"; "C"]));
assert(isequal(selection.localMap.state_field, ["state_A"; "state_C"]));
assert(isequaln(selection.localStates{1}, initialStates.state_A));
assert(isequaln(selection.localStates{2}, initialStates.state_C));
```

End with:

```matlab
fprintf('T-STATE-01 passed: persistent four-bed state container shape and deterministic selection.\n');
```

### Test 2: `tests/four_bed/testYangFourBedWritebackOnlyParticipants.m`

Maps to `T-STATE-02`.

**Purpose:** writeback only replaces participating named bed states.

**Failure modes caught:** `STATE-01`, `STATE-02`.

**Test setup:**

1. Build a sentinel container.
2. Select a paired operation, such as `EQI A->C`.
3. Create terminal states for the two local positions.
4. Write back.
5. Assert `state_A` and `state_C` changed as expected.
6. Assert `state_B` and `state_D` are unchanged.

Minimum assertions:

```matlab
terminalStates = {
    struct("bed", "A", "payload", 1001, "marker", "terminal_A_from_local_1")
    struct("bed", "C", "payload", 3003, "marker", "terminal_C_from_local_2")
};

[updated, report] = writeBackYangFourBedStates(container, selection, terminalStates, ...
    "UpdateNote", "T-STATE-02 synthetic terminal states");

assert(isequaln(updated.state_A, terminalStates{1}));
assert(isequaln(updated.state_C, terminalStates{2}));
assert(isequaln(updated.state_B, container.state_B));
assert(isequaln(updated.state_D, container.state_D));
assert(isequal(string(report.updatedStateFields), ["state_A"; "state_C"]));
```

End with:

```matlab
fprintf('T-STATE-02 passed: writeback replaces only participating bed states.\n');
```

### Test 3: `tests/four_bed/testYangFourBedCrossedPairRoundTrip.m`

Maps to `T-STATE-03`.

**Purpose:** crossed pair local outputs return to correct global bed labels.

**Failure modes caught:** `STATE-01`, `SCHED-02`.

**Test setup:**

1. Build a sentinel container.
2. Select a crossed pair that is not adjacent, preferably `EQI B->D`.
3. Confirm local map is `B` then `D`.
4. Create terminal local states whose markers identify local position and intended global bed.
5. Write back.
6. Assert `state_B` receives local 1 and `state_D` receives local 2.
7. Assert `state_A` and `state_C` are unchanged.

Minimum assertions:

```matlab
pair = pairMap.transferPairs( ...
    pairMap.transferPairs.direct_transfer_family == "EQI" & ...
    pairMap.transferPairs.donor_bed == "B" & ...
    pairMap.transferPairs.receiver_bed == "D", :);
selection = selectYangFourBedPairStates(container, pair);
assert(isequal(selection.localMap.global_bed, ["B"; "D"]));

terminalStates = {
    struct("bed", "B", "payload", 2002, "marker", "local_1_donor_B_terminal")
    struct("bed", "D", "payload", 4004, "marker", "local_2_receiver_D_terminal")
};

updated = writeBackYangFourBedStates(container, selection, terminalStates);

assert(isequaln(updated.state_B, terminalStates{1}));
assert(isequaln(updated.state_D, terminalStates{2}));
assert(isequaln(updated.state_A, container.state_A));
assert(isequaln(updated.state_C, container.state_C));
```

End with:

```matlab
fprintf('T-STATE-03 passed: crossed-pair local states write back to correct global beds.\n');
```

---

## Runner to add: `scripts/run_sanity_tests.m`

Create this runner if it does not already exist. Keep it lightweight.

```matlab
%RUN_SANITY_TESTS Run lightweight unit/sanity tests for project wrappers.
%
% Default smoke inclusion: yes for WP3 state-container tests. Runtime class:
% < 30 s. This runner must not hide long validation, optimization,
% sensitivity, event-policy, or pilot Yang runs.

fprintf('Running sanity/unit tests...\n');

testYangFourBedStateContainerShape();
testYangFourBedWritebackOnlyParticipants();
testYangFourBedCrossedPairRoundTrip();

fprintf('All sanity/unit tests passed.\n');
```

Do not put numerical Yang pilots in this runner.

After creating it, run:

```matlab
addpath(genpath(pwd));
run("scripts/run_source_tests.m");
run("scripts/run_sanity_tests.m");
```

On the intended Windows MATLAB installation, use:

```powershell
& 'C:\Program Files\MATLAB\R2026a\bin\matlab.exe' -batch "addpath(genpath(pwd)); run('scripts/run_source_tests.m'); run('scripts/run_sanity_tests.m');"
```

---

## Documentation to add

Create:

```text
docs/four_bed/WP3_persistent_four_bed_state_container.md
```

Minimum content:

1. Purpose of WP3.
2. Explicit statement that WP3 is a state-management layer only.
3. Container schema summary.
4. Pair selection contract: local 1 donor, local 2 receiver.
5. Single-bed selection contract: local 1 selected bed.
6. Writeback contract: replace only participating named beds.
7. Initialization policy: explicit payloads supplied by caller; no physical Yang phase-offset claim.
8. Validation tests:

   ```text
   T-STATE-01 -> testYangFourBedStateContainerShape.m
   T-STATE-02 -> testYangFourBedWritebackOnlyParticipants.m
   T-STATE-03 -> testYangFourBedCrossedPairRoundTrip.m
   ```

9. Handoff to WP4:

   - WP4 should consume `selection.localStates` and `selection.localMap`.
   - WP4 should return terminal local states in the same local order.
   - WP4 must not discard global bed identity metadata.

10. Handoff to WP5:

   - WP5 can later use selection metadata and writeback logs for ledger attribution.
   - WP3 does not compute ledgers or metrics.

Update `scripts/README.md` and `tests/README.md` with short status bullets for WP3. Do not rewrite these docs wholesale.

---

## Acceptance criteria

WP3 is complete when:

1. Existing WP1/WP2 source tests still pass.
2. New WP3 sanity tests pass.
3. The repository contains a documented state container API.
4. No toPSAil core files changed.
5. No dynamic internal tank/header state is introduced.
6. No four-bed RHS/DAE is introduced.
7. The crossed-pair test proves that local output order maps back to the correct global bed labels.
8. Non-participating bed states remain `isequaln` to their pre-writeback values in tests.
9. Initialization policy is recorded without pretending to solve physical Yang phase offsets.

---

## Common mistakes to avoid

### Mistake 1: storing states in a four-element array without names

Do not do this:

```matlab
container.states = {stateA, stateB, stateC, stateD};
```

A list without names invites index drift. Use named fields and metadata.

### Mistake 2: sorting pair beds alphabetically

Do not do this:

```matlab
localBeds = sort([pairRow.donor_bed, pairRow.receiver_bed]);
```

The correct order is donor then receiver. `EQI B->D` must preserve `B` as local 1 and `D` as local 2.

### Mistake 3: rebuilding all four states after one pair call

Do not reconstruct the whole container from a partial result. Replace only participating fields. Nonparticipants are innocent bystanders, not spare variables awaiting reassignment.

### Mistake 4: creating fake companion tanks for single-bed operations

WP3 should not create any cases, tanks, headers, or flows. A single-bed selection is just a state and metadata contract.

### Mistake 5: peeking into payload internals

Do not read `payload.c`, `payload.q`, `payload.T`, or similar. WP3 should survive any payload type.

### Mistake 6: mixing WP3 and WP4

Do not call `runPsaCycle`, `runPsaCycleStep`, `solvOdes`, `defineRhsFunc`, or any case-builder logic from WP3 tests. The tests should run fast and not require numerical integration.

### Mistake 7: claiming Yang initialization is solved

Unless a later work package implements a manifest-driven first-cycle/phase-offset initializer, the honest state is:

```text
initial states are externally supplied or synthetic test sentinels
```

Record that. Lies are faster, right up until debugging begins.

---

## Suggested implementation order

1. Run existing `scripts/run_source_tests.m`.
2. Create `makeYangFourBedStateContainer.m`.
3. Create `validateYangFourBedStateContainer.m`.
4. Create `selectYangFourBedPairStates.m`.
5. Create `writeBackYangFourBedStates.m`.
6. Create `selectYangFourBedSingleState.m`.
7. Add `testYangFourBedStateContainerShape.m`.
8. Run it manually.
9. Add `testYangFourBedWritebackOnlyParticipants.m`.
10. Run it manually.
11. Add `testYangFourBedCrossedPairRoundTrip.m`.
12. Run it manually.
13. Add `scripts/run_sanity_tests.m`.
14. Run both source and sanity runners.
15. Add WP3 documentation and README status lines.
16. Run both runners again.
17. Prepare the required task report.

Manual single-test commands while developing:

```matlab
addpath(genpath(pwd));
testYangFourBedStateContainerShape();
testYangFourBedWritebackOnlyParticipants();
testYangFourBedCrossedPairRoundTrip();
```

Final required command:

```matlab
addpath(genpath(pwd));
run("scripts/run_source_tests.m");
run("scripts/run_sanity_tests.m");
```

---

## Required final report format for the Codex agent

End the implementation task with this exact structure:

```text
Task objective:
- Implement WP3 persistent four-bed state container and writeback contract.

Files inspected:
- ...

Files changed:
- ...

Commands run:
- ...

Tests passed:
- ...

Tests failed:
- ...

Unresolved uncertainties:
- ...

Core toPSAil files changed:
- No.  [or explain exactly what changed and why, but this should not happen for WP3]

Validation numbers changed:
- No.  [WP3 should not change validation numbers]

Architecture guardrails:
- Dynamic internal tanks introduced: No.
- Shared header inventory introduced: No.
- Global four-bed RHS/DAE introduced: No.
- Core adsorber physics changed: No.
- Solver invoked by WP3 tests: No.

Next smallest recommended task:
- WP4 temporary two-bed/single-step case-builder contract, using WP3 selection/writeback API.
```

Stop and report instead of editing if MATLAB is unavailable or if the source tests fail. The report should be honest about what ran and what did not. “Trust me, it should work” is not a validation strategy; it is a genre of folklore.
