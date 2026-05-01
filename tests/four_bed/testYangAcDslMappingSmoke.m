function testYangAcDslMappingSmoke()
%TESTYANGACDSLMAPPINGSMOKE FI-2 deterministic DSL point-test smoke.
%
% Tier: Static/source. Runtime class: < 5 s. Default smoke: yes.
% Failure modes caught: PARAM-02 hidden DSL unit/mapping drift and false
% non-isothermal validation claims.

    report = testYangAcDslMapping("Tolerance", 1e-8);

    assert(isfield(report, "pass"));
    assert(isfield(report, "maxResidual"));
    assert(isfield(report, "pointTable"));
    assert(report.referenceTemperaturePass);
    assert(report.pass);
    assert(height(report.pointTable) == 27);
    assert(report.referenceMaxResidual <= report.tolerance);

    fprintf('FI-2 DSL mapping smoke passed at reference temperature; full-grid pass = %d.\n', ...
        report.fullTemperatureGridPass);
end
