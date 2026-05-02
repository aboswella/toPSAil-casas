function summary = summarizeYangFourBedLedger(ledger, varargin)
%SUMMARIZEYANGFOURBEDLEDGER Aggregate ledger stream rows by category.

    result = validateYangFourBedLedger(ledger);
    if ~result.pass
        error('WP5:InvalidLedger', ...
            'Cannot summarize invalid ledger: %s', char(strjoin(result.failures, " | ")));
    end

    parser = inputParser;
    addParameter(parser, 'CycleIndex', []);
    addParameter(parser, 'SlotIndex', []);
    parse(parser, varargin{:});
    opts = parser.Results;

    rows = filterRows(ledger.streamRows, opts.CycleIndex, opts.SlotIndex);
    totals = makeEmptyTotals();
    if height(rows) > 0
        keyVars = ["stream_scope", "stage_label", "direct_transfer_family", "component"];
        keys = unique(rows(:, keyVars), 'rows');
        for i = 1:height(keys)
            mask = rows.stream_scope == keys.stream_scope(i) & ...
                rows.stage_label == keys.stage_label(i) & ...
                rows.direct_transfer_family == keys.direct_transfer_family(i) & ...
                rows.component == keys.component(i);
            totals = [totals; table( ... %#ok<AGROW>
                string(keys.stream_scope(i)), ...
                string(keys.stage_label(i)), ...
                string(keys.direct_transfer_family(i)), ...
                string(keys.component(i)), ...
                sum(rows.moles(mask)), ...
                'VariableNames', totals.Properties.VariableNames)];
        end
    end

    summary = struct();
    summary.version = "WP5-Yang2009-ledger-summary-v1";
    summary.streamTotals = totals;
    summary.nStreamRows = height(rows);
    summary.externalProductMoles = sum(rows.moles(rows.stream_scope == "external_product"));
    summary.internalTransferMoles = sum(rows.moles(rows.stream_scope == "internal_transfer"));
    summary.internalTransfersExcludedFromProduct = true;
end

function rows = filterRows(rows, cycleIndex, slotIndex)
    if ~isempty(cycleIndex)
        rows = rows(rows.cycle_index == cycleIndex, :);
    end
    if ~isempty(slotIndex)
        rows = rows(rows.slot_index == slotIndex, :);
    end
end

function totals = makeEmptyTotals()
    totals = table( ...
        strings(0, 1), ...
        strings(0, 1), ...
        strings(0, 1), ...
        strings(0, 1), ...
        zeros(0, 1), ...
        'VariableNames', [
            "stream_scope"
            "stage_label"
            "direct_transfer_family"
            "component"
            "moles"
        ]);
end
