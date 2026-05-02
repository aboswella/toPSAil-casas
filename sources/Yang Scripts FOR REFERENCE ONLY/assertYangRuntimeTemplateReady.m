function report = assertYangRuntimeTemplateReady(params)
%ASSERTYANGRUNTIMETEMPLATEREADY Check FI-8 native runtime readiness.

    report = struct();
    report.version = "FI8-Yang2009-runtime-template-readiness-v1";
    report.pass = true;
    report.failures = strings(0, 1);
    report.warnings = strings(0, 1);
    report.checkedFields = strings(0, 1);

    if nargin < 1 || ~isstruct(params)
        report = fail(report, "params must be a scalar struct");
        return;
    end

    report = checkH2Co2Basis(report, params);
    report = checkRuntimeFields(report, params);
    report = checkStateLayout(report, params);
    report = checkForbiddenModelFlags(report, params);

    report.pass = isempty(report.failures);
end

function report = checkH2Co2Basis(report, params)
    if ~hasField(params, "nComs") || params.nComs ~= 2
        report = fail(report, "params.nComs must be 2");
    end
    if ~hasField(params, "componentNames") || ...
            any(string(params.componentNames(:)) ~= ["H2"; "CO2"])
        report = fail(report, "componentNames must be [H2; CO2]");
    end
    if ~hasField(params, "yangBasis")
        report = fail(report, "yangBasis metadata is required");
    elseif ~isfield(params.yangBasis, 'acOnlyHomogeneous') || ...
            ~logical(params.yangBasis.acOnlyHomogeneous)
        report = fail(report, "yangBasis must declare AC-only homogeneous surrogate");
    end
end

function report = checkRuntimeFields(report, params)
    required = [
        "initStates"
        "bool"
        "numZero"
        "numIntSolv"
        "nTiPts"
        "funcRat"
        "funcIso"
        "coefMat"
        "cstrHt"
        "partCoefHp"
        "nFeTaStT"
        "nRaTaStT"
        "nExTaStT"
        "inShFeTa"
        "inShRaTa"
        "inShExTa"
        "inShComp"
        "inShVac"
        "feTaVolNorm"
        "raTaVolNorm"
        "exTaVolNorm"
        "gasConsNormEq"
        "tempFeedNorm"
        "pRatFe"
        "pRatAmb"
        "yFeC"
        "tiScaleFac"
        "htCapRatioFe"
        "compFacFe"
        "isEntEffFeComp"
        "isEntEffExComp"
        "isEntEffPump"
        "odeRelTol"
        "odeAbsTol"
    ];
    fields = string(fieldnames(params));
    missing = setdiff(required, fields);
    report.checkedFields = required(:);
    if ~isempty(missing)
        report = fail(report, "missing runtime fields: " + strjoin(missing, ", "));
    end
    if hasField(params, "yangRuntimeFinalization") && ...
            isfield(params.yangRuntimeFinalization, 'finalized') && ...
            logical(params.yangRuntimeFinalization.finalized)
        return;
    end
    report.warnings(end+1, 1) = ...
        "yangRuntimeFinalization.finalized is not true; runtime may still work but is not explicitly commissioned";
end

function report = checkStateLayout(report, params)
    required = ["nColSt", "nColStT", "nComs", "nVols", "nStates", "nStatesT", "initStates"];
    if ~all(ismember(required, string(fieldnames(params))))
        report = fail(report, "state-size fields are incomplete");
        return;
    end
    if params.nColSt ~= params.nStates * params.nVols
        report = fail(report, "nColSt must equal nStates*nVols");
    end
    if params.nColStT - params.nColSt ~= 2 * params.nComs
        report = fail(report, "nColStT - nColSt must equal 2*nComs");
    end
    if numel(params.initStates) ~= params.nStatesT
        report = fail(report, sprintf("initStates length %d does not match nStatesT %d", ...
            numel(params.initStates), params.nStatesT));
    end
    if ~hasField(params, "tiScaleFac") || ~isnumeric(params.tiScaleFac) || ...
            ~isscalar(params.tiScaleFac) || ~isfinite(params.tiScaleFac) || params.tiScaleFac <= 0
        report = fail(report, "tiScaleFac must be a finite positive scalar");
    end
end

function report = checkForbiddenModelFlags(report, params)
    if ~hasField(params, "yangBasis")
        return;
    end
    forbidden = [
        "coIncluded"
        "ch4Included"
        "zeolite5AIncluded"
        "layeredBedEnabled"
        "pseudoImpurityIncluded"
    ];
    for i = 1:numel(forbidden)
        name = char(forbidden(i));
        if isfield(params.yangBasis, name) && logical(params.yangBasis.(name))
            report = fail(report, "forbidden surrogate flag enabled: " + forbidden(i));
        end
    end
end

function tf = hasField(s, name)
    tf = isstruct(s) && isfield(s, char(name)) && ~isempty(s.(char(name)));
end

function report = fail(report, message)
    report.failures(end+1, 1) = string(message);
    report.pass = false;
end
