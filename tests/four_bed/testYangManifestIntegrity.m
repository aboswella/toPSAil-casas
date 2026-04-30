function testYangManifestIntegrity()
%TESTYANGMANIFESTINTEGRITY T-STATIC-01: Yang manifest integrity.
%
% Failure modes caught: SCHED-01 transcription errors, SCHED-03 AD&PP
% collapse, SCHED-04 duration normalization drift, PAIR-03 EQI/EQII
% collapse, and ARCH-01 hidden dynamic-tank/header metadata.

    manifest = getYangFourBedScheduleManifest();
    result = validateYangFourBedScheduleManifest(manifest);

    if ~result.pass
        disp(result.checks);
        disp(result.failures);
        error('WP1:TStatic01Failed', ...
            'T-STATIC-01 failed: Yang manifest integrity check failed.');
    end

    assert(height(manifest.sourceColumns) == 10);
    assert(height(manifest.bedSteps) == 40);
    assert(isequal(manifest.bedLabels, ["A", "B", "C", "D"]));

    adpp = manifest.labelGlossary(manifest.labelGlossary.yang_label == "AD&PP", :);
    assert(height(adpp) == 1);
    assert(adpp.is_compound(1));
    assert(adpp.requires_pair_map(1));
    assert(adpp.direct_transfer_family(1) == "ADPP_BF");

    eqiRows = manifest.bedSteps(manifest.bedSteps.direct_transfer_family == "EQI", :);
    eqiiRows = manifest.bedSteps(manifest.bedSteps.direct_transfer_family == "EQII", :);
    assert(~isempty(eqiRows));
    assert(~isempty(eqiiRows));

    assert(manifest.duration.rawUnitsPerDisplayedCycle == 25);
    assert(abs(manifest.duration.rawSumFractionOfTc - 25/24) < 1e-12);
    assert(abs(sum(manifest.sourceColumns.normalized_fraction_of_displayed_cycle) - 1) < 1e-12);

    forbiddenPartnerVars = [
        "partner_bed"
        "paired_with"
        "donor_bed"
        "receiver_bed"
        "partnerBed"
        "pairedWith"
        "donorBed"
        "receiverBed"
    ];
    assert(isempty(intersect( ...
        lower(string(manifest.bedSteps.Properties.VariableNames)), ...
        lower(forbiddenPartnerVars))));

    fprintf('T-STATIC-01 passed: Yang manifest integrity.\n');
end
