function [rows, nativeLedgerReport] = extractYangNativeLedgerRows(nativeReport, group, templateParams, controls, varargin)
%EXTRACTYANGNATIVELEDGERROWS Convert native counter tails to ledger rows.

    if nargin < 3 || ~isstruct(templateParams)
        error('FI7:InvalidTemplateParams', ...
            'templateParams is required for native counter-tail extraction.');
    end
    if nargin < 4 || isempty(controls)
        controls = normalizeYangFourBedControls(struct(), templateParams);
    end

    parser = inputParser;
    addParameter(parser, 'CycleIndex', NaN);
    addParameter(parser, 'OperationGroupId', getGroupField(group, 'operationGroupId', "not_supplied"));
    addParameter(parser, 'ComponentNames', getFieldOrDefault(controls, 'componentNames', ["H2"; "CO2"]));
    addParameter(parser, 'CounterSignPolicy', "signed_native_boundary_convention");
    parse(parser, varargin{:});
    opts = parser.Results;

    validateCounterParams(templateParams);
    componentNames = string(opts.ComponentNames(:));
    family = string(group.operationFamily);
    localMap = group.localMap;
    nLocal = height(localMap);
    counterDeltas = resolveCounterDeltas(nativeReport, templateParams, nLocal);

    tmpLedger = makeYangFourBedLedger(componentNames, 'LedgerNote', "FI-7 native extraction temporary ledger");
    common = {'CycleIndex', opts.CycleIndex, ...
        'SlotIndex', group.sourceCol, ...
        'OperationGroupId', string(opts.OperationGroupId), ...
        'SourceCol', group.sourceCol, ...
        'PairId', string(group.pairId), ...
        'StageLabel', string(group.stageLabel), ...
        'DirectTransferFamily', string(group.directTransferFamily), ...
        'Basis', "native_counter_tail_delta", ...
        'Units', "native_integrated_units", ...
        'Notes', "FI-7 native ledger extraction from signed column counter tails"};

    switch family
        case "AD"
            [feedTail, productTail] = splitCounterTail(templateParams, counterDeltas{1});
            feedTail = counterAmount(feedTail, -1, "AD feed-end counter", opts.CounterSignPolicy);
            productTail = counterAmount(productTail, -1, "AD product-end counter", opts.CounterSignPolicy);
            tmpLedger = appendNativeLocalRows(tmpLedger, componentNames, feedTail, ...
                common, localMap, 1, "external_feed", "in", "feed_end");
            tmpLedger = appendNativeLocalRows(tmpLedger, componentNames, productTail, ...
                common, localMap, 1, "external_product", "out", "product_end");

        case "BD"
            [feedTail, ~] = splitCounterTail(templateParams, counterDeltas{1});
            feedTail = counterAmount(feedTail, 1, "BD feed-end waste counter", opts.CounterSignPolicy);
            tmpLedger = appendNativeLocalRows(tmpLedger, componentNames, feedTail, ...
                common, localMap, 1, "external_waste", "out", "feed_end");

        case {"EQI", "EQII"}
            if nLocal ~= 2
                error('FI7:InvalidNativeLocalMap', ...
                    '%s native pair extraction requires two local beds.', char(family));
            end
            [~, donorProduct] = splitCounterTail(templateParams, counterDeltas{1});
            [~, receiverProduct] = splitCounterTail(templateParams, counterDeltas{2});
            donorProduct = counterAmount(donorProduct, -1, ...
                family + " donor product-end counter", opts.CounterSignPolicy);
            receiverProduct = counterAmount(receiverProduct, 1, ...
                family + " receiver product-end counter", opts.CounterSignPolicy);
            tmpLedger = appendNativeLocalRows(tmpLedger, componentNames, donorProduct, ...
                common, localMap, 1, "internal_transfer", "out_of_donor", "product_end");
            tmpLedger = appendNativeLocalRows(tmpLedger, componentNames, receiverProduct, ...
                common, localMap, 2, "internal_transfer", "into_receiver", "product_end");

        otherwise
            error('FI7:UnsupportedNativeFamily', ...
                'Operation family %s is not a native ledger extraction family.', char(family));
    end

    rows = tmpLedger.streamRows;
    nativeLedgerReport = struct();
    nativeLedgerReport.version = "FI7-Yang2009-native-ledger-extraction-v1";
    nativeLedgerReport.operationFamily = family;
    nativeLedgerReport.counterTailLayout = ...
        "first_nComs_feed_end_second_nComs_product_end_from_getRhsFuncVals";
    nativeLedgerReport.counterSignPolicy = string(opts.CounterSignPolicy);
    nativeLedgerReport.counterSignConvention = ...
        "feed counter positive out of feed end; product counter positive into product end; ledger amounts use absolute signed deltas by default";
    nativeLedgerReport.nRows = height(rows);
    nativeLedgerReport.basis = "native_counter_tail_delta";
end

function validateCounterParams(params)
    required = ["nColSt", "nColStT", "nComs"];
    if ~all(ismember(required, string(fieldnames(params))))
        error('FI7:InvalidTemplateParams', ...
            'templateParams must contain nColSt, nColStT, and nComs.');
    end
    expectedTail = 2 * params.nComs;
    actualTail = params.nColStT - params.nColSt;
    if actualTail ~= expectedTail
        error('FI7:UnexpectedCounterTailLength', ...
            'Native counter tail length is %d; expected 2*nComs = %d.', ...
            actualTail, expectedTail);
    end
end

function counterDeltas = resolveCounterDeltas(nativeReport, params, nLocal)
    if isstruct(nativeReport) && isfield(nativeReport, 'counterTailDeltas')
        counterDeltas = normalizeCounterCell(nativeReport.counterTailDeltas, nLocal);
        return;
    end

    if isstruct(nativeReport) && isfield(nativeReport, 'stStates') && ...
            isnumeric(nativeReport.stStates) && size(nativeReport.stStates, 1) >= 1
        stStates = nativeReport.stStates;
        if size(stStates, 2) < nLocal * params.nColStT
            error('FI7:NativeCounterTailUnavailable', ...
                'nativeReport.stStates does not contain all local native state vectors.');
        end
        counterDeltas = cell(nLocal, 1);
        for i = 1:nLocal
            idx = ((i-1)*params.nColStT + params.nColSt + 1):(i*params.nColStT);
            counterDeltas{i} = stStates(end, idx).' - stStates(1, idx).';
        end
        return;
    end

    error('FI7:NativeCounterTailUnavailable', ...
        'Native report must expose counterTailDeltas or stStates for ledger extraction.');
end

function counterDeltas = normalizeCounterCell(value, nLocal)
    if iscell(value)
        counterDeltas = value(:);
    elseif isnumeric(value)
        if size(value, 1) == nLocal
            counterDeltas = cell(nLocal, 1);
            for i = 1:nLocal
                counterDeltas{i} = value(i, :).';
            end
        elseif size(value, 2) == nLocal
            counterDeltas = cell(nLocal, 1);
            for i = 1:nLocal
                counterDeltas{i} = value(:, i);
            end
        else
            error('FI7:NativeCounterTailUnavailable', ...
                'Numeric counterTailDeltas must have one row or column per local bed.');
        end
    else
        error('FI7:NativeCounterTailUnavailable', ...
            'counterTailDeltas must be a cell array or numeric matrix.');
    end

    if numel(counterDeltas) ~= nLocal
        error('FI7:NativeCounterTailUnavailable', ...
            'counterTailDeltas has %d entries; expected %d.', numel(counterDeltas), nLocal);
    end
end

function [feedTail, productTail] = splitCounterTail(params, tail)
    tail = tail(:);
    expected = 2 * params.nComs;
    if numel(tail) ~= expected
        error('FI7:UnexpectedCounterTailLength', ...
            'Counter tail has %d entries; expected %d.', numel(tail), expected);
    end
    feedTail = tail(1:params.nComs);
    productTail = tail(params.nComs+1:end);
end

function amount = counterAmount(values, expectedSign, label, policy)
    values = values(:);
    if string(policy) == "allow_signed"
        amount = abs(values);
        return;
    end
    if string(policy) == "signed_native_boundary_convention"
        amount = abs(values);
        return;
    end
    if any(values < -1e-12)
        error('FI7:NativeCounterSignMismatch', ...
            '%s contains negative counter deltas under nonnegative policy.', char(label));
    end
    amount = values;
end

function tmpLedger = appendNativeLocalRows(tmpLedger, componentNames, amounts, common, localMap, localIndex, scope, direction, endpoint)
    row = localMap(localMap.local_index == localIndex, :);
    if height(row) ~= 1
        error('FI7:InvalidNativeLocalMap', ...
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
