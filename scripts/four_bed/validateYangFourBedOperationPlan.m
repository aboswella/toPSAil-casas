function result = validateYangFourBedOperationPlan(plan, manifest, pairMap)
%VALIDATEYANGFOURBEDOPERATIONPLAN Check FI-6 plan integrity.

    if nargin < 2 || isempty(manifest)
        manifest = getYangFourBedScheduleManifest();
    end
    if nargin < 3 || isempty(pairMap)
        pairMap = getYangDirectTransferPairMap(manifest);
    end

    failures = strings(0, 1);
    warnings = strings(0, 1);
    checks = table(strings(0, 1), false(0, 1), strings(0, 1), ...
        'VariableNames', ["check", "passed", "detail"]);

    if nargin < 1 || ~isstruct(plan)
        recordCheck("plan_is_struct", false, ...
            "Operation plan must be a struct.");
        result = packResult();
        return;
    end

    requiredFields = [
        "operationGroups"
        "perBedSequences"
        "durationFractions"
        "durationSeconds"
        "pairedDurationPolicy"
        "source"
    ];
    planFields = string(fieldnames(plan));
    for i = 1:numel(requiredFields)
        recordCheck("has_field_" + requiredFields(i), ...
            ismember(requiredFields(i), planFields), ...
            "Required FI-6 plan field.");
    end
    if ~all(ismember(requiredFields, planFields))
        result = packResult();
        return;
    end

    groups = plan.operationGroups(:);
    recordCheck("operation_group_count_24", numel(groups) == 24, ...
        "A complete cycle must have 24 operation groups.");
    families = string({groups.operationFamily}).';
    requiredFamilies = ["AD"; "BD"; "EQI"; "EQII"; "PP_PU"; "ADPP_BF"];
    for i = 1:numel(requiredFamilies)
        fam = requiredFamilies(i);
        recordCheck("four_groups_" + fam, sum(families == fam) == 4, ...
            "Each operation family must appear exactly four times.");
    end

    participationCount = 0;
    for i = 1:numel(groups)
        participationCount = participationCount + numel(string(groups(i).participants(:)));
        recordCheck("group_" + i + "_route_defined", strlength(string(groups(i).route)) > 0, ...
            "Every group needs a dispatch route.");
        recordCheck("group_" + i + "_duration_defined", ...
            isfinite(groups(i).durationSec) && groups(i).durationSec > 0, ...
            "Every group needs a positive executable duration.");
        recordCheck("group_" + i + "_local_map_table", istable(groups(i).localMap), ...
            "Every group needs a local/global map.");
    end
    recordCheck("bed_step_participations_40", participationCount == 40, ...
        "A complete cycle has 40 bed-step participations.");

    expected = expectedBedSequences();
    bedLabels = string(manifest.bedLabels(:));
    for i = 1:numel(bedLabels)
        bed = bedLabels(i);
        if ~isfield(plan.perBedSequences, char(bed))
            recordCheck("bed_sequence_" + bed + "_present", false, ...
                "Missing per-bed sequence.");
            continue;
        end
        labels = string(plan.perBedSequences.(char(bed)).yang_label);
        recordCheck("bed_sequence_" + bed + "_matches_manifest", ...
            isequal(labels(:), expected.(char(bed))(:)), ...
            "Per-bed operation order must preserve the manifest.");
    end

    pairGroups = groups(families ~= "AD" & families ~= "BD");
    planPairIds = string({pairGroups.pairId}).';
    sourcePairIds = string(pairMap.transferPairs.pair_id(:));
    recordCheck("all_pairs_from_pair_map", ...
        isempty(setdiff(planPairIds, sourcePairIds)) && isempty(setdiff(sourcePairIds, planPairIds)), ...
        "Paired groups must come from explicit pair-map rows.");

    routes = string({groups.route}).';
    recordCheck("native_and_adapter_routes_only", ...
        all(ismember(routes, ["native_single", "native_pair", "adapter"])), ...
        "Routes must stay within wrapper temporary cases and adapters.");

    recordCheck("duration_fractions_sum_one", ...
        abs(sum(plan.durationFractions(:)) - 1) < 1e-12, ...
        "Executable duration fractions must sum to one.");

    if isfield(plan, 'architecture') && isstruct(plan.architecture)
        arch = plan.architecture;
        recordCheck("arch_no_dynamic_tanks", hasTrue(arch, 'noDynamicInternalTanks'), ...
            "Operation planning must not create dynamic internal tanks.");
        recordCheck("arch_no_shared_header", hasTrue(arch, 'noSharedHeaderInventory'), ...
            "Operation planning must not create shared header inventory.");
        recordCheck("arch_no_global_rhs", hasTrue(arch, 'noGlobalFourBedRhs'), ...
            "Operation planning must not create a global four-bed RHS.");
    else
        warnings(end+1, 1) = "operation plan has no architecture field";
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

function expected = expectedBedSequences()
    expected = struct();
    expected.A = ["AD"; "AD&PP"; "EQI-BD"; "PP"; "EQII-BD"; ...
        "BD"; "PU"; "EQII-PR"; "EQI-PR"; "BF"];
    expected.B = ["EQI-PR"; "BF"; "AD"; "AD&PP"; "EQI-BD"; ...
        "PP"; "EQII-BD"; "BD"; "PU"; "EQII-PR"];
    expected.C = ["BD"; "PU"; "EQII-PR"; "EQI-PR"; "BF"; ...
        "AD"; "AD&PP"; "EQI-BD"; "PP"; "EQII-BD"];
    expected.D = ["EQI-BD"; "PP"; "EQII-BD"; "BD"; "PU"; ...
        "EQII-PR"; "EQI-PR"; "BF"; "AD"; "AD&PP"];
end

function tf = hasTrue(s, fieldName)
    tf = isfield(s, fieldName) && logical(s.(fieldName));
end
