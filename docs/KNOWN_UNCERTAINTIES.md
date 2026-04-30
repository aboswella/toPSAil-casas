# Known Uncertainties

This register records unresolved source, modelling, and workflow uncertainties. Do not silently resolve these by choosing convenient values.

## Source Availability

- The local Yang PDF is present as `sources/Yang 2009 4-bed 10-step relevant.pdf`.

## Yang Schedule And Manifest

- The displayed duration units in the WP1 guidance sum to 25 units of `t_c/24`. WP1 must preserve raw duration labels and expose normalized displayed-cycle fractions rather than silently rescaling the source labels.
- WP1 does not define pair identities. Pair identities belong to WP2.
- `AD&PP` combines external adsorption/product behaviour with internal backfill-donor behaviour. It must remain compound in metadata and ledgers.
- `EQI` and `EQII` must remain distinct metadata and ledger families even if native machinery uses a generic paired-bed operation.

## Pairing And State

- Direct-transfer pair identities must be explicit. Do not infer them from row order, bed adjacency, or native two-bed assumptions.
- The state injection/extraction contract for persistent beds `A/B/C/D` is not yet implemented.
- Initial phase offsets for the four persistent beds must be documented before any multi-cycle pilot can be interpreted.

## Physical Model

- Yang uses layered activated carbon and zeolite 5A beds. Current layered-bed support in toPSAil must be audited before a physical reproduction claim.
- Intermediate pressure classes `P1`, `P2`, `P3`, `P5`, and `P6` are symbolic unless a task provides explicit numeric source support.
- Thermal mode and wall/ambient assumptions must be stated before comparing temperature behaviour.
- Any mismatch between Yang model assumptions and toPSAil assumptions must be reported as a model limitation rather than patched by tuning constants.

## Ledgers And Metrics

- Internal direct-transfer streams must not be counted as external product.
- Yang-basis purity, recovery, productivity, and CSS metrics require wrapper ledgers and all-bed state residuals.
- Native toPSAil metrics may be useful diagnostics but are not automatically the Yang external-product basis.

## Tooling

- `rg` is available and working on this machine. Use `rg` and `rg --files` as the first-choice search commands.
- Confirm whether Codex reads `.codex/config.toml` using `/status` before relying on profile settings.
