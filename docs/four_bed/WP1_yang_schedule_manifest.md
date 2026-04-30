# WP1 Yang Schedule Manifest

## Purpose

WP1 adds a static, machine-readable Yang 2009 four-bed ten-step schedule
manifest for later wrapper work. It defines schedule metadata, duration
normalization, label semantics, symbolic pressure classes, and a layered-bed
capability audit. It does not execute the PSA cycle.

## Source Schedule

The manifest encodes Yang Table 2 for beds `A`, `B`, `C`, and `D` with ten
source columns:

| Source column | Duration label | Units in `t_c/24` | Bed A | Bed B | Bed C | Bed D |
|---:|---|---:|---|---|---|---|
| 1 | `t_c/24` | 1 | AD | EQI-PR | BD | EQI-BD |
| 2 | `t_c/4` | 6 | AD&PP | BF | PU | PP |
| 3 | `t_c/24` | 1 | EQI-BD | AD | EQII-PR | EQII-BD |
| 4 | `t_c/6` | 4 | PP | AD&PP | EQI-PR | BD |
| 5 | `t_c/24` | 1 | EQII-BD | EQI-BD | BF | PU |
| 6 | `t_c/24` | 1 | BD | PP | AD | EQII-PR |
| 7 | `t_c/6` | 4 | PU | EQII-BD | AD&PP | EQI-PR |
| 8 | `t_c/24` | 1 | EQII-PR | BD | EQI-BD | BF |
| 9 | `t_c/24` | 1 | EQI-PR | PU | PP | AD |
| 10 | `5t_c/24` | 5 | BF | EQII-PR | EQII-BD | AD&PP |

The per-bed sequences are validated against this table. The PDF text renders
`AD&PP` as `AD & PP`; the manifest preserves the compact project label
`AD&PP` while recording the alias in the glossary.

## Architecture Assumptions

WP1 does not define pair identities. Later WP2 work must provide explicit bed
partners for every direct-transfer role.

WP1 does not create dynamic internal tanks, shared header inventory, global
four-bed RHS/DAE state, or core adsorber-physics changes. The architecture
metadata records fixed-duration scheduling only; event-based termination is
out of scope.

## Duration Normalization

Raw Yang duration units are stored as:

```matlab
[1; 6; 1; 4; 1; 1; 4; 1; 1; 5]
```

These sum to `25` units of `t_c/24`, or `25*t_c/24`. WP1 preserves the raw
labels and exposes normalized displayed-cycle fractions:

```matlab
raw_fraction_of_tc = duration_units_t24 ./ 24;
normalized_fraction_of_displayed_cycle = duration_units_t24 ./ 25;
```

Later work packages must decide how simulation `cycleTimeSec` maps to Yang's
`t_c`; WP1 does not silently rescale the source labels.

## Label Glossary

The glossary covers `AD`, `AD&PP`, `EQI-BD`, `PP`, `EQII-BD`, `BD`, `PU`,
`EQII-PR`, `EQI-PR`, and `BF`.

Important WP1 semantics:

- `AD&PP` is compound: external adsorption/product plus internal BF donor
  metadata.
- `EQI` and `EQII` remain distinct metadata families.
- `PP` means provide purge.
- `PU` is the schedule-table purge label; Yang prose may use `PG`.
- Internal transfer gas is not external product. `AD&PP` keeps an external
  product flag only because the step also produces external product.

## Pressure Classes

Pressure classes are symbolic:

| Class | Meaning | Numeric WP1 value |
|---|---|---:|
| PF | adsorption/feed pressure | 9.0 atm |
| P1 | first equalization donor terminal pressure | symbolic |
| P2 | provide-purge donor terminal pressure | symbolic |
| P3 | second equalization donor terminal pressure | symbolic |
| P4 | lowest purge/blowdown pressure | 1.3 atm |
| P5 | second equalization receiver terminal pressure | symbolic |
| P6 | first equalization receiver terminal pressure | symbolic |

No numeric values are assigned to `P1`, `P2`, `P3`, `P5`, or `P6` in WP1.

## Layered-Bed Caveat

Yang uses layered activated carbon and zeolite 5A beds. The local PDF states a
100 cm activated-carbon layer at the feed end and a 70 cm zeolite 5A layer
above it. WP1 records this as an audit fact but does not implement layered-bed
physics.

The current audit result is
`not_confirmed_homogeneous_surrogate_required`. Any later Yang comparison must
be labelled as a homogeneous surrogate unless axial layered material assignment
is confirmed. Current project direction is to not incorporate layered beds for
now, so near-term reports should explicitly use the homogeneous-surrogate
position.

## Manual Source Check

The WP1 manifest was manually checked against
`sources/Yang 2009 4-bed 10-step relevant.pdf` for:

- Table 2 ten-column schedule and duration labels.
- Raw duration units and the `25*t_c/24` displayed-span issue.
- Operation semantics for the ten schedule labels.
- Pressure anchors `PF = 9 atm` and `P4 = 1.3 atm`.
- Layered-bed materials and layer heights.

One source-text ambiguity is recorded in `docs/KNOWN_UNCERTAINTIES.md`: the
purge prose includes a cross-reference that appears to point to step `(c)`,
while step `(d)`, the boundary-condition notation `yi,PP`, and the project
workflow support the `PP -> PU/PG` direct-transfer family. WP1 keeps `PP_PU`
metadata and leaves explicit pair identities to WP2.

Full Table 3 operating-condition transcription and Table 4 isotherm
transcription are out of WP1 scope.

## Validation Tests

- `T-STATIC-01`: `tests/four_bed/testYangManifestIntegrity.m`
- `T-PARAM-01`: `tests/four_bed/testYangLayeredBedCapability.m`

Run:

```matlab
addpath(genpath(pwd));
run("scripts/run_source_tests.m");
```

## Handoff To WP2

WP2 should consume `manifest.bedSteps` rows where `requires_pair_map == true`
and build explicit direct-transfer pair identities from `bed`, `source_col`,
`yang_label`, `role_class`, `direct_transfer_family`, and pressure classes.
WP2 must not infer pair identities from source table row order, bed adjacency,
or native two-bed assumptions.
