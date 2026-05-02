function selection = selectYangFourBedPairStates(container, pairRow)
%SELECTYANGFOURBEDPAIRSTATES Select donor/receiver states for a pair call.
%
% Local index 1 is always the WP2 donor bed and local index 2 is always the
% WP2 receiver bed. Pair identity comes from pairRow, never from adjacency.

    result = validateYangFourBedStateContainer(container);
    if ~result.pass
        error('WP3:InvalidStateContainer', ...
            'State container failed WP3 validation before pair-state selection.');
    end

    if nargin < 2 || ~istable(pairRow) || height(pairRow) ~= 1
        error('WP3:InvalidPairRow', ...
            'pairRow must be a one-row table from pairMap.transferPairs.');
    end

    requiredVars = [
        "pair_id"
        "direct_transfer_family"
        "donor_bed"
        "receiver_bed"
        "donor_record_id"
        "receiver_record_id"
        "donor_source_col"
        "receiver_source_col"
        "donor_yang_label"
        "receiver_yang_label"
        "donor_p_start_class"
        "donor_p_end_class"
        "receiver_p_start_class"
        "receiver_p_end_class"
        "donor_outlet_endpoint"
        "receiver_inlet_endpoint"
        "receiver_waste_endpoint"
        "transfer_accounting_category"
    ];
    pairVars = string(pairRow.Properties.VariableNames);
    missingVars = setdiff(requiredVars, pairVars);
    if ~isempty(missingVars)
        error('WP3:InvalidPairRow', ...
            'pairRow is missing required columns: %s.', char(strjoin(missingVars, ", ")));
    end

    donorBed = string(pairRow.donor_bed(1));
    receiverBed = string(pairRow.receiver_bed(1));
    if donorBed == receiverBed
        error('WP3:DuplicatePairBed', ...
            'A direct-transfer pair cannot select the same bed twice: %s.', char(donorBed));
    end

    assertKnownBedLabel(donorBed, container.bedLabels);
    assertKnownBedLabel(receiverBed, container.bedLabels);

    donorField = getStateFieldName(donorBed);
    receiverField = getStateFieldName(receiverBed);
    assertStateFieldExists(container, donorField);
    assertStateFieldExists(container, receiverField);

    localIndex = [1; 2];
    localRole = ["donor"; "receiver"];
    globalBed = [donorBed; receiverBed];
    stateField = [donorField; receiverField];
    yangLabel = [string(pairRow.donor_yang_label(1)); string(pairRow.receiver_yang_label(1))];
    recordId = [string(pairRow.donor_record_id(1)); string(pairRow.receiver_record_id(1))];
    sourceCol = [pairRow.donor_source_col(1); pairRow.receiver_source_col(1)];
    pStartClass = [string(pairRow.donor_p_start_class(1)); string(pairRow.receiver_p_start_class(1))];
    pEndClass = [string(pairRow.donor_p_end_class(1)); string(pairRow.receiver_p_end_class(1))];
    inletEndpoint = ["none"; string(pairRow.receiver_inlet_endpoint(1))];
    outletEndpoint = [string(pairRow.donor_outlet_endpoint(1)); "none"];
    wasteEndpoint = ["none"; string(pairRow.receiver_waste_endpoint(1))];
    transferAccountingCategory = [
        string(pairRow.transfer_accounting_category(1))
        string(pairRow.transfer_accounting_category(1))
    ];

    localMap = table( ...
        localIndex, ...
        localRole, ...
        globalBed, ...
        stateField, ...
        yangLabel, ...
        recordId, ...
        sourceCol, ...
        pStartClass, ...
        pEndClass, ...
        inletEndpoint, ...
        outletEndpoint, ...
        wasteEndpoint, ...
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
    selection.selectionType = "paired_direct_transfer";
    selection.pairId = string(pairRow.pair_id(1));
    selection.directTransferFamily = string(pairRow.direct_transfer_family(1));
    selection.localStates = {
        container.(char(donorField))
        container.(char(receiverField))
    };
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
