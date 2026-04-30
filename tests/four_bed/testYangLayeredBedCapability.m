function testYangLayeredBedCapability()
%TESTYANGLAYEREDBEDCAPABILITY T-PARAM-01: layered-bed capability audit.
%
% Failure mode caught: PARAM-01/PARAM-02 assumption of Yang physical
% fidelity before layered activated-carbon/zeolite support is confirmed.

    manifest = getYangFourBedScheduleManifest();
    audit = auditYangLayeredBedSupport();

    allowed = ["confirmed", "not_confirmed_homogeneous_surrogate_required"];
    assert(ismember(audit.result, allowed));
    assert(audit.yangRequiresLayeredBed);
    assert(height(audit.layers) == 2);
    assert(isequal(audit.layers.material, ["activated_carbon"; "zeolite_5A"]));
    assert(isequal(audit.layers.height, [100; 70]));

    assert(isfield(manifest, 'layeredBedAudit'));
    assert(isfield(manifest.layeredBedAudit, 'result'));
    assert(ismember(manifest.layeredBedAudit.result, allowed));

    if audit.result == "not_confirmed_homogeneous_surrogate_required"
        assert(manifest.layeredBedAudit.result == audit.result);
    end

    fprintf('T-PARAM-01 passed: layered-bed capability is confirmed or explicitly labelled as surrogate.\n');
end
