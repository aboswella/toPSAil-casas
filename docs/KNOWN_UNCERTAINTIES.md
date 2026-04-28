# Known Uncertainties

This register records unresolved source, modelling, and workflow uncertainties. Do not silently resolve these by choosing convenient values.

## Source availability

- `Missing information.txt` is mentioned in the handover but is not currently present under `sources/`.

## Casas-lite

- Exact breakthrough front shape is not a validation target because Casas includes axial dispersion and detector/piping effects that are outside the near-term toPSAil-native scope.
- Acceptable breakthrough timing and thermal-response tolerances still need to be defined in `validation/manifests/casas_lite_breakthrough.md`.
- Any Casas parameters not directly transcribed from the source must be recorded before implementation.

## Schell validation

- Schell-specific boundary-condition mechanics are outside the current integration pack. Use toPSAil-native handling first unless a future explicit instruction pack authorises a labelled reproduction mode.
- Thermal wall parameters and any source gaps must be made explicit before running Schell validation.
- Schell reports CO2-rich product metrics by subtraction from feed inventory and measured H2-rich product. This is a validation reporting-basis note, not a simulator defect; extractors must state whether they compare direct toPSAil stream outputs or the same subtraction basis.
- Flow-rate basis remains an explicit uncertainty: the paper reports `20 cm3/s`, and the canonical source pack uses actual volumetric flow at step pressure because Schell states molar feed flow changes with pressure. A standard-volume interpretation is not a second paper value; it is a labelled unit-ambiguity sensitivity only. The wrong choice should cause large, obvious shifts in inventory, thermal response, and product metrics, so report that evidence rather than tuning around it.
- The Schell case-input route is not yet chosen. Prefer wrappers around the simulator entry points wherever practical, then use a small case-input strategy decision before building a runnable case.
- Intentional design choice: add the Schell Sips equation as an optional core isotherm without changing default toPSAil behaviour. Before any agent edits core files, it must alert the project owner that this needs a dedicated implementation plan.
- An interrupted all-else-equal `case_study_1.0` diagnostic suggested that routing the native example through the optional Schell Sips isotherm may greatly increase runtime and repeatedly trigger native "raff. tank pressure has not reached" messages. A later reduced diagnostic (`nVols = 8`, `nTiPts = 5`, `nCycles = 3`, `numZero = 1e-3`) showed that the raffinate-tank message is not Sips-specific: the reduced baseline emitted 8 such messages and reached the loose CSS threshold after 2 cycles, while the Sips variant emitted 23 messages, ran about 3 times longer inside `runPsaCycle`, and needed the full 3-cycle budget. Treat Sips as a likely runtime/stiffness amplifier in this diagnostic, not as the sole cause of native receiver-tank pressure messages.
- Temperature-profile comparisons remain qualitative/manual-review targets. Do not digitize Schell curves by default; instead present the relevant source/profile files or excerpts directly to the project owner for manual examination.

## Pressure equalisation

- Whether a Schell/Casas-style iterative equalisation comparison is needed is unknown. Use toPSAil-native equalisation first.
- Equalisation diagnostics are desired but should be added only under a dedicated task.
- Schell `p_peq` is not a table-given source parameter. Do not invent it for default validation.

## Delgado extension

- Whether toPSAil natively supports layered beds or spatially varying adsorbent properties is not yet audited.
- Delgado PSA results are simulation-to-simulation targets, not experimental validation.
- The project basis remains binary H2/CO2 unless a contaminant-polishing task explicitly expands the component set.

## Tooling

- `rg` is available and working on this machine. Use `rg` and `rg --files` as the first-choice search commands.
- The Schell JSON source pack intentionally preserves source-symbol field names `a`/`A` and `b`/`B` for Sips parameters. MATLAB `jsondecode` and Python JSON tools parse it correctly, but PowerShell `ConvertFrom-Json` treats these as duplicate case-insensitive keys. Use MATLAB or Python for source-pack checks unless a future task explicitly renames those fields.
- Confirm whether Codex reads `.codex/config.toml` using `/status` before relying on profile settings.
