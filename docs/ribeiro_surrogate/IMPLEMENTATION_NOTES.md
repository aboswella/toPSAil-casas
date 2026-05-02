# Ribeiro Surrogate Implementation Notes

## Batch 0 Bootstrap

- Active guide: `Overall Implementation Guide.md`.
- Active source of truth for Ribeiro values: `sources/Ribeiro 2008.pdf`.
- Yang paper and scripts under `sources/` are reference-only material for native toPSAil patterns.
- Do not import Yang cycle labels, adapters, diagnostics, ledgers, wrapper architecture, or tests.
- Batch 0 creates only repository instructions and this notes file.

## Baseline Scope

- Minimal binary H2/CO2 activated-carbon surrogate.
- Native toPSAil machinery wherever possible.
- Four columns, eight logical steps per column, and sixteen native schedule slots.
- Feed composition `[0.8153503893; 0.1846496107]`.
- Feed flow about `0.1513 mol/s`, from Ribeiro Table 5 `12.2 N m^3/h`.
- Pressure basis `bara`, with `7 bara` high pressure and `1 bara` low pressure.

## Later Notes

Batch 1 and later should add source-backed constants, unit conversions, schedule details, and metric-basis caveats here as those implementation files are created.
