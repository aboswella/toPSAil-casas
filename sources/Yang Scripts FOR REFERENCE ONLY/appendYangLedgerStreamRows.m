function ledger = appendYangLedgerStreamRows(ledger, componentNames, moles, varargin)
%APPENDYANGLEDGERSTREAMROWS Append one component vector as ledger rows.

    componentNames = string(componentNames(:));
    if numel(componentNames) ~= numel(ledger.componentNames) || ...
            any(componentNames ~= string(ledger.componentNames(:)))
        error('WP5:ComponentNameMismatch', ...
            'componentNames must match ledger.componentNames exactly.');
    end

    if ~isnumeric(moles) || ~isvector(moles) || numel(moles) ~= numel(componentNames)
        error('WP5:InvalidMolesVector', ...
            'moles must be a numeric vector with one value per component.');
    end
    moles = moles(:);

    parser = inputParser;
    addParameter(parser, 'CycleIndex', NaN);
    addParameter(parser, 'SlotIndex', NaN);
    addParameter(parser, 'OperationGroupId', "not_supplied");
    addParameter(parser, 'SourceCol', NaN);
    addParameter(parser, 'RecordId', "not_supplied");
    addParameter(parser, 'PairId', "none");
    addParameter(parser, 'StageLabel', "not_supplied");
    addParameter(parser, 'DirectTransferFamily', "none");
    addParameter(parser, 'YangLabel', "not_supplied");
    addParameter(parser, 'GlobalBed', "none");
    addParameter(parser, 'LocalIndex', NaN);
    addParameter(parser, 'LocalRole', "not_supplied");
    addParameter(parser, 'StreamScope', "");
    addParameter(parser, 'StreamDirection', "");
    addParameter(parser, 'Endpoint', "not_applicable");
    addParameter(parser, 'Basis', "caller_supplied");
    addParameter(parser, 'Units', "mol");
    addParameter(parser, 'Notes', "");
    addParameter(parser, 'AllowSignedMoles', false);
    parse(parser, varargin{:});
    opts = parser.Results;

    streamScope = string(opts.StreamScope);
    streamDirection = string(opts.StreamDirection);
    allowedScopes = [
        "external_feed"
        "external_product"
        "external_waste"
        "internal_transfer"
        "bed_inventory_delta"
    ];
    allowedDirections = [
        "in"
        "out"
        "out_of_donor"
        "into_receiver"
        "delta"
    ];
    if ~ismember(streamScope, allowedScopes)
        error('WP5:InvalidStreamScope', ...
            'Unsupported stream scope %s.', char(streamScope));
    end
    if ~ismember(streamDirection, allowedDirections)
        error('WP5:InvalidStreamDirection', ...
            'Unsupported stream direction %s.', char(streamDirection));
    end
    if ~all(isfinite(moles))
        error('WP5:InvalidMolesVector', ...
            'moles must be finite for ledger stream rows.');
    end
    if streamScope ~= "bed_inventory_delta" && ~logical(opts.AllowSignedMoles) && any(moles < 0)
        error('WP5:NegativeStreamMoles', ...
            'Only bed_inventory_delta rows or explicitly signed rows may contain negative moles.');
    end

    nRows = numel(componentNames);
    newRows = table( ...
        repmat(double(opts.CycleIndex), nRows, 1), ...
        repmat(double(opts.SlotIndex), nRows, 1), ...
        repmat(string(opts.OperationGroupId), nRows, 1), ...
        repmat(double(opts.SourceCol), nRows, 1), ...
        repmat(string(opts.RecordId), nRows, 1), ...
        repmat(string(opts.PairId), nRows, 1), ...
        repmat(string(opts.StageLabel), nRows, 1), ...
        repmat(string(opts.DirectTransferFamily), nRows, 1), ...
        repmat(string(opts.YangLabel), nRows, 1), ...
        repmat(string(opts.GlobalBed), nRows, 1), ...
        repmat(double(opts.LocalIndex), nRows, 1), ...
        repmat(string(opts.LocalRole), nRows, 1), ...
        repmat(streamScope, nRows, 1), ...
        repmat(streamDirection, nRows, 1), ...
        repmat(string(opts.Endpoint), nRows, 1), ...
        componentNames(:), ...
        moles, ...
        repmat(string(opts.Basis), nRows, 1), ...
        repmat(string(opts.Units), nRows, 1), ...
        repmat(string(opts.Notes), nRows, 1), ...
        'VariableNames', ledger.streamRows.Properties.VariableNames);

    ledger.streamRows = [ledger.streamRows; newRows];
    result = validateYangFourBedLedger(ledger);
    if ~result.pass
        error('WP5:InvalidLedgerAfterAppend', ...
            'Ledger failed validation after stream-row append: %s', ...
            char(strjoin(result.failures, " | ")));
    end
end
