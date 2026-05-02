function testYangFourBedCycleLedgerSmoke()
%TESTYANGFOURBEDCYCLELEDGERSMOKE FI-7 one-cycle ledger smoke.
%
% Tier: Sanity/integration using spy and validation-only routes. Final
% items: FI-6/FI-7. Runtime class: < 15 s. Default smoke: no. Failure mode
% caught: missing stream scopes, internal-transfer product overcount, and
% ledger balance schema regressions.

    params = buildYangH2Co2AcTemplateParams('NVols', 2, 'NCols', 2, 'NSteps', 1);
    params.nScaleFac = 1.0;
    controls = struct( ...
        "cycleTimeSec", 240, ...
        "nativeRunner", @spyNativeRunnerUnchangedWithFlows, ...
        "adapterValidationOnly", true);

    [~, report] = runYangFourBedCycle(makePhysicalContainer(params), params, controls);
    rows = report.ledger.streamRows;
    for scope = ["external_feed", "external_product", "external_waste", ...
            "internal_transfer", "bed_inventory_delta"]
        assert(any(rows.stream_scope == scope));
    end
    assert(report.performanceMetrics.internalTransfersExcluded);
    assert(isfield(report, 'balanceSummary'));
    assert(isfield(report.balanceSummary, 'nBalanceRows'));
    assert(report.balanceSummary.nBalanceRows > 0);
    assert(any(contains(report.warnings, "validationOnly")) || ...
        any(contains(report.warnings, "native/nondimensional")));

    productRows = rows(rows.stream_scope == "external_product", :);
    assert(~any(productRows.stream_scope == "internal_transfer"));

    fprintf('FI-7 cycle ledger smoke passed: one spy cycle emits all wrapper stream scopes.\n');
end

function [terminalLocalStates, nativeReport] = spyNativeRunnerUnchangedWithFlows(tempCase, params, ~, group)
    terminalLocalStates = cell(tempCase.nLocalBeds, 1);
    for i = 1:tempCase.nLocalBeds
        terminalLocalStates{i} = extractYangPhysicalBedState(params, tempCase.localStates{i});
    end
    nativeReport = struct();
    nativeReport.runner = "spy";
    nativeReport.didInvokeNative = false;
    nativeReport.warnings = strings(0, 1);
    nativeReport.counterTailDeltas = makeCounterDeltas(tempCase.nLocalBeds, params, group.operationFamily);
end

function deltas = makeCounterDeltas(nLocal, params, family)
    base = (1:params.nComs)' .* 0.02;
    deltas = cell(nLocal, 1);
    switch string(family)
        case "AD"
            deltas{1} = [base; 0.5 * base];
        case "BD"
            deltas{1} = [0.25 * base; zeros(params.nComs, 1)];
        case {"EQI", "EQII"}
            deltas{1} = [zeros(params.nComs, 1); base];
            deltas{2} = [zeros(params.nComs, 1); base];
        otherwise
            error('test:UnsupportedSpyFamily', 'Unsupported spy native family.');
    end
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
        'InitializationPolicy', "FI-7 cycle ledger smoke", ...
        'SourceNote', "synthetic physical states");
end

function vec = makePhysicalVector(params, offset)
    one = [0.70 + 0.01 * offset; 0.30; 0.01 * offset; 0.02; 1.0; 1.0];
    vec = repmat(one, params.nVols, 1);
end
