function stateVector = extractYangStateVector(statePayload)
%EXTRACTYANGSTATEVECTOR Resolve a WP5 CSS payload to a numeric vector.

    if isnumeric(statePayload)
        stateVector = statePayload;
    elseif isstruct(statePayload) && isfield(statePayload, 'stateVector')
        stateVector = statePayload.stateVector;
    else
        error('WP5:UnsupportedStatePayload', ...
            'CSS residuals require numeric vectors or structs with a numeric stateVector field.');
    end

    if ~isnumeric(stateVector) || ~isvector(stateVector)
        error('WP5:UnsupportedStatePayload', ...
            'Resolved CSS state payload must be a numeric vector.');
    end

    stateVector = stateVector(:);
end
