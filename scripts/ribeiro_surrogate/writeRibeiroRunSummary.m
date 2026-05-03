function writeRibeiroRunSummary(out, outputDir)
%WRITERIBEIRORUNSUMMARY Write a minimal Markdown/MAT run summary.

if nargin < 1 || ~isstruct(out)
    error('RibeiroSurrogate:InvalidOutputStruct', ...
        'out must be a struct returned by runRibeiroSurrogate.');
end
if nargin < 2 || isempty(outputDir)
    outputDir = fullfile(pwd, 'diagnostic_outputs', 'ribeiro_surrogate');
end
if isstring(outputDir)
    outputDir = char(outputDir);
end
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

summary = out.summary;
summaryPath = fullfile(outputDir, 'summary.md');
matPath = fullfile(outputDir, 'summary.mat');

fid = fopen(summaryPath, 'w');
if fid < 0
    error('RibeiroSurrogate:CannotWriteSummary', ...
        'Could not open %s for writing.', summaryPath);
end
cleanup = onCleanup(@() fclose(fid));

fprintf(fid, '# Ribeiro surrogate run summary\n\n');
fprintf(fid, '- Components: H2/CO2\n');
fprintf(fid, '- Feed: 81.535 mol%% H2, 18.465 mol%% CO2, renormalized from Ribeiro Table 5 H2/CO2 entries\n');
fprintf(fid, '- Source feed: H2/CO2/CH4/CO/N2 = 73.3/16.6/3.5/2.9/3.7 mol %%\n');
fprintf(fid, '- Feed flow: 12.2 N m^3/h source basis, about 0.1513 mol/s\n');
fprintf(fid, '- Pressure: %.6g to %.6g bar_abs\n', ...
    summary.highPressureBarAbs, summary.lowPressureBarAbs);
fprintf(fid, '- Beds: %d\n', summary.nCols);
fprintf(fid, '- Logical cycle: 8 steps\n');
fprintf(fid, '- Native schedule slots: %d\n', summary.nNativeSteps);
fprintf(fid, '- Adsorbent: activated-carbon surrogate\n');
fprintf(fid, '- Native valve coefficient: %.12g\n', summary.nativeValveCoefficient);
fprintf(fid, '- Feed valve coefficient: %.12g\n', summary.feedValveCoefficient);
fprintf(fid, '- Purge valve coefficient: %.12g\n', summary.purgeValveCoefficient);
fprintf(fid, '- Blowdown valve coefficient: %.12g\n', summary.blowdownValveCoefficient);
fprintf(fid, '- Equalization valve coefficient: %.12g\n', summary.equalizationValveCoefficient);
fprintf(fid, '- Pressurization valve coefficient: %.12g\n', summary.pressurizationValveCoefficient);
fprintf(fid, '- Boundary mode: %s\n', char(summary.boundaryMode));
fprintf(fid, '- Boundary basis: %s\n', char(summary.boundaryModeBasis));
fprintf(fid, '- Feed boundary basis: %s\n', char(summary.feedBoundaryBasis));
fprintf(fid, '- Purge boundary basis: %s\n', char(summary.purgeBoundaryBasis));
fprintf(fid, '- Blowdown boundary basis: %s\n', char(summary.blowdownBoundaryBasis));
fprintf(fid, '- Pressurization boundary basis: %s\n', char(summary.pressurizationBoundaryBasis));
fprintf(fid, '- Equalization basis: %s\n', char(summary.equalizationBoundaryBasis));
fprintf(fid, '- Blowdown gain: %.12g mol/s/bar\n', summary.blowdownGainMolSecBar);
fprintf(fid, '- Pressurization gain: %.12g mol/s/bar\n', summary.pressurizationGainMolSecBar);
fprintf(fid, '- Max boundary molar flow: %.12g mol/s\n', summary.maxBoundaryMolarFlowMolSec);
fprintf(fid, '- Soft-validation status: %s\n', char(summary.softValidationStatus));
fprintf(fid, '- Soft-validation basis: %s\n', char(summary.softValidationBasis));
fprintf(fid, '- Native H2 purity: %.12g\n', summary.nativeProductPurityH2);
fprintf(fid, '- Native H2 recovery: %.12g\n', summary.nativeProductRecoveryH2);
if string(summary.boundaryMode) == "ribeiro_fixed_non_eq"
    fprintf(fid, '- Native toPSAil tank metrics are diagnostic only in ribeiro_fixed_non_eq mode.\n');
end
fprintf(fid, '- Ribeiro Eq. 2 boundary-basis H2 purity: %.12g\n', summary.ribeiroEq2PurityH2);
fprintf(fid, '- Ribeiro Eq. 3 boundary-basis H2 recovery: %.12g\n', summary.ribeiroEq3RecoveryH2);
fprintf(fid, '- Expected total feed, final cycle: %.12g mol\n', ...
    summary.expectedTotalFeedMolesFinalCycle);
fprintf(fid, '- Accounting total feed, final cycle: %.12g mol\n', ...
    summary.accountingTotalFeedMolesFinalCycle);
fprintf(fid, '- Total feed relative error: %.12g\n', ...
    summary.totalFeedMolesRelativeError);
fprintf(fid, '- Column feed-boundary delivered total feed, final cycle: %.12g mol\n', ...
    summary.feedBoundaryDeliveredTotalMolesFinalCycle);
fprintf(fid, '- Column feed-boundary delivered H2 feed, final cycle: %.12g mol\n', ...
    summary.feedBoundaryDeliveredBinaryH2MolesFinalCycle);
fprintf(fid, '- Column feed-boundary total relative error: %.12g\n', ...
    summary.feedBoundaryDeliveredTotalRelativeError);
fprintf(fid, '- Expected binary H2 feed, final cycle: %.12g mol\n', ...
    summary.expectedBinaryH2FeedMolesFinalCycle);
fprintf(fid, '- Accounting binary H2 feed, final cycle: %.12g mol\n', ...
    summary.accountingBinaryH2FeedMolesFinalCycle);
fprintf(fid, '- Binary feed component relative errors, H2/CO2: %s\n', ...
    numericVectorString(summary.feedMolesRelativeError));
fprintf(fid, '- Expected source purge H2, final cycle: %.12g mol\n', ...
    summary.expectedSourcePurgeH2MolesFinalCycle);
fprintf(fid, '- Boundary-counter purge H2, final cycle: %.12g mol\n', ...
    summary.boundaryCounterPurgeH2MolesFinalCycle);
fprintf(fid, '- Purge H2 relative error: %.12g\n', ...
    summary.purgeH2RelativeError);
fprintf(fid, '- Expected purge/H2-feed ratio, binary denominator: %.12g\n', ...
    summary.expectedPurgeToBinaryFeedH2Ratio);
fprintf(fid, '- Achieved purge/H2-feed ratio, binary denominator: %.12g\n', ...
    summary.achievedPurgeToBinaryFeedH2Ratio);
fprintf(fid, '- Purge/H2-feed ratio error, binary denominator: %.12g\n', ...
    summary.purgeToBinaryFeedH2RatioError);
fprintf(fid, '- Expected purge/H2-feed ratio, full-source denominator: %.12g\n', ...
    summary.expectedPurgeToFullSourceFeedH2Ratio);
fprintf(fid, '- Source Table 5 purge/H2-feed ratio, full-source denominator: %.12g\n', ...
    summary.sourceTable5PurgeToFullFeedH2Ratio);
fprintf(fid, '- H2 used for pressurization, final cycle: %.12g mol\n', ...
    summary.h2UsedForPressurizationFinalCycle);
fprintf(fid, '- H2 used for purge, final cycle: %.12g mol\n', ...
    summary.h2UsedForPurgeFinalCycle);
fprintf(fid, '- Metric basis note: %s\n', char(strjoin(string(summary.metricBasisNote), " ")));
fprintf(fid, '- Raw counter basis: %s\n', char(summary.ribeiroMetricRawCounterBasis));

if isfield(summary, 'ribeiroPressureAudit')
    audit = summary.ribeiroPressureAudit;
    fprintf(fid, '\n## Pressure audit\n\n');
    fprintf(fid, '- Basis: %s\n', char(audit.basis));
    if isfield(audit, 'maxFeedPressureErrorBar')
        fprintf(fid, '- Pressure audit, feed/high/low/pressurization: %.12g / %.12g / %.12g bar max error\n', ...
            audit.maxFeedPressureErrorBar, ...
            audit.maxLowPressureErrorBar, ...
            audit.maxPressurizationErrorBar);
    end
    fprintf(fid, '- Feed pressure mean, final cycle: %.12g bar\n', ...
        audit.feedPressureMeanBar);
    fprintf(fid, '- Blowdown end pressure mean, final cycle: %.12g bar\n', ...
        audit.blowdownEndPressureMeanBar);
    fprintf(fid, '- Purge pressure mean, final cycle: %.12g bar\n', ...
        audit.purgePressureMeanBar);
    fprintf(fid, '- Equalization pressure range, final cycle: %.12g bar\n', ...
        audit.equalizationPressureRangeBar);
    fprintf(fid, '- Pressurization end pressure mean, final cycle: %.12g bar\n', ...
        audit.pressurizationEndPressureMeanBar);
    if isfield(audit, 'feedEndPressureBarByColumn')
        fprintf(fid, '- Feed/high endpoint pressure by column, bar: %s\n', ...
            numericVectorString(audit.feedEndPressureBarByColumn));
        fprintf(fid, '- Blowdown endpoint pressure by column, bar: %s\n', ...
            numericVectorString(audit.blowdownEndPressureBarByColumn));
        fprintf(fid, '- Purge endpoint pressure by column, bar: %s\n', ...
            numericVectorString(audit.purgeEndPressureBarByColumn));
        fprintf(fid, '- Pressurization endpoint pressure by column, bar: %s\n', ...
            numericVectorString(audit.pressurizationEndPressureBarByColumn));
    end
    fprintf(fid, '- Start pressure by slot/column, bar: %s\n', ...
        numericMatrixString(audit.pressureBySlotByColumnStartBar));
    fprintf(fid, '- End pressure by slot/column, bar: %s\n', ...
        numericMatrixString(audit.pressureBySlotByColumnEndBar));
end

if isfield(summary, 'warnings') && ~isempty(summary.warnings)
    fprintf(fid, '\n## Warnings\n\n');
    for idx = 1:numel(summary.warnings)
        fprintf(fid, '- %s\n', char(summary.warnings(idx)));
    end
end

clear cleanup;
save(matPath, 'out', 'summary');

end

function text = numericVectorString(values)

if isempty(values)
    text = "[]";
    return;
end
parts = strings(1, numel(values));
for idx = 1:numel(values)
    parts(idx) = sprintf('%.12g', values(idx));
end
text = "[" + strjoin(parts, ", ") + "]";

end

function text = numericMatrixString(values)

if isempty(values)
    text = "[]";
    return;
end

rows = strings(1, size(values, 1));
for row = 1:size(values, 1)
    rows(row) = numericVectorString(values(row, :));
end
text = "[" + strjoin(rows, "; ") + "]";

end
