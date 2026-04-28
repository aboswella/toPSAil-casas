# Source Ledger

## Ledger policy

This ledger records source roles only. It does not resolve missing or ambiguous parameters. Unresolved source issues belong in `docs/KNOWN_UNCERTAINTIES.md`.

## Casas 2012

Role:
- breakthrough sanity validation.

Use:
- bed geometry;
- feed conditions;
- approximate breakthrough timing;
- approximate thermal response;
- activated-carbon H2/CO2 behaviour.

Not used for:
- exact front-shape reproduction;
- exact detector-piping reproduction;
- exact axial-dispersion validation.

Local artifact status:
- `sources/Casas 2012.pdf` is present.

## Casas thesis 2012

Role:
- higher-level PSA design and optimisation context.

Use:
- multi-bed PSA configuration logic;
- CO2 capture framing;
- pressure equalisation discussion;
- cycle scheduling constraints;
- later parametric/optimisation framing.

Not used for:
- immediate implementation target;
- replacement for Schell experimental validation.

Local artifact status:
- `sources/Casas thesis 2012.pdf` is present.

## Schell 2013

Role:
- primary two-bed PSA experimental validation.

Use:
- cycle structure;
- pressure levels;
- feed composition;
- bed/adsorbent properties;
- product metrics;
- temperature profiles;
- pressure histories.

Policy:
- use as an experimental validation target;
- do not rewrite toPSAil boundary conditions to mimic Schell unless a documented validation failure demands a separate labelled mode.

Local artifact status:
- `sources/Schell 2013.pdf` is present.
- `sources/Schell 2013 SI.pdf` is present.

## Delgado 2014

Role:
- extension material/cycle source.

Use:
- BPL activated carbon LF parameters;
- 13X zeolite LF parameters;
- diffusion constants;
- contaminant-polishing concept;
- layered-bed H2 purification case.

Caution:
- Delgado PSA performance is simulation-based, not experimental PSA validation.
- the binary H2/CO2 basis of design remains unless a specific contaminant-polishing task is opened.

Local artifact status:
- `sources/Delgado.pdf` is present.
- `sources/SI Delgado.pdf` is present.
