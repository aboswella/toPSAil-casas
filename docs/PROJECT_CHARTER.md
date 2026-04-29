# Project Charter

## Aim

Develop a MATLAB PSA modelling workflow based on toPSAil for H2/CO2 separation, validated progressively against Casas-lite breakthrough behaviour and Schell two-bed PSA experiments, with Delgado-inspired layered-bed contaminant-polishing considered as an extension.

## Base design assumption

The basis of design assumes a binary H2/CO2 feed due to upstream gas pretreatment. The pretreatment system itself is outside this project scope.

## Primary validation source

Schell 2013 laboratory two-column PSA experiments are the primary validation target for full-cycle PSA behaviour.

## Secondary validation source

Casas 2012 breakthrough experiments are used only to validate basic adsorption, thermal response, and breakthrough timing. Exact front shape is not a project objective.

## Extension source

Delgado 2014 is used to motivate and parameterise possible contaminant-polishing studies involving CO, CH4, CO2, H2, BPL activated carbon, and 13X zeolite.

## Out of scope unless explicitly authorised

- Full detector piping reproduction.
- Exact Casas axial-dispersion/front-shape reproduction.
- Rewriting toPSAil boundary-condition internals.
- Full industrial pretreatment design.
- Multi-objective optimisation before validation cases are stable.