# Yang metric accounting ladder diagnostic

## Run identity
- Branch: `codex/yang`
- Commit SHA: `cc0435d62a7ee3f9dedffe9868cd2a47617c7cfb`
- Git status:
```text
?? diagnostic_outputs/
?? scripts/four_bed/diagnoseYangMetricAccountingLadder.m
?? scripts/four_bed/diagnostics/
```
- MATLAB version: `26.1.0.3203278 (R2026a)`
- Runtime: 61.879 s
- Cycles used: 3
- Exact baseline params: `NVols=2, NCols=2, NSteps=1, NTimePoints=21, CycleTimeSec=2.4, FinalizeForRuntime=true`
- Exact baseline controls: `cycleTimeSec=2.4, Cv_directTransfer=1e-6, ADPP_BF_internalSplitFraction=1/3, balanceAbsTol=1e-8, balanceRelTol=1e-6`
- `params.valScaleFac`: 2176282.464083839
- Raw native valve coefficient: 1e-06
- Resolved native valve coefficient: 2.176282464083839
- `Cv_directTransfer`: 1e-06

## Pass/fail headline
- Run completed: yes
- Balance pass: yes
- Metrics pass: yes
- CSS pass: no. CSS is not meaningful after only 3 cycle(s); this diagnostic does not use CSS as evidence of convergence.
- Max balance residual: 3.66347e-11 mol
- Failing balance rows: 0
- Old EQII balance failure reproduced: no

## H2 accounting conclusion
- Reported recovery is `external_product_H2 / external_feed_H2`. Through cycle 3, cumulative recovery is 0.475112.
- The cumulative H2 fractions are waste 0.288726 and bed inventory delta 0.236162, with residual 3.39997e-11 mol.
- The balance-predicted recovery column uses `(feed - waste - bed_delta) / feed`, so inventory release or accumulation is visible without calling a closed ledger a metric failure.
- The apparent recovery behavior is explainable from the ledger: waste is larger than inventory delta on the cumulative H2 feed basis.

## Product/waste source conclusion
- Dominant external product family: `AD`.
- Dominant external waste family: `BD`.
- ADPP_BF external product H2 / total external product H2: 1.83583e-08.
- PP_PU waste H2 / total external waste H2: 1.57652e-06; BD waste H2 / total external waste H2: 0.999998.

## Adapter magnitude conclusion
- ADPP_BF internal transfer H2 / total internal-transfer-out H2: 1.25437e-07.
- Max adapter external product relative to same-cycle native AD product: 2.3148e-07, classified as negligible at a 0.01 diagnostic threshold.
- Max adapter internal transfer relative to same-cycle native EQ transfer: 3.52566e-07, classified as negligible at the same diagnostic threshold.
- Adapter conservation residual max across adapter rows: 2.75384e-12.
- The adapters are small against native AD/native EQ flows in this baseline, so this report does not recommend a split sweep.

## Paired-operation direction conclusion
- Inventory-delta donor/receiver contradictions flagged: 14 total; EQII: 9.
- Slot/cycle mass balance remains the governing check here: balance pass is yes.
- Native EQ pressure diagnostics are recorded as `not_available` when the operation report does not expose clean initial/terminal pressure summaries.

## Recommended next smallest task
- stop diagnostics and proceed to parameter/performance calibration

## Artifacts
- `cycle_h2_accounting.csv`
- `cumulative_h2_accounting.csv`
- `stage_scope_decomposition.csv`
- `operation_h2_decomposition.csv`
- `adapter_magnitude_summary.csv`
- `paired_operation_direction_audit.csv`
- `failing_balance_rows.csv`
- `metric_accounting_ladder_report.mat`
