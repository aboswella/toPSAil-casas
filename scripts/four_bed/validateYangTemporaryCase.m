function result = validateYangTemporaryCase(tempCase, varargin)
%VALIDATEYANGTEMPORARYCASE Static WP4 temporary-case checks.

    failures = strings(0, 1);
    warnings = strings(0, 1);
    checks = table(strings(0, 1), false(0, 1), strings(0, 1), ...
        'VariableNames', ["check", "passed", "detail"]);

    parser = inputParser;
    addParameter(parser, 'StrictNativeRunnable', false);
    parse(parser, varargin{:});
    opts = parser.Results;

    if nargin < 1 || ~isstruct(tempCase)
        recordCheck("temporary_case_is_struct", false, ...
            "Temporary case input must be a struct.");
        result = packResult();
        return;
    end

    requiredFields = [
        "version"
        "caseType"
        "selectionVersion"
        "selectionType"
        "pairId"
        "directTransferFamily"
        "nLocalBeds"
        "localMap"
        "localStates"
        "yang"
        "native"
        "template"
        "execution"
        "architecture"
        "metadata"
    ];
    tempFields = string(fieldnames(tempCase));
    for i = 1:numel(requiredFields)
        fieldName = requiredFields(i);
        recordCheck("has_field_" + fieldName, any(tempFields == fieldName), ...
            "Required WP4 temporary-case top-level field.");
    end
    if ~all(ismember(requiredFields, tempFields))
        result = packResult();
        return;
    end

    recordCheck("version_nonempty", strlength(string(tempCase.version)) > 0, ...
        "Temporary case version must be nonempty.");
    recordCheck("case_type_supported", ...
        ismember(string(tempCase.caseType), ["paired_direct_transfer", "single_bed_operation"]), ...
        "caseType must be paired_direct_transfer or single_bed_operation.");
    recordCheck("n_local_beds_supported", ismember(tempCase.nLocalBeds, [1, 2]), ...
        "nLocalBeds must be 1 or 2.");

    validateLocalMap(tempCase.localMap, tempCase.nLocalBeds, string(tempCase.caseType));
    validateLocalStates(tempCase.localStates, tempCase.nLocalBeds);
    validateNativeTranslation(tempCase.native, tempCase.nLocalBeds, logical(opts.StrictNativeRunnable));
    validateArchitecture(tempCase.architecture);

    guard = assertNoYangInternalTankInventory(tempCase);
    recordCheck("no_internal_tank_inventory_guard", guard.pass, ...
        "No forbidden internal inventory or four-bed RHS/DAE fields.");
    if ~guard.pass
        failures = [failures; guard.failures]; %#ok<AGROW>
    end

    selectedStateCountOk = true;
    if isfield(tempCase, 'localStates') && iscell(tempCase.localStates)
        selectedStateCountOk = numel(tempCase.localStates) == tempCase.nLocalBeds;
    end
    recordCheck("contains_only_selected_local_state_payloads", selectedStateCountOk, ...
        "Temporary case localStates must contain exactly the selected local payloads.");

    result = packResult();

    function validateLocalMap(localMap, nLocalBeds, caseType)
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

        recordCheck("local_map_is_table", istable(localMap), ...
            "localMap must be a table.");
        if ~istable(localMap)
            return;
        end

        mapVars = string(localMap.Properties.VariableNames);
        recordCheck("local_map_required_columns", all(ismember(requiredMapVars, mapVars)), ...
            "localMap must expose the WP3/WP4 mapping schema.");
        recordCheck("local_map_height_matches_n_local", height(localMap) == nLocalBeds, ...
            "localMap height must match nLocalBeds.");
        recordCheck("local_indices_are_consecutive", ...
            isequal(localMap.local_index(:), (1:nLocalBeds)'), ...
            "localMap.local_index must be 1:nLocalBeds.");
        recordCheck("global_beds_are_known", ...
            all(ismember(string(localMap.global_bed), ["A", "B", "C", "D"])), ...
            "global_bed values must be A, B, C, or D.");

        if caseType == "paired_direct_transfer" && height(localMap) == 2
            recordCheck("paired_global_beds_are_distinct", ...
                numel(unique(string(localMap.global_bed))) == 2, ...
                "Paired cases must use distinct donor and receiver beds.");
            recordCheck("paired_local_roles_are_donor_receiver", ...
                string(localMap.local_role(1)) == "donor" && string(localMap.local_role(2)) == "receiver", ...
                "Paired cases must keep donor as local 1 and receiver as local 2.");
        end
    end

    function validateLocalStates(localStates, nLocalBeds)
        recordCheck("local_states_is_cell", iscell(localStates), ...
            "localStates must be a cell array.");
        if iscell(localStates)
            recordCheck("local_states_count_matches_n_local", numel(localStates) == nLocalBeds, ...
                "localStates count must equal nLocalBeds.");
        end
    end

    function validateNativeTranslation(native, nLocalBeds, strictNativeRunnable)
        requiredNativeFields = [
            "version"
            "nativeRunnable"
            "nativeRunnableScope"
            "nativeStepNames"
            "wrapperOperation"
            "localOperations"
            "endpointPolicy"
            "pressureClassPolicy"
            "accountingPolicy"
            "warnings"
            "unsupportedReason"
        ];

        recordCheck("native_translation_is_struct", isstruct(native), ...
            "native translation must be a struct.");
        if ~isstruct(native)
            return;
        end

        nativeFields = string(fieldnames(native));
        recordCheck("native_translation_required_fields", ...
            all(ismember(requiredNativeFields, nativeFields)), ...
            "native translation must expose the WP4 translation schema.");
        if ~all(ismember(requiredNativeFields, nativeFields))
            return;
        end

        nativeStepNames = string(native.nativeStepNames(:));
        recordCheck("native_step_name_count_matches_n_local", ...
            numel(nativeStepNames) == nLocalBeds, ...
            "nativeStepNames must have one entry per local bed.");

        rawYangLabels = [
            "AD"
            "AD&PP"
            "EQI-BD"
            "PP"
            "EQII-BD"
            "BD"
            "PU"
            "EQII-PR"
            "EQI-PR"
            "BF"
        ];
        rawLabelLeak = any(ismember(nativeStepNames, rawYangLabels));
        recordCheck("raw_yang_labels_not_native_steps", ~rawLabelLeak, ...
            "Native step-name fields must not contain raw Yang labels.");

        if ~logical(native.nativeRunnable)
            recordCheck("unsupported_translation_has_reason", ...
                strlength(string(native.unsupportedReason)) > 0, ...
                "Unsupported translations must state why they are not native-runnable.");
        elseif strictNativeRunnable
            recordCheck("native_runnable_has_core_scope", ...
                ismember(string(native.nativeRunnableScope), ["core_step", "wrapper_adapter"]), ...
                "Strict native-runnable checks require a core or wrapper-adapter scope.");
        end

        recordCheck("local_operations_is_table", istable(native.localOperations), ...
            "native.localOperations must be a table.");
        if istable(native.localOperations)
            recordCheck("local_operations_height_matches_n_local", ...
                height(native.localOperations) == nLocalBeds, ...
                "native.localOperations must have one row per local bed.");
        end
    end

    function validateArchitecture(architecture)
        requiredTrue = [
            "noDynamicInternalTanks"
            "noSharedHeaderInventory"
            "noFourBedRhsDae"
            "noCoreAdsorberPhysicsRewrite"
            "temporaryCaseContainsOnlySelectedLocalStates"
        ];
        requiredFalse = [
            "wp4ComputesLedgersOrMetrics"
            "wp4UsesEventScheduling"
        ];

        recordCheck("architecture_is_struct", isstruct(architecture), ...
            "architecture must be a guardrail struct.");
        if ~isstruct(architecture)
            return;
        end

        for i = 1:numel(requiredTrue)
            flagName = requiredTrue(i);
            recordCheck("architecture_" + flagName, ...
                isfield(architecture, char(flagName)) && logical(architecture.(char(flagName))), ...
                "Required WP4 architecture guardrail flag must be true.");
        end

        for i = 1:numel(requiredFalse)
            flagName = requiredFalse(i);
            recordCheck("architecture_" + flagName, ...
                isfield(architecture, char(flagName)) && ~logical(architecture.(char(flagName))), ...
                "Required WP4 non-owner architecture flag must be false.");
        end
    end

    function recordCheck(name, didPass, detail)
        didPass = logical(didPass);
        checks = [checks; table(string(name), didPass, string(detail), ...
            'VariableNames', ["check", "passed", "detail"])]; %#ok<AGROW>
        if ~didPass
            failures(end+1, 1) = string(name) + ": " + string(detail); %#ok<AGROW>
        end
    end

    function packed = packResult()
        packed = struct();
        packed.pass = isempty(failures);
        packed.failures = failures;
        packed.warnings = warnings;
        packed.checks = checks;
    end
end
