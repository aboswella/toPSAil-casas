function params = finalizeRibeiroSurrogateTemplateParams(params, varargin)
%FINALIZERIBEIROSURROGATETEMPLATEPARAMS Complete native runtime params.

if ~isempty(varargin)
    error('RibeiroSurrogate:UnexpectedFinalizeInput', ...
        'Batch 2 finalizer does not accept additional inputs.');
end

params.bool = zeros(12, 1);
params.bool(1) = double(params.nCols > 1);
params.bool(3) = 0;
params.bool(5) = 0;

params.presColHigh = 7.0;
params.presColLow = 1.0;
params.presFeTa = params.presColHigh;
params.presRaTa = params.presColHigh;
params.presExTa = params.presColLow;
params.presAmbi = params.presColLow;
params.presDoSt = params.presColLow;
params = getPresRats(params);

params.tempAmbi = 303.0;
params.tempCol = 303.0;
params.tempFeed = 303.0;
params.tempRefIso = 303.0;
params.tempAmbiNorm = 1;
params.tempColNorm = 1;
params.tempFeedNorm = 1;
params.tempRefNorm = 1;
params = getTempRats(params);

params = getVoidAndDens(params);
params = getColumnParams(params);
params.radInFeTa = params.radInCol;
params.radInRaTa = params.radInCol;
params.radInExTa = params.radInCol;
params.radOutFeTa = params.radOutCol;
params.radOutRaTa = params.radOutCol;
params.radOutExTa = params.radOutCol;
params.heightFeTa = params.heightCol;
params.heightRaTa = params.heightCol;
params.heightExTa = params.heightCol;
params = getTankParams(params);

params.numZero = 1e-10;
params.numIntSolv = "ode15s";
params.odeRelTol = 3e-4;
params.odeAbsTol = 1e-5;
params.nRows = 1;

params.ldfMtc = params.ldfMassTransferPerSec * ones(params.nComs, 1);
params.compFacC = ones(params.nComs, 1);
params.gasCons = 83.14;
params.htCapCpC = [28.84; 37.14];
params.htCapCvC = params.htCapCpC - (params.gasCons / 10);

params = initializeDefaultSchedulePlaceholders(params);

[models, subModels] = getSubModels(params);
params.funcIso = models{1};
params.funcRat = models{2};
params.funcEos = models{3};
params.funcVal = models{4};
params.funcVol = models{6};
params.funcVolUnits = subModels{6};
params.funcCss = models{7};

params = getSolverOpts(params);
params = getStatesParams(params);
params = getStreamParams(params);
params = getTotalGasConc(params);
params = getAdsEquilParams(params);
params = getTotalAdsConc(params);
params = getAdsEquilParams(params, 1);
params = getFeHtCapRatio(params);
params = getFeMixCompFac(params);
params = getScaleFacs(params);
params = getDimLessParams(params);

end

function params = initializeDefaultSchedulePlaceholders(params)

nativeValveCoefficient = params.nativeValveCoefficient;

params.sStepCol = repmat({'RT-XXX-XXX'}, params.nCols, params.nSteps);
params.typeDaeModel = ones(params.nCols, params.nSteps);
params.flowDirCol = zeros(params.nCols, params.nSteps);
params.numAdsEqPrEnd = zeros(params.nCols, params.nSteps);
params.numAdsEqFeEnd = zeros(params.nCols, params.nSteps);
params.valFeedCol = nativeValveCoefficient * ones(params.nCols, params.nSteps);
params.valProdCol = nativeValveCoefficient * ones(params.nCols, params.nSteps);
params.eveVal = NaN(1, params.nSteps);
params.eveUnit = repmat({'None'}, 1, params.nSteps);
params.eveLoc = repmat({'None'}, 1, params.nSteps);
params.funcEve = repmat({[]}, 1, params.nSteps);

end
