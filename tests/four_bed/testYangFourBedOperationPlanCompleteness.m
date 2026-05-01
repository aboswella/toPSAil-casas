function testYangFourBedOperationPlanCompleteness()
%TESTYANGFOURBEDOPERATIONPLANCOMPLETENESS FI-6 plan integrity.
%
% Tier: Unit/static. Final item: FI-6. Runtime class: < 10 s.
% Default smoke: no. Failure mode caught: manifest-column looping that
% misses explicit pair-map groups or breaks per-bed sequence order.

    manifest = getYangFourBedScheduleManifest();
    pairMap = getYangDirectTransferPairMap(manifest);
    durations = getYangNormalizedSlotDurations(250);
    plan = buildYangFourBedOperationPlan(manifest, pairMap, durations);

    assert(numel(plan.operationGroups) == 24);
    families = string({plan.operationGroups.operationFamily});
    for family = ["AD", "BD", "EQI", "EQII", "PP_PU", "ADPP_BF"]
        assert(sum(families == family) == 4);
    end

    participations = 0;
    for i = 1:numel(plan.operationGroups)
        participations = participations + numel(plan.operationGroups(i).participants);
        assert(strlength(plan.operationGroups(i).route) > 0);
        assert(isfinite(plan.operationGroups(i).durationSec));
        assert(plan.operationGroups(i).durationSec > 0);
    end
    assert(participations == 40);

    assertSequence(plan, "A", ["AD"; "AD&PP"; "EQI-BD"; "PP"; "EQII-BD"; ...
        "BD"; "PU"; "EQII-PR"; "EQI-PR"; "BF"]);
    assertSequence(plan, "B", ["EQI-PR"; "BF"; "AD"; "AD&PP"; "EQI-BD"; ...
        "PP"; "EQII-BD"; "BD"; "PU"; "EQII-PR"]);
    assertSequence(plan, "C", ["BD"; "PU"; "EQII-PR"; "EQI-PR"; "BF"; ...
        "AD"; "AD&PP"; "EQI-BD"; "PP"; "EQII-BD"]);
    assertSequence(plan, "D", ["EQI-BD"; "PP"; "EQII-BD"; "BD"; "PU"; ...
        "EQII-PR"; "EQI-PR"; "BF"; "AD"; "AD&PP"]);

    pairIds = string({plan.operationGroups.pairId});
    pairIds = pairIds(pairIds ~= "none");
    assert(isempty(setdiff(pairIds(:), string(pairMap.transferPairs.pair_id))));
    assert(isempty(setdiff(string(pairMap.transferPairs.pair_id), pairIds(:))));
    assert(any(strlength(plan.warnings) > 0));

    validation = validateYangFourBedOperationPlan(plan, manifest, pairMap);
    assert(validation.pass);

    fprintf('FI-6 operation plan completeness passed: 24 groups and 40 participations preserve per-bed order.\n');
end

function assertSequence(plan, bed, expected)
    actual = string(plan.perBedSequences.(char(bed)).yang_label);
    assert(isequal(actual(:), expected(:)));
end
