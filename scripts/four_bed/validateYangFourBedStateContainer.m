function result = validateYangFourBedStateContainer(container, varargin)
%VALIDATEYANGFOURBEDSTATECONTAINER Static WP3 state-container checks.

    failures = strings(0, 1);
    warnings = strings(0, 1);
    checks = table(strings(0, 1), false(0, 1), strings(0, 1), ...
        'VariableNames', ["check", "passed", "detail"]);

    parser = inputParser;
    addParameter(parser, 'Manifest', []);
    addParameter(parser, 'PairMap', []);
    parse(parser, varargin{:});
    opts = parser.Results;

    if nargin < 1 || ~isstruct(container)
        recordCheck("container_is_struct", false, ...
            "Container input must be a struct.");
        result = packResult();
        return;
    end

    requiredFields = [
        "version"
        "manifestVersion"
        "pairMapVersion"
        "bedLabels"
        "stateFields"
        "initializationPolicy"
        "architecture"
        "stateMetadata"
        "writebackLog"
        "state_A"
        "state_B"
        "state_C"
        "state_D"
    ];

    containerFields = string(fieldnames(container));
    for i = 1:numel(requiredFields)
        fieldName = requiredFields(i);
        recordCheck("has_field_" + fieldName, any(containerFields == fieldName), ...
            "Required WP3 state-container top-level field.");
    end

    if ~all(ismember(requiredFields, containerFields))
        result = packResult();
        return;
    end

    expectedBeds = ["A", "B", "C", "D"];
    expectedStateFields = ["state_A", "state_B", "state_C", "state_D"];

    recordCheck("bed_labels_are_A_B_C_D", ...
        isequal(string(container.bedLabels), expectedBeds), ...
        "Bed labels must be exactly A, B, C, and D.");
    recordCheck("state_fields_are_named_beds", ...
        isequal(string(container.stateFields), expectedStateFields), ...
        "State fields must be exactly state_A, state_B, state_C, and state_D.");

    for i = 1:numel(expectedStateFields)
        fieldName = expectedStateFields(i);
        canAccess = false;
        if isfield(container, char(fieldName))
            try
                container.(char(fieldName)); %#ok<VUNUS>
                canAccess = true;
            catch
                canAccess = false;
            end
        end
        recordCheck("state_payload_addressable_" + fieldName, canAccess, ...
            "Each named bed payload must be addressable without inspecting its internals.");
    end

    expectedMetadataVars = [
        "bed"
        "state_field"
        "initialization_policy"
        "source_note"
        "last_update_role"
        "last_update_pair_id"
        "last_update_operation"
        "last_update_source_col"
        "writeback_count"
    ];
    recordCheck("state_metadata_is_table", istable(container.stateMetadata), ...
        "stateMetadata must be a table.");
    if istable(container.stateMetadata)
        recordCheck("state_metadata_has_four_rows", height(container.stateMetadata) == 4, ...
            "stateMetadata must contain one row for each persistent bed.");
        metadataVars = string(container.stateMetadata.Properties.VariableNames);
        recordCheck("state_metadata_required_columns", ...
            all(ismember(expectedMetadataVars, metadataVars)), ...
            "stateMetadata must expose the WP3 metadata schema.");
    end

    expectedLogVars = [
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
    ];
    recordCheck("writeback_log_is_table", istable(container.writebackLog), ...
        "writebackLog must be a table, even when empty.");
    if istable(container.writebackLog)
        logVars = string(container.writebackLog.Properties.VariableNames);
        recordCheck("writeback_log_required_columns", ...
            all(ismember(expectedLogVars, logVars)), ...
            "writebackLog must expose the WP3 writeback schema.");
    end

    arch = container.architecture;
    trueFlags = [
        "noDynamicInternalTanks"
        "noSharedHeaderInventory"
        "noFourBedRhsDae"
        "noCoreAdsorberPhysicsRewrite"
        "wp3StoresPersistentBedStates"
    ];
    falseFlags = [
        "wp3BuildsTemporaryCases"
        "wp3InvokesSolver"
        "wp3ComputesLedgersOrMetrics"
    ];

    for i = 1:numel(trueFlags)
        flagName = trueFlags(i);
        recordCheck("architecture_" + flagName, ...
            isstruct(arch) && isfield(arch, char(flagName)) && logical(arch.(char(flagName))), ...
            "Required WP3 architecture guardrail flag must be true.");
    end

    for i = 1:numel(falseFlags)
        flagName = falseFlags(i);
        recordCheck("architecture_" + flagName, ...
            isstruct(arch) && isfield(arch, char(flagName)) && ~logical(arch.(char(flagName))), ...
            "Required WP3 non-owner architecture flag must be false.");
    end

    forbiddenTopLevelTokens = [
        "tank_state"
        "header_inventory"
        "shared_header_inventory"
        "dynamic_tank_inventory"
        "four_bed_rhs"
        "four_bed_dae"
    ];
    lowerFields = lower(containerFields);
    hasForbiddenField = false;
    for i = 1:numel(forbiddenTopLevelTokens)
        hasForbiddenField = hasForbiddenField || any(contains(lowerFields, forbiddenTopLevelTokens(i)));
    end
    recordCheck("no_forbidden_physical_state_top_level_fields", ~hasForbiddenField, ...
        "WP3 container must not create tank/header inventory or four-bed RHS/DAE fields.");

    if ~isempty(opts.Manifest)
        manifestVersionMatches = isstruct(opts.Manifest) && ...
            isfield(opts.Manifest, 'version') && ...
            string(container.manifestVersion) == string(opts.Manifest.version);
        recordCheck("manifest_version_matches", manifestVersionMatches, ...
            "Container manifestVersion must match the supplied manifest version.");
    end

    if ~isempty(opts.PairMap)
        pairMapVersionMatches = isstruct(opts.PairMap) && ...
            isfield(opts.PairMap, 'version') && ...
            string(container.pairMapVersion) == string(opts.PairMap.version);
        recordCheck("pair_map_version_matches", pairMapVersionMatches, ...
            "Container pairMapVersion must match the supplied pair map version.");
    end

    result = packResult();

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
