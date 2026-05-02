# One-cycle EQII slot-7 trace

- Created: 2026-05-02 14:07:11
- MATLAB version: 26.1.0.3203278 (R2026a)
- Runtime seconds: 36.6323
- Branch: `codex/yang`
- Commit SHA: `3028bda948c25e5ac52115dca30368a84cfd4b01`
- Git status short:

```text
?? diagnostic_outputs/
?? scripts/four_bed/diagnoseYangNativeEqMicrobalance.m
?? scripts/four_bed/diagnoseYangNativeValveBasis.m
?? scripts/four_bed/diagnoseYangOneCycleEqiiTrace.m
?? scripts/four_bed/diagnostics/
?? validation/reports/yang_diagnostics/
```

- Recent commits:

```text
3028bda Revert native Cv sentinel pinning
aca7c2d Cull Yang Cv controls to direct transfers
15da510 Add fixed ADPP BF split control
46f9aa1 Apply Yang surrogate scaling corrections
c02a200 Set aggressive Yang solver tolerances
```

- Run completed: `true`
- Balance pass: `true`
- Metrics pass: `true`
- CSS pass: `false` (not meaningful for one cycle; reported only because the simulation API computes it)
- Max absolute residual: 3.663473218376125e-11
- Cycle 1 slot 7 EQII reproduced balance failure: `false`
- Operation group ID: `EQII-B-to-A`
- Participants: B, A
- Resolved native valve: 2.176282464083839
- `valFeedColNorm`: [0, 0]
- `valProdColNorm`: [2.176282464083839, 2.176282464083839]

## Component Trace

| Component | internal out | internal in | bed donor delta | bed receiver delta | slot external residual | slot internal residual | cycle external residual |
|---|---:|---:|---:|---:|---:|---:|---:|
| H2 | 8.250491444783963e-05 | 8.25049144492243e-05 | 8.250491446487596e-05 | -8.250491445455088e-05 | -1.032507412901396e-14 | 1.384675252062706e-15 | 3.605509814319507e-11 |
| CO2 | 2.218088600072631e-07 | 2.21808860009137e-07 | 2.218088608341162e-07 | -2.218088615280056e-07 | 6.938893903907228e-16 | 1.873980986461334e-18 | 1.17723136469107e-11 |

## Adapter Trace Magnitudes

| Operation | Family | Max adapter conservation residual | Ledger rows appended |
|---|---|---:|---:|
| ADPP_BF-A-to-B | ADPP_BF | 1.078394764998785e-12 | 12 |
| PP_PU-D-to-C | PP_PU | 2.753844652379293e-12 | 10 |
| ADPP_BF-B-to-C | ADPP_BF | 6.168988186055668e-14 | 12 |
| PP_PU-A-to-D | PP_PU | 1.420692371058791e-13 | 10 |
| PP_PU-B-to-A | PP_PU | 3.230963896606261e-14 | 10 |
| ADPP_BF-C-to-D | ADPP_BF | 2.87598697466379e-14 | 12 |
| PP_PU-C-to-B | PP_PU | 8.2688356550376e-14 | 10 |
| ADPP_BF-D-to-A | ADPP_BF | 8.477717771357605e-14 | 12 |

## Micro-Diagnostic Comparison

- Micro summary available: `true`
- Isolated EQII residual pass from summary: `false`
- Compared against: `C:\dev\psa\toPSAil-casas\validation\reports\yang_diagnostics\native_eq_microbalance\summary.md`

## Prior Operations Touching EQII Beds

| Operation | Family | Source col | Participants | Touching beds |
|---|---|---:|---|---|
| AD-A-col01 | AD | 1 | A | A |
| EQI-D-to-B | EQI | 1 | D+B | B |
| ADPP_BF-A-to-B | ADPP_BF | 2 | A+B | A+B |
| AD-B-col03 | AD | 3 | B | B |
| EQI-A-to-C | EQI | 3 | A+C | A |
| ADPP_BF-B-to-C | ADPP_BF | 4 | B+C | B |
| PP_PU-A-to-D | PP_PU | 4 | A+D | A |
| EQII-A-to-D | EQII | 5 | A+D | A |
| EQI-B-to-D | EQI | 5 | B+D | B |
| BD-A-col06 | BD | 6 | A | A |
| PP_PU-B-to-A | PP_PU | 6 | B+A | B+A |

## Interpretation

Case A: one-cycle current branch passes; the previous failure is not reproduced under the current codex/yang baseline. EQII slot residuals are nonzero but below configured tolerance.

Next recommended action: stop this diagnostic campaign and record that the current branch does not reproduce the prior EQII balance failure under baseline settings.
