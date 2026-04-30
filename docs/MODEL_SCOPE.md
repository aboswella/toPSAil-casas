# Model Scope

## Purpose

This project uses toPSAil as the base MATLAB PSA simulator for a Yang 2009 four-bed workflow. The near-term objective is controlled four-bed orchestration, not solver reinvention.

## In Scope

- Confirm unchanged toPSAil examples run.
- Add project-specific wrappers, manifests, cases, parameter packs, ledgers, reports, and tests.
- Build a machine-readable Yang schedule manifest with raw and normalized duration representations.
- Build explicit pair maps for direct transfers.
- Maintain persistent named bed states for `A`, `B`, `C`, and `D`.
- Build temporary toPSAil-compatible single-bed or paired-bed calls.
- Reconstruct external/internal stream ledgers, Yang-basis metrics, and all-bed CSS diagnostics.
- Audit layered-bed and thermal capability before claiming physical fidelity.

## Out Of Scope Unless Explicitly Authorised

- Editing toPSAil solver internals.
- Editing pressure-flow or boundary-condition machinery.
- Creating dynamic internal tanks for Yang internal transfers.
- Creating shared header inventory for Yang internal transfers.
- Assembling a global four-bed RHS/DAE state.
- Adding event-driven scheduling before fixed-duration execution works.
- Running optimization or broad sensitivity studies before the wrapper is stable.

## Default Model Mode

The default model mode is toPSAil-native orchestration:

- native single-bed and paired-bed machinery,
- wrapper-level schedule and pair metadata,
- persistent named bed states outside the core solver,
- explicit external/internal stream ledgers,
- documented thermal and layered-bed assumptions.

## Source Separation

Parameter packs must remain source-specific and traceable. Do not create a generic mixed parameter file by blending values from unrelated papers or exploratory assumptions.

## Core Boundary

The original toPSAil folders are treated as core:

- `1_config/`
- `2_run/`
- `3_source/`
- `4_example/`
- `5_reference/`
- `6_publication/`

Prefer new project files under `cases/`, `params/`, `validation/`, `scripts/`, `tests/`, and `docs/`.
