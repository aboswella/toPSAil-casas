# Batch 1 implementation guide: schedule finalisation and physical-state persistence cleanup

## Assignment

You are implementing **Batch 1** of the final four-bed toPSAil implementation. This batch covers:

- **FI-1 Schedule finalisation**: make the normalised Yang duration basis the only executable schedule policy.
- **FI-3 Physical state persistence cleanup**: ensure the four persistent bed states store only physical adsorber state, not cumulative boundary-flow counters.

You are working in parallel with another Codex agent implementing **Batch 2**, the H2/CO2 activated-carbon parameter pack. You are not working alone in the codebase. Keep your changes narrow, and do not modify files that belong to Batch 2 unless absolutely unavoidable and explicitly justified in your final handoff.

## Important project reset

The old WP1-WP5 work-package documents are no longer the active implementation instructions. They are legacy artifacts from the previous planning phase. Existing files, tests, comments, and docs may still use names like `WP1`, `WP3`, or `WP5`, but those labels must not determine your scope.

Use this guide and `docs/four_bed/FINAL_IMPLEMENTATION_CONTEXT.md` as the authority. Do not follow older guidance files such as:

- `docs/four_bed/WP Archive/WP1_yang_schedule_manifest.md`
- `docs/four_bed/WP Archive/WP2_direct_transfer_pair_map.md`
- `docs/four_bed/WP Archive/WP3_persistent_four_bed_state_container*.md`
- `docs/four_bed/WP Archive/WP4_temporary_case_builder*.md`
- `docs/four_bed/WP Archive/WP5_ledger_css_reporting*.md`
- `.codex/prompts/05_yang_wp1_schedule_manifest.md`
- `docs/workflow/Work package guidance docs/*`

Do not delete these files just because they are old. Treat them as historical context only. If a test or function name still contains `WP`, that is acceptable. The implementation logic must reflect FI-1 and FI-3.

## Scope boundaries

### You own

Schedule finalisation:

- `scripts/four_bed/getYangFourBedScheduleManifest.m`
- `scripts/four_bed/parseYangDurationLabel.m`
- `scripts/four_bed/validateYangFourBedScheduleManifest.m`
- A new helper, recommended path:
  - `scripts/four_bed/getYangNormalizedSlotDurations.m`
- Existing or new schedule tests under:
  - `tests/four_bed/testYangManifestIntegrity.m`
  - `tests/four_bed/testYangNormalizedSlotDurations.m`, if added

Physical-state persistence cleanup:

- `scripts/four_bed/extractYangTerminalLocalStates.m`
- `scripts/four_bed/extractYangStateVector.m`
- `scripts/four_bed/writeBackYangFourBedStates.m`
- `scripts/four_bed/computeYangFourBedCssResiduals.m`
- `scripts/four_bed/computeYangStateFamilyResiduals.m`
- New helpers, recommended paths:
  - `scripts/four_bed/extractYangPhysicalBedState.m`
  - `scripts/four_bed/extractYangCounterTailDeltas.m`
- Existing or new state/CSS tests under:
  - `tests/four_bed/testYangFourBedStateContainerShape.m`
  - `tests/four_bed/testYangFourBedWritebackOnlyParticipants.m`
  - `tests/four_bed/testYangCssResidualsAllBeds.m`
  - `tests/four_bed/testYangPhysicalStatePersistenceCleanup.m`, if added

### You must not own

Do not implement or materially change:

- `params/yang_h2co2_ac_surrogate/*`
- `cases/yang_h2co2_ac_surrogate/*`
- `params/README.md` except possibly a tiny note if required by repository conventions
- Any Yang H2/CO2 AC parameter builder or DSL point-test script. That is Batch 2.
- Custom PP->PU adapter code.
- Custom AD&PP->BF adapter code.
- Full four-bed cycle driver code.
- Final ledger extraction, audit export, or external-basis performance metrics beyond preserving counter-tail access for later ledger work.
- Core toPSAil adsorber mass, energy, momentum, isotherm, or RHS files.

If you need a `params` struct for tests, build a **synthetic local struct inside the test**. Do not wait for Batch 2 and do not import Batch 2's parameter package.

## Architectural guardrails

These are non-negotiable:

1. No dynamic internal tanks or shared header inventory for Yang internal transfers.
2. No global four-bed RHS/DAE.
3. No rewrite of core toPSAil adsorber physics.
4. The wrapper persists only named bed states: `state_A`, `state_B`, `state_C`, `state_D`.
5. Temporary local bed indices are solver conveniences only. They are not physical identities.
6. Cumulative boundary-flow counters are ledger/accounting data, not physical bed state.
7. CSS residuals must be computed over physical bed states only.

## Part A: FI-1 schedule finalisation

### Background

The Yang Table 2 duration labels are preserved as source metadata, but they must no longer be treated as the executable basis. The displayed source labels correspond to raw units:

```matlab
durationUnits = [1, 6, 1, 4, 1, 1, 4, 1, 1, 5];
```

These raw displayed units sum to 25. The final executable schedule is:

```matlab
durationFractions = durationUnits / 25;
durationSeconds(i) = cycleTimeSec * durationFractions(i);
```

The old raw `t_c/24` interpretation remains metadata only. Raw labels can still be stored for traceability, but no execution path should use `durationUnits / 24` or the old `rawFractionOfTc` to determine step duration.

### Required behaviour

Implement a clear duration helper:

```matlab
schedule = getYangNormalizedSlotDurations(cycleTimeSec)
```

Recommended behaviour:

- `cycleTimeSec` is required, scalar, numeric, finite, and positive.
- The function returns a struct or table with enough metadata for later cycle-driver use.
- At minimum expose:
  - `durationUnits = [1;6;1;4;1;1;4;1;1;5]`
  - `durationFractions = durationUnits / 25`
  - `durationSeconds = cycleTimeSec * durationFractions`
  - `sourceCol = (1:10)'`
  - `durationLabelRaw = ["t_c/24"; "t_c/4"; ...]`
  - `cycleTimeSec`
  - `normalizationPolicy = "executable_fractions_sum_to_one_duration_units_over_25"` or equivalent
- The returned fractions must sum to one within floating point tolerance.
- The returned seconds must sum to `cycleTimeSec` within floating point tolerance.

Recommended shape:

```matlab
function duration = getYangNormalizedSlotDurations(cycleTimeSec)
    arguments
        cycleTimeSec (1,1) double {mustBeFinite, mustBePositive}
    end

    sourceCol = (1:10)';
    durationLabelRaw = [
        "t_c/24"
        "t_c/4"
        "t_c/24"
        "t_c/6"
        "t_c/24"
        "t_c/24"
        "t_c/6"
        "t_c/24"
        "t_c/24"
        "5t_c/24"
    ];
    durationUnits = [1; 6; 1; 4; 1; 1; 4; 1; 1; 5];
    durationFractions = durationUnits ./ sum(durationUnits);
    durationSeconds = cycleTimeSec .* durationFractions;

    duration = struct();
    duration.version = "FI1-Yang2009-normalized-slot-durations-v1";
    duration.cycleTimeSec = cycleTimeSec;
    duration.durationUnits = durationUnits;
    duration.durationFractions = durationFractions;
    duration.durationSeconds = durationSeconds;
    duration.slotTable = table(sourceCol, durationLabelRaw, durationUnits, ...
        durationFractions, durationSeconds);
end
```

That exact implementation is not mandatory, but the contract is.

### Manifest updates

Update `getYangFourBedScheduleManifest.m` so the manifest clearly distinguishes:

- Raw source labels and raw displayed units, retained for traceability.
- Executable normalised fractions, used for simulation.
- The cycle-time mapping policy, now fixed as `cycleTimeSec * durationUnits / 25`.

The current manifest from WP5-era code may contain wording like "later work packages must decide how simulation cycleTimeSec maps to Yang t_c". That is now obsolete. Replace it.

Expected final manifest duration metadata should communicate something like:

```matlab
manifest.duration = struct( ...
    "rawBasis", "Yang Table 2 labels", ...
    "rawUnitLabel", "t_c/24", ...
    "rawUnitsPerDisplayedCycle", 25, ...
    "rawSumFractionOfTc", 25/24, ...       % metadata only
    "executableUnits", [1;6;1;4;1;1;4;1;1;5], ...
    "executableUnitsPerCycle", 25, ...
    "executableFractions", [1;6;1;4;1;1;4;1;1;5] ./ 25, ...
    "normalizationPolicy", "execute_normalized_displayed_cycle_units_over_25", ...
    "cycleTimeMappingPolicy", "durationSeconds = cycleTimeSec * executableFractions" ...
);
```

Use names that fit the repository style. The key is that later agents cannot plausibly read the manifest and revive the old 24-unit execution basis.

### Validation updates

Update `validateYangFourBedScheduleManifest.m` to check:

- There are 10 source columns and 40 bed steps.
- `duration_units_t24` still parses correctly from raw labels.
- Raw units still sum to 25.
- Raw `25/24` remains metadata only, not executable policy.
- Executable fractions exist and sum to one.
- The executable duration policy is explicitly normalised over 25 units.
- No partner identity fields are introduced by FI-1.
- No tank/header/four-bed-RHS fields are introduced.

Update `testYangManifestIntegrity.m` or add `testYangNormalizedSlotDurations.m` so the following assertions are covered:

```matlab
cycleTimeSec = 250;
d = getYangNormalizedSlotDurations(cycleTimeSec);
assert(isequal(d.durationUnits(:), [1;6;1;4;1;1;4;1;1;5]));
assert(abs(sum(d.durationFractions) - 1) < 1e-12);
assert(abs(sum(d.durationSeconds) - cycleTimeSec) < 1e-12);
assert(isequal(d.durationSeconds(:), cycleTimeSec * [1;6;1;4;1;1;4;1;1;5] / 25));
```

Also test invalid cycle times:

- `0`
- negative value
- `NaN`
- non-scalar vector

The exact error IDs are less important than failure being explicit.

## Part B: FI-3 physical-state persistence cleanup

### Background

The native toPSAil adsorber state vector contains:

```matlab
params.nColSt   % physical CSTR state length
params.nColStT  % physical state plus cumulative boundary-flow counters
```

The final implementation basis says persistent named bed states must include only the physical adsorber state:

```matlab
physicalBedState = localStateVector(1:params.nColSt);
counterTail      = localStateVector(params.nColSt+1:params.nColStT);
```

The counter tail is useful for ledgers. It must not be written into `state_A`, `state_B`, `state_C`, or `state_D`.

### Required helpers

Add a helper for physical state slicing:

```matlab
physicalPayload = extractYangPhysicalBedState(params, localStateVector, varargin)
```

Recommended contract:

- Accepts a `params` struct with `nColSt` and `nColStT`.
- Accepts a numeric local state vector or a payload struct containing a vector.
- Returns a payload struct that is safe to persist.
- The persisted vector length must be exactly `params.nColSt`.
- Include metadata showing the source was sliced from a native local state.
- Preserve backwards compatibility by setting both `physicalStateVector` and `stateVector` to the same physical vector, unless you choose a cleaner migration and update all dependent functions accordingly.

Recommended payload:

```matlab
physicalPayload = struct( ...
    "payloadType", "yang_physical_adsorber_state_v1", ...
    "stateVector", physicalVector, ...
    "physicalStateVector", physicalVector, ...
    "metadata", metadataStruct);
```

Add a helper for counter tails:

```matlab
counterReport = extractYangCounterTailDeltas(params, initialLocalStateVector, terminalLocalStateVector, varargin)
```

or, if initial counters are not available in the current call path:

```matlab
counterTail = extractYangCounterTailDeltas(params, terminalLocalStateVector)
```

Recommended contract:

- It must never return something intended to be persisted as bed state.
- It should return a struct or table with `counterTail`, and if possible `counterTailDelta`.
- It should include enough identity fields for later ledger code: local index, global bed, source column, Yang label, pair ID, and direct transfer family if available.
- If both initial and terminal tails are supplied, return `terminalTail - initialTail`.
- If only the terminal tail is supplied, label it clearly as terminal tail, not delta.

Do not build the full ledger here. Do not classify product/recovery here. This helper exists so the later ledger agent can extract accounting data without polluting persistent state.

### Update terminal extraction

Update `extractYangTerminalLocalStates.m`.

Current WP5-era behaviour may call `convert2ColStates(params, termStates, i)` and store the full returned vector as `stateVector`. That full vector is length `nColStT`, which includes cumulative boundary counters. This is the central bug you are fixing.

Required final behaviour:

- Preserve the existing first output as physical-only terminal local states.
- Add an optional second output for counter/accounting data if useful:

```matlab
[terminalLocalStates, counterTailReport] = extractYangTerminalLocalStates(params, stStates, tempCase)
```

- `terminalLocalStates{i}` must contain only physical bed state.
- `counterTailReport` may contain counter tails or deltas for ledger work.
- Do not write counter tails into `terminalLocalStates{i}.stateVector`.

Recommended shape:

```matlab
termStates = convert2TermStates(params, stStates);
for i = 1:tempCase.nLocalBeds
    localStateVector = convert2ColStates(params, termStates, i);
    terminalLocalStates{i} = extractYangPhysicalBedState(params, localStateVector, ...
        'Metadata', makeMetadataFromTempCase(tempCase, i));
    counterTailRows(i) = extractYangCounterTailDeltas(params, localStateVector, ...
        'Metadata', makeMetadataFromTempCase(tempCase, i));
end
```

Do not assume that `nColStT == nColSt`. The whole point of this batch is to handle the case where it is not.

### Update writeback

Update `writeBackYangFourBedStates.m` so it cannot silently persist counter tails.

Recommended behaviour:

- If a terminal payload has `physicalStateVector`, persist only that vector/payload.
- If a terminal payload has a `stateVector` and no `physicalStateVector`, accept it only if it is already physical length or if the caller supplied enough `Params` to slice it.
- Consider adding an optional `'Params'` argument to `writeBackYangFourBedStates` to validate/slice state lengths.
- If a vector is length `params.nColStT`, slice it to `params.nColSt` and warn or report that counters were stripped.
- If a vector has an unexpected length, error.
- Non-participating beds must remain unchanged.

Do not alter the local/global mapping semantics. The existing behaviour that writes `terminalLocalStates{i}` to `selection.localMap.state_field(i)` is correct and must be preserved.

### Update CSS residuals

Update CSS functions so residuals are based only on physical state.

Recommended approach:

- Update `extractYangStateVector.m` to prefer `physicalStateVector` over `stateVector`.
- If only `stateVector` exists and `Params` are supplied, use `params.nColSt` to slice physical state when needed.
- Update `computeYangStateFamilyResiduals.m` so it does not create a CSS family that treats boundary counters as part of convergence evidence.
- It is acceptable to record a diagnostic row saying boundary counters were excluded when legacy payloads contain tails, but that diagnostic must not control pass/fail CSS.

Expected persistent payloads should make this simple: `stateVector` should already be physical-only.

### State payload contract for later batches

By the end of this batch, later agents should be able to rely on this contract:

```matlab
container.state_A
container.state_B
container.state_C
container.state_D
```

Each contains one physical adsorber state payload. No cumulative feed-end/product-end counters are stored as persistent bed state. Valid payloads should support:

```matlab
vec = extractYangStateVector(container.state_A, 'Params', params);
assert(numel(vec) == params.nColSt);
```

If you choose not to change `extractYangStateVector` signature, document exactly how later agents should extract a physical vector. Do not leave it ambiguous.

## Tests to run or update

At minimum, this batch should leave these tests passing:

- `tests/four_bed/testYangManifestIntegrity.m`
- `tests/four_bed/testYangPairMapCompleteness.m`, if affected by manifest fields
- `tests/four_bed/testYangFourBedStateContainerShape.m`
- `tests/four_bed/testYangFourBedWritebackOnlyParticipants.m`
- `tests/four_bed/testYangFourBedCrossedPairRoundTrip.m`, if available
- `tests/four_bed/testYangCssResidualsAllBeds.m`

Add new tests if existing tests cannot cover the final basis cleanly:

- `tests/four_bed/testYangNormalizedSlotDurations.m`
- `tests/four_bed/testYangPhysicalStatePersistenceCleanup.m`

Suggested physical-state cleanup test:

```matlab
params = struct();
params.nComs = 2;
params.nVols = 2;
params.nStates = 2*params.nComs + 2;
params.nColSt = params.nStates * params.nVols;
params.nColStT = params.nColSt + 2*params.nComs;

localFull = (1:params.nColStT)';
payload = extractYangPhysicalBedState(params, localFull);
assert(numel(payload.stateVector) == params.nColSt);
assert(isequal(payload.stateVector, localFull(1:params.nColSt)));

counter = extractYangCounterTailDeltas(params, localFull);
assert(isequal(counter.counterTail(:), localFull(params.nColSt+1:params.nColStT)));
```

Suggested CSS test:

```matlab
initialPayload = struct("stateVector", (1:params.nColStT)');
finalPayload = initialPayload;
finalPayload.stateVector(params.nColSt+1:end) = finalPayload.stateVector(params.nColSt+1:end) + 999;

% CSS should pass if only counters differ, because counters are excluded.
```

The exact test style should match the repository.

## Handoff requirements

At the end of your work, provide a concise handoff containing:

1. Files changed.
2. The final executable duration policy and how to call the helper.
3. The final persistent state payload schema.
4. Whether `extractYangTerminalLocalStates` now has one output or two outputs.
5. How counter tails are exposed for later ledger work.
6. Tests run and their results.
7. Any remaining ambiguity or intentional non-change.

## Acceptance criteria

This batch is complete only if:

- `cycleTimeSec -> durationSeconds` uses `[1,6,1,4,1,1,4,1,1,5] / 25` and no execution path uses the raw 24-unit basis.
- The manifest still preserves raw Yang labels as metadata.
- `state_A/state_B/state_C/state_D` persist only physical bed states.
- Counter tails are extractable for later ledgers but not persisted as bed state.
- CSS residuals use physical state only.
- Non-participating beds remain unchanged during writeback.
- No dynamic tanks, shared header inventory, global four-bed RHS/DAE, or core adsorber-balance edits are introduced.
- No Batch 2 parameter-pack files are modified.
