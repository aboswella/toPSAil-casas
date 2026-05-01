function counterReport = extractYangCounterTailDeltas(params, initialOrTerminalPayload, terminalPayload, varargin)
%EXTRACTYANGCOUNTERTAILDELTAS Report native boundary-flow counter tails.
%
% Counter tails are accounting data for later ledgers. They are never a
% persistent Yang bed state.

    if nargin < 3
        terminalPayload = initialOrTerminalPayload;
        initialPayload = [];
        extraArgs = varargin;
    elseif isNameValueToken(terminalPayload)
        initialPayload = [];
        extraArgs = [{terminalPayload}, varargin];
        terminalPayload = initialOrTerminalPayload;
    else
        initialPayload = initialOrTerminalPayload;
        extraArgs = varargin;
    end

    parser = inputParser;
    addParameter(parser, 'Metadata', struct());
    parse(parser, extraArgs{:});
    opts = parser.Results;

    validateParams(params);
    terminalVector = resolvePayloadVector(terminalPayload);
    [terminalTail, terminalMode] = getCounterTail(params, terminalVector);

    if isempty(initialPayload)
        initialTail = [];
        counterTailDelta = [];
        deltaMode = "terminal_tail_only_not_delta";
    else
        initialVector = resolvePayloadVector(initialPayload);
        [initialTail, initialMode] = getCounterTail(params, initialVector); %#ok<ASGLU>
        if numel(initialTail) ~= numel(terminalTail)
            error('FI3:CounterTailLengthMismatch', ...
                'Initial and terminal counter tails must have the same length.');
        end
        counterTailDelta = terminalTail - initialTail;
        deltaMode = "terminal_minus_initial";
    end

    metadata = opts.Metadata;
    metadata.counterTailPolicy = "accounting_only_not_persistent_bed_state";
    metadata.physicalStateLength = params.nColSt;
    metadata.nativeStateLength = params.nColStT;
    metadata.terminalTailExtractionMode = terminalMode;

    counterReport = struct();
    counterReport.payloadType = "yang_counter_tail_report_v1";
    counterReport.persistAsBedState = false;
    counterReport.counterTailMode = deltaMode;
    counterReport.counterTail = terminalTail;
    counterReport.terminalCounterTail = terminalTail;
    counterReport.initialCounterTail = initialTail;
    counterReport.counterTailDelta = counterTailDelta;
    counterReport.metadata = metadata;
end

function tf = isNameValueToken(value)
    tf = ischar(value) || (isstring(value) && isscalar(value));
end

function validateParams(params)
    if nargin < 1 || ~isstruct(params) || ...
            ~isfield(params, 'nColSt') || ~isfield(params, 'nColStT')
        error('FI3:InvalidParams', ...
            'Params must include nColSt and nColStT for counter-tail extraction.');
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

function stateVector = resolvePayloadVector(payload)
    if isnumeric(payload)
        stateVector = payload;
    elseif isstruct(payload)
        if isfield(payload, 'stateVector')
            stateVector = payload.stateVector;
        elseif isfield(payload, 'physicalStateVector')
            stateVector = payload.physicalStateVector;
        else
            error('FI3:UnsupportedStatePayload', ...
                'State payload structs must contain stateVector or physicalStateVector.');
        end
    else
        error('FI3:UnsupportedStatePayload', ...
            'State payload must be a numeric vector or a struct containing a vector.');
    end

    if ~isnumeric(stateVector) || ~isvector(stateVector)
        error('FI3:UnsupportedStatePayload', ...
            'Resolved state payload must be a numeric vector.');
    end

    stateVector = stateVector(:);
end

function [counterTail, mode] = getCounterTail(params, stateVector)
    nState = numel(stateVector);
    if nState == params.nColStT
        counterTail = stateVector(params.nColSt+1:params.nColStT);
        mode = "native_tail_extracted";
    elseif nState == params.nColSt
        counterTail = zeros(0, 1);
        mode = "physical_state_only_no_counter_tail_available";
    else
        error('FI3:StateLengthMismatch', ...
            'State vector has %d entries; expected nColSt = %d or nColStT = %d.', ...
            nState, params.nColSt, params.nColStT);
    end
end
