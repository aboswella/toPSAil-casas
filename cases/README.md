# Cases

This folder contains project-specific case definitions. Each case must have a
`case_spec.md` before implementation.

For the active final four-bed work, case scope comes from
`docs/four_bed/FINAL_IMPLEMENTATION_CONTEXT.md` and the relevant batch guide.
The old WP1-WP5 artifacts are legacy context, not prerequisites for adding a
final surrogate case.

Current final case basis:

- Yang-inspired H2/CO2 homogeneous activated-carbon surrogate;
- binary-renormalized Yang feed;
- normalized executable schedule durations;
- no dynamic internal tanks or shared headers for internal transfers;
- no global four-bed RHS/DAE;
- wrapper-level ledgers and audit metadata.

Case files should prefer wrappers and input definitions over toPSAil core edits.
