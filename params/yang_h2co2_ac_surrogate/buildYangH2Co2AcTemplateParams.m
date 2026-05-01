function params = buildYangH2Co2AcTemplateParams(varargin)
%BUILDYANGH2CO2ACTEMPLATEPARAMS Build FI-2 H2/CO2 AC surrogate params.
%
% This builder creates a programmatic, Excel-free toPSAil-compatible
% template for later single-bed or paired-bed temporary cases. It does not
% calculate Yang schedule durations or build a four-bed cycle driver.

    parser = inputParser;
    parser.FunctionName = "buildYangH2Co2AcTemplateParams";
    addParameter(parser, "Isothermal", true, @(x) islogical(x) && isscalar(x));
    addParameter(parser, "PressureDropModel", "existing_default", @(x) ischar(x) || isstring(x));
    addParameter(parser, "NVols", 10, @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x >= 1 && fix(x) == x);
    addParameter(parser, "NCols", 2, @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x >= 1 && fix(x) == x);
    addParameter(parser, "NCycles", 1, @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x >= 1 && fix(x) == x);
    addParameter(parser, "NSteps", 10, @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x >= 1 && fix(x) == x);
    addParameter(parser, "NTimePoints", 2, @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x >= 1 && fix(x) == x);
    addParameter(parser, "FeedVelocityCmSec", [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && isfinite(x) && x > 0));
    addParameter(parser, "CycleTimeSec", [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && isfinite(x) && x > 0));
    addParameter(parser, "SolverTolerances", defaultYangSolverTolerances(), @(x) isstruct(x));
    addParameter(parser, "ReferenceTemperatureK", [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && isfinite(x) && x > 0));
    addParameter(parser, "FinalizeForRuntime", false, @(x) islogical(x) && isscalar(x));
    parse(parser, varargin{:});
    opts = parser.Results;

    basis = yangH2Co2AcSurrogateConstants();
    if ~isempty(opts.ReferenceTemperatureK)
        basis.referenceTemperatureK = opts.ReferenceTemperatureK;
    end

    pressureDropModel = string(opts.PressureDropModel);
    if ~ismember(pressureDropModel, ["existing_default", "none"])
        error("YangH2Co2Ac:UnsupportedPressureDropModel", ...
            "FI-2 supports PressureDropModel values 'existing_default' and 'none' only.");
    end

    params = struct();
    params.parameterPackVersion = "FI2-Yang2009-H2CO2-AC-surrogate-params-v1";
    params.parameterPackName = "yang_h2co2_ac_surrogate";
    params.yangBasis = basis;

    params.nComs = 2;
    params.componentNames = basis.componentNames;
    params.componentOrder = basis.componentOrder;
    params.feedMoleFractions = basis.feed.binaryRenormalizedMoleFractions;
    params.yFeC = params.feedMoleFractions;

    params.nVols = double(opts.NVols);
    params.nCols = double(opts.NCols);
    params.nCycles = double(opts.NCycles);
    params.nSteps = double(opts.NSteps);
    params.nTiPts = double(opts.NTimePoints);

    params.bool = zeros(12, 1);
    params.bool(5) = double(~opts.Isothermal);
    params.modSp = [6; 1; 1; 1; 0; 0; 0];

    params.isothermal = opts.Isothermal;
    params.pressureDropModel = pressureDropModel;
    params.feedVelocityCmSec = opts.FeedVelocityCmSec;
    params.cycleTimeSec = opts.CycleTimeSec;
    params.solverTolerances = opts.SolverTolerances;

    params.radInCol = basis.geometry.insideRadiusCm;
    params.radOutCol = basis.geometry.outsideRadiusCm;
    params.heightCol = basis.geometry.defaultModelLengthCm;
    params.activatedCarbonLayerHeightCm = basis.geometry.activatedCarbonLayerLengthCm;
    params.zeoliteLayerHeightCm = basis.geometry.zeoliteLayerLengthCm;
    params.voidFracBed = basis.activatedCarbon.voidFracBed;
    params.overVoid = basis.activatedCarbon.voidFracBed;
    params.maTrRes = 0;
    params.pellDens = basis.activatedCarbon.pelletDensityKgPerCm3;
    params.adsorbentBulkDens = basis.activatedCarbon.bulkDensityKgPerCm3;
    params.pelletDiameterCm = basis.activatedCarbon.pelletSizeMm / 10;
    params = getColumnParams(params);
    if ~isempty(opts.FeedVelocityCmSec)
        params.volFlowFeed = opts.FeedVelocityCmSec * params.crsAreaInCol;
    end

    params.gasCons = basis.constants.gasConstantCcBarPerMolK;
    params.tempAmbi = basis.referenceTemperatureK;
    params.tempCol = basis.referenceTemperatureK;
    params.tempFeed = basis.referenceTemperatureK;
    params.tempRefIso = basis.referenceTemperatureK;
    params.tempAmbiNorm = 1;
    params.tempColNorm = 1;
    params.tempFeedNorm = 1;
    params.tempRefNorm = 1;

    pressureBar = basis.pressure.knownValuesBar;
    params.presColHigh = pressureBar(basis.pressure.knownClasses == "PF");
    params.presColLow = pressureBar(basis.pressure.knownClasses == "P4");
    params.pressureAnchorsAtm = table(basis.pressure.knownClasses, ...
        basis.pressure.knownValuesAtm, ...
        'VariableNames', {'pressure_class', 'pressure_atm'});
    params.symbolicIntermediatePressureClasses = basis.pressure.intermediateClassesSymbolic;

    params.qSatSiteOneC = basis.dsl.siteOne.qSatMolPerKg;
    params.qSatSiteTwoC = basis.dsl.siteTwo.qSatMolPerKg;
    params.nSiteOneC = [1; 1];
    params.nSiteTwoC = [1; 1];
    params.isoStHtC = basis.dsl.heatOfAdsorptionJPerMol;

    refT = basis.referenceTemperatureK;
    bSiteOnePerAtm = basis.dsl.siteOne.affinityPreExponentialPerAtm ...
        .* exp(basis.dsl.siteOne.affinityExponentK ./ refT);
    bSiteTwoPerAtm = basis.dsl.siteTwo.affinityPreExponentialPerAtm ...
        .* exp(basis.dsl.siteTwo.affinityExponentK ./ refT);
    params.bSiteOneC = bSiteOnePerAtm ./ basis.constants.atmToBar;
    params.bSiteTwoC = bSiteTwoPerAtm ./ basis.constants.atmToBar;

    params.gasConT = params.presColHigh / (params.gasCons * refT);
    params.adsConC = evaluateYangSourceDslLoading(basis, ...
        basis.pressure.knownValuesAtm(basis.pressure.knownClasses == "PF"), ...
        refT, params.feedMoleFractions);
    params.adsConT = sum(params.adsConC);

    params.dimLessqSatSiteOneC = params.qSatSiteOneC ./ params.adsConT;
    params.dimLessqSatSiteTwoC = params.qSatSiteTwoC ./ params.adsConT;
    params.dimLessbSiteOneC = params.bSiteOneC .* (params.gasCons * params.tempAmbi * params.gasConT);
    params.dimLessbSiteTwoC = params.bSiteTwoC .* (params.gasCons * params.tempAmbi * params.gasConT);
    params.dimLessnSiteOneC = params.nSiteOneC;
    params.dimLessnSiteTwoC = params.nSiteTwoC;
    params.dimLessIsoStHtRef = params.isoStHtC ./ ((params.gasCons / 10) * params.tempAmbi);

    params = getStatesParams(params);
    params.sComNums = cell(params.nComs, 1);
    for i = 1:params.nComs
        params.sComNums{i} = append('C', int2str(i));
    end
    params.sColNums = cell(params.nCols, 1);
    for i = 1:params.nCols
        params.sColNums{i} = append('n', int2str(i));
    end
    params.nRows = 1;

    params.funcIso = @(paramsIn, states, nAds) calcIsothermExtDuSiLangFreu(paramsIn, states, nAds);

    params.nativeDslMapping = struct();
    params.nativeDslMapping.nativeIsotherm = "extended_dual_site_langmuir_freundlich";
    params.nativeDslMapping.modSp1 = 6;
    params.nativeDslMapping.siteExponents = [params.nSiteOneC, params.nSiteTwoC];
    params.nativeDslMapping.referenceTemperatureK = refT;
    params.nativeDslMapping.affinityBasis = "Yang B(Tref) converted from 1/atm to 1/bar for toPSAil pressure units";
    params.nativeDslMapping.temperatureDependenceCaveat = ...
        "Native toPSAil DSL has one component heat parameter, not Yang's site-specific affinity exponents.";

    params.architecture = struct( ...
        "noDynamicInternalTanks", true, ...
        "noSharedHeaderInventory", true, ...
        "noFourBedRhsDae", true, ...
        "noCoreAdsorberPhysicsRewrite", true);

    if opts.FinalizeForRuntime
        params = finalizeYangH2Co2AcTemplateParams(params);
    end
end

function tol = defaultYangSolverTolerances()
    tol = struct();
    tol.relativeTolerance = 1e-6;
    tol.absoluteTolerance = 1e-8;
end

function q = evaluateYangSourceDslLoading(basis, pressureAtm, temperatureK, y)
    y = y(:);
    b1 = basis.dsl.siteOne.affinityPreExponentialPerAtm ...
        .* exp(basis.dsl.siteOne.affinityExponentK ./ temperatureK);
    b2 = basis.dsl.siteTwo.affinityPreExponentialPerAtm ...
        .* exp(basis.dsl.siteTwo.affinityExponentK ./ temperatureK);
    term1 = b1 .* pressureAtm .* y;
    term2 = b2 .* pressureAtm .* y;
    q = basis.dsl.siteOne.qSatMolPerKg .* term1 ./ (1 + sum(term1)) ...
      + basis.dsl.siteTwo.qSatMolPerKg .* term2 ./ (1 + sum(term2));
end
