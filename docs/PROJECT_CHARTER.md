# Project Charter

## Aim

Develop a MATLAB four-bed PSA workflow based on toPSAil for the Yang 2009 ten-step cycle.

The immediate objective is a thin orchestration layer that reuses existing toPSAil bed-step machinery while maintaining four persistent named bed states.

## Base Design Assumption

The four-bed implementation is wrapper-level:

- persistent bed states are named `A`, `B`, `C`, and `D`;
- internal transfers are direct bed-to-bed couplings;
- existing toPSAil single-bed or paired-bed behaviour remains the numerical engine;
- external/internal stream accounting is reconstructed outside the core solver.

## Primary Literature Source

Yang 2009 Table 2 and process description define the four-bed schedule, operation labels, and duration labels for this branch.

## Canonical Planning Source

The canonical implementation planning files are under `docs/workflow/`.

Start with `docs/workflow/four_bed_project_context_file_map.txt`, then use the work-package, architecture, manifest, issue-register, test-matrix, stage-gate, and evidence CSVs as task-specific control files.

## Out Of Scope Unless Explicitly Authorised

- Dynamic internal tanks for Yang internal transfers.
- Shared header inventory for Yang internal transfers.
- A global four-bed RHS/DAE solve.
- Rewriting toPSAil adsorber physics, pressure-flow logic, or boundary-condition internals.
- Event-based Yang scheduling before the fixed-duration direct-coupling path passes its gates.
- Optimization or generalized PFD work before the wrapper path is stable.
