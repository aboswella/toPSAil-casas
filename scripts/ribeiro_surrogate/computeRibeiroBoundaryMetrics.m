function metrics = computeRibeiroBoundaryMetrics(params, schedule, sol)
%COMPUTERIBEIROBOUNDARYMETRICS Compute Ribeiro Eq. 2/3 boundary metrics.

metrics = initializeMetrics(params);
metrics.lastCompleteCycle = resolveLastCompleteCycle(params, sol);
metrics.pressureAudit = getRibeiroPressureAudit(params, schedule, sol, metrics.lastCompleteCycle);
metrics.warnings = [metrics.warnings; metrics.pressureAudit.warnings(:)];

[expectedTotalFeed, expectedFeed] = getExpectedFeedMoles(params);
expectedPurgeH2 = nm3hrToMolSec(params.ribeiroBasis.purge.sourceFlowNm3Hr) ...
    * params.tFeedSec;

metrics.feedMolesFinalCycleExpected = expectedFeed;
metrics.feedH2MolesFinalCycleExpected = expectedFeed(1);
metrics.feedCO2MolesFinalCycleExpected = expectedFeed(2);
metrics.expectedSourcePurgeH2MolesFinalCycle = expectedPurgeH2;

metrics.expectedTotalFeedMolesFinalCycle = expectedTotalFeed;
metrics.expectedFeedMolesFinalCycle = expectedFeed;
metrics.expectedBinaryH2FeedMolesFinalCycle = expectedFeed(1);
metrics.expectedFullSourceH2FeedMolesFinalCycle = getExpectedFullSourceH2Feed(params, expectedTotalFeed);
metrics.accountingTotalFeedMolesFinalCycle = expectedTotalFeed;
metrics.accountingFeedMolesFinalCycle = expectedFeed;
metrics.accountingBinaryH2FeedMolesFinalCycle = expectedFeed(1);
metrics.feedMolesFinalCycle = expectedFeed;
metrics.achievedTotalFeedMolesFinalCycle = expectedTotalFeed;
metrics.achievedBinaryH2FeedMolesFinalCycle = expectedFeed(1);
metrics.feedMolesRelativeError = zeros(size(expectedFeed));
metrics.totalFeedMolesRelativeError = 0;

if isempty(sol)
    metrics.warnings(end+1, 1) = "No solution supplied; boundary accounting counters were not computed.";
    return;
end
if metrics.lastCompleteCycle < 1
    metrics.warnings(end+1, 1) = "No complete cycle available; boundary accounting counters were not computed.";
    return;
end

try
    feedProduct = getRibeiroColumnStepCounterMoles(params, sol, ...
        metrics.lastCompleteCycle, "HP-FEE-RAF", "prod");
    feedBoundarySigned = getRibeiroColumnStepCounterMoles(params, sol, ...
        metrics.lastCompleteCycle, "HP-FEE-RAF", "feed");
    pressSigned = getRibeiroColumnStepCounterMoles(params, sol, ...
        metrics.lastCompleteCycle, "RP-XXX-RAF", "prod");
    purgeSigned = getRibeiroColumnStepCounterMoles(params, sol, ...
        metrics.lastCompleteCycle, "LP-ATM-RAF", "prod");
catch err
    metrics.warnings(end+1, 1) = "Final-cycle boundary counter extraction failed: " + string(err.message);
    return;
end

feedProduct = cleanNearZero(feedProduct, params.numZero);
feedBoundarySigned = cleanNearZero(feedBoundarySigned, params.numZero);
feedBoundaryDelivered = -cleanNearZero(feedBoundarySigned, params.numZero);
pressSigned = cleanNearZero(pressSigned, params.numZero);
purgeSigned = cleanNearZero(purgeSigned, params.numZero);

h2Press = abs(pressSigned(1));
h2Purge = abs(purgeSigned(1));

metrics.feedStepProductMolesFinalCycle = feedProduct;
metrics.feedBoundarySignedMolesFinalCycle = feedBoundarySigned;
metrics.feedBoundaryDeliveredMolesFinalCycle = feedBoundaryDelivered;
metrics.feedBoundaryDeliveredTotalMolesFinalCycle = sum(feedBoundaryDelivered);
metrics.feedBoundaryDeliveredBinaryH2MolesFinalCycle = feedBoundaryDelivered(1);
metrics.feedBoundaryDeliveredRelativeError = relativeError( ...
    feedBoundaryDelivered, expectedFeed);
metrics.feedBoundaryDeliveredTotalRelativeError = relativeError( ...
    sum(feedBoundaryDelivered), expectedTotalFeed);
metrics.achievedTotalFeedMolesFinalCycle = ...
    metrics.feedBoundaryDeliveredTotalMolesFinalCycle;
metrics.achievedBinaryH2FeedMolesFinalCycle = ...
    metrics.feedBoundaryDeliveredBinaryH2MolesFinalCycle;
metrics.feedMolesRelativeError = metrics.feedBoundaryDeliveredRelativeError;
metrics.totalFeedMolesRelativeError = ...
    metrics.feedBoundaryDeliveredTotalRelativeError;
metrics.pressurizationProductEndMolesSignedFinalCycle = pressSigned;
metrics.purgeProductEndMolesSignedFinalCycle = purgeSigned;
metrics.h2ProductDuringFeedFinalCycle = feedProduct(1);
metrics.h2UsedForPressurizationFinalCycle = h2Press;
metrics.h2UsedForPurgeFinalCycle = h2Purge;
metrics.achievedPurgeH2MolesFinalCycle = h2Purge;
metrics.boundaryCounterPurgeH2MolesFinalCycle = h2Purge;
metrics.purgeH2RelativeError = relativeError(h2Purge, expectedPurgeH2);

metrics.expectedPurgeToBinaryFeedH2Ratio = safeDivide(expectedPurgeH2, expectedFeed(1));
metrics.expectedPurgeToFullSourceFeedH2Ratio = safeDivide( ...
    expectedPurgeH2, metrics.expectedFullSourceH2FeedMolesFinalCycle);
metrics.purgeToFeedH2Ratio = safeDivide(h2Purge, expectedFeed(1));
metrics.achievedPurgeToBinaryFeedH2Ratio = metrics.purgeToFeedH2Ratio;
metrics.purgeToBinaryFeedH2RatioError = ...
    metrics.achievedPurgeToBinaryFeedH2Ratio - metrics.expectedPurgeToBinaryFeedH2Ratio;
if isfield(params.ribeiroBasis.purge, 'sourcePurgeToFullFeedH2Ratio')
    metrics.sourceTable5PurgeToFullFeedH2Ratio = ...
        params.ribeiroBasis.purge.sourcePurgeToFullFeedH2Ratio;
end

totalFeedProduct = sum(feedProduct);
if isfinite(totalFeedProduct) && abs(totalFeedProduct) > params.numZero
    metrics.ribeiroEq2PurityH2 = feedProduct(1) / totalFeedProduct;
    metrics.purityH2 = metrics.ribeiroEq2PurityH2;
else
    metrics.warnings(end+1, 1) = "Feed-step product total was zero or non-finite.";
end

if isfinite(expectedFeed(1)) && abs(expectedFeed(1)) > params.numZero
    metrics.ribeiroEq3RecoveryH2 = ...
        (feedProduct(1) - h2Press - h2Purge) / expectedFeed(1);
    metrics.recoveryH2 = metrics.ribeiroEq3RecoveryH2;
else
    metrics.warnings(end+1, 1) = "Expected binary H2 feed denominator was zero or non-finite.";
end

metrics = addNativeDiagnosticCounters(params, sol, metrics);
metrics = auditBoundaryMetrics(params, metrics);

end

function metrics = initializeMetrics(params)

metrics = struct();
metrics.version = "Ribeiro2008-boundary-accounting-v1";
metrics.boundaryMode = getBoundaryMode(params);
metrics.lastCompleteCycle = 0;
metrics.feedMolesFinalCycleExpected = NaN(1, params.nComs);
metrics.feedH2MolesFinalCycleExpected = NaN;
metrics.feedCO2MolesFinalCycleExpected = NaN;
metrics.feedStepProductMolesFinalCycle = NaN(1, params.nComs);
metrics.pressurizationProductEndMolesSignedFinalCycle = NaN(1, params.nComs);
metrics.purgeProductEndMolesSignedFinalCycle = NaN(1, params.nComs);
metrics.feedBoundarySignedMolesFinalCycle = NaN(1, params.nComs);
metrics.feedBoundaryDeliveredMolesFinalCycle = NaN(1, params.nComs);
metrics.feedBoundaryDeliveredTotalMolesFinalCycle = NaN;
metrics.feedBoundaryDeliveredBinaryH2MolesFinalCycle = NaN;
metrics.feedBoundaryDeliveredRelativeError = NaN(1, params.nComs);
metrics.feedBoundaryDeliveredTotalRelativeError = NaN;
metrics.h2ProductDuringFeedFinalCycle = NaN;
metrics.h2UsedForPressurizationFinalCycle = NaN;
metrics.h2UsedForPurgeFinalCycle = NaN;
metrics.expectedSourcePurgeH2MolesFinalCycle = NaN;
metrics.purgeH2RelativeError = NaN;
metrics.ribeiroEq2PurityH2 = NaN;
metrics.ribeiroEq3RecoveryH2 = NaN;
metrics.pressureAudit = struct();
metrics.warnings = strings(0, 1);
metrics.metricBasisNote = [
    "Validation-facing metrics use Ribeiro Table 5 prescribed feed and purge boundaries when BoundaryMode is ribeiro_fixed_non_eq."
    "Ribeiro Eq. 2 purity uses H2 over total gas leaving the product end during HP-FEE-RAF slots."
    "Ribeiro Eq. 3 recovery subtracts pure-H2 debits entering the product end during RP-XXX-RAF and LP-ATM-RAF slots from feed-step H2 product."
    "Native toPSAil dynamic tank metrics are retained only as diagnostics in this mode."
];
metrics.basisNote = metrics.metricBasisNote;
metrics.productCounterBasis = "column_product_end_counter_during_HP_FEE_RAF";
metrics.rawCounterBasis = ...
    "sol.Step*.col.n*.cumMol.prod(end,:) dimensionalized by params.nScaleFac and grouped by native step label";
metrics.flowAuditBasis = ...
    "Accounting feed denominator is prescribed Ribeiro Table 5 molar feed flow times 4*tfeed times binary H2/CO2 composition.";
metrics.nativeRaffinateProductMolesFinalCycle = NaN(1, params.nComs);
metrics.nativeRaffinateWasteMolesFinalCycle = NaN(1, params.nComs);
metrics.nativeFeedMolesFinalCycleDiagnostic = NaN(1, params.nComs);
metrics.expectedFeedMolesFinalCycle = NaN(1, params.nComs);
metrics.expectedTotalFeedMolesFinalCycle = NaN;
metrics.expectedBinaryH2FeedMolesFinalCycle = NaN;
metrics.expectedFullSourceH2FeedMolesFinalCycle = NaN;
metrics.accountingTotalFeedMolesFinalCycle = NaN;
metrics.accountingFeedMolesFinalCycle = NaN(1, params.nComs);
metrics.accountingBinaryH2FeedMolesFinalCycle = NaN;
metrics.feedMolesFinalCycle = NaN(1, params.nComs);
metrics.achievedTotalFeedMolesFinalCycle = NaN;
metrics.achievedBinaryH2FeedMolesFinalCycle = NaN;
metrics.feedMolesRelativeError = NaN(1, params.nComs);
metrics.totalFeedMolesRelativeError = NaN;
metrics.achievedPurgeH2MolesFinalCycle = NaN;
metrics.boundaryCounterPurgeH2MolesFinalCycle = NaN;
metrics.purgeToFeedH2Ratio = NaN;
metrics.achievedPurgeToBinaryFeedH2Ratio = NaN;
metrics.expectedPurgeToBinaryFeedH2Ratio = NaN;
metrics.expectedPurgeToFullSourceFeedH2Ratio = NaN;
metrics.sourceTable5PurgeToFullFeedH2Ratio = NaN;
metrics.purgeToBinaryFeedH2RatioError = NaN;
metrics.purityH2 = NaN;
metrics.recoveryH2 = NaN;

end

function mode = getBoundaryMode(params)

mode = "native_valves";
if isfield(params, 'ribeiroBoundary') && isstruct(params.ribeiroBoundary) && ...
        isfield(params.ribeiroBoundary, 'mode') && ~isempty(params.ribeiroBoundary.mode)
    mode = string(params.ribeiroBoundary.mode);
end

end

function [expectedTotalFeed, expectedFeed] = getExpectedFeedMoles(params)

cycleTimeSec = 4 * params.tFeedSec;
expectedTotalFeed = params.ribeiroBasis.feed.totalMolarFlowMolSec * cycleTimeSec;
expectedFeed = expectedTotalFeed * params.ribeiroBasis.feed.moleFractions(:).';

end

function expectedH2 = getExpectedFullSourceH2Feed(params, expectedTotalFeed)

expectedH2 = NaN;
if isfield(params.ribeiroBasis.feed, 'fullSourceMoleFractions')
    expectedH2 = expectedTotalFeed * params.ribeiroBasis.feed.fullSourceMoleFractions(1);
end

end

function molSec = nm3hrToMolSec(flowNm3Hr)

normalMolarVolM3PerKmol = 22.414;
molSec = flowNm3Hr / 3600 / normalMolarVolM3PerKmol * 1000;

end

function metrics = addNativeDiagnosticCounters(params, sol, metrics)

try
    metrics.nativeFeedMolesFinalCycleDiagnostic = ...
        getFeedMolCycle(params, sol, [], metrics.lastCompleteCycle);
    [raffProd, raffWaste] = getRaffMoleCycle(params, sol, [], metrics.lastCompleteCycle);
    metrics.nativeRaffinateProductMolesFinalCycle = raffProd(:).';
    metrics.nativeRaffinateWasteMolesFinalCycle = raffWaste(:).';
catch err
    metrics.warnings(end+1, 1) = ...
        "Native diagnostic tank counter extraction failed: " + string(err.message);
end

end

function metrics = auditBoundaryMetrics(params, metrics)

if any(metrics.feedStepProductMolesFinalCycle < -params.numZero)
    metrics.warnings(end+1, 1) = ...
        "Feed-step product-end counters are negative; stop and audit endpoint/sign mapping.";
end

if isfinite(metrics.purgeH2RelativeError) && metrics.purgeH2RelativeError > 0.05
    metrics.warnings(end+1, 1) = sprintf( ...
        'Boundary-counter purge H2 differs from prescribed source purge by %.3g relative error.', ...
        metrics.purgeH2RelativeError);
end

if isfinite(metrics.feedBoundaryDeliveredTotalRelativeError) && ...
        metrics.feedBoundaryDeliveredTotalRelativeError > 0.05
    metrics.warnings(end+1, 1) = sprintf( ...
        'Column feed-end boundary counter differs from prescribed Ribeiro feed by %.3g relative error.', ...
        metrics.feedBoundaryDeliveredTotalRelativeError);
end

if isfinite(metrics.ribeiroEq2PurityH2) && ...
        (metrics.ribeiroEq2PurityH2 < -params.numZero || metrics.ribeiroEq2PurityH2 > 1 + params.numZero)
    metrics.warnings(end+1, 1) = ...
        "Ribeiro Eq. 2 boundary-basis H2 purity failed the physical [0, 1] gate.";
end

if isfinite(metrics.ribeiroEq3RecoveryH2) && ...
        (metrics.ribeiroEq3RecoveryH2 < -params.numZero || metrics.ribeiroEq3RecoveryH2 > 1 + params.numZero)
    metrics.warnings(end+1, 1) = ...
        "Ribeiro Eq. 3 boundary-basis H2 recovery failed the physical [0, 1] gate.";
end

end

function values = cleanNearZero(values, numZero)

values(abs(values) < numZero) = 0;

end

function ratio = safeDivide(numerator, denominator)

if isfinite(numerator) && isfinite(denominator) && abs(denominator) > eps
    ratio = numerator ./ denominator;
else
    ratio = NaN;
end

end

function err = relativeError(value, expected)

err = NaN(size(value));
valid = isfinite(value) & isfinite(expected) & abs(expected) > eps;
err(valid) = abs(value(valid) - expected(valid)) ./ abs(expected(valid));

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
