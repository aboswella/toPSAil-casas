function params = injectYangLocalStatesIntoTemplateParams(templateParams, tempCase, varargin)
%INJECTYANGLOCALSTATESINTOTEMPLATEPARAMS Insert WP4 local states into params.
%
% This helper is intentionally narrow: it requires a safe initialized
% toPSAil params template whose column count and column-state length already
% match the temporary case. It does not build physical parameters.

    parser = inputParser;
    addParameter(parser, 'DurationSeconds', []);
    addParameter(parser, 'DurationDimless', []);
    parse(parser, varargin{:});
    opts = parser.Results;

    if nargin < 1 || ~isstruct(templateParams)
        error('WP4:InvalidTemplateParams', ...
            'TemplateParams must be an initialized toPSAil params struct.');
    end

    result = validateYangTemporaryCase(tempCase);
    if ~result.pass
        error('WP4:InvalidTemporaryCase', ...
            'Cannot inject states into an invalid temporary case.');
    end

    requiredFields = ["nCols", "nColSt", "nColStT", "nComs", "initStates"];
    paramsFields = string(fieldnames(templateParams));
    missingFields = setdiff(requiredFields, paramsFields);
    if ~isempty(missingFields)
        error('WP4:InvalidTemplateParams', ...
            'TemplateParams is missing required fields: %s.', char(strjoin(missingFields, ", ")));
    end

    if templateParams.nCols ~= tempCase.nLocalBeds
        error('WP4:TemplateColumnCountMismatch', ...
            'TemplateParams.nCols must match tempCase.nLocalBeds.');
    end

    params = templateParams;
    counterTailLength = params.nColStT - params.nColSt;
    expectedCounterTailLength = 2 * params.nComs;
    if counterTailLength ~= expectedCounterTailLength
        error('FI6:UnexpectedCounterTailLength', ...
            'Native counter tail length is %d; expected 2*nComs = %d.', ...
            counterTailLength, expectedCounterTailLength);
    end

    initStates = params.initStates;
    if size(initStates, 1) ~= 1
        initStates = initStates(:).';
    end

    injectionModes = strings(tempCase.nLocalBeds, 1);
    for i = 1:tempCase.nLocalBeds
        localStateVector = extractStateVector(tempCase.localStates{i});
        if numel(localStateVector) == params.nColSt
            localStateVector = [localStateVector(:); zeros(counterTailLength, 1)];
            injectionModes(i) = "physical_state_with_zero_counter_tail_for_temporary_native_execution";
        elseif numel(localStateVector) == params.nColStT
            localStateVector = localStateVector(:);
            injectionModes(i) = "native_length_state_supplied";
        else
            error('WP4:LocalStateLengthMismatch', ...
                'Local state %d has %d entries; expected nColSt = %d or nColStT = %d.', ...
                i, numel(localStateVector), params.nColSt, params.nColStT);
        end

        idx = ((i-1)*params.nColStT + 1):(i*params.nColStT);
        initStates(idx) = localStateVector(:).';
    end

    params.initStates = initStates;
    params.sStepCol = cellstr(string(tempCase.native.nativeStepNames(:)));
    params.nSteps = 1;
    params.numAdsEqPrEnd = reshape(tempCase.native.numAdsEqPrEnd, [], 1);
    params.numAdsEqFeEnd = reshape(tempCase.native.numAdsEqFeEnd, [], 1);

    durationValue = pickDuration(tempCase, opts.DurationSeconds, opts.DurationDimless);
    if ~isempty(durationValue)
        params.durStep = durationValue;
    end

    params.yangStateInjectionReport = struct( ...
        "version", "FI6-Yang2009-temporary-native-state-injection-v1", ...
        "persistentStateBasis", "physical_adsorber_state_only", ...
        "nativeExecutionTailPolicy", "zero_counter_tails_appended_only_for_temporary_native_calls", ...
        "localInjectionModes", injectionModes, ...
        "counterTailLength", counterTailLength);
end

function stateVector = extractStateVector(localState)
    if isnumeric(localState)
        stateVector = localState;
    elseif isstruct(localState) && isfield(localState, 'stateVector')
        stateVector = localState.stateVector;
    else
        error('WP4:UnsupportedLocalStatePayload', ...
            'Native injection requires numeric local states or structs with a numeric stateVector field.');
    end

    if ~isnumeric(stateVector) || ~isvector(stateVector)
        error('WP4:UnsupportedLocalStatePayload', ...
            'Native local state payloads must resolve to numeric vectors.');
    end
end

function durationValue = pickDuration(tempCase, durationSeconds, durationDimless)
    durationValue = [];
    if ~isempty(durationDimless)
        durationValue = durationDimless;
    elseif ~isempty(durationSeconds)
        durationValue = durationSeconds;
    elseif isfield(tempCase.execution, 'durationDimless') && ~isempty(tempCase.execution.durationDimless)
        durationValue = tempCase.execution.durationDimless;
    elseif isfield(tempCase.execution, 'durationSeconds') && ~isempty(tempCase.execution.durationSeconds)
        durationValue = tempCase.execution.durationSeconds;
    end
end
