function basis = yangH2Co2AcSurrogateConstants()
%YANGH2CO2ACSURROGATECONSTANTS Source constants for the FI-2 surrogate.
%
% The returned structure is source metadata plus unit conversions. It does
% not call the solver and does not define any four-bed schedule policy.

    atmToBar = 1.01325;
    calToJ = 4.184;

    componentOrder = ["H2"; "CO2"];
    feedMoleFractions = [0.7697228145; 0.2302771855];

    basis = struct();
    basis.version = "FI2-Yang2009-H2CO2-AC-surrogate-constants-v1";
    basis.sourceName = "Yang et al. 2009 H2 PSA activated-carbon subset";
    basis.surrogateName = "Yang-inspired H2/CO2 homogeneous activated-carbon surrogate";

    basis.componentNames = componentOrder;
    basis.componentOrder = componentOrder;
    basis.nComs = 2;

    basis.feed = struct();
    basis.feed.rawYangSubsetComponentNames = componentOrder;
    basis.feed.rawYangSubsetMolePercent = [72.2; 21.6];
    basis.feed.binaryRenormalizedMoleFractions = feedMoleFractions;
    basis.feed.omittedYangComponents = ["CO"; "CH4"];
    basis.feed.omissionNote = "CO and CH4 are omitted from the model components, not included as zero components.";

    basis.geometry = struct();
    basis.geometry.fullBedLengthCm = 170;
    basis.geometry.activatedCarbonLayerLengthCm = 100;
    basis.geometry.zeoliteLayerLengthCm = 70;
    basis.geometry.insideDiameterCm = 3.84;
    basis.geometry.outsideDiameterCm = 4.86;
    basis.geometry.insideRadiusCm = basis.geometry.insideDiameterCm / 2;
    basis.geometry.outsideRadiusCm = basis.geometry.outsideDiameterCm / 2;
    basis.geometry.defaultModelLengthCm = basis.geometry.fullBedLengthCm;
    basis.geometry.defaultGeometryPolicy = "full_yang_vessel_length_filled_homogeneously_with_activated_carbon";

    basis.activatedCarbon = struct();
    basis.activatedCarbon.pelletSizeMm = 1.15;
    basis.activatedCarbon.pelletDensityGPerCm3 = 0.85;
    basis.activatedCarbon.pelletDensityKgPerCm3 = 0.85e-3;
    basis.activatedCarbon.bulkDensityGPerCm3 = 0.482;
    basis.activatedCarbon.bulkDensityKgPerCm3 = 0.482e-3;
    basis.activatedCarbon.voidFracBed = 0.433;
    basis.activatedCarbon.heatCapacityCalPerGPerK = 0.25;
    basis.activatedCarbon.heatCapacityJPerKgPerK = 0.25 * calToJ * 1000;

    basis.column = struct();
    basis.column.heatCapacityCalPerGPerK = 0.12;
    basis.column.heatCapacityJPerKgPerK = 0.12 * calToJ * 1000;
    basis.column.densityGPerCm3 = 7.83;
    basis.column.densityKgPerCm3 = 7.83e-3;
    basis.column.internalHeatTransferCoefficientKjPerSecPerM3PerK = 0.0385;
    basis.column.internalHeatTransferCoefficientJPerSecPerM3PerK = 0.0385 * 1000;
    basis.column.externalHeatTransferCoefficientKjPerSecPerM3PerK = 0.0142;
    basis.column.externalHeatTransferCoefficientJPerSecPerM3PerK = 0.0142 * 1000;

    basis.pressure = struct();
    basis.pressure.knownClasses = ["PF"; "P4"];
    basis.pressure.knownValuesAtm = [9.0; 1.3];
    basis.pressure.knownValuesBar = basis.pressure.knownValuesAtm * atmToBar;
    basis.pressure.intermediateClassesSymbolic = ["P1"; "P2"; "P3"; "P5"; "P6"];
    basis.pressure.note = "Intermediate pressure classes remain symbolic in FI-2.";

    basis.dsl = struct();
    basis.dsl.componentOrder = componentOrder;
    basis.dsl.siteOne = struct();
    basis.dsl.siteOne.qSatMolPerKg = [2.40e-5; 8.00e-3];
    basis.dsl.siteOne.affinityPreExponentialPerAtm = [9.0e-4; 8.0e-6];
    basis.dsl.siteOne.affinityExponentK = [1700; 3100];
    basis.dsl.siteTwo = struct();
    basis.dsl.siteTwo.qSatMolPerKg = [4.80e-4; 1.40e-3];
    basis.dsl.siteTwo.affinityPreExponentialPerAtm = [6.0e-5; 9.6e-7];
    basis.dsl.siteTwo.affinityExponentK = [1915; 4750];
    basis.dsl.heatOfAdsorptionCalPerMol = [1800; 5900];
    basis.dsl.heatOfAdsorptionJPerMol = basis.dsl.heatOfAdsorptionCalPerMol * calToJ;
    basis.dsl.unitNote = "Yang reports q in mmol/g and affinity in 1/atm; mmol/g is numerically equal to mol/kg.";

    basis.referenceTemperatureK = 303.15;
    basis.constants = struct();
    basis.constants.atmToBar = atmToBar;
    basis.constants.gasConstantCcBarPerMolK = 83.14;
    basis.constants.calToJ = calToJ;

    basis.h2co2Renormalized = true;
    basis.acOnlyHomogeneous = true;
    basis.zeolite5AIncluded = false;
    basis.layeredBedEnabled = false;
    basis.coIncluded = false;
    basis.ch4Included = false;
    basis.pseudoImpurityIncluded = false;
    basis.noDynamicInternalTanks = true;

    basis.modelScopeNote = "FI-2 is a binary homogeneous activated-carbon surrogate, not a full Yang layered four-component reproduction.";
end
