function metrics = computeYangPerformanceMetrics(ledger, varargin)
%COMPUTEYANGPERFORMANCEMETRICS Reconstruct Yang-basis external metrics.

    result = validateYangFourBedLedger(ledger);
    if ~result.pass
        error('WP5:InvalidLedger', ...
            'Cannot compute metrics for invalid ledger: %s', char(strjoin(result.failures, " | ")));
    end

    componentNames = string(ledger.componentNames(:));
    defaultTarget = componentNames(1);
    h2Match = componentNames(componentNames == "H2");
    if ~isempty(h2Match)
        defaultTarget = h2Match(1);
    end

    parser = inputParser;
    addParameter(parser, 'TargetProductComponent', defaultTarget);
    addParameter(parser, 'CycleIndex', []);
    parse(parser, varargin{:});
    opts = parser.Results;

    targetComponent = string(opts.TargetProductComponent);
    if ~ismember(targetComponent, componentNames)
        error('WP5:UnknownMetricComponent', ...
            'TargetProductComponent %s is not in ledger.componentNames.', char(targetComponent));
    end

    rows = ledger.streamRows;
    if ~isempty(opts.CycleIndex)
        cycles = double(opts.CycleIndex(:));
    elseif height(rows) == 0
        cycles = zeros(0, 1);
    else
        cycles = unique(rows.cycle_index);
    end

    metricRows = ledger.metricRows([],:);
    for i = 1:numel(cycles)
        cycleIndex = cycles(i);
        cycleRows = rows(rows.cycle_index == cycleIndex, :);
        productRows = cycleRows(cycleRows.stream_scope == "external_product", :);
        feedRows = cycleRows(cycleRows.stream_scope == "external_feed", :);

        targetProduct = sum(productRows.moles(productRows.component == targetComponent));
        totalProduct = sum(productRows.moles);
        targetFeed = sum(feedRows.moles(feedRows.component == targetComponent));

        [purity, purityPass, purityNote] = safeRatio(targetProduct, totalProduct, ...
            "product purity denominator is total external_product moles");
        metricRows = appendMetricRow(metricRows, cycleIndex, "product_purity", targetComponent, ...
            purity, targetProduct, totalProduct, purityPass, purityNote);

        [recovery, recoveryPass, recoveryNote] = safeRatio(targetProduct, targetFeed, ...
            "product recovery denominator is target-component external_feed moles");
        metricRows = appendMetricRow(metricRows, cycleIndex, "product_recovery", targetComponent, ...
            recovery, targetProduct, targetFeed, recoveryPass, recoveryNote);
    end

    metrics = struct();
    metrics.version = "WP5-Yang2009-external-ledger-metrics-v1";
    metrics.targetProductComponent = targetComponent;
    metrics.basis = "external_ledger_only_internal_transfers_excluded";
    metrics.rows = metricRows;
    metrics.internalTransfersExcluded = true;
end

function [value, pass, note] = safeRatio(numerator, denominator, note)
    if denominator == 0
        value = NaN;
        pass = false;
        note = string(note) + "; denominator is zero so value is NaN";
    else
        value = numerator / denominator;
        pass = isfinite(value);
        note = string(note) + "; internal_transfer rows excluded";
    end
end

function metricRows = appendMetricRow(metricRows, cycleIndex, metricName, component, ...
        value, numerator, denominator, pass, notes)
    row = table( ...
        double(cycleIndex), ...
        string(metricName), ...
        string(component), ...
        double(value), ...
        double(numerator), ...
        double(denominator), ...
        "external_ledger_only_internal_transfers_excluded", ...
        logical(pass), ...
        string(notes), ...
        'VariableNames', metricRows.Properties.VariableNames);
    metricRows = [metricRows; row];
end
