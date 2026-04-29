# Future Literature Case Guardrails

Task context: Schell pressure-program diagnostic and fix.

Use these guardrails before adding later literature implementations or new PSA cases.

1. Keep source pressure setpoints separate from numerical reservoir headroom. If a tank pressure is raised only to drive a native valve, label it as an adapter artefact and do not validate column pressure against that value.
2. Do not reuse one valve coefficient for physically different duties unless a ledger shows it preserves the intended step endpoint and flow role. Repressurisation, adsorption feed, blowdown, and purge deserve separate named controls.
3. Add a per-step ledger before comparing purity and recovery. At minimum, log column pressure start/end/min/max, column feed/product boundary cumulative moles, external product and waste moles, and tank pressure/composition.
4. Treat toPSAil step strings as literal source/sink commands. A label such as `LP-EXT-RAF` is not a generic purge; in native connectivity it uses the dynamic raffinate tank as the product-end source.
5. Keep native stream accounting separate from literature reporting bases. For Schell, native raffinate/extract product metrics are diagnostic until the SI subtraction-basis extractor is implemented.
6. Add invariant tests for adapter semantics before validation targets. Useful invariants include pressure endpoint bounds, non-trace intended product flow, fixed component order, no non-positive schedule segments, and explicit warnings for known approximations.
7. Do not weaken thresholds or tune physical constants to repair stream placement. First prove source/sink connectivity, pressure programme, and accounting basis.
