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

## Batch 2 Parameter Builder

`params/ribeiro_surrogate/buildRibeiroSurrogateTemplateParams.m` and `params/ribeiro_surrogate/finalizeRibeiroSurrogateTemplateParams.m` create an Excel-free native four-column parameter struct for the binary activated-carbon surrogate.

The builder converts Ribeiro Table 5 `12.2 N m^3/h` through the batch 1 molar-flow basis, using `R = 83.14 cm^3 bar mol^-1 K^-1`, `T = 303 K`, `P = 7 bar_abs`, and `n = 0.1513 mol/s`, which gives a native feed flow of about `545 cm^3/s`.

Particle values are stored in native-compatible units for later runtime use: particle density `842 kg/m^3` becomes `8.42e-4 kg/cm^3` as `params.pellDens`, and particle radius `1.17e-3 m` becomes pellet diameter `0.234 cm` as `params.diamPellet`. Particle porosity `0.566` is retained as a dimensionless particle-porosity field; the current batch uses `maTrRes = 0`, so the material-balance overall void remains the bed void fraction `0.38`.

The finalizer initializes the default valve placeholders before calling `getDimLessParams` because native toPSAil reads `valFeedCol` and `valProdCol` during dimensionless setup. These are placeholders only; no Ribeiro native schedule is built in batch 2.

## Later Notes

Later batches should add unit conversions, schedule details, and metric-basis caveats here as those implementation files are created.
