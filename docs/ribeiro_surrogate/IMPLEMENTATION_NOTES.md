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

## Batch 1 Constants

`params/ribeiro_surrogate/ribeiroSurrogateConstants.m` defines the source-backed constants for the first Ribeiro surrogate. This is not a full Ribeiro reproduction. Ribeiro's full paper uses a five-component H2/CO2/CH4/CO/N2 feed, layered activated-carbon/zeolite beds, and a full dynamic non-isothermal model. This branch starts with a dry binary H2/CO2 activated-carbon surrogate for speed.

The source paper's objective is high-purity hydrogen production. The constants keep that target context while limiting the first implementation to the H2/CO2 activated-carbon subset, the Table 5 feed renormalization, and the pressure basis recorded in the active guide.

No native schedule was built in batch 1.

## Later Notes

Later batches should add unit conversions, schedule details, and metric-basis caveats here as those implementation files are created.
