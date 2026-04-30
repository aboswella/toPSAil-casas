function testYangRunMetadataAssumptions()
%TESTYANGRUNMETADATAASSUMPTIONS T-DOC-01 run metadata assumptions.
%
% Tier: Output/static. Runtime class: < 10 s. Default smoke: yes.
% Failure mode caught: DOC-01 hidden architecture or metric-basis
% assumptions in output artifacts.

    manifest = getYangFourBedScheduleManifest();
    pairMap = getYangDirectTransferPairMap(manifest);
    metadata = makeYangFourBedRunMetadata(manifest, pairMap, ...
        'RunnerMode', "synthetic_test", ...
        'Notes', "T-DOC-01 metadata assumption test");

    result = validateYangFourBedRunMetadata(metadata);
    assert(result.pass);
    assert(metadata.eventPolicy == "fixed_duration_only");
    assert(contains(metadata.internalTransferPolicy, "not_external_product"));
    assert(contains(metadata.metricBasis, "external"));
    assert(contains(metadata.validationClaim, "commissioning"));
    assert(metadata.architectureFlags.noDynamicInternalTanks);
    assert(metadata.architectureFlags.noSharedHeaderInventory);
    assert(metadata.architectureFlags.noFourBedRhsDae);

    missing = rmfield(metadata, 'metricBasis');
    missingResult = validateYangFourBedRunMetadata(missing);
    assert(~missingResult.pass);

    altered = metadata;
    altered.internalTransferPolicy = "internal_transfers_may_be_product";
    alteredResult = validateYangFourBedRunMetadata(altered);
    assert(~alteredResult.pass);

    fprintf('T-DOC-01 passed: run metadata exposes WP5 assumptions and rejects omissions.\n');
end
