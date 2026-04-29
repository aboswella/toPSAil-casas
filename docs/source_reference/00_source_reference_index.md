# Source Reference Pack for Codex Tasks

## Purpose

These files are the literature-derived parameter and configuration sheets for the staged toPSAil development workflow. They are intended to let Codex retrieve source facts from Markdown files rather than repeatedly searching the original PDFs.

Codex should treat these files as the first source of truth for project-specific parameters. The original source PDFs should only be opened when:

1. a value in these files is internally inconsistent;
2. a required value is absent and the task explicitly permits source lookup;
3. a task is specifically about auditing or correcting this reference pack.

This is not a substitute for engineering judgement. It is a substitute for sending an agent into a PDF minefield and hoping it comes back with the right column radius. Humanity has chosen worse processes, but not many.

## Files in this pack

| File | Workflow stage | Main use |
|---|---:|---|
| `01_casas_2012_breakthrough_validation.md` | 2 | Casas-lite AP3-60 CO2/H2 fixed-bed breakthrough sanity case. |
| `02_schell_2013_two_bed_psa_validation.md` | 3 | Schell AP3-60 two-bed H2/CO2 PSA experimental validation. |
| `03_delgado_2014_layered_bed_extension.md` | 4 | Delgado BPL + 13X layered-bed H2 purification extension and simulation reproduction. |
| `04_casas_thesis_sensitivity_optimisation.md` | 5-6 | Casas thesis parametric study, sensitivity, scheduling, CSS, and optimisation context. |
| `05_transcription_audit_and_guardrails.md` | all | Cross-check record, unresolved issues, and non-negotiable guardrails. |

## Workflow ordering

Use the reference sheets in this order:

1. Baseline toPSAil example run: no literature parameter pack required.
2. Casas-lite breakthrough sanity: use `01_casas_2012_breakthrough_validation.md`.
3. Schell two-bed PSA validation: use `02_schell_2013_two_bed_psa_validation.md`.
4. Delgado layered-bed extension: use `03_delgado_2014_layered_bed_extension.md`.
5. Sensitivity and optimisation: use `04_casas_thesis_sensitivity_optimisation.md` only after the validation cases are stable.

## Source separation rules

Keep these parameter packs separate:

```text
params/casas2012_ap360_sips_binary/
params/schell2013_ap360_sips_binary/
params/delgado2014_bpl13x_lf_four_component/
```

Do not blend AP3-60, BPL, 13X, Sips, Langmuir-Freundlich, Schell PSA heat assumptions, Delgado kinetics, or Casas thesis adiabatic optimisation settings into a single default parameter file.

## Boundary-condition policy for Codex

Default implementation mode remains toPSAil-native:

- use native toPSAil pressure-flow handling;
- use native toPSAil boundary-condition handling;
- use project-specific wrappers, parameter files, and validation manifests around the native machinery.

Only implement literature-specific boundary functions in a separately labelled reproduction mode. Do not silently replace the native boundary machinery because a paper used a convenient pressure-time formula. That is how models become fan fiction.

## Hard versus soft targets

Use the following categories:

| Category | Meaning |
|---|---|
| Hard transcription | Direct table values, equations, and explicit source statements. These may be used as implementation constants. |
| Soft plot-read target | Approximate values read from figures. Use only for sanity checks unless the figure is digitised in a dedicated task. |
| Diagnostic detail | Piping, detector, stagnant-tank, or source-specific measurement corrections. Include only in labelled diagnostic/reproduction modes. |
| Missing or ambiguous | Do not invent. Stop and report the gap. |

## Triple-check method used

The main numeric tables were checked three ways where possible:

1. `pdftotext -layout` extraction from the uploaded source PDFs.
2. Visual inspection of rendered PDF pages.
3. Cross-check against a second source table, SI file, thesis section, or dimensional/consistency check.

Some figure-derived values cannot be triple-checked to table precision because the source gives them graphically. Those are explicitly labelled as soft targets.
