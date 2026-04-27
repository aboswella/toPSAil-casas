# Schell case-input strategy decision template

Create this decision record during `SCHELL-05`. Do not implement the chosen route in the same task.

## Decision

Chosen route: `A | B | C | D | blocked`

- A: native Excel case under `4_example`
- B: JSON-to-Excel generator
- C: JSON-to-params MATLAB builder that calls `runPsaCycle(params)`
- D: wrapper around an existing native example/params output
- blocked: missing prerequisite prevents decision

## Repo facts inspected

- Native entry point:
- Parameter loading path:
- Excel files required:
- Platform constraints:
- Existing examples available:
- Existing tests/runners available:

## Compatibility with project rules

Does the route touch toPSAil core? `yes/no`

If yes, exact files and why explicit authorisation is needed:

## Source traceability

How the route consumes `schell_2013_source_pack.json`:

How source-pack hash is recorded in outputs:

## Smallest first runnable case

Case ID:
Cycles:
Expected runtime:
Expected hard checks:
Expected output summary path:

## Risks

| Risk | Mitigation |
|---|---|
| Flow-rate basis | |
| Sips model registration | |
| Pressure equalization | |
| MATLAB/Excel platform | |
| Output extraction | |

## Recommendation

One paragraph. No implementation in this task. Restrain yourself. It builds character, allegedly.
