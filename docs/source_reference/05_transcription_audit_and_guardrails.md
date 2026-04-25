# Transcription Audit and Guardrails

## Purpose

This file records how the source-reference sheets were checked and where the remaining ambiguities are. Codex should read this before modifying parameter files or validation manifests.

## Triple-check protocol used

The extraction used three checks where possible:

1. **Text extraction:** `pdftotext -layout` from the uploaded PDFs.
2. **Visual verification:** rendered PDF page images, especially for tables and figures.
3. **Cross-check:** comparison against supporting information, thesis sections, or a consistency check.

A value is marked as a hard transcription only when the source gives it directly in a table or explicit text. Plot reads and derived values are labelled.

## High-risk parameter conflicts

These are not errors in the reference pack. They are source-dependent differences that Codex must keep separate.

| Topic | Casas 2012 breakthrough | Schell 2013 PSA | Delgado 2014 layered PSA | Action |
|---|---:|---:|---:|---|
| Adsorbent | AP3-60 activated carbon | AP3-60 activated carbon | BPL 4X10 carbon + 13X zeolite | Never merge into one pack. |
| Isotherm family | Sips preferred | Sips | Langmuir-Freundlich | Keep source-specific equations. |
| CO2 heat of adsorption | -26000 J/mol | -21000 J/mol | Qst table in kJ/mol by gas/adsorbent | Do not carry Casas heat into Schell. |
| H2 heat of adsorption | -9800 J/mol | -9800 J/mol | Qst table in kJ/mol by gas/adsorbent | Shared value only for AP3-60 sources. |
| Bed density | 507 kg/m3 | 480 kg/m3 | Not same concept; use Table 1 density/porosity | Do not substitute Casas bed density into Schell. |
| Axial dispersion | Included for breakthrough front fitting | Neglected for PSA validation | Peclet = 500 plug-flow approximation | Use by stage. |
| Wall heat transfer | Breakthrough wall/heater model | Lab PSA wall/heater model | Adiabatic PSA model | Use by stage. |
| Boundary pressure functions | Breakthrough constant pressure | Schell has optional source-specific formulas | Delgado uses linear pressure changes and stored streams | Default remains toPSAil-native unless labelled. |

## Remaining ambiguities and required handling

| Ambiguity | Location | Why it matters | Required Codex behaviour |
|---|---|---|---|
| Delgado particle radius | Delgado PSA paragraph says `0.7 cm`, while Table 1 particle sizes imply about `0.7 mm` radius. | A factor-of-ten radius error can strongly affect Ergun pressure drop and mass-transfer terms. | Do not silently correct. Parameterise both options and require task-level authorisation. |
| Casas thesis geometry | Thesis line says `Ri = 2.5 cm`; Casas/Schell tables imply `Ri = 1.25 cm`. | Could double cross-sectional area if taken literally. | Use validated lab geometry unless a task explicitly selects thesis literal geometry. |
| Delgado 298 K diffusion constants | Main text says use 298 K constants from SI, but SI tables are temperature series rather than exact 298 K rows for most gases. | Kinetic constants are needed for reproduction. | Use the derived estimates in the Delgado sheet only if the task accepts derived values; otherwise stop and request explicit choice. |
| Casas CO2 breakthrough time | Figure 4 gives a graphical front; text explicitly gives only H2 breakthrough about 110 s. | Exact front-shape matching is not the Casas-lite objective. | Treat CO2 timing as soft plot-read target unless digitised. |
| Schell profile matching after piping | Source adds pipe and optional stagnant tank diagnostics. | Can distract from table-performance validation. | Do not include by default; use only in labelled diagnostic/reproduction mode. |

## Stage-specific hard values audited

### Casas 2012 breakthrough

| Group | Source | Status |
|---|---|---|
| Column/bed parameters | Table 2 | Hard transcription, rendered page checked. |
| Dynamic parameters | Table 3 | Hard transcription, rendered page checked. |
| Sips/Langmuir parameters | Table 4 | Hard transcription, rendered page checked. |
| Reference H2 breakthrough about 110 s | Text + Figure 4 | Approximate textual target. |
| CO2 breakthrough timing | Figure 4 | Soft plot-read only. |

### Schell 2013 PSA

| Group | Source | Status |
|---|---|---|
| Bed/setup parameters | Table 1 | Hard transcription, rendered page checked. |
| Timings/performance | Table 2 | Hard transcription, rendered page checked. |
| Model parameters | Table 3 | Hard transcription, rendered page checked. |
| Sips parameters | SI Table 3 | Hard transcription, rendered page checked. |
| Piping parameters | Table 4 | Diagnostic hard transcription. |
| Stagnant tank | Discussion around Figure 8 | Diagnostic only. |

### Delgado 2014 layered PSA

| Group | Source | Status |
|---|---|---|
| Adsorbent properties | Table 1 | Hard transcription, rendered page checked. |
| LF parameters | Table 4 | Hard transcription, rendered page checked. |
| Cycle sequence | Text + Figure 8 | Hard sequence, figure-derived schedule. |
| Cycle times | Figure 8 + text | Adsorption/equalization/blowdown text checked; PP/RP/BF timings are figure-derived. |
| Diffusion constants | SI Tables S1-S2 | Raw table checked; 298 K values are derived estimates. |
| Performance targets | Case 1 text | Hard transcription. |

### Casas thesis optimisation

| Group | Source | Status |
|---|---|---|
| Base case configuration | Table 4.1 | Hard transcription from text extraction. |
| Scheduling constraints | Chapter 4 text | Hard transcription. |
| CSS criteria | Eq. 4.1 | Hard transcription. |
| Performance definitions | Eqs. 4.2-4.6 | Hard transcription, paraphrased. |
| Representative Pareto point | Table 4.3 + text | Hard transcription. |
| Parametric conclusions | Chapter 4 discussion/conclusion | Paraphrased source conclusions. |

## What Codex should do when a value is missing

Use this decision tree:

```text
1. Search the relevant source-reference Markdown file.
2. Search this audit/guardrail file.
3. If absent, check whether the task explicitly authorises reading the source PDFs.
4. If not authorised, stop and report the missing value.
5. If authorised, extract the value, add it to the correct source-reference sheet, and record the source anchor.
```

Do not infer a missing parameter merely because another paper used something similar. There are enough wrong models in the world already.

## Required reporting language for validation tasks

Every validation report should include:

```text
source_reference_file = <one of these MD files>
parameter_pack = <path>
model_mode = topsail_native | source_reproduction | diagnostic
source_values_changed = yes/no
validation_thresholds_changed = yes/no
known_omissions = <piping, wall model, layered-bed support, etc.>
```

## File placement recommendation

Place this pack in the repository under:

```text
docs/source_reference/
```

Do not commit raw PDFs unless the project owner explicitly decides to do so and has the right to redistribute them.
