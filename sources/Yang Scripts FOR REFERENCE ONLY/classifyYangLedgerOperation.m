function spec = classifyYangLedgerOperation(tempCase)
%CLASSIFYYANGLEDGEROPERATION Return expected WP5 stream categories.
%
% This helper classifies categories only. Quantities still have to come from
% caller-supplied packets, spy packets, or a tested native extractor.

    if nargin < 1 || ~isstruct(tempCase) || ~isfield(tempCase, 'caseType')
        error('WP5:InvalidTemporaryCase', ...
            'Expected a WP4 temporary case struct.');
    end

    result = validateYangTemporaryCase(tempCase);
    if ~result.pass
        error('WP5:InvalidTemporaryCase', ...
            'Temporary case failed WP4 validation before ledger classification: %s', ...
            char(strjoin(result.failures, " | ")));
    end

    stageLabel = "not_applicable";
    if isfield(tempCase, 'native') && isfield(tempCase.native, 'stageLabel')
        stageLabel = string(tempCase.native.stageLabel);
    end

    spec = struct();
    spec.version = "WP5-Yang2009-ledger-operation-classification-v1";
    spec.classificationStatus = "classified";
    spec.caseType = string(tempCase.caseType);
    spec.stage_label = stageLabel;
    spec.direct_transfer_family = string(tempCase.directTransferFamily);
    spec.expected_stream_scopes = strings(0, 1);
    spec.external_stream_scopes = strings(0, 1);
    spec.internal_stream_scopes = strings(0, 1);
    spec.requires_caller_quantities = true;
    spec.notes = strings(0, 1);

    if string(tempCase.caseType) == "paired_direct_transfer"
        classifyPaired();
    elseif string(tempCase.caseType) == "single_bed_operation"
        classifySingle();
    else
        error('WP5:UnsupportedTemporaryCaseType', ...
            'Unsupported temporary case type %s.', char(string(tempCase.caseType)));
    end

    function classifyPaired()
        family = string(tempCase.directTransferFamily);
        switch family
            case "EQI"
                spec.stage_label = "EQI";
                spec.expected_stream_scopes = ["internal_transfer"];
                spec.internal_stream_scopes = ["internal_transfer"];
                spec.notes = "EQI direct equalization is internal transfer only.";

            case "EQII"
                spec.stage_label = "EQII";
                spec.expected_stream_scopes = ["internal_transfer"];
                spec.internal_stream_scopes = ["internal_transfer"];
                spec.notes = "EQII direct equalization is internal transfer only and remains distinct from EQI.";

            case "PP_PU"
                spec.stage_label = "PP_PU";
                spec.expected_stream_scopes = ["internal_transfer"; "external_waste"];
                spec.external_stream_scopes = ["external_waste"];
                spec.internal_stream_scopes = ["internal_transfer"];
                spec.notes = "PP->PU internal transfer is separated from receiver external purge waste.";

            case "ADPP_BF"
                spec.stage_label = "ADPP_BF";
                spec.expected_stream_scopes = ["external_feed"; "external_product"; "internal_transfer"];
                spec.external_stream_scopes = ["external_feed"; "external_product"];
                spec.internal_stream_scopes = ["internal_transfer"];
                spec.notes = "AD&PP external product is separated from BF internal backfill.";

            otherwise
                spec.classificationStatus = "unsupported_direct_transfer_family";
                spec.notes = "No WP5 ledger classification exists for direct-transfer family " + family + ".";
        end
    end

    function classifySingle()
        yangLabel = string(tempCase.localMap.yang_label(1));
        switch yangLabel
            case "AD"
                spec.stage_label = "AD";
                spec.direct_transfer_family = "none";
                spec.expected_stream_scopes = ["external_feed"; "external_product"];
                spec.external_stream_scopes = ["external_feed"; "external_product"];
                spec.notes = "AD single-bed operation has external feed and external product.";

            case "BD"
                spec.stage_label = "BD";
                spec.direct_transfer_family = "none";
                spec.expected_stream_scopes = ["external_waste"];
                spec.external_stream_scopes = ["external_waste"];
                spec.notes = "BD single-bed operation has external waste.";

            otherwise
                spec.classificationStatus = "paired_selection_required";
                spec.expected_stream_scopes = strings(0, 1);
                spec.external_stream_scopes = strings(0, 1);
                spec.internal_stream_scopes = strings(0, 1);
                spec.notes = "Yang label " + yangLabel + " requires explicit paired selection before WP5 ledgering.";
        end
    end
end
