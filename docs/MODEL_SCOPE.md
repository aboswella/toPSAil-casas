# Model Scope

## Purpose

This project uses toPSAil as the base MATLAB PSA simulator for H2/CO2 separation studies. The near-term objective is validation discipline, not solver reinvention.

## In scope

- Confirm unchanged toPSAil examples run.
- Add project-specific wrappers, cases, parameter packs, validation manifests, reports, and tests.
- Build a Casas-lite breakthrough sanity case.
- Build a Schell two-bed H2/CO2 PSA validation case.
- Add a Delgado-inspired layered-bed or contaminant-polishing extension only after the baseline and Schell path are stable.
- Add sensitivity and optimisation wrappers only after validation cases are stable.

## Out of scope unless explicitly authorised

- Editing toPSAil solver internals.
- Editing pressure-flow or boundary-condition machinery.
- Reproducing Casas detector piping or exact axial-dispersion front shape.
- Forcing Schell boundary conditions into the default toPSAil-native model.
- Designing an upstream SMR pretreatment train.
- Running full optimisation as part of smoke or default validation.

## Default model mode

The default model mode is toPSAil-native:

- native pressure-flow handling,
- native boundary-condition handling,
- native cycle/equalisation/auxiliary-unit machinery,
- project-specific case and parameter inputs around that machinery.

A separate Schell-reproduction mode may be added later only if a documented validation failure justifies it. Such a mode must be labelled separately and must not replace the default mode.

## Source separation

Parameter packs must remain source-specific:

- `params/casas2012_ap360_sips_binary/`
- `params/schell2013_ap360_sips_binary/`
- `params/delgado2014_bpl13x_lf_four_component/`

Do not blend AP3-60, BPL, 13X, Sips, Langmuir-Freundlich, Schell heat-transfer assumptions, or Delgado kinetics into one default parameter file.

## Core boundary

The original toPSAil folders are treated as core:

- `1_config/`
- `2_run/`
- `3_source/`
- `4_example/`
- `5_reference/`
- `6_publication/`

Prefer new project files under `cases/`, `params/`, `validation/`, `scripts/`, and `tests/`.
