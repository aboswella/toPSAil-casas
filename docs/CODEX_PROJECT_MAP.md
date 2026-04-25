# Codex Project Map

## Purpose

This repository is a fork of toPSAil used to develop a MATLAB PSA model for H2/CO2 separation.

The project must proceed in controlled stages:

1. Confirm unmodified toPSAil runs.
2. Add project documentation and source ledgers.
3. Build a Casas-lite breakthrough sanity case.
4. Build a Schell two-bed H2/CO2 PSA validation case.
5. Add Delgado-inspired layered-bed / contaminant-polishing extension if time permits.
6. Add sensitivity analysis.
7. Add optimisation wrappers.

Do not skip stages.

## Source roles

### Casas 2012

Role:
- sanity validation of breakthrough timing, thermal behaviour, and solver health.

Not role:
- exact front-shape reproduction;
- exact detector-piping reproduction;
- reason to rewrite toPSAil boundary conditions.

### Schell 2013

Role:
- primary experimental validation for full-cycle two-bed H2/CO2 PSA behaviour.

Validation targets:
- pressure evolution;
- temperature profiles;
- H2 purity/recovery;
- CO2 purity/recovery where reconstructable;
- CSS convergence;
- physically sensible stream accounting.

### Delgado 2014

Role:
- extension source for layered beds, BPL activated carbon, 13X zeolite, and contaminant polishing.

Not role:
- primary experimental validation source.

Caution:
- Delgado PSA results are simulation-to-simulation reproduction targets, not experimental PSA validation.

## toPSAil policy

Use toPSAil-native machinery wherever possible.

Avoid modifying toPSAil core solver, boundary-condition, and cycle machinery unless a task explicitly authorises it.

Prefer:
- case files;
- wrappers;
- parameter packs;
- validation scripts;
- reports;
- tests.

Avoid:
- silent solver changes;
- hybrid boundary-condition hacks;
- changing validation thresholds;
- tuning parameters to match literature.

## Project folders

### docs/

Human and Codex-facing project instructions.

### cases/

Project-specific case definitions and run scripts.

Expected subfolders:

- cases/casas_lite_breakthrough/
- cases/schell_2bed_validation/
- cases/delgado_layered_extension/

### validation/

Validation manifests, expected targets, and generated reports.

Raw source data and generated reports must be kept separate.

### tests/

Small test suite.

Test tiers:

- smoke;
- source;
- equations;
- sanity;
- validation.

### scripts/

Convenience scripts for running tests and validation.

### .codex/

Codex configuration and reusable prompts.

## Required reading for Codex

Before editing, read:

1. AGENTS.md
2. docs/CODEX_PROJECT_MAP.md
3. docs/TASK_PROTOCOL.md
4. docs/TEST_POLICY.md
5. docs/VALIDATION_STRATEGY.md
6. docs/GIT_WORKFLOW.md
7. relevant case_spec.md

## Default task order

The next task should always be the smallest task that advances the current project stage.

Never combine:
- new physics;
- new metrics;
- new validation thresholds;
- new plotting;
- new optimisation.

## Stop and report if

- a source is ambiguous;
- a required parameter is missing;
- a change would touch toPSAil core internals;
- validation mismatch has multiple plausible causes;
- MATLAB cannot run the test;
- a task would skip a project stage;
- a test threshold would need changing.