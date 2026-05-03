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
audit.feedMeanPressureBar = NaN;
audit.feedEndPressureBar = NaN;
audit.feedPressureErrorBar = NaN;
audit.blowdownEndPressureMeanBar = NaN;
audit.blowdownEndPressureBar = NaN;
audit.purgePressureMeanBar = NaN;
audit.purgeMeanPressureBar = NaN;
audit.lowPressureErrorBar = NaN;
audit.equalizationPressureRangeBar = NaN;
audit.pressurizationEndPressureMeanBar = NaN;
audit.pressurizationEndPressureBar = NaN;
audit.pressurizationPressureErrorBar = NaN;
audit.maxFeedPressureErrorBar = NaN;
audit.maxLowPressureErrorBar = NaN;
audit.maxPressurizationErrorBar = NaN;
audit.equalizationTransferBySlot = struct([]);
audit.equalizationTransferNonzero = false;
audit.equalizationDonorPressureOrderingPass = false;
audit.equalizationReceiverPressureOrderingPass = false;
audit.equalizationPressureOrderingByColumn = struct([]);
audit.maxBoundaryMolarFlowMolSecEffective = getBoundaryCap(params);
audit.blowdownCapActiveSampleCount = 0;
audit.pressurizationCapActiveSampleCount = 0;
audit.maxBlowdownUncappedDemandMolSec = NaN;
audit.maxPressurizationUncappedDemandMolSec = NaN;
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
audit.feedMeanPressureBar = audit.feedPressureMeanBar;
audit.feedEndPressureBar = audit.feedPressureMeanBar;
audit.feedPressureErrorBar = absFinite( ...
    audit.feedEndPressureBar - params.presColHigh);
audit.blowdownEndPressureMeanBar = safeMean(audit.blowdownEndPressureBarByColumn);
audit.blowdownEndPressureBar = audit.blowdownEndPressureMeanBar;
audit.purgePressureMeanBar = safeMean(audit.purgeEndPressureBarByColumn);
audit.purgeMeanPressureBar = audit.purgePressureMeanBar;
audit.equalizationPressureRangeBar = rangeFinite(getEqualizationPressures(params, audit));
audit.pressurizationEndPressureMeanBar = safeMean(audit.pressurizationEndPressureBarByColumn);
audit.pressurizationEndPressureBar = audit.pressurizationEndPressureMeanBar;
audit.pressurizationPressureErrorBar = absFinite( ...
    audit.pressurizationEndPressureBar - params.presColHigh);

audit.maxFeedPressureErrorBar = maxAbsFinite( ...
    feedEndpointValues - params.presColHigh);
audit.maxLowPressureErrorBar = maxAbsFinite(lowEndpointValues - params.presColLow);
audit.maxPressurizationErrorBar = maxAbsFinite( ...
    pressEndpointValues - params.presColHigh);
audit.lowPressureErrorBar = audit.maxLowPressureErrorBar;
audit.equalizationTransferBySlot = buildEqualizationTransferAudit( ...
    params, schedule, sol, lastCycle, audit);
audit.equalizationTransferNonzero = anyEqualizationTransferNonzero( ...
    audit.equalizationTransferBySlot, params.numZero);
audit.equalizationPressureOrderingByColumn = ...
    buildEqualizationPressureOrdering(params, schedule, audit);
audit.equalizationDonorPressureOrderingPass = allStructField( ...
    audit.equalizationPressureOrderingByColumn, 'donorOrderingPass');
audit.equalizationReceiverPressureOrderingPass = allStructField( ...
    audit.equalizationPressureOrderingByColumn, 'receiverOrderingPass');
audit = addBoundaryCapAudit(params, schedule, sol, lastCycle, audit);
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

function value = absFinite(value)

if ~isfinite(value)
    value = NaN;
else
    value = abs(value);
end

end

function cap = getBoundaryCap(params)

cap = NaN;
if isfield(params, 'ribeiroBoundary') && isstruct(params.ribeiroBoundary)
    if isfield(params.ribeiroBoundary, 'maxBoundaryMolarFlowMolSecEffective')
        cap = params.ribeiroBoundary.maxBoundaryMolarFlowMolSecEffective;
    elseif isfield(params.ribeiroBoundary, 'maxBoundaryMolarFlowMolSec')
        cap = params.ribeiroBoundary.maxBoundaryMolarFlowMolSec;
    end
end

end

function eqAudit = buildEqualizationTransferAudit(params, schedule, sol, lastCycle, audit)

eqAudit = struct([]);
if isempty(sol) || lastCycle < 1 || ~isstruct(schedule) || ...
        ~isfield(schedule, 'eqRoleByCol')
    return;
end

stepInit = (lastCycle - 1) * params.nSteps + 1;
entryIdx = 0;

for localSlot = 1:params.nSteps
    eqCols = find(string(params.sStepCol(:, localSlot)) == "EQ-XXX-APR");
    if numel(eqCols) ~= 2
        continue;
    end

    stepField = sprintf('Step%d', stepInit + localSlot - 1);
    if ~isfield(sol, stepField) || ~isfield(sol.(stepField), 'col')
        continue;
    end

    roles = schedule.eqRoleByCol(eqCols, localSlot);
    donorLocal = find(startsWith(roles, "donor"), 1);
    receiverLocal = find(startsWith(roles, "receiver"), 1);
    if isempty(donorLocal) || isempty(receiverLocal)
        continue;
    end

    donorCol = eqCols(donorLocal);
    receiverCol = eqCols(receiverLocal);
    donorField = params.sColNums{donorCol};
    receiverField = params.sColNums{receiverCol};
    if ~isfield(sol.(stepField).col, donorField) || ...
            ~isfield(sol.(stepField).col, receiverField)
        continue;
    end

    donor = sol.(stepField).col.(donorField);
    receiver = sol.(stepField).col.(receiverField);

    entryIdx = entryIdx + 1;
    eqAudit(entryIdx).slotIndex = localSlot;
    eqAudit(entryIdx).pair = string(schedule.columnNames(eqCols)).';
    eqAudit(entryIdx).roles = roles(:).';
    eqAudit(entryIdx).donorColumn = string(schedule.columnNames(donorCol));
    eqAudit(entryIdx).receiverColumn = string(schedule.columnNames(receiverCol));
    eqAudit(entryIdx).donorRole = string(schedule.eqRoleByCol(donorCol, localSlot));
    eqAudit(entryIdx).receiverRole = string(schedule.eqRoleByCol(receiverCol, localSlot));
    eqAudit(entryIdx).donorStartPressureBar = ...
        audit.pressureBySlotByColumnStartBar(donorCol, localSlot);
    eqAudit(entryIdx).donorEndPressureBar = ...
        audit.pressureBySlotByColumnEndBar(donorCol, localSlot);
    eqAudit(entryIdx).receiverStartPressureBar = ...
        audit.pressureBySlotByColumnStartBar(receiverCol, localSlot);
    eqAudit(entryIdx).receiverEndPressureBar = ...
        audit.pressureBySlotByColumnEndBar(receiverCol, localSlot);
    eqAudit(entryIdx).donorProductEndSignedMoles = ...
        getColumnCounterMoles(params, donor, 'prod');
    eqAudit(entryIdx).receiverProductEndSignedMoles = ...
        getColumnCounterMoles(params, receiver, 'prod');
    eqAudit(entryIdx).signedPairTransferMoles = ...
        eqAudit(entryIdx).donorProductEndSignedMoles;
    eqAudit(entryIdx).productEndValveCoefficient = ...
        params.valProdCol(donorCol, localSlot);
end

end

function moles = getColumnCounterMoles(params, col, endName)

moles = NaN(1, params.nComs);
if isfield(col, 'cumMol') && isfield(col.cumMol, endName) && ...
        ~isempty(col.cumMol.(endName))
    moles = col.cumMol.(endName)(end, :) .* params.nScaleFac;
end

end

function tf = anyEqualizationTransferNonzero(eqAudit, numZero)

tf = false;
for idx = 1:numel(eqAudit)
    values = eqAudit(idx).signedPairTransferMoles;
    if any(isfinite(values) & abs(values) > numZero)
        tf = true;
        return;
    end
end

end

function ordering = buildEqualizationPressureOrdering(params, schedule, audit)

ordering = repmat(struct( ...
    'column', "", ...
    'highPressureBar', NaN, ...
    'afterD1PressureBar', NaN, ...
    'afterD2PressureBar', NaN, ...
    'lowPressureBar', NaN, ...
    'afterP1PressureBar', NaN, ...
    'afterP2PressureBar', NaN, ...
    'afterPressurizationPressureBar', NaN, ...
    'donorOrderingPass', false, ...
    'receiverOrderingPass', false), params.nCols, 1);

if ~isstruct(schedule) || ~isfield(schedule, 'logicalLabelsByCol')
    return;
end

for colIdx = 1:params.nCols
    labels = string(schedule.logicalLabelsByCol(colIdx, :));
    endPressures = audit.pressureBySlotByColumnEndBar(colIdx, :);
    lowCandidates = endPressures(labels == "BLOWDOWN" | labels == "PURGE");

    ordering(colIdx).column = sprintf('n%d', colIdx);
    ordering(colIdx).highPressureBar = lastForLabel(labels, endPressures, "FEED");
    ordering(colIdx).afterD1PressureBar = lastForLabel(labels, endPressures, "EQ_D1");
    ordering(colIdx).afterD2PressureBar = lastForLabel(labels, endPressures, "EQ_D2");
    ordering(colIdx).lowPressureBar = safeMean(lowCandidates(:));
    ordering(colIdx).afterP1PressureBar = lastForLabel(labels, endPressures, "EQ_P1");
    ordering(colIdx).afterP2PressureBar = lastForLabel(labels, endPressures, "EQ_P2");
    ordering(colIdx).afterPressurizationPressureBar = ...
        lastForLabel(labels, endPressures, "PRESSURIZATION");

    donorValues = [
        ordering(colIdx).highPressureBar
        ordering(colIdx).afterD1PressureBar
        ordering(colIdx).afterD2PressureBar
        ordering(colIdx).lowPressureBar
    ];
    receiverValues = [
        ordering(colIdx).lowPressureBar
        ordering(colIdx).afterP1PressureBar
        ordering(colIdx).afterP2PressureBar
        ordering(colIdx).afterPressurizationPressureBar
    ];
    ordering(colIdx).donorOrderingPass = all(isfinite(donorValues)) && ...
        all(diff(donorValues) < 0);
    ordering(colIdx).receiverOrderingPass = all(isfinite(receiverValues)) && ...
        all(diff(receiverValues) > 0);
end

end

function value = lastForLabel(labels, values, label)

idx = find(labels == label, 1, 'last');
if isempty(idx)
    value = NaN;
else
    value = values(idx);
end

end

function tf = allStructField(values, fieldName)

if isempty(values)
    tf = false;
    return;
end

tf = true;
for idx = 1:numel(values)
    if ~isfield(values(idx), fieldName) || ~values(idx).(fieldName)
        tf = false;
        return;
    end
end

end

function audit = addBoundaryCapAudit(params, ~, sol, lastCycle, audit)

if isempty(sol) || lastCycle < 1 || ~isfinite(audit.maxBoundaryMolarFlowMolSecEffective)
    return;
end

stepInit = (lastCycle - 1) * params.nSteps + 1;
blowdownDemand = zeros(0, 1);
pressDemand = zeros(0, 1);

for localSlot = 1:params.nSteps
    stepField = sprintf('Step%d', stepInit + localSlot - 1);
    if ~isfield(sol, stepField) || ~isfield(sol.(stepField), 'col')
        continue;
    end
    for colIdx = 1:params.nCols
        label = string(params.sStepCol{colIdx, localSlot});
        colField = params.sColNums{colIdx};
        if ~isfield(sol.(stepField).col, colField)
            continue;
        end
        col = sol.(stepField).col.(colField);
        switch label
            case "DP-ATM-XXX"
                pressureBar = getBoundaryPressureTraceBar(params, col, 1);
                demand = params.ribeiroBoundary.blowdownGainMolSecBar ...
                    .* max(0, pressureBar - params.presColLow);
                blowdownDemand = [blowdownDemand; demand(:)]; %#ok<AGROW>
            case "RP-XXX-RAF"
                pressureBar = getBoundaryPressureTraceBar(params, col, params.nVols);
                demand = params.ribeiroBoundary.pressurizationGainMolSecBar ...
                    .* max(0, params.presColHigh - pressureBar);
                pressDemand = [pressDemand; demand(:)]; %#ok<AGROW>
        end
    end
end

cap = audit.maxBoundaryMolarFlowMolSecEffective;
audit.maxBlowdownUncappedDemandMolSec = maxFinite(blowdownDemand);
audit.maxPressurizationUncappedDemandMolSec = maxFinite(pressDemand);
audit.blowdownCapActiveSampleCount = nnz(isfinite(blowdownDemand) ...
    & blowdownDemand > cap + params.numZero);
audit.pressurizationCapActiveSampleCount = nnz(isfinite(pressDemand) ...
    & pressDemand > cap + params.numZero);

end

function pressureBar = getBoundaryPressureTraceBar(params, col, volIdx)

pressureBar = NaN;
if ~isfield(col, 'gasConsTot') || ~isfield(col, 'temps') || ...
        ~isfield(col.temps, 'cstr')
    return;
end

volIdx = max(1, min(volIdx, size(col.gasConsTot, 2)));
pressureBar = col.gasConsTot(:, volIdx) ...
    .* params.gConScaleFac ...
    .* params.gasCons ...
    .* col.temps.cstr(:, volIdx) ...
    .* params.teScaleFac;

end

function value = maxFinite(values)

finiteValues = values(isfinite(values));
if isempty(finiteValues)
    value = NaN;
else
    value = max(finiteValues);
end

end

function warnings = pressureGateWarnings(~, audit)

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

if ~audit.equalizationTransferNonzero
    warnings(end+1, 1) = ...
        "Equalization transfer audit found no nonzero final-cycle product-end transfer.";
end

if ~audit.equalizationDonorPressureOrderingPass
    warnings(end+1, 1) = ...
        "Equalization donor pressure ordering failed: expected high > after_D1 > after_D2 > low.";
end

if ~audit.equalizationReceiverPressureOrderingPass
    warnings(end+1, 1) = ...
        "Equalization receiver pressure ordering failed: expected low < after_P1 < after_P2 < high.";
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
