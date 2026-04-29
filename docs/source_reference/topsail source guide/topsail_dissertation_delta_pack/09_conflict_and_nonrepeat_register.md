# 09 - Conflict, refinement, and non-repeat register

Use this file to prevent future agents from wasting context on material already extracted from the shorter toPSAil paper pack. The universe is expanding, but Codex context windows are not.

## Already covered by the earlier paper extraction pack

| Topic already covered | Dissertation restatement source | Delta status |
|---|---|---|
| Fixed PFD sections and feed/raffinate/extract tank semantics | Diss p. 193-196 (PDF p. 228-231), §4.1.1 | No delta extracted for the broad PFD idea. Deltas retained only for valve numbering, product outlet behavior, extract compression to `P_f`, and two-column limitation. |
| Dynamic tank concept | Diss p. 130-140 (PDF p. 165-175), §3.2 | No delta extracted for "tanks are dynamic well-mixed units". Deltas retained for tank-volume normalization, MFC control laws, and product tank outlet/check behavior. |
| Step-string grammar and examples | Diss p. 201-202 (PDF p. 236-237), §4.2.2 | No delta extracted for `STEP-FEEDEND-PRODUCTEND` or `HP-FEE-RAF` examples. Deltas retained for event-location limits and automatic boundary-condition assignment. |
| Pressure-driven vs flow-driven simulation modes | Diss p. 199-200 (PDF p. 234-235), §4.2.2 | No delta extracted for the basic mode distinction. Deltas retained for solver/workflow implications, exact product-tank control in flow-driven mode, and numerical diagnostics. |
| Event termination concept | Diss p. 130 (PDF p. 165), §3.1.9; Diss p. 201 (PDF p. 236), §4.2.2 | No delta extracted for event termination existing. Deltas retained for event locations, cumulative-product-purity control, CSS acceleration, and event conflicts. |
| Flow reversals are supported | Diss p. 229-230 (PDF p. 264-265), §5.5.1 | No delta extracted for the mere fact of reversal support. Deltas retained for reversal causes and balance-violation tests. |
| Native metrics are not automatically literature metrics | Diss p. 161-164 (PDF p. 196-199), §3.6 | No delta extracted for the broad warning. Deltas retained for formula-level nuance and a possible conflict with earlier native metric wording. |
| Four-bed extension hazards | Diss p. 239 (PDF p. 274), §6.1; Diss p. 243 (PDF p. 278), §6.2.4 | No delta extracted for generic caution. Major delta retained: dissertation says current version does not support >2 adsorbers. |

## Dissertation items that refine or contradict the earlier pack

| Issue | Dissertation evidence | Earlier-pack implication | Refinement for future Codex |
|---|---|---|---|
| Four-bed support is stronger-limited than previously framed | Diss p. 243 (PDF p. 278), §6.2.4 says toPSAil "does not support" more than two adsorbers. Diss p. 239 (PDF p. 274), §6.1 says steps consider up to two-adsorber interactions. | Earlier pack treated code as possibly supporting multiple adsorbers while UI was two-bed limited. | Treat four-bed as unsupported until audited and implemented. Add fail-fast gates. |
| Product purity formula may be tank-state based in dissertation | Diss p. 163 (PDF p. 198), §3.6.2 defines purity as `c^t_{n,i}(t_f,m)/c^t_n(t_f,m)`. | Earlier pack described native purity as product generated during a cycle. | Verify current `getPerformanceMetrics.m`. For literature comparisons, reconstruct source metrics from ledgers regardless of native label. |
| Product recovery uses stream after product tank | Diss p. 163 (PDF p. 198), §3.6.3 defines recovery using `N^c_n,i` in the stream after the product tank divided by feed cumulative moles. | Earlier pack warned native tank/product streams differ, but not this exact formula. | Export column boundary, tank inventory, and external outlet ledgers separately. |
| Plain BPR is not a check valve | Diss p. 146-147 (PDF p. 181-182), §3.3.4 says a BPR can allow flow either way if upstream exceeds set pressure; combined BPR/check uses `max`. | Earlier pack grouped product outlet behavior at a higher level. | When adding valves, distinguish linear valve, BPR, check valve, and combined BPR/check. |
| Implicit model support is nuanced | Diss p. 266-267 (PDF p. 301-302), §D.1.5 includes implicit multi-site Langmuir solved with fsolve; Diss p. 241 and p. 244 (PDF p. 276 and 279), §6.2.2/§6.2.4 make general implicit procedures future work. | Earlier pack focused on current LDF/isotherm assumptions. | Do not infer general gL/MS-LDF support from one implicit equilibrium solve. |
| Event-driven CSS acceleration is not universal | Diss p. 236 (PDF p. 271), §5.5.3 says pressure-driven simulations did not show the same trend. | Earlier pack noted events may reduce cycles and conflicts exist. | Report mode-specific evidence. Do not promise acceleration for pressure-driven runs. |
| No-pressure-drop reversals can be adsorption-sink-driven | Diss p. 230 (PDF p. 265), §5.5.1 says high adsorption rate can make inflow to each CSTR exceed outflow. | Earlier pack warned flow-driven mode may violate pressure-gradient intuition. | Add adsorption-rate terms to reversal diagnostics. |
| Output visualisation roadmap is CSV-animation oriented | Diss p. 245 (PDF p. 280), §6.2.5 says future tool will read `.csv` and create animations. | Earlier pack asked for ledgers but did not source animation tooling. | Build CSV-first dashboards and timeline/animation scripts. |

## Unresolved ambiguities requiring human decision

| Ambiguity | Dissertation source | Why it matters | Human decision needed |
|---|---|---|---|
| Schell fixed-composition purge source vs native dynamic tanks | Diss p. 137-140 (PDF p. 172-175), §3.2.5; Diss p. 193-196 (PDF p. 228-231), §4.1.1 | Native tanks are dynamic and product tanks can feed adsorbers. A fixed equimolar purge may require PFD extension or custom boundary. | Choose native approximation, custom boundary, or PFD extension, and label validation status. |
| Metric basis for publication comparison | Diss p. 161-164 (PDF p. 196-199), §3.6 | Dissertation native metrics may not match Schell's literature accounting. | Decide which reconstructed metrics are reported as source-comparable. |
| Whether to preserve Excel as canonical input or create a manifest-first route | Diss p. 202-204 (PDF p. 237-239), §4.2.3; Diss p. 273-277 (PDF p. 308-312), Appendix E §E.4.1 | Current workflow imports `.xlsm`, validates types, scales, and builds `params`. | Decide whether manifests generate Excel-compatible hidden data, feed `params` directly, or both. |
| DAE solver priority for implicit adsorption models | Diss p. 241 (PDF p. 276), §6.2.2; Diss p. 244 (PDF p. 279), §6.2.4 | gL/MS-LDF need implicit procedures, but Schell/four-bed routing does not. | Decide whether implicit-model implementation is in scope before validation tasks. |
| Four-bed event priority policy | Diss p. 235-236 (PDF p. 270-271), §5.5.3 | No general conflict-resolution approach is given. | Define source-specific priority, fixed-duration fallback, or multi-objective event handling. |
| Four-bed equalisation representation | Diss p. 239 (PDF p. 274), §6.1; Diss p. 243 (PDF p. 278), §6.2.4 | Existing step list is two-adsorber scoped and multiple equalisation is unsupported. | Decide explicit pair-map schema and whether multiple equalisation stages are allowed. |
| Node-count/MTZ rule | Diss p. 249 (PDF p. 284), Appendix B §B.1 | Numerical diffusion depends on node count, but no direct node-setting rule is given beyond adequate MTZ nodes. | Define a benchmark-specific node-count selection and sensitivity policy. |
| Energy accounting for feed compression/vacuum | Diss p. 164 (PDF p. 199), §3.6.5 | Feed compression can be skipped if feed is already above `P_f`; vacuum skipped if `P_l >= P_a`. | Decide whether literature comparison includes or excludes these native energy terms. |

## Do not bother Codex with these sections unless the task explicitly needs them

| Section | Why not needed for current Schell/four-bed work |
|---|---|
| Chapter 1 general PSA background, except §1.3.2 and §1.3.3 | The background is conceptual. Deltas retained only for unsupported emerging models and design-rule motivation. Sources: Diss p. 22-26 (PDF p. 57-61), §1.3. |
| Chapter 3 detailed adsorber derivations outside targeted tank/valve/metric/nondimensionalization details | Existing pack already captures the CIS model contract. Use only if changing balances or scaling. Sources: Diss p. 73-129 in Chapter 3, especially §3.1. |
| §3.7.2 detailed fixed-bed nondimensional derivation | Only scaling constants and dimensionless contract are needed now; the derivation is not implementation-changing unless rewriting core equations. Source: Diss p. 166-180 (PDF p. 201-215), §3.7.2. |
| Appendix A supporting calculations | It contains broad energy analogies and back-of-envelope calculations, not toPSAil implementation deltas. Source: Diss p. 247 (PDF p. 282), Appendix A. |
| Appendix C sample numeric calculations | Useful only for equilibrium-theory sanity checks or design normalisation, not for Schell stream routing or four-bed scheduler work. Source: Diss p. 254-258 (PDF p. 289-293), Appendix C §C.1.1-§C.2.1. |
| GUI screenshots and button-click instructions in Appendix E | Useful for human users, not Codex agents. Retain only folder trees, run entry points, input categories, and macro/import constraints. Source: Diss p. 274-278 (PDF p. 309-313), Appendix E §E.4. |
| Long pressure-changer thermodynamic derivation | Retain only isentropic assumption, efficiency, and energy metric implications unless rewriting compressor/vacuum work. Source: Diss p. 147-158 (PDF p. 182-193), §3.4. |
| TSA/SMB future extension discussion | Research-only and not needed for PSA Schell/four-bed tasks. Source: Diss p. 244 (PDF p. 279), §6.2.4. |
