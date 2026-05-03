function params = buildRibeiroSurrogateTemplateParams(varargin)
%BUILDRIBEIROSURROGATETEMPLATEPARAMS Build native params for Ribeiro surrogate.

parser = inputParser;
parser.FunctionName = mfilename;
addParameter(parser, 'NVols', 3, @mustBePositiveIntegerScalar);
addParameter(parser, 'NCols', 4, @mustBePositiveIntegerScalar);
addParameter(parser, 'NCycles', 1, @mustBePositiveIntegerScalar);
addParameter(parser, 'NTimePoints', 2, @mustBePositiveIntegerScalar);
addParameter(parser, 'TFeedSec', 40, @mustBePositiveNumericScalar);
addParameter(parser, 'Isothermal', true, @mustBeLogicalScalar);
addParameter(parser, 'FinalizeForRuntime', true, @mustBeLogicalScalar);
addParameter(parser, 'NativeValveCoefficient', 1e-6, @mustBePositiveNumericScalar);
addParameter(parser, 'FeedValveCoefficient', [], @mustBeEmptyOrPositiveNumericScalar);
addParameter(parser, 'PurgeValveCoefficient', [], @mustBeEmptyOrPositiveNumericScalar);
addParameter(parser, 'BlowdownValveCoefficient', [], @mustBeEmptyOrPositiveNumericScalar);
addParameter(parser, 'EqualizationValveCoefficient', [], @mustBeEmptyOrPositiveNumericScalar);
addParameter(parser, 'PressurizationValveCoefficient', [], @mustBeEmptyOrPositiveNumericScalar);
addParameter(parser, 'LdfMassTransferPerSec', [], @mustBeEmptyPositiveScalarOrBinaryVector);
addParameter(parser, 'BoundaryMode', "ribeiro_fixed_non_eq", @mustBeValidBoundaryMode);
addParameter(parser, 'FeedBasisMode', "full_total_renormalized_binary", ...
    @mustBeValidFeedBasisMode);
addParameter(parser, 'BlowdownGainMolSecBar', [], @mustBeEmptyOrNonnegativeNumericScalar);
addParameter(parser, 'PressurizationGainMolSecBar', [], @mustBeEmptyOrNonnegativeNumericScalar);
addParameter(parser, 'MaxBoundaryMolarFlowMolSec', [], @mustBeEmptyOrNonnegativeNumericScalar);
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

basis = ribeiroSurrogateConstants("FeedBasisMode", opts.FeedBasisMode);
basis.feed.totalVolumetricFlowCm3Sec = convertMolarFeedToVolumetricFeed(basis);
ldfMassTransferPerSec = resolveLdfMassTransfer(opts.LdfMassTransferPerSec, basis);
feedValveCoefficient = resolveValveCoefficientDefault( ...
    opts.FeedValveCoefficient, basis.valves.feedValveCoefficientDefault);
purgeValveCoefficient = resolveValveCoefficientDefault( ...
    opts.PurgeValveCoefficient, basis.valves.purgeValveCoefficientDefault);
blowdownValveCoefficient = resolveValveCoefficientDefault( ...
    opts.BlowdownValveCoefficient, opts.NativeValveCoefficient);
equalizationValveCoefficient = resolveValveCoefficientDefault( ...
    opts.EqualizationValveCoefficient, basis.valves.equalizationValveCoefficientDefault);
pressurizationValveCoefficient = resolveValveCoefficientDefault( ...
    opts.PressurizationValveCoefficient, opts.NativeValveCoefficient);

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
params.sColNums = makeIndexedNames('n', params.nCols);
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
params.KCSourceKInfBarInv = basis.adsorbent.multisiteLangmuir.kInfPaInv * 1e5;
params.KC = calcEffectiveIsothermalKCBasis(basis);
params.KCBasis = [
    "Effective isothermal native MSL coefficient at 303 K."
    "KC = a_i * k_inf(Pa^-1) * 1e5 * exp(deltaH_i/(R*T))."
    "The a_i multiplier adapts Ribeiro Eq. (1) to native funcMultiSiteLang, which already uses a_i only as the vacancy exponent."
];
params.KCTemperatureK = basis.feed.temperatureK;
params.KCIncludesRibeiroMultiplicity = true;
params.KCIncludesHeatFactor = true;
params.isoStHtC = 1000 * basis.adsorbent.multisiteLangmuir.heatOfAdsorptionKJMol;
params.funcIso = @(paramsIn, states, nAds) calcIsothermMultiSiteLang(paramsIn, states, nAds);
params.isothermCaveat = ...
    "Ribeiro Table 4 activated-carbon H2/CO2 subset only; excludes zeolite and CH4/CO/N2";

params.nativeValveCoefficient = opts.NativeValveCoefficient;
params.feedValveCoefficient = feedValveCoefficient;
params.purgeValveCoefficient = purgeValveCoefficient;
params.blowdownValveCoefficient = blowdownValveCoefficient;
params.equalizationValveCoefficient = equalizationValveCoefficient;
params.pressurizationValveCoefficient = pressurizationValveCoefficient;
params.valveCoefficientBasis = ...
    "NativeValveCoefficient is the fallback Cv; feed/purge/blowdown/equalization/pressurization overrides are native pressure-flow audit knobs, not Ribeiro paper constants.";
params.ldfMassTransferPerSec = ldfMassTransferPerSec;
params.ldfMassTransferBasis = ...
    "Ribeiro Table 6 H2/CO2 activated-carbon LDF values by default; scalar overrides are expanded to both components";
params.ribeiroBoundary = makeRibeiroBoundaryOptions(opts);

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

function kEffBarInv = calcEffectiveIsothermalKCBasis(basis)

gasConstantJMolK = 8.31446261815324;
temperatureK = basis.feed.temperatureK;
msl = basis.adsorbent.multisiteLangmuir;

kInfBarInv = msl.kInfPaInv(:) * 1e5;
aFactor = msl.a(:);
heatFactor = exp((1000 * msl.heatOfAdsorptionKJMol(:)) ...
    ./ (gasConstantJMolK * temperatureK));

kEffBarInv = aFactor .* kInfBarInv .* heatFactor;

end

function ldfMassTransferPerSec = resolveLdfMassTransfer(value, basis)

if isempty(value)
    ldfMassTransferPerSec = basis.adsorbent.ldf.massTransferPerSec(:);
elseif isscalar(value)
    ldfMassTransferPerSec = value * ones(basis.nComs, 1);
else
    ldfMassTransferPerSec = value(:);
end

end

function valveCoefficient = resolveValveCoefficientDefault(value, defaultValue)

if isempty(value)
    valveCoefficient = defaultValue;
else
    valveCoefficient = value;
end

end

function boundary = makeRibeiroBoundaryOptions(opts)

boundary = struct();
boundary.mode = string(validatestring( ...
    char(opts.BoundaryMode), {'native_valves', 'ribeiro_fixed_non_eq'}));
boundary.modeBasis = ...
    "Ribeiro fixed non-equalization boundary mode overrides feed, blowdown, purge, and pressurization while leaving native EQ-XXX-APR intact.";
boundary.feedBoundaryBasis = ...
    "HP-FEE-RAF uses prescribed Ribeiro Table 5 binary feed molar flow and H2/CO2 composition.";
boundary.purgeBoundaryBasis = ...
    "LP-ATM-RAF uses prescribed Ribeiro Table 5 pure-H2 purge molar flow at the product end.";
boundary.blowdownBoundaryBasis = ...
    "DP-ATM-XXX uses a fixed 1 bar sink with a pressure-relief controller gain.";
boundary.pressurizationBoundaryBasis = ...
    "RP-XXX-RAF uses a fixed pure-H2 product-end source with a high-pressure controller gain.";
boundary.equalizationBoundaryBasis = ...
    "native column-to-column EQ-XXX-APR retained";
boundary.blowdownGainMolSecBar = resolveBoundaryGain( ...
    opts.BlowdownGainMolSecBar, 0.30);
boundary.pressurizationGainMolSecBar = resolveBoundaryGain( ...
    opts.PressurizationGainMolSecBar, 0.18);
boundary.maxBoundaryMolarFlowMolSecRequested = opts.MaxBoundaryMolarFlowMolSec;
boundary.maxBoundaryMolarFlowMolSecEffective = resolveMaxBoundaryMolarFlow( ...
    opts.MaxBoundaryMolarFlowMolSec);
boundary.maxBoundaryMolarFlowMolSec = ...
    boundary.maxBoundaryMolarFlowMolSecEffective;
boundary = updateBoundaryBasisText(boundary);

end

function maxFlow = resolveMaxBoundaryMolarFlow(inputValue)

if isempty(inputValue)
    maxFlow = 0.5;
else
    maxFlow = inputValue;
end

end

function gain = resolveBoundaryGain(inputValue, defaultValue)

if isempty(inputValue)
    gain = defaultValue;
else
    gain = inputValue;
end

end

function boundary = updateBoundaryBasisText(boundary)

if boundary.mode == "native_valves"
    boundary.modeBasis = ...
        "Native toPSAil valves and dynamic tanks define all boundary flows.";
    boundary.feedBoundaryBasis = ...
        "HP-FEE-RAF uses native feed tank composition and feed valve flow.";
    boundary.purgeBoundaryBasis = ...
        "LP-ATM-RAF uses native raffinate tank composition and product-end valve flow.";
    boundary.blowdownBoundaryBasis = ...
        "DP-ATM-XXX uses native feed-end valve flow to low-pressure waste.";
    boundary.pressurizationBoundaryBasis = ...
        "RP-XXX-RAF uses native raffinate tank composition and product-end valve flow.";
    boundary.equalizationBoundaryBasis = ...
        "native column-to-column EQ-XXX-APR retained";
end

end

function mustBePositiveIntegerScalar(value)

if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || ...
        value <= 0 || value ~= fix(value)
    error('RibeiroSurrogate:InvalidPositiveInteger', ...
        'Value must be a positive integer scalar.');
end

end

function mustBeEmptyPositiveScalarOrBinaryVector(value)

if isempty(value)
    return;
end
if ~isnumeric(value) || any(~isfinite(value(:))) || any(value(:) <= 0)
    error('RibeiroSurrogate:InvalidPositiveScalarOrVector', ...
        'Value must be empty, a positive scalar, or a positive two-element vector.');
end
if ~(isscalar(value) || numel(value) == 2)
    error('RibeiroSurrogate:InvalidPositiveScalarOrVector', ...
        'Value must be empty, a positive scalar, or a positive two-element vector.');
end

end

function mustBePositiveNumericScalar(value)

if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || value <= 0
    error('RibeiroSurrogate:InvalidPositiveScalar', ...
        'Value must be a positive numeric scalar.');
end

end

function mustBeEmptyOrPositiveNumericScalar(value)

if isempty(value)
    return;
end
if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || value <= 0
    error('RibeiroSurrogate:InvalidPositiveScalar', ...
        'Value must be empty or a positive numeric scalar.');
end

end

function mustBeValidBoundaryMode(value)

validatestring(char(value), {'native_valves', 'ribeiro_fixed_non_eq'});

end

function mustBeValidFeedBasisMode(value)

validatestring(char(value), ...
    {'full_total_renormalized_binary', 'source_h2co2_partial_flow'});

end

function mustBeEmptyOrNonnegativeNumericScalar(value)

if isempty(value)
    return;
end
mustBeNonnegativeNumericScalar(value);

end

function mustBeNonnegativeNumericScalar(value)

if ~isnumeric(value) || ~isscalar(value) || isnan(value) || value < 0
    error('RibeiroSurrogate:InvalidNonnegativeScalar', ...
        'Value must be a nonnegative numeric scalar.');
end

end

function mustBeLogicalScalar(value)

if ~(islogical(value) && isscalar(value))
    error('RibeiroSurrogate:InvalidLogicalScalar', ...
        'Value must be a logical scalar.');
end

end
