# Boundary Condition Policy

## Default policy

Use toPSAil-native pressure-flow and boundary-condition handling.

## Rationale

The project goal is not to recreate the Schell solver exactly. The goal is to test whether toPSAil can reproduce the dominant behaviour of the Schell H2/CO2 PSA experiments well enough for design studies.

## Forbidden hybridisation

Do not mix isolated Schell-style boundary approximations into the toPSAil-native model unless explicitly authorised.

Examples of forbidden uncontrolled hybrids:

- using Schell pressure-time profiles for one step and toPSAil-native pressure-flow control for another without documentation;
- changing equalisation handling to match one validation output;
- changing pressure control and product accounting in the same task.

## Allowed validation mode

A separate Schell-reproduction mode may be created if needed. It must be labelled clearly and must not replace the default toPSAil-native mode.

## Required diagnostics for pressure-changing steps

For pressurisation, blowdown, and pressure equalisation, report:

- initial pressure,
- final pressure,
- pressure trajectory,
- inlet/outlet flow direction,
- total gas inventory change,
- component inventory change,
- boundary molar flow integrals.