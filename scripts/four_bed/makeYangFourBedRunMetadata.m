function metadata = makeYangFourBedRunMetadata(manifest, pairMap, varargin)
%MAKEYANGFOURBEDRUNMETADATA Build WP5 run-output assumption metadata.
%
% The metadata is deliberately explicit about the wrapper assumptions so
% ledger/CSS reports cannot be mistaken for a Yang validation claim.

    if nargin < 1
        manifest = [];
    end
    if nargin < 2
        pairMap = [];
    end

    parser = inputParser;
    addParameter(parser, 'RunnerMode', "not_supplied");
    addParameter(parser, 'WrapperMode', "thin_four_bed_orchestration_layer");
    addParameter(parser, 'NumericalCommissioningStatus', "not_numerically_commissioned_wp5_ledger_first");
    addParameter(parser, 'LayeredBedPolicy', "");
    addParameter(parser, 'ThermalPolicy', "");
    addParameter(parser, 'Notes', "not_supplied");
    parse(parser, varargin{:});
    opts = parser.Results;

    manifestVersion = "not_supplied";
    layeredBedPolicy = "not_confirmed";
    thermalPolicy = "not_exercised";
    if isstruct(manifest)
        if isfield(manifest, 'version')
            manifestVersion = string(manifest.version);
        end
        if isfield(manifest, 'layeredBedAudit') && isstruct(manifest.layeredBedAudit)
            audit = manifest.layeredBedAudit;
            if isfield(audit, 'result')
                layeredBedPolicy = string(audit.result);
            end
            if isfield(audit, 'thermalMode')
                thermalPolicy = string(audit.thermalMode);
            end
        end
    end

    if strlength(string(opts.LayeredBedPolicy)) > 0
        layeredBedPolicy = string(opts.LayeredBedPolicy);
    end
    if strlength(string(opts.ThermalPolicy)) > 0
        thermalPolicy = string(opts.ThermalPolicy);
    end

    pairMapVersion = "not_supplied";
    if isstruct(pairMap) && isfield(pairMap, 'version')
        pairMapVersion = string(pairMap.version);
    end

    metadata = struct();
    metadata.version = "WP5-Yang2009-run-metadata-v1";
    metadata.createdBy = "Codex WP5 wrapper ledger/css/reporting layer";
    metadata.manifestVersion = manifestVersion;
    metadata.pairMapVersion = pairMapVersion;
    metadata.wrapperMode = string(opts.WrapperMode);
    metadata.holdupPolicy = "zero_holdup_direct_bed_to_bed_internal_transfers_no_dynamic_tanks_no_shared_header_inventory";
    metadata.internalTransferPolicy = "internal_transfers_are_not_external_product";
    metadata.statePolicy = "persistent_named_bed_states_A_B_C_D_only";
    metadata.caseBuilderPolicy = "temporary_single_or_two_local_bed_cases";
    metadata.eventPolicy = "fixed_duration_only";
    metadata.metricBasis = "external_feed_product_waste_ledger_internal_transfers_excluded";
    metadata.cssBasis = "all_persistent_bed_states_A_B_C_D_boundary_cumulative_flows_excluded_when_layout_known";
    metadata.nativeMetricPolicy = "native_metrics_diagnostic_not_yang_basis";
    metadata.layeredBedPolicy = layeredBedPolicy;
    metadata.thermalPolicy = thermalPolicy;
    metadata.modelMismatchPolicy = "do_not_claim_yang_validation_before_mismatch_register_complete";
    metadata.validationClaim = "ledger_css_reporting_commissioning_only";
    metadata.runnerMode = string(opts.RunnerMode);
    metadata.numericalCommissioningStatus = string(opts.NumericalCommissioningStatus);
    metadata.architectureFlags = struct( ...
        "noDynamicInternalTanks", true, ...
        "noSharedHeaderInventory", true, ...
        "noFourBedRhsDae", true, ...
        "noCoreAdsorberPhysicsRewrite", true, ...
        "internalTransfersExcludedFromExternalProduct", true, ...
        "fixedDurationOnly", true);
    metadata.notes = string(opts.Notes(:));
end
