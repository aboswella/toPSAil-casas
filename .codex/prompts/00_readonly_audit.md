Task ID:
readonly-yang-branch-audit

Goal:
Audit the toPSAil fork and identify the smallest safe next Yang four-bed task.

Allowed files:
- none; run in read-only mode.

Forbidden files:
- all repository files.

Required reading:
- AGENTS.md
- docs/CODEX_PROJECT_MAP.md
- docs/PROJECT_CHARTER.md
- docs/MODEL_SCOPE.md
- docs/SOURCE_LEDGER.md
- docs/VALIDATION_STRATEGY.md
- docs/TEST_POLICY.md
- docs/BOUNDARY_CONDITION_POLICY.md
- docs/THERMAL_MODEL_POLICY.md
- docs/TASK_PROTOCOL.md
- docs/KNOWN_UNCERTAINTIES.md
- docs/REPORT_POSITIONING.md
- docs/GIT_WORKFLOW.md
- docs/workflow/four_bed_project_context_file_map.txt
- docs/workflow/four_bed_executive_summary.csv
- docs/workflow/four_bed_work_packages.csv
- docs/workflow/four_bed_architecture_map.csv
- docs/workflow/four_bed_test_matrix.csv
- docs/workflow/four_bed_issue_register.csv
- docs/workflow/four_bed_yang_manifest.csv
- docs/workflow/four_bed_stage_gates.csv
- docs/workflow/four_bed_evidence_notes.csv
- docs/workflow/Work package guidance docs/WP1_yang_schedule_manifest_guidance.md

Find:
- whether agent-facing files still route future work toward retired Casas/Schell/Delgado validation tasks;
- whether the available infrastructure preserves the no-tank, no-header, no-global-four-bed-RHS wrapper architecture;
- how to run original toPSAil examples;
- where isotherms are implemented;
- where kinetics are implemented;
- where cycle steps and connections are defined;
- where boundary conditions are implemented;
- where CSS convergence is checked;
- where performance metrics are computed;
- whether layered beds or spatially varying adsorbent properties are natively supported;
- whether existing paired-bed machinery can be invoked through wrapper-level calls.

Return:
1. files inspected;
2. answers to each audit question with file references;
3. whether core edits appear necessary for the next stage;
4. risks and uncertainties;
5. recommended smallest next task.

Do not propose broad rewrites.
Do not edit files.
