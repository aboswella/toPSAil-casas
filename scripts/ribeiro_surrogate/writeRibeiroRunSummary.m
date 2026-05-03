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
fprintf(fid, '- Native H2 purity: %.12g\n', summary.nativeProductPurityH2);
fprintf(fid, '- Native H2 recovery: %.12g\n', summary.nativeProductRecoveryH2);
fprintf(fid, '- Ribeiro Eq. 2 surrogate H2 purity: %.12g\n', summary.ribeiroEq2PurityH2);
fprintf(fid, '- Ribeiro Eq. 3 surrogate H2 recovery: %.12g\n', summary.ribeiroEq3RecoveryH2);
fprintf(fid, '- Expected total feed, final cycle: %.12g mol\n', ...
    summary.expectedTotalFeedMolesFinalCycle);
fprintf(fid, '- Achieved total feed, final cycle: %.12g mol\n', ...
    summary.achievedTotalFeedMolesFinalCycle);
fprintf(fid, '- Total feed relative error: %.12g\n', ...
    summary.totalFeedMolesRelativeError);
fprintf(fid, '- Expected binary H2 feed, final cycle: %.12g mol\n', ...
    summary.expectedBinaryH2FeedMolesFinalCycle);
fprintf(fid, '- Achieved binary H2 feed, final cycle: %.12g mol\n', ...
    summary.achievedBinaryH2FeedMolesFinalCycle);
fprintf(fid, '- Binary feed component relative errors, H2/CO2: %s\n', ...
    numericVectorString(summary.feedMolesRelativeError));
fprintf(fid, '- Expected source purge H2, final cycle: %.12g mol\n', ...
    summary.expectedSourcePurgeH2MolesFinalCycle);
fprintf(fid, '- Achieved purge H2, final cycle: %.12g mol\n', ...
    summary.achievedPurgeH2MolesFinalCycle);
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
fprintf(fid, '- Metric basis caveat: %s\n', char(join(string(summary.metricBasisNote), "")));
fprintf(fid, '- Raw counter basis: %s\n', char(summary.ribeiroMetricRawCounterBasis));

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
