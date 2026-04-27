# Schell 2013 implementation pack - start here

This pack redrafts the Schell integration plan into an implementation-ready form for the `toPSAil-casas` fork.

It applies three corrections to the earlier plan:

1. Baseline readiness now comes before Schell source-pack work.
2. JSON is the only canonical source pack. YAML is deliberately omitted because humans invented drift and then gave it file extensions.
3. The Schell Sips tests include independent numerical anchor values, so Codex cannot test its own misunderstanding against itself and declare victory.

## How to use this pack

This repository carries the imported `repo_overlay/` artifacts in their project locations:

- `docs/workflow/schell_2013_implementation/`
- `params/schell2013_ap360_sips_binary/`
- `validation/targets/`
- `tests/fixtures/`

Recommended first action in the repo:

```powershell
git status --short
git branch --show-current
```

Then give Codex `docs/workflow/schell_2013_implementation/task_cards.md` and ask it to execute only `SCHELL-PRE`, then stop and report.

Do not start at the model implementation tasks. Start with repo state, baseline smoke/status, source-reference correction, manifest population, source-pack schema, and equation-local tests. The first several tasks are boring on purpose. Boring is how numerical code avoids becoming interpretive dance.

## Files in this overlay

| Path | Role |
|---|---|
| `docs/workflow/schell_2013_implementation/implementation_guidance.md` | Executive summary and integration strategy. |
| `docs/workflow/schell_2013_implementation/task_cards.md` | Ordered Codex task cards. |
| `docs/workflow/schell_2013_implementation/source_extraction_audit.md` | Sceptical audit against the Schell paper and SI. |
| `docs/workflow/schell_2013_implementation/case_input_strategy_template.md` | Template for the required strategy decision before native case work. |
| `docs/workflow/schell_2013_implementation/schell_2013_output_summary.schema.json` | Required summary-output schema for validation runs. |
| `params/schell2013_ap360_sips_binary/schell_2013_source_pack.json` | Canonical typed Schell source pack. |
| `params/schell2013_ap360_sips_binary/schell_2013_source_pack.schema.json` | JSON schema for the source pack. |
| `params/schell2013_ap360_sips_binary/schell_2013_sips_anchor_cases.json` | Independent numerical Sips anchors. |
| `validation/targets/schell_2013_validation_targets.csv` | Table 2 validation targets. |
| `validation/manifests/schell_2bed_validation_PROPOSED.md` | Replacement content for the scaffold manifest. |
| `tests/fixtures/schell_2013_sips_anchor_cases.json` | Test fixture copy of the Sips anchors. |

## First Codex prompt

Use `codex_first_prompt.md` at the top of this bundle. It tells Codex to reconcile the pack and execute only the first task. That restriction is not decorative.
