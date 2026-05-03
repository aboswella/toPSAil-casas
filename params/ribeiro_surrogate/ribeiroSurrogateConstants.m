function basis = ribeiroSurrogateConstants()
%RIBEIROSURROGATECONSTANTS Source-backed constants for the Ribeiro surrogate.

basis.version = "Ribeiro2008-H2CO2-AC-surrogate-constants-v1";
basis.sourceName = "Ribeiro et al. 2008, Chemical Engineering Science 63, 5258-5273";
basis.surrogateName = "simplified_ribeiro_h2co2_ac_surrogate";

basis.componentNames = ["H2"; "CO2"];
basis.componentOrder = ["H2"; "CO2"];
basis.nComs = 2;
basis.productComponent = "H2";

basis.feed.fullSourceComponentOrder = ["H2"; "CO2"; "CH4"; "CO"; "N2"];
basis.feed.fullSourceMoleFractions = [0.733; 0.166; 0.035; 0.029; 0.037];
basis.feed.discardedImpurityFraction = 0.101;
basis.feed.moleFractions = [0.8153503893; 0.1846496107];
basis.feed.moleFractionBasis = ...
    "H2/CO2 renormalized from Ribeiro Table 5 full five-component feed";
basis.feed.sourceFlowNm3Hr = 12.2;
basis.feed.totalMolarFlowMolSec = 0.1513;
basis.feed.pressureBarAbs = 7.0;
basis.feed.temperatureK = 303.0;

basis.pressure.basis = "bar_abs";
basis.pressure.highBarAbs = 7.0;
basis.pressure.lowBarAbs = 1.0;

basis.target.h2Purity = 0.9999;

basis.cycle.nBeds = 4;
basis.cycle.logicalStepLabels = [
    "FEED"
    "EQ_D1"
    "EQ_D2"
    "BLOWDOWN"
    "PURGE"
    "EQ_P1"
    "EQ_P2"
    "PRESSURIZATION"
];
basis.cycle.tFeedDefaultSec = 40.0;
basis.cycle.nativeSlotPolicy = "16_slots_using_tfeed_over_4_base_slot";
basis.cycle.nativeSlotDefaultSec = basis.cycle.tFeedDefaultSec / 4;

basis.adsorbent.name = "activated_carbon_surrogate";
basis.adsorbent.layeredBed = false;
basis.adsorbent.zeoliteIncluded = false;
basis.adsorbent.parameterBasis = ...
    "Ribeiro Table 4 activated-carbon H2/CO2 subset; binary AC-only surrogate, not full layered five-component reproduction";
basis.adsorbent.source = "sources/Ribeiro 2008.pdf Table 4 and Table 5";
basis.adsorbent.multisiteLangmuir.componentOrder = ["H2"; "CO2"];
basis.adsorbent.multisiteLangmuir.qMaxMolKg = [23.565; 7.8550];
basis.adsorbent.multisiteLangmuir.a = [1.0; 3.0];
basis.adsorbent.multisiteLangmuir.kInfPaInv = [7.233e-11; 2.125e-11];
basis.adsorbent.multisiteLangmuir.heatOfAdsorptionKJMol = [12.843; 29.084];
basis.adsorbent.particlePorosity = 0.566;
basis.adsorbent.particleDensityKgM3 = 842;
basis.adsorbent.particleRadiusM = 1.17e-3;
basis.adsorbent.ldf.componentOrder = ["H2"; "CO2"];
basis.adsorbent.ldf.massTransferPerSec = [8.89e-2; 1.24e-2];
basis.adsorbent.ldf.source = ...
    "Ribeiro Table 6 activated-carbon micropore LDF values at feed inlet conditions";

basis.purge.sourceFlowNm3Hr = 3.5;
basis.purge.sourcePurgeToFullFeedH2Ratio = 0.097;
basis.purge.sourceBasis = ...
    "Ribeiro Table 5 purge flow and purge/H2-feed ratio for the full five-component feed";

basis.valves.nativeFallbackCoefficient = 1e-6;
basis.valves.feedValveCoefficientDefault = 4.65e-3;
basis.valves.purgeValveCoefficientDefault = 8.0e-4;
basis.valves.defaultBasis = ...
    "Native source-flow calibration for the binary surrogate; feed/purge Cv values are not Ribeiro paper constants";

basis.scope.binaryOnly = true;
basis.scope.humidFeed = false;
basis.scope.fullFiveComponentMultisiteLangmuirModel = false;
basis.scope.fullRibeiroReproduction = false;

end
