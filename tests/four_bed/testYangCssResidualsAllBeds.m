function testYangCssResidualsAllBeds()
%TESTYANGCSSRESIDUALSALLBEDS T-CSS-01 all-bed CSS residual.
%
% Tier: Integration/sanity. Runtime class: < 10 s. Default smoke: yes.
% Failure modes caught: CSS-01 one-bed/local-case convergence and CSS-02
% missing state-family control information.

    [manifest, pairMap] = buildWp5ManifestContext();
    params = struct();
    params.nComs = 2;
    params.nVols = 2;
    params.nStates = 2*params.nComs + 2;
    params.nColStT = params.nStates*params.nVols + 2*params.nComs;

    initial = makeContainer(manifest, pairMap, 0);
    finalFail = makeContainer(manifest, pairMap, 0);
    finalFail.state_C.stateVector(12) = finalFail.state_C.stateVector(12) + 1e-4;

    cssFail = computeYangFourBedCssResiduals(initial, finalFail, ...
        'Params', params, 'AbsTol', 1e-8, 'RelTol', 1e-8, 'CycleIndex', 5);
    assert(~cssFail.pass);
    assert(cssFail.controllingBed == "C");
    assert(cssFail.controllingFamily == "wall_temperature");
    families = unique(cssFail.rows.family);
    assert(ismember("gas_concentration", families));
    assert(ismember("adsorbed_loading", families));
    assert(ismember("gas_temperature", families));
    assert(ismember("wall_temperature", families));
    assert(ismember("boundary_cumulative_flow_excluded", families));

    finalPass = makeContainer(manifest, pairMap, 0);
    finalPass.state_C.stateVector(12) = finalPass.state_C.stateVector(12) + 1e-10;
    cssPass = computeYangFourBedCssResiduals(initial, finalPass, ...
        'Params', params, 'AbsTol', 1e-8, 'RelTol', 1e-6, 'CycleIndex', 6);
    assert(cssPass.pass);

    failedAsExpected = false;
    try
        computeYangFourBedCssResiduals(struct("localStates", {{initial.state_A, initial.state_B}}), finalPass);
    catch
        failedAsExpected = true;
    end
    assert(failedAsExpected);

    fprintf('T-CSS-01 passed: CSS residuals check all A/B/C/D beds and state families.\n');
end

function container = makeContainer(manifest, pairMap, offset)
    states = struct();
    states.state_A = struct("stateVector", (1:16) + offset + 0);
    states.state_B = struct("stateVector", (1:16) + offset + 100);
    states.state_C = struct("stateVector", (1:16) + offset + 200);
    states.state_D = struct("stateVector", (1:16) + offset + 300);
    container = makeYangFourBedStateContainer(states, ...
        'Manifest', manifest, 'PairMap', pairMap, ...
        'InitializationPolicy', "unit_test_numeric_state_vectors", ...
        'SourceNote', "T-CSS-01 synthetic state vectors");
end

function [manifest, pairMap] = buildWp5ManifestContext()
    manifest = getYangFourBedScheduleManifest();
    pairMap = getYangDirectTransferPairMap(manifest);
end
