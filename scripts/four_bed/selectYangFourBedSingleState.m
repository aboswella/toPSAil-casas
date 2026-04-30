function selection = selectYangFourBedSingleState(container, bedStepRow)
%SELECTYANGFOURBEDSINGLESTATE Select one named bed state for a single call.
%
% WP3 records the local/global identity contract only. Operation
% compatibility and temporary case construction belong to WP4.

    result = validateYangFourBedStateContainer(container);
    if ~result.pass
        error('WP3:InvalidStateContainer', ...
            'State container failed WP3 validation before single-state selection.');
    end

    if nargin < 2 || ~istable(bedStepRow) || height(bedStepRow) ~= 1
        error('WP3:InvalidBedStepRow', ...
            'bedStepRow must be a one-row table from manifest.bedSteps.');
    end

    requiredVars = [
        "bed"
        "record_id"
        "source_col"
        "yang_label"
        "role_class"
        "direct_transfer_family"
        "p_start_class"
        "p_end_class"
    ];
    rowVars = string(bedStepRow.Properties.VariableNames);
    missingVars = setdiff(requiredVars, rowVars);
    if ~isempty(missingVars)
        error('WP3:InvalidBedStepRow', ...
            'bedStepRow is missing required columns: %s.', char(strjoin(missingVars, ", ")));
    end

    bedLabel = string(bedStepRow.bed(1));
    assertKnownBedLabel(bedLabel, container.bedLabels);

    stateField = getStateFieldName(bedLabel);
    assertStateFieldExists(container, stateField);

    if ismember("internal_transfer_category", rowVars)
        transferAccountingCategory = string(bedStepRow.internal_transfer_category(1));
    else
        transferAccountingCategory = "none";
    end

    localMap = table( ...
        1, ...
        string(bedStepRow.role_class(1)), ...
        bedLabel, ...
        stateField, ...
        string(bedStepRow.yang_label(1)), ...
        string(bedStepRow.record_id(1)), ...
        bedStepRow.source_col(1), ...
        string(bedStepRow.p_start_class(1)), ...
        string(bedStepRow.p_end_class(1)), ...
        "none", ...
        "none", ...
        "none", ...
        transferAccountingCategory, ...
        'VariableNames', [
            "local_index"
            "local_role"
            "global_bed"
            "state_field"
            "yang_label"
            "record_id"
            "source_col"
            "p_start_class"
            "p_end_class"
            "inlet_endpoint"
            "outlet_endpoint"
            "waste_endpoint"
            "transfer_accounting_category"
        ]);

    selection = struct();
    selection.version = "WP3-Yang2009-state-selection-v1";
    selection.selectionType = "single_bed_operation";
    selection.pairId = "none";
    selection.directTransferFamily = string(bedStepRow.direct_transfer_family(1));
    selection.localStates = {container.(char(stateField))};
    selection.localMap = localMap;
end

function fieldName = getStateFieldName(bedLabel)
    fieldName = "state_" + string(bedLabel);
end

function assertKnownBedLabel(bedLabel, bedLabels)
    if ~ismember(string(bedLabel), string(bedLabels))
        error('WP3:UnknownBedLabel', ...
            'Unknown Yang bed label %s.', char(string(bedLabel)));
    end
end

function assertStateFieldExists(container, fieldName)
    if ~isfield(container, char(fieldName))
        error('WP3:MissingStateField', ...
            'State container is missing field %s.', char(fieldName));
    end
end
