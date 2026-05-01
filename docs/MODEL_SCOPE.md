# Model Scope

## Purpose

This project uses toPSAil as the base MATLAB PSA simulator for a Yang-inspired
four-bed workflow. The active target is a controlled H2/CO2 homogeneous
activated-carbon surrogate, not solver reinvention and not a full Yang layered
four-component reproduction.

## In Scope

- Confirm unchanged toPSAil examples still run.
- Add project-specific wrappers, manifests, cases, parameter packs, adapters,
  ledgers, reports, and tests.
- Execute normalized Yang displayed-column durations using
  `[1, 6, 1, 4, 1, 1, 4, 1, 1, 5] / 25`.
- Preserve raw Yang labels and duration labels as metadata.
- Use component order `[H2; CO2]` and binary-renormalized feed composition.
- Use a homogeneous activated-carbon-only surrogate as the default final basis.
- Maintain persistent named bed states for `A`, `B`, `C`, and `D`.
- Persist physical adsorber state only; separate cumulative counter tails for
  ledger extraction.
- Build temporary toPSAil-compatible single-bed or paired-bed calls where native
  behaviour is suitable.
- Add wrapper-level direct-coupling adapters for PP->PU and AD&PP->BF.
- Reconstruct external/internal stream ledgers, H2/CO2 external-basis metrics,
  pressure diagnostics, adapter audit records, and all-bed CSS diagnostics.

## Out Of Scope Unless Explicitly Authorised

- Editing toPSAil solver internals.
- Editing pressure-flow or boundary-condition machinery except for a narrow,
  documented interface hook if wrapper adapters cannot otherwise run.
- Creating dynamic internal tanks for Yang internal transfers.
- Creating shared header inventory for Yang internal transfers.
- Assembling a global four-bed RHS/DAE state.
- Adding zeolite 5A, layered-bed behaviour, CO, CH4, or pseudo-impurity
  components to the first final implementation.
- Adding event-driven scheduling before fixed-duration execution works.
- Running optimization or broad sensitivity studies before the wrapper is stable.

## Default Model Mode

The default model mode is toPSAil-native orchestration with wrapper adapters:

- native single-bed and paired-bed machinery where suitable;
- custom direct-coupling adapters for PP->PU and AD&PP->BF;
- wrapper-level schedule, pair metadata, pressure diagnostics, and ledgers;
- persistent named bed states outside the core solver;
- documented H2/CO2 renormalization, activated-carbon-only basis, thermal mode,
  and homogeneous surrogate assumptions.

## Source Separation

Parameter packs must remain source-specific and traceable. Do not create a
generic mixed parameter file by blending values from unrelated papers or
exploratory assumptions.

## Core Boundary

The original toPSAil folders are treated as core:

- `1_config/`
- `2_run/`
- `3_source/`
- `4_example/`
- `5_reference/`
- `6_publication/`

Prefer new project files under `cases/`, `params/`, `validation/`, `scripts/`,
`tests/`, and `docs/`.
