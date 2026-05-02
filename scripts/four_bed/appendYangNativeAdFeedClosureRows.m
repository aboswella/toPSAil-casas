function [rowsOut, closureReport] = appendYangNativeAdFeedClosureRows(rowsIn, group, controls, varargin)
%APPENDYANGNATIVEADFEEDCLOSUREROWS Reconstruct missing native AD feed rows.
%
% Native HP-FEE-RAF column counter tails can expose product-side outflow while
% leaving feed-side input near zero. For wrapper physical-mole ledger closure,
% add only the positive external-feed amount required by the AD slot balance.

    if nargin < 3 || isempty(controls)
        controls = struct();
    end

    parser = inputParser;
    addParameter(parser, 'CycleIndex', getGroupField(group, 'cycleIndex', NaN));
    addParameter(parser, 'ComponentNames', getControlField(controls, ...
        'componentNames', ["H2"; "CO2"]));
    addParameter(parser, 'AbsTol', getControlField(controls, 'balanceAbsTol', 1e-8));
    addParameter(parser, 'RelTol', getControlField(controls, 'balanceRelTol', 1e-6));
    parse(parser, varargin{:});
    opts = parser.Results;

    rowsOut = rowsIn;
    componentNames = string(opts.ComponentNames(:));
    closureReport = struct();
    closureReport.version = "FI7-Yang2009-native-AD-feed-closure-v1";
    closureReport.applied = false;
    closureReport.nRowsAppended = 0;
    closureReport.basis = "physical_moles_reconstructed_from_ad_slot_balance";
    closureReport.units = "mol";
    closureReport.operationGroupId = string(getGroupField(group, ...
        'operationGroupId', "not_supplied"));
    closureReport.stageLabel = string(getGroupField(group, 'stageLabel', ""));
    closureReport.requiredAdditionalFeedByComponent = zeros(numel(componentNames), 1);
    closureReport.toleranceByComponent = zeros(numel(componentNames), 1);
    closureReport.notes = "No native AD feed closure row required.";

    if ~istable(rowsIn) || ~all(ismember(["stream_scope", "component", "moles"], ...
            string(rowsIn.Properties.VariableNames)))
        error('FI7:InvalidNativeAdClosureRows', ...
            'rowsIn must be a ledger stream-row table.');
    end
    if height(rowsIn) == 0 || string(getGroupField(group, 'operationFamily', "")) ~= "AD"
        return;
    end

    missingFeed = zeros(numel(componentNames), 1);
    tolerances = zeros(numel(componentNames), 1);
    for c = 1:numel(componentNames)
        component = componentNames(c);
        compMask = rowsIn.component == component;
        feed = sumScope(rowsIn, compMask, "external_feed");
        product = sumScope(rowsIn, compMask, "external_product");
        waste = sumScope(rowsIn, compMask, "external_waste");
        delta = sumScope(rowsIn, compMask, "bed_inventory_delta");
        missingFeed(c) = product + waste + delta - feed;
        tolerances(c) = residualTolerance([feed, product, waste, delta], ...
            opts.AbsTol, opts.RelTol);
    end

    closureReport.requiredAdditionalFeedByComponent = missingFeed;
    closureReport.toleranceByComponent = tolerances;

    if any(missingFeed < -tolerances)
        error('FI7:NativeAdFeedClosureNegative', ...
            ['Native AD ledger rows for %s already exceed the feed required ', ...
            'by product/waste/inventory closure. Refusing to append negative feed.'], ...
            char(closureReport.operationGroupId));
    end

    appendMask = missingFeed > tolerances;
    if ~any(appendMask)
        return;
    end

    amounts = zeros(numel(componentNames), 1);
    amounts(appendMask) = missingFeed(appendMask);

    tmpLedger = makeYangFourBedLedger(componentNames, ...
        'LedgerNote', "FI-7 native AD feed closure temporary ledger");
    localMap = group.localMap;
    tmpLedger = appendYangLedgerStreamRows(tmpLedger, componentNames, amounts, ...
        'CycleIndex', opts.CycleIndex, ...
        'SlotIndex', group.sourceCol, ...
        'OperationGroupId', string(group.operationGroupId), ...
        'SourceCol', group.sourceCol, ...
        'RecordId', string(localMap.record_id(1)), ...
        'PairId', string(group.pairId), ...
        'StageLabel', string(group.stageLabel), ...
        'DirectTransferFamily', string(group.directTransferFamily), ...
        'YangLabel', string(localMap.yang_label(1)), ...
        'GlobalBed', string(localMap.global_bed(1)), ...
        'LocalIndex', localMap.local_index(1), ...
        'LocalRole', string(localMap.local_role(1)), ...
        'StreamScope', "external_feed", ...
        'StreamDirection', "in", ...
        'Endpoint', "feed_end", ...
        'Basis', closureReport.basis, ...
        'Units', closureReport.units, ...
        'Notes', "Native AD feed input reconstructed as product + waste + bed_inventory_delta - existing_feed.");
    closureRows = tmpLedger.streamRows(tmpLedger.streamRows.moles > 0, :);

    rowsOut = [rowsIn; closureRows];
    closureReport.applied = true;
    closureReport.nRowsAppended = height(closureRows);
    closureReport.notes = "Appended positive external-feed closure rows for native AD physical-mole accounting.";
end

function value = sumScope(rows, mask, scope)
    value = sum(rows.moles(mask & rows.stream_scope == scope));
end

function tol = residualTolerance(values, absTol, relTol)
    scale = max(abs(values));
    if isempty(scale) || ~isfinite(scale)
        scale = 0;
    end
    tol = absTol + relTol * scale;
end

function value = getControlField(s, name, defaultValue)
    value = defaultValue;
    if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
        value = s.(name);
    end
end

function value = getGroupField(s, name, defaultValue)
    value = defaultValue;
    if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
        value = s.(name);
    end
end
