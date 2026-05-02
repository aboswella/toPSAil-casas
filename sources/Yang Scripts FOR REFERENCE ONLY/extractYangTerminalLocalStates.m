function [terminalLocalStates, counterTailReport] = extractYangTerminalLocalStates(params, stStates, tempCase)
%EXTRACTYANGTERMINALLOCALSTATES Return terminal adsorber states in local order.

    result = validateYangTemporaryCase(tempCase);
    if ~result.pass
        error('WP4:InvalidTemporaryCase', ...
            'Cannot extract terminal states from an invalid temporary case.');
    end

    if nargin < 1 || ~isstruct(params) || ...
            ~isfield(params, 'nColSt') || ~isfield(params, 'nColStT')
        error('WP4:InvalidTemplateParams', ...
            'Params must include nColSt and nColStT for terminal state extraction.');
    end

    if nargin < 2 || ~isnumeric(stStates) || isempty(stStates)
        error('WP4:InvalidStateHistory', ...
            'stStates must be a nonempty numeric state-history matrix.');
    end

    termStates = convert2TermStates(params, stStates);
    terminalLocalStates = cell(tempCase.nLocalBeds, 1);
    counterTailRows = cell(tempCase.nLocalBeds, 1);
    for i = 1:tempCase.nLocalBeds
        localStateVector = convert2ColStates(params, termStates, i);
        metadata = makeMetadataFromTempCase(tempCase, i);
        terminalLocalStates{i} = extractYangPhysicalBedState(params, localStateVector, ...
            'Metadata', metadata);
        counterTailRows{i} = extractYangCounterTailDeltas(params, localStateVector, ...
            'Metadata', metadata);
    end

    counterTailReport = struct();
    counterTailReport.version = "FI3-Yang2009-counter-tail-report-v1";
    counterTailReport.payloadType = "yang_counter_tail_report_collection_v1";
    counterTailReport.persistAsBedState = false;
    counterTailReport.counterTailPolicy = "accounting_only_not_persistent_bed_state";
    counterTailReport.localMap = tempCase.localMap;
    counterTailReport.reports = counterTailRows;
end

function metadata = makeMetadataFromTempCase(tempCase, localIndex)
    metadata = struct();
    metadata.source = "WP4 temporary case";
    metadata.globalBed = string(tempCase.localMap.global_bed(localIndex));
    metadata.localIndex = tempCase.localMap.local_index(localIndex);
    metadata.yangLabel = string(tempCase.localMap.yang_label(localIndex));
    metadata.recordId = string(tempCase.localMap.record_id(localIndex));
    metadata.sourceCol = tempCase.localMap.source_col(localIndex);
    metadata.pairId = string(tempCase.pairId);
    metadata.directTransferFamily = string(tempCase.directTransferFamily);
    if ismember("local_role", string(tempCase.localMap.Properties.VariableNames))
        metadata.localRole = string(tempCase.localMap.local_role(localIndex));
    end
end
