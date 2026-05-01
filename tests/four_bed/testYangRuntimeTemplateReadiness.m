function testYangRuntimeTemplateReadiness()
%TESTYANGRUNTIMETEMPLATEREADINESS FI-8 runtime template gate.
%
% Tier: Static/unit. Final item: FI-8. Runtime class: < 10 s. Default
% smoke: no. Failure mode caught: H2/CO2 AC template looks complete but
% lacks native runtime fields required by runPsaCycleStep.

    raw = buildYangH2Co2AcTemplateParams('NVols', 2, 'NCols', 2, 'NSteps', 1);
    rawReport = assertYangRuntimeTemplateReady(raw);
    assert(~rawReport.pass);
    assert(any(contains(rawReport.failures, "missing runtime fields")));

    params = buildYangH2Co2AcTemplateParams('NVols', 2, 'NCols', 2, ...
        'NSteps', 1, 'FinalizeForRuntime', true);
    report = assertYangRuntimeTemplateReady(params);
    assert(report.pass);
    assert(isfield(params, 'yangRuntimeFinalization'));
    assert(params.yangRuntimeFinalization.finalized);
    assert(params.yangRuntimeFinalization.dynamicInternalTanksAdded == false);
    assert(params.nComs == 2);
    assert(all(string(params.componentNames(:)) == ["H2"; "CO2"]));
    assert(isfinite(params.tiScaleFac) && params.tiScaleFac > 0);
    assert(isfinite(params.htCapRatioFe) && params.htCapRatioFe > 1);
    assert(isfinite(params.compFacFe) && params.compFacFe > 0);

    fprintf('FI-8 runtime template readiness passed: finalized template exposes native runtime fields.\n');
end
