function audit = getRibeiroPressureAudit(params, schedule, sol, lastCycle)
%GETRIBEIROPRESSUREAUDIT Audit final-cycle pressure endpoint gates.

if nargin < 4 || isempty(lastCycle)
    lastCycle = resolveLastCompleteCycle(params, sol);
end

audit = struct();
audit.version = "Ribeiro2008-boundary-pressure-audit-v1";
audit.lastCompleteCycle = lastCycle;
audit.basis = "Final-cycle average column pressure from native gasConsTot and temps.cstr, dimensionalized with native ideal-gas factors.";
audit.feedEndPressureBarByColumn = NaN(params.nCols, 1);
audit.blowdownEndPressureBarByColumn = NaN(params.nCols, 1);
audit.purgeEndPressureBarByColumn = NaN(params.nCols, 1);
audit.pressurizationEndPressureBarByColumn = NaN(params.nCols, 1);
audit.pressureBySlotByColumnStartBar = NaN(params.nCols, params.nSteps);
audit.pressureBySlotByColumnEndBar = NaN(params.nCols, params.nSteps);
audit.pressureByStepFamilyMinMeanMaxBar = struct();
audit.feedPressureMeanBar = NaN;
audit.blowdownEndPressureMeanBar = NaN;
audit.purgePressureMeanBar = NaN;
audit.equalizationPressureRangeBar = NaN;
audit.pressurizationEndPressureMeanBar = NaN;
audit.maxFeedPressureErrorBar = NaN;
audit.maxLowPressureErrorBar = NaN;
audit.maxPressurizationErrorBar = NaN;
audit.warnings = strings(0, 1);

if isempty(sol)
    audit.warnings(end+1, 1) = "No solution supplied; pressure audit was not computed.";
    return;
end
if lastCycle < 1
    audit.warnings(end+1, 1) = "No complete cycle available; pressure audit was not computed.";
    return;
end

families = getScheduleFamilies(schedule);
samplesByFamily = initializeFamilyMap(families);
stepInit = (lastCycle - 1) * params.nSteps + 1;
feedEndpointValues = zeros(0, 1);
lowEndpointValues = zeros(0, 1);
pressEndpointValues = zeros(0, 1);

try
    for localSlot = 1:params.nSteps
        stepIndex = stepInit + localSlot - 1;
        stepField = sprintf('Step%d', stepIndex);
        if ~isfield(sol, stepField) || ~isfield(sol.(stepField), 'col')
            continue;
        end

        for colIdx = 1:params.nCols
            colField = params.sColNums{colIdx};
            if ~isfield(sol.(stepField).col, colField)
                continue;
            end

            col = sol.(stepField).col.(colField);
            startPressureBar = getColumnPressureAtRowBar(params, col, 1);
            endPressureBar = getColumnPressureAtRowBar(params, col, getColumnTimeRows(col));
            audit.pressureBySlotByColumnStartBar(colIdx, localSlot) = startPressureBar;
            audit.pressureBySlotByColumnEndBar(colIdx, localSlot) = endPressureBar;

            family = getFamilyForSlot(schedule, colIdx, localSlot);
            if ~isempty(family) && isfield(samplesByFamily, family)
                samplesByFamily.(family) = [samplesByFamily.(family); endPressureBar];
            end

            label = string(params.sStepCol{colIdx, localSlot});
            switch label
                case "HP-FEE-RAF"
                    audit.feedEndPressureBarByColumn(colIdx) = endPressureBar;
                    feedEndpointValues(end+1, 1) = endPressureBar; %#ok<AGROW>
                case "DP-ATM-XXX"
                    audit.blowdownEndPressureBarByColumn(colIdx) = endPressureBar;
                    lowEndpointValues(end+1, 1) = endPressureBar; %#ok<AGROW>
                case "LP-ATM-RAF"
                    audit.purgeEndPressureBarByColumn(colIdx) = endPressureBar;
                    lowEndpointValues(end+1, 1) = endPressureBar; %#ok<AGROW>
                case "RP-XXX-RAF"
                    audit.pressurizationEndPressureBarByColumn(colIdx) = endPressureBar;
                    pressEndpointValues(end+1, 1) = endPressureBar; %#ok<AGROW>
            end
        end
    end
catch err
    audit.warnings(end+1, 1) = "Pressure audit extraction failed: " + string(err.message);
    return;
end

familyNames = fieldnames(samplesByFamily);
for idx = 1:numel(familyNames)
    family = familyNames{idx};
    audit.pressureByStepFamilyMinMeanMaxBar.(family) = minMeanMax(samplesByFamily.(family));
end

audit.feedPressureMeanBar = safeMean(audit.feedEndPressureBarByColumn);
audit.blowdownEndPressureMeanBar = safeMean(audit.blowdownEndPressureBarByColumn);
audit.purgePressureMeanBar = safeMean(audit.purgeEndPressureBarByColumn);
audit.equalizationPressureRangeBar = rangeFinite(getEqualizationPressures(params, audit));
audit.pressurizationEndPressureMeanBar = safeMean(audit.pressurizationEndPressureBarByColumn);

audit.maxFeedPressureErrorBar = maxAbsFinite( ...
    feedEndpointValues - params.presColHigh);
audit.maxLowPressureErrorBar = maxAbsFinite(lowEndpointValues - params.presColLow);
audit.maxPressurizationErrorBar = maxAbsFinite( ...
    pressEndpointValues - params.presColHigh);
audit.warnings = [audit.warnings; pressureGateWarnings(params, audit)];

end

function families = getScheduleFamilies(schedule)

if isstruct(schedule) && isfield(schedule, 'logicalLabelsByCol')
    families = unique(string(schedule.logicalLabelsByCol(:)), 'stable');
else
    families = strings(0, 1);
end
families(families == "") = [];

end

function samplesByFamily = initializeFamilyMap(families)

samplesByFamily = struct();
for idx = 1:numel(families)
    samplesByFamily.(char(families(idx))) = zeros(0, 1);
end

end

function family = getFamilyForSlot(schedule, colIdx, localSlot)

family = '';
if isstruct(schedule) && isfield(schedule, 'logicalLabelsByCol') && ...
        size(schedule.logicalLabelsByCol, 1) >= colIdx && ...
        size(schedule.logicalLabelsByCol, 2) >= localSlot
    family = char(schedule.logicalLabelsByCol(colIdx, localSlot));
end

end

function nRows = getColumnTimeRows(col)

nRows = 1;
if isfield(col, 'gasConsTot') && ~isempty(col.gasConsTot)
    nRows = size(col.gasConsTot, 1);
end

end

function pressureBar = getColumnPressureAtRowBar(params, col, rowIdx)

pressureBar = NaN;
if ~isfield(col, 'gasConsTot') || ~isfield(col, 'temps') || ...
        ~isfield(col.temps, 'cstr') || isempty(col.gasConsTot) || ...
        isempty(col.temps.cstr)
    return;
end

rowIdx = max(1, min(rowIdx, size(col.gasConsTot, 1)));
tempRowIdx = max(1, min(rowIdx, size(col.temps.cstr, 1)));
pressureBar = mean(col.gasConsTot(rowIdx, :), 2) ...
    .* params.gConScaleFac ...
    .* params.gasCons ...
    .* mean(col.temps.cstr(tempRowIdx, :), 2) ...
    .* params.teScaleFac;

end

function values = getEqualizationPressures(params, audit)

values = zeros(0, 1);
for colIdx = 1:params.nCols
    for slotIdx = 1:params.nSteps
        if string(params.sStepCol{colIdx, slotIdx}) == "EQ-XXX-APR"
            values(end+1, 1) = audit.pressureBySlotByColumnEndBar(colIdx, slotIdx); %#ok<AGROW>
        end
    end
end

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

function value = maxAbsFinite(values)

finiteValues = values(isfinite(values));
if isempty(finiteValues)
    value = NaN;
else
    value = max(abs(finiteValues));
end

end

function warnings = pressureGateWarnings(params, audit)

warnings = strings(0, 1);
toleranceBar = 0.5;

if isfinite(audit.maxFeedPressureErrorBar) && ...
        audit.maxFeedPressureErrorBar > toleranceBar
    warnings(end+1, 1) = sprintf( ...
        'HP-FEE-RAF final-cycle pressure gate failed: max high-pressure error is %.3g bar.', ...
        audit.maxFeedPressureErrorBar);
end

if isfinite(audit.maxLowPressureErrorBar) && ...
        audit.maxLowPressureErrorBar > toleranceBar
    warnings(end+1, 1) = sprintf( ...
        'DP-ATM-XXX/LP-ATM-RAF final-cycle pressure gate failed: max low-pressure error is %.3g bar.', ...
        audit.maxLowPressureErrorBar);
end

if isfinite(audit.maxPressurizationErrorBar) && ...
        audit.maxPressurizationErrorBar > toleranceBar
    warnings(end+1, 1) = sprintf( ...
        'RP-XXX-RAF final-cycle pressure gate failed: max high-pressure error is %.3g bar.', ...
        audit.maxPressurizationErrorBar);
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
