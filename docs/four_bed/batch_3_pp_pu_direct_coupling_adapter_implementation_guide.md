# Batch 3 implementation guide: PP→PU direct-coupling adapter

## Assignment

You are implementing **Batch 3** of the final four-bed toPSAil implementation. This batch covers:

- **FI-4 Custom PP→PU adapter**: implement the Yang provide-purge direct-coupling operation without dynamic internal tanks, shared headers, or a global four-bed RHS/DAE.

This guide is for a fresh Codex agent working in the most recent repository snapshot, after Batch 1 and Batch 2 have landed. You are not working alone. Adapter implementation is a high-risk integration point, so keep the scope narrow, validate signs and accounting explicitly, and fail loudly on ambiguous runtime assumptions.

## Active source of truth

Use these files as active context before editing anything:

1. `AGENTS.md`
2. `docs/four_bed/README.md`
3. `docs/four_bed/FINAL_IMPLEMENTATION_CONTEXT.md`
4. `docs/BOUNDARY_CONDITION_POLICY.md`
5. `docs/KNOWN_UNCERTAINTIES.md`
6. `docs/TEST_POLICY.md`
7. `docs/CODEX_PROJECT_MAP.md`
8. Existing Batch 1 and Batch 2 guides:
   - `docs/four_bed/batch_1_schedule_state_persistence_implementation_guide.md`
   - `docs/four_bed/batch_2_h2co2_ac_parameter_pack_implementation_guide.md`

The old WP1-WP5 docs and `docs/workflow/*.csv` files are legacy. Use them only for historical rationale, risk cross-checking, or old test IDs. They do not define this batch.

## Current repository baseline from previous batches

Batch 1 appears to have implemented the normalized schedule and physical-state-only persistence contract:

- `scripts/four_bed/getYangNormalizedSlotDurations.m`
- `scripts/four_bed/getYangFourBedScheduleManifest.m`
- `scripts/four_bed/extractYangPhysicalBedState.m`
- `scripts/four_bed/extractYangCounterTailDeltas.m`
- `scripts/four_bed/writeBackYangFourBedStates.m`
- `scripts/four_bed/computeYangFourBedCssResiduals.m`

Batch 2 appears to have implemented the H2/CO2 homogeneous activated-carbon surrogate parameter package:

- `params/yang_h2co2_ac_surrogate/buildYangH2Co2AcTemplateParams.m`
- `params/yang_h2co2_ac_surrogate/yangH2Co2AcSurrogateConstants.m`
- `params/yang_h2co2_ac_surrogate/testYangAcDslMapping.m`
- `cases/yang_h2co2_ac_surrogate/case_spec.md`

Important caveat: the Batch 2 builder is a **template/parameter pack**, not automatically a fully initialized runnable toPSAil case unless the required runtime fields are present. Do not silently fabricate missing solver fields. If a runnable template cannot be built from existing functions, report the missing fields clearly and keep the adapter API and structural tests complete.

## Scope boundaries

### You own

Primary implementation files:

- `scripts/four_bed/runYangDirectCouplingAdapter.m`
- `scripts/four_bed/runYangPpPuAdapter.m`

Recommended helper files, only if they keep the main functions readable:

- `scripts/four_bed/validateYangDirectCouplingAdapterInputs.m`
- `scripts/four_bed/prepareYangAdapterLocalRunParams.m`
- `scripts/four_bed/calcYangPpPuBoundaryFlows.m`
- `scripts/four_bed/integrateYangPpPuAdapterFlows.m`
- `scripts/four_bed/computeYangBedComponentInventory.m`
- `scripts/four_bed/summarizeYangBedPressureProfile.m`

Tests:

- `tests/four_bed/testYangPpPuAdapterContract.m`
- `tests/four_bed/testYangPpPuAdapterConservation.m`

Optional runner:

- `scripts/run_adapter_tests.m`

### You may make a narrow interface hook

You may make a very small change to an existing wrapper helper only if it is required to make Batch 3 interoperable with Batch 1 physical-state persistence. The most likely candidate is not core toPSAil, but this wrapper helper:

- `scripts/four_bed/injectYangLocalStatesIntoTemplateParams.m`

If you touch it, the allowed change is only this:

- accept local states of length `params.nColSt` as physical states;
- append zero counter tails for the temporary native run only;
- continue accepting `params.nColStT` states;
- keep persistent writeback physical-only;
- add a report flag saying counters were zero-initialized for the local temporary run.

Prefer an adapter-private helper instead of editing shared helpers. Do not widen the shared API unless necessary.

### You must not own

Do not implement or materially change:

- AD&PP→BF adapter logic. That is Batch 4.
- Full four-bed cycle driver. That is Batch 5.
- Wrapper-level final H2 purity/recovery reconstruction. That is Batch 5.
- Audit file export. Batch 3 should return an in-memory `adapterReport`; compact audit writing belongs to Batch 5 unless a tiny diagnostic is explicitly needed.
- New event-based scheduling.
- Dynamic internal tanks or shared header inventory.
- A global four-bed RHS/DAE.
- Core adsorber physics in `3_source/`, including mass, energy, isotherm, momentum, or valve law equations.

Do not use native `EQ-XXX-APR` as a fake PP→PU. Equalization does not include receiver feed-end waste, so it cannot satisfy the required PP→PU accounting or endpoint contract.

## Non-negotiable architecture

The PP→PU adapter must preserve the final architecture:

1. Four persistent named bed states remain outside the adapter.
2. The adapter receives only a temporary two-bed local case.
3. Local bed 1 is the PP donor.
4. Local bed 2 is the PU receiver.
5. Donor product-end gas feeds the receiver product end directly.
6. Receiver waste exits the receiver feed end.
7. There is no dynamic tank, no shared header, and no hidden holdup.
8. Internal transfer gas is not external product.
9. Terminal local states returned by the adapter are physical adsorber states only.
10. Counters and stream integrals are adapter accounting data only.

## PP→PU semantics

### Physical meaning

The PP donor is cocurrently depressurized through its product end. Its product-end gas is routed directly into the PU receiver at the receiver product end. The receiver is purged countercurrently, and waste exits from the receiver feed end.

For the local two-bed case:

| Local index | Role | Yang label | Endpoint behavior |
|---:|---|---|---|
| 1 | donor | `PP` | product-end outflow to receiver product end |
| 2 | receiver | `PU` | product-end inflow from donor; feed-end external waste outflow |

The pair map already defines PP→PU pair identities. Expected family pairs are:

| Family | Donor | Receiver |
|---|---|---|
| `PP_PU` | A | D |
| `PP_PU` | B | A |
| `PP_PU` | C | B |
| `PP_PU` | D | C |

Use `getYangDirectTransferPairMap` and `selectYangFourBedPairStates`. Never infer the receiver from source row order, adjacency, or implicit bed naming patterns.

### Accounting meaning

PP→PU produces:

- one internal transfer stream from donor product end to receiver product end;
- one external waste stream from receiver feed end;
- no external feed;
- no external product.

Required stream categories:

| Stream | Scope | Direction | Endpoint | Counts in H2 recovery? |
|---|---|---|---|---|
| donor internal out | `internal_transfer` | `out_of_donor` | `product_end` | No |
| receiver internal in | `internal_transfer` | `into_receiver` | `product_end` | No |
| receiver waste out | `external_waste` | `out` | `feed_end` | No |
| bed inventory change | `bed_inventory_delta` | `delta` | `not_applicable` | No |

Internal donor-out and receiver-in should match componentwise within tolerance when expressed in the same basis. They cancel at the pair level and must not appear as external product.

## Adapter API contract

Implement a shared dispatcher now, even though Batch 3 only supports PP→PU. Batch 4 should be able to extend this without inventing a second adapter abstraction.

### `runYangDirectCouplingAdapter.m`

Required signature:

```matlab
function [terminalLocalStates, adapterReport] = runYangDirectCouplingAdapter(tempCase, templateParams, adapterConfig)
```

Required behavior:

```matlab
family = string(tempCase.directTransferFamily);
switch family
    case "PP_PU"
        [terminalLocalStates, adapterReport] = runYangPpPuAdapter(tempCase, templateParams, adapterConfig);
    case "ADPP_BF"
        error('FI4:AdapterFamilyNotImplementedInBatch3', ...
            'ADPP_BF belongs to Batch 4. Do not implement it in Batch 3.');
    otherwise
        error('FI4:UnsupportedDirectCouplingFamily', ...
            'Unsupported directTransferFamily %s.', char(family));
end
```

Do not quietly pass through native-runnable EQI/EQII. This dispatcher is for custom direct-coupling adapters, not all paired operations.

### `runYangPpPuAdapter.m`

Required signature:

```matlab
function [terminalLocalStates, adapterReport] = runYangPpPuAdapter(tempCase, templateParams, adapterConfig)
```

Required inputs:

- `tempCase`: a two-bed temporary case built from `makeYangTemporaryPairedCase`.
- `templateParams`: initialized two-column toPSAil-compatible params, or a params template that the adapter can complete without changing core physics.
- `adapterConfig`: control and diagnostics structure.

Required output:

- `terminalLocalStates`: a 2-by-1 cell array in `tempCase.localMap.local_index` order.
  - Each cell must be a physical-state payload compatible with `extractYangPhysicalBedState`.
  - Do not return native counter tails as persistent bed state.
- `adapterReport`: a scalar struct with identity, controls, pressure diagnostics, integrated flows, conservation residuals, and warnings.

### Required `adapterReport` schema

Use these groups. Field names can be MATLAB-style, but do not omit the information.

```matlab
adapterReport = struct();
adapterReport.version = "FI4-Yang2009-PP-PU-adapter-report-v1";
adapterReport.payloadType = "yang_pp_pu_adapter_report_v1";
adapterReport.directTransferFamily = "PP_PU";
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
- `operationGroupId`, recommended value like `"PP_PU-B-to-A"`.

Control fields:

- `durationSeconds`, if supplied.
- `durationDimless`, if used by the solver.
- `timeBasis`, e.g. `"dimensionless"`, `"seconds_converted_to_dimensionless"`, or `"seconds_direct"` only if justified.
- `Cv_PP_PU_internal`.
- `Cv_PU_waste`.
- `receiverWastePressureRatio` or equivalent explicitly named pressure basis.
- `allowReverseInternalFlow`.
- `allowReverseWasteFlow`.
- solver tolerances used.

Pressure diagnostics:

- donor initial product-end pressure.
- donor terminal product-end pressure.
- donor initial/final pressure profile summaries.
- receiver initial product-end pressure.
- receiver terminal product-end pressure.
- receiver initial/final pressure profile summaries.
- receiver initial/final feed-end pressure.
- pressure endpoint deviations when targets are supplied.

Flow diagnostics:

- `internalTransferOutByComponent`.
- `internalTransferInByComponent`.
- `externalWasteByComponent`.
- total internal transfer.
- total external waste.
- flow sign counts and extrema:
  - donor product-end flow expected nonnegative;
  - receiver product-end flow expected nonpositive;
  - receiver feed-end waste flow expected nonpositive.
- any reverse-flow or zero-flow warnings.

Conservation diagnostics:

- donor inventory delta by component.
- receiver inventory delta by component.
- pair inventory delta by component.
- donor residual: `donorDelta + internalOut`.
- receiver residual: `receiverDelta - internalIn + externalWaste`.
- pair residual: `pairDelta + externalWaste`.
- absolute and relative tolerances.
- pass/fail boolean.

Sanity fields:

- `hasNaN`.
- `hasNegativePressure`.
- `hasNegativeConcentration`.
- `hasInvalidMoleFraction`.
- `warnings` as a string vector.

## Adapter controls

Batch 3 should not hard-code valve settings as hidden constants. The adapter may provide test defaults only through a clearly marked helper or local test config. Production dynamic runs should require explicit controls.

Recommended config shape:

```matlab
adapterConfig = struct();
adapterConfig.version = "FI4-Yang2009-PP-PU-adapter-config-v1";
adapterConfig.directTransferFamily = "PP_PU";
adapterConfig.durationSeconds = [];
adapterConfig.durationDimless = [];
adapterConfig.Cv_PP_PU_internal = [];
adapterConfig.Cv_PU_waste = [];
adapterConfig.receiverWastePressureRatio = [];
adapterConfig.receiverWastePressureClass = "P4";
adapterConfig.allowReverseInternalFlow = false;
adapterConfig.allowReverseWasteFlow = false;
adapterConfig.componentNames = ["H2"; "CO2"];
adapterConfig.conservationAbsTol = 1e-8;
adapterConfig.conservationRelTol = 1e-6;
adapterConfig.debugKeepStateHistory = false;
adapterConfig.cycleIndex = NaN;
adapterConfig.slotIndex = NaN;
```

Validation requirements:

- exactly one of `durationSeconds` or `durationDimless` is required;
- `Cv_PP_PU_internal` must be numeric, scalar, finite, and nonnegative;
- `Cv_PU_waste` must be numeric, scalar, finite, and nonnegative;
- if `durationSeconds` is supplied and toPSAil expects dimensionless time, convert using `params.tiScaleFac` and record this conversion;
- do not invent missing intermediate pressures;
- if no numeric waste pressure ratio can be obtained from `adapterConfig` or `templateParams`, fail with `FI4:MissingWastePressureBasis`.

Recommended duration handling:

```matlab
if ~isempty(adapterConfig.durationDimless)
    tDom = [0, adapterConfig.durationDimless];
    report.timeBasis = "dimensionless";
elseif isfield(templateParams, 'tiScaleFac') && ~isempty(templateParams.tiScaleFac)
    durationDimless = adapterConfig.durationSeconds / templateParams.tiScaleFac;
    tDom = [0, durationDimless];
    report.timeBasis = "seconds_converted_to_dimensionless_using_tiScaleFac";
else
    error('FI4:CannotConvertDurationSeconds', ...
        'DurationSeconds was supplied but templateParams.tiScaleFac is missing.');
end
```

Do not repeat the existing ambiguity in `runYangTemporaryCase`, which currently passes a supplied duration straight to `runPsaCycleStep`. The adapter report must state what time basis was actually integrated.

## Implementation strategy

### Step 1: validate the temporary case

Before doing any numerical work:

```matlab
result = validateYangTemporaryCase(tempCase);
if ~result.pass
    error('FI4:InvalidTemporaryCase', ...);
end
```

Then check:

```matlab
assert(tempCase.caseType == "paired_direct_transfer")
assert(tempCase.nLocalBeds == 2)
assert(tempCase.directTransferFamily == "PP_PU")
assert(tempCase.localMap.local_index(1) == 1)
assert(tempCase.localMap.local_index(2) == 2)
assert(tempCase.localMap.local_role(1) == "donor")
assert(tempCase.localMap.local_role(2) == "receiver")
assert(tempCase.localMap.yang_label(1) == "PP")
assert(tempCase.localMap.yang_label(2) == "PU")
assert(tempCase.native.endpointPolicy.donorOutletEndpoint == "product_end")
assert(tempCase.native.endpointPolicy.receiverInletEndpoint == "product_end")
assert(tempCase.native.endpointPolicy.receiverWasteEndpoint == "feed_end")
```

Use explicit errors, not `assert`, in production functions. The `assert` form above is just the contract.

### Step 2: prepare local run states without persisting counters

Batch 1 made persistent states physical-only. Your adapter must accept physical-state payloads.

For each local state:

1. resolve numeric vector from payload;
2. if length is `params.nColSt`, append `zeros(2*params.nComs, 1)` for the temporary native run;
3. if length is `params.nColStT`, keep it for the run but still persist only `1:params.nColSt` later;
4. reject any other length.

Recommended helper:

```matlab
function nativeVector = resolveYangAdapterNativeLocalState(params, payload)
    physical = extractYangPhysicalBedState(params, payload);
    nativeVector = [physical.physicalStateVector(:); zeros(2*params.nComs, 1)];
end
```

This avoids contaminating persistent beds with cumulative counter tails. The counters used for adapter accounting should be reconstructed from the adapter flow integration, not persisted state tails.

### Step 3: build an isolated two-bed params object

The adapter params object must have `nCols = 2`, `nSteps = 1`, and two local columns only. It must not contain four persistent beds.

Required preparation:

```matlab
params = templateParams;
params.nCols = 2;
params.nSteps = 1;
params.nRows = 1;
params.sStepCol = {"YANG-PP-PU"; "YANG-PP-PU"};  % metadata only; custom adapter owns flow law
params.numAdsEqPrEnd = [2; 1];  % lets makeCol2Interact use donor product-end gas at receiver product end
params.numAdsEqFeEnd = [0; 0];
params.yangAdapterConfig = adapterConfig;
params.yangAdapterFamily = "PP_PU";
```

You may need to reshape some native fields to two rows and one step. Do this narrowly and document it in the helper.

Potential fields that may need adapter-specific two-column/one-step values, depending on the template:

- `typeDaeModel`
- `flowDirCol`
- `volFlBo`
- `volFlBoFree`
- `valFeedColNorm`
- `valProdColNorm`
- `valFeEndEq`
- `valPrEndEq`
- `valAdsFeEnd2ExWa`
- `valAdsPrEnd2RaWa`
- `valFeTa2AdsFeEnd`
- `valFeTa2AdsPrEnd`
- `valRaTa2AdsFeEnd`
- `valRaTa2AdsPrEnd`
- `valExTa2AdsFeEnd`
- `valExTa2AdsPrEnd`
- `valAdsPrEnd2RaTa`
- `valAdsPrEnd2RaWa`
- `valAdsFeEnd2ExTa`
- `valAdsFeEnd2ExWa`

Set tank interaction matrices to zeros unless the native helper requires them for shape. The PP→PU adapter must not use tank inventories to represent internal transfer.

### Step 4: use existing adsorber machinery through a wrapper-level boundary hook

Preferred implementation route:

1. Use `runPsaCycleStep` as the ODE integrator and existing adsorber balance engine.
2. Do not edit `defineRhsFunc.m`.
3. Override wrapper-level params so the existing `params.funcVol` path uses adapter boundary functions.
4. Keep auxiliary tank flows zero.
5. Reconstruct adapter stream integrals from the solved state trajectory.

The cleanest route is:

```matlab
params.volFlBo = cell(2, 2, 1);  % {product/feed end, local bed, step}
params.volFlBo{1,1,1} = @(params,col,feTa,raTa,exTa,nS,nCo) ...
    calcYangPpPuBoundaryFlows(params,col,nS,nCo,"donor_product_end");
params.volFlBo{2,1,1} = @(params,col,feTa,raTa,exTa,nS,nCo) 0;
params.volFlBo{1,2,1} = @(params,col,feTa,raTa,exTa,nS,nCo) ...
    calcYangPpPuBoundaryFlows(params,col,nS,nCo,"receiver_product_end");
params.volFlBo{2,2,1} = @(params,col,feTa,raTa,exTa,nS,nCo) ...
    calcYangPpPuBoundaryFlows(params,col,nS,nCo,"receiver_feed_waste");
params.funcVolUnits = @zeroYangAdapterAuxiliaryVolFlows;
```

Then select the native interior volumetric-flow calculation already used by the template:

- if the template already has a valid `params.funcVol`, preserve it only if it is an existing adsorber-interior flow calculator and does not route via native tank grammar;
- otherwise choose the appropriate existing no-pressure-drop or pressure-drop function from the template policy;
- do not edit core interior-flow functions.

If this cannot be done safely because the Batch 2 template is not fully initialized, stop with an explicit `FI4:TemplateParamsNotRunnable` error and keep the adapter structural tests passing. Do not fake a dynamic tank to get a green test. A green lie is still a lie, just with formatting.

### Step 5: implement PP→PU boundary flow law

Compute pressure ratios using local product/feed CSTR totals:

```matlab
pDonorPr = donorGasTotalPr .* donorTempPr;
pRecvPr  = receiverGasTotalPr .* receiverTempPr;
pRecvFe  = receiverGasTotalFe .* receiverTempFe;
pWaste   = adapterConfig.receiverWastePressureRatio;
```

Internal transfer molar rate, native dimensionless basis:

```matlab
rawInternal = adapterConfig.Cv_PP_PU_internal .* (pDonorPr - pRecvPr);
if adapterConfig.allowReverseInternalFlow
    nDotInternal = rawInternal;
else
    nDotInternal = max(0, rawInternal);
end
```

Receiver waste molar rate, native dimensionless basis:

```matlab
rawWaste = adapterConfig.Cv_PU_waste .* (pRecvFe - pWaste);
if adapterConfig.allowReverseWasteFlow
    nDotWaste = rawWaste;
else
    nDotWaste = max(0, rawWaste);
end
```

Convert molar rates to boundary volumetric rates for each local endpoint:

```matlab
% Donor product-end outflow: positive product-end volumetric flow.
vDonorProduct = nDotInternal ./ donorGasTotalPr;

% Receiver product-end inflow: negative product-end volumetric flow.
vReceiverProduct = -nDotInternal ./ receiverGasTotalPr;

% Receiver feed-end waste outflow: negative feed-end volumetric flow.
vReceiverFeedWaste = -nDotWaste ./ receiverGasTotalFe;
```

Guard against division by zero:

```matlab
safeDen = max(gasTotal, eps);
```

Do not use the receiver's product composition for the internal transfer. The gas entering the receiver is donor product-end gas. `params.numAdsEqPrEnd = [2; 1]` makes `makeCol2Interact` place donor product-end composition into the receiver product-end boundary condition. Still, your report integrator should explicitly compute internal component rates from donor product-end composition:

```matlab
yDonorPr_i = cDonorPr_i ./ donorGasTotalPr;
nDotInternal_i = yDonorPr_i .* nDotInternal;
```

Receiver waste composition comes from receiver feed-end CSTR:

```matlab
yRecvFe_i = cRecvFe_i ./ receiverGasTotalFe;
nDotWaste_i = yRecvFe_i .* nDotWaste;
```

### Step 6: keep auxiliary tanks inert

The adapter may need native tank state fields to satisfy `defineRhsFunc`, but those tanks must not carry Yang internal-transfer inventory.

Implement an auxiliary zero-flow helper:

```matlab
function units = zeroYangAdapterAuxiliaryVolFlows(params, units, nS)
    nCols = params.nCols;
    nRows = params.nRows;
    units.feTa.n1.volFlRat = zeros(nRows, nCols + 1);
    units.raTa.n1.volFlRat = zeros(nRows, nCols + 1);
    units.exTa.n1.volFlRat = zeros(nRows, nCols + 1);
end
```

If the native tank balance functions require additional fields, satisfy only shape and zero-flow requirements. Do not route donor gas into `raTa` or `exTa` as an intermediate. That would be a dynamic tank by another name, and the final basis explicitly forbids it.

### Step 7: run the solver

After constructing `params.initStates`:

```matlab
[stTime, stStates, flags] = runPsaCycleStep(params, params.initStates, tDom, 1, 1);
```

Then extract physical terminal states:

```matlab
[terminalLocalStates, counterTailReport] = extractYangTerminalLocalStates(params, stStates, tempCase);
```

The returned `terminalLocalStates` must be physical-only payloads. `counterTailReport` may be included in `adapterReport` as diagnostic accounting, but not persisted.

### Step 8: integrate adapter flows from the state history

Do not add new ODE states just to count adapter streams. Reconstruct rates from `stTime` and `stStates`, then integrate with trapezoidal quadrature.

Recommended helper:

```matlab
flowReport = integrateYangPpPuAdapterFlows(params, stTime, stStates, adapterConfig);
```

At each time row:

1. build `units.col = makeColumns(params, xRow)`;
2. build inert tanks if needed;
3. call `makeCol2Interact(params, units, 1)` so receiver product-end boundary composition is donor product-end gas;
4. evaluate the same PP→PU boundary flow law;
5. compute component molar rates:
   - donor internal out by component;
   - receiver internal in by component;
   - receiver waste out by component;
6. collect flow signs and extrema.

Integrate each component rate:

```matlab
amount = trapz(stTime, rate);
```

Use the same time basis as the solver. If you convert to physical moles, multiply by `params.nScaleFac` and record that conversion. If the required scale factor is missing, report native scaled amounts under an explicitly named field and do not call them physical moles.

Recommended flow-report fields:

```matlab
flowReport.native.internalOutByComponent
flowReport.native.internalInByComponent
flowReport.native.externalWasteByComponent
flowReport.native.unitBasis = "native_dimensionless_integral"
flowReport.moles.internalOutByComponent     % only if params.nScaleFac exists
flowReport.moles.internalInByComponent
flowReport.moles.externalWasteByComponent
flowReport.flowSigns
```

### Step 9: compute inventories and conservation residuals

Implement a helper that computes total gas-plus-adsorbed inventory by component for one local bed state.

For native dimensionless state vectors:

```matlab
function inventory = computeYangBedComponentInventory(params, localStatePayload)
```

Use existing converters:

```matlab
gas = convert2ColGasConc(params, nativeStateVector, 0_or_col);
ads = convert2ColAdsConc(params, nativeStateVector, 0_or_col);
```

For a single local column vector, avoid `convert2ColStates` by passing the resolved local column vector directly to `convert2ColGasConc(params, localVector, 0)`, or create a small local extractor that respects the same state layout. Be careful: the converter's special `colNum = 0` path treats the input as one CSTR unless you manage `nVols` correctly. Safer implementation is to parse by index using `params.nStates`, `params.nVols`, and `params.nComs`.

State layout per CSTR is:

```matlab
[c_1 ... c_nComs, q_1 ... q_nComs, T_cstr, T_wall]
```

Gas inventory in moles, when physical scales exist:

```matlab
N_gas_i = sum(c_i_dimless .* params.gConScaleFac .* params.overVoid .* params.colVol .* params.cstrHt);
```

Adsorbed inventory in moles, when physical scales exist:

```matlab
N_ads_i = sum(q_i_dimless .* params.aConScaleFac .* params.pellDens .* ...
              (1 - params.voidFracBed) .* params.colVol .* params.cstrHt);
```

Total:

```matlab
N_total_i = N_gas_i + N_ads_i;
```

If `gConScaleFac`, `aConScaleFac`, `overVoid`, `colVol`, `cstrHt`, `pellDens`, or `voidFracBed` are unavailable, compute a clearly labelled native scaled inventory and set `inventory.unitBasis = "native_scaled_not_physical_moles"`.

Conservation residuals for PP→PU:

```matlab
donorDelta   = donorFinalInventory - donorInitialInventory;
receiverDelta = receiverFinalInventory - receiverInitialInventory;
pairDelta = donorDelta + receiverDelta;

% All vectors are componentwise.
donorResidual = donorDelta + internalOut;
receiverResidual = receiverDelta - internalIn + externalWaste;
pairResidual = pairDelta + externalWaste;
```

Expected behavior:

- `internalOut ≈ internalIn` componentwise.
- `pairResidual ≈ 0` componentwise.
- `externalProduct == 0` componentwise.

Do not tune valve coefficients to make conservation pass. Conservation failure is a bug in signs, units, endpoint composition, or state accounting.

## Pressure diagnostics

Implement a pressure-profile summarizer:

```matlab
function p = summarizeYangBedPressureProfile(params, localStatePayload)
```

For each CSTR:

```matlab
pressureRatio = sum(c_i_dimless) .* T_cstr_dimless;
```

Report:

- `minPressureRatio`
- `maxPressureRatio`
- `feedEndPressureRatio`
- `productEndPressureRatio`
- `meanPressureRatio`
- physical bar values only if a validated scale such as `params.presColHigh` exists.

Flag:

- negative pressure ratios;
- NaN/Inf pressure ratios;
- endpoint pressure class mismatch if a numeric target is explicitly supplied.

Do not invent numeric values for `P1`, `P2`, `P3`, `P5`, or `P6`.

## Tests

### `testYangPpPuAdapterContract.m`

Purpose: structural/API test. This should be a default smoke test and should not require a long solver run.

Build a sentinel context like existing pair tests:

```matlab
manifest = getYangFourBedScheduleManifest();
pairMap = getYangDirectTransferPairMap(manifest);
container = makeYangFourBedStateContainer(buildSentinelStates(), ...);
pair = pairMap.transferPairs(pairMap.transferPairs.direct_transfer_family == "PP_PU" & ...
                             pairMap.transferPairs.donor_bed == "B" & ...
                             pairMap.transferPairs.receiver_bed == "A", :);
selection = selectYangFourBedPairStates(container, pair);
tempCase = makeYangTemporaryPairedCase(selection, 'DurationSeconds', 1);
```

Required assertions:

- dispatcher routes `PP_PU` to `runYangPpPuAdapter` or at least validates as supported;
- `ADPP_BF` through dispatcher errors with `FI4:AdapterFamilyNotImplementedInBatch3`;
- `tempCase.native.nativeRunnable` remains false;
- donor is local index 1;
- receiver is local index 2;
- endpoints are product/product/feed-waste;
- adapter report declares no dynamic tanks, no shared header, no global RHS;
- no `external_product` appears in PP→PU report schema;
- required config fields are validated and missing fields cause explicit errors.

If the test uses sentinel nonnumeric states, do not call the solver. Use a validation-only mode or deliberately test input rejection. Do not pretend sentinel structs are physical beds.

### `testYangPpPuAdapterConservation.m`

Purpose: dynamic adapter conservation, endpoint, and accounting test.

This test should run a short two-bed adapter step only if a runnable two-column template can be created. Keep runtime small. It should not run a full four-bed cycle.

Recommended setup:

```matlab
params = buildYangH2Co2AcTemplateParams('NCols', 2, 'NSteps', 1, 'NVols', 4, ...);
params = completeTemplateForRuntimeIfExistingHelpersAllow(params);  % do not invent physics
```

If no clean runtime initialization path exists, create a clear helper failure and leave a TODO in the test comment. Do not skip silently; an untested adapter conservation path is an explicit implementation risk.

Required dynamic assertions:

- terminal states are a 2-cell local-order array;
- terminal states have physical length `params.nColSt`;
- no counter tails are persisted;
- `adapterReport.directTransferFamily == "PP_PU"`;
- `sum(adapterReport.flows.externalProductByComponent) == 0`, or the equivalent field is absent/zero;
- internal out and internal in match componentwise within tolerance;
- external waste is nonnegative;
- pair conservation residual passes;
- pressure summaries are finite;
- no negative absolute pressures;
- no NaNs;
- donor product-end flow has no negative samples unless reverse flow is explicitly allowed;
- receiver product-end flow has no positive samples unless reverse flow is explicitly allowed;
- receiver feed-end waste flow has no positive samples unless reverse flow is explicitly allowed.

### Add an adapter test runner

Optional but useful:

```matlab
% scripts/run_adapter_tests.m
fprintf('Running Yang adapter tests...\n');
testYangPpPuAdapterContract();
testYangPpPuAdapterConservation();
fprintf('Yang adapter tests passed.\n');
```

Do not add long dynamic tests to `scripts/run_sanity_tests.m` until they are reliable and genuinely small.

## Common failure modes to guard against

| Failure mode | Symptom | Guard |
|---|---|---|
| Dynamic tank smuggled in | donor gas enters `raTa`/`exTa` then receiver purges from tank | zero auxiliary tank flows; no tank counters for internal transfer |
| Native equalization used as PP→PU | no receiver feed-end waste | reject native `EQ-XXX-APR` for `PP_PU` |
| Local/global inversion | terminal donor written to receiver bed | preserve local index 1 donor, 2 receiver; test B→A pair |
| Product overcount | PP internal gas appears in H2 recovery numerator | no `external_product` rows/fields in PP→PU |
| Boundary sign error | receiver purge flows into feed end, or donor product flow reverses | sign diagnostics and endpoint sign assertions |
| Composition error | receiver product inlet uses receiver gas instead of donor gas | set `numAdsEqPrEnd=[2;1]`; integrate internal rates from donor product composition |
| Counter-tail persistence | returned states have length `nColStT` | call `extractYangPhysicalBedState`; assert length `nColSt` |
| Unit confusion | conservation residual fails despite plausible flows | record native vs mole basis; use same basis for inventory and integrated flows |
| Duration confusion | step runs too long/short | convert seconds to dimensionless using `tiScaleFac`, or require `durationDimless` |
| Hidden pressure fabrication | made-up `P2` or `P4` values | require explicit numeric waste pressure ratio or known `params.pRatDoSt`/`presColLow/presColHigh` |

## Required handoff notes

At the end of the implementation, report:

1. Files changed.
2. Whether `templateParams` was runnable without core edits.
3. Whether any shared wrapper helper was modified.
4. The exact PP→PU flow law used.
5. The exact time basis used by the solver.
6. The inventory and flow unit basis used for conservation.
7. Tests added and their runtime class.
8. Any failure to run MATLAB tests.
9. Any unresolved template initialization issue.
10. Confirmation that no dynamic tanks, shared headers, global four-bed RHS, or core adsorber balance edits were introduced.

## Acceptance checklist

Batch 3 is acceptable only if all of these are true:

- `runYangDirectCouplingAdapter` exists and dispatches `PP_PU` only.
- `runYangPpPuAdapter` validates PP→PU temp cases rigorously.
- The adapter returns two physical terminal local states in local-map order.
- The adapter report includes identity, controls, pressures, flows, signs, conservation, and warnings.
- Internal transfer and external waste are separately integrated.
- PP→PU creates no external product.
- Physical-state persistence remains clean: no counter tails in returned bed states.
- Tests cover contract and conservation or explicitly expose the runtime-template blocker.
- No forbidden architecture appears.
- No core adsorber physics was changed.

## Suggested implementation order

1. Add `runYangDirectCouplingAdapter.m` with dispatcher validation and `ADPP_BF` rejection.
2. Add `runYangPpPuAdapter.m` with full input/config validation and report skeleton.
3. Add adapter-private state normalization from physical to native temporary run state.
4. Add boundary-flow helper and zero auxiliary flow helper.
5. Add flow-history integration helper.
6. Add pressure and inventory helpers.
7. Wire the short solver run only after the structural path is stable.
8. Add `testYangPpPuAdapterContract.m`.
9. Add `testYangPpPuAdapterConservation.m`.
10. Run existing sanity/source/parameter tests plus adapter tests.
11. Write handoff notes.

Keep Batch 3 narrow. Batch 4 can reuse the shared dispatcher and report pattern, but it must implement the AD&PP→BF split separately. Batch 5 can later consume the adapter report into wrapper ledger rows. Do not pre-build either of those features here.
