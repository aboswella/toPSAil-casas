function [rows, adapterLedgerReport] = extractYangAdapterLedgerRows(adapterReport, group, templateParams, controls, varargin)
%EXTRACTYANGADAPTERLEDGERROWS Convert adapter reports to wrapper ledger rows.

    if nargin < 3
        templateParams = struct();
    end
    if nargin < 4 || isempty(controls)
        controls = normalizeYangFourBedControls(struct(), templateParams);
    end

    parser = inputParser;
    addParameter(parser, 'CycleIndex', getReportField(adapterReport, 'cycleIndex', NaN));
    addParameter(parser, 'OperationGroupId', getGroupField(group, 'operationGroupId', "not_supplied"));
    addParameter(parser, 'ComponentNames', getFieldOrDefault(controls, 'componentNames', ["H2"; "CO2"]));
    parse(parser, varargin{:});
    opts = parser.Results;

    componentNames = string(opts.ComponentNames(:));
    family = string(getGroupField(group, 'operationFamily', ...
        getReportField(adapterReport, 'directTransferFamily', "")));
    localMap = group.localMap;

    switch family
        case "PP_PU"
            required = [
                "internalTransferOutByComponent"
                "internalTransferInByComponent"
                "externalWasteByComponent"
            ];
        case "ADPP_BF"
            required = [
                "externalFeedByComponent"
                "externalProductByComponent"
                "internalTransferOutByComponent"
                "internalTransferInByComponent"
            ];
        otherwise
            error('FI7:UnsupportedAdapterFamily', ...
                'Unsupported adapter family %s.', char(family));
    end

    flowBasis = chooseYangAdapterFlowBasis(adapterReport, 'RequiredFields', required);
    tmpLedger = makeYangFourBedLedger(componentNames, 'LedgerNote', "FI-7 adapter extraction temporary ledger");
    common = commonRowArgs(group, opts.CycleIndex, opts.OperationGroupId, flowBasis);

    switch family
        case "PP_PU"
            tmpLedger = appendLocalRows(tmpLedger, componentNames, ...
                flowBasis.values.internalTransferOutByComponent, common, localMap, 1, ...
                "internal_transfer", "out_of_donor", "product_end");
            tmpLedger = appendLocalRows(tmpLedger, componentNames, ...
                flowBasis.values.internalTransferInByComponent, common, localMap, 2, ...
                "internal_transfer", "into_receiver", "product_end");
            tmpLedger = appendLocalRows(tmpLedger, componentNames, ...
                flowBasis.values.externalWasteByComponent, common, localMap, 2, ...
                "external_waste", "out", "feed_end");

        case "ADPP_BF"
            tmpLedger = appendLocalRows(tmpLedger, componentNames, ...
                flowBasis.values.externalFeedByComponent, common, localMap, 1, ...
                "external_feed", "in", "feed_end");
            tmpLedger = appendLocalRows(tmpLedger, componentNames, ...
                flowBasis.values.externalProductByComponent, common, localMap, 1, ...
                "external_product", "out", "product_end");
            tmpLedger = appendLocalRows(tmpLedger, componentNames, ...
                flowBasis.values.internalTransferOutByComponent, common, localMap, 1, ...
                "internal_transfer", "out_of_donor", "product_end");
            tmpLedger = appendLocalRows(tmpLedger, componentNames, ...
                flowBasis.values.internalTransferInByComponent, common, localMap, 2, ...
                "internal_transfer", "into_receiver", "product_end");
            if isfield(flowBasis.values, 'externalWasteByComponent') && ...
                    any(abs(flowBasis.values.externalWasteByComponent(:)) > 0)
                tmpLedger = appendLocalRows(tmpLedger, componentNames, ...
                    flowBasis.values.externalWasteByComponent, common, localMap, 2, ...
                    "external_waste", "out", "feed_end");
            end
    end

    rows = tmpLedger.streamRows;
    adapterLedgerReport = struct();
    adapterLedgerReport.version = "FI7-Yang2009-adapter-ledger-extraction-v1";
    adapterLedgerReport.directTransferFamily = family;
    adapterLedgerReport.flowBasis = flowBasis;
    adapterLedgerReport.effectiveSplit = getReportField(adapterReport, ...
        'effectiveSplit', getNestedReportField(adapterReport, ["flowReport", "effectiveSplit"], struct()));
    adapterLedgerReport.nRows = height(rows);
    adapterLedgerReport.warnings = strings(0, 1);
    if strlength(string(flowBasis.warning)) > 0
        adapterLedgerReport.warnings(end+1, 1) = string(flowBasis.warning);
    end
end

function tmpLedger = appendLocalRows(tmpLedger, componentNames, amounts, common, localMap, localIndex, scope, direction, endpoint)
    row = localMap(localMap.local_index == localIndex, :);
    if height(row) ~= 1
        error('FI7:InvalidAdapterLocalMap', ...
            'Expected exactly one localMap row for local index %d.', localIndex);
    end
    tmpLedger = appendYangLedgerStreamRows(tmpLedger, componentNames, amounts(:), common{:}, ...
        'RecordId', string(row.record_id(1)), ...
        'YangLabel', string(row.yang_label(1)), ...
        'GlobalBed', string(row.global_bed(1)), ...
        'LocalIndex', row.local_index(1), ...
        'LocalRole', string(row.local_role(1)), ...
        'StreamScope', string(scope), ...
        'StreamDirection', string(direction), ...
        'Endpoint', string(endpoint));
end

function args = commonRowArgs(group, cycleIndex, operationGroupId, flowBasis)
    args = {'CycleIndex', cycleIndex, ...
        'SlotIndex', group.sourceCol, ...
        'OperationGroupId', string(operationGroupId), ...
        'SourceCol', group.sourceCol, ...
        'PairId', string(group.pairId), ...
        'StageLabel', string(group.stageLabel), ...
        'DirectTransferFamily', string(group.directTransferFamily), ...
        'Basis', string(flowBasis.basis), ...
        'Units', string(flowBasis.units), ...
        'Notes', "FI-7 adapter ledger extraction from " + string(flowBasis.sourceField)};
end

function value = getFieldOrDefault(s, name, defaultValue)
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

function value = getReportField(s, name, defaultValue)
    value = defaultValue;
    if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
        value = s.(name);
    end
end

function value = getNestedReportField(s, names, defaultValue)
    value = defaultValue;
    current = s;
    for i = 1:numel(names)
        name = char(names(i));
        if ~isstruct(current) || ~isfield(current, name)
            return;
        end
        current = current.(name);
    end
    value = current;
end
