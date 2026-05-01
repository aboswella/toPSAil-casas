# Thermal Model Policy

## Default

Do not claim a physically faithful Yang reproduction for the active final
implementation.

Yang uses non-isothermal layered beds. The active target is a homogeneous
activated-carbon H2/CO2 surrogate. Thermal behaviour must be documented for each
case or report, and any mismatch with Yang must be treated as a model limitation.

## Required Modes And Labels

Every case or pilot report must label its thermal mode, such as:

- finite wall heat transfer;
- adiabatic sensitivity case;
- fixed-wall or isothermal approximation;
- thermal mode not yet exercised in a static or parameter-pack task.

If the mode depends on a missing parameter, stop and record the uncertainty
instead of silently choosing a value.

## Homogeneous Surrogate Requirement

The first final implementation deliberately excludes:

- zeolite 5A;
- layered activated carbon plus zeolite beds;
- CO and CH4;
- pseudo-impurity or inert placeholder components.

Run metadata must state that the active model is a homogeneous
activated-carbon-only surrogate.

## Layered-Bed Position

Layered-bed support may remain historically relevant for later model-expansion
work, but it is not part of the active final surrogate. Do not add layered-bed
physics under a final implementation batch unless the user explicitly changes
the target.

Allowed current positions:

- homogeneous activated-carbon surrogate;
- layered-bed support not used in this final implementation;
- layered-bed capability noted only as a limitation or later extension.

## Sensitivity Variables

Later sensitivity analysis may consider:

- heat transfer coefficient multiplier;
- wall heat capacity;
- ambient/wall temperature;
- heat of adsorption;
- gas heat capacity model;
- column radius;
- superficial velocity;
- valve coefficients;
- cycle time;
- feed velocity.

Sensitivity analysis is not part of default smoke or baseline commissioning
unless the task explicitly asks for optimization-readiness checks.

## Documentation Rule

Every case spec, manifest, adapter audit, or validation report must state:

- thermal mode;
- homogeneous activated-carbon surrogate status;
- known physical-model mismatches;
- whether the output is a schedule/wrapper/adapter test or a physical comparison.
