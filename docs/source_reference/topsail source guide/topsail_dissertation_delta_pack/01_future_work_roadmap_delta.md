# 01 - Chapter 6 future-work roadmap delta

This file extracts actionable future-work priorities from Chapter 6 only where the dissertation adds implementation-facing detail beyond the paper extraction pack.

## Experimental validation and collaboration

| Item | Dissertation location | Short quote | Implementation implication | Schell relevance | Four-bed relevance | Priority |
|---|---|---|---|---|---|---|
| Validate against additional lab or industrial PSA systems. | Diss p. 240 (PDF p. 275), §6.2.1 | "evaluate the predictive power of the simulator" | Build validation harnesses around source-fidelity manifests, not around tuned final metrics. | Immediate: Schell comparison must wait until source/sink ledgers and metric basis pass. | Later: four-bed implementation should be validated as a new simulator capability, not assumed. | Immediate |
| Use failed/edge cases to decide model extensions. | Diss p. 240 (PDF p. 275), §6.2.1 | "edge cases that toPSAil cannot fully represent" | Add a limitations register and explicit unsupported-feature failures. Do not silently patch unsupported flowsheets. | Immediate: document Schell purge/source limitations if native PFD cannot express them. | Immediate: document current >2 adsorber limitation before implementation. | Immediate |
| Simulation should drive model advancement where experiment and model diverge. | Diss p. 240 (PDF p. 275), §6.2.1 | "fill the gaps between the prediction from simulations" | Keep validation residuals, not just pass/fail metrics, so gaps point to missing physics or routing. | Later: after Schell routing is credible, compare residual patterns. | Later: useful after a four-bed prototype produces conserved ledgers. | Later |

## Emerging adsorption models

| Item | Dissertation location | Short quote | Implementation implication | Schell relevance | Four-bed relevance | Priority |
|---|---|---|---|---|---|---|
| Existing simulators lack reliable metrics for non-ideal feeds, advanced sorbents, and kinetic separations. | Diss p. 240 (PDF p. 275), §6.2.2 | "cannot calculate reliable performance metrics" | Reject any comparison that relies on an unsupported adsorption model. Emit a model-capability manifest. | Later unless Schell's source model is unsupported by native toPSAil. | Later: four-bed routing can be developed with existing submodels first. | Later |
| Future support requires implicit solution procedures. | Diss p. 241 (PDF p. 276), §6.2.2 | "models are also implicit in their nature" | Plan a DAE or implicit residual layer. Do not fake implicit isotherms/rates as explicit callbacks. | Research-only for current Schell integration unless the source requires gL/MS-LDF. | Research-only until routing/scheduling works. | Research-only |
| Specific future models are MS-LDF and Generalized Langmuir. | Diss p. 241 (PDF p. 276), §6.2.2 | "Maxwell-Stefan Linear Driving Force (LDF)" | Add `unsupported_model` gates for MS-LDF and gL unless implemented with solver tests. | Later. | Later. | Research-only |

## Design and operation intensification

| Item | Dissertation location | Short quote | Implementation implication | Schell relevance | Four-bed relevance | Priority |
|---|---|---|---|---|---|---|
| Manual design/operation tuning is unreliable because decisions are coupled and narrow. | Diss p. 241 (PDF p. 276), §6.2.3 | "highly coupled, have narrow feasible ranges" | Do not tune Schell pressures/valves before ledgers prove wiring, pressure semantics, and metrics. | Immediate: prevents false validation from tuned constants. | Later: four-bed schedules multiply coupling and should use manifests. | Immediate |
| Automated decision tools should use adsorbent properties and user preference trade-offs. | Diss p. 241 (PDF p. 276), §6.2.3 | "adsorbent properties and user-specified inputs" | After validation, expose design variables and objectives explicitly in a design manifest. | Later: use only after central case fidelity. | Later: can guide four-bed schedule choices after core support. | Later |
| Valve-free policy can reparameterize operation and reduce parameter count. | Diss p. 242 (PDF p. 277), §6.2.3 | "reparameterize the model for making operational decisions" | Treat valve-free logic as a separate control/planning layer that maps back to valve-based simulations. | Later: useful for reducing tuning burden, not for current Schell wiring. | Later: potentially useful once four-bed events/timeline exist. | Research-only |
| Surrogate/ML models can map design parameters to metrics. | Diss p. 242 (PDF p. 277), §6.2.3 | "train a machine learning model" | Store run manifests and outputs in machine-readable form before any surrogate work. | Later. | Later. | Research-only |
| Comparisons should identify show-stoppers and enable fairer comparisons. | Diss p. 242 (PDF p. 277), §6.2.3 | "fairer comparisons between potential game changers" | Standardize metric basis, ledgers, and unsupported-feature labels before ranking processes. | Later. | Later. | Later |

## Simulation capability development

| Item | Dissertation location | Short quote | Implementation implication | Schell relevance | Four-bed relevance | Priority |
|---|---|---|---|---|---|---|
| Current toPSAil lacks bed layering, >2 adsorbers, and multiple equalization steps. | Diss p. 243 (PDF p. 278), §6.2.4 | "does not support simulations involving adsorbent bed layering" | Treat these as explicit feature gaps. Add fail-fast guards if code paths are not implemented. | Later unless Schell uses these features. | Immediate: four-bed is a new capability, not a UI toggle. | Immediate |
| Bed layering can be implemented by assigning properties per CSTR. | Diss p. 243 (PDF p. 278), §6.2.4 | "assign different adsorbent and adsorber properties for each CSTR" | Future layered-bed manifests need CSTR-to-layer maps and per-layer adsorbent/isotherm properties. | Not immediate. | Later if four-bed system also has layered adsorbents. | Later |
| More than two adsorbers create combinatorial connection and cost challenges. | Diss p. 243 (PDF p. 278), §6.2.4 | "combinatorially increasing possible connections" | Four-bed code needs explicit schedule/pairing metadata, not inferred optimism. | Not immediate. | Immediate. | Immediate |
| DAE solvers are proposed for implicit isotherm/rate models. | Diss p. 244 (PDF p. 279), §6.2.4 | "a more natural and numerically efficient way" | Keep current ODE-with-inner-solve route for existing models; design a DAE interface only for implicit-model work. | Later. | Later. | Research-only |
| Higher-order finite volume with flux limiter may reduce nodes. | Diss p. 244 (PDF p. 279), §6.2.4 | "without sacrificing the accuracy" | Do not change the CIS discretization during Schell/four-bed wiring. Treat higher-order FVM as separate numerical research. | Not immediate. | Not immediate. | Research-only |
| TSA and SMB would require process-characteristic changes, especially boundary conditions. | Diss p. 244 (PDF p. 279), §6.2.4 | "different boundary conditions" | Keep PSA boundary semantics isolated so future TSA/SMB branches do not contaminate PSA tests. | Not immediate. | Not immediate. | Research-only |

## Visualisation and output tooling

| Item | Dissertation location | Short quote | Implementation implication | Schell relevance | Four-bed relevance | Priority |
|---|---|---|---|---|---|---|
| Future visualisation should read CSV simulation data and create animations. | Diss p. 245 (PDF p. 280), §6.2.5 | "reading in the simulation data, given as .csv files" | Design output diagnostics around exported CSV trajectories plus generated static plots/animations. | Immediate: helps expose wrong stream routing. | Immediate: essential for debugging multi-bed timelines. | Immediate |
| Visualisation should diagnose and compare dynamics/performance. | Diss p. 245 (PDF p. 280), §6.2.5 | "diagnose and compare dynamics and performance" | Build diagnostics that compare native vs reconstructed accounting, tank histories, and event timelines. | Immediate. | Immediate. | Immediate |
| Prototype animation uses population-pyramid chart features. | Diss p. 245 (PDF p. 280), §6.2.5 | "population pyramid charts" | [INFERENCE] A useful animation idiom is mirrored per-bed or per-end bar histories, not just line plots. | Later. | Later: promising for four-bed side-by-side axial/timeline views. | Later |
