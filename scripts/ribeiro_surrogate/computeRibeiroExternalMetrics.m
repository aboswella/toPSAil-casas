function metrics = computeRibeiroExternalMetrics(params, schedule, sol)
%COMPUTERIBEIROEXTERNALMETRICS Compute final-cycle Ribeiro Eq. 2/3 counters.

if useRibeiroBoundaryAccounting(params)
    metrics = computeRibeiroBoundaryMetrics(params, schedule, sol);
    return;
end

metrics = struct();
metrics.version = "Ribeiro2008-surrogate-eq2-eq3-metrics-v2";
metrics.lastCompleteCycle = resolveLastCompleteCycle(params, sol);
metrics.feedMolesFinalCycle = NaN(1, params.nComs);
metrics.expectedFeedMolesFinalCycle = NaN(1, params.nComs);
metrics.expectedTotalFeedMolesFinalCycle = NaN;
metrics.expectedBinaryH2FeedMolesFinalCycle = NaN;
metrics.expectedFullSourceH2FeedMolesFinalCycle = NaN;
metrics.achievedTotalFeedMolesFinalCycle = NaN;
metrics.achievedBinaryH2FeedMolesFinalCycle = NaN;
metrics.feedMolesRelativeError = NaN(1, params.nComs);
metrics.totalFeedMolesRelativeError = NaN;
metrics.nativeRaffinateProductMolesFinalCycle = NaN(1, params.nComs);
metrics.nativeRaffinateWasteMolesFinalCycle = NaN(1, params.nComs);
metrics.feedStepProductMolesFinalCycle = NaN(1, params.nComs);
metrics.pressurizationProductEndMolesSignedFinalCycle = NaN(1, params.nComs);
metrics.purgeProductEndMolesSignedFinalCycle = NaN(1, params.nComs);
metrics.h2UsedForPressurizationFinalCycle = NaN;
metrics.h2UsedForPurgeFinalCycle = NaN;
metrics.achievedPurgeH2MolesFinalCycle = NaN;
metrics.purgeToFeedH2Ratio = NaN;
metrics.achievedPurgeToBinaryFeedH2Ratio = NaN;
metrics.expectedSourcePurgeH2MolesFinalCycle = NaN;
metrics.expectedPurgeToBinaryFeedH2Ratio = NaN;
metrics.expectedPurgeToFullSourceFeedH2Ratio = NaN;
metrics.sourceTable5PurgeToFullFeedH2Ratio = NaN;
metrics.purgeToBinaryFeedH2RatioError = NaN;
metrics.ribeiroEq2PurityH2 = NaN;
metrics.ribeiroEq3RecoveryH2 = NaN;
metrics.purityH2 = NaN;
metrics.recoveryH2 = NaN;
metrics.basisNote = [
    "Ribeiro Eq. 2 surrogate purity uses product-end gas leaving feed beds during HP-FEE-RAF slots."
    "Ribeiro Eq. 3 surrogate recovery subtracts the magnitude of H2 crossing the product end during RP-XXX-RAF and LP-ATM-RAF slots."
    "Native column product-end counters are signed and their raw values are reported separately because sign conventions can differ across DAE paths."
];
metrics.warnings = strings(0, 1);
metrics.scheduleVersion = string(schedule.version);
metrics.productCounterBasis = "column_product_end_counter_during_HP_FEE_RAF";
metrics.rawCounterBasis = ...
    "sol.Step*.col.n*.cumMol.prod(end,:) dimensionalized by params.nScaleFac and grouped by native step label";
metrics.flowAuditBasis = ...
    "Expected source-scale flows use Ribeiro Table 5 feed/purge flow, tcycle = 4*tfeed, and binary H2/CO2 feed renormalization.";

metrics = addExpectedSourceFlowBasis(params, metrics);

if isempty(sol)
    metrics.warnings(end+1, 1) = "No solution supplied; external metrics were not computed.";
    return;
end
if metrics.lastCompleteCycle < 1
    metrics.warnings(end+1, 1) = "No complete cycle available; external metrics were not computed.";
    return;
end

try
    feedMol = getFeedMolCycle(params, sol, [], metrics.lastCompleteCycle);
    [raffProd, raffWaste] = getRaffMoleCycle(params, sol, [], metrics.lastCompleteCycle);
    feedStepProduct = getColumnProductEndMolesForStep(params, sol, ...
        metrics.lastCompleteCycle, "HP-FEE-RAF");
    pressurizationSigned = getColumnProductEndMolesForStep(params, sol, ...
        metrics.lastCompleteCycle, "RP-XXX-RAF");
    purgeSigned = getColumnProductEndMolesForStep(params, sol, ...
        metrics.lastCompleteCycle, "LP-ATM-RAF");
catch err
    metrics.warnings(end+1, 1) = "Final-cycle counter extraction failed: " + string(err.message);
    return;
end

feedMol = feedMol(:).';
raffProd = raffProd(:).';
raffWaste = raffWaste(:).';
feedStepProduct = cleanNearZero(feedStepProduct, params.numZero);
pressurizationSigned = cleanNearZero(pressurizationSigned, params.numZero);
purgeSigned = cleanNearZero(purgeSigned, params.numZero);

h2UsedPressurization = abs(pressurizationSigned(1));
h2UsedPurge = abs(purgeSigned(1));
totalFeedStepProduct = sum(feedStepProduct);
h2Feed = feedMol(1);

metrics.feedMolesFinalCycle = feedMol;
metrics.achievedTotalFeedMolesFinalCycle = sum(feedMol);
metrics.achievedBinaryH2FeedMolesFinalCycle = feedMol(1);
metrics.feedMolesRelativeError = relativeError(feedMol, metrics.expectedFeedMolesFinalCycle);
metrics.totalFeedMolesRelativeError = relativeError( ...
    metrics.achievedTotalFeedMolesFinalCycle, ...
    metrics.expectedTotalFeedMolesFinalCycle);
metrics.nativeRaffinateProductMolesFinalCycle = raffProd;
metrics.nativeRaffinateWasteMolesFinalCycle = raffWaste;
metrics.feedStepProductMolesFinalCycle = feedStepProduct;
metrics.pressurizationProductEndMolesSignedFinalCycle = pressurizationSigned;
metrics.purgeProductEndMolesSignedFinalCycle = purgeSigned;
metrics.h2UsedForPressurizationFinalCycle = h2UsedPressurization;
metrics.h2UsedForPurgeFinalCycle = h2UsedPurge;
metrics.achievedPurgeH2MolesFinalCycle = h2UsedPurge;

if isfinite(totalFeedStepProduct) && abs(totalFeedStepProduct) > params.numZero
    metrics.ribeiroEq2PurityH2 = feedStepProduct(1) / totalFeedStepProduct;
    metrics.purityH2 = metrics.ribeiroEq2PurityH2;
else
    metrics.warnings(end+1, 1) = "Feed-step product total was zero or non-finite.";
end

if isfinite(h2Feed) && abs(h2Feed) > params.numZero
    metrics.ribeiroEq3RecoveryH2 = ...
        (feedStepProduct(1) - h2UsedPressurization - h2UsedPurge) / h2Feed;
    metrics.recoveryH2 = metrics.ribeiroEq3RecoveryH2;
    metrics.purgeToFeedH2Ratio = h2UsedPurge / h2Feed;
    metrics.achievedPurgeToBinaryFeedH2Ratio = metrics.purgeToFeedH2Ratio;
    metrics.purgeToBinaryFeedH2RatioError = ...
        metrics.purgeToFeedH2Ratio - metrics.expectedPurgeToBinaryFeedH2Ratio;
else
    metrics.warnings(end+1, 1) = "H2 feed denominator was zero or non-finite.";
end

metrics = auditCounterSigns(params, metrics);
metrics = auditSourceFlowScale(params, metrics);

end

function metrics = addExpectedSourceFlowBasis(params, metrics)

if ~isfield(params, 'ribeiroBasis') || ~isstruct(params.ribeiroBasis) || ...
        ~isfield(params.ribeiroBasis, 'feed')
    metrics.warnings(end+1, 1) = ...
        "Ribeiro source basis is missing; expected source-flow counters were not computed.";
    return;
end

basis = params.ribeiroBasis;
feed = basis.feed;
cycleTimeSec = resolveCycleTimeSec(params);
tFeedSec = cycleTimeSec / 4;

if isfield(feed, 'totalMolarFlowMolSec') && ...
        isfield(feed, 'moleFractions') && ...
        isfield(feed, 'fullSourceMoleFractions')
    expectedTotalFeed = feed.totalMolarFlowMolSec * cycleTimeSec;
    expectedFeed = expectedTotalFeed * feed.moleFractions(:).';

    metrics.expectedTotalFeedMolesFinalCycle = expectedTotalFeed;
    metrics.expectedFeedMolesFinalCycle = expectedFeed;
    metrics.expectedBinaryH2FeedMolesFinalCycle = expectedFeed(1);
    if isfield(feed, 'originalFullFeedTotalMolarFlowMolSec')
        metrics.expectedFullSourceH2FeedMolesFinalCycle = ...
            feed.originalFullFeedTotalMolarFlowMolSec ...
            * cycleTimeSec ...
            * feed.fullSourceMoleFractions(1);
    else
        metrics.expectedFullSourceH2FeedMolesFinalCycle = ...
            expectedTotalFeed * feed.fullSourceMoleFractions(1);
    end
else
    metrics.warnings(end+1, 1) = ...
        "Feed source basis is incomplete; expected feed moles were not computed.";
end

if isfield(basis, 'purge') && isfield(basis.purge, 'sourceFlowNm3Hr')
    normalMolarVolM3PerKmol = 22.414;
    sourcePurgeMolSec = basis.purge.sourceFlowNm3Hr ...
        / 3600 / normalMolarVolM3PerKmol * 1000;
    metrics.expectedSourcePurgeH2MolesFinalCycle = sourcePurgeMolSec * tFeedSec;

    metrics.expectedPurgeToBinaryFeedH2Ratio = safeDivide( ...
        metrics.expectedSourcePurgeH2MolesFinalCycle, ...
        metrics.expectedBinaryH2FeedMolesFinalCycle);
    metrics.expectedPurgeToFullSourceFeedH2Ratio = safeDivide( ...
        metrics.expectedSourcePurgeH2MolesFinalCycle, ...
        metrics.expectedFullSourceH2FeedMolesFinalCycle);

    if isfield(basis.purge, 'sourcePurgeToFullFeedH2Ratio')
        metrics.sourceTable5PurgeToFullFeedH2Ratio = ...
            basis.purge.sourcePurgeToFullFeedH2Ratio;
    end
else
    metrics.warnings(end+1, 1) = ...
        "Purge source basis is incomplete; expected purge moles were not computed.";
end

end

function metrics = auditSourceFlowScale(params, metrics)

if isfinite(metrics.totalFeedMolesRelativeError) && ...
        metrics.totalFeedMolesRelativeError > 0.05
    metrics.warnings(end+1, 1) = sprintf( ...
        'Achieved total feed differs from Ribeiro source-scale feed by %.3g relative error.', ...
        metrics.totalFeedMolesRelativeError);
end

if numel(metrics.feedMolesRelativeError) >= 1 && ...
        isfinite(metrics.feedMolesRelativeError(1)) && ...
        metrics.feedMolesRelativeError(1) > 0.05
    metrics.warnings(end+1, 1) = sprintf( ...
        'Achieved binary H2 feed differs from Ribeiro source-scale H2 feed by %.3g relative error.', ...
        metrics.feedMolesRelativeError(1));
end

if isfinite(metrics.purgeToBinaryFeedH2RatioError) && ...
        abs(metrics.purgeToBinaryFeedH2RatioError) > 0.02
    metrics.warnings(end+1, 1) = sprintf( ...
        'Achieved purge/H2-feed ratio differs from the binary source reference by %.3g absolute ratio points.', ...
        metrics.purgeToBinaryFeedH2RatioError);
end

if isfinite(metrics.ribeiroEq2PurityH2) && ...
        (metrics.ribeiroEq2PurityH2 < -params.numZero || metrics.ribeiroEq2PurityH2 > 1 + params.numZero)
    metrics.warnings(end+1, 1) = ...
        "Ribeiro Eq. 2 H2 purity failed the physical [0, 1] flow-audit gate.";
end

if isfinite(metrics.ribeiroEq3RecoveryH2) && ...
        (metrics.ribeiroEq3RecoveryH2 < -params.numZero || metrics.ribeiroEq3RecoveryH2 > 1 + params.numZero)
    metrics.warnings(end+1, 1) = ...
        "Ribeiro Eq. 3 H2 recovery failed the physical [0, 1] flow-audit gate.";
end

end

function productMoles = getColumnProductEndMolesForStep(params, sol, lastCycle, stepLabel)

productMoles = zeros(1, params.nComs);
stepInit = (lastCycle - 1) * params.nSteps + 1;

for localSlot = 1:params.nSteps
    stepIndex = stepInit + localSlot - 1;
    stepField = sprintf('Step%d', stepIndex);
    if ~isfield(sol, stepField)
        continue;
    end

    for col = 1:params.nCols
        if ~strcmp(params.sStepCol{col, localSlot}, char(stepLabel))
            continue;
        end
        colField = params.sColNums{col};
        productMoles = productMoles + ...
            sol.(stepField).col.(colField).cumMol.prod(end, :) .* params.nScaleFac;
    end
end

end

function metrics = auditCounterSigns(params, metrics)

if any(metrics.feedStepProductMolesFinalCycle < -params.numZero)
    metrics.warnings(end+1, 1) = ...
        "Feed-step product-end counter contains negative component moles; native sign convention needs audit.";
end
if isfinite(metrics.ribeiroEq2PurityH2) && ...
        (metrics.ribeiroEq2PurityH2 < -params.numZero || metrics.ribeiroEq2PurityH2 > 1 + params.numZero)
    metrics.warnings(end+1, 1) = "Ribeiro Eq. 2 H2 purity is outside [0, 1].";
end
if isfinite(metrics.ribeiroEq3RecoveryH2) && ...
        (metrics.ribeiroEq3RecoveryH2 < -params.numZero || metrics.ribeiroEq3RecoveryH2 > 1 + params.numZero)
    metrics.warnings(end+1, 1) = "Ribeiro Eq. 3 H2 recovery is outside [0, 1].";
end

end

function values = cleanNearZero(values, numZero)

values(abs(values) < numZero) = 0;

end

function cycleTimeSec = resolveCycleTimeSec(params)

if isfield(params, 'cycleTimeSec') && ~isempty(params.cycleTimeSec)
    cycleTimeSec = params.cycleTimeSec;
elseif isfield(params, 'tFeedSec') && ~isempty(params.tFeedSec)
    cycleTimeSec = 4 * params.tFeedSec;
elseif isfield(params, 'durStep') && ~isempty(params.durStep)
    cycleTimeSec = sum(params.durStep);
else
    cycleTimeSec = 160;
end

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

function tf = useRibeiroBoundaryAccounting(params)

tf = false;
if isfield(params, 'ribeiroBoundary') && isstruct(params.ribeiroBoundary) && ...
        isfield(params.ribeiroBoundary, 'mode')
    tf = string(params.ribeiroBoundary.mode) == "ribeiro_fixed_non_eq";
end

end
