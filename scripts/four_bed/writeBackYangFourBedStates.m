function [updatedContainer, report] = writeBackYangFourBedStates(container, selection, terminalLocalStates, varargin)
%WRITEBACKYANGFOURBEDSTATES Replace selected persistent bed states.
%
% Only state fields named in selection.localMap are replaced. Non-
% participating state_A/state_B/state_C/state_D payloads are left unchanged.

    parser = inputParser;
    addParameter(parser, 'UpdateNote', "not_supplied");
    addParameter(parser, 'Params', []);
    parse(parser, varargin{:});
    opts = parser.Results;

    result = validateYangFourBedStateContainer(container);
    if ~result.pass
        error('WP3:InvalidStateContainer', ...
            'State container failed WP3 validation before writeback.');
    end

    validateSelection(selection);

    if ~iscell(terminalLocalStates)
        error('WP3:InvalidTerminalStates', ...
            'terminalLocalStates must be a cell array in selection.localMap order.');
    end

    terminalLocalStates = terminalLocalStates(:);
    localMap = selection.localMap;
    nLocal = height(localMap);
    if numel(terminalLocalStates) ~= nLocal
        error('WP3:TerminalStateCountMismatch', ...
            'Expected %d terminal local states but received %d.', ...
            nLocal, numel(terminalLocalStates));
    end

    targetFields = string(localMap.state_field);
    if numel(unique(targetFields)) ~= numel(targetFields)
        error('WP3:DuplicateWritebackTarget', ...
            'Selection contains duplicate writeback targets.');
    end

    for i = 1:numel(targetFields)
        if ~isfield(container, char(targetFields(i)))
            error('WP3:MissingWritebackTarget', ...
                'Container is missing writeback target %s.', char(targetFields(i)));
        end
    end

    updatedContainer = container;
    counterTailStripped = false(nLocal, 1);
    persistentPayloads = cell(nLocal, 1);
    for i = 1:nLocal
        fieldName = targetFields(i);
        [persistentPayloads{i}, counterTailStripped(i)] = normalizePersistentPayload( ...
            terminalLocalStates{i}, opts.Params);
        updatedContainer.(char(fieldName)) = persistentPayloads{i};
    end

    nextWritebackIndex = getNextWritebackIndex(updatedContainer.writebackLog);
    updatedContainer.stateMetadata = updateStateMetadata( ...
        updatedContainer.stateMetadata, localMap, selection);
    updatedContainer.writebackLog = appendWritebackLog( ...
        updatedContainer.writebackLog, localMap, selection, nextWritebackIndex, string(opts.UpdateNote));

    report = struct();
    report.updatedStateFields = targetFields;
    report.updatedBedLabels = string(localMap.global_bed);
    report.unchangedStateFields = setdiff(string(container.stateFields(:)), targetFields, 'stable');
    report.persistedPayloads = persistentPayloads;
    report.counterTailStripped = counterTailStripped;
    report.persistencePolicy = "physical_adsorber_state_only_no_boundary_counter_tails";
    report.writebackIndex = nextWritebackIndex;
    report.selectionType = string(selection.selectionType);
    report.pairId = string(selection.pairId);
    report.directTransferFamily = string(selection.directTransferFamily);
end

function [persistentPayload, counterTailStripped] = normalizePersistentPayload(payload, params)
    counterTailStripped = false;
    if isempty(params)
        [persistentPayload, counterTailStripped] = normalizeWithoutParams(payload);
    else
        validateParams(params);
        [persistentPayload, counterTailStripped] = normalizeWithParams(payload, params);
    end
end

function [persistentPayload, counterTailStripped] = normalizeWithoutParams(payload)
    counterTailStripped = false;
    persistentPayload = payload;

    if isnumeric(payload)
        error('WP3:MissingParamsForStateVector', ...
            'Numeric terminal states require Params so writeback can verify physical length.');
    end

    if ~isstruct(payload)
        return;
    end

    if isfield(payload, 'physicalStateVector')
        physicalVector = validateVector(payload.physicalStateVector);
        persistentPayload.stateVector = physicalVector;
        persistentPayload.physicalStateVector = physicalVector;
        return;
    end

    if isfield(payload, 'stateVector')
        payloadType = "";
        if isfield(payload, 'payloadType')
            payloadType = string(payload.payloadType);
        end
        if payloadType == "yang_physical_adsorber_state_v1"
            persistentPayload.stateVector = validateVector(payload.stateVector);
            persistentPayload.physicalStateVector = persistentPayload.stateVector;
        else
            error('WP3:MissingParamsForStateVector', ...
                'Terminal payloads with stateVector require physicalStateVector, a physical payloadType, or Params.');
        end
    end
end

function [persistentPayload, counterTailStripped] = normalizeWithParams(payload, params)
    counterTailStripped = false;

    if isnumeric(payload)
        counterTailStripped = numel(payload) == params.nColStT && params.nColStT > params.nColSt;
        persistentPayload = extractYangPhysicalBedState(params, payload);
        return;
    end

    if ~isstruct(payload)
        persistentPayload = payload;
        return;
    end

    if isfield(payload, 'physicalStateVector')
        physicalVector = validateVector(payload.physicalStateVector);
        if numel(physicalVector) ~= params.nColSt
            error('WP3:PhysicalStateLengthMismatch', ...
                'physicalStateVector has %d entries; expected nColSt = %d.', ...
                numel(physicalVector), params.nColSt);
        end
        persistentPayload = payload;
        persistentPayload.stateVector = physicalVector;
        persistentPayload.physicalStateVector = physicalVector;
        return;
    end

    if isfield(payload, 'stateVector')
        stateVector = validateVector(payload.stateVector);
        counterTailStripped = numel(stateVector) == params.nColStT && params.nColStT > params.nColSt;
        persistentPayload = extractYangPhysicalBedState(params, payload);
    else
        persistentPayload = payload;
    end
end

function validateParams(params)
    if ~isstruct(params) || ~isfield(params, 'nColSt') || ~isfield(params, 'nColStT')
        error('WP3:InvalidParams', ...
            'Params must include nColSt and nColStT for physical writeback validation.');
    end

    validateattributes(params.nColSt, {'numeric'}, ...
        {'scalar', 'integer', 'positive'}, mfilename, 'params.nColSt');
    validateattributes(params.nColStT, {'numeric'}, ...
        {'scalar', 'integer', 'positive'}, mfilename, 'params.nColStT');
    if params.nColStT < params.nColSt
        error('WP3:InvalidParams', ...
            'params.nColStT must be greater than or equal to params.nColSt.');
    end
end

function stateVector = validateVector(stateVector)
    if ~isnumeric(stateVector) || ~isvector(stateVector)
        error('WP3:UnsupportedStatePayload', ...
            'State payload vectors must be numeric vectors.');
    end
    stateVector = stateVector(:);
end

function validateSelection(selection)
    requiredFields = [
        "version"
        "selectionType"
        "pairId"
        "directTransferFamily"
        "localStates"
        "localMap"
    ];
    if ~isstruct(selection)
        error('WP3:InvalidSelection', ...
            'Selection must be a struct returned by a WP3 selector.');
    end

    selectionFields = string(fieldnames(selection));
    missingFields = setdiff(requiredFields, selectionFields);
    if ~isempty(missingFields)
        error('WP3:InvalidSelection', ...
            'Selection is missing required fields: %s.', char(strjoin(missingFields, ", ")));
    end

    if ~istable(selection.localMap) || height(selection.localMap) < 1
        error('WP3:InvalidSelection', ...
            'selection.localMap must be a nonempty table.');
    end

    requiredMapVars = [
        "local_index"
        "local_role"
        "global_bed"
        "state_field"
        "yang_label"
        "record_id"
        "source_col"
    ];
    mapVars = string(selection.localMap.Properties.VariableNames);
    missingMapVars = setdiff(requiredMapVars, mapVars);
    if ~isempty(missingMapVars)
        error('WP3:InvalidSelection', ...
            'selection.localMap is missing required columns: %s.', char(strjoin(missingMapVars, ", ")));
    end
end

function nextWritebackIndex = getNextWritebackIndex(writebackLog)
    if height(writebackLog) == 0
        nextWritebackIndex = 1;
    else
        nextWritebackIndex = max(writebackLog.writeback_index) + 1;
    end
end

function metadata = updateStateMetadata(metadata, localMap, selection)
    for i = 1:height(localMap)
        fieldName = string(localMap.state_field(i));
        metadataRow = metadata.state_field == fieldName;
        if ~any(metadataRow)
            error('WP3:MissingWritebackTarget', ...
                'stateMetadata has no row for writeback target %s.', char(fieldName));
        end

        metadata.last_update_role(metadataRow) = string(localMap.local_role(i));
        metadata.last_update_pair_id(metadataRow) = string(selection.pairId);
        metadata.last_update_operation(metadataRow) = string(localMap.yang_label(i));
        metadata.last_update_source_col(metadataRow) = localMap.source_col(i);
        metadata.writeback_count(metadataRow) = metadata.writeback_count(metadataRow) + 1;
    end
end

function writebackLog = appendWritebackLog(writebackLog, localMap, selection, writebackIndex, updateNote)
    nRows = height(localMap);
    writebackIndexCol = repmat(writebackIndex, nRows, 1);
    selectionType = repmat(string(selection.selectionType), nRows, 1);
    pairId = repmat(string(selection.pairId), nRows, 1);
    directTransferFamily = repmat(string(selection.directTransferFamily), nRows, 1);
    localIndex = localMap.local_index;
    localRole = string(localMap.local_role);
    globalBed = string(localMap.global_bed);
    stateField = string(localMap.state_field);
    yangLabel = string(localMap.yang_label);
    recordId = string(localMap.record_id);
    sourceCol = localMap.source_col;
    updateNoteCol = repmat(updateNote, nRows, 1);

    newRows = table( ...
        writebackIndexCol, ...
        selectionType, ...
        pairId, ...
        directTransferFamily, ...
        localIndex, ...
        localRole, ...
        globalBed, ...
        stateField, ...
        yangLabel, ...
        recordId, ...
        sourceCol, ...
        updateNoteCol, ...
        'VariableNames', [
            "writeback_index"
            "selection_type"
            "pair_id"
            "direct_transfer_family"
            "local_index"
            "local_role"
            "global_bed"
            "state_field"
            "yang_label"
            "record_id"
            "source_col"
            "update_note"
        ]);

    writebackLog = [writebackLog; newRows];
end
