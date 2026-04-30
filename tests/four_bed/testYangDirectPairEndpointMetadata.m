function testYangDirectPairEndpointMetadata()
%TESTYANGDIRECTPAIRENDPOINTMETADATA WP4 endpoint metadata audit.
%
% Tier: Unit. Runtime class: < 10 s. Default smoke: yes.
% Failure modes caught: PAIR-02 donor/receiver inversion, PAIR-03 EQI/EQII
% metadata collapse, and PAIR-04 PP->PU endpoint/waste confusion.

    [~, pairMap, container] = buildWp4SentinelContext();

    eqiCase = makeYangTemporaryPairedCase( ...
        selectPair(container, pairMap, "EQI", "B", "D"), ...
        'DurationSeconds', 1);
    assert(eqiCase.localMap.local_role(1) == "donor");
    assert(eqiCase.localMap.local_role(2) == "receiver");
    assert(eqiCase.native.endpointPolicy.donorOutletEndpoint == "product_end");
    assert(eqiCase.native.endpointPolicy.receiverInletEndpoint == "product_end");
    assert(eqiCase.native.endpointPolicy.receiverWasteEndpoint == "none");
    assert(eqiCase.native.stageLabel == "EQI");
    assert(isequal(eqiCase.native.numAdsEqPrEnd, [2; 1]));

    eqiiCase = makeYangTemporaryPairedCase( ...
        selectPair(container, pairMap, "EQII", "A", "D"), ...
        'DurationSeconds', 1);
    assert(eqiiCase.native.endpointPolicy.donorOutletEndpoint == "product_end");
    assert(eqiiCase.native.endpointPolicy.receiverInletEndpoint == "product_end");
    assert(eqiiCase.native.endpointPolicy.receiverWasteEndpoint == "none");
    assert(eqiiCase.native.stageLabel == "EQII");
    assert(eqiiCase.native.stageLabel ~= eqiCase.native.stageLabel);
    assert(isequal(eqiiCase.native.numAdsEqPrEnd, [2; 1]));

    ppCase = makeYangTemporaryPairedCase( ...
        selectPair(container, pairMap, "PP_PU", "B", "A"), ...
        'DurationSeconds', 1);
    assert(ppCase.native.endpointPolicy.donorOutletEndpoint == "product_end");
    assert(ppCase.native.endpointPolicy.receiverInletEndpoint == "product_end");
    assert(ppCase.native.endpointPolicy.receiverWasteEndpoint == "feed_end");
    assert(~ppCase.native.nativeRunnable);
    assert(strlength(ppCase.native.unsupportedReason) > 0);

    adppCase = makeYangTemporaryPairedCase( ...
        selectPair(container, pairMap, "ADPP_BF", "A", "B"), ...
        'DurationSeconds', 1);
    assert(adppCase.localMap.yang_label(1) == "AD&PP");
    assert(adppCase.localMap.yang_label(2) == "BF");
    assert(adppCase.native.endpointPolicy.donorOutletEndpoint == "product_end");
    assert(adppCase.native.endpointPolicy.receiverInletEndpoint == "product_end");
    assert(adppCase.native.endpointPolicy.externalProductSeparated);
    assert(~adppCase.native.nativeRunnable);
    assert(strlength(adppCase.native.unsupportedReason) > 0);

    fprintf('T-PAIR endpoint metadata passed: direct-transfer endpoint roles are explicit.\n');
end

function selection = selectPair(container, pairMap, family, donor, receiver)
    pair = pairMap.transferPairs( ...
        pairMap.transferPairs.direct_transfer_family == string(family) & ...
        pairMap.transferPairs.donor_bed == string(donor) & ...
        pairMap.transferPairs.receiver_bed == string(receiver), :);
    assert(height(pair) == 1);
    selection = selectYangFourBedPairStates(container, pair);
end

function [manifest, pairMap, container] = buildWp4SentinelContext()
    manifest = getYangFourBedScheduleManifest();
    pairMap = getYangDirectTransferPairMap(manifest);
    initialStates = buildSentinelStates();
    container = makeYangFourBedStateContainer(initialStates, ...
        'Manifest', manifest, ...
        'PairMap', pairMap, ...
        'InitializationPolicy', "unit_test_distinguishable_sentinel_states", ...
        'SourceNote', "T-PAIR endpoint synthetic sentinel states");
end

function states = buildSentinelStates()
    states = struct();
    states.state_A = struct("bed", "A", "payload", 101, "marker", "sentinel_A");
    states.state_B = struct("bed", "B", "payload", 202, "marker", "sentinel_B");
    states.state_C = struct("bed", "C", "payload", 303, "marker", "sentinel_C");
    states.state_D = struct("bed", "D", "payload", 404, "marker", "sentinel_D");
end
