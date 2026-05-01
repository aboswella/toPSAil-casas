# Batch 4 implementation guide: AD&PP→BF direct-coupling adapter

## Assignment

You are implementing **Batch 4** of the final four-bed toPSAil implementation. This batch covers:

- **FI-5 Custom AD&PP→BF adapter**: implement the Yang adsorption/product/backfill direct-coupling operation with separate external-product and internal-backfill accounting.

This guide is for a fresh Codex agent working from the most recent repository snapshot, after Batch 1, Batch 2, and Batch 3 have landed. Batch 3 should already provide the PP→PU adapter and the initial shared direct-coupling dispatcher. Treat that implementation as a useful foundation, not as sacred scripture. Verify its contracts before extending them.

Place this guide in the repository at:

```text
docs/four_bed/batch_4_adpp_bf_direct_coupling_adapter_implementation_guide.md
```

## Active source of truth

Read these files before editing anything:

1. `AGENTS.md`
2. `docs/four_bed/README.md`
3. `docs/four_bed/FINAL_IMPLEMENTATION_CONTEXT.md`
4. `docs/four_bed/batch_1_schedule_state_persistence_implementation_guide.md`
5. `docs/four_bed/batch_2_h2co2_ac_parameter_pack_implementation_guide.md`
6. `docs/four_bed/batch_3_pp_pu_direct_coupling_adapter_implementation_guide.md`
7. `docs/BOUNDARY_CONDITION_POLICY.md`
8. `docs/KNOWN_UNCERTAINTIES.md`
9. `docs/TEST_POLICY.md`
10. `docs/CODEX_PROJECT_MAP.md`

The old WP1-WP5 docs and `docs/workflow/*.csv` files are legacy. Use them only for historical rationale, old test IDs, or risk cross-checking. They do not define this batch.

## Current repository baseline from previous batches

Batch 1 should have implemented normalized schedule helpers and physical-state-only persistence:

- `scripts/four_bed/getYangNormalizedSlotDurations.m`
- `scripts/four_bed/getYangFourBedScheduleManifest.m`
- `scripts/four_bed/extractYangPhysicalBedState.m`
- `scripts/four_bed/extractYangCounterTailDeltas.m`
- `scripts/four_bed/writeBackYangFourBedStates.m`
- `scripts/four_bed/computeYangFourBedCssResiduals.m`

Batch 2 should have implemented the Yang H2/CO2 homogeneous activated-carbon surrogate parameter pack:

- `params/yang_h2co2_ac_surrogate/buildYangH2Co2AcTemplateParams.m`
- `params/yang_h2co2_ac_surrogate/yangH2Co2AcSurrogateConstants.m`
- `params/yang_h2co2_ac_surrogate/testYangAcDslMapping.m`
- `cases/yang_h2co2_ac_surrogate/case_spec.md`

Batch 3 should have implemented the PP→PU adapter and an initial direct-coupling adapter pattern:

- `scripts/four_bed/runYangDirectCouplingAdapter.m`
- `scripts/four_bed/runYangPpPuAdapter.m`
- `scripts/four_bed/validateYangDirectCouplingAdapterInputs.m`
- `scripts/four_bed/prepareYangAdapterLocalRunParams.m`
- `scripts/four_bed/calcYangPpPuBoundaryFlows.m`
- `scripts/four_bed/integrateYangPpPuAdapterFlows.m`
- `scripts/four_bed/computeYangBedComponentInventory.m`
- `scripts/four_bed/summarizeYangBedPressureProfile.m`
- `scripts/four_bed/zeroYangAdapterAuxiliaryVolFlows.m`
- `tests/four_bed/testYangPpPuAdapterContract.m`
- `tests/four_bed/testYangPpPuAdapterConservation.m`
- `scripts/run_adapter_tests.m`

Important caveat: the Batch 2 builder may be a template/parameter pack, not a fully runnable initialized toPSAil case in all environments. Follow the Batch 3 precedent: if a dynamic run is blocked by missing runtime fields, fail explicitly with a targeted error and keep the structural/API tests meaningful. Do not silently fabricate solver fields.

## Scope boundaries

### You own

Primary implementation files:

- `scripts/four_bed/runYangDirectCouplingAdapter.m`
- `scripts/four_bed/runYangAdppBfAdapter.m`

Recommended helper files, if they keep the implementation readable:

- `scripts/four_bed/validateYangAdppBfAdapterInputs.m`
- `scripts/four_bed/prepareYangAdppBfAdapterLocalRunParams.m`
- `scripts/four_bed/calcYangAdppBfBoundaryFlows.m`
- `scripts/four_bed/integrateYangAdppBfAdapterFlows.m`

Shared helpers that you may reuse but should not damage:

- `scripts/four_bed/computeYangBedComponentInventory.m`
- `scripts/four_bed/summarizeYangBedPressureProfile.m`
- `scripts/four_bed/extractYangPhysicalBedState.m`
- `scripts/four_bed/extractYangTerminalLocalStates.m`
- `scripts/four_bed/zeroYangAdapterAuxiliaryVolFlows.m`

Tests:

- `tests/four_bed/testYangAdppBfAdapterContract.m`
- `tests/four_bed/testYangAdppBfAdapterSplitConservation.m`

Existing test to preserve and, if useful, reference:

- `tests/four_bed/testYangAdppBfLedgerSplit.m`

Optional runner update:

- `scripts/run_adapter_tests.m`

### You may make a narrow interface hook

You may make a small adapter-dispatch change to:

- `scripts/four_bed/runYangDirectCouplingAdapter.m`

The only required dispatcher change is:

```matlab
case "ADPP_BF"
    [terminalLocalStates, adapterReport] = runYangAdppBfAdapter( ...
        tempCase, templateParams, adapterConfig);
```

You may refactor Batch 3 helper code only if it is necessary and low risk. If you refactor, preserve all existing PP→PU test behavior and error identifiers unless there is a documented reason to change them. In practice, it is safer to add AD&PP→BF-specific helpers rather than mutate the PP→PU helpers into a premature framework. Humanity has suffered enough from premature frameworks.

### You must not own

Do not implement or materially change:

- PP→PU logic except to preserve compatibility with the shared dispatcher.
- Full four-bed cycle driver. That is Batch 5.
- Final wrapper-owned H2 purity/recovery reconstruction. That is Batch 5.
- Adapter audit file writing. Batch 4 should return an in-memory `adapterReport`; compact audit export belongs to Batch 5 unless an existing runner already writes reports.
- Dynamic internal tanks or shared headers.
- A global four-bed RHS/DAE.
- Event-based Yang scheduling.
- Core adsorber physics in `3_source/`, including mass, energy, isotherm, momentum, valve, or solver equations.
- Zeolite, CO, CH4, pseudo-components, layered-bed behavior, or full Yang reproduction.

Do not use a fake raffinate/product tank as the production architecture for the internal BF stream. External feed and external product can be represented as external boundary/reservoir interactions; the BF transfer itself is a direct bed-to-bed product-end coupling with zero holdup.

## Non-negotiable architecture

The AD&PP→BF adapter must preserve the final architecture:

1. Four persistent named bed states remain outside the adapter.
2. The adapter receives only a temporary two-bed local case.
3. Local bed 1 is the AD&PP donor.
4. Local bed 2 is the BF receiver.
5. Donor feed-end gas comes from the external feed basis.
6. Donor product-end gas is split into:
   - external product; and
   - internal BF transfer to the receiver product end.
7. Receiver product-end inflow is the internal BF stream only.
8. The BF receiver feed end is closed for this operation.
9. There is no dynamic internal tank, no shared header, and no hidden internal holdup.
10. Internal BF transfer is not external product.
11. Terminal local states returned by the adapter are physical adsorber states only.
12. Counters and stream integrals are adapter accounting data only.

## AD&PP→BF semantics

### Physical meaning

The AD&PP donor performs adsorption while also providing gas for backfill. The donor receives external feed through its feed end. Product-side gas leaves the donor product end. Part of that product-side gas leaves the PSA system as external H2-rich product. The rest flows directly into the BF receiver at the receiver product end, raising the receiver pressure toward the high-pressure adsorption class.

For the local two-bed case:

| Local index | Role | Yang label | Endpoint behavior |
|---:|---|---|---|
| 1 | donor | `AD&PP` | feed-end external feed in; product-end external product out plus internal BF out |
| 2 | receiver | `BF` | product-end internal BF in; feed end closed |

The pair map already defines AD&PP→BF pair identities. Expected family pairs are:

| Family | Donor | Receiver |
|---|---|---|
| `ADPP_BF` | A | B |
| `ADPP_BF` | B | C |
| `ADPP_BF` | C | D |
| `ADPP_BF` | D | A |

Use `getYangDirectTransferPairMap` and `selectYangFourBedPairStates`. Never infer the receiver from source table row order, bed adjacency, or native two-bed defaults.

### Accounting meaning

AD&PP→BF produces:

- one external feed stream into the donor feed end;
- one external product stream out of the donor product end;
- one internal BF transfer stream out of the donor product end;
- one matching internal BF transfer stream into the receiver product end;
- no receiver external waste;
- physical bed inventory changes for donor and receiver.

Required stream categories:

| Stream | Scope | Direction | Endpoint | Counts in H2 recovery? |
|---|---|---|---|---|
| donor feed in | `external_feed` | `in` | `feed_end` | Denominator only |
| donor external product out | `external_product` | `out` | `product_end` | Yes |
| donor internal BF out | `internal_transfer` | `out_of_donor` | `product_end` | No |
| receiver internal BF in | `internal_transfer` | `into_receiver` | `product_end` | No |
| bed inventory change | `bed_inventory_delta` | `delta` | `not_applicable` | No |

Internal donor-out and receiver-in should match componentwise within tolerance in the same unit basis. They cancel at the pair level and must not appear as external product.

## Adapter API contract

### `runYangDirectCouplingAdapter.m`

Update the existing shared dispatcher. Required signature remains:

```matlab
function [terminalLocalStates, adapterReport] = runYangDirectCouplingAdapter(tempCase, templateParams, adapterConfig)
```

Required behavior after Batch 4:

```matlab
family = string(tempCase.directTransferFamily);
switch family
    case "PP_PU"
        [terminalLocalStates, adapterReport] = runYangPpPuAdapter( ...
            tempCase, templateParams, adapterConfig);
    case "ADPP_BF"
        [terminalLocalStates, adapterReport] = runYangAdppBfAdapter( ...
            tempCase, templateParams, adapterConfig);
    otherwise
        error('FI5:UnsupportedDirectCouplingFamily', ...
            'Unsupported directTransferFamily %s.', char(family));
end
```

Preserve the existing PP→PU behavior and tests. If existing PP→PU tests expect `FI4:UnsupportedDirectCouplingFamily` for non-PP families, update only those tests that are now invalid because ADPP_BF is implemented. Do not make PP→PU tests pass by pretending ADPP_BF is still unimplemented.

### `runYangAdppBfAdapter.m`

Required signature:

```matlab
function [terminalLocalStates, adapterReport] = runYangAdppBfAdapter(tempCase, templateParams, adapterConfig)
```

Required inputs:

- `tempCase`: a two-bed temporary case built from `makeYangTemporaryPairedCase`.
- `templateParams`: initialized two-column toPSAil-compatible params, or a params template that the adapter can complete without changing core physics.
- `adapterConfig`: control and diagnostics structure.

Required output:

- `terminalLocalStates`: a 2-by-1 cell array in `tempCase.localMap.local_index` order.
  - Each cell must be a physical-state payload compatible with `extractYangPhysicalBedState`.
  - Do not return native counter tails as persistent bed state.
- `adapterReport`: a scalar struct with identity, controls, pressure diagnostics, integrated branch flows, effective split ratios, conservation residuals, sanity diagnostics, and warnings.

### Required `adapterReport` schema

Use these groups. Field names can be MATLAB-style, but do not omit the information.

```matlab
adapterReport = struct();
adapterReport.version = "FI5-Yang2009-ADPP-BF-adapter-report-v1";
adapterReport.payloadType = "yang_adpp_bf_adapter_report_v1";
adapterReport.directTransferFamily = "ADPP_BF";
adapterReport.runner = "wrapper_direct_coupling_adapter";
adapterReport.nativeStepGrammarUsed = false;
adapterReport.noDynamicInternalTanks = true;
adapterReport.noSharedHeaderInventory = true;
adapterReport.noFourBedRhsDae = true;
adapterReport.noCoreAdsorberPhysicsRewrite = true;
```

Identity fields:

- `cycleIndex`, if supplied by `adapterConfig`, otherwise `NaN`.
- `slotIndex`, if supplied, otherwise `NaN`.
- `pairId`.
- `sourceColumns`.
- `donorBed`, `receiverBed`.
- `donorRecordId`, `receiverRecordId`.
- `localMap`.
- `operationGroupId`.

Control fields:

- `durationSeconds`.
- `durationDimless`.
- `timeBasis`.
- `Cv_ADPP_feed`.
- `Cv_ADPP_product`.
- `Cv_ADPP_BF_internal`.
- `feedPressureRatio` and its basis.
- `externalProductPressureRatio` and its basis.
- `allowReverseFeedFlow`.
- `allowReverseProductFlow`.
- `allowReverseInternalFlow`.
- `componentNames`.
- `conservationAbsTol`.
- `conservationRelTol`.

Diagnostics and outputs:

- `pressureDiagnostics.initial`.
- `pressureDiagnostics.terminal`.
- `flows.native`.
- `flows.moles`, if `params.nScaleFac` is available.
- `flowReport` with rate samples and flow sign summaries.
- `effectiveSplit`.
- `conservation`.
- `sanity`.
- `warnings`.

## Adapter configuration contract

Use this structure as the minimum accepted control contract:

```matlab
adapterConfig = struct();
adapterConfig.version = "FI5-Yang2009-ADPP-BF-adapter-config-v1";
adapterConfig.directTransferFamily = "ADPP_BF";
adapterConfig.durationSeconds = [];
adapterConfig.durationDimless = 0.01;
adapterConfig.Cv_ADPP_feed = 0.05;
adapterConfig.Cv_ADPP_product = 0.02;
adapterConfig.Cv_ADPP_BF_internal = 0.02;
adapterConfig.feedPressureRatio = [];
adapterConfig.externalProductPressureRatio = [];
adapterConfig.allowReverseFeedFlow = false;
adapterConfig.allowReverseProductFlow = false;
adapterConfig.allowReverseInternalFlow = false;
adapterConfig.componentNames = ["H2"; "CO2"];
adapterConfig.conservationAbsTol = 1e-8;
adapterConfig.conservationRelTol = 1e-6;
adapterConfig.debugKeepStateHistory = false;
adapterConfig.validationOnly = false;
adapterConfig.cycleIndex = NaN;
adapterConfig.slotIndex = NaN;
adapterConfig.operationGroupId = "";
```

Do not introduce a hard-coded split-ratio input as the primary control. The split must emerge from valve coefficients and current pressure states. It is acceptable to include a diagnostic target or warning threshold later, but the implemented branch flows must be computed from pressure-flow controls.

### Pressure basis resolution

Resolve pressure ratios explicitly and report the source used. Recommended precedence:

For `feedPressureRatio`:

1. `adapterConfig.feedPressureRatio`, if supplied.
2. A clear high-pressure ratio field from `templateParams`, if present and unambiguous.
3. Dimensionless high-pressure default of `1.0`, only if the template’s dimensionless pressure convention is demonstrably normalized to feed pressure.
4. Otherwise error with `FI5:MissingFeedPressureBasis`.

For `externalProductPressureRatio`:

1. `adapterConfig.externalProductPressureRatio`, if supplied.
2. A clear raffinate/product pressure ratio from `templateParams`, if present and unambiguous.
3. Dimensionless high-pressure default of `1.0`, only if the intended product sink is high-pressure product and the convention is documented.
4. Otherwise error with `FI5:MissingProductPressureBasis`.

Do not guess symbolic Yang pressure classes such as `P5`, `P6`, or `PF` from labels alone.

## Validation requirements

### `validateYangAdppBfAdapterInputs.m`

Recommended signature:

```matlab
function [adapterConfig, validationReport] = validateYangAdppBfAdapterInputs(tempCase, templateParams, adapterConfig)
```

Required checks:

1. `tempCase` passes `validateYangTemporaryCase`.
2. `tempCase.caseType == "paired_direct_transfer"`.
3. `tempCase.nLocalBeds == 2`.
4. `tempCase.directTransferFamily == "ADPP_BF"`.
5. `localMap.local_index == [1; 2]`.
6. `localMap.local_role(1) == "donor"`.
7. `localMap.local_role(2) == "receiver"`.
8. `localMap.yang_label(1) == "AD&PP"`.
9. `localMap.yang_label(2) == "BF"`.
10. Endpoint policy is:
    - donor outlet endpoint: `product_end`;
    - receiver inlet endpoint: `product_end`;
    - receiver waste endpoint: `none`.
11. `tempCase.native.nativeRunnable == false`.
12. `tempCase.native.endpointPolicy.externalProductSeparated == true`, if that field exists.
13. Exactly one of `durationSeconds` or `durationDimless` is supplied.
14. Required valve coefficients are numeric, scalar, real, finite, and nonnegative.
15. Reverse-flow flags are scalar logicals.
16. Component names resolve to the template component count.
17. `validationOnly` defaults to `false`.

Recommended validation report fields:

```matlab
validationReport.version = "FI5-Yang2009-ADPP-BF-adapter-input-validation-v1";
validationReport.pass = true;
validationReport.directTransferFamily = "ADPP_BF";
validationReport.pairId = string(tempCase.pairId);
validationReport.localMap = tempCase.localMap;
validationReport.endpointPolicy = tempCase.native.endpointPolicy;
validationReport.configVersion = string(adapterConfig.version);
validationReport.noDynamicInternalTanks = true;
validationReport.noSharedHeaderInventory = true;
validationReport.noFourBedRhsDae = true;
validationReport.noCoreAdsorberPhysicsRewrite = true;
```

Use `FI5:*` error identifiers for new AD&PP→BF failures. Preserve existing `FI4:*` identifiers in PP→PU code unless there is a compelling reason to refactor them.

## Local two-bed runtime setup

### `prepareYangAdppBfAdapterLocalRunParams.m`

Recommended signature:

```matlab
function [params, prepReport] = prepareYangAdppBfAdapterLocalRunParams(tempCase, templateParams, adapterConfig)
```

Start from the Batch 3 preparation pattern, but do not blindly copy the PP→PU endpoint setup. AD&PP→BF has external feed and split product-end accounting.

Required local runtime structure:

```matlab
params = templateParams;
params.nCols = 2;
params.nSteps = 1;
params.nRows = 1;
params.sColNums = {'n1'; 'n2'};
params.sStepCol = {'YANG-ADPP-BF'; 'YANG-ADPP-BF'};
params.typeDaeModel = ones(2, 1);
params.flowDirCol = [1; 1]; % verify against native sign convention before finalizing
params.volFlBoFree = zeros(2, 1);
params.volFlBo = makeAdppBfBoundaryCells();
params.funcVol = @calcVolFlowsDP0DT0;
params.funcVolUnits = @zeroYangAdapterAuxiliaryVolFlows;
params.yangAdapterConfig = adapterConfig;
params.yangAdapterFamily = "ADPP_BF";
```

The exact `flowDirCol` values must be verified against the current toPSAil sign convention. The intended signs are:

| Boundary | Intended volumetric sign |
|---|---:|
| donor feed-end external feed in | positive into first CSTR, matching native feed-end inflow convention |
| donor product-end total outflow | positive out of product end |
| receiver product-end BF inflow | negative at receiver product end |
| receiver feed end closed | zero |

If the native convention requires different `flowDirCol` values, use the native convention and document it in `prepReport`. Do not change signs by making conservation diagnostics lie.

### Required interaction matrices

The adapter may use native `makeCol2Interact` logic for endpoint upstream compositions, but the interaction flags must be deliberate.

Recommended policy:

- Donor feed-end upstream source: feed tank composition.
  - Set `valFeTa2AdsFeEnd(1,1) = 1`.
- Receiver product-end upstream source: donor product-end gas.
  - Set `numAdsEqPrEnd(2,1) = 1`.
- Donor product-end outflow: no upstream source should matter when flow is clamped outward, but keep the default harmless and block reverse flow unless explicitly allowed.
- Receiver feed end: closed.
- No auxiliary tank/unit inventory should carry internal transfer.

A likely setup is:

```matlab
params.numAdsEqPrEnd = [0; 1];
params.numAdsEqFeEnd = [0; 0];
params.valFeTa2AdsFeEnd = [1; 0];
params.valFeTa2AdsPrEnd = [0; 0];
params.valRaTa2AdsFeEnd = [0; 0];
params.valRaTa2AdsPrEnd = [0; 0];
params.valExTa2AdsFeEnd = [0; 0];
params.valExTa2AdsPrEnd = [0; 0];
```

If the current native interaction machinery cannot support the intended donor-feed and receiver-product composition paths without using an internal tank, stop and report the smallest possible wrapper-level hook. Do not edit core mass balances casually.

### Initial state handling

Use the Batch 3 physical-state policy:

1. Accept local physical states of length `params.nColSt`.
2. Accept native local states of length `params.nColStT` only to extract their physical prefix.
3. Build temporary native local states by appending zero counter tails:

```matlab
nativeVector = [
    physical.physicalStateVector(:)
    zeros(2*params.nComs, 1)
];
```

4. Insert those temporary native local states into `params.initStates`.
5. Return only physical terminal states.

Do not persist cumulative feed/product counter tails.

## Boundary flow law

### `calcYangAdppBfBoundaryFlows.m`

Recommended signature:

```matlab
function [volumetricFlow, flowState] = calcYangAdppBfBoundaryFlows(params, col, nS, nCo, endpoint)
```

The helper should evaluate three independent molar branch rates from the instantaneous state:

```matlab
pDonorFeed = donor.feed.gasTotal .* donor.feed.temperature;
pDonorProduct = donor.product.gasTotal .* donor.product.temperature;
pReceiverProduct = receiver.product.gasTotal .* receiver.product.temperature;

rawFeed = config.Cv_ADPP_feed .* (config.feedPressureRatio - pDonorFeed);
rawProduct = config.Cv_ADPP_product .* (pDonorProduct - config.externalProductPressureRatio);
rawInternal = config.Cv_ADPP_BF_internal .* (pDonorProduct - pReceiverProduct);
```

Apply reverse-flow policy:

```matlab
if config.allowReverseFeedFlow
    nDotFeed = rawFeed;
else
    nDotFeed = max(0, rawFeed);
end

if config.allowReverseProductFlow
    nDotProduct = rawProduct;
else
    nDotProduct = max(0, rawProduct);
end

if config.allowReverseInternalFlow
    nDotInternal = rawInternal;
else
    nDotInternal = max(0, rawInternal);
end
```

Return endpoint volumetric flows using current endpoint gas totals:

```matlab
switch string(endpoint)
    case "donor_feed_end"
        volumetricFlow = nDotFeed ./ safeDenominator(donor.feed.gasTotal);
    case "donor_product_end"
        volumetricFlow = (nDotProduct + nDotInternal) ./ safeDenominator(donor.product.gasTotal);
    case "receiver_product_end"
        volumetricFlow = -nDotInternal ./ safeDenominator(receiver.product.gasTotal);
    case "receiver_feed_end_closed"
        volumetricFlow = zeros(size(nDotInternal));
    case "zero"
        volumetricFlow = zeros(size(nDotInternal));
    otherwise
        error('FI5:UnsupportedAdppBfEndpoint', ...
            'Unsupported AD&PP->BF endpoint %s.', char(endpoint));
end
```

Important: the native donor product-end boundary sees only the **aggregate outflow** `nDotProduct + nDotInternal`. The adapter report must separately integrate `nDotProduct` and `nDotInternal`. Native cumulative product-end counters are not sufficient for AD&PP→BF split accounting.

### Boundary cell setup

Recommended local boundary cell setup:

```matlab
function volFlBo = makeAdppBfBoundaryCells()
    volFlBo = cell(2, 2, 1);
    volFlBo{1, 1, 1} = @(params,col,feTa,raTa,exTa,nS,nCo) ...
        calcYangAdppBfBoundaryFlows(params, col, nS, nCo, "donor_product_end");
    volFlBo{2, 1, 1} = @(params,col,feTa,raTa,exTa,nS,nCo) ...
        calcYangAdppBfBoundaryFlows(params, col, nS, nCo, "donor_feed_end");
    volFlBo{1, 2, 1} = @(params,col,feTa,raTa,exTa,nS,nCo) ...
        calcYangAdppBfBoundaryFlows(params, col, nS, nCo, "receiver_product_end");
    volFlBo{2, 2, 1} = @(params,col,feTa,raTa,exTa,nS,nCo) ...
        calcYangAdppBfBoundaryFlows(params, col, nS, nCo, "receiver_feed_end_closed");
end
```

Verify `volFlBo{1,...}` versus `volFlBo{2,...}` endpoint ordering against Batch 3 and native `getVolFlowFuncHandle` conventions before committing. The table above describes intent; the code must match native indexing.

## Flow integration and split diagnostics

### `integrateYangAdppBfAdapterFlows.m`

Recommended signature:

```matlab
function flowReport = integrateYangAdppBfAdapterFlows(params, stTime, stStates, adapterConfig)
```

At each time sample, parse the donor and receiver local states and reconstruct branch rates:

- external feed by component, using feed composition from `params.yFeC` or a validated `adapterConfig.feedMoleFractions` if you add one;
- external product by component, using donor product-end gas composition;
- internal BF out by component, using donor product-end gas composition;
- internal BF in by component, equal to internal BF out by component in the direct zero-holdup model.

Recommended component-rate definitions:

```matlab
yFeed = resolveFeedMoleFractions(params, config);
yDonorProduct = donorProductGas ./ safeDenominator(sum(donorProductGas));

externalFeedRate = yFeed .* nDotFeed;
externalProductRate = yDonorProduct .* nDotProduct;
internalByComponent = yDonorProduct .* nDotInternal;
```

Integrate by trapezoidal rule, following the PP→PU helper style:

```matlab
nativeExternalFeed = integrateRows(stTime, externalFeedRate);
nativeExternalProduct = integrateRows(stTime, externalProductRate);
nativeInternalOut = integrateRows(stTime, internalOutRate);
nativeInternalIn = integrateRows(stTime, internalInRate);
```

Required `flowReport.native` fields:

```matlab
flowReport.native.unitBasis = "native_dimensionless_integral";
flowReport.native.externalFeedByComponent = nativeExternalFeed;
flowReport.native.externalProductByComponent = nativeExternalProduct;
flowReport.native.internalTransferOutByComponent = nativeInternalOut;
flowReport.native.internalTransferInByComponent = nativeInternalIn;
flowReport.native.externalWasteByComponent = zeros(nComs, 1);
flowReport.native.totalExternalFeed = sum(nativeExternalFeed);
flowReport.native.totalExternalProduct = sum(nativeExternalProduct);
flowReport.native.totalInternalTransferOut = sum(nativeInternalOut);
flowReport.native.totalInternalTransferIn = sum(nativeInternalIn);
flowReport.native.totalExternalWaste = 0;
```

If `params.nScaleFac` exists, also populate `flowReport.moles` with physical moles. If it does not exist, report:

```matlab
flowReport.moles.unitBasis = "not_available_missing_params.nScaleFac";
```

Do not fail solely because physical mole conversion is unavailable; conservation can still be tested in native integral units.

### Effective split ratio

Compute effective split ratios after integration. Minimum required fields:

```matlab
effectiveSplit = struct();
effectiveSplit.unitBasis = flowReport.native.unitBasis;
effectiveSplit.H2 = n_H2_internal_BF ./ safeDenominator(n_H2_internal_BF + n_H2_external_product);
effectiveSplit.total = totalInternal ./ safeDenominator(totalInternal + totalExternalProduct);
effectiveSplit.componentNames = string(config.componentNames(:));
effectiveSplit.byComponent = internalByComponent ./ safeDenominator(internalByComponent + externalProductByComponent);
effectiveSplit.primaryControl = "valve_coefficients_not_hard_coded_split_ratio";
```

For zero denominator cases, return `NaN` and emit a warning rather than inventing a split.

## Conservation diagnostics

Use `computeYangBedComponentInventory` for initial and final inventories.

All branch integrals are positive magnitudes in their natural accounting direction:

- `externalFeed`: into donor.
- `externalProduct`: out of donor and out of the PSA system.
- `internalOut`: out of donor.
- `internalIn`: into receiver.
- `externalWaste`: zero for this adapter.

Recommended residuals:

```matlab
donorDelta = donorFinal - donorInitial;
receiverDelta = receiverFinal - receiverInitial;
pairDelta = donorDelta + receiverDelta;

internalMismatch = internalOut - internalIn;
donorResidual = donorDelta - externalFeed + externalProduct + internalOut;
receiverResidual = receiverDelta - internalIn;
pairResidual = pairDelta - externalFeed + externalProduct;
```

Expected pass condition:

```matlab
scale = max(1, max(abs([
    donorDelta;
    receiverDelta;
    externalFeed;
    externalProduct;
    internalOut
])));
threshold = absTol + relTol .* scale;
pass = all(abs([donorResidual; receiverResidual; pairResidual; internalMismatch]) <= threshold);
```

Required conservation report fields:

```matlab
conservation.evaluated = true;
conservation.unitBasis = flowReport.native.unitBasis;
conservation.donorInventoryDeltaByComponent = donorDelta;
conservation.receiverInventoryDeltaByComponent = receiverDelta;
conservation.pairInventoryDeltaByComponent = pairDelta;
conservation.externalFeedByComponent = externalFeed;
conservation.externalProductByComponent = externalProduct;
conservation.internalTransferOutByComponent = internalOut;
conservation.internalTransferInByComponent = internalIn;
conservation.internalTransferMismatchByComponent = internalMismatch;
conservation.donorResidualByComponent = donorResidual;
conservation.receiverResidualByComponent = receiverResidual;
conservation.pairResidualByComponent = pairResidual;
conservation.absTol = absTol;
conservation.relTol = relTol;
conservation.threshold = threshold;
conservation.pass = pass;
```

Do not count internal BF transfer in external product or in the recovery numerator.

## Pressure and sanity diagnostics

Follow the PP→PU report pattern and add AD&PP→BF-specific endpoints.

Initial pressure fields should include:

- donor feed-end pressure ratio;
- donor product-end pressure ratio;
- receiver product-end pressure ratio;
- receiver feed-end pressure ratio.

Terminal pressure fields should include the same endpoints, plus concise diagnostic aliases:

```matlab
pressure.donorTerminalFeedEndPressureRatio
pressure.donorTerminalProductEndPressureRatio
pressure.receiverTerminalProductEndPressureRatio
pressure.receiverTerminalFeedEndPressureRatio
```

Sanity diagnostics must check:

- no NaNs;
- no negative absolute or dimensionless pressure;
- no negative gas concentrations beyond tolerance;
- no negative adsorbed loadings beyond tolerance;
- no invalid gas mole fractions;
- no unintended reverse feed, product, or internal flow when reverse flags are false.

Required flow sign summaries:

```matlab
flowReport.flowSigns.donorFeedEnd
flowReport.flowSigns.donorProductEnd
flowReport.flowSigns.receiverProductEnd
flowReport.flowSigns.receiverFeedEnd
flowReport.flowSigns.reverseFeedSampleCount
flowReport.flowSigns.reverseProductSampleCount
flowReport.flowSigns.reverseInternalSampleCount
```

Expected signs:

| Endpoint | Expected sign |
|---|---:|
| donor feed end | nonnegative into donor |
| donor product end | nonnegative out of donor |
| receiver product end | nonpositive into receiver |
| receiver feed end | zero |

## Validation-only mode

As in Batch 3, support `adapterConfig.validationOnly = true`.

Validation-only mode should:

1. Validate the ADPP_BF temporary case and adapter config.
2. Return terminal local states equal to the input physical states.
3. Return zero flow schema with explicit ADPP_BF fields.
4. Set:

```matlab
adapterReport.solverRunStatus = "validation_only_no_native_solver_invocation";
adapterReport.didInvokeNative = false;
adapterReport.timeBasis = "validation_only_not_integrated";
```

5. Mark conservation as not evaluated with a clear reason.
6. Still evaluate shape, endpoint metadata, no-tank flags, physical-state-only return shape, and report schema.

This mode is not a substitute for the dynamic conservation path. It exists so the API contract remains testable even when the current params template is not runnable.

## Implementation sequence

### Step 1: inspect Batch 3 without editing

Read:

- `scripts/four_bed/runYangDirectCouplingAdapter.m`
- `scripts/four_bed/runYangPpPuAdapter.m`
- `scripts/four_bed/validateYangDirectCouplingAdapterInputs.m`
- `scripts/four_bed/prepareYangAdapterLocalRunParams.m`
- `scripts/four_bed/calcYangPpPuBoundaryFlows.m`
- `scripts/four_bed/integrateYangPpPuAdapterFlows.m`
- `tests/four_bed/testYangPpPuAdapterContract.m`
- `tests/four_bed/testYangPpPuAdapterConservation.m`

Confirm before coding:

- PP→PU tests pass or fail only for explicitly documented runnable-template limitations.
- `runYangDirectCouplingAdapter` currently blocks or dispatches ADPP_BF.
- `makeYangTemporaryPairedCase(selectYangFourBedPairStates(... "ADPP_BF" ...))` produces local bed 1 as donor and local bed 2 as receiver.

### Step 2: add ADPP_BF dispatcher support

Update `runYangDirectCouplingAdapter.m` to call `runYangAdppBfAdapter` for `ADPP_BF`.

Do not route ADPP_BF through PP→PU validation or PP→PU flow law.

### Step 3: implement ADPP_BF validation helper

Create `validateYangAdppBfAdapterInputs.m`.

Keep it ADPP_BF-specific unless there is already a clean shared validation abstraction. This avoids breaking PP→PU behavior.

### Step 4: implement ADPP_BF runtime preparation helper

Create `prepareYangAdppBfAdapterLocalRunParams.m`.

Use Batch 3’s physical-state preparation pattern, but configure donor feed, donor product split, and receiver product-end BF inflow correctly.

### Step 5: implement ADPP_BF boundary flow helper

Create `calcYangAdppBfBoundaryFlows.m`.

Test it independently before using it in a dynamic run. The boundary law is where most sign errors will hide, smugly waiting for an integration test to embarrass you.

### Step 6: implement ADPP_BF flow integration helper

Create `integrateYangAdppBfAdapterFlows.m`.

Ensure external product and internal BF branches are separately integrated even though the donor product boundary uses their aggregate outflow in the native balance.

### Step 7: implement `runYangAdppBfAdapter.m`

Follow the PP→PU structure:

```matlab
[adapterConfig, validationReport] = validateYangAdppBfAdapterInputs(...);
adapterReport = initializeReport(...);

if adapterConfig.validationOnly
    [terminalLocalStates, adapterReport] = runValidationOnly(...);
    return;
end

[params, prepReport] = prepareYangAdppBfAdapterLocalRunParams(...);
[tDom, timeReport] = resolveTimeDomain(params, adapterConfig);
initialPressure = summarizeInitialPressure(params, tempCase);
initialInventory = computeInitialInventories(params, tempCase);

[stTime, stStates, flags] = runPsaCycleStep(params, params.initStates, tDom, 1, 1);
[terminalLocalStates, counterTailReport] = extractYangTerminalLocalStates(params, stStates, tempCase);

flowReport = integrateYangAdppBfAdapterFlows(params, stTime, stStates, adapterConfig);
finalPressure = summarizeTerminalPressure(params, terminalLocalStates);
finalInventory = computeTerminalInventories(params, terminalLocalStates);
conservation = computeConservationDiagnostics(...);
effectiveSplit = computeEffectiveSplit(...);
sanity = computeSanityDiagnostics(...);

adapterReport.solverRunStatus = "completed_native_runPsaCycleStep";
adapterReport.didInvokeNative = true;
adapterReport.flags = flags;
adapterReport.counterTailReport = counterTailReport;
adapterReport.pressureDiagnostics = struct("initial", initialPressure, "terminal", finalPressure);
adapterReport.flows = flowReport.native;
adapterReport.flowReport = flowReport;
adapterReport.effectiveSplit = effectiveSplit;
adapterReport.conservation = conservation;
adapterReport.sanity = sanity;
adapterReport.warnings = collectWarnings(...);
```

### Step 8: update adapter tests and runner

Add new tests and update `scripts/run_adapter_tests.m`.

Recommended runner:

```matlab
fprintf('Running Yang adapter tests...\n');
testYangPpPuAdapterContract();
testYangPpPuAdapterConservation();
testYangAdppBfAdapterContract();
testYangAdppBfAdapterSplitConservation();
fprintf('Yang adapter tests passed.\n');
```

If dynamic conservation is blocked by missing runtime fields, the dynamic test may pass only by proving the failure is explicit and targeted, following the Batch 3 pattern. Structural tests must still pass.

## Required tests

### `testYangAdppBfAdapterContract.m`

Purpose: prove the ADPP_BF dispatcher, endpoint contract, schema, no-tank architecture, physical-state-only output, and split controls.

Minimum assertions:

1. Build params:

```matlab
params = buildYangH2Co2AcTemplateParams("NVols", 2, "NCols", 2, "NSteps", 1);
```

2. Build manifest, pair map, and four-bed state container using simple physical states.
3. Select `ADPP_BF` pair `A -> B`.
4. Build temp case:

```matlab
adppCase = makeYangTemporaryPairedCase( ...
    selectPair(container, pairMap, "ADPP_BF", "A", "B"), ...
    'DurationDimless', 0.01, ...
    'RunnerMode', "wrapper_adapter", ...
    'CaseNote', "FI-5 ADPP_BF contract");
```

5. Validate config and assert:

```matlab
validation.pass
normalizedConfig.directTransferFamily == "ADPP_BF"
adppCase.native.nativeRunnable == false
adppCase.localMap.local_role(1) == "donor"
adppCase.localMap.local_role(2) == "receiver"
adppCase.localMap.yang_label(1) == "AD&PP"
adppCase.localMap.yang_label(2) == "BF"
adppCase.native.endpointPolicy.donorOutletEndpoint == "product_end"
adppCase.native.endpointPolicy.receiverInletEndpoint == "product_end"
adppCase.native.endpointPolicy.receiverWasteEndpoint == "none"
```

6. Run validation-only adapter through dispatcher:

```matlab
[terminalLocalStates, adapterReport] = runYangDirectCouplingAdapter( ...
    adppCase, params, config);
```

7. Assert:

```matlab
numel(terminalLocalStates) == 2
numel(terminalLocalStates{1}.stateVector) == params.nColSt
numel(terminalLocalStates{2}.stateVector) == params.nColSt
adapterReport.directTransferFamily == "ADPP_BF"
adapterReport.nativeStepGrammarUsed == false
adapterReport.noDynamicInternalTanks
adapterReport.noSharedHeaderInventory
adapterReport.noFourBedRhsDae
adapterReport.noCoreAdsorberPhysicsRewrite
adapterReport.solverRunStatus == "validation_only_no_native_solver_invocation"
isfield(adapterReport.flows, 'externalFeedByComponent')
isfield(adapterReport.flows, 'externalProductByComponent')
isfield(adapterReport.flows, 'internalTransferOutByComponent')
isfield(adapterReport, 'effectiveSplit')
```

8. Assert missing required controls fail:

```matlab
rmfield(config, 'Cv_ADPP_BF_internal')
```

Expected error: `FI5:MissingAdapterConfigField`.

9. Assert PP→PU still dispatches to PP→PU and still has no external product.

### Boundary flow subtests

Within `testYangAdppBfAdapterContract.m` or a private helper, evaluate `calcYangAdppBfBoundaryFlows` on a synthetic two-bed state and assert signs:

```matlab
donorFeed >= 0
donorProduct >= 0
receiverProduct <= 0
receiverFeed == 0
```

Also assert that changing `Cv_ADPP_product` changes the external product branch but does not change the internal branch directly, and changing `Cv_ADPP_BF_internal` changes the internal branch. Do this through the integration helper or by inspecting `flowState`, not by relying on full dynamic runs.

### `testYangAdppBfAdapterSplitConservation.m`

Purpose: dynamic/sanity gate for conservation, split accounting, and no external/internal collapse.

Follow the PP→PU conservation test pattern:

1. Build a two-bed ADPP_BF temp case.
2. Run `runYangAdppBfAdapter` with `validationOnly = false`.
3. If the template is not runnable, allow only an explicit targeted error, for example:

```matlab
FI5:TemplateParamsNotRunnable
```

The error message must identify missing runtime fields such as `initStates`, `funcRat`, `cstrHt`, or feed/product pressure basis.

4. If runnable, assert:

```matlab
numel(terminalLocalStates) == 2
numel(terminalLocalStates{1}.stateVector) == params.nColSt
numel(terminalLocalStates{2}.stateVector) == params.nColSt
adapterReport.directTransferFamily == "ADPP_BF"
all(adapterReport.flows.externalFeedByComponent >= 0)
all(adapterReport.flows.externalProductByComponent >= 0)
all(adapterReport.flows.internalTransferOutByComponent >= 0)
all(adapterReport.flows.internalTransferInByComponent >= 0)
all(adapterReport.flows.externalWasteByComponent == 0)
norm(adapterReport.flows.internalTransferOutByComponent - adapterReport.flows.internalTransferInByComponent, inf) <= tolerance
adapterReport.conservation.pass
~adapterReport.sanity.hasNaN
~adapterReport.sanity.hasNegativePressure
~adapterReport.sanity.hasInvalidMoleFraction
adapterReport.flowReport.flowSigns.donorFeedEnd.negativeCount == 0
adapterReport.flowReport.flowSigns.donorProductEnd.negativeCount == 0
adapterReport.flowReport.flowSigns.receiverProductEnd.positiveCount == 0
adapterReport.flowReport.flowSigns.receiverFeedEnd.positiveCount == 0
```

5. Assert split reporting:

```matlab
isfield(adapterReport, 'effectiveSplit')
adapterReport.effectiveSplit.primaryControl == "valve_coefficients_not_hard_coded_split_ratio"
```

6. Add a synthetic integration subtest where `Cv_ADPP_product` and `Cv_ADPP_BF_internal` are both positive and donor product pressure exceeds receiver product pressure. Assert:

```matlab
externalProductByComponent > 0 for at least H2
internalTransferOutByComponent > 0 for at least H2
effectiveSplit.H2 > 0 && effectiveSplit.H2 < 1
```

This catches the easiest mistake: collapsing all donor product-end outflow into either product or BF.

### Existing ledger test

Keep `tests/four_bed/testYangAdppBfLedgerSplit.m` passing. It already checks that large internal BF transfer does not alter external-product purity or recovery. It is a ledger test, not an adapter dynamic test, but it protects the same accounting principle.

## Commands to run

From repository root:

```matlab
addpath(genpath(pwd));
testYangAdppBfAdapterContract();
testYangAdppBfAdapterSplitConservation();
testYangAdppBfLedgerSplit();
run("scripts/run_adapter_tests.m");
```

Also run the existing PP→PU adapter tests after any shared dispatcher/helper edit:

```matlab
addpath(genpath(pwd));
testYangPpPuAdapterContract();
testYangPpPuAdapterConservation();
```

If MATLAB is unavailable in the execution environment, perform static checks and report that dynamic tests were not run. Do not claim passing dynamic tests you did not run.

## Stop conditions

Stop and report instead of forcing an implementation if any of these occur:

1. `tempCase` does not expose ADPP_BF donor/receiver roles with local donor first.
2. The native boundary machinery cannot provide donor feed composition and receiver product-end BF composition without a core mass-balance change.
3. A proposed solution requires a dynamic internal tank or shared header for the BF transfer.
4. A proposed solution counts BF internal transfer as external product.
5. A proposed solution requires a global four-bed RHS/DAE.
6. A proposed solution changes core files under `3_source/` without explicit authorization.
7. Pressure basis fields are ambiguous and cannot be resolved from the template or config.
8. Conservation signs cannot be reconciled with the native boundary sign convention.

If a narrow interface hook is truly required, document:

- exact file and function;
- reason the wrapper cannot solve it otherwise;
- why the hook does not alter core adsorber physics;
- downstream impact on PP→PU, Batch 5, and tests.

## Expected files changed

Expected additions:

```text
scripts/four_bed/runYangAdppBfAdapter.m
scripts/four_bed/validateYangAdppBfAdapterInputs.m
scripts/four_bed/prepareYangAdppBfAdapterLocalRunParams.m
scripts/four_bed/calcYangAdppBfBoundaryFlows.m
scripts/four_bed/integrateYangAdppBfAdapterFlows.m
tests/four_bed/testYangAdppBfAdapterContract.m
tests/four_bed/testYangAdppBfAdapterSplitConservation.m
```

Expected modifications:

```text
scripts/four_bed/runYangDirectCouplingAdapter.m
scripts/run_adapter_tests.m
```

Possible modifications, only if needed and documented:

```text
tests/four_bed/testYangPpPuAdapterContract.m
```

Do not modify:

```text
3_source/**
2_run/**
1_config/**
params/yang_h2co2_ac_surrogate/**
```

unless a stop-condition report has been accepted or the user explicitly authorizes it.

## Handoff requirements

At the end of the Codex task, report:

- task objective;
- files changed;
- files inspected;
- commands run;
- tests passed;
- tests failed;
- whether dynamic ADPP_BF execution was run or blocked by explicit template limitations;
- unresolved uncertainties;
- whether any toPSAil core files changed;
- whether any validation numbers changed;
- whether PP→PU tests still pass;
- next smallest recommended task.

## Acceptance criteria

Batch 4 is acceptable when:

1. `runYangDirectCouplingAdapter` dispatches `PP_PU` and `ADPP_BF` to separate adapters.
2. `runYangAdppBfAdapter` validates ADPP_BF local donor/receiver identity and endpoints.
3. The adapter returns physical terminal states only.
4. Donor external feed, donor external product, donor internal BF out, and receiver internal BF in are separately integrated.
5. Internal BF transfer is not counted as external product.
6. Effective split ratio is reported after the run and is controlled by valve coefficients, not hard-coded.
7. Conservation diagnostics use correct signs and pass on runnable short tests or fail explicitly if runtime template fields are missing.
8. Pressure and flow-sign diagnostics are present.
9. No dynamic internal tanks, shared headers, global four-bed RHS/DAE, or core physics rewrites are introduced.
10. Existing PP→PU adapter tests still pass.

Only after these criteria are satisfied should Batch 5 attempt full four-bed cycle integration and wrapper-owned ledger/audit extraction.
