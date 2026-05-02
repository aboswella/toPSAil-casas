# Yang adapter Cv activation diagnostic

## Run metadata
- Branch: `codex/yang`
- Commit: `1f42e286f572006d3a4c0b306a4d50444c038cee`
- MATLAB version: `26.1.0.3203278 (R2026a)`
- Runtime: 302.275 s
- Dirty/untracked status:
```text
?? diagnostic_outputs/
?? scripts/four_bed/diagnoseYangAdapterCvActivation.m
?? scripts/four_bed/diagnostics/
```

## Baseline conclusion
- The previous accounting run showed low H2 recovery as a real wrapper-ledger outcome, with product dominated by native AD, waste dominated by native BD, and adapters at spectator scale.
- NativeValveCoefficient remains 1e-06 raw and resolves to 2.17628 through `params.valScaleFac`; adapter `Cv_directTransfer` remains raw/direct.

## One-cycle ladder table
| Cv | recovery | ADPP product/total | PP_PU waste/total | adapter internal/total | balance | class | runtime s |
|---:|---:|---:|---:|---:|---|---|---:|
| 1e-06 | 0.492403 | 6.8485e-09 | 1.57532e-06 | 4.96877e-07 | yes | spectator | 32.87 |
| 1e-05 | 0.492403 | 6.8485e-08 | 1.5753e-05 | 4.96875e-06 | yes | spectator | 25.33 |
| 1e-04 | 0.492402 | 6.84854e-07 | 0.000157507 | 4.9685e-05 | yes | spectator | 29.67 |
| 1e-03 | 0.492389 | 6.84891e-06 | 0.00157284 | 0.000496605 | yes | spectator | 24.73 |
| 1e-02 | 0.492256 | 6.85258e-05 | 0.015508 | 0.00494169 | yes | activated | 22.48 |

## Adapter operation details
- Adapter pressure diagnostics available: yes. Max initial product-end pressure delta 0.106227; max initial feed-end pressure delta 0.106227; max flow-sign warnings per adapter operation 0.
- Low-Cv scaling: `approximately_linear`; adapter stream magnitude per Cv stayed within a factor of two.

## Three-cycle confirmation
| Cv | cumulative recovery | product/feed | waste/feed | bed accumulation/feed | balance | runtime s |
|---:|---:|---:|---:|---:|---|---:|
| 1e-06 | 0.475112 | 0.475112 | 0.288726 | 0.236162 | yes | 85.25 |
| 1e-02 | 0.474593 | 0.474593 | 0.292889 | 0.232518 | yes | 79.09 |

## Interpretation
- Category B: Cv activation merely increases losses.
- Reason: adapter streams grew, but recovery did not improve materially; best recovery delta -0.000519163 and best waste-fraction delta 0.00416354.

## Recommendation
- inspect PP->PU and ADPP_BF endpoint pressure policies before calibration
