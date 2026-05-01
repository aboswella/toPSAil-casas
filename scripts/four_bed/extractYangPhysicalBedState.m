function physicalPayload = extractYangPhysicalBedState(params, localStatePayload, varargin)
%EXTRACTYANGPHYSICALBEDSTATE Return only the physical adsorber state.
%
% Native toPSAil column states may include trailing cumulative boundary-flow
% counters. Persistent Yang bed states store only indices 1:params.nColSt.

    parser = inputParser;
    addParameter(parser, 'Metadata', struct());
    parse(parser, varargin{:});
    opts = parser.Results;

    validateParams(params);
    [sourceVector, sourcePayloadType, sourceMetadata] = resolvePayloadVector(localStatePayload);
    sourceVector = sourceVector(:);

    nSource = numel(sourceVector);
    if nSource == params.nColSt
        physicalVector = sourceVector;
        extractionPolicy = "already_physical_length";
    elseif nSource == params.nColStT
        physicalVector = sourceVector(1:params.nColSt);
        extractionPolicy = "sliced_1_to_nColSt_from_native_local_state";
    else
        error('FI3:StateLengthMismatch', ...
            'State vector has %d entries; expected nColSt = %d or nColStT = %d.', ...
            nSource, params.nColSt, params.nColStT);
    end

    metadata = mergeMetadata(sourceMetadata, opts.Metadata);
    metadata.sourcePayloadType = sourcePayloadType;
    metadata.sourceStateLength = nSource;
    metadata.physicalStateLength = params.nColSt;
    metadata.nativeStateLength = params.nColStT;
    metadata.extractionPolicy = extractionPolicy;
    metadata.counterTailPolicy = "excluded_from_persistent_bed_state";

    physicalPayload = struct();
    physicalPayload.payloadType = "yang_physical_adsorber_state_v1";
    physicalPayload.stateVector = physicalVector;
    physicalPayload.physicalStateVector = physicalVector;
    physicalPayload.metadata = metadata;
end

function metadata = mergeMetadata(sourceMetadata, requestMetadata)
    metadata = sourceMetadata;
    if isstruct(requestMetadata)
        names = fieldnames(requestMetadata);
        for i = 1:numel(names)
            metadata.(names{i}) = requestMetadata.(names{i});
        end
    else
        metadata.requestMetadata = requestMetadata;
    end
end

function validateParams(params)
    if nargin < 1 || ~isstruct(params) || ...
            ~isfield(params, 'nColSt') || ~isfield(params, 'nColStT')
        error('FI3:InvalidParams', ...
            'Params must include nColSt and nColStT for physical state extraction.');
    end

    validateattributes(params.nColSt, {'numeric'}, ...
        {'scalar', 'integer', 'positive'}, mfilename, 'params.nColSt');
    validateattributes(params.nColStT, {'numeric'}, ...
        {'scalar', 'integer', 'positive'}, mfilename, 'params.nColStT');

    if params.nColStT < params.nColSt
        error('FI3:InvalidParams', ...
            'params.nColStT must be greater than or equal to params.nColSt.');
    end
end

function [stateVector, payloadType, metadata] = resolvePayloadVector(payload)
    payloadType = "numeric_vector";
    metadata = struct();

    if isnumeric(payload)
        stateVector = payload;
        return;
    end

    if isstruct(payload)
        if isfield(payload, 'payloadType')
            payloadType = string(payload.payloadType);
        else
            payloadType = "struct_payload";
        end
        if isfield(payload, 'metadata') && isstruct(payload.metadata)
            metadata = payload.metadata;
        end
        if isfield(payload, 'physicalStateVector')
            stateVector = payload.physicalStateVector;
        elseif isfield(payload, 'stateVector')
            stateVector = payload.stateVector;
        else
            error('FI3:UnsupportedStatePayload', ...
                'State payload structs must contain physicalStateVector or stateVector.');
        end
    else
        error('FI3:UnsupportedStatePayload', ...
            'State payload must be a numeric vector or a struct containing a vector.');
    end

    if ~isnumeric(stateVector) || ~isvector(stateVector)
        error('FI3:UnsupportedStatePayload', ...
            'Resolved state payload must be a numeric vector.');
    end
end
