function plan = buildYangFourBedOperationPlan(manifest, pairMap, durations, varargin)
%BUILDYANGFOURBEDOPERATIONPLAN Build FI-6 executable operation groups.

    if nargin < 1 || isempty(manifest)
        manifest = getYangFourBedScheduleManifest();
    end
    if nargin < 2 || isempty(pairMap)
        pairMap = getYangDirectTransferPairMap(manifest);
    end
    if nargin < 3 || isempty(durations)
        durations = getYangNormalizedSlotDurations(240.0);
    end

    parser = inputParser;
    addParameter(parser, 'Policy', "topological_per_bed_sequence");
    addParameter(parser, 'PairedDurationPolicy', "donor_source_col");
    addParameter(parser, 'AllowSourceColumnMismatchWarnings', true);
    parse(parser, varargin{:});
    opts = parser.Results;

    validateInputs(manifest, pairMap, durations);

    groups = [buildSingleGroups(manifest, durations); ...
        buildPairGroups(manifest, pairMap, durations, opts)];
    [sortedGroups, perBedSequences, planWarnings] = topologicalSortGroups( ...
        groups, manifest, pairMap);

    plan = struct();
    plan.version = "FI6-Yang2009-four-bed-operation-plan-v1";
    plan.policy = string(opts.Policy);
    plan.pairedDurationPolicy = string(opts.PairedDurationPolicy);
    plan.durationUnits = durations.durationUnits(:);
    plan.durationFractions = durations.durationFractions(:);
    plan.durationSeconds = durations.durationSeconds(:);
    plan.durationUnitsSource = string(durations.normalizationPolicy);
    plan.durationUnitsPerCycle = sum(durations.durationUnits);
    plan.operationGroups = sortedGroups;
    plan.perBedSequences = perBedSequences;
    plan.warnings = planWarnings(:);
    plan.source = "manifest_plus_explicit_pair_map";
    plan.architecture = struct( ...
        "noDynamicInternalTanks", true, ...
        "noSharedHeaderInventory", true, ...
        "noGlobalFourBedRhs", true, ...
        "persistentStateBasis", "physical_adsorber_state_only");

    validation = validateYangFourBedOperationPlan(plan, manifest, pairMap);
    if ~validation.pass
        error('FI6:InvalidOperationPlan', ...
            'Yang operation plan failed validation: %s', ...
            char(strjoin(validation.failures, " | ")));
    end
    plan.validation = validation;
end

function validateInputs(manifest, pairMap, durations)
    if ~isstruct(manifest) || ~isfield(manifest, 'bedSteps')
        error('FI6:InvalidManifest', ...
            'manifest must contain a bedSteps table.');
    end
    if ~isstruct(pairMap) || ~isfield(pairMap, 'transferPairs')
        error('FI6:InvalidPairMap', ...
            'pairMap must contain transferPairs.');
    end
    requiredDurationFields = ["durationSeconds", "durationFractions", "durationUnits"];
    if ~isstruct(durations) || ~all(ismember(requiredDurationFields, string(fieldnames(durations))))
        error('FI6:InvalidDurations', ...
            'durations must come from getYangNormalizedSlotDurations.');
    end
end

function groups = buildSingleGroups(manifest, durations)
    rows = manifest.bedSteps(ismember(manifest.bedSteps.yang_label, ["AD", "BD"]), :);
    rows = sortrows(rows, ["source_col", "bed"]);
    groups = repmat(emptyGroup(), height(rows), 1);
    for i = 1:height(rows)
        row = rows(i, :);
        family = string(row.yang_label(1));
        localMap = makeSingleLocalMap(row);
        selection = makeSyntheticSelection("single_bed_operation", "none", ...
            "none", localMap);
        nativeStepSpec = translateYangNativeOperation(selection);

        groups(i) = emptyGroup();
        groups(i).operationGroupId = sprintf('%s-%s-col%02d', ...
            family, string(row.bed(1)), row.source_col(1));
        groups(i).operationFamily = family;
        groups(i).route = "native_single";
        groups(i).stageLabel = family;
        groups(i).directTransferFamily = "none";
        groups(i).sourceCol = row.source_col(1);
        groups(i).durationSec = durations.durationSeconds(row.source_col(1));
        groups(i).sourceDurationSec = groups(i).durationSec;
        groups(i).sourceDurationFraction = durations.durationFractions(row.source_col(1));
        groups(i).participants = string(row.bed(1));
        groups(i).primaryBed = string(row.bed(1));
        groups(i).donorBed = "none";
        groups(i).receiverBed = "none";
        groups(i).receiverSourceCol = NaN;
        groups(i).receiverDurationSec = NaN;
        groups(i).pairId = "none";
        groups(i).localMap = localMap;
        groups(i).nativeStepSpec = nativeStepSpec;
        groups(i).adapterFamily = "none";
        groups(i).ledgerHints = ledgerHintsForFamily(family);
        groups(i).notes = "single-bed native wrapper operation";
    end
end

function groups = buildPairGroups(manifest, pairMap, durations, opts)
    pairs = pairMap.transferPairs;
    pairs = sortrows(pairs, ["donor_source_col", "direct_transfer_family", "donor_bed"]);
    groups = repmat(emptyGroup(), height(pairs), 1);
    for i = 1:height(pairs)
        pair = pairs(i, :);
        family = string(pair.direct_transfer_family(1));
        donorCol = pair.donor_source_col(1);
        receiverCol = pair.receiver_source_col(1);
        localMap = makePairLocalMap(pair);
        selection = makeSyntheticSelection("paired_direct_transfer", ...
            string(pair.pair_id(1)), family, localMap);
        nativeStepSpec = translateYangNativeOperation(selection);
        warnings = strings(0, 1);
        if donorCol ~= receiverCol || ...
                durations.durationSeconds(donorCol) ~= durations.durationSeconds(receiverCol)
            message = sprintf(['paired group %s uses donor source column %d ', ...
                'while receiver source column is %d'], ...
                string(pair.pair_id(1)), donorCol, receiverCol);
            if logical(opts.AllowSourceColumnMismatchWarnings)
                warnings(end+1, 1) = string(message);
            else
                error('FI6:PairSourceColumnMismatch', '%s', message);
            end
        end

        route = "adapter";
        if ismember(family, ["EQI", "EQII"])
            route = "native_pair";
        end

        groups(i) = emptyGroup();
        groups(i).operationGroupId = string(pair.pair_id(1));
        groups(i).operationFamily = family;
        groups(i).route = route;
        groups(i).stageLabel = family;
        groups(i).directTransferFamily = family;
        groups(i).sourceCol = donorCol;
        groups(i).durationSec = durations.durationSeconds(donorCol);
        groups(i).sourceDurationSec = groups(i).durationSec;
        groups(i).sourceDurationFraction = durations.durationFractions(donorCol);
        groups(i).participants = [string(pair.donor_bed(1)); string(pair.receiver_bed(1))];
        groups(i).primaryBed = string(pair.donor_bed(1));
        groups(i).donorBed = string(pair.donor_bed(1));
        groups(i).receiverBed = string(pair.receiver_bed(1));
        groups(i).receiverSourceCol = receiverCol;
        groups(i).receiverDurationSec = durations.durationSeconds(receiverCol);
        groups(i).pairId = string(pair.pair_id(1));
        groups(i).localMap = localMap;
        groups(i).nativeStepSpec = nativeStepSpec;
        groups(i).adapterFamily = adapterFamilyForGroup(family);
        groups(i).ledgerHints = ledgerHintsForFamily(family);
        groups(i).notes = "paired group duration uses donor_source_col policy";
        groups(i).warnings = warnings;
    end
end

function [sortedGroups, perBedSequences, planWarnings] = topologicalSortGroups(groups, manifest, pairMap)
    nGroups = numel(groups);
    recordToNode = containers.Map('KeyType', 'char', 'ValueType', 'double');
    for i = 1:nGroups
        localMap = groups(i).localMap;
        for j = 1:height(localMap)
            recordToNode(char(string(localMap.record_id(j)))) = i;
        end
    end

    edges = false(nGroups, nGroups);
    perBedSequences = struct();
    bedLabels = string(manifest.bedLabels(:));
    for b = 1:numel(bedLabels)
        bed = bedLabels(b);
        rows = sortrows(manifest.bedSteps(manifest.bedSteps.bed == bed, :), "bed_step_index");
        labels = string(rows.yang_label);
        nodeIds = zeros(height(rows), 1);
        operationGroupIds = strings(height(rows), 1);
        for r = 1:height(rows)
            key = char(string(rows.record_id(r)));
            if ~isKey(recordToNode, key)
                error('FI6:OperationPlanMissingRecord', ...
                    'No operation group maps manifest record %s.', key);
            end
            nodeIds(r) = recordToNode(key);
            operationGroupIds(r) = groups(nodeIds(r)).operationGroupId;
        end
        for r = 1:(numel(nodeIds)-1)
            if nodeIds(r) ~= nodeIds(r+1)
                edges(nodeIds(r), nodeIds(r+1)) = true;
            end
        end
        perBedSequences.(char(bed)) = table( ...
            rows.bed_step_index, rows.source_col, labels, nodeIds, operationGroupIds, ...
            'VariableNames', ["bed_step_index", "source_col", "yang_label", ...
            "operation_group_index", "operation_group_id"]);
    end

    order = topoOrder(groups, edges);
    sortedGroups = groups(order);
    for i = 1:numel(sortedGroups)
        sortedGroups(i).operationGroupIndex = i;
        sortedGroups(i).topologicalOrder = i;
    end

    oldToNew = zeros(nGroups, 1);
    oldToNew(order) = 1:nGroups;
    for b = 1:numel(bedLabels)
        bed = bedLabels(b);
        seq = perBedSequences.(char(bed));
        seq.operation_group_index = oldToNew(seq.operation_group_index);
        for r = 1:height(seq)
            seq.operation_group_id(r) = sortedGroups(seq.operation_group_index(r)).operationGroupId;
        end
        perBedSequences.(char(bed)) = seq;
    end

    planWarnings = strings(0, 1);
    for i = 1:numel(sortedGroups)
        planWarnings = [planWarnings; sortedGroups(i).warnings(:)]; %#ok<AGROW>
    end

    expectedPairs = string(pairMap.transferPairs.pair_id);
    actualPairs = string({groups(~strcmp({groups.pairId}, "none")).pairId});
    missingPairs = setdiff(expectedPairs, actualPairs);
    if ~isempty(missingPairs)
        error('FI6:OperationPlanMissingPair', ...
            'Operation plan missed pair-map rows: %s.', char(strjoin(missingPairs, ", ")));
    end
end

function order = topoOrder(groups, edges)
    nGroups = numel(groups);
    indegree = sum(edges, 1).';
    order = zeros(nGroups, 1);
    used = false(nGroups, 1);
    rank = makeSortRank(groups);
    for pos = 1:nGroups
        candidates = find(indegree == 0 & ~used);
        if isempty(candidates)
            error('FI6:OperationPlanCycle', ...
                'Unable to build a per-bed topological Yang operation plan.');
        end
        [~, localIdx] = sortrows(rank(candidates, :));
        node = candidates(localIdx(1));
        order(pos) = node;
        used(node) = true;
        successors = find(edges(node, :));
        indegree(successors) = indegree(successors) - 1;
    end
end

function rank = makeSortRank(groups)
    nGroups = numel(groups);
    rank = zeros(nGroups, 4);
    for i = 1:nGroups
        rank(i, 1) = groups(i).sourceCol;
        rank(i, 2) = familyRank(groups(i).operationFamily);
        rank(i, 3) = bedRank(groups(i).primaryBed);
        rank(i, 4) = i;
    end
end

function r = familyRank(family)
    families = ["AD", "ADPP_BF", "EQI", "PP_PU", "EQII", "BD"];
    r = find(families == string(family), 1);
    if isempty(r)
        r = 99;
    end
end

function r = bedRank(bed)
    beds = ["A", "B", "C", "D", "none"];
    r = find(beds == string(bed), 1);
    if isempty(r)
        r = 99;
    end
end

function localMap = makeSingleLocalMap(row)
    localMap = table( ...
        1, ...
        string(row.role_class(1)), ...
        string(row.bed(1)), ...
        "state_" + string(row.bed(1)), ...
        string(row.yang_label(1)), ...
        string(row.record_id(1)), ...
        row.source_col(1), ...
        string(row.p_start_class(1)), ...
        string(row.p_end_class(1)), ...
        "none", ...
        "none", ...
        "none", ...
        string(row.internal_transfer_category(1)), ...
        'VariableNames', localMapVars());
end

function localMap = makePairLocalMap(pair)
    localMap = table( ...
        [1; 2], ...
        ["donor"; "receiver"], ...
        [string(pair.donor_bed(1)); string(pair.receiver_bed(1))], ...
        ["state_" + string(pair.donor_bed(1)); "state_" + string(pair.receiver_bed(1))], ...
        [string(pair.donor_yang_label(1)); string(pair.receiver_yang_label(1))], ...
        [string(pair.donor_record_id(1)); string(pair.receiver_record_id(1))], ...
        [pair.donor_source_col(1); pair.receiver_source_col(1)], ...
        [string(pair.donor_p_start_class(1)); string(pair.receiver_p_start_class(1))], ...
        [string(pair.donor_p_end_class(1)); string(pair.receiver_p_end_class(1))], ...
        ["none"; string(pair.receiver_inlet_endpoint(1))], ...
        [string(pair.donor_outlet_endpoint(1)); "none"], ...
        ["none"; string(pair.receiver_waste_endpoint(1))], ...
        repmat(string(pair.transfer_accounting_category(1)), 2, 1), ...
        'VariableNames', localMapVars());
end

function vars = localMapVars()
    vars = [
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
end

function selection = makeSyntheticSelection(selectionType, pairId, family, localMap)
    selection = struct();
    selection.version = "FI6-Yang2009-operation-plan-synthetic-selection-v1";
    selection.selectionType = string(selectionType);
    selection.pairId = string(pairId);
    selection.directTransferFamily = string(family);
    selection.localStates = repmat({[]}, height(localMap), 1);
    selection.localMap = localMap;
end

function family = adapterFamilyForGroup(operationFamily)
    if ismember(string(operationFamily), ["PP_PU", "ADPP_BF"])
        family = string(operationFamily);
    else
        family = "none";
    end
end

function hints = ledgerHintsForFamily(family)
    switch string(family)
        case "AD"
            hints = ["external_feed"; "external_product"; "bed_inventory_delta"];
        case "BD"
            hints = ["external_waste"; "bed_inventory_delta"];
        case {"EQI", "EQII"}
            hints = ["internal_transfer"; "bed_inventory_delta"];
        case "PP_PU"
            hints = ["internal_transfer"; "external_waste"; "bed_inventory_delta"];
        case "ADPP_BF"
            hints = ["external_feed"; "external_product"; ...
                "internal_transfer"; "bed_inventory_delta"];
        otherwise
            hints = strings(0, 1);
    end
end

function group = emptyGroup()
    group = struct();
    group.operationGroupIndex = NaN;
    group.topologicalOrder = NaN;
    group.operationGroupId = "";
    group.operationFamily = "";
    group.route = "";
    group.stageLabel = "";
    group.directTransferFamily = "";
    group.sourceCol = NaN;
    group.durationSec = NaN;
    group.sourceDurationSec = NaN;
    group.sourceDurationFraction = NaN;
    group.participants = strings(0, 1);
    group.primaryBed = "";
    group.donorBed = "";
    group.receiverBed = "";
    group.receiverSourceCol = NaN;
    group.receiverDurationSec = NaN;
    group.pairId = "";
    group.localMap = table();
    group.nativeStepSpec = struct();
    group.adapterFamily = "";
    group.ledgerHints = strings(0, 1);
    group.notes = "";
    group.warnings = strings(0, 1);
end
