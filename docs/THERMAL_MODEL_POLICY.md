# Thermal Model Policy

## Default

Do not assume adiabatic operation for small-column validation.

Finite wall heat transfer is the preferred default for Schell-style small-column validation when required source parameters are available or explicitly bracketed.

## Required modes

The model should support, where practical:

1. finite wall heat transfer,
2. adiabatic sensitivity case,
3. fixed wall or isothermal approximation if explicitly justified.

## Sensitivity variables

At minimum, later sensitivity analysis should consider:

- heat transfer coefficient multiplier,
- wall heat capacity,
- ambient/wall temperature,
- heat of adsorption,
- gas heat capacity model,
- column radius,
- superficial velocity.

## Validation expectations

For Casas-lite:
- breakthrough timing and temperature rise are more important than exact front shape.

For Schell:
- thermocouple trends are a major validation observable.

For Delgado:
- thermal behaviour is secondary to reproducing reported PSA performance metrics unless contaminant polishing becomes a major project branch.

## Documentation rule

Every case spec must state its thermal mode:

- finite wall heat transfer,
- adiabatic sensitivity,
- isothermal or fixed-wall approximation.

If the mode depends on a missing parameter, stop and record the uncertainty instead of silently choosing a value.
