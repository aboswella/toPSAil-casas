function container = makeYangFourBedStateContainer(initialStates, varargin)
%MAKEYANGFOURBEDSTATECONTAINER Create the WP3 persistent bed-state store.
%
% The bed payloads are intentionally opaque. WP3 stores, selects, and
% replaces them by named bed identity; it does not inspect physical state.

    stateFields = ["state_A", "state_B", "state_C", "state_D"];
    bedLabels = ["A", "B", "C", "D"];

    if nargin < 1 || ~isstruct(initialStates)
        error('WP3:InvalidInitialStates', ...
            'Expected initialStates to be a struct with state_A/state_B/state_C/state_D fields.');
    end

    for i = 1:numel(stateFields)
        fieldName = stateFields(i);
        if ~isfield(initialStates, char(fieldName))
            error('WP3:MissingStateField', ...
                'initialStates is missing required field %s.', char(fieldName));
        end
    end

    parser = inputParser;
    addParameter(parser, 'Manifest', []);
    addParameter(parser, 'PairMap', []);
    addParameter(parser, 'InitializationPolicy', "explicit_four_bed_payloads_supplied_by_caller");
    addParameter(parser, 'SourceNote', "explicit payloads supplied to WP3 state container");
    parse(parser, varargin{:});
    opts = parser.Results;

    manifestVersion = "not_supplied";
    if ~isempty(opts.Manifest)
        if ~isstruct(opts.Manifest) || ~isfield(opts.Manifest, 'version')
            error('WP3:InvalidManifest', ...
                'Manifest must be a struct with a version field when supplied.');
        end
        manifestVersion = string(opts.Manifest.version);
    end

    pairMapVersion = "not_supplied";
    if ~isempty(opts.PairMap)
        if ~isstruct(opts.PairMap) || ~isfield(opts.PairMap, 'version')
            error('WP3:InvalidPairMap', ...
                'PairMap must be a struct with a version field when supplied.');
        end
        pairMapVersion = string(opts.PairMap.version);
    end

    initializationPolicy = string(opts.InitializationPolicy);
    sourceNote = string(opts.SourceNote);

    container = struct();
    container.version = "WP3-Yang2009-four-bed-state-container-v1";
    container.manifestVersion = manifestVersion;
    container.pairMapVersion = pairMapVersion;
    container.bedLabels = bedLabels;
    container.stateFields = stateFields;
    container.initializationPolicy = initializationPolicy;
    container.sourceName = "Yang et al. 2009 Table 2 wrapper state layer";
    container.architecture = struct( ...
        "noDynamicInternalTanks", true, ...
        "noSharedHeaderInventory", true, ...
        "noFourBedRhsDae", true, ...
        "noCoreAdsorberPhysicsRewrite", true, ...
        "wp3StoresPersistentBedStates", true, ...
        "wp3BuildsTemporaryCases", false, ...
        "wp3InvokesSolver", false, ...
        "wp3ComputesLedgersOrMetrics", false ...
    );

    for i = 1:numel(stateFields)
        fieldName = stateFields(i);
        container.(char(fieldName)) = initialStates.(char(fieldName));
    end

    bed = bedLabels(:);
    stateField = stateFields(:);
    initializationPolicyCol = repmat(initializationPolicy, numel(bedLabels), 1);
    sourceNoteCol = repmat(sourceNote, numel(bedLabels), 1);
    lastUpdateRole = repmat("initial", numel(bedLabels), 1);
    lastUpdatePairId = repmat("none", numel(bedLabels), 1);
    lastUpdateOperation = repmat("initial", numel(bedLabels), 1);
    lastUpdateSourceCol = nan(numel(bedLabels), 1);
    writebackCount = zeros(numel(bedLabels), 1);

    container.stateMetadata = table( ...
        bed, ...
        stateField, ...
        initializationPolicyCol, ...
        sourceNoteCol, ...
        lastUpdateRole, ...
        lastUpdatePairId, ...
        lastUpdateOperation, ...
        lastUpdateSourceCol, ...
        writebackCount, ...
        'VariableNames', [
            "bed"
            "state_field"
            "initialization_policy"
            "source_note"
            "last_update_role"
            "last_update_pair_id"
            "last_update_operation"
            "last_update_source_col"
            "writeback_count"
        ]);

    container.writebackLog = table( ...
        zeros(0, 1), ...
        strings(0, 1), ...
        strings(0, 1), ...
        strings(0, 1), ...
        zeros(0, 1), ...
        strings(0, 1), ...
        strings(0, 1), ...
        strings(0, 1), ...
        strings(0, 1), ...
        strings(0, 1), ...
        zeros(0, 1), ...
        strings(0, 1), ...
        'VariableNames', [
            "writeback_index"
            "selection_type"
            "pair_id"
            "direct_transfer_family"
            "local_index"
            "local_role"
            "global_bed"
            "state_field"
            "yang_label"
            "record_id"
            "source_col"
            "update_note"
        ]);
end
