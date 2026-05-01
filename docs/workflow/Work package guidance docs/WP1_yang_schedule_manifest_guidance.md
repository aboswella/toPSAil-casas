# Legacy WP1 Codex Guidance: Yang Four-Bed Schedule Manifest for toPSAil

Legacy notice: this document is retained for historical context only. The active
final implementation plan is FI-1 through FI-8, routed through
`docs/four_bed/FINAL_IMPLEMENTATION_CONTEXT.md` and the current batch guides.
Do not use this file as active implementation scope unless the user explicitly
asks for legacy WP1 review.

## 0. Purpose of this document

This document is the complete implementation guide for **Work Package 1 (WP1)** of the four-bed toPSAil implementation.

The Codex agent implementing WP1 will have access to:

- the toPSAil repository;
- the project CSV planning files;
- this guidance document.
- the Yang et al. PDF at `sources/Yang 2009 4-bed 10-step relevant.pdf`.

The table containing the information has been given in this document. Confirm it against the local Yang PDF only when the task explicitly asks for source confirmation or when the workflow files are inconsistent.

---

## 1. High-level implementation concept

The four-bed Yang implementation is **not** a new four-bed process-network solver.

It is intended to be a **thin orchestration layer** around existing toPSAil bed-step behaviour.

The eventual four-bed wrapper will maintain four persistent named bed states:

```text
A, B, C, D
```

For each Yang cycle slot, the later wrapper will:

1. determine what each bed is doing;
2. identify whether the operation is a single-bed/external operation or a direct bed-to-bed transfer;
3. call existing toPSAil-style machinery on the relevant named bed state or coupled bed-pair states;
4. write the returned terminal state back to the relevant named bed(s);
5. move to the next slot.

WP1 does **not** implement that runtime wrapper. WP1 only creates the schedule-definition layer that later work packages will use.

---

## 2. Strict architecture constraints

WP1 must preserve the corrected project architecture:

```text
No dynamic internal tanks for Yang bed-to-bed transfers.
No shared header inventory for Yang internal transfers.
No global four-bed RHS or four-bed DAE system.
No rewrite of core adsorber physics.
No event-based scheduling in WP1.
No pair identity inference from Yang table row order.
```

Internal Yang transfers are to be represented later as **direct bed-to-bed couplings**, not as intermediate tank/header interactions.

This means WP1 must produce metadata that makes later direct-coupling implementation possible, but must not implement the coupling itself.

---

## 3. WP1 scope

WP1 is the **Yang schedule manifest** work package.

Its job is to create a small, durable, machine-readable representation of the Yang four-bed cycle.

WP1 deliverables:

1. A programmatic manifest for the Yang four-bed ten-step schedule.
2. A normalized source schedule table.
3. A bed-operation table for beds A/B/C/D.
4. A label glossary for Yang operation labels.
5. Pressure-class metadata.
6. Pair-map-ready metadata, but not the pair map itself.
7. A lightweight layered-bed capability audit/flag.
8. Static validation tests.
9. A short implementation note/doc in the repo.

WP1 non-goals:

```text
Do not edit solver/RHS logic.
Do not implement direct bed-to-bed transfer.
Do not create dynamic tanks or shared headers.
Do not implement a four-bed state vector solve.
Do not implement product/recovery accounting.
Do not implement CSS convergence logic.
Do not implement event-driven Yang steps.
Do not tune valves or numerical parameters.
Do not implement layered-bed physics under WP1.
```

---

## 4. Canonical project CSV files Codex should consult

Codex should consult these CSV files, in this order, before and during implementation:

```text
four_bed_work_packages.csv
four_bed_architecture_map.csv
four_bed_test_matrix.csv
four_bed_issue_register.csv
four_bed_yang_manifest.csv
four_bed_stage_gates.csv
four_bed_evidence_notes.csv
```

Recommended use:

- `four_bed_work_packages.csv`: confirm WP1 scope, deliverables, non-goals, and handoff tests.
- `four_bed_architecture_map.csv`: confirm architectural constraints.
- `four_bed_test_matrix.csv`: confirm WP1 tests, especially T-STATIC-01 and T-PARAM-01.
- `four_bed_issue_register.csv`: check known failure modes before making design choices.
- `four_bed_yang_manifest.csv`: compare against the Yang schedule reproduced below.
- `four_bed_stage_gates.csv`: confirm Stage Gate 1 completion criteria.
- `four_bed_evidence_notes.csv`: use only to support or challenge assumptions.

Do not treat the CSV files as infallible. If a contradiction appears, report it clearly.

---

## 5. Yang four-bed schedule to encode

The Yang four-bed process uses four named beds and ten source schedule columns.

Encode this schedule exactly.

| Source column | Duration label | Duration units in `t_c/24` | Bed A | Bed B | Bed C | Bed D |
|---:|---:|---:|---|---|---|---|
| 1 | `t_c/24` | 1 | AD | EQI-PR | BD | EQI-BD |
| 2 | `t_c/4` | 6 | AD&PP | BF | PU | PP |
| 3 | `t_c/24` | 1 | EQI-BD | AD | EQII-PR | EQII-BD |
| 4 | `t_c/6` | 4 | PP | AD&PP | EQI-PR | BD |
| 5 | `t_c/24` | 1 | EQII-BD | EQI-BD | BF | PU |
| 6 | `t_c/24` | 1 | BD | PP | AD | EQII-PR |
| 7 | `t_c/6` | 4 | PU | EQII-BD | AD&PP | EQI-PR |
| 8 | `t_c/24` | 1 | EQII-PR | BD | EQI-BD | BF |
| 9 | `t_c/24` | 1 | EQI-PR | PU | PP | AD |
| 10 | `5t_c/24` | 5 | BF | EQII-PR | EQII-BD | AD&PP |

The per-bed sequences implied by this table are:

| Bed | Expected ten-step sequence |
|---|---|
| A | AD, AD&PP, EQI-BD, PP, EQII-BD, BD, PU, EQII-PR, EQI-PR, BF |
| B | EQI-PR, BF, AD, AD&PP, EQI-BD, PP, EQII-BD, BD, PU, EQII-PR |
| C | BD, PU, EQII-PR, EQI-PR, BF, AD, AD&PP, EQI-BD, PP, EQII-BD |
| D | EQI-BD, PP, EQII-BD, BD, PU, EQII-PR, EQI-PR, BF, AD, AD&PP |

---

## 6. Duration handling

The Yang source duration labels are to be preserved exactly.

Use these raw duration units:

```matlab
duration_units_t24 = [1; 6; 1; 4; 1; 1; 4; 1; 1; 5];
```

These sum to:

```matlab
sum(duration_units_t24) = 25
```

Therefore the displayed source schedule spans `25 * t_c / 24`, not exactly `t_c` if interpreted literally.

Do **not** silently "fix" this.

The manifest must expose both:

1. the raw Yang duration interpretation; and
2. a normalized displayed-cycle fraction.

Use:

```matlab
raw_fraction_of_tc = duration_units_t24 ./ 24;
normalized_fraction_of_displayed_cycle = duration_units_t24 ./ sum(duration_units_t24);
```

Use raw start/end units:

```matlab
raw_start_units_t24 = [0; 1; 7; 8; 12; 13; 14; 18; 19; 20];
raw_end_units_t24   = [1; 7; 8; 12; 13; 14; 18; 19; 20; 25];
```

Use normalized start/end positions:

```matlab
normalized_start = raw_start_units_t24 ./ sum(duration_units_t24);
normalized_end   = raw_end_units_t24   ./ sum(duration_units_t24);
```

The documentation should state that later work packages must decide how simulation `cycleTimeSec` maps to Yang's `t_c`. WP1 only preserves and normalizes the source schedule.

---

## 7. Suggested repository files to add

Use the branch-wide core boundary from `AGENTS.md` and `docs/MODEL_SCOPE.md`.
The original toPSAil folders, including `3_source/`, are treated as core unless a
specific task explicitly authorizes a narrow exception. WP1 should therefore
prefer project-specific folders such as:

```text
scripts/four_bed/
  getYangFourBedScheduleManifest.m
  validateYangFourBedScheduleManifest.m
  parseYangDurationLabel.m
  getYangLabelGlossary.m
  getYangPressureClassMap.m
  auditYangLayeredBedSupport.m

tests/four_bed/
  testYangManifestIntegrity.m
  testYangLayeredBedCapability.m

docs/four_bed/
  WP1_yang_schedule_manifest.md
```

If the active branch already has a non-core four-bed helper location, use the
nearest existing equivalent. Do not create duplicate parallel systems if a
four-bed schedule folder already exists.

Do not modify core solver/model files.

---

## 8. Manifest top-level schema

Implement:

```matlab
manifest = getYangFourBedScheduleManifest();
```

Suggested top-level structure:

```matlab
manifest = struct();

manifest.version = "WP1-Yang2009-Table2-v1";
manifest.sourceName = "Yang et al. 2009 Table 2";
manifest.bedLabels = ["A","B","C","D"];

manifest.architecture = struct( ...
    "noDynamicInternalTanks", true, ...
    "noSharedHeaderInventory", true, ...
    "noFourBedRhsDae", true, ...
    "noCoreAdsorberPhysicsRewrite", true, ...
    "pairingPolicy", "explicit_pair_map_required_no_row_order_inference", ...
    "eventPolicy", "fixed_duration_only" ...
);

manifest.duration = struct( ...
    "rawBasis", "Yang Table 2 labels", ...
    "unitLabel", "t_c/24", ...
    "rawUnitsPerDisplayedCycle", 25, ...
    "rawSumFractionOfTc", 25/24, ...
    "normalizationPolicy", "preserve raw labels; expose normalized fractions; do not silently rescale source labels" ...
);

manifest.sourceColumns = table(...);  % 10 rows
manifest.bedSteps = table(...);       % 40 rows
manifest.labelGlossary = table(...);  % Yang operation labels
manifest.pressureClasses = table(...);
manifest.layeredBedAudit = struct(...);
```

Keep the manifest self-contained. It should not require Excel, GUI interaction, solver execution, or literature-file access.

---

## 9. `sourceColumns` table schema

`manifest.sourceColumns` must have exactly ten rows.

Required columns:

```text
source_col
duration_label_raw
duration_units_t24
raw_fraction_of_tc
normalized_fraction_of_displayed_cycle
raw_start_units_t24
raw_end_units_t24
normalized_start
normalized_end
bed_A_label
bed_B_label
bed_C_label
bed_D_label
source_note
```

Each row corresponds to one source schedule column from the table in section 5.

---

## 10. `bedSteps` table schema

`manifest.bedSteps` must have exactly forty rows:

```text
4 beds x 10 source columns = 40 rows
```

Required columns:

```text
record_id
bed
source_col
bed_step_index
yang_label
duration_label_raw
duration_units_t24
raw_fraction_of_tc
normalized_fraction_of_displayed_cycle
raw_start_units_t24
raw_end_units_t24
operation_family
role_class
pressure_mode
p_start_class
p_end_class
is_compound
requires_pair_map
direct_transfer_family
external_feed
external_product
external_waste
internal_transfer_category
source_step_letter
source_step_name
notes
```

`bed_step_index` is the sequence index for each named bed, ordered by source column.

For example, Bed A should have:

```text
bed_step_index 1: AD
bed_step_index 2: AD&PP
bed_step_index 3: EQI-BD
...
bed_step_index 10: BF
```

---

## 11. Yang label glossary

Implement:

```matlab
glossary = getYangLabelGlossary();
```

The glossary should be the canonical source of operation semantics.

Use at least these labels and meanings:

| Yang label | Source step letter | Source step name | Meaning | Role class | Pressure transition | Requires pair map? | Compound? |
|---|---|---|---|---|---|---|---|
| AD | a | Adsorption | Feed gas enters at adsorption pressure and H2-rich product exits product end | external_single | `PF -> PF` | false | false |
| AD&PP | b | Adsorption and provide pressurization | Adsorption continues; part of product gas is used to pressurize companion bed undergoing BF | compound_donor | `PF -> PF` | true | true |
| EQI-BD | c | First pressure equalization, blowdown side | Cocurrent depressurization to first intermediate pressure; gas goes to another bed undergoing EQI-PR | donor | `PF -> P1` | true | false |
| PP | d | Provide purge | Cocurrent depressurization to provide purge gas to another bed undergoing PU/PG | donor | `P1 -> P2` | true | false |
| EQII-BD | e | Second pressure equalization, blowdown side | Further cocurrent depressurization; gas goes to another bed undergoing EQII-PR | donor | `P2 -> P3` | true | false |
| BD | f | Blowdown | Countercurrent depressurization to lowest pressure; waste outlet | external_waste_single | `P3 -> P4` | false | false |
| PU | g | Purge | Countercurrent purge using gas from a PP donor bed; waste exits | receiver_with_external_waste | `P4 -> P4` | true | false |
| EQII-PR | h | Second pressure equalization, pressurization side | Pressurization from low pressure using EQII-BD donor gas | receiver | `P4 -> P5` | true | false |
| EQI-PR | i | First pressure equalization, pressurization side | Further pressurization using EQI-BD donor gas | receiver | `P5 -> P6` | true | false |
| BF | j | Backfill | Final pressurization using gas from a bed undergoing AD&PP | receiver | `P6 -> PF` | true | false |

Notes:

- `PU` is the label in the schedule table. Yang's prose may also refer to purge as `PG`. Preserve `PU` in the manifest and optionally note the alias.
- `AD&PP` is a compound operation. It must not be collapsed into ordinary `AD`.
- `EQI` and `EQII` must remain distinct.
- `PP` means provide-purge, not product pressurization in a generic sense.

Suggested glossary fields:

```text
yang_label
source_step_letter
source_step_name
operation_family
role_class
pressure_mode
p_start_class
p_end_class
is_compound
requires_pair_map
direct_transfer_family
external_feed
external_product
external_waste
internal_transfer_category
alias
notes
```

---

## 12. Pressure-class metadata

Implement:

```matlab
pressureClasses = getYangPressureClassMap();
```

Use symbolic pressure classes. WP1 must not invent missing numeric pressures.

| Pressure class | Meaning |
|---|---|
| PF | adsorption/feed pressure |
| P1 | first equalization donor terminal pressure |
| P2 | provide-purge donor terminal pressure |
| P3 | second equalization donor terminal pressure |
| P4 | lowest purge/blowdown pressure |
| P5 | second equalization receiver terminal pressure |
| P6 | first equalization receiver terminal pressure |

Known numeric anchors from Yang may be stored separately:

```matlab
pressureKnown = table( ...
    ["PF"; "P4"], ...
    [9.0; 1.3], ...
    ["atm"; "atm"], ...
    ["Yang experimental operating condition"; "Yang experimental operating condition"], ...
    'VariableNames', ["class","value","unit","basis"] ...
);
```

Do not assign numeric values to `P1`, `P2`, `P3`, `P5`, or `P6` under WP1.

---

## 13. Pair-map-ready metadata

WP1 must not define pair identities.

However, every bed-step row should contain enough metadata for WP2 to build an explicit pair map.

Use `direct_transfer_family` values:

```text
none
EQI
EQII
PP_PU
ADPP_BF
```

Map labels as follows:

| Yang label | direct_transfer_family | role_class |
|---|---|---|
| AD | none | external_single |
| AD&PP | ADPP_BF | compound_donor |
| EQI-BD | EQI | donor |
| PP | PP_PU | donor |
| EQII-BD | EQII | donor |
| BD | none | external_waste_single |
| PU | PP_PU | receiver_with_external_waste |
| EQII-PR | EQII | receiver |
| EQI-PR | EQI | receiver |
| BF | ADPP_BF | receiver |

Use `requires_pair_map = true` for:

```text
AD&PP
EQI-BD
PP
EQII-BD
PU
EQII-PR
EQI-PR
BF
```

Use `requires_pair_map = false` for:

```text
AD
BD
```

WP1 should not include fields such as `partner_bed`, `paired_with`, `donor_bed`, or `receiver_bed`, unless they are explicitly empty and documented as WP2-owned. The safest option is not to include partner identity fields at all.

---

## 14. External/internal stream flags

Each bed-step row should contain simple boolean flags:

```text
external_feed
external_product
external_waste
```

Suggested values:

| Label | external_feed | external_product | external_waste |
|---|---:|---:|---:|
| AD | true | true | false |
| AD&PP | true | true | false |
| EQI-BD | false | false | false |
| PP | false | false | false |
| EQII-BD | false | false | false |
| BD | false | false | true |
| PU | false | false | true |
| EQII-PR | false | false | false |
| EQI-PR | false | false | false |
| BF | false | false | false |

Important: internal transfer gas is not external product. Later metrics must distinguish material that leaves the process from material transferred internally between beds.

---

## 15. Layered-bed audit

Yang uses layered beds of activated carbon and zeolite 5A.

WP1 should not implement layered-bed physics, but it should include a lightweight audit/flag so later agents cannot accidentally claim a physically faithful Yang reproduction if the implementation is actually homogeneous.

Implement:

```matlab
audit = auditYangLayeredBedSupport();
```

Suggested return structure:

```matlab
audit = struct();
audit.testId = "T-PARAM-01";
audit.yangRequiresLayeredBed = true;
audit.layers = table( ...
    ["activated_carbon"; "zeolite_5A"], ...
    [100; 70], ...
    ["cm"; "cm"], ...
    'VariableNames', ["material","height","unit"] ...
);

audit.toPSAilLayeredSupportStatus = "unknown";
audit.result = "not_confirmed_homogeneous_surrogate_required";
audit.notes = [
    "WP1 does not modify adsorber physics."
    "If layered axial material assignment is not confirmed by a later work package, Yang comparison must be labelled as a homogeneous surrogate."
];
```

Codex may inspect the repo to see whether layered axial adsorbent/material assignment already exists. If it can confirm support cleanly, it may return:

```matlab
audit.toPSAilLayeredSupportStatus = "confirmed";
audit.result = "confirmed";
```

But Codex must not add layered-bed physics under WP1.

---

## 16. Duration parser

Implement:

```matlab
units = parseYangDurationLabel(label)
```

It only needs to support the labels used here:

```text
t_c/24   -> 1
t_c/4    -> 6
t_c/6    -> 4
5t_c/24  -> 5
```

It should fail loudly on unknown labels.

Suggested behavior:

```matlab
assert(parseYangDurationLabel("t_c/24") == 1);
assert(parseYangDurationLabel("t_c/4") == 6);
assert(parseYangDurationLabel("t_c/6") == 4);
assert(parseYangDurationLabel("5t_c/24") == 5);
```

Do not build a symbolic algebra parser unless the repo already has one. WP1 needs reliability, not a tiny computer-algebra vanity project.

---

## 17. Validation function

Implement:

```matlab
result = validateYangFourBedScheduleManifest(manifest);
```

It should return a struct:

```matlab
result = struct();
result.pass = true;
result.failures = strings(0,1);
result.warnings = strings(0,1);
result.checks = table(...);
```

Validation should not merely print output. Tests should fail based on `result.pass`.

Required checks:

1. `manifest.version` exists and is nonempty.
2. `manifest.sourceName` exists and is nonempty.
3. `manifest.bedLabels` is exactly `A, B, C, D`.
4. `manifest.sourceColumns` has exactly 10 rows.
5. `manifest.bedSteps` has exactly 40 rows.
6. Every source column has labels for all four beds.
7. Every bed has exactly ten `bed_step_index` values.
8. Each bed sequence matches the expected sequence in section 5.
9. Every `yang_label` appears in `labelGlossary`.
10. Every label has nonempty `pressure_mode`, `p_start_class`, and `p_end_class`.
11. Every duration label parses to the expected `duration_units_t24` value.
12. Raw duration units sum to 25.
13. `manifest.duration.rawUnitsPerDisplayedCycle == 25`.
14. `manifest.duration.rawSumFractionOfTc == 25/24`.
15. Normalized source-column fractions sum to 1 within tolerance.
16. No pair partner identity is assigned in WP1.
17. Every internal/direct-transfer operation has `requires_pair_map = true`.
18. `AD&PP` is marked `is_compound = true`.
19. `EQI` and `EQII` remain distinct in `direct_transfer_family`.
20. Architecture flags are present and true.
21. No dynamic internal tank/header state is represented anywhere in the manifest.

---

## 18. Test: `testYangManifestIntegrity.m`

Create a lightweight static test.

Suggested skeleton:

```matlab
function testYangManifestIntegrity()
    manifest = getYangFourBedScheduleManifest();
    result = validateYangFourBedScheduleManifest(manifest);

    if ~result.pass
        disp(result.failures);
        error("T-STATIC-01 failed: Yang manifest integrity check failed.");
    end

    fprintf("T-STATIC-01 passed: Yang manifest integrity.\n");
end
```

Add explicit assertions for high-risk details:

```matlab
assert(height(manifest.sourceColumns) == 10);
assert(height(manifest.bedSteps) == 40);
assert(all(ismember(["A","B","C","D"], manifest.bedLabels)));

adpp = manifest.labelGlossary(manifest.labelGlossary.yang_label == "AD&PP", :);
assert(height(adpp) == 1);
assert(adpp.is_compound == true);
assert(adpp.requires_pair_map == true);

eqiRows  = manifest.bedSteps(manifest.bedSteps.direct_transfer_family == "EQI", :);
eqiiRows = manifest.bedSteps(manifest.bedSteps.direct_transfer_family == "EQII", :);
assert(~isempty(eqiRows));
assert(~isempty(eqiiRows));

assert(manifest.duration.rawUnitsPerDisplayedCycle == 25);
assert(abs(sum(manifest.sourceColumns.normalized_fraction_of_displayed_cycle) - 1) < 1e-12);
```

This test corresponds to T-STATIC-01 in the project test matrix.

---

## 19. Test: `testYangLayeredBedCapability.m`

Create a static/audit test.

Suggested skeleton:

```matlab
function testYangLayeredBedCapability()
    manifest = getYangFourBedScheduleManifest();
    audit = auditYangLayeredBedSupport();

    allowed = ["confirmed", "not_confirmed_homogeneous_surrogate_required"];
    assert(ismember(audit.result, allowed));

    if audit.result == "not_confirmed_homogeneous_surrogate_required"
        assert(isfield(manifest.layeredBedAudit, "result"));
        assert(manifest.layeredBedAudit.result == audit.result);
    end

    fprintf("T-PARAM-01 passed: layered-bed capability is confirmed or explicitly labelled as surrogate.\n");
end
```

This test corresponds to T-PARAM-01 in the project test matrix.

---

## 20. Documentation to add in the repo

Add:

```text
docs/four_bed/WP1_yang_schedule_manifest.md
```

It should include:

```text
Purpose
Source schedule table
Architecture assumptions
Duration normalization policy
Label glossary
Pressure classes
Layered-bed caveat
Validation tests
Handoff to WP2
```

It must explicitly state:

```text
WP1 does not define pair identities.
WP1 does not create dynamic tanks or shared header inventory.
WP1 does not alter core adsorber physics.
WP1 does not implement event-based termination.
AD&PP is a compound operation.
EQI and EQII are distinct metadata families.
PU is the Yang schedule-table purge label; PG may appear as a prose alias.
Raw displayed duration units sum to 25 units of t_c/24; normalized displayed-cycle fractions are stored separately.
```

---

## 21. What Codex must not do

Do not:

1. Add a dynamic tank or header for Yang internal transfers.
2. Build a global `[state_A, state_B, state_C, state_D]` RHS.
3. Modify adsorption, energy, momentum, or valve-flow equations.
4. Infer pairings from source table row order.
5. Infer pairings from bed adjacency.
6. Infer pairings from native two-bed assumptions.
7. Collapse `EQI` and `EQII` into one category.
8. Treat `AD&PP` as ordinary `AD`.
9. Treat `PP` as generic product pressurization.
10. Treat internal transfer gas as external product.
11. Add event-based scheduling.
12. Tune valves.
13. Claim Yang validation merely because the manifest exists.
14. Quietly rescale duration labels without recording raw and normalized values.
15. Implement layered-bed physics under WP1.

---

## 22. Handoff to WP2

At WP1 completion, WP2 should be able to consume:

```text
manifest.sourceColumns
manifest.bedSteps
manifest.labelGlossary
manifest.pressureClasses
manifest.duration
manifest.architecture
manifest.layeredBedAudit
```

WP2 should then search `manifest.bedSteps` for:

```matlab
manifest.bedSteps.requires_pair_map == true
```

and build explicit pair identities using:

```text
bed
source_col
yang_label
role_class
direct_transfer_family
p_start_class
p_end_class
```

WP1 should make every direct-transfer role unambiguous, but should not assign partner bed identities. Pair identity completeness belongs to WP2.

---

## 23. WP1 acceptance criteria

WP1 is complete when all of the following are true:

```text
1. getYangFourBedScheduleManifest() returns a manifest struct without Excel, GUI, solver execution, or literature-file access.
2. validateYangFourBedScheduleManifest() returns pass = true.
3. testYangManifestIntegrity.m passes.
4. auditYangLayeredBedSupport() returns either confirmed or not_confirmed_homogeneous_surrogate_required.
5. testYangLayeredBedCapability.m passes.
6. The manifest contains no dynamic internal tank/header state.
7. No core adsorber physics files are modified.
8. AD&PP is compound.
9. EQI and EQII remain distinct.
10. Raw and normalized duration representations are both present.
11. Documentation exists and states the assumptions and caveats plainly.
12. Any contradiction with the CSV planning files is reported clearly.
```

---

## 24. Suggested final Codex report

At completion, Codex should report:

```text
Files added/modified
Tests run
Test outputs
Any CSV/document contradictions found
Layered-bed audit result
Confirmation that no solver/core physics files were modified
Confirmation that no dynamic tanks/shared headers/global four-bed RHS were added
```

Do not include claims of Yang numerical validation. WP1 is only the schedule manifest. The machine-readable table existing correctly is progress, not a Nobel prize.
