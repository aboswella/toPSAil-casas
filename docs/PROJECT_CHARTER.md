# Project Charter

## Aim

Complete a MATLAB four-bed PSA workflow based on toPSAil for a Yang-inspired
H2/CO2 homogeneous activated-carbon surrogate.

The immediate objective is a thin wrapper-and-adapter implementation that reuses
existing toPSAil adsorber machinery while maintaining four persistent named bed
states.

## Base Design Assumption

The four-bed implementation is wrapper-level:

- persistent bed states are named `A`, `B`, `C`, and `D`;
- only physical adsorber state persists between slots;
- cumulative boundary counters are extracted for ledgers, then discarded or
  reset;
- internal transfers are direct bed-to-bed couplings;
- PP->PU and AD&PP->BF use custom wrapper-level adapters where native toPSAil
  step grammar is insufficient;
- existing toPSAil single-bed or paired-bed behaviour remains the numerical
  engine wherever suitable;
- external/internal stream accounting is reconstructed outside the core solver.

## Active Planning Source

The active final implementation context is:

- `docs/four_bed/README.md`
- `docs/four_bed/FINAL_IMPLEMENTATION_CONTEXT.md`
- the relevant active batch guide under `docs/four_bed/`

The old WP1-WP5 work-package documents and `docs/workflow/` CSV files are
legacy context. Use them for historical rationale, source provenance, old test
IDs, and risk cross-checking only.

## Primary Literature Source

Yang 2009 Table 2 and process description define the four-bed schedule,
operation labels, duration labels, and direct-transfer semantics for this
branch.

The active model target deliberately narrows that source into an H2/CO2
activated-carbon-only homogeneous surrogate. Do not present the final surrogate
as a full Yang layered four-component reproduction.

## Out Of Scope Unless Explicitly Authorised

- Dynamic internal tanks for Yang internal transfers.
- Shared header inventory for Yang internal transfers.
- A global four-bed RHS/DAE solve.
- Rewriting toPSAil adsorber physics, pressure-flow logic, or boundary-condition
  internals.
- Zeolite 5A, layered-bed behaviour, CO, CH4, or pseudo-impurity components in
  the first final implementation.
- Event-based Yang scheduling before the fixed-duration direct-coupling path
  passes commissioning.
- Optimization or generalized PFD work before the wrapper/adapters are stable.
