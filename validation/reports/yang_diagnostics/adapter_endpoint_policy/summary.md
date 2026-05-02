# Yang adapter endpoint-policy perturbation diagnostic

## Run metadata
- branch: `codex/yang`
- commit: `6ba57caad04050676798531e5772c10fffa36e93`
- MATLAB version: `26.1.0.3203278 (R2026a)`
- runtime: 74.314 s
- dirty/untracked status:
```text
?? diagnostic_outputs/
?? scripts/four_bed/diagnoseYangAdapterEndpointPolicy.m
?? scripts/four_bed/diagnostics/
?? validation/reports/yang_diagnostics/adapter_cv_activation/adapter_operation_details.zip
```

## Prior finding
- The prior `adapter_cv_activation` run found that `Cv_directTransfer = 1e-2` increased adapter streams but slightly reduced cumulative H2 recovery, with waste/feed increasing and bed accumulation/feed decreasing.

## Selected operation context
| operation | family | donor->receiver | product delta | donor product P | receiver product P | receiver feed P | reason |
|---|---|---|---:|---:|---:|---:|---|
| PP_PU-A-to-D | PP_PU | A->D | 0.106227 | 0.826442 | 0.720215 | 0.720215 | requested_by_prompt |
| PP_PU-B-to-A | PP_PU | B->A | -0.0228653 | 0.758118 | 0.780983 | 0.780983 | requested_by_prompt |
| PP_PU-C-to-B | PP_PU | C->B | -0.0245171 | 0.724001 | 0.748518 | 0.748518 | requested_by_prompt |
| ADPP_BF-A-to-B | ADPP_BF | A->B | 0.0362398 | 1 | 0.96376 | 0.96376 | requested_by_prompt |
| ADPP_BF-D-to-A | ADPP_BF | D->A | -0.0686597 | 0.704835 | 0.773495 | 0.773495 | requested_by_prompt |

## PP_PU endpoint variants
| operation | variant | waste P | internal H2 | waste H2 | waste/internal | near-zero internal waste | residual | warnings |
|---|---|---:|---:|---:|---:|---|---:|---:|
| PP_PU-A-to-D | current_low_pressure_basis | 0.144444 | 1.40689e-06 | 1.82202e-05 | 12.9506 | no | 1.41e-09 | 0 |
| PP_PU-A-to-D | receiver_waste_0p50 | 0.5 | 1.4066e-06 | 6.84585e-06 | 4.86694 | no | 1.41e-09 | 0 |
| PP_PU-A-to-D | receiver_waste_0p75 | 0.75 | 1.40643e-06 | 0 | 0 | no | 1.42e-09 | 0 |
| PP_PU-A-to-D | receiver_waste_0p90 | 0.9 | 1.40643e-06 | 0 | 0 | no | 1.42e-09 | 0 |
| PP_PU-A-to-D | initial_receiver_feed_pressure | 0.720215 | 1.40643e-06 | 0 | 0 | no | 1.42e-09 | 0 |
| PP_PU-B-to-A | current_low_pressure_basis | 0.144444 | 0 | 5.09632e-06 | NaN | yes | 2.91e-10 | 0 |
| PP_PU-B-to-A | receiver_waste_0p50 | 0.5 | 0 | 2.2461e-06 | NaN | yes | 3.79e-10 | 0 |
| PP_PU-B-to-A | receiver_waste_0p75 | 0.75 | 0 | 2.42042e-07 | NaN | yes | 4.42e-10 | 0 |
| PP_PU-B-to-A | receiver_waste_0p90 | 0.9 | 0 | 0 | NaN | no | 3.22e-15 | 0 |
| PP_PU-B-to-A | initial_receiver_feed_pressure | 0.780983 | 0 | 0 | NaN | no | 3.22e-15 | 0 |
| PP_PU-C-to-B | current_low_pressure_basis | 0.144444 | 0 | 4.84224e-06 | NaN | yes | 8.36e-10 | 0 |
| PP_PU-C-to-B | receiver_waste_0p50 | 0.5 | 0 | 1.98976e-06 | NaN | yes | 8.3e-10 | 0 |
| PP_PU-C-to-B | receiver_waste_0p75 | 0.75 | 0 | 0 | NaN | no | 1.11e-16 | 0 |
| PP_PU-C-to-B | receiver_waste_0p90 | 0.9 | 0 | 0 | NaN | no | 1.11e-16 | 0 |
| PP_PU-C-to-B | initial_receiver_feed_pressure | 0.748518 | 0 | 0 | NaN | no | 1.11e-16 | 0 |

## ADPP_BF endpoint variants
| operation | variant | product P | feed H2 | product H2 | internal H2 | product/feed | internal/feed | residual | warnings |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| ADPP_BF-A-to-B | current_default | 1 | 1.59274e-06 | 5.48173e-07 | 2.74086e-07 | 0.344169 | 0.172084 | 1.08e-08 | 0 |
| ADPP_BF-A-to-B | external_product_0p90 | 0.9 | 1.59277e-06 | 9.07143e-07 | 4.53572e-07 | 0.569536 | 0.284768 | 1.49e-08 | 0 |
| ADPP_BF-A-to-B | external_product_0p75 | 0.75 | 1.59288e-06 | 2.81063e-06 | 1.40531e-06 | 1.7645 | 0.882248 | 2.13e-08 | 0 |
| ADPP_BF-A-to-B | external_product_0p50 | 0.5 | 1.59306e-06 | 6.30081e-06 | 3.1504e-06 | 3.95517 | 1.97758 | 1.78e-08 | 0 |
| ADPP_BF-A-to-B | external_product_low_pressure | 0.144444 | 1.59331e-06 | 1.12646e-05 | 5.63231e-06 | 7.06994 | 3.53497 | 1.64e-08 | 0 |
| ADPP_BF-D-to-A | current_default | 1 | 4.60601e-06 | 0 | 0 | 0 | 0 | 8.52e-10 | 1 |
| ADPP_BF-D-to-A | external_product_0p90 | 0.9 | 4.60601e-06 | 0 | 0 | 0 | 0 | 8.52e-10 | 1 |
| ADPP_BF-D-to-A | external_product_0p75 | 0.75 | 4.60601e-06 | 0 | 0 | 0 | 0 | 8.52e-10 | 1 |
| ADPP_BF-D-to-A | external_product_0p50 | 0.5 | 4.60611e-06 | 2.70667e-06 | 1.35333e-06 | 0.587625 | 0.293812 | 1.96e-09 | 0 |
| ADPP_BF-D-to-A | external_product_low_pressure | 0.144444 | 4.60629e-06 | 7.45941e-06 | 3.72971e-06 | 1.6194 | 0.809698 | 1.97e-09 | 0 |

## Interpretation
- C. Both endpoint policies are suspect.
- PP_PU: 2 current low-pressure PP_PU variant row(s) produced waste H2 while internal H2 was below the near-zero threshold.
- ADPP_BF: At least one lower external-product-pressure ADPP_BF variant sharply increased product H2 without a conservation or sanity failure.

## Recommendation
- Prototype isolated endpoint-policy fixes starting with PP_PU receiver-waste gating, then repeat this diagnostic before touching ADPP_BF.
