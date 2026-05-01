# Parameter Packs

Parameter packs must be source-specific and traceable. Do not create a default
mixed parameter file.

For the active final four-bed implementation, the primary parameter package is
the Yang-inspired H2/CO2 homogeneous activated-carbon surrogate. Scope comes from
`docs/four_bed/FINAL_IMPLEMENTATION_CONTEXT.md` and the relevant batch guide.

Each pack should include:

- source references;
- units;
- transcription notes;
- unresolved source ambiguities;
- thermal assumptions;
- homogeneous or layered-bed status;
- component basis and feed renormalization, when applicable;
- a source-transcription or point-test plan.

Do not add zeolite 5A, CO, CH4, pseudo-components, or layered-bed behaviour to
the first final surrogate unless the user explicitly changes the target.

Small canonical source packs may be stored as JSON when they are source-derived
inputs rather than generated outputs. Avoid maintaining hand-edited duplicate
formats for the same parameter pack.
