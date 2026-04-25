# Delgado Layered Extension Case Spec

## Role

Delgado 2014 supports later extension work for layered beds and contaminant polishing. It is not the primary validation target.

## Source basis

- `docs/SOURCE_LEDGER.md`
- Delgado 2014 paper and SI when added under `sources/`

## Required model posture

- Do not begin implementation until the source PDFs/SI are present or a task provides verified source excerpts.
- First audit whether toPSAil supports layered beds or spatially varying adsorbent properties.
- Keep this extension separate from the binary H2/CO2 Schell validation path.

## Parameter pack

Expected parameter folder:

- `params/delgado2014_bpl13x_lf_four_component/`

Expected components:

- H2;
- CO2;
- CO;
- CH4.

Expected adsorbents:

- BPL activated carbon;
- 13X zeolite.

## Thermal mode

Thermal behaviour is secondary for Delgado-style extension unless contaminant polishing becomes a major branch. Any approximation must be explicit in the manifest.

## Validation targets

Delgado targets are simulation-to-simulation reproduction targets, not experimental validation:

- H2 purity;
- H2 recovery;
- productivity or related reported metrics;
- qualitative contaminant polishing behaviour.

## Stop conditions

Stop instead of editing if:

- Delgado paper or SI data are unavailable;
- layered-bed support is unknown and unaudited;
- the task would alter Schell validation files;
- the task would expand the component set without updating manifests and parameter-pack documentation.
