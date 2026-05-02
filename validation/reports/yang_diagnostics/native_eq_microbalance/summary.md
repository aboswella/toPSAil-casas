# Native EQ micro-balance diagnostic

- Created: 2026-05-02 14:03:24
- MATLAB version: 26.1.0.3203278 (R2026a)
- Runtime seconds: 10.4003
- Branch: `codex/yang`
- Commit SHA: `3028bda948c25e5ac52115dca30368a84cfd4b01`
- Git status short:

```text
?? diagnostic_outputs/
?? scripts/four_bed/diagnoseYangNativeEqMicrobalance.m
?? scripts/four_bed/diagnoseYangNativeValveBasis.m
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

- `params.valScaleFac`: 2176282.464083839
- Raw `NativeValveCoefficient`: 1e-06
- Resolved default native valve: 2.176282464083839
- `params.nScaleFac`: 0.3084470897405255

## EQI

- Operation group ID: `EQI-A-to-C`
- Pair ID: `EQI-A-to-C`
- Source column: 3
- Duration seconds: 0.096
- Runtime seconds: 1.62745
- Resolved native valve from prep report: 2.176282464083839
- `valFeedColNorm`: [0, 0]
- `valProdColNorm`: [2.176282464083839, 2.176282464083839]
- Max balance residual: 2.36967112599018e-11
- Balance pass: `true`
- Residual pass: `true`

| Component | internal mismatch | donor residual | receiver residual | pair inventory delta | slot external residual |
|---|---:|---:|---:|---:|---:|
| H2 | -2.369667962036249e-11 | -1.375496803046258e-17 | -1.788457128568252e-17 | -2.36967112599018e-11 | 2.36967112599018e-11 |
| CO2 | -8.764525208418158e-12 | 1.235585727233586e-15 | 1.700945893152894e-15 | -8.761588676797771e-12 | 8.761588676797771e-12 |

Interpretation: Representative EQI micro-balance passes under clean synthetic state.

## EQII

- Operation group ID: `EQII-B-to-A`
- Pair ID: `EQII-B-to-A`
- Source column: 7
- Duration seconds: 0.384
- Runtime seconds: 0.815505
- Resolved native valve from prep report: 2.176282464083839
- `valFeedColNorm`: [0, 0]
- `valProdColNorm`: [2.176282464083839, 2.176282464083839]
- Max balance residual: 8.005509588571158e-10
- Balance pass: `true`
- Residual pass: `false`

| Component | internal mismatch | donor residual | receiver residual | pair inventory delta | slot external residual |
|---|---:|---:|---:|---:|---:|
| H2 | 8.005509520512061e-10 | 8.923396888875136e-06 | -8.924997990786045e-06 | -8.005509588571158e-10 | 8.005509588571158e-10 |
| CO2 | 2.668503133738647e-10 | 1.927345878715322e-06 | -1.927879551814784e-06 | -2.668227860880279e-10 | 2.668227860880279e-10 |

Interpretation: Internal cancellation and pair inventory delta pass, but donor/receiver residuals fail with opposite signs; this points to local role or counter-direction interpretation rather than a gross pair mass leak.

## Output files

- `native_eq_microbalance_residuals.csv`
- `EQI_stream_rows.csv`
- `EQII_stream_rows.csv`
- `EQI_balance_rows.csv`
- `EQII_balance_rows.csv`
- `EQI_native_counter_tail_report.txt`
- `EQII_native_counter_tail_report.txt`
- `native_eq_microbalance_report.mat`
