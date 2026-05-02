# Active task

Implement a minimal Ribeiro-style H2/CO2 PSA surrogate on native toPSAil.

## Rules

- Use native toPSAil machinery wherever possible.
- Do not implement Yang 2009.
- Do not port Yang custom adapters.
- Do not write tests unless explicitly requested.
- Do not modify native toPSAil core directories unless a blocker is proven.
- Native core directories are `1_config/`, `2_run/`, `3_source/`, `4_example/`, `5_reference/`, and `6_publication/`.
- New active Ribeiro files live under `params/ribeiro_surrogate/` and `scripts/ribeiro_surrogate/`.

## Target

- 4 columns.
- 8 logical steps per column.
- 16 native schedule slots.
- Binary H2/CO2.
- Feed composition `[0.8153503893; 0.1846496107]`, the H2/CO2-only renormalization of Ribeiro Table 5.
- Total molar feed flow about `0.1513 mol/s`, derived from Ribeiro Table 5 `12.2 N m^3/h`.
- Pressure basis `bara`.
- High pressure `7 bara`.
- Low pressure `1 bara`.
- Pure activated-carbon surrogate.
