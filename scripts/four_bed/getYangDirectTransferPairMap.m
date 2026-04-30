function pairMap = getYangDirectTransferPairMap(manifest)
%GETYANGDIRECTTRANSFERPAIRMAP Build WP2 direct-transfer bed pair identities.
%
% The pair map is static wrapper metadata. It assigns named bed partners for
% Yang internal direct transfers but does not create state, tanks, ledgers,
% events, or solver calls.

    if nargin < 1 || isempty(manifest)
        manifest = getYangFourBedScheduleManifest();
    end

    if ~isstruct(manifest) || ~isfield(manifest, "bedSteps")
        error('WP2:InvalidManifest', ...
            'Expected a WP1 manifest struct with a bedSteps table.');
    end

    bedSteps = manifest.bedSteps;
    pairSpec = buildPairSpec();
    endpointMetadata = buildEndpointMetadata();

    nPairs = height(pairSpec);
    pairId = strings(nPairs, 1);
    directTransferFamily = strings(nPairs, 1);
    donorBed = strings(nPairs, 1);
    receiverBed = strings(nPairs, 1);
    donorRecordId = strings(nPairs, 1);
    receiverRecordId = strings(nPairs, 1);
    donorSourceCol = zeros(nPairs, 1);
    receiverSourceCol = zeros(nPairs, 1);
    donorYangLabel = strings(nPairs, 1);
    receiverYangLabel = strings(nPairs, 1);
    donorRoleClass = strings(nPairs, 1);
    receiverRoleClass = strings(nPairs, 1);
    donorPStartClass = strings(nPairs, 1);
    donorPEndClass = strings(nPairs, 1);
    receiverPStartClass = strings(nPairs, 1);
    receiverPEndClass = strings(nPairs, 1);
    donorInternalTransferCategory = strings(nPairs, 1);
    receiverInternalTransferCategory = strings(nPairs, 1);
    donorOutletEndpoint = strings(nPairs, 1);
    receiverInletEndpoint = strings(nPairs, 1);
    receiverWasteEndpoint = strings(nPairs, 1);
    transferAccountingCategory = strings(nPairs, 1);
    sourceBasisNote = strings(nPairs, 1);

    for row = 1:nPairs
        family = pairSpec.direct_transfer_family(row);
        donor = findManifestRoleRow(bedSteps, family, pairSpec.donor_bed(row), ...
            ["donor", "compound_donor"]);
        receiver = findManifestRoleRow(bedSteps, family, pairSpec.receiver_bed(row), ...
            ["receiver", "receiver_with_external_waste"]);
        endpoint = endpointMetadata(endpointMetadata.direct_transfer_family == family, :);

        pairId(row) = sprintf('%s-%s-to-%s', family, donor.bed(1), receiver.bed(1));
        directTransferFamily(row) = family;
        donorBed(row) = donor.bed(1);
        receiverBed(row) = receiver.bed(1);
        donorRecordId(row) = donor.record_id(1);
        receiverRecordId(row) = receiver.record_id(1);
        donorSourceCol(row) = donor.source_col(1);
        receiverSourceCol(row) = receiver.source_col(1);
        donorYangLabel(row) = donor.yang_label(1);
        receiverYangLabel(row) = receiver.yang_label(1);
        donorRoleClass(row) = donor.role_class(1);
        receiverRoleClass(row) = receiver.role_class(1);
        donorPStartClass(row) = donor.p_start_class(1);
        donorPEndClass(row) = donor.p_end_class(1);
        receiverPStartClass(row) = receiver.p_start_class(1);
        receiverPEndClass(row) = receiver.p_end_class(1);
        donorInternalTransferCategory(row) = donor.internal_transfer_category(1);
        receiverInternalTransferCategory(row) = receiver.internal_transfer_category(1);
        donorOutletEndpoint(row) = endpoint.donor_outlet_endpoint(1);
        receiverInletEndpoint(row) = endpoint.receiver_inlet_endpoint(1);
        receiverWasteEndpoint(row) = endpoint.receiver_waste_endpoint(1);
        transferAccountingCategory(row) = endpoint.transfer_accounting_category(1);
        sourceBasisNote(row) = pairSpec.source_basis_note(row);
    end

    transferPairs = table( ...
        pairId, ...
        directTransferFamily, ...
        donorBed, ...
        receiverBed, ...
        donorRecordId, ...
        receiverRecordId, ...
        donorSourceCol, ...
        receiverSourceCol, ...
        donorYangLabel, ...
        receiverYangLabel, ...
        donorRoleClass, ...
        receiverRoleClass, ...
        donorPStartClass, ...
        donorPEndClass, ...
        receiverPStartClass, ...
        receiverPEndClass, ...
        donorInternalTransferCategory, ...
        receiverInternalTransferCategory, ...
        donorOutletEndpoint, ...
        receiverInletEndpoint, ...
        receiverWasteEndpoint, ...
        transferAccountingCategory, ...
        sourceBasisNote, ...
        'VariableNames', [
            "pair_id"
            "direct_transfer_family"
            "donor_bed"
            "receiver_bed"
            "donor_record_id"
            "receiver_record_id"
            "donor_source_col"
            "receiver_source_col"
            "donor_yang_label"
            "receiver_yang_label"
            "donor_role_class"
            "receiver_role_class"
            "donor_p_start_class"
            "donor_p_end_class"
            "receiver_p_start_class"
            "receiver_p_end_class"
            "donor_internal_transfer_category"
            "receiver_internal_transfer_category"
            "donor_outlet_endpoint"
            "receiver_inlet_endpoint"
            "receiver_waste_endpoint"
            "transfer_accounting_category"
            "source_basis_note"
        ]);

    pairMap = struct();
    pairMap.version = "WP2-Yang2009-direct-transfer-pair-map-v1";
    pairMap.manifestVersion = string(manifest.version);
    pairMap.sourceName = "Yang et al. 2009 Table 2 and process description";
    pairMap.sourceDocument = string(manifest.sourceDocument);
    pairMap.bedLabels = string(manifest.bedLabels);
    pairMap.pairingPolicy = "explicit_cyclic_map_no_row_order_or_adjacency_inference";
    pairMap.holdupPolicy = "zero_holdup_direct_bed_to_bed_no_dynamic_tanks_no_shared_header_inventory";
    pairMap.eventPolicy = "fixed_duration_only";
    pairMap.sourceNotes = [
        "WP2 consumes manifest.bedSteps rows where requires_pair_map is true."
        "Pair identities use the user-confirmed cyclic map; source columns may differ because WP1 preserves displayed Yang schedule spans."
        "PP->PU follows the workflow decision despite the Yang prose cross-reference ambiguity recorded in KNOWN_UNCERTAINTIES."
        "The pair map is metadata for later temporary paired-bed calls; it does not invoke solver machinery."
    ];
    pairMap.architecture = struct( ...
        "noDynamicInternalTanks", true, ...
        "noSharedHeaderInventory", true, ...
        "noFourBedRhsDae", true, ...
        "noCoreAdsorberPhysicsRewrite", true, ...
        "wp2DefinesPairIdentities", true, ...
        "wp2CreatesPhysicalState", false, ...
        "wp2InvokesSolver", false ...
    );
    pairMap.endpointMetadata = endpointMetadata;
    pairMap.transferPairs = transferPairs;
end

function pairSpec = buildPairSpec()
    directTransferFamily = [
        "ADPP_BF"; "ADPP_BF"; "ADPP_BF"; "ADPP_BF"
        "EQI"; "EQI"; "EQI"; "EQI"
        "EQII"; "EQII"; "EQII"; "EQII"
        "PP_PU"; "PP_PU"; "PP_PU"; "PP_PU"
    ];

    donorBed = [
        "A"; "B"; "C"; "D"
        "A"; "B"; "C"; "D"
        "A"; "B"; "C"; "D"
        "A"; "B"; "C"; "D"
    ];

    receiverBed = [
        "B"; "C"; "D"; "A"
        "C"; "D"; "A"; "B"
        "D"; "A"; "B"; "C"
        "D"; "A"; "B"; "C"
    ];

    sourceBasisNote = repmat( ...
        "Explicit WP2 cyclic pair identity; not inferred from source table row order, bed adjacency, or native two-bed defaults.", ...
        numel(directTransferFamily), 1);

    pairSpec = table( ...
        directTransferFamily, ...
        donorBed, ...
        receiverBed, ...
        sourceBasisNote, ...
        'VariableNames', [
            "direct_transfer_family"
            "donor_bed"
            "receiver_bed"
            "source_basis_note"
        ]);
end

function endpointMetadata = buildEndpointMetadata()
    directTransferFamily = ["ADPP_BF"; "EQI"; "EQII"; "PP_PU"];
    donorOutletEndpoint = ["product_end"; "product_end"; "product_end"; "product_end"];
    receiverInletEndpoint = ["product_end"; "product_end"; "product_end"; "product_end"];
    receiverWasteEndpoint = ["none"; "none"; "none"; "feed_end"];
    transferAccountingCategory = [
        "internal_backfill"
        "internal_equalization_I"
        "internal_equalization_II"
        "internal_provide_purge"
    ];
    endpointNote = [
        "AD&PP donor supplies BF gas from product-end product while external product remains separate for later ledgers."
        "EQI-BD product-end gas pressurizes the EQI-PR receiver."
        "EQII-BD product-end gas pressurizes the EQII-PR receiver."
        "PP donor product-end gas purges the PU receiver countercurrently; PU waste exits the feed end."
    ];

    endpointMetadata = table( ...
        directTransferFamily, ...
        donorOutletEndpoint, ...
        receiverInletEndpoint, ...
        receiverWasteEndpoint, ...
        transferAccountingCategory, ...
        endpointNote, ...
        'VariableNames', [
            "direct_transfer_family"
            "donor_outlet_endpoint"
            "receiver_inlet_endpoint"
            "receiver_waste_endpoint"
            "transfer_accounting_category"
            "endpoint_note"
        ]);
end

function row = findManifestRoleRow(bedSteps, family, bedLabel, roleClasses)
    row = bedSteps( ...
        bedSteps.direct_transfer_family == family & ...
        bedSteps.bed == bedLabel & ...
        ismember(bedSteps.role_class, roleClasses), :);

    if height(row) ~= 1
        error('WP2:PairMapManifestLookupFailed', ...
            'Expected exactly one %s row for bed %s in direct-transfer family %s.', ...
            char(strjoin(roleClasses, "/")), char(bedLabel), char(family));
    end
end
