Codex Task 02: Yang WP1 Schedule Manifest

Objective

Implement the WP1 Yang four-bed schedule manifest, metadata, layered-bed capability audit, and static tests.

This task is WP1 only. It does not implement pair identities, runtime direct coupling, persistent state execution, ledgers, CSS, or numerical validation.

Allowed files

Prefer project-specific wrapper locations:

scripts/four_bed/
tests/four_bed/
docs/four_bed/
scripts/run_source_tests.m
scripts/README.md
tests/README.md
docs/KNOWN_UNCERTAINTIES.md only if a real source or workflow ambiguity must be recorded.

Forbidden files

Do not edit toPSAil core folders unless a human task explicitly authorises a narrow exception:

1_config/
2_run/
3_source/
4_example/
5_reference/
6_publication/

Do not edit cases/, params/, validation/manifests/, or validation/reports/ for WP1 unless the task explicitly expands scope.

Required reading before doing anything

Read these files first:

AGENTS.md
docs/CODEX_PROJECT_MAP.md
docs/PROJECT_CHARTER.md
docs/MODEL_SCOPE.md
docs/SOURCE_LEDGER.md
docs/VALIDATION_STRATEGY.md
docs/TEST_POLICY.md
docs/BOUNDARY_CONDITION_POLICY.md
docs/THERMAL_MODEL_POLICY.md
docs/TASK_PROTOCOL.md
docs/KNOWN_UNCERTAINTIES.md
docs/REPORT_POSITIONING.md
docs/GIT_WORKFLOW.md
docs/workflow/four_bed_project_context_file_map.txt
docs/workflow/four_bed_executive_summary.csv
docs/workflow/four_bed_work_packages.csv
docs/workflow/four_bed_architecture_map.csv
docs/workflow/four_bed_test_matrix.csv
docs/workflow/four_bed_issue_register.csv
docs/workflow/four_bed_yang_manifest.csv
docs/workflow/four_bed_stage_gates.csv
docs/workflow/four_bed_evidence_notes.csv
docs/workflow/Work package guidance docs/WP1_yang_schedule_manifest_guidance.md

Source basis

Yang 2009 Table 2 and process-description semantics as routed through docs/workflow/ and docs/SOURCE_LEDGER.md.

Scope

You may:

add a programmatic Yang schedule manifest;
add duration parsing and normalization helpers;
add a label glossary;
add pressure-class metadata;
add a layered-bed support audit;
add static validation functions and tests;
add short WP1 implementation documentation.

You may not:

edit toPSAil core solver or adsorber physics;
implement direct bed-to-bed transfer;
define pair identities;
create dynamic internal tanks or shared header inventory;
assemble a global four-bed RHS/DAE;
implement product/recovery accounting;
implement CSS convergence logic;
add event-based scheduling;
tune valves or numerical parameters;
claim Yang numerical validation.

Required checks

Before editing anything, report:

git status --short
git branch --show-current

Confirm that the Yang PDF is available at:

sources/Yang 2009 4-bed 10-step relevant.pdf

Required implementation

Follow the WP1 guidance document. The manifest must preserve:

four named beds A/B/C/D;
the ten source schedule columns;
raw Yang duration labels;
raw duration units in t_c/24;
normalized displayed-cycle fractions;
operation labels;
operation family and role metadata;
pressure classes;
requires-pair-map flags;
architecture flags;
layered-bed audit result.

Required tests

Add or run tests matching:

T-STATIC-01: Yang manifest integrity.
T-PARAM-01: layered-bed capability is confirmed or explicitly labelled as a surrogate.

Use the smallest available runner. If a script runner exists, run it with:

addpath(genpath(pwd)); run("<runner>");

Stop conditions

Stop if:

the source schedule contradicts the workflow files;
required labels or durations cannot be reconciled;
the implementation would need a core edit;
pair identities appear necessary to complete WP1;
a test threshold would need to be weakened;
MATLAB cannot run a required test.

Final report must include:

files changed;
files inspected;
commands run;
tests passed;
tests failed;
CSV/document contradictions found;
layered-bed audit result;
confirmation that no solver/core physics files were modified;
confirmation that no dynamic tanks, shared headers, or global four-bed RHS were added;
confirmation that no validation numbers changed;
next smallest task.
