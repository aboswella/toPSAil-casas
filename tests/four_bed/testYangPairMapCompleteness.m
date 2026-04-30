function testYangPairMapCompleteness()
%TESTYANGPAIRMAPCOMPLETENESS T-STATIC-02: direct-transfer pair map.
%
% Failure modes caught: PAIR-01 wrong or missing direct-transfer partners,
% SCHED-02 row-order/adjacency inference, PAIR-03 EQI/EQII collapse, and
% PAIR-04 missing PP->PU endpoint metadata.

    manifest = getYangFourBedScheduleManifest();
    pairMap = getYangDirectTransferPairMap(manifest);
    result = validateYangDirectTransferPairMap(pairMap, manifest);

    if ~result.pass
        disp(result.checks);
        disp(result.failures);
        error('WP2:TStatic02Failed', ...
            'T-STATIC-02 failed: Yang direct-transfer pair map is incomplete or inconsistent.');
    end

    pairs = pairMap.transferPairs;
    requiredRows = manifest.bedSteps(manifest.bedSteps.requires_pair_map, :);
    coveredRecordIds = [pairs.donor_record_id; pairs.receiver_record_id];

    assert(height(pairs) == 16);
    assert(numel(unique(coveredRecordIds)) == height(requiredRows));
    assert(all(ismember(requiredRows.record_id, coveredRecordIds)));

    assert(any(pairs.direct_transfer_family == "ADPP_BF" & ...
        pairs.donor_bed == "A" & pairs.receiver_bed == "B"));
    assert(any(pairs.direct_transfer_family == "EQI" & ...
        pairs.donor_bed == "A" & pairs.receiver_bed == "C"));
    assert(any(pairs.direct_transfer_family == "EQI" & ...
        pairs.donor_bed == "B" & pairs.receiver_bed == "D"));
    assert(any(pairs.direct_transfer_family == "EQII" & ...
        pairs.donor_bed == "A" & pairs.receiver_bed == "D"));
    assert(any(pairs.direct_transfer_family == "PP_PU" & ...
        pairs.donor_bed == "B" & pairs.receiver_bed == "A"));

    assert(any(pairs.direct_transfer_family == "PP_PU" & ...
        pairs.receiver_waste_endpoint == "feed_end"));
    assert(any(pairs.donor_source_col ~= pairs.receiver_source_col));

    eqiPairs = pairs(pairs.direct_transfer_family == "EQI", :);
    eqiiPairs = pairs(pairs.direct_transfer_family == "EQII", :);
    assert(height(eqiPairs) == 4);
    assert(height(eqiiPairs) == 4);
    assert(all(eqiPairs.donor_yang_label == "EQI-BD"));
    assert(all(eqiPairs.receiver_yang_label == "EQI-PR"));
    assert(all(eqiiPairs.donor_yang_label == "EQII-BD"));
    assert(all(eqiiPairs.receiver_yang_label == "EQII-PR"));

    fprintf('T-STATIC-02 passed: Yang direct-transfer pair map completeness.\n');
end
