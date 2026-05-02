# Source Ledger

## Ledger Policy

This ledger records branch-relevant source roles and local artifact status. It
does not resolve missing or ambiguous parameters. Unresolved source, modelling,
and workflow issues belong in `docs/KNOWN_UNCERTAINTIES.md`.

## Final Implementation Context

Role:

- active project routing source for remaining four-bed work;
- source of the final H2/CO2 homogeneous activated-carbon surrogate target;
- source of FI-1 through FI-8 and Batch 1 through Batch 6 implementation scope;
- source of the current state, adapter, ledger, pressure-diagnostic, and
  commissioning contracts.

Primary files:

- `docs/four_bed/README.md`
- `docs/four_bed/FINAL_IMPLEMENTATION_CONTEXT.md`
- current batch guides under `docs/four_bed/`

Policy:

- use these files before legacy workflow files for active implementation scope;
- treat conflicts with old WP1-WP5 documents as contradictions to report, not
  invitations to revive the old plan.

## Yang 2009

Role:

- four-bed ten-step PSA schedule source;
- operation-label and duration-label source;
- process-semantics source for `AD`, `AD&PP`, `EQI-BD`, `PP`, `EQII-BD`, `BD`,
  `PU`, `EQII-PR`, `EQI-PR`, and `BF`;
- physical-model caveat source for layered beds, thermal behaviour, and later
  validation positioning.

Use:

- Table 2 schedule labels and duration labels;
- process-description semantics for direct-transfer families;
- pressure anchors only where explicitly stated by the source or current final
  context.

Active narrowing:

- final implementation uses H2/CO2 only, renormalized from the Yang feed;
- final implementation uses a homogeneous activated-carbon-only surrogate;
- raw Yang schedule labels remain metadata while executable durations are
  normalized over 25 displayed units.

Not used for:

- permission to rewrite toPSAil core physics;
- implicit bed-pair inference from table row order;
- dynamic internal tank or shared-header modelling;
- adding zeolite 5A, CO, CH4, pseudo-components, or layered-bed behaviour to the
  first final implementation;
- unlabelled validation claims before wrapper correctness, ledgers, and model
  limitations are documented.

Local artifact status:

- `sources/Yang 2009 4-bed 10-step relevant.pdf` is present locally.

## Legacy Workflow Planning Files

Role:

- historical branch planning source for old WP1-WP5 scope, architecture
  constraints, test mapping, stage gates, issue register, and evidence notes;
- useful source provenance and risk cross-checking context.

Primary files:

- `docs/workflow/four_bed_project_context_file_map.txt`
- `docs/workflow/four_bed_executive_summary.csv`
- `docs/workflow/four_bed_work_packages.csv`
- `docs/workflow/four_bed_architecture_map.csv`
- `docs/workflow/four_bed_issue_register.csv`
- `docs/workflow/four_bed_test_matrix.csv`
- `docs/workflow/four_bed_yang_manifest.csv`
- `docs/workflow/four_bed_stage_gates.csv`
- `docs/workflow/four_bed_evidence_notes.csv`
- `docs/workflow/Work package guidance docs/WP1_yang_schedule_manifest_guidance.md`

Policy:

- treat these files as legacy planning inputs;
- use them to explain old test IDs, old issue IDs, and architecture rationale;
- do not use them as the active implementation sequence;
- report contradictions instead of silently choosing the convenient
  interpretation.

## toPSAil

Role:

- base MATLAB PSA simulator and numerical engine;
- source of existing single-bed and paired-bed behaviour;
- regression target when adding wrapper-level functionality.

Use:

- native pressure-flow, boundary-condition, cycle, and auxiliary-unit machinery
  wherever practical;
- original examples for Tier 0 smoke/regression checks;
- project wrappers and adapters to adapt Yang schedule/state orchestration around
  existing behaviour.

Not used for:

- assuming four persistent beds are already supported by the GUI or existing
  examples;
- bypassing wrapper ledgers for final external/internal metric reconstruction.

## Yang H2/CO2 AC q_m Loading Basis

Role:

- activated-carbon DSL saturation capacities for the active H2/CO2
  homogeneous surrogate.

Policy:

- retain the Yang source-table `q_m` numbers as metadata;
- convert those source-table values to active runtime `mol/kg` capacities with
  a `1000x` loading-capacity factor;
- keep this as a parameter-pack correction, not a tuned validation constant.

Current active runtime values in component order `[H2; CO2]`:

- site 1: `[2.40e-2; 8.00] mol/kg`;
- site 2: `[4.80e-1; 1.40] mol/kg`.
