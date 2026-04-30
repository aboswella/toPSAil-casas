function [balanceRows, summary] = computeYangLedgerBalances(ledger, varargin)
%COMPUTEYANGLEDGERBALANCES Compute WP5 external and internal balances.

    result = validateYangFourBedLedger(ledger);
    if ~result.pass
        error('WP5:InvalidLedger', ...
            'Cannot compute balances for invalid ledger: %s', char(strjoin(result.failures, " | ")));
    end

    parser = inputParser;
    addParameter(parser, 'CycleIndex', []);
    addParameter(parser, 'SlotIndex', []);
    addParameter(parser, 'AbsTol', 1e-9);
    addParameter(parser, 'RelTol', 1e-9);
    parse(parser, varargin{:});
    opts = parser.Results;

    rows = filterRows(ledger.streamRows, opts.CycleIndex, opts.SlotIndex);
    balanceRows = ledger.balanceRows([],:);
    componentNames = string(ledger.componentNames(:));

    if height(rows) > 0
        balanceRows = appendSlotExternalBalances(balanceRows, rows, componentNames, opts);
        balanceRows = appendCycleExternalBalances(balanceRows, rows, componentNames, opts);
        balanceRows = appendInternalTransferBalances(balanceRows, rows, componentNames, opts);
    end

    summary = struct();
    summary.version = "WP5-Yang2009-ledger-balance-summary-v1";
    summary.pass = all(balanceRows.pass);
    summary.nBalanceRows = height(balanceRows);
    if height(balanceRows) == 0
        summary.maxAbsResidual = 0;
    else
        summary.maxAbsResidual = max(abs(balanceRows.residual_moles));
    end
    summary.basis = "external_feed_minus_product_minus_waste_minus_bed_delta_and_internal_transfer_cancellation";
end

function rows = filterRows(rows, cycleIndex, slotIndex)
    if ~isempty(cycleIndex)
        rows = rows(rows.cycle_index == cycleIndex, :);
    end
    if ~isempty(slotIndex)
        rows = rows(rows.slot_index == slotIndex, :);
    end
end

function balanceRows = appendSlotExternalBalances(balanceRows, rows, componentNames, opts)
    keyVars = ["cycle_index", "slot_index", "operation_group_id", "stage_label", "direct_transfer_family"];
    keys = unique(rows(:, keyVars), 'rows');
    for k = 1:height(keys)
        keyMask = rows.cycle_index == keys.cycle_index(k) & ...
            rows.slot_index == keys.slot_index(k) & ...
            rows.operation_group_id == keys.operation_group_id(k) & ...
            rows.stage_label == keys.stage_label(k) & ...
            rows.direct_transfer_family == keys.direct_transfer_family(k);
        for c = 1:numel(componentNames)
            component = componentNames(c);
            compMask = keyMask & rows.component == component;
            feed = sumScope(rows, compMask, "external_feed");
            product = sumScope(rows, compMask, "external_product");
            waste = sumScope(rows, compMask, "external_waste");
            delta = sumScope(rows, compMask, "bed_inventory_delta");
            residual = feed - product - waste - delta;
            tol = residualTolerance([feed, product, waste, delta], opts.AbsTol, opts.RelTol);
            balanceRows = appendBalanceRow(balanceRows, ...
                keys.cycle_index(k), keys.slot_index(k), "slot_external", ...
                keys.operation_group_id(k), keys.stage_label(k), keys.direct_transfer_family(k), ...
                component, feed, product, waste, delta, 0, 0, residual, tol, ...
                "external_feed-product-waste-bed_inventory_delta", ...
                "Slot-level external balance by component.");
        end
    end
end

function balanceRows = appendCycleExternalBalances(balanceRows, rows, componentNames, opts)
    cycles = unique(rows.cycle_index);
    for k = 1:numel(cycles)
        cycleIndex = cycles(k);
        keyMask = rows.cycle_index == cycleIndex;
        for c = 1:numel(componentNames)
            component = componentNames(c);
            compMask = keyMask & rows.component == component;
            feed = sumScope(rows, compMask, "external_feed");
            product = sumScope(rows, compMask, "external_product");
            waste = sumScope(rows, compMask, "external_waste");
            delta = sumScope(rows, compMask, "bed_inventory_delta");
            residual = feed - product - waste - delta;
            tol = residualTolerance([feed, product, waste, delta], opts.AbsTol, opts.RelTol);
            balanceRows = appendBalanceRow(balanceRows, ...
                cycleIndex, NaN, "cycle_external", ...
                "cycle_total", "all", "all", ...
                component, feed, product, waste, delta, 0, 0, residual, tol, ...
                "cycle_external_feed-product-waste-bed_inventory_delta", ...
                "Cycle-level external balance by component.");
        end
    end
end

function balanceRows = appendInternalTransferBalances(balanceRows, rows, componentNames, opts)
    internalRows = rows(rows.stream_scope == "internal_transfer", :);
    if height(internalRows) == 0
        return;
    end

    keyVars = ["cycle_index", "slot_index", "operation_group_id", "stage_label", "direct_transfer_family"];
    keys = unique(internalRows(:, keyVars), 'rows');
    for k = 1:height(keys)
        keyMask = internalRows.cycle_index == keys.cycle_index(k) & ...
            internalRows.slot_index == keys.slot_index(k) & ...
            internalRows.operation_group_id == keys.operation_group_id(k) & ...
            internalRows.stage_label == keys.stage_label(k) & ...
            internalRows.direct_transfer_family == keys.direct_transfer_family(k);
        for c = 1:numel(componentNames)
            component = componentNames(c);
            compMask = keyMask & internalRows.component == component;
            out = sumDirection(internalRows, compMask, "out_of_donor");
            into = sumDirection(internalRows, compMask, "into_receiver");
            residual = into - out;
            tol = residualTolerance([out, into], opts.AbsTol, opts.RelTol);
            balanceRows = appendBalanceRow(balanceRows, ...
                keys.cycle_index(k), keys.slot_index(k), "slot_internal_transfer", ...
                keys.operation_group_id(k), keys.stage_label(k), keys.direct_transfer_family(k), ...
                component, 0, 0, 0, 0, out, into, residual, tol, ...
                "internal_into_receiver_minus_internal_out_of_donor", ...
                "Slot-level internal transfer cancellation by component.");
        end
    end
end

function value = sumScope(rows, mask, scope)
    value = sum(rows.moles(mask & rows.stream_scope == scope));
end

function value = sumDirection(rows, mask, direction)
    value = sum(rows.moles(mask & rows.stream_direction == direction));
end

function tol = residualTolerance(values, absTol, relTol)
    scale = max(abs(values));
    if isempty(scale) || ~isfinite(scale)
        scale = 0;
    end
    tol = absTol + relTol * scale;
end

function balanceRows = appendBalanceRow(balanceRows, cycleIndex, slotIndex, balanceScope, ...
        operationGroupId, stageLabel, directTransferFamily, component, feed, product, waste, ...
        delta, internalOut, internalInto, residual, tol, basis, notes)
    pass = abs(residual) <= tol;
    row = table( ...
        double(cycleIndex), ...
        double(slotIndex), ...
        string(balanceScope), ...
        string(operationGroupId), ...
        string(stageLabel), ...
        string(directTransferFamily), ...
        string(component), ...
        double(feed), ...
        double(product), ...
        double(waste), ...
        double(delta), ...
        double(internalOut), ...
        double(internalInto), ...
        double(residual), ...
        double(tol), ...
        logical(pass), ...
        string(basis), ...
        string(notes), ...
        'VariableNames', balanceRows.Properties.VariableNames);
    balanceRows = [balanceRows; row];
end
