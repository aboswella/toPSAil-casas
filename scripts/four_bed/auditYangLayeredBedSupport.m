function audit = auditYangLayeredBedSupport()
%AUDITYANGLAYEREDBEDSUPPORT Record WP1 layered-bed capability status.
%
% WP1 does not implement layered-bed physics. The conservative result below
% prevents later reports from claiming a physically faithful Yang reproduction
% before axial material assignment is confirmed.

    audit = struct();
    audit.testId = "T-PARAM-01";
    audit.yangRequiresLayeredBed = true;
    audit.layers = table( ...
        ["activated_carbon"; "zeolite_5A"], ...
        [100; 70], ...
        ["cm"; "cm"], ...
        ["feed-end layer"; "above activated carbon layer"], ...
        'VariableNames', [
            "material"
            "height"
            "unit"
            "position"
        ]);

    audit.toPSAilLayeredSupportStatus = "not_confirmed";
    audit.result = "not_confirmed_homogeneous_surrogate_required";
    audit.nearTermLayeredBedPolicy = "not_incorporated_for_now";
    audit.thermalMode = "not_exercised_static_manifest_task";
    audit.sourceBasis = "Yang 2009 local PDF: experiment section states 100 cm activated carbon and 70 cm zeolite 5A layered bed.";
    audit.notes = [
        "WP1 does not modify adsorber physics."
        "Current project decision: layered beds will not be incorporated for now."
        "Repo inspection did not identify a clear WP1-level axial material assignment contract."
        "Near-term Yang comparison must be labelled as a homogeneous surrogate."
    ];
end
