# Thermal Model Policy

## Default

Do not assume adiabatic operation by default for Yang four-bed comparisons.

Yang uses non-isothermal dynamics and layered beds. The wrapper can be architecturally correct while still being only a physical surrogate if thermal or layered-bed support is incomplete.

## Required Modes And Labels

Every case or pilot report must label its thermal mode, such as:

- finite wall heat transfer;
- adiabatic sensitivity case;
- fixed-wall or isothermal approximation;
- thermal mode not yet exercised in a static manifest task.

If the mode depends on a missing parameter, stop and record the uncertainty instead of silently choosing a value.

## Layered-Bed Requirement

WP1 must audit layered-bed capability but must not implement layered-bed physics.

Allowed WP1 audit outcomes:

- layered support confirmed;
- layered support not confirmed, homogeneous surrogate required;
- audit blocked by a missing interface or source ambiguity.

Do not describe a homogeneous surrogate as physically faithful to Yang layered beds.

## Sensitivity Variables

Later sensitivity analysis may consider:

- heat transfer coefficient multiplier;
- wall heat capacity;
- ambient/wall temperature;
- heat of adsorption;
- gas heat capacity model;
- column radius;
- superficial velocity;
- layer material assignment.

Sensitivity analysis is not part of WP1.

## Documentation Rule

Every case spec, manifest, or validation report must state:

- thermal mode;
- layered-bed support status;
- known physical-model mismatches;
- whether the output is a schedule/wrapper test or a physical comparison.
