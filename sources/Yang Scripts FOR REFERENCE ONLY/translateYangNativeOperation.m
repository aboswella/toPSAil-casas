function translation = translateYangNativeOperation(selection, varargin)
%TRANSLATEYANGNATIVEOPERATION Translate Yang labels to WP4 native specs.
%
% The translation is wrapper metadata. It never uses Yang source labels as
% native toPSAil step names unless an explicit native grammar mapping exists.

    parser = inputParser;
    addParameter(parser, 'OperationPolicy', "fixed_duration_direct_coupling");
    addParameter(parser, 'ExternalProductSink', "RAF");
    addParameter(parser, 'ExternalWasteSink', "ATM");
    addParameter(parser, 'AllowDiagnosticOnly', false);
    parse(parser, varargin{:});
    opts = parser.Results;

    validateSelection(selection);

    selectionType = string(selection.selectionType);
    localMap = selection.localMap;
    nLocal = height(localMap);
    directTransferFamily = string(selection.directTransferFamily);

    nativeStepNames = repmat("not_applicable", nLocal, 1);
    nativeRunnable = false;
    nativeRunnableScope = "not_runnable_yet";
    wrapperOperation = "unsupported";
    stageLabel = "not_applicable";
    unsupportedReason = "";
    warnings = strings(0, 1);
    numAdsEqPrEnd = zeros(nLocal, 1);
    numAdsEqFeEnd = zeros(nLocal, 1);

    endpointPolicy = makeEndpointPolicy(localMap, opts);
    pressureClassPolicy = makePressureClassPolicy(localMap);
    accountingPolicy = makeAccountingPolicy(localMap);

    if selectionType == "paired_direct_transfer"
        if nLocal ~= 2
            error('WP4:InvalidPairedSelection', ...
                'Paired direct-transfer selections must contain exactly two local beds.');
        end

        switch directTransferFamily
            case "EQI"
                nativeRunnable = true;
                nativeRunnableScope = "core_step";
                nativeStepNames = ["EQ-XXX-APR"; "EQ-XXX-APR"];
                wrapperOperation = "product_end_equalization_direct_transfer";
                stageLabel = "EQI";
                numAdsEqPrEnd = [2; 1];

            case "EQII"
                nativeRunnable = true;
                nativeRunnableScope = "core_step";
                nativeStepNames = ["EQ-XXX-APR"; "EQ-XXX-APR"];
                wrapperOperation = "product_end_equalization_direct_transfer";
                stageLabel = "EQII";
                numAdsEqPrEnd = [2; 1];

            case "PP_PU"
                nativeRunnable = false;
                nativeRunnableScope = "wrapper_adapter_required";
                wrapperOperation = "product_end_provide_purge_direct_transfer";
                stageLabel = "PP_PU";
                unsupportedReason = ...
                    "Native core grammar lacks this exact direct-transfer endpoint/waste combination without a custom wrapper adapter.";
                warnings(end+1, 1) = ...
                    "PP->PU is specified as endpoint metadata only; no fake native equalization step is emitted.";

            case "ADPP_BF"
                nativeRunnable = false;
                nativeRunnableScope = "wrapper_adapter_required";
                wrapperOperation = "compound_adsorption_product_backfill_direct_transfer";
                stageLabel = "ADPP_BF";
                endpointPolicy.externalProductSeparated = true;
                unsupportedReason = ...
                    "Native core grammar lacks the AD&PP external-product and BF internal-backfill split without a custom wrapper adapter.";
                warnings(end+1, 1) = ...
                    "AD&PP->BF remains wrapper-only so external product and internal backfill are not collapsed.";

            otherwise
                unsupportedReason = "Unknown paired direct-transfer family: " + directTransferFamily + ".";
        end

    elseif selectionType == "single_bed_operation"
        if nLocal ~= 1
            error('WP4:InvalidSingleSelection', ...
                'Single-bed selections must contain exactly one local bed.');
        end

        yangLabel = string(localMap.yang_label(1));
        switch yangLabel
            case "AD"
                nativeRunnable = true;
                nativeRunnableScope = "core_step";
                nativeStepNames = "HP-FEE-RAF";
                wrapperOperation = "external_adsorption_single_bed";
                stageLabel = "AD";
                endpointPolicy.externalFeed = true;
                endpointPolicy.externalProduct = true;
                endpointPolicy.externalProductSink = string(opts.ExternalProductSink);

            case "BD"
                nativeRunnable = true;
                nativeRunnableScope = "core_step";
                nativeStepNames = "DP-ATM-XXX";
                wrapperOperation = "external_blowdown_single_bed";
                stageLabel = "BD";
                endpointPolicy.externalWaste = true;
                endpointPolicy.externalWasteSink = string(opts.ExternalWasteSink);

            case "AD&PP"
                nativeRunnable = false;
                nativeRunnableScope = "paired_selection_required";
                wrapperOperation = "compound_donor_requires_ADPP_BF_pair";
                stageLabel = "ADPP_BF";
                endpointPolicy.externalProductSeparated = true;
                unsupportedReason = ...
                    "AD&PP is compound and must be represented through the ADPP_BF paired direct-transfer selection.";

            case {"EQI-BD", "EQI-PR"}
                nativeRunnable = false;
                nativeRunnableScope = "paired_selection_required";
                wrapperOperation = "equalization_role_requires_EQI_pair";
                stageLabel = "EQI";
                unsupportedReason = ...
                    "EQI roles require an explicit WP2 donor/receiver pair before a native product-end equalization can be built.";

            case {"EQII-BD", "EQII-PR"}
                nativeRunnable = false;
                nativeRunnableScope = "paired_selection_required";
                wrapperOperation = "equalization_role_requires_EQII_pair";
                stageLabel = "EQII";
                unsupportedReason = ...
                    "EQII roles require an explicit WP2 donor/receiver pair before a native product-end equalization can be built.";

            case {"PP", "PU"}
                nativeRunnable = false;
                nativeRunnableScope = "paired_selection_required";
                wrapperOperation = "provide_purge_role_requires_PP_PU_pair";
                stageLabel = "PP_PU";
                unsupportedReason = ...
                    "PP and PU require an explicit WP2 PP_PU pair and remain wrapper-adapter operations.";

            case "BF"
                nativeRunnable = false;
                nativeRunnableScope = "paired_selection_required";
                wrapperOperation = "backfill_receiver_requires_ADPP_BF_pair";
                stageLabel = "ADPP_BF";
                unsupportedReason = ...
                    "BF requires an explicit WP2 ADPP_BF pair and remains a wrapper-adapter operation.";

            otherwise
                unsupportedReason = "Unknown Yang single-bed label: " + yangLabel + ".";
        end

    else
        error('WP4:InvalidSelectionType', ...
            'Unsupported WP4 selection type %s.', char(selectionType));
    end

    localOperations = makeLocalOperations(localMap, nativeStepNames);

    translation = struct();
    translation.version = "WP4-Yang2009-native-translation-v1";
    translation.selectionType = selectionType;
    translation.directTransferFamily = directTransferFamily;
    translation.nativeRunnable = nativeRunnable;
    translation.nativeRunnableScope = nativeRunnableScope;
    translation.nativeStepNames = nativeStepNames(:);
    translation.sStepCol = cellstr(nativeStepNames(:));
    translation.wrapperOperation = wrapperOperation;
    translation.stageLabel = stageLabel;
    translation.localOperations = localOperations;
    translation.endpointPolicy = endpointPolicy;
    translation.pressureClassPolicy = pressureClassPolicy;
    translation.accountingPolicy = accountingPolicy;
    translation.numAdsEqPrEnd = numAdsEqPrEnd(:);
    translation.numAdsEqFeEnd = numAdsEqFeEnd(:);
    translation.operationPolicy = string(opts.OperationPolicy);
    translation.warnings = warnings;
    translation.unsupportedReason = unsupportedReason;
    translation.allowDiagnosticOnly = logical(opts.AllowDiagnosticOnly);
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
        error('WP4:InvalidSelection', ...
            'Selection must be a struct returned by a WP3 selector.');
    end

    selectionFields = string(fieldnames(selection));
    missingFields = setdiff(requiredFields, selectionFields);
    if ~isempty(missingFields)
        error('WP4:InvalidSelection', ...
            'Selection is missing required fields: %s.', char(strjoin(missingFields, ", ")));
    end

    if ~istable(selection.localMap) || height(selection.localMap) < 1
        error('WP4:InvalidSelection', ...
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
        "p_start_class"
        "p_end_class"
        "inlet_endpoint"
        "outlet_endpoint"
        "waste_endpoint"
        "transfer_accounting_category"
    ];
    mapVars = string(selection.localMap.Properties.VariableNames);
    missingMapVars = setdiff(requiredMapVars, mapVars);
    if ~isempty(missingMapVars)
        error('WP4:InvalidSelection', ...
            'selection.localMap is missing required columns: %s.', char(strjoin(missingMapVars, ", ")));
    end
end

function endpointPolicy = makeEndpointPolicy(localMap, opts)
    endpointPolicy = struct();
    endpointPolicy.donorOutletEndpoint = firstOrNone(localMap, "outlet_endpoint");
    endpointPolicy.receiverInletEndpoint = lastOrNone(localMap, "inlet_endpoint");
    endpointPolicy.receiverWasteEndpoint = lastOrNone(localMap, "waste_endpoint");
    endpointPolicy.externalFeed = false;
    endpointPolicy.externalProduct = false;
    endpointPolicy.externalWaste = false;
    endpointPolicy.externalProductSink = string(opts.ExternalProductSink);
    endpointPolicy.externalWasteSink = string(opts.ExternalWasteSink);
    endpointPolicy.externalProductSeparated = false;
    endpointPolicy.internalTransferIsExternalProduct = false;
end

function pressureClassPolicy = makePressureClassPolicy(localMap)
    pressureClassPolicy = struct();
    pressureClassPolicy.startClasses = string(localMap.p_start_class);
    pressureClassPolicy.endClasses = string(localMap.p_end_class);
    pressureClassPolicy.numericIntermediatePressurePolicy = ...
        "symbolic_only_do_not_invent_P1_P2_P3_P5_P6_values";
end

function accountingPolicy = makeAccountingPolicy(localMap)
    accountingPolicy = struct();
    accountingPolicy.localCategories = string(localMap.transfer_accounting_category);
    if height(localMap) > 0
        accountingPolicy.transferAccountingCategory = string(localMap.transfer_accounting_category(1));
    else
        accountingPolicy.transferAccountingCategory = "none";
    end
    accountingPolicy.internalTransfersCountAsExternalProduct = false;
end

function localOperations = makeLocalOperations(localMap, nativeStepNames)
    localIndex = localMap.local_index;
    localRole = string(localMap.local_role);
    globalBed = string(localMap.global_bed);
    yangLabel = string(localMap.yang_label);
    nativeStepName = nativeStepNames(:);
    inletEndpoint = string(localMap.inlet_endpoint);
    outletEndpoint = string(localMap.outlet_endpoint);
    wasteEndpoint = string(localMap.waste_endpoint);
    pStartClass = string(localMap.p_start_class);
    pEndClass = string(localMap.p_end_class);
    accountingCategory = string(localMap.transfer_accounting_category);

    localOperations = table( ...
        localIndex, ...
        localRole, ...
        globalBed, ...
        yangLabel, ...
        nativeStepName, ...
        inletEndpoint, ...
        outletEndpoint, ...
        wasteEndpoint, ...
        pStartClass, ...
        pEndClass, ...
        accountingCategory, ...
        'VariableNames', [
            "local_index"
            "local_role"
            "global_bed"
            "yang_label"
            "native_step_name"
            "inlet_endpoint"
            "outlet_endpoint"
            "waste_endpoint"
            "p_start_class"
            "p_end_class"
            "accounting_category"
        ]);
end

function value = firstOrNone(localMap, varName)
    if height(localMap) < 1 || ~ismember(varName, string(localMap.Properties.VariableNames))
        value = "none";
    else
        value = string(localMap.(char(varName))(1));
    end
end

function value = lastOrNone(localMap, varName)
    if height(localMap) < 1 || ~ismember(varName, string(localMap.Properties.VariableNames))
        value = "none";
    else
        value = string(localMap.(char(varName))(height(localMap)));
    end
end
