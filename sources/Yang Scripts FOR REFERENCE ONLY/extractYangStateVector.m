function stateVector = extractYangStateVector(statePayload, varargin)
%EXTRACTYANGSTATEVECTOR Resolve a physical Yang bed-state vector.
%
% CSS and persistent-state comparisons use only the physical adsorber state.
% If Params are supplied, native nColStT vectors are sliced to nColSt.

    parser = inputParser;
    addParameter(parser, 'Params', []);
    parse(parser, varargin{:});
    opts = parser.Results;

    if isnumeric(statePayload)
        stateVector = statePayload;
    elseif isstruct(statePayload) && isfield(statePayload, 'physicalStateVector')
        stateVector = statePayload.physicalStateVector;
    elseif isstruct(statePayload) && isfield(statePayload, 'stateVector')
        stateVector = statePayload.stateVector;
    else
        error('WP5:UnsupportedStatePayload', ...
            'CSS residuals require numeric vectors or structs with a numeric physicalStateVector or stateVector field.');
    end

    if ~isnumeric(stateVector) || ~isvector(stateVector)
        error('WP5:UnsupportedStatePayload', ...
            'Resolved CSS state payload must be a numeric vector.');
    end

    stateVector = stateVector(:);

    if ~isempty(opts.Params)
        params = opts.Params;
        if ~isstruct(params) || ~isfield(params, 'nColSt')
            error('WP5:InvalidParams', ...
                'Params supplied for state extraction must include nColSt.');
        end
        validateattributes(params.nColSt, {'numeric'}, ...
            {'scalar', 'integer', 'positive'}, mfilename, 'params.nColSt');

        if numel(stateVector) == params.nColSt
            return;
        end

        if isfield(params, 'nColStT') && numel(stateVector) == params.nColStT
            stateVector = stateVector(1:params.nColSt);
            return;
        end

        if isfield(params, 'nColStT')
            error('WP5:StateLengthMismatch', ...
                'State vector has %d entries; expected nColSt = %d or nColStT = %d.', ...
                numel(stateVector), params.nColSt, params.nColStT);
        else
            error('WP5:StateLengthMismatch', ...
                'State vector has %d entries; expected nColSt = %d.', ...
                numel(stateVector), params.nColSt);
        end
    end
end
