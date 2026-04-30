function result = assertNoYangInternalTankInventory(tempCase)
%ASSERTNOYANGINTERNALTANKINVENTORY Guard WP4 no-internal-tank policy.
%
% The guard scans field names for forbidden Yang-path inventory objects.
% Metadata values such as localMap.state_field or external product sinks are
% allowed because they do not create persistent internal transfer inventory.

    failures = strings(0, 1);
    warnings = strings(0, 1);
    checks = table(strings(0, 1), false(0, 1), strings(0, 1), ...
        'VariableNames', ["check", "passed", "detail"]);

    if nargin < 1 || ~isstruct(tempCase)
        recordCheck("temporary_case_is_struct", false, ...
            "Temporary case must be a struct.");
        result = packResult();
        return;
    end

    forbiddenFieldTokens = [
        "tank_state"
        "internal_tank"
        "dynamic_tank"
        "dynamic_tank_inventory"
        "header_inventory"
        "shared_header"
        "shared_header_inventory"
        "four_bed_rhs"
        "four_bed_dae"
    ];
    forbiddenPersistentStateFields = ["state_A", "state_B", "state_C", "state_D"];

    fieldPaths = collectStructFieldPaths(tempCase, "");
    lowerPaths = lower(fieldPaths);

    hasForbiddenInventoryField = false;
    for i = 1:numel(forbiddenFieldTokens)
        hasForbiddenInventoryField = hasForbiddenInventoryField || ...
            any(contains(lowerPaths, forbiddenFieldTokens(i)));
    end
    recordCheck("no_dynamic_internal_tank_or_header_fields", ~hasForbiddenInventoryField, ...
        "No Yang internal tank/header inventory or four-bed RHS/DAE field names may be present.");

    hasPersistentStateField = false;
    for i = 1:numel(forbiddenPersistentStateFields)
        hasPersistentStateField = hasPersistentStateField || ...
            any(fieldPaths == forbiddenPersistentStateFields(i)) || ...
            any(endsWith(fieldPaths, "." + forbiddenPersistentStateFields(i)));
    end
    recordCheck("no_persistent_named_bed_state_fields", ~hasPersistentStateField, ...
        "Temporary cases must not contain state_A/state_B/state_C/state_D payload fields.");

    if isfield(tempCase, 'architecture') && isstruct(tempCase.architecture)
        arch = tempCase.architecture;
        requiredTrue = [
            "noDynamicInternalTanks"
            "noSharedHeaderInventory"
            "noFourBedRhsDae"
        ];
        for i = 1:numel(requiredTrue)
            flagName = requiredTrue(i);
            recordCheck("architecture_" + flagName, ...
                isfield(arch, char(flagName)) && logical(arch.(char(flagName))), ...
                "Required WP4 architecture guardrail flag must be true.");
        end
    else
        recordCheck("architecture_guardrail_struct_present", false, ...
            "Temporary case must include architecture guardrail metadata.");
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

function fieldPaths = collectStructFieldPaths(value, prefix)
    fieldPaths = strings(0, 1);
    if ~isstruct(value)
        return;
    end

    fields = string(fieldnames(value));
    for i = 1:numel(fields)
        if prefix == ""
            path = fields(i);
        else
            path = prefix + "." + fields(i);
        end
        fieldPaths(end+1, 1) = path; %#ok<AGROW>

        nested = value.(char(fields(i)));
        if isstruct(nested)
            nestedPaths = collectStructFieldPaths(nested, path);
            fieldPaths = [fieldPaths; nestedPaths]; %#ok<AGROW>
        end
    end
end
