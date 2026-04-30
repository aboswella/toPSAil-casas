function manifest = getYangFourBedScheduleManifest()
%GETYANGFOURBEDSCHEDULEMANIFEST Build the WP1 Yang four-bed manifest.
%
% The manifest is a static, self-contained schedule/metadata artifact. It
% does not call the solver, define pair identities, or create physical state.

    bedLabels = ["A", "B", "C", "D"];

    durationLabelRaw = [
        "t_c/24"
        "t_c/4"
        "t_c/24"
        "t_c/6"
        "t_c/24"
        "t_c/24"
        "t_c/6"
        "t_c/24"
        "t_c/24"
        "5t_c/24"
    ];

    durationUnitsT24 = arrayfun(@parseYangDurationLabel, durationLabelRaw);
    durationUnitsT24 = durationUnitsT24(:);
    rawStartUnitsT24 = [0; cumsum(durationUnitsT24(1:end-1))];
    rawEndUnitsT24 = cumsum(durationUnitsT24);
    rawUnitsPerDisplayedCycle = sum(durationUnitsT24);

    rawFractionOfTc = durationUnitsT24 ./ 24;
    normalizedFractionOfDisplayedCycle = durationUnitsT24 ./ rawUnitsPerDisplayedCycle;
    normalizedStart = rawStartUnitsT24 ./ rawUnitsPerDisplayedCycle;
    normalizedEnd = rawEndUnitsT24 ./ rawUnitsPerDisplayedCycle;

    bedALabel = ["AD"; "AD&PP"; "EQI-BD"; "PP"; "EQII-BD"; "BD"; "PU"; "EQII-PR"; "EQI-PR"; "BF"];
    bedBLabel = ["EQI-PR"; "BF"; "AD"; "AD&PP"; "EQI-BD"; "PP"; "EQII-BD"; "BD"; "PU"; "EQII-PR"];
    bedCLabel = ["BD"; "PU"; "EQII-PR"; "EQI-PR"; "BF"; "AD"; "AD&PP"; "EQI-BD"; "PP"; "EQII-BD"];
    bedDLabel = ["EQI-BD"; "PP"; "EQII-BD"; "BD"; "PU"; "EQII-PR"; "EQI-PR"; "BF"; "AD"; "AD&PP"];

    sourceCol = (1:10)';
    sourceNote = [
        "Source Table 2 row labels preserved; WP2 pair map required for EQI."
        "Compound AD&PP and direct-transfer-ready BF/PU/PP metadata preserved."
        "EQI-BD and EQII metadata remain distinct; no row-order pairing."
        "Displayed duration span normalized separately from raw source label."
        "Stage labels remain distinct even if future native calls are generic."
        "External BD and internal/external categories stay separated."
        "Longer source span normalized without event policy."
        "Terminal state ownership remains named-bed metadata for later WPs."
        "PP->PU transfer family marked internal; AD remains external."
        "AD&PP->BF transfer family marked internal while product flag remains external."
    ];

    sourceColumns = table( ...
        sourceCol, ...
        durationLabelRaw, ...
        durationUnitsT24, ...
        rawFractionOfTc, ...
        normalizedFractionOfDisplayedCycle, ...
        rawStartUnitsT24, ...
        rawEndUnitsT24, ...
        normalizedStart, ...
        normalizedEnd, ...
        bedALabel, ...
        bedBLabel, ...
        bedCLabel, ...
        bedDLabel, ...
        sourceNote, ...
        'VariableNames', [
            "source_col"
            "duration_label_raw"
            "duration_units_t24"
            "raw_fraction_of_tc"
            "normalized_fraction_of_displayed_cycle"
            "raw_start_units_t24"
            "raw_end_units_t24"
            "normalized_start"
            "normalized_end"
            "bed_A_label"
            "bed_B_label"
            "bed_C_label"
            "bed_D_label"
            "source_note"
        ]);

    labelGlossary = getYangLabelGlossary();
    pressureClasses = getYangPressureClassMap();
    bedSteps = buildBedSteps(sourceColumns, bedLabels, labelGlossary);

    manifest = struct();
    manifest.version = "WP1-Yang2009-Table2-v1";
    manifest.sourceName = "Yang et al. 2009 Table 2";
    manifest.sourceDocument = "sources/Yang 2009 4-bed 10-step relevant.pdf";
    manifest.bedLabels = bedLabels;

    manifest.architecture = struct( ...
        "noDynamicInternalTanks", true, ...
        "noSharedHeaderInventory", true, ...
        "noFourBedRhsDae", true, ...
        "noCoreAdsorberPhysicsRewrite", true, ...
        "pairingPolicy", "explicit_pair_map_required_no_row_order_inference", ...
        "eventPolicy", "fixed_duration_only", ...
        "wp1DefinesPairIdentities", false, ...
        "physicalStatePolicy", "no_physical_state_created_by_wp1_manifest" ...
    );

    manifest.duration = struct( ...
        "rawBasis", "Yang Table 2 labels", ...
        "unitLabel", "t_c/24", ...
        "rawUnitsPerDisplayedCycle", rawUnitsPerDisplayedCycle, ...
        "rawSumFractionOfTc", rawUnitsPerDisplayedCycle / 24, ...
        "normalizationPolicy", "preserve raw labels; expose normalized fractions; do not silently rescale source labels", ...
        "cycleTimeMappingPolicy", "later work packages must decide how simulation cycleTimeSec maps to Yang t_c" ...
    );

    manifest.sourceColumns = sourceColumns;
    manifest.bedSteps = bedSteps;
    manifest.labelGlossary = labelGlossary;
    manifest.pressureClasses = pressureClasses;
    manifest.layeredBedAudit = auditYangLayeredBedSupport();
end

function bedSteps = buildBedSteps(sourceColumns, bedLabels, glossary)
    nRows = height(sourceColumns) * numel(bedLabels);
    recordId = strings(nRows, 1);
    bed = strings(nRows, 1);
    sourceCol = zeros(nRows, 1);
    bedStepIndex = zeros(nRows, 1);
    yangLabel = strings(nRows, 1);
    durationLabelRaw = strings(nRows, 1);
    durationUnitsT24 = zeros(nRows, 1);
    rawFractionOfTc = zeros(nRows, 1);
    normalizedFractionOfDisplayedCycle = zeros(nRows, 1);
    rawStartUnitsT24 = zeros(nRows, 1);
    rawEndUnitsT24 = zeros(nRows, 1);
    operationFamily = strings(nRows, 1);
    roleClass = strings(nRows, 1);
    pressureMode = strings(nRows, 1);
    pStartClass = strings(nRows, 1);
    pEndClass = strings(nRows, 1);
    isCompound = false(nRows, 1);
    requiresPairMap = false(nRows, 1);
    directTransferFamily = strings(nRows, 1);
    externalFeed = false(nRows, 1);
    externalProduct = false(nRows, 1);
    externalWaste = false(nRows, 1);
    internalTransferCategory = strings(nRows, 1);
    sourceStepLetter = strings(nRows, 1);
    sourceStepName = strings(nRows, 1);
    notes = strings(nRows, 1);

    row = 0;
    for sourceIdx = 1:height(sourceColumns)
        for bedIdx = 1:numel(bedLabels)
            row = row + 1;
            currentBed = bedLabels(bedIdx);
            sourceLabel = sourceColumns.(sprintf('bed_%s_label', currentBed))(sourceIdx);
            glossaryRow = glossary(glossary.yang_label == sourceLabel, :);
            if height(glossaryRow) ~= 1
                error('WP1:MissingYangLabelGlossaryEntry', ...
                    'Expected exactly one glossary row for Yang label %s.', char(sourceLabel));
            end

            recordId(row) = sprintf('%s-%02d', currentBed, sourceIdx);
            bed(row) = currentBed;
            sourceCol(row) = sourceColumns.source_col(sourceIdx);
            bedStepIndex(row) = sourceIdx;
            yangLabel(row) = sourceLabel;
            durationLabelRaw(row) = sourceColumns.duration_label_raw(sourceIdx);
            durationUnitsT24(row) = sourceColumns.duration_units_t24(sourceIdx);
            rawFractionOfTc(row) = sourceColumns.raw_fraction_of_tc(sourceIdx);
            normalizedFractionOfDisplayedCycle(row) = sourceColumns.normalized_fraction_of_displayed_cycle(sourceIdx);
            rawStartUnitsT24(row) = sourceColumns.raw_start_units_t24(sourceIdx);
            rawEndUnitsT24(row) = sourceColumns.raw_end_units_t24(sourceIdx);
            operationFamily(row) = glossaryRow.operation_family;
            roleClass(row) = glossaryRow.role_class;
            pressureMode(row) = glossaryRow.pressure_mode;
            pStartClass(row) = glossaryRow.p_start_class;
            pEndClass(row) = glossaryRow.p_end_class;
            isCompound(row) = glossaryRow.is_compound;
            requiresPairMap(row) = glossaryRow.requires_pair_map;
            directTransferFamily(row) = glossaryRow.direct_transfer_family;
            externalFeed(row) = glossaryRow.external_feed;
            externalProduct(row) = glossaryRow.external_product;
            externalWaste(row) = glossaryRow.external_waste;
            internalTransferCategory(row) = glossaryRow.internal_transfer_category;
            sourceStepLetter(row) = glossaryRow.source_step_letter;
            sourceStepName(row) = glossaryRow.source_step_name;
            notes(row) = glossaryRow.notes;
        end
    end

    bedSteps = table( ...
        recordId, ...
        bed, ...
        sourceCol, ...
        bedStepIndex, ...
        yangLabel, ...
        durationLabelRaw, ...
        durationUnitsT24, ...
        rawFractionOfTc, ...
        normalizedFractionOfDisplayedCycle, ...
        rawStartUnitsT24, ...
        rawEndUnitsT24, ...
        operationFamily, ...
        roleClass, ...
        pressureMode, ...
        pStartClass, ...
        pEndClass, ...
        isCompound, ...
        requiresPairMap, ...
        directTransferFamily, ...
        externalFeed, ...
        externalProduct, ...
        externalWaste, ...
        internalTransferCategory, ...
        sourceStepLetter, ...
        sourceStepName, ...
        notes, ...
        'VariableNames', [
            "record_id"
            "bed"
            "source_col"
            "bed_step_index"
            "yang_label"
            "duration_label_raw"
            "duration_units_t24"
            "raw_fraction_of_tc"
            "normalized_fraction_of_displayed_cycle"
            "raw_start_units_t24"
            "raw_end_units_t24"
            "operation_family"
            "role_class"
            "pressure_mode"
            "p_start_class"
            "p_end_class"
            "is_compound"
            "requires_pair_map"
            "direct_transfer_family"
            "external_feed"
            "external_product"
            "external_waste"
            "internal_transfer_category"
            "source_step_letter"
            "source_step_name"
            "notes"
        ]);
end
