function counterDeltas = computeYangCounterTailDeltasFromStates(params, stStates, nLocalBeds)
%COMPUTEYANGCOUNTERTAILDELTASFROMSTATES Extract native counter-tail deltas.

    if nargin < 3 || isempty(nLocalBeds)
        nLocalBeds = params.nCols;
    end
    validateInputs(params, stStates, nLocalBeds);

    counterDeltas = cell(nLocalBeds, 1);
    for i = 1:nLocalBeds
        idx = ((i-1) * params.nColStT + params.nColSt + 1):(i * params.nColStT);
        counterDeltas{i} = stStates(end, idx).' - stStates(1, idx).';
    end
end

function validateInputs(params, stStates, nLocalBeds)
    required = ["nColSt", "nColStT", "nComs"];
    if ~isstruct(params) || ~all(ismember(required, string(fieldnames(params))))
        error('FI8:InvalidCounterTailParams', ...
            'params must contain nColSt, nColStT, and nComs.');
    end
    if params.nColStT - params.nColSt ~= 2 * params.nComs
        error('FI8:UnexpectedCounterTailLength', ...
            'Native counter tail length must equal 2*nComs.');
    end
    if ~isnumeric(stStates) || size(stStates, 1) < 1 || ...
            size(stStates, 2) < nLocalBeds * params.nColStT
        error('FI8:InvalidStateHistory', ...
            'stStates must include all local native state vectors.');
    end
end
