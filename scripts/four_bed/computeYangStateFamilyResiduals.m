function rows = computeYangStateFamilyResiduals(initialState, finalState, varargin)
%COMPUTEYANGSTATEFAMILYRESIDUALS Compute per-family state residual rows.

    parser = inputParser;
    addParameter(parser, 'Params', []);
    addParameter(parser, 'CycleIndex', NaN);
    addParameter(parser, 'Bed', "not_supplied");
    addParameter(parser, 'StateField', "not_supplied");
    addParameter(parser, 'AbsTol', 1e-8);
    addParameter(parser, 'RelTol', 1e-6);
    parse(parser, varargin{:});
    opts = parser.Results;

    rows = makeEmptyRows();
    try
        initialVector = extractYangStateVector(initialState);
        finalVector = extractYangStateVector(finalState);
    catch err
        rows = appendResidualRow(rows, opts, "unsupported_payload", 0, NaN, NaN, NaN, false, ...
            "Unsupported CSS payload: " + string(err.message));
        return;
    end

    if numel(initialVector) ~= numel(finalVector)
        rows = appendResidualRow(rows, opts, "unsupported_payload", 0, NaN, NaN, NaN, false, ...
            "Initial and final state vectors have different lengths.");
        return;
    end

    params = opts.Params;
    if isempty(params)
        rows = appendFamilyResidual(rows, opts, "state_vector", initialVector, finalVector, 1:numel(initialVector), ...
            "State-vector residual without toPSAil family split.");
        return;
    end

    if ~isstruct(params) || ~isfield(params, 'nComs')
        rows = appendResidualRow(rows, opts, "unsupported_payload", numel(initialVector), NaN, NaN, NaN, false, ...
            "Params supplied for CSS split must include nComs.");
        return;
    end

    nComs = params.nComs;
    if isfield(params, 'nStates')
        nStates = params.nStates;
    else
        nStates = 2*nComs + 2;
    end
    if isfield(params, 'nVols')
        nVols = params.nVols;
    elseif isfield(params, 'nColStT')
        nVols = (params.nColStT - 2*nComs) / nStates;
    else
        rows = appendResidualRow(rows, opts, "unsupported_payload", numel(initialVector), NaN, NaN, NaN, false, ...
            "Params supplied for CSS split must include nVols or nColStT.");
        return;
    end

    if nVols ~= floor(nVols) || nVols < 1
        rows = appendResidualRow(rows, opts, "unsupported_payload", numel(initialVector), NaN, NaN, NaN, false, ...
            "Params imply a non-integer or invalid number of volumes.");
        return;
    end

    persistentLength = nStates * nVols;
    boundaryLength = 2 * nComs;
    if numel(initialVector) < persistentLength
        rows = appendResidualRow(rows, opts, "unsupported_payload", numel(initialVector), NaN, NaN, NaN, false, ...
            "State vector is shorter than the persistent CSTR layout implied by Params.");
        return;
    end

    gasIdx = [];
    adsIdx = [];
    gasTempIdx = [];
    wallTempIdx = [];
    for v = 1:nVols
        base = (v - 1) * nStates;
        gasIdx = [gasIdx, base + (1:nComs)]; %#ok<AGROW>
        adsIdx = [adsIdx, base + nComs + (1:nComs)]; %#ok<AGROW>
        gasTempIdx = [gasTempIdx, base + 2*nComs + 1]; %#ok<AGROW>
        wallTempIdx = [wallTempIdx, base + 2*nComs + 2]; %#ok<AGROW>
    end

    rows = appendFamilyResidual(rows, opts, "gas_concentration", initialVector, finalVector, gasIdx, ...
        "Gas concentration CSS residual.");
    rows = appendFamilyResidual(rows, opts, "adsorbed_loading", initialVector, finalVector, adsIdx, ...
        "Adsorbed loading CSS residual.");
    rows = appendFamilyResidual(rows, opts, "gas_temperature", initialVector, finalVector, gasTempIdx, ...
        "Gas temperature CSS residual.");
    rows = appendFamilyResidual(rows, opts, "wall_temperature", initialVector, finalVector, wallTempIdx, ...
        "Wall temperature CSS residual.");

    if numel(initialVector) >= persistentLength + boundaryLength
        rows = appendResidualRow(rows, opts, "boundary_cumulative_flow_excluded", boundaryLength, ...
            0, 0, 0, true, ...
            "Trailing cumulative boundary-flow counters are excluded from CSS residuals.");
    end
end

function rows = makeEmptyRows()
    rows = table( ...
        zeros(0, 1), ...
        strings(0, 1), ...
        strings(0, 1), ...
        strings(0, 1), ...
        zeros(0, 1), ...
        zeros(0, 1), ...
        zeros(0, 1), ...
        zeros(0, 1), ...
        false(0, 1), ...
        strings(0, 1), ...
        'VariableNames', [
            "cycle_index"
            "bed"
            "state_field"
            "family"
            "n_values"
            "max_abs"
            "rms_abs"
            "relative_norm"
            "pass"
            "notes"
        ]);
end

function rows = appendFamilyResidual(rows, opts, family, initialVector, finalVector, idx, notes)
    idx = idx(:);
    diffValues = finalVector(idx) - initialVector(idx);
    maxAbs = max(abs(diffValues));
    rmsAbs = sqrt(mean(diffValues.^2));
    scale = max([max(abs(initialVector(idx))), max(abs(finalVector(idx))), opts.AbsTol]);
    relativeNorm = maxAbs / scale;
    tol = opts.AbsTol + opts.RelTol * scale;
    pass = maxAbs <= tol;
    rows = appendResidualRow(rows, opts, family, numel(idx), maxAbs, rmsAbs, relativeNorm, pass, notes);
end

function rows = appendResidualRow(rows, opts, family, nValues, maxAbs, rmsAbs, relativeNorm, pass, notes)
    row = table( ...
        double(opts.CycleIndex), ...
        string(opts.Bed), ...
        string(opts.StateField), ...
        string(family), ...
        double(nValues), ...
        double(maxAbs), ...
        double(rmsAbs), ...
        double(relativeNorm), ...
        logical(pass), ...
        string(notes), ...
        'VariableNames', rows.Properties.VariableNames);
    rows = [rows; row];
end
