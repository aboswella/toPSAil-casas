function testYangH2Co2AcParameterPack()
%TESTYANGH2CO2ACPARAMETERPACK Static FI-2 parameter-pack contract test.
%
% Tier: Static/source. Runtime class: < 5 s. Default smoke: yes.
% Failure modes caught: PARAM-01/PARAM-02 surrogate-basis drift, component
% order drift, feed-renormalisation drift, and accidental layered/impurity
% component introduction.

    params = buildYangH2Co2AcTemplateParams("NVols", 2);

    assert(params.nComs == 2);
    assert(isequal(params.componentOrder, ["H2"; "CO2"]));
    assert(isequal(params.componentNames, ["H2"; "CO2"]));
    assert(params.modSp(1) == 6);
    assert(isequal(params.nSiteOneC(:), [1; 1]));
    assert(isequal(params.nSiteTwoC(:), [1; 1]));
    assert(abs(sum(params.feedMoleFractions) - 1) < 1e-12);
    assert(abs(params.feedMoleFractions(1) - 0.7697228145) < 1e-10);
    assert(abs(params.feedMoleFractions(2) - 0.2302771855) < 1e-10);
    assert(params.yangBasis.h2co2Renormalized);
    assert(params.yangBasis.acOnlyHomogeneous);
    assert(~params.yangBasis.zeolite5AIncluded);
    assert(~params.yangBasis.layeredBedEnabled);
    assert(~params.yangBasis.coIncluded);
    assert(~params.yangBasis.ch4Included);
    assert(~params.yangBasis.pseudoImpurityIncluded);
    assert(params.yangBasis.noDynamicInternalTanks);
    assert(params.heightCol == 170);
    assert(params.activatedCarbonLayerHeightCm == 100);
    assert(params.zeoliteLayerHeightCm == 70);
    assert(params.voidFracBed == 0.433);
    assert(params.nStates == 2 * params.nComs + 2);
    assert(params.nColSt == params.nStates * params.nVols);
    assert(params.nColStT == params.nColSt + 2 * params.nComs);
    assert(params.nColSt < params.nColStT);
    assert(all(params.symbolicIntermediatePressureClasses == ["P1"; "P2"; "P3"; "P5"; "P6"]));

    fprintf('FI-2 parameter-pack contract passed: Yang H2/CO2 AC surrogate.\n');
end
