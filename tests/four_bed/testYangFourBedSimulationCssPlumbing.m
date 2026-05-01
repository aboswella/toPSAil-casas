function testYangFourBedSimulationCssPlumbing()
%TESTYANGFOURBEDSIMULATIONCSSPLUMBING FI-6 CSS loop plumbing.
%
% Tier: Sanity/integration using spy and validation-only routes. Final
% item: FI-6. Runtime class: < 20 s. Default smoke: no. Failure mode
% caught: CSS over nonphysical state or false StopAtCss pass on changing
% states.

    params = buildYangH2Co2AcTemplateParams('NVols', 2, 'NCols', 2, 'NSteps', 1);
    initial = makePhysicalContainer(params);

    unchangedControls = struct( ...
        "cycleTimeSec", 240, ...
        "nativeRunner", @spyNativeRunnerUnchanged, ...
        "adapterValidationOnly", true);
    unchanged = runYangFourBedSimulation(initial, params, unchangedControls, ...
        'MaxCycles', 3, 'StopAtCss', true, 'KeepCycleReports', false);
    assert(unchanged.stopReason == "css_tolerance_satisfied");
    assert(height(unchanged.cssHistory) == 1);
    assert(unchanged.cssHistory.pass(1));

    changingControls = struct( ...
        "cycleTimeSec", 240, ...
        "nativeRunner", @spyNativeRunnerChanging, ...
        "adapterValidationOnly", true);
    changing = runYangFourBedSimulation(initial, params, changingControls, ...
        'MaxCycles', 2, 'StopAtCss', true, 'KeepCycleReports', false);
    assert(changing.stopReason == "max_cycles_reached");
    assert(height(changing.cssHistory) == 2);
    assert(~changing.cssHistory.pass(end));

    fprintf('FI-6 simulation CSS plumbing passed: StopAtCss responds to physical-state residuals.\n');
end

function [terminalLocalStates, nativeReport] = spyNativeRunnerUnchanged(tempCase, params, ~, group)
    terminalLocalStates = unchangedTerminalStates(tempCase, params);
    nativeReport = zeroNativeReport(tempCase, params, group);
end

function [terminalLocalStates, nativeReport] = spyNativeRunnerChanging(tempCase, params, ~, group)
    terminalLocalStates = unchangedTerminalStates(tempCase, params);
    for i = 1:numel(terminalLocalStates)
        vec = terminalLocalStates{i}.stateVector;
        vec(1) = vec(1) + 1e-3 * group.operationGroupIndex;
        terminalLocalStates{i} = extractYangPhysicalBedState(params, vec);
    end
    nativeReport = zeroNativeReport(tempCase, params, group);
end

function terminalLocalStates = unchangedTerminalStates(tempCase, params)
    terminalLocalStates = cell(tempCase.nLocalBeds, 1);
    for i = 1:tempCase.nLocalBeds
        terminalLocalStates{i} = extractYangPhysicalBedState(params, tempCase.localStates{i});
    end
end

function nativeReport = zeroNativeReport(tempCase, params, ~)
    nativeReport = struct();
    nativeReport.runner = "spy";
    nativeReport.didInvokeNative = false;
    nativeReport.warnings = strings(0, 1);
    nativeReport.counterTailDeltas = repmat({zeros(2 * params.nComs, 1)}, tempCase.nLocalBeds, 1);
end

function container = makePhysicalContainer(params)
    states = struct();
    beds = ["A", "B", "C", "D"];
    for idx = 1:numel(beds)
        states.("state_" + beds(idx)) = extractYangPhysicalBedState(params, ...
            makePhysicalVector(params, idx));
    end
    manifest = getYangFourBedScheduleManifest();
    pairMap = getYangDirectTransferPairMap(manifest);
    container = makeYangFourBedStateContainer(states, ...
        'Manifest', manifest, 'PairMap', pairMap, ...
        'InitializationPolicy', "FI-6 CSS plumbing", ...
        'SourceNote', "synthetic physical states");
end

function vec = makePhysicalVector(params, offset)
    one = [0.72 + 0.01 * offset; 0.28; 0.01 * offset; 0.02; 1.0; 1.0];
    vec = repmat(one, params.nVols, 1);
end
