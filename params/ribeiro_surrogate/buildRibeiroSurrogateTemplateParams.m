function params = buildRibeiroSurrogateTemplateParams(varargin)
%BUILDRIBEIROSURROGATETEMPLATEPARAMS Build native params for Ribeiro surrogate.

parser = inputParser;
parser.FunctionName = mfilename;
addParameter(parser, 'NVols', 8, @mustBePositiveIntegerScalar);
addParameter(parser, 'NCols', 4, @mustBePositiveIntegerScalar);
addParameter(parser, 'NCycles', 10, @mustBePositiveIntegerScalar);
addParameter(parser, 'NTimePoints', 2, @mustBePositiveIntegerScalar);
addParameter(parser, 'TFeedSec', 40, @mustBePositiveNumericScalar);
addParameter(parser, 'Isothermal', true, @mustBeLogicalScalar);
addParameter(parser, 'FinalizeForRuntime', true, @mustBeLogicalScalar);
addParameter(parser, 'NativeValveCoefficient', 1e-6, @mustBePositiveNumericScalar);
addParameter(parser, 'LdfMassTransferPerSec', 0.05, @mustBePositiveNumericScalar);
parse(parser, varargin{:});
opts = parser.Results;

if opts.NCols ~= 4
    error('RibeiroSurrogate:InvalidNCols', ...
        'The Ribeiro surrogate batch 2 builder supports exactly four columns.');
end

if ~opts.Isothermal
    error('RibeiroSurrogate:NonIsothermalUnsupported', ...
        'Batch 2 only supports the isothermal Ribeiro surrogate.');
end

basis = ribeiroSurrogateConstants();
basis.feed.totalVolumetricFlowCm3Sec = convertMolarFeedToVolumetricFeed(basis);

params = struct();
params.parameterPackVersion = "Ribeiro2008-H2CO2-AC-surrogate-params-v1";
params.parameterPackName = "ribeiro_h2co2_ac_surrogate";
params.ribeiroBasis = basis;

params.nComs = 2;
params.componentNames = basis.componentNames;
params.componentOrder = basis.componentOrder;
params.sCom = cellstr(params.componentNames);
params.sComNums = makeIndexedNames('C', params.nComs);
params.nLKs = 1;

params.yFeC = basis.feed.moleFractions;
params.yRaC = [1; 0];
params.yExC = [0; 1];

params.nVols = opts.NVols;
params.nCols = opts.NCols;
params.nCycles = opts.NCycles;
params.nSteps = 16;
params.nTiPts = opts.NTimePoints;

params.tFeedSec = opts.TFeedSec;
params.nativeSlotSec = opts.TFeedSec / 4;
params.cycleTimeSec = 4 * opts.TFeedSec;
params.isothermal = opts.Isothermal;

params.volFlowFeed = basis.feed.totalVolumetricFlowCm3Sec;

params.radInCol = 10.0;
params.radOutCol = 10.5;
params.heightCol = 100.0;

params.voidFracBed = 0.38;
params.overVoid = params.voidFracBed;
params.maTrRes = 0;
params.particlePorosity = basis.adsorbent.particlePorosity;
params.voidFracPell = basis.adsorbent.particlePorosity;
params.voidFracMac = basis.adsorbent.particlePorosity;
params.voidFracMic = 0;
params.pellDens = basis.adsorbent.particleDensityKgM3 / 1e6;
params.diamPellet = 2 * basis.adsorbent.particleRadiusM * 100;

params.modSp = [3; 1; 1; 1; 0; 0; 0];
params.qSatC = basis.adsorbent.multisiteLangmuir.qMaxMolKg;
params.aC = basis.adsorbent.multisiteLangmuir.a;
params.KC = basis.adsorbent.multisiteLangmuir.kInfPaInv;
params.isoStHtC = 1000 * basis.adsorbent.multisiteLangmuir.heatOfAdsorptionKJMol;
params.funcIso = @(paramsIn, states, nAds) calcIsothermMultiSiteLang(paramsIn, states, nAds);
params.isothermCaveat = ...
    "Ribeiro Table 4 activated-carbon H2/CO2 subset only; excludes zeolite and CH4/CO/N2";

params.nativeValveCoefficient = opts.NativeValveCoefficient;
params.ldfMassTransferPerSec = opts.LdfMassTransferPerSec;

if opts.FinalizeForRuntime
    params = finalizeRibeiroSurrogateTemplateParams(params);
end

end

function volFlowCm3Sec = convertMolarFeedToVolumetricFeed(basis)

gasConsCm3BarMolK = 83.14;
temperatureK = basis.feed.temperatureK;
pressureBarAbs = basis.feed.pressureBarAbs;
molarFlowMolSec = basis.feed.totalMolarFlowMolSec;

volFlowCm3Sec = molarFlowMolSec ...
    * gasConsCm3BarMolK ...
    * temperatureK ...
    / pressureBarAbs;

end

function names = makeIndexedNames(prefix, count)

names = cell(count, 1);
for idx = 1:count
    names{idx} = sprintf('%s%d', prefix, idx);
end

end

function mustBePositiveIntegerScalar(value)

if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || ...
        value <= 0 || value ~= fix(value)
    error('RibeiroSurrogate:InvalidPositiveInteger', ...
        'Value must be a positive integer scalar.');
end

end

function mustBePositiveNumericScalar(value)

if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || value <= 0
    error('RibeiroSurrogate:InvalidPositiveScalar', ...
        'Value must be a positive numeric scalar.');
end

end

function mustBeLogicalScalar(value)

if ~(islogical(value) && isscalar(value))
    error('RibeiroSurrogate:InvalidLogicalScalar', ...
        'Value must be a logical scalar.');
end

end
