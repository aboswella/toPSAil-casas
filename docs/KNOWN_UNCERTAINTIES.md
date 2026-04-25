# Known Uncertainties

This register records unresolved source, modelling, and workflow uncertainties. Do not silently resolve these by choosing convenient values.

## Source availability

- Delgado 2014 paper and SI are expected but are not currently present under `sources/`.
- `Missing information.txt` is mentioned in the handover but is not currently present under `sources/`.

## Casas-lite

- Exact breakthrough front shape is not a validation target because Casas includes axial dispersion and detector/piping effects that are outside the near-term toPSAil-native scope.
- Acceptable breakthrough timing and thermal-response tolerances still need to be defined in `validation/manifests/casas_lite_breakthrough.md`.
- Any Casas parameters not directly transcribed from the source must be recorded before implementation.

## Schell validation

- The extent to which Schell boundary-condition details must be reproduced is unresolved. Default policy is to use toPSAil-native handling first.
- Thermal wall parameters and any source gaps must be made explicit before running Schell validation.
- CO2 capture/purity metrics may require reconstruction from available source outputs; record assumptions before comparing.

## Pressure equalisation

- Whether a Schell/Casas-style iterative equalisation comparison is needed is unknown. Use toPSAil-native equalisation first.
- Equalisation diagnostics are desired but should be added only under a dedicated task.

## Delgado extension

- Whether toPSAil natively supports layered beds or spatially varying adsorbent properties is not yet audited.
- Delgado PSA results are simulation-to-simulation targets, not experimental validation.
- The project basis remains binary H2/CO2 unless a contaminant-polishing task explicitly expands the component set.

## Tooling

- `rg` currently resolves to the bundled WindowsApps/Codex path and fails with access denied on this machine. Use PowerShell fallback until a working ripgrep install is ahead in PATH.
- Confirm whether Codex reads `.codex/config.toml` using `/status` before relying on profile settings.
