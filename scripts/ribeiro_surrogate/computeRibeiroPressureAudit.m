function audit = computeRibeiroPressureAudit(params, schedule, sol)
%COMPUTERIBEIROPRESSUREAUDIT Audit final-cycle native column pressures.

audit = struct();
audit.version = "Ribeiro2008-surrogate-pressure-audit-v1";
audit.lastCompleteCycle = resolveLastCompleteCycle(params, sol);
audit.basis = "Average CSTR pressure from native gasConsTot and temps.cstr, using the same ideal-gas basis as plotColPresProfiles.";
audit.pressureBySlotByColumnStartBar = NaN(params.nCols, params.nSteps);
audit.pressureBySlotByColumnEndBar = NaN(params.nCols, params.nSteps);
audit.pressureByStepFamilyMinMeanMaxBar = struct();
audit.feedPressureMeanBar = NaN;
audit.blowdownEndPressureMeanBar = NaN;
audit.purgePressureMeanBar = NaN;
audit.equalizationPressureRangeBar = NaN;
audit.pressurizationEndPressureMeanBar = NaN;
audit.warnings = strings(0, 1);

if isempty(sol)
    audit.warnings(end+1, 1) = "No solution supplied; pressure audit was not computed.";
    return;
end
if audit.lastCompleteCycle < 1
    audit.warnings(end+1, 1) = "No complete cycle available; pressure audit was not computed.";
    return;
end

[samplesByFamily, endByFamily] = initializeFamilyMaps(schedule);
stepInit = (audit.lastCompleteCycle - 1) * params.nSteps + 1;

try
    for localSlot = 1:params.nSteps
        stepIndex = stepInit + localSlot - 1;
        stepField = sprintf('Step%d', stepIndex);
        if ~isfield(sol, stepField)
            continue;
        end

        for col = 1:params.nCols
            colField = params.sColNums{col};
            if ~isfield(sol.(stepField).col, colField)
                continue;
            end

            pressureBar = getColumnPressureBar(params, sol.(stepField).col.(colField));
            if isempty(pressureBar)
                continue;
            end

            family = char(schedule.logicalLabelsByCol(col, localSlot));
            audit.pressureBySlotByColumnStartBar(col, localSlot) = pressureBar(1);
            audit.pressureBySlotByColumnEndBar(col, localSlot) = pressureBar(end);
            samplesByFamily.(family) = [samplesByFamily.(family); pressureBar(:)];
            endByFamily.(family) = [endByFamily.(family); pressureBar(end)];
        end
    end
catch err
    audit.warnings(end+1, 1) = "Pressure audit extraction failed: " + string(err.message);
    return;
end

familyNames = fieldnames(samplesByFamily);
for idx = 1:numel(familyNames)
    family = familyNames{idx};
    values = samplesByFamily.(family);
    audit.pressureByStepFamilyMinMeanMaxBar.(family) = minMeanMax(values);
end

audit.feedPressureMeanBar = safeMean(samplesByFamily.FEED);
audit.blowdownEndPressureMeanBar = safeMean(endByFamily.BLOWDOWN);
audit.purgePressureMeanBar = safeMean(samplesByFamily.PURGE);
audit.equalizationPressureRangeBar = rangeFinite([
    samplesByFamily.EQ_D1
    samplesByFamily.EQ_D2
    samplesByFamily.EQ_P1
    samplesByFamily.EQ_P2
]);
audit.pressurizationEndPressureMeanBar = safeMean(endByFamily.PRESSURIZATION);
audit.warnings = [audit.warnings; pressureGateWarnings(params, audit)];

end

function [samplesByFamily, endByFamily] = initializeFamilyMaps(schedule)

families = unique(string(schedule.logicalLabelsByCol(:)), 'stable');
samplesByFamily = struct();
endByFamily = struct();
for idx = 1:numel(families)
    family = char(families(idx));
    samplesByFamily.(family) = zeros(0, 1);
    endByFamily.(family) = zeros(0, 1);
end

end

function pressureBar = getColumnPressureBar(params, col)

pressureBar = [];
if ~isfield(col, 'gasConsTot') || ~isfield(col, 'temps') || ...
        ~isfield(col.temps, 'cstr')
    return;
end

gasConsTot = col.gasConsTot;
cstrTemps = col.temps.cstr;
pressureBar = mean(gasConsTot, 2) ...
    .* params.gConScaleFac ...
    .* params.gasCons ...
    .* mean(cstrTemps, 2) ...
    .* params.teScaleFac;

end

function stats = minMeanMax(values)

finiteValues = values(isfinite(values));
if isempty(finiteValues)
    stats = [NaN, NaN, NaN];
else
    stats = [min(finiteValues), mean(finiteValues), max(finiteValues)];
end

end

function value = safeMean(values)

finiteValues = values(isfinite(values));
if isempty(finiteValues)
    value = NaN;
else
    value = mean(finiteValues);
end

end

function value = rangeFinite(values)

finiteValues = values(isfinite(values));
if isempty(finiteValues)
    value = NaN;
else
    value = max(finiteValues) - min(finiteValues);
end

end

function warnings = pressureGateWarnings(params, audit)

warnings = strings(0, 1);
highPressureBar = params.presColHigh;
lowPressureBar = params.presColLow;
highToleranceBar = 0.5;
lowToleranceBar = 0.5;
eqMinimumRangeBar = 0.5;

if isfinite(audit.feedPressureMeanBar) && ...
        abs(audit.feedPressureMeanBar - highPressureBar) > highToleranceBar
    warnings(end+1, 1) = sprintf( ...
        'HP-FEE-RAF final-cycle pressure is %.3g bar, not near %.3g bar.', ...
        audit.feedPressureMeanBar, highPressureBar);
end

if isfinite(audit.blowdownEndPressureMeanBar) && ...
        abs(audit.blowdownEndPressureMeanBar - lowPressureBar) > lowToleranceBar
    warnings(end+1, 1) = sprintf( ...
        'DP-ATM-XXX final-cycle end pressure is %.3g bar, not near %.3g bar.', ...
        audit.blowdownEndPressureMeanBar, lowPressureBar);
end

if isfinite(audit.purgePressureMeanBar) && ...
        abs(audit.purgePressureMeanBar - lowPressureBar) > lowToleranceBar
    warnings(end+1, 1) = sprintf( ...
        'LP-ATM-RAF final-cycle pressure is %.3g bar, not near %.3g bar.', ...
        audit.purgePressureMeanBar, lowPressureBar);
end

if isfinite(audit.equalizationPressureRangeBar) && ...
        audit.equalizationPressureRangeBar < eqMinimumRangeBar
    warnings(end+1, 1) = sprintf( ...
        'Equalization final-cycle pressure range is %.3g bar; staged equalization is not resolved.', ...
        audit.equalizationPressureRangeBar);
end

if isfinite(audit.pressurizationEndPressureMeanBar) && ...
        abs(audit.pressurizationEndPressureMeanBar - highPressureBar) > highToleranceBar
    warnings(end+1, 1) = sprintf( ...
        'RP-XXX-RAF final-cycle end pressure is %.3g bar, not near %.3g bar.', ...
        audit.pressurizationEndPressureMeanBar, highPressureBar);
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
