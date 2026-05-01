function [params, prepReport] = prepareYangAdppBfAdapterLocalRunParams(tempCase, templateParams, adapterConfig)
%PREPAREYANGADPPBFADAPTERLOCALRUNPARAMS Build isolated AD&PP->BF run params.

    if nargin < 2 || ~isstruct(templateParams)
        error('FI5:TemplateParamsNotRunnable', ...
            'templateParams must be a fully initialized toPSAil params struct.');
    end
    requireStateSizeFields(templateParams);

    params = templateParams;
    params.nCols = 2;
    params.nSteps = 1;
    params.nRows = 1;
    params.sColNums = {'n1'; 'n2'};
    params.sStepCol = {'YANG-ADPP-BF'; 'YANG-ADPP-BF'};
    params.numAdsEqPrEnd = [0; 1];
    params.numAdsEqFeEnd = [0; 0];
    params.typeDaeModel = ones(2, 1);
    params.flowDirCol = [0; 1];
    params.volFlBoFree = zeros(2, 1);
    params.volFlBo = makeAdppBfBoundaryCells();
    params.funcVol = @calcVolFlowsDP0DT0;
    params.funcVolUnits = @zeroYangAdapterAuxiliaryVolFlows;
    params.yangAdapterConfig = adapterConfig;
    params.yangAdapterFamily = "ADPP_BF";

    params = ensureNoEventStepFields(params);
    params = ensureAdppBfInteractionMatrices(params);

    missingRuntime = findMissingRuntimeFields(params);
    if ~isempty(missingRuntime)
        error('FI5:TemplateParamsNotRunnable', ...
            'Template params cannot run AD&PP->BF adapter without fields: %s.', ...
            char(strjoin(missingRuntime, ", ")));
    end

    nativeLocalStates = cell(tempCase.nLocalBeds, 1);
    stateRows = cell(tempCase.nLocalBeds, 1);
    for i = 1:tempCase.nLocalBeds
        [nativeLocalStates{i}, stateRows{i}] = resolveNativeLocalState( ...
            params, tempCase.localStates{i}, tempCase, i);
    end

    initStates = params.initStates;
    if size(initStates, 1) ~= 1
        initStates = initStates(:).';
    end
    if numel(initStates) ~= params.nStatesT
        error('FI5:TemplateParamsNotRunnable', ...
            'templateParams.initStates has %d entries; expected nStatesT = %d.', ...
            numel(initStates), params.nStatesT);
    end

    for i = 1:tempCase.nLocalBeds
        idx = ((i-1)*params.nColStT + 1):(i*params.nColStT);
        initStates(idx) = nativeLocalStates{i}(:).';
    end
    params.initStates = initStates;

    prepReport = struct();
    prepReport.version = "FI5-Yang2009-ADPP-BF-adapter-local-run-prep-v1";
    prepReport.paramsNCols = params.nCols;
    prepReport.paramsNSteps = params.nSteps;
    prepReport.flowDirCol = params.flowDirCol;
    prepReport.flowDirectionPolicy = ...
        "local1 donor co-current feed-to-product; local2 receiver counter-current product-end backfill";
    prepReport.interactionPolicy = ...
        "donor feed uses external feed composition; receiver product end uses donor product-end gas; receiver feed end closed";
    prepReport.localStatePreparation = stateRows;
    prepReport.counterTailPolicy = "zero_initialized_for_temporary_native_run_not_persisted";
    prepReport.auxiliaryTankFlowPolicy = "zero_flow_shape_only_no_internal_transfer_inventory";
end

function requireStateSizeFields(params)
    required = ["nComs", "nVols", "nStates", "nColSt", "nColStT", "nStatesT"];
    fields = string(fieldnames(params));
    missing = setdiff(required, fields);
    if ~isempty(missing)
        error('FI5:TemplateParamsNotRunnable', ...
            'Template params are missing state-size fields: %s.', char(strjoin(missing, ", ")));
    end
end

function volFlBo = makeAdppBfBoundaryCells()
    volFlBo = cell(2, 2, 1);
    volFlBo{1, 1, 1} = @(params,col,feTa,raTa,exTa,nS,nCo) ...
        calcYangAdppBfBoundaryFlows(params, col, nS, nCo, "donor_product_end");
    volFlBo{2, 1, 1} = @(params,col,feTa,raTa,exTa,nS,nCo) ...
        calcYangAdppBfBoundaryFlows(params, col, nS, nCo, "donor_feed_end");
    volFlBo{1, 2, 1} = @(params,col,feTa,raTa,exTa,nS,nCo) ...
        calcYangAdppBfBoundaryFlows(params, col, nS, nCo, "receiver_product_end");
    volFlBo{2, 2, 1} = @(params,col,feTa,raTa,exTa,nS,nCo) ...
        calcYangAdppBfBoundaryFlows(params, col, nS, nCo, "receiver_feed_end");
end

function params = ensureNoEventStepFields(params)
    params.funcEve = {[]};
    if ~isfield(params, 'eveLkMolFrac') || isempty(params.eveLkMolFrac)
        params.eveLkMolFrac = NaN;
    else
        params.eveLkMolFrac = params.eveLkMolFrac(1);
    end
    if ~isfield(params, 'eveTotPresNorm') || isempty(params.eveTotPresNorm)
        params.eveTotPresNorm = NaN;
    else
        params.eveTotPresNorm = params.eveTotPresNorm(1);
    end
    if ~isfield(params, 'eveTempNorm') || isempty(params.eveTempNorm)
        params.eveTempNorm = NaN;
    else
        params.eveTempNorm = params.eveTempNorm(1);
    end
end

function params = ensureAdppBfInteractionMatrices(params)
    zeroFields = [
        "valFeTa2AdsFeEnd"
        "valFeTa2AdsPrEnd"
        "valRaTa2AdsFeEnd"
        "valRaTa2AdsPrEnd"
        "valExTa2AdsFeEnd"
        "valExTa2AdsPrEnd"
        "valAdsPrEnd2RaTa"
        "valAdsPrEnd2RaWa"
        "valAdsFeEnd2ExTa"
        "valAdsFeEnd2ExWa"
        "valFeEndEq"
        "valPrEndEq"
    ];
    for i = 1:numel(zeroFields)
        params.(char(zeroFields(i))) = zeros(2, 1);
    end

    params.valFeTa2AdsFeEnd = [1; 0];
    params.numAdsEqPrEnd = [0; 1];
    params.numAdsEqFeEnd = [0; 0];
end

function missing = findMissingRuntimeFields(params)
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
        "yFeC"
    ];
    fields = string(fieldnames(params));
    missing = setdiff(required, fields);
end

function [nativeVector, prepRow] = resolveNativeLocalState(params, payload, tempCase, localIndex)
    physical = extractYangPhysicalBedState(params, payload, ...
        'Metadata', makeStateMetadata(tempCase, localIndex));

    nativeVector = [
        physical.physicalStateVector(:)
        zeros(2*params.nComs, 1)
    ];

    prepRow = struct();
    prepRow.localIndex = localIndex;
    prepRow.globalBed = string(tempCase.localMap.global_bed(localIndex));
    prepRow.yangLabel = string(tempCase.localMap.yang_label(localIndex));
    prepRow.sourceStateLength = physical.metadata.sourceStateLength;
    prepRow.nativeRunStateLength = numel(nativeVector);
    prepRow.physicalStateLength = params.nColSt;
    prepRow.counterTailsZeroInitialized = true;
    prepRow.persistedCounterTails = false;
end

function metadata = makeStateMetadata(tempCase, localIndex)
    metadata = struct();
    metadata.source = "FI5 ADPP_BF adapter preparation";
    metadata.pairId = string(tempCase.pairId);
    metadata.directTransferFamily = string(tempCase.directTransferFamily);
    metadata.localIndex = localIndex;
    metadata.localRole = string(tempCase.localMap.local_role(localIndex));
    metadata.globalBed = string(tempCase.localMap.global_bed(localIndex));
    metadata.yangLabel = string(tempCase.localMap.yang_label(localIndex));
    metadata.recordId = string(tempCase.localMap.record_id(localIndex));
    metadata.sourceCol = tempCase.localMap.source_col(localIndex);
end
