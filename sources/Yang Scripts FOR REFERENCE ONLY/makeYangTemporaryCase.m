function tempCase = makeYangTemporaryCase(selection, varargin)
%MAKEYANGTEMPORARYCASE Build a WP4 temporary local case specification.
%
% A temporary case contains only the selected local bed states plus wrapper
% metadata. It does not assemble a four-bed state vector or create internal
% tank/header inventory.

    parser = inputParser;
    addParameter(parser, 'DurationSeconds', []);
    addParameter(parser, 'DurationDimless', []);
    addParameter(parser, 'RunnerMode', "dry_run");
    addParameter(parser, 'CaseNote', "not_supplied");
    addParameter(parser, 'OperationPolicy', "fixed_duration_direct_coupling");
    addParameter(parser, 'ExternalProductSink', "RAF");
    addParameter(parser, 'ExternalWasteSink', "ATM");
    parse(parser, varargin{:});
    opts = parser.Results;

    validateSelection(selection);
    validateDurationOptions(opts.DurationSeconds, opts.DurationDimless);

    translation = translateYangNativeOperation(selection, ...
        'OperationPolicy', opts.OperationPolicy, ...
        'ExternalProductSink', opts.ExternalProductSink, ...
        'ExternalWasteSink', opts.ExternalWasteSink);

    localStates = selection.localStates(:);
    localMap = selection.localMap;
    nLocalBeds = height(localMap);
    hasExecutableDuration = ~isempty(opts.DurationSeconds) || ~isempty(opts.DurationDimless);

    tempCase = struct();
    tempCase.version = "WP4-Yang2009-temporary-case-v1";
    tempCase.caseType = string(selection.selectionType);
    tempCase.selectionVersion = string(selection.version);
    tempCase.selectionType = string(selection.selectionType);
    tempCase.pairId = string(selection.pairId);
    tempCase.directTransferFamily = string(selection.directTransferFamily);
    tempCase.nLocalBeds = nLocalBeds;
    tempCase.localMap = localMap;
    tempCase.localStates = localStates;
    tempCase.yang = makeYangMetadata(localMap);
    tempCase.native = translation;
    tempCase.template = struct( ...
        "paramsStatus", "not_supplied", ...
        "nativeTemplateRequiredForNativeRunner", logical(translation.nativeRunnable));
    tempCase.execution = struct( ...
        "runnerMode", string(opts.RunnerMode), ...
        "durationSeconds", opts.DurationSeconds, ...
        "durationDimless", opts.DurationDimless, ...
        "hasExecutableDuration", hasExecutableDuration, ...
        "durationPolicy", "caller_supplied_only_no_source_column_duration_inference", ...
        "nativeRunStatus", "not_run");
    tempCase.architecture = struct( ...
        "noDynamicInternalTanks", true, ...
        "noSharedHeaderInventory", true, ...
        "noFourBedRhsDae", true, ...
        "noCoreAdsorberPhysicsRewrite", true, ...
        "temporaryCaseContainsOnlySelectedLocalStates", true, ...
        "wp4ComputesLedgersOrMetrics", false, ...
        "wp4UsesEventScheduling", false);
    tempCase.validation = struct("status", "not_validated");
    tempCase.metadata = struct( ...
        "source", "WP4 temporary toPSAil-compatible case adapter", ...
        "caseNote", string(opts.CaseNote), ...
        "stateOrderContract", "terminalLocalStates must return in localMap.local_index order", ...
        "validationClaim", "structural case-builder only; no Yang validation claim");

    result = validateYangTemporaryCase(tempCase);
    tempCase.validation = result;
    if ~result.pass
        error('WP4:InvalidTemporaryCase', ...
            'Temporary case failed WP4 validation: %s', char(strjoin(result.failures, " | ")));
    end
end

function validateSelection(selection)
    if ~isstruct(selection) || ~isfield(selection, 'selectionType')
        error('WP4:InvalidSelection', ...
            'Expected a WP3 selection struct with a selectionType field.');
    end

    if ~ismember(string(selection.selectionType), ["paired_direct_transfer", "single_bed_operation"])
        error('WP4:InvalidSelectionType', ...
            'Unsupported selectionType %s.', char(string(selection.selectionType)));
    end

    if ~isfield(selection, 'localStates') || ~iscell(selection.localStates)
        error('WP4:InvalidSelection', ...
            'Selection must contain localStates as a cell array.');
    end

    if ~isfield(selection, 'localMap') || ~istable(selection.localMap)
        error('WP4:InvalidSelection', ...
            'Selection must contain localMap as a table.');
    end

    if numel(selection.localStates) ~= height(selection.localMap)
        error('WP4:SelectionStateCountMismatch', ...
            'Selection localStates count must match localMap height.');
    end
end

function validateDurationOptions(durationSeconds, durationDimless)
    if ~isempty(durationSeconds) && ~isempty(durationDimless)
        error('WP4:AmbiguousDuration', ...
            'Provide only one of DurationSeconds or DurationDimless.');
    end

    if ~isempty(durationSeconds)
        validateattributes(durationSeconds, {'numeric'}, {'scalar', 'real', 'positive'}, ...
            mfilename, 'DurationSeconds');
    end

    if ~isempty(durationDimless)
        validateattributes(durationDimless, {'numeric'}, {'scalar', 'real', 'positive'}, ...
            mfilename, 'DurationDimless');
    end
end

function yang = makeYangMetadata(localMap)
    yang = struct();
    yang.sourceYangLabels = string(localMap.yang_label);
    yang.sourceRecordIds = string(localMap.record_id);
    yang.sourceColumns = localMap.source_col;
    yang.localRoles = string(localMap.local_role);
    yang.globalBeds = string(localMap.global_bed);
    yang.pressureStartClasses = string(localMap.p_start_class);
    yang.pressureEndClasses = string(localMap.p_end_class);
    yang.inletEndpoints = string(localMap.inlet_endpoint);
    yang.outletEndpoints = string(localMap.outlet_endpoint);
    yang.wasteEndpoints = string(localMap.waste_endpoint);
    yang.durationTraceabilityPolicy = ...
        "source columns retained; executable duration must be supplied by caller";
end
