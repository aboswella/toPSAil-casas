function testYangNativeTranslationCoverage()
%TESTYANGNATIVETRANSLATIONCOVERAGE T-CASE: Yang label translation coverage.
%
% Tier: Unit/static. Runtime class: < 10 s. Default smoke: yes.
% Failure modes caught: CASE-02 raw Yang labels reaching native parser,
% SCHED-03 AD&PP collapse, PAIR-03 EQI/EQII collapse, and PAIR-04 endpoint
% loss for PP->PU.

    [manifest, pairMap, container] = buildWp4SentinelContext();

    labels = manifest.labelGlossary.yang_label;
    for i = 1:numel(labels)
        row = manifest.bedSteps(manifest.bedSteps.yang_label == labels(i), :);
        assert(height(row) >= 1);
        selection = selectYangFourBedSingleState(container, row(1, :));
        translation = translateYangNativeOperation(selection, ...
            'AllowDiagnosticOnly', true);
        assert(isfield(translation, 'nativeRunnable'));
        assert(isfield(translation, 'nativeStepNames'));
        assert(isfield(translation, 'unsupportedReason'));
        assert(~any(ismember(string(translation.nativeStepNames), labels)));
    end

    pairs = pairMap.transferPairs;
    for i = 1:height(pairs)
        selection = selectYangFourBedPairStates(container, pairs(i, :));
        translation = translateYangNativeOperation(selection);
        assert(isfield(translation, 'directTransferFamily'));
        assert(translation.directTransferFamily == pairs.direct_transfer_family(i));
        assert(~any(ismember(string(translation.nativeStepNames), labels)));
    end

    ad = translateSingle(container, manifest, "AD");
    assert(ad.nativeRunnable);
    assert(ad.nativeStepNames == "HP-FEE-RAF");

    bd = translateSingle(container, manifest, "BD");
    assert(bd.nativeRunnable);
    assert(bd.nativeStepNames == "DP-ATM-XXX");

    eqi = translatePair(container, pairMap, "EQI", "B", "D");
    assert(eqi.nativeRunnable);
    assert(all(eqi.nativeStepNames == "EQ-XXX-APR"));
    assert(eqi.stageLabel == "EQI");
    assert(isequal(eqi.numAdsEqPrEnd, [2; 1]));

    eqii = translatePair(container, pairMap, "EQII", "A", "D");
    assert(eqii.nativeRunnable);
    assert(all(eqii.nativeStepNames == "EQ-XXX-APR"));
    assert(eqii.stageLabel == "EQII");

    ppPu = translatePair(container, pairMap, "PP_PU", "B", "A");
    assert(~ppPu.nativeRunnable);
    assert(ppPu.endpointPolicy.donorOutletEndpoint == "product_end");
    assert(ppPu.endpointPolicy.receiverInletEndpoint == "product_end");
    assert(ppPu.endpointPolicy.receiverWasteEndpoint == "feed_end");
    assert(strlength(ppPu.unsupportedReason) > 0);

    adppBf = translatePair(container, pairMap, "ADPP_BF", "A", "B");
    assert(~adppBf.nativeRunnable);
    assert(adppBf.endpointPolicy.externalProductSeparated);
    assert(adppBf.wrapperOperation ~= "external_adsorption_single_bed");

    fprintf('T-CASE translation coverage passed.\n');
end

function translation = translateSingle(container, manifest, yangLabel)
    row = manifest.bedSteps(manifest.bedSteps.yang_label == string(yangLabel), :);
    selection = selectYangFourBedSingleState(container, row(1, :));
    translation = translateYangNativeOperation(selection);
end

function translation = translatePair(container, pairMap, family, donor, receiver)
    pair = pairMap.transferPairs( ...
        pairMap.transferPairs.direct_transfer_family == string(family) & ...
        pairMap.transferPairs.donor_bed == string(donor) & ...
        pairMap.transferPairs.receiver_bed == string(receiver), :);
    assert(height(pair) == 1);
    selection = selectYangFourBedPairStates(container, pair);
    translation = translateYangNativeOperation(selection);
end

function [manifest, pairMap, container] = buildWp4SentinelContext()
    manifest = getYangFourBedScheduleManifest();
    pairMap = getYangDirectTransferPairMap(manifest);
    initialStates = buildSentinelStates();
    container = makeYangFourBedStateContainer(initialStates, ...
        'Manifest', manifest, ...
        'PairMap', pairMap, ...
        'InitializationPolicy', "unit_test_distinguishable_sentinel_states", ...
        'SourceNote', "T-CASE translation coverage sentinel states");
end

function states = buildSentinelStates()
    states = struct();
    states.state_A = struct("bed", "A", "payload", 101, "marker", "sentinel_A");
    states.state_B = struct("bed", "B", "payload", 202, "marker", "sentinel_B");
    states.state_C = struct("bed", "C", "payload", 303, "marker", "sentinel_C");
    states.state_D = struct("bed", "D", "payload", 404, "marker", "sentinel_D");
end
