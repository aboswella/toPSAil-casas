function moles = getRibeiroColumnStepCounterMoles(params, sol, lastCycle, stepLabel, endName)
%GETRIBEIROCOLUMNSTEPCOUNTERMOLES Sum final-cycle column boundary counters.

if nargin < 5
    error('RibeiroSurrogate:MissingCounterEnd', ...
        'endName must be "prod" or "feed".');
end

endName = string(endName);
if ~(endName == "prod" || endName == "feed")
    error('RibeiroSurrogate:InvalidCounterEnd', ...
        'endName must be "prod" or "feed".');
end

moles = zeros(1, params.nComs);
if isempty(sol) || lastCycle < 1
    return;
end

stepLabel = string(stepLabel);
stepInit = (lastCycle - 1) * params.nSteps + 1;

for localSlot = 1:params.nSteps
    if string(params.sStepCol{1, localSlot}) == ""
        continue;
    end

    stepIndex = stepInit + localSlot - 1;
    stepField = sprintf('Step%d', stepIndex);
    if ~isfield(sol, stepField) || ~isfield(sol.(stepField), 'col')
        continue;
    end

    for colIdx = 1:params.nCols
        if string(params.sStepCol{colIdx, localSlot}) ~= stepLabel
            continue;
        end

        colField = params.sColNums{colIdx};
        if ~isfield(sol.(stepField).col, colField)
            continue;
        end

        col = sol.(stepField).col.(colField);
        if ~isfield(col, 'cumMol') || ~isfield(col.cumMol, char(endName)) || ...
                isempty(col.cumMol.(char(endName)))
            continue;
        end

        counter = col.cumMol.(char(endName));
        moles = moles + counter(end, :) .* params.nScaleFac;
    end
end

moles = moles(:).';

end
