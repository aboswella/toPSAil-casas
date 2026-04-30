function result = validateYangFourBedLedger(ledger)
%VALIDATEYANGFOURBEDLEDGER Static schema and accounting guard checks.

    failures = strings(0, 1);
    warnings = strings(0, 1);
    checks = table(strings(0, 1), false(0, 1), strings(0, 1), ...
        'VariableNames', ["check", "passed", "detail"]);

    if nargin < 1 || ~isstruct(ledger)
        recordCheck("ledger_is_struct", false, ...
            "Ledger input must be a struct.");
        result = packResult();
        return;
    end

    requiredFields = [
        "version"
        "componentNames"
        "streamRows"
        "balanceRows"
        "metricRows"
        "cssRows"
        "metadata"
        "architecture"
    ];
    fields = string(fieldnames(ledger));
    for i = 1:numel(requiredFields)
        fieldName = requiredFields(i);
        recordCheck("has_field_" + fieldName, any(fields == fieldName), ...
            "Required WP5 ledger top-level field.");
    end

    if ~all(ismember(requiredFields, fields))
        result = packResult();
        return;
    end

    componentNames = string(ledger.componentNames(:));
    recordCheck("component_names_nonempty", ~isempty(componentNames) && all(strlength(componentNames) > 0), ...
        "Ledger must carry nonempty component names.");
    recordCheck("component_names_unique", numel(unique(componentNames)) == numel(componentNames), ...
        "Ledger component names must be unique.");

    validateStreamRows(ledger.streamRows, componentNames);
    validateTableColumns(ledger.balanceRows, [
        "cycle_index"
        "slot_index"
        "balance_scope"
        "operation_group_id"
        "stage_label"
        "direct_transfer_family"
        "component"
        "external_feed_moles"
        "external_product_moles"
        "external_waste_moles"
        "bed_inventory_delta_moles"
        "internal_out_of_donor_moles"
        "internal_into_receiver_moles"
        "residual_moles"
        "tolerance_moles"
        "pass"
        "basis"
        "notes"
    ], "balance_rows");
    validateTableColumns(ledger.metricRows, [
        "cycle_index"
        "metric_name"
        "component"
        "value"
        "numerator_moles"
        "denominator_moles"
        "basis"
        "pass"
        "notes"
    ], "metric_rows");
    validateTableColumns(ledger.cssRows, [
        "cycle_index"
        "bed"
        "state_field"
        "family"
        "n_values"
        "max_abs"
        "rms_abs"
        "relative_norm"
        "pass"
        "notes"
    ], "css_rows");

    if isstruct(ledger.metadata)
        metadataResult = validateYangFourBedRunMetadata(ledger.metadata);
        recordCheck("metadata_required_assumptions", metadataResult.pass, ...
            "Ledger metadata must state WP5 assumptions.");
        if ~metadataResult.pass
            failures = [failures; metadataResult.failures]; %#ok<AGROW>
        end
    else
        recordCheck("metadata_is_struct", false, ...
            "Ledger metadata must be a struct.");
    end

    arch = ledger.architecture;
    recordCheck("architecture_is_struct", isstruct(arch), ...
        "Ledger architecture guardrails must be a struct.");
    if isstruct(arch)
        requiredTrue = [
            "noDynamicInternalTanks"
            "noSharedHeaderInventory"
            "noFourBedRhsDae"
            "noCoreAdsorberPhysicsRewrite"
            "wp5AccountingLayerOnly"
        ];
        for i = 1:numel(requiredTrue)
            flagName = requiredTrue(i);
            recordCheck("architecture_" + flagName, ...
                isfield(arch, char(flagName)) && logical(arch.(char(flagName))), ...
                "Required WP5 architecture guardrail flag must be true.");
        end
        recordCheck("architecture_internal_transfers_not_product", ...
            isfield(arch, 'internalTransfersCountAsExternalProduct') && ...
            ~logical(arch.internalTransfersCountAsExternalProduct), ...
            "Internal transfers must not count as external product.");
    end

    result = packResult();

    function validateStreamRows(rows, components)
        requiredVars = [
            "cycle_index"
            "slot_index"
            "operation_group_id"
            "source_col"
            "record_id"
            "pair_id"
            "stage_label"
            "direct_transfer_family"
            "yang_label"
            "global_bed"
            "local_index"
            "local_role"
            "stream_scope"
            "stream_direction"
            "endpoint"
            "component"
            "moles"
            "basis"
            "units"
            "notes"
        ];
        validateTableColumns(rows, requiredVars, "stream_rows");
        if ~istable(rows)
            return;
        end
        rowVars = string(rows.Properties.VariableNames);
        if ~all(ismember(requiredVars, rowVars))
            return;
        end

        allowedScopes = [
            "external_feed"
            "external_product"
            "external_waste"
            "internal_transfer"
            "bed_inventory_delta"
        ];
        allowedDirections = [
            "in"
            "out"
            "out_of_donor"
            "into_receiver"
            "delta"
        ];

        recordCheck("stream_components_known", all(ismember(string(rows.component), components)), ...
            "Every stream row component must appear in ledger.componentNames.");
        recordCheck("stream_scopes_allowed", all(ismember(string(rows.stream_scope), allowedScopes)), ...
            "Stream scopes must be WP5 external/internal/inventory categories.");
        recordCheck("stream_directions_allowed", all(ismember(string(rows.stream_direction), allowedDirections)), ...
            "Stream directions must be one of the WP5 sign-convention labels.");
        recordCheck("stream_moles_finite", all(isfinite(rows.moles)), ...
            "Stream-row moles must be finite.");

        if height(rows) > 0
            nonInventory = string(rows.stream_scope) ~= "bed_inventory_delta";
            recordCheck("non_inventory_moles_nonnegative", all(rows.moles(nonInventory) >= 0), ...
                "External and internal stream rows must be nonnegative.");
            internalRows = string(rows.stream_scope) == "internal_transfer";
            productRows = string(rows.stream_scope) == "external_product";
            recordCheck("internal_rows_not_product_rows", ~any(internalRows & productRows), ...
                "Internal-transfer rows must not also be external-product rows.");
        end
    end

    function validateTableColumns(rows, requiredVars, tableName)
        recordCheck(tableName + "_is_table", istable(rows), ...
            tableName + " must be a table.");
        if istable(rows)
            rowVars = string(rows.Properties.VariableNames);
            recordCheck(tableName + "_required_columns", all(ismember(requiredVars, rowVars)), ...
                tableName + " must expose the WP5 schema.");
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
