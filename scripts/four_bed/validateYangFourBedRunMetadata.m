function result = validateYangFourBedRunMetadata(metadata)
%VALIDATEYANGFOURBEDRUNMETADATA Check WP5 output assumption metadata.

    failures = strings(0, 1);
    warnings = strings(0, 1);
    checks = table(strings(0, 1), false(0, 1), strings(0, 1), ...
        'VariableNames', ["check", "passed", "detail"]);

    if nargin < 1 || ~isstruct(metadata)
        recordCheck("metadata_is_struct", false, ...
            "Run metadata must be a struct.");
        result = packResult();
        return;
    end

    requiredFields = [
        "version"
        "createdBy"
        "manifestVersion"
        "pairMapVersion"
        "wrapperMode"
        "holdupPolicy"
        "internalTransferPolicy"
        "statePolicy"
        "caseBuilderPolicy"
        "eventPolicy"
        "metricBasis"
        "cssBasis"
        "nativeMetricPolicy"
        "layeredBedPolicy"
        "thermalPolicy"
        "modelMismatchPolicy"
        "validationClaim"
        "runnerMode"
        "numericalCommissioningStatus"
        "notes"
    ];

    fields = string(fieldnames(metadata));
    for i = 1:numel(requiredFields)
        fieldName = requiredFields(i);
        hasField = any(fields == fieldName);
        recordCheck("has_field_" + fieldName, hasField, ...
            "Required WP5 run-metadata field.");
        if hasField
            value = string(metadata.(char(fieldName)));
            recordCheck("field_nonempty_" + fieldName, any(strlength(value) > 0), ...
                "Required run-metadata fields must be nonempty.");
        end
    end

    if ~all(ismember(requiredFields, fields))
        result = packResult();
        return;
    end

    recordCheck("manifest_version_supplied", string(metadata.manifestVersion) ~= "not_supplied", ...
        "Output metadata must carry the manifest version.");
    recordCheck("pair_map_version_supplied", string(metadata.pairMapVersion) ~= "not_supplied", ...
        "Output metadata must carry the pair-map version.");
    recordCheck("wrapper_mode_thin_layer", ...
        string(metadata.wrapperMode) == "thin_four_bed_orchestration_layer", ...
        "Wrapper mode must identify the thin four-bed orchestration layer.");
    recordCheck("holdup_policy_no_tanks_or_header", ...
        contains(string(metadata.holdupPolicy), "zero_holdup") && ...
        contains(string(metadata.holdupPolicy), "no_dynamic_tanks") && ...
        contains(string(metadata.holdupPolicy), "no_shared_header_inventory"), ...
        "Holdup policy must state zero holdup, no dynamic tanks, and no shared header inventory.");
    recordCheck("internal_transfer_not_product", ...
        contains(string(metadata.internalTransferPolicy), "not_external_product"), ...
        "Internal-transfer policy must state that transfers are not external product.");
    recordCheck("state_policy_named_beds", ...
        contains(string(metadata.statePolicy), "A_B_C_D"), ...
        "State policy must state that only persistent named A/B/C/D bed states are used.");
    recordCheck("case_builder_policy_temporary_cases", ...
        contains(string(metadata.caseBuilderPolicy), "temporary_single_or_two"), ...
        "Case-builder policy must state temporary single/two local bed cases.");
    recordCheck("event_policy_fixed_duration", ...
        string(metadata.eventPolicy) == "fixed_duration_only", ...
        "Event policy must remain fixed-duration only.");
    recordCheck("metric_basis_external_and_internal_excluded", ...
        contains(string(metadata.metricBasis), "external") && ...
        contains(string(metadata.metricBasis), "internal_transfers_excluded"), ...
        "Metric basis must state external streams and internal-transfer exclusion.");
    recordCheck("native_metric_policy_diagnostic", ...
        contains(string(metadata.nativeMetricPolicy), "diagnostic_not_yang_basis"), ...
        "Native toPSAil metrics must be labelled diagnostic, not Yang-basis.");
    recordCheck("layered_bed_policy_visible", ...
        strlength(string(metadata.layeredBedPolicy)) > 0, ...
        "Layered-bed or homogeneous-surrogate status must be visible.");
    recordCheck("thermal_policy_visible", ...
        strlength(string(metadata.thermalPolicy)) > 0, ...
        "Thermal mode/status must be visible.");
    recordCheck("model_mismatch_policy_visible", ...
        contains(string(metadata.modelMismatchPolicy), "do_not_claim_yang_validation"), ...
        "Model mismatch policy must prevent premature Yang validation claims.");
    recordCheck("validation_claim_commissioning_only", ...
        contains(string(metadata.validationClaim), "commissioning_only"), ...
        "Validation claim must be limited to WP5 commissioning.");

    if isfield(metadata, 'architectureFlags') && isstruct(metadata.architectureFlags)
        flags = metadata.architectureFlags;
        requiredTrue = [
            "noDynamicInternalTanks"
            "noSharedHeaderInventory"
            "noFourBedRhsDae"
            "noCoreAdsorberPhysicsRewrite"
            "internalTransfersExcludedFromExternalProduct"
            "fixedDurationOnly"
        ];
        for i = 1:numel(requiredTrue)
            flagName = requiredTrue(i);
            recordCheck("architecture_flag_" + flagName, ...
                isfield(flags, char(flagName)) && logical(flags.(char(flagName))), ...
                "Required metadata architecture flag must be true.");
        end
    else
        recordCheck("architecture_flags_present", false, ...
            "Run metadata must expose architectureFlags.");
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
