function summary = summarizeRibeiroRun(params, schedule, sol)
%SUMMARIZERIBEIRORUN Return compact run metadata and H2 metrics.

warnings = strings(0, 1);

summary = struct();
summary.version = "Ribeiro2008-surrogate-summary-v2";
summary.caseName = string(params.parameterPackName);
summary.componentNames = string(params.componentNames(:));
summary.feedMoleFractions = params.yFeC(:);
summary.feedTotalMolarFlowMolSec = params.ribeiroBasis.feed.totalMolarFlowMolSec;
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
summary.expectedFeedMolesFinalCycle = metrics.expectedFeedMolesFinalCycle;
summary.expectedTotalFeedMolesFinalCycle = metrics.expectedTotalFeedMolesFinalCycle;
summary.expectedBinaryH2FeedMolesFinalCycle = metrics.expectedBinaryH2FeedMolesFinalCycle;
summary.expectedFullSourceH2FeedMolesFinalCycle = metrics.expectedFullSourceH2FeedMolesFinalCycle;
summary.achievedTotalFeedMolesFinalCycle = metrics.achievedTotalFeedMolesFinalCycle;
summary.achievedBinaryH2FeedMolesFinalCycle = metrics.achievedBinaryH2FeedMolesFinalCycle;
summary.feedMolesRelativeError = metrics.feedMolesRelativeError;
summary.totalFeedMolesRelativeError = metrics.totalFeedMolesRelativeError;
summary.feedStepProductMolesFinalCycle = metrics.feedStepProductMolesFinalCycle;
summary.feedStepProductMoles = metrics.feedStepProductMolesFinalCycle;
summary.ribeiroProductMoles = metrics.feedStepProductMolesFinalCycle;
summary.nativeRaffinateProductMolesFinalCycle = metrics.nativeRaffinateProductMolesFinalCycle;
summary.nativeRaffinateWasteMolesFinalCycle = metrics.nativeRaffinateWasteMolesFinalCycle;
summary.pressurizationProductEndMolesSignedFinalCycle = metrics.pressurizationProductEndMolesSignedFinalCycle;
summary.purgeProductEndMolesSignedFinalCycle = metrics.purgeProductEndMolesSignedFinalCycle;
summary.h2UsedForPressurizationFinalCycle = metrics.h2UsedForPressurizationFinalCycle;
summary.h2UsedForPurgeFinalCycle = metrics.h2UsedForPurgeFinalCycle;
summary.achievedPurgeH2MolesFinalCycle = metrics.achievedPurgeH2MolesFinalCycle;
summary.purgeToFeedH2Ratio = metrics.purgeToFeedH2Ratio;
summary.achievedPurgeToBinaryFeedH2Ratio = metrics.achievedPurgeToBinaryFeedH2Ratio;
summary.expectedSourcePurgeH2MolesFinalCycle = metrics.expectedSourcePurgeH2MolesFinalCycle;
summary.expectedPurgeToBinaryFeedH2Ratio = metrics.expectedPurgeToBinaryFeedH2Ratio;
summary.expectedPurgeToFullSourceFeedH2Ratio = metrics.expectedPurgeToFullSourceFeedH2Ratio;
summary.sourceTable5PurgeToFullFeedH2Ratio = metrics.sourceTable5PurgeToFullFeedH2Ratio;
summary.purgeToBinaryFeedH2RatioError = metrics.purgeToBinaryFeedH2RatioError;
summary.cssLast = cssLast;
summary.metricBasisNote = metrics.basisNote;
summary.warnings = unique(warnings, 'stable');

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
