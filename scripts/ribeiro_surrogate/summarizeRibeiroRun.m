function summary = summarizeRibeiroRun(params, schedule, sol)
%SUMMARIZERIBEIRORUN Return compact run metadata and H2 metrics.

warnings = strings(0, 1);

summary = struct();
summary.version = "Ribeiro2008-surrogate-summary-v2";
summary.caseName = string(params.parameterPackName);
summary.componentNames = string(params.componentNames(:));
summary.feedMoleFractions = params.yFeC(:);
summary.feedTotalMolarFlowMolSec = params.ribeiroBasis.feed.totalMolarFlowMolSec;
summary.feedBasisMode = string(params.ribeiroBasis.feed.feedBasisMode);
summary.activeSurrogateFeedBasis = string(params.ribeiroBasis.feed.activeSurrogateFeedBasis);
summary.feedBasisDescription = string(params.ribeiroBasis.feed.feedBasisDescription);
summary.originalFullFeedTotalMolarFlowMolSec = ...
    params.ribeiroBasis.feed.originalFullFeedTotalMolarFlowMolSec;
summary.h2co2PartialTotalMolarFlowMolSec = ...
    params.ribeiroBasis.feed.h2co2PartialTotalMolarFlowMolSec;
summary.pressureBasis = string(params.ribeiroBasis.pressure.basis);
summary.highPressureBarAbs = params.presColHigh;
summary.lowPressureBarAbs = params.presColLow;
summary.nCols = params.nCols;
summary.nNativeSteps = params.nSteps;
summary.nCycles = params.nCycles;
summary.tFeedSec = schedule.tFeedSec;
summary.nativeSlotSec = schedule.baseSlotSec;
summary.nativeValveCoefficient = params.nativeValveCoefficient;
summary.feedValveCoefficient = params.feedValveCoefficient;
summary.purgeValveCoefficient = params.purgeValveCoefficient;
summary.blowdownValveCoefficient = getFieldOrDefault( ...
    params, 'blowdownValveCoefficient', params.nativeValveCoefficient);
summary.equalizationValveCoefficient = getFieldOrDefault( ...
    params, 'equalizationValveCoefficient', params.nativeValveCoefficient);
summary.pressurizationValveCoefficient = getFieldOrDefault( ...
    params, 'pressurizationValveCoefficient', params.nativeValveCoefficient);
boundary = getRibeiroBoundarySummary(params);
summary.boundaryMode = boundary.mode;
summary.boundaryModeBasis = boundary.modeBasis;
summary.feedBoundaryBasis = boundary.feedBoundaryBasis;
summary.purgeBoundaryBasis = boundary.purgeBoundaryBasis;
summary.blowdownBoundaryBasis = boundary.blowdownBoundaryBasis;
summary.pressurizationBoundaryBasis = boundary.pressurizationBoundaryBasis;
summary.equalizationBoundaryBasis = boundary.equalizationBoundaryBasis;
summary.blowdownGainMolSecBar = boundary.blowdownGainMolSecBar;
summary.pressurizationGainMolSecBar = boundary.pressurizationGainMolSecBar;
summary.maxBoundaryMolarFlowMolSec = boundary.maxBoundaryMolarFlowMolSec;
summary.maxBoundaryMolarFlowMolSecRequested = ...
    boundary.maxBoundaryMolarFlowMolSecRequested;
summary.maxBoundaryMolarFlowMolSecEffective = ...
    boundary.maxBoundaryMolarFlowMolSecEffective;

lastCycle = resolveLastCompleteCycle(params, sol);
summary.lastCompleteCycle = lastCycle;

if isempty(sol)
    warnings(end+1, 1) = "StopAfterBuild was true; no native simulation was run.";
    nativeProductPurityH2 = NaN;
    nativeProductRecoveryH2 = NaN;
    cssLast = NaN;
else
    [nativeProductPurityH2, nativeProductRecoveryH2, nativeWarnings] = ...
        extractNativeMetrics(params, sol, lastCycle);
    warnings = [warnings; nativeWarnings(:)];
    cssLast = extractCssLast(sol);
end

metrics = computeRibeiroExternalMetrics(params, schedule, sol);
warnings = [warnings; metrics.warnings(:)];
if isfield(metrics, 'pressureAudit') && isstruct(metrics.pressureAudit)
    pressureAudit = metrics.pressureAudit;
else
    pressureAudit = getRibeiroPressureAudit(params, schedule, sol, lastCycle);
end
warnings = [warnings; pressureAudit.warnings(:)];

summary.nativeProductPurityH2 = nativeProductPurityH2;
summary.nativeProductRecoveryH2 = nativeProductRecoveryH2;
summary.ribeiroEq2PurityH2 = metrics.ribeiroEq2PurityH2;
summary.ribeiroEq3RecoveryH2 = metrics.ribeiroEq3RecoveryH2;
summary.ribeiroProductPurityH2 = metrics.ribeiroEq2PurityH2;
summary.ribeiroProductRecoveryH2 = metrics.ribeiroEq3RecoveryH2;
summary.ribeiroMetricProductCounterBasis = metrics.productCounterBasis;
summary.ribeiroMetricRawCounterBasis = metrics.rawCounterBasis;
summary.ribeiroFlowAuditBasis = metrics.flowAuditBasis;
summary.feedMolesFinalCycle = metrics.feedMolesFinalCycle;
summary.feedMoles = metrics.feedMolesFinalCycle;
summary.feedMolesFinalCycleExpected = getFieldOrDefault( ...
    metrics, 'feedMolesFinalCycleExpected', metrics.expectedFeedMolesFinalCycle);
summary.expectedFeedMolesFinalCycle = metrics.expectedFeedMolesFinalCycle;
summary.expectedTotalFeedMolesFinalCycle = metrics.expectedTotalFeedMolesFinalCycle;
summary.expectedBinaryH2FeedMolesFinalCycle = metrics.expectedBinaryH2FeedMolesFinalCycle;
summary.expectedFullSourceH2FeedMolesFinalCycle = metrics.expectedFullSourceH2FeedMolesFinalCycle;
summary.accountingFeedMolesFinalCycle = getFieldOrDefault( ...
    metrics, 'accountingFeedMolesFinalCycle', metrics.feedMolesFinalCycle);
summary.accountingTotalFeedMolesFinalCycle = getFieldOrDefault( ...
    metrics, 'accountingTotalFeedMolesFinalCycle', metrics.achievedTotalFeedMolesFinalCycle);
summary.accountingBinaryH2FeedMolesFinalCycle = getFieldOrDefault( ...
    metrics, 'accountingBinaryH2FeedMolesFinalCycle', metrics.achievedBinaryH2FeedMolesFinalCycle);
summary.achievedTotalFeedMolesFinalCycle = metrics.achievedTotalFeedMolesFinalCycle;
summary.achievedBinaryH2FeedMolesFinalCycle = metrics.achievedBinaryH2FeedMolesFinalCycle;
summary.feedMolesRelativeError = metrics.feedMolesRelativeError;
summary.totalFeedMolesRelativeError = metrics.totalFeedMolesRelativeError;
summary.feedBoundarySignedMolesFinalCycle = getFieldOrDefault( ...
    metrics, 'feedBoundarySignedMolesFinalCycle', NaN(1, params.nComs));
summary.feedBoundaryDeliveredMolesFinalCycle = getFieldOrDefault( ...
    metrics, 'feedBoundaryDeliveredMolesFinalCycle', NaN(1, params.nComs));
summary.feedBoundaryDeliveredTotalMolesFinalCycle = getFieldOrDefault( ...
    metrics, 'feedBoundaryDeliveredTotalMolesFinalCycle', NaN);
summary.feedBoundaryDeliveredBinaryH2MolesFinalCycle = getFieldOrDefault( ...
    metrics, 'feedBoundaryDeliveredBinaryH2MolesFinalCycle', NaN);
summary.feedBoundaryDeliveredRelativeError = getFieldOrDefault( ...
    metrics, 'feedBoundaryDeliveredRelativeError', NaN(1, params.nComs));
summary.feedBoundaryDeliveredTotalRelativeError = getFieldOrDefault( ...
    metrics, 'feedBoundaryDeliveredTotalRelativeError', NaN);
summary.feedStepProductMolesFinalCycle = metrics.feedStepProductMolesFinalCycle;
summary.feedStepProductMoles = metrics.feedStepProductMolesFinalCycle;
summary.ribeiroProductMoles = metrics.feedStepProductMolesFinalCycle;
summary.nativeRaffinateProductMolesFinalCycle = metrics.nativeRaffinateProductMolesFinalCycle;
summary.nativeRaffinateWasteMolesFinalCycle = metrics.nativeRaffinateWasteMolesFinalCycle;
summary.pressurizationProductEndMolesSignedFinalCycle = metrics.pressurizationProductEndMolesSignedFinalCycle;
summary.purgeProductEndMolesSignedFinalCycle = metrics.purgeProductEndMolesSignedFinalCycle;
summary.pressurizationDebitMolesFinalCycle = getFieldOrDefault( ...
    metrics, 'pressurizationDebitMolesFinalCycle', NaN(1, params.nComs));
summary.purgeDebitMolesFinalCycle = getFieldOrDefault( ...
    metrics, 'purgeDebitMolesFinalCycle', NaN(1, params.nComs));
summary.h2UsedForPressurizationFinalCycle = metrics.h2UsedForPressurizationFinalCycle;
summary.h2UsedForPurgeFinalCycle = metrics.h2UsedForPurgeFinalCycle;
summary.ribeiroEq2DenominatorFinalCycle = getFieldOrDefault( ...
    metrics, 'ribeiroEq2DenominatorFinalCycle', NaN);
summary.ribeiroEq3NumeratorFinalCycle = getFieldOrDefault( ...
    metrics, 'ribeiroEq3NumeratorFinalCycle', NaN);
summary.ribeiroEq3DenominatorFinalCycle = getFieldOrDefault( ...
    metrics, 'ribeiroEq3DenominatorFinalCycle', NaN);
summary.achievedPurgeH2MolesFinalCycle = metrics.achievedPurgeH2MolesFinalCycle;
summary.boundaryCounterPurgeH2MolesFinalCycle = getFieldOrDefault( ...
    metrics, 'boundaryCounterPurgeH2MolesFinalCycle', metrics.achievedPurgeH2MolesFinalCycle);
summary.purgeH2RelativeError = getFieldOrDefault( ...
    metrics, 'purgeH2RelativeError', abs(metrics.purgeToBinaryFeedH2RatioError));
summary.purgeToFeedH2Ratio = metrics.purgeToFeedH2Ratio;
summary.achievedPurgeToBinaryFeedH2Ratio = metrics.achievedPurgeToBinaryFeedH2Ratio;
summary.expectedSourcePurgeH2MolesFinalCycle = metrics.expectedSourcePurgeH2MolesFinalCycle;
summary.expectedPurgeToBinaryFeedH2Ratio = metrics.expectedPurgeToBinaryFeedH2Ratio;
summary.expectedPurgeToFullSourceFeedH2Ratio = metrics.expectedPurgeToFullSourceFeedH2Ratio;
summary.sourceTable5PurgeToFullFeedH2Ratio = metrics.sourceTable5PurgeToFullFeedH2Ratio;
summary.purgeToBinaryFeedH2RatioError = metrics.purgeToBinaryFeedH2RatioError;
summary.cssLast = cssLast;
summary.purityH2LastCycle = getFieldOrDefault(metrics, 'purityH2LastCycle', NaN);
summary.purityH2PreviousCycle = getFieldOrDefault(metrics, 'purityH2PreviousCycle', NaN);
summary.recoveryH2LastCycle = getFieldOrDefault(metrics, 'recoveryH2LastCycle', NaN);
summary.recoveryH2PreviousCycle = getFieldOrDefault(metrics, 'recoveryH2PreviousCycle', NaN);
summary.purityH2AbsDriftLastCycle = getFieldOrDefault( ...
    metrics, 'purityH2AbsDriftLastCycle', NaN);
summary.recoveryH2AbsDriftLastCycle = getFieldOrDefault( ...
    metrics, 'recoveryH2AbsDriftLastCycle', NaN);
summary.purityH2LastThreeCycles = getFieldOrDefault( ...
    metrics, 'purityH2LastThreeCycles', NaN(1, 3));
summary.recoveryH2LastThreeCycles = getFieldOrDefault( ...
    metrics, 'recoveryH2LastThreeCycles', NaN(1, 3));
summary.metricBasisNote = getFieldOrDefault(metrics, 'metricBasisNote', metrics.basisNote);
summary.nativeFeedMolesFinalCycleDiagnostic = getFieldOrDefault( ...
    metrics, 'nativeFeedMolesFinalCycleDiagnostic', NaN(1, params.nComs));
summary.ribeiroPressureAudit = pressureAudit;
summary.pressureAudit = pressureAudit;
summary.softValidationStatus = deriveSoftValidationStatus(params, metrics, pressureAudit, sol);
summary.cssMetricGatePassed = deriveCssMetricGate(params, metrics, pressureAudit, sol);
summary.softValidationBasis = ...
    "Ribeiro Eq. 2/Eq. 3 boundary metrics are source-basis soft verification only until pressure, feed-flow, and purge-flow gates pass.";
summary.modelForm = string(params.ribeiroBasis.scope.modelForm);
summary.isFullRibeiroTargetComparable = ...
    params.ribeiroBasis.target.isFullRibeiroTargetComparable;
summary.fullRibeiroTargetPurityH2 = ...
    params.ribeiroBasis.target.fullRibeiroTargetPurityH2;
summary.fullRibeiroTargetRecoveryH2 = ...
    params.ribeiroBasis.target.fullRibeiroTargetRecoveryH2;
summary.comparisonScope = string(params.ribeiroBasis.target.comparisonBasis);
summary.adsorbentMassKgAcOnly = calcAcOnlyAdsorbentMassKg(params);
summary.productivityMolH2KgAdsDayAcOnly = calcAcOnlyProductivity( ...
    summary.ribeiroEq3NumeratorFinalCycle, params, ...
    summary.adsorbentMassKgAcOnly);
summary.productivityComparableToRibeiro = false;
summary.productivityBasis = ...
    "AC-only surrogate productivity uses final-cycle Eq. 3 net H2 product, total four-bed activated-carbon mass, and cycle time; it is not comparable to Ribeiro layered AC/zeolite productivity.";
summary.warnings = unique(warnings, 'stable');

end

function status = deriveSoftValidationStatus(params, metrics, pressureAudit, sol)

if isempty(sol)
    status = "NOT_RUN";
    return;
end

purgeError = getFieldOrDefault(metrics, 'purgeH2RelativeError', NaN);
if isnan(purgeError) && isfinite(metrics.purgeToBinaryFeedH2RatioError)
    purgeError = abs(metrics.purgeToBinaryFeedH2RatioError);
end

flowOk = isfinite(metrics.totalFeedMolesRelativeError) && ...
    metrics.totalFeedMolesRelativeError <= 0.05 && ...
    numel(metrics.feedMolesRelativeError) >= 1 && ...
    isfinite(metrics.feedMolesRelativeError(1)) && ...
    metrics.feedMolesRelativeError(1) <= 0.05 && ...
    isfinite(purgeError) && purgeError <= 0.05 && ...
    isfinite(metrics.ribeiroEq2PurityH2) && ...
    metrics.ribeiroEq2PurityH2 >= -params.numZero && ...
    metrics.ribeiroEq2PurityH2 <= 1 + params.numZero && ...
    isfinite(metrics.ribeiroEq3RecoveryH2) && ...
    metrics.ribeiroEq3RecoveryH2 >= -params.numZero && ...
    metrics.ribeiroEq3RecoveryH2 <= 1 + params.numZero;

if isfield(pressureAudit, 'maxFeedPressureErrorBar')
    pressureOk = isfinite(pressureAudit.maxFeedPressureErrorBar) && ...
        pressureAudit.maxFeedPressureErrorBar <= 0.5 && ...
        isfinite(pressureAudit.maxLowPressureErrorBar) && ...
        pressureAudit.maxLowPressureErrorBar <= 0.5 && ...
        isfinite(pressureAudit.maxPressurizationErrorBar) && ...
        pressureAudit.maxPressurizationErrorBar <= 0.5;
else
    pressureOk = isfinite(pressureAudit.feedPressureMeanBar) && ...
        abs(pressureAudit.feedPressureMeanBar - params.presColHigh) <= 0.5 && ...
        isfinite(pressureAudit.blowdownEndPressureMeanBar) && ...
        abs(pressureAudit.blowdownEndPressureMeanBar - params.presColLow) <= 0.5 && ...
        isfinite(pressureAudit.purgePressureMeanBar) && ...
        abs(pressureAudit.purgePressureMeanBar - params.presColLow) <= 0.5 && ...
        isfinite(pressureAudit.pressurizationEndPressureMeanBar) && ...
        abs(pressureAudit.pressurizationEndPressureMeanBar - params.presColHigh) <= 0.5;
end

if flowOk && pressureOk
    status = "PASS_PRESSURE_FLOW_AUDIT";
else
    status = "FAIL_PRESSURE_FLOW_AUDIT";
end

end

function passed = deriveCssMetricGate(params, metrics, pressureAudit, sol)

if isempty(sol)
    passed = false;
    return;
end

purgeError = getFieldOrDefault(metrics, 'purgeH2RelativeError', NaN);
flowOk = isfinite(metrics.totalFeedMolesRelativeError) && ...
    metrics.totalFeedMolesRelativeError <= 0.05 && ...
    numel(metrics.feedMolesRelativeError) >= 1 && ...
    isfinite(metrics.feedMolesRelativeError(1)) && ...
    metrics.feedMolesRelativeError(1) <= 0.05 && ...
    isfinite(purgeError) && purgeError <= 0.05;

pressureOk = isfield(pressureAudit, 'maxFeedPressureErrorBar') && ...
    isfinite(pressureAudit.maxFeedPressureErrorBar) && ...
    pressureAudit.maxFeedPressureErrorBar <= 0.5 && ...
    isfinite(pressureAudit.maxLowPressureErrorBar) && ...
    pressureAudit.maxLowPressureErrorBar <= 0.5 && ...
    isfinite(pressureAudit.maxPressurizationErrorBar) && ...
    pressureAudit.maxPressurizationErrorBar <= 0.5;

purityDrift = getFieldOrDefault(metrics, 'purityH2AbsDriftLastCycle', NaN);
recoveryDrift = getFieldOrDefault(metrics, 'recoveryH2AbsDriftLastCycle', NaN);
driftOk = isfinite(purityDrift) && purityDrift <= 0.001 && ...
    isfinite(recoveryDrift) && recoveryDrift <= 0.005;

passed = flowOk && pressureOk && driftOk && ...
    isfinite(metrics.ribeiroEq2PurityH2) && ...
    metrics.ribeiroEq2PurityH2 >= -params.numZero && ...
    metrics.ribeiroEq2PurityH2 <= 1 + params.numZero && ...
    isfinite(metrics.ribeiroEq3RecoveryH2) && ...
    metrics.ribeiroEq3RecoveryH2 >= -params.numZero && ...
    metrics.ribeiroEq3RecoveryH2 <= 1 + params.numZero;

end

function massKg = calcAcOnlyAdsorbentMassKg(params)

bedVolumeCm3 = pi * params.radInCol^2 * params.heightCol;
solidVolumeCm3 = bedVolumeCm3 * (1 - params.voidFracBed);
massKg = solidVolumeCm3 * params.pellDens * params.nCols;

end

function productivity = calcAcOnlyProductivity(netH2MolCycle, params, massKg)

if ~isfinite(netH2MolCycle) || netH2MolCycle <= 0 || ...
        ~isfinite(massKg) || massKg <= 0
    productivity = NaN;
    return;
end

cycleTimeSec = 4 * params.tFeedSec;
productivity = netH2MolCycle / massKg / cycleTimeSec * 86400;

end

function value = getFieldOrDefault(inputStruct, fieldName, defaultValue)

if isfield(inputStruct, fieldName) && ~isempty(inputStruct.(fieldName))
    value = inputStruct.(fieldName);
else
    value = defaultValue;
end

end

function boundary = getRibeiroBoundarySummary(params)

boundary = defaultRibeiroBoundarySummary();
if isfield(params, 'ribeiroBoundary') && isstruct(params.ribeiroBoundary)
    fields = fieldnames(boundary);
    for idx = 1:numel(fields)
        fieldName = fields{idx};
        if isfield(params.ribeiroBoundary, fieldName) && ...
                ~isempty(params.ribeiroBoundary.(fieldName))
            boundary.(fieldName) = params.ribeiroBoundary.(fieldName);
        end
    end
end
boundary.mode = string(boundary.mode);

end

function boundary = defaultRibeiroBoundarySummary()

boundary = struct();
boundary.mode = "native_valves";
boundary.modeBasis = ...
    "Native toPSAil valves and dynamic tanks define all boundary flows.";
boundary.feedBoundaryBasis = ...
    "Native feed tank and feed valve.";
boundary.purgeBoundaryBasis = ...
    "Native raffinate tank and product-end purge valve.";
boundary.blowdownBoundaryBasis = ...
    "Native feed-end valve to low-pressure waste.";
boundary.pressurizationBoundaryBasis = ...
    "Native raffinate tank and product-end pressurization valve.";
boundary.equalizationBoundaryBasis = ...
    "native column-to-column EQ-XXX-APR retained";
boundary.blowdownGainMolSecBar = NaN;
boundary.pressurizationGainMolSecBar = NaN;
boundary.maxBoundaryMolarFlowMolSecRequested = [];
boundary.maxBoundaryMolarFlowMolSecEffective = NaN;
boundary.maxBoundaryMolarFlowMolSec = NaN;

end

function [purityH2, recoveryH2, warnings] = extractNativeMetrics(~, sol, lastCycle)

warnings = strings(0, 1);
purityH2 = NaN;
recoveryH2 = NaN;

if lastCycle < 1
    warnings(end+1, 1) = "No complete cycle was available for native metrics.";
    return;
end
if ~isfield(sol, 'perMet') || ~isfield(sol.perMet, 'productPurity') || ...
        ~isfield(sol.perMet, 'productRecovery')
    warnings(end+1, 1) = "sol.perMet did not contain native purity/recovery fields.";
    return;
end
if size(sol.perMet.productPurity, 1) < lastCycle || ...
        size(sol.perMet.productRecovery, 1) < lastCycle
    warnings(end+1, 1) = "Native metric arrays did not include the last complete cycle.";
    return;
end

purityH2 = sol.perMet.productPurity(lastCycle, 1);
recoveryH2 = sol.perMet.productRecovery(lastCycle, 1);

if ~isfinite(purityH2)
    warnings(end+1, 1) = "Native H2 purity is not finite.";
end
if ~isfinite(recoveryH2)
    warnings(end+1, 1) = "Native H2 recovery is not finite.";
end

end

function cssLast = extractCssLast(sol)

cssLast = NaN;
if isfield(sol, 'css') && ~isempty(sol.css)
    finiteCss = sol.css(isfinite(sol.css));
    if ~isempty(finiteCss)
        cssLast = finiteCss(end);
    end
end

end

function lastCycle = resolveLastCompleteCycle(params, sol)

if isempty(sol)
    lastCycle = 0;
    return;
end
if isfield(sol, 'lastStep') && ~isempty(sol.lastStep)
    lastCycle = floor(double(sol.lastStep) / params.nSteps);
else
    lastCycle = params.nCycles;
end
lastCycle = max(0, min(params.nCycles, lastCycle));

end
