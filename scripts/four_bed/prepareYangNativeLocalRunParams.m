function [params, prepReport] = prepareYangNativeLocalRunParams(tempCase, templateParams, varargin)
%PREPAREYANGNATIVELOCALRUNPARAMS Build one-step native local-run params.

    parser = inputParser;
    parser.FunctionName = "prepareYangNativeLocalRunParams";
    addParameter(parser, 'Controls', []);
    addParameter(parser, 'DurationSeconds', []);
    addParameter(parser, 'DurationDimless', []);
    parse(parser, varargin{:});
    opts = parser.Results;

    validateInputs(tempCase, templateParams);
    readiness = assertYangRuntimeTemplateReady(templateParams);
    if ~readiness.pass
        error('FI8:TemplateParamsNotRunnable', ...
            'Template params are not runtime-ready: %s.', ...
            char(strjoin(readiness.failures, " | ")));
    end

    controls = normalizeControls(opts.Controls, templateParams);
    sourceNCols = templateParams.nCols;

    params = templateParams;
    params.nCols = tempCase.nLocalBeds;
    params.nSteps = 1;
    params.nCycles = 1;
    params.nRows = 1;
    params.bool(1) = double(params.nCols > 1);
    params.inConBed = ones(params.nCols, 1);

    params = getStatesParams(params);
    params = getStreamParams(params);
    params.sColNums = makeColumnNames(params.nCols);
    params.sComNums = makeComponentNames(params.nComs);

    stepNames = cellstr(string(tempCase.native.nativeStepNames(:)));
    params.sStepCol = reshape(stepNames, params.nCols, 1);
    params.typeDaeModel = resolveTypeDaeModel(params.sStepCol);
    params.flowDirCol = resolveFlowDirection(tempCase, params.sStepCol);
    params.numAdsEqPrEnd = reshape(tempCase.native.numAdsEqPrEnd, [], 1);
    params.numAdsEqFeEnd = reshape(tempCase.native.numAdsEqFeEnd, [], 1);
    params.durStep = resolveDurationSecondsForMetadata(tempCase, opts);
    params.eveVal = NaN;
    params.eveUnit = {'None'};
    params.eveLoc = {'None'};
    params.funcEve = {[]};

    [params.valFeedColNorm, params.valProdColNorm, valveReport] = ...
        resolveNativeValveMatrices(tempCase, controls, params);
    if all(params.valFeedColNorm(:) == 1) && all(params.valProdColNorm(:) == 1)
        params.valFeedCol = ones(size(params.valFeedColNorm));
        params.valProdCol = ones(size(params.valProdColNorm));
    elseif isfield(params, 'valScaleFac') && isfinite(params.valScaleFac) && params.valScaleFac > 0
        params.valFeedCol = params.valFeedColNorm ./ params.valScaleFac;
        params.valProdCol = params.valProdColNorm ./ params.valScaleFac;
    end

    params = getFlowSheetValves(params);
    params = getColBoundConds(params);
    params = getTimeSpan(params);
    params = getEventParams(params);
    params = getNumParams(params);
    params = ensureNativeSentinelCoefficientMatrices(params);
    params.initStates = getInitialStates(params);

    [params.initStates, stateRows] = injectLocalPhysicalStates(params, tempCase);

    prepReport = struct();
    prepReport.version = "FI8-Yang2009-native-local-run-prep-v1";
    prepReport.sourceTemplateNCols = sourceNCols;
    prepReport.localNCols = params.nCols;
    prepReport.nColSt = params.nColSt;
    prepReport.nColStT = params.nColStT;
    prepReport.nStatesT = params.nStatesT;
    prepReport.nativeStepNames = string(params.sStepCol(:));
    prepReport.typeDaeModel = params.typeDaeModel;
    prepReport.flowDirCol = params.flowDirCol;
    prepReport.numAdsEqPrEnd = params.numAdsEqPrEnd;
    prepReport.numAdsEqFeEnd = params.numAdsEqFeEnd;
    prepReport.counterTailPolicy = ...
        "zero_initialized_for_temporary_native_run_not_persisted";
    prepReport.durationBasis = "resolved_by_resolveYangNativeTimeDomain";
    prepReport.valveReport = valveReport;
    prepReport.localStatePreparation = stateRows;
end

function validateInputs(tempCase, templateParams)
    if nargin < 1 || ~isstruct(tempCase)
        error('FI8:InvalidTemporaryCase', ...
            'tempCase must be a scalar struct.');
    end
    result = validateYangTemporaryCase(tempCase);
    if ~result.pass
        error('FI8:InvalidTemporaryCase', ...
            'Cannot prepare invalid temporary case: %s', ...
            char(strjoin(result.failures, " | ")));
    end
    if ~logical(tempCase.native.nativeRunnable)
        error('FI8:UnsupportedNativeOperation', ...
            'Temporary case is not native-runnable: %s.', ...
            char(string(tempCase.native.unsupportedReason)));
    end
    if nargin < 2 || ~isstruct(templateParams)
        error('FI8:TemplateParamsNotRunnable', ...
            'templateParams must be a runtime-ready params struct.');
    end
end

function controls = normalizeControls(controls, templateParams)
    if isempty(controls)
        controls = struct();
    end
    controls = normalizeYangFourBedControls(controls, templateParams);
end

function names = makeColumnNames(nCols)
    names = cell(nCols, 1);
    for i = 1:nCols
        names{i} = append('n', int2str(i));
    end
end

function names = makeComponentNames(nComs)
    names = cell(nComs, 1);
    for i = 1:nComs
        names{i} = append('C', int2str(i));
    end
end

function typeDaeModel = resolveTypeDaeModel(stepNames)
    stepNames = string(stepNames(:));
    typeDaeModel = ones(numel(stepNames), 1);
    constantPressure = ismember(stepNames, ["HP-FEE-RAF"]);
    typeDaeModel(constantPressure) = 0;
end

function flowDirCol = resolveFlowDirection(tempCase, stepNames)
    family = string(tempCase.native.stageLabel);
    nLocal = tempCase.nLocalBeds;
    flowDirCol = zeros(nLocal, 1);
    switch family
        case "BD"
            flowDirCol(:) = 1;
        case {"EQI", "EQII"}
            roles = string(tempCase.localMap.local_role(:));
            receiver = roles == "receiver";
            flowDirCol(receiver) = 1;
        otherwise
            stepNames = string(stepNames(:));
            flowDirCol(ismember(stepNames, ["DP-ATM-XXX"])) = 1;
    end
end

function durationSeconds = resolveDurationSecondsForMetadata(tempCase, opts)
    durationSeconds = opts.DurationSeconds;
    if isempty(durationSeconds) && isfield(tempCase.execution, 'durationSeconds')
        durationSeconds = tempCase.execution.durationSeconds;
    end
    if isempty(durationSeconds)
        durationSeconds = NaN;
    end
end

function [valFeed, valProd, report] = resolveNativeValveMatrices(tempCase, controls, params)
    nLocal = tempCase.nLocalBeds;
    valFeed = zeros(nLocal, 1);
    valProd = zeros(nLocal, 1);
    defaultCv = defaultNativeValveCoefficient(params);
    family = string(tempCase.native.stageLabel);

    report = struct();
    report.version = "FI8-Yang2009-native-valve-wiring-v1";
    report.family = family;
    report.defaultDimensionlessValve = defaultCv;
    report.nativeCvSentinelValue = 1.0;
    report.source = "fixed_internal_native_runtime_default";

    switch family
        case "AD"
            valFeed(:) = defaultCv;
        case "BD"
            valFeed(:) = defaultCv;
        case "EQI"
            valProd(:) = defaultCv;
        case "EQII"
            valProd(:) = defaultCv;
        otherwise
            error('FI8:UnsupportedNativeOperation', ...
                'No native valve wiring for family %s.', char(family));
    end

    report.valFeedColNorm = valFeed;
    report.valProdColNorm = valProd;
    report.controlValveBasis = ...
        "fixed native runtime default; no top-level Yang native Cv controls";
    report.nativeControlsWired = false;
    report.nativeControlExposure = "not_exposed_in_minimal_yang_controls";
    if isstruct(controls) && isfield(controls, 'Cv_directTransferAliasReport')
        report.ignoredNativeCvFields = controls.Cv_directTransferAliasReport.ignoredNativeCvFields;
    else
        report.ignoredNativeCvFields = strings(0, 1);
    end
end

function value = defaultNativeValveCoefficient(params)
    value = 1.0;
    value = usableValve(value, "default_native_valve");
end

function value = usableValve(value, label)
    if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || value <= 0
        error('FI8:InvalidNativeValveCoefficient', ...
            '%s must be a finite positive scalar.', char(label));
    end
    value = double(value);
end

function params = ensureNativeSentinelCoefficientMatrices(params)
    for nS = 1:params.nSteps
        for nC = 1:params.nCols
            if params.typeDaeModel(nC, nS) ~= 0 || ...
                    ~isempty(params.coefMat{nC, nS})
                continue;
            end
            params.coefMat{nC, nS} = makeConstantPressureCoefficientPair( ...
                params, nC, nS);
        end
    end
end

function pair = makeConstantPressureCoefficientPair(params, nC, nS)
    lower = makeLowerConstantPressureMatrix(params.nVols);
    upper = makeUpperConstantPressureMatrix(params.nVols);
    flowDir = params.flowDirCol(nC, nS);
    feedBoundary = params.volFlBoFree(nC, nS) == 1;
    if feedBoundary && flowDir == 0
        pair = {lower, -lower};
    elseif ~feedBoundary && flowDir == 1
        pair = {upper, -upper};
    else
        error('FI8:UnsupportedNativeSentinelValveMatrix', ...
            ['Native step %s uses sentinel valve coefficient 1 but does ' ...
             'not match a supported constant-pressure boundary.'], ...
            char(string(params.sStepCol{nC, nS})));
    end
end

function matrix = makeLowerConstantPressureMatrix(nVols)
    matrix = eye(nVols) + diag(-ones(1, nVols - 1), -1);
    matrix = sparse(matrix);
end

function matrix = makeUpperConstantPressureMatrix(nVols)
    matrix = diag(ones(1, nVols - 1), +1) - eye(nVols);
    matrix = sparse(matrix);
end

function [initStates, stateRows] = injectLocalPhysicalStates(params, tempCase)
    initStates = params.initStates;
    if size(initStates, 1) ~= 1
        initStates = initStates(:).';
    end
    if numel(initStates) ~= params.nStatesT
        error('FI8:TemplateParamsNotRunnable', ...
            'Prepared initStates length %d does not match nStatesT %d.', ...
            numel(initStates), params.nStatesT);
    end

    stateRows = cell(tempCase.nLocalBeds, 1);
    for i = 1:tempCase.nLocalBeds
        physical = extractYangPhysicalBedState(params, tempCase.localStates{i}, ...
            'Metadata', makeStateMetadata(tempCase, i));
        nativeVector = [
            physical.physicalStateVector(:)
            zeros(2 * params.nComs, 1)
        ];
        idx = ((i-1) * params.nColStT + 1):(i * params.nColStT);
        initStates(idx) = nativeVector(:).';

        stateRows{i} = struct( ...
            "localIndex", i, ...
            "globalBed", string(tempCase.localMap.global_bed(i)), ...
            "yangLabel", string(tempCase.localMap.yang_label(i)), ...
            "sourceStateLength", physical.metadata.sourceStateLength, ...
            "physicalStateLength", params.nColSt, ...
            "nativeRunStateLength", params.nColStT, ...
            "counterTailsZeroInitialized", true, ...
            "persistedCounterTails", false);
    end
end

function metadata = makeStateMetadata(tempCase, localIndex)
    metadata = struct();
    metadata.source = "FI8 native local run preparation";
    metadata.pairId = string(tempCase.pairId);
    metadata.directTransferFamily = string(tempCase.directTransferFamily);
    metadata.localIndex = localIndex;
    metadata.localRole = string(tempCase.localMap.local_role(localIndex));
    metadata.globalBed = string(tempCase.localMap.global_bed(localIndex));
    metadata.yangLabel = string(tempCase.localMap.yang_label(localIndex));
    metadata.recordId = string(tempCase.localMap.record_id(localIndex));
    metadata.sourceCol = tempCase.localMap.source_col(localIndex);
end
