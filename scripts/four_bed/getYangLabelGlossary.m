function glossary = getYangLabelGlossary()
%GETYANGLABELGLOSSARY Return WP1 operation metadata for Yang Table 2 labels.
%
% The glossary preserves Yang labels and separates source semantics from
% future WP2 pair identities.

    yangLabel = [
        "AD"
        "AD&PP"
        "EQI-BD"
        "PP"
        "EQII-BD"
        "BD"
        "PU"
        "EQII-PR"
        "EQI-PR"
        "BF"
    ];

    sourceStepLetter = ["a"; "b"; "c"; "d"; "e"; "f"; "g"; "h"; "i"; "j"];

    sourceStepName = [
        "Adsorption"
        "Adsorption and provide pressurization"
        "First pressure equalization, blowdown side"
        "Provide purge"
        "Second pressure equalization, blowdown side"
        "Blowdown"
        "Purge"
        "Second pressure equalization, pressurization side"
        "First pressure equalization, pressurization side"
        "Backfill"
    ];

    meaning = [
        "Feed gas enters at adsorption pressure and hydrogen-rich product exits the product end."
        "Adsorption continues while part of product-end gas pressurizes a companion bed undergoing BF."
        "Cocurrent depressurization to the first intermediate pressure; gas goes to an EQI-PR receiver."
        "Cocurrent depressurization provides purge gas to a companion bed undergoing PU."
        "Further cocurrent depressurization; gas goes to an EQII-PR receiver."
        "Countercurrent depressurization to the lowest pressure through the waste outlet."
        "Countercurrent purge using gas from a PP donor bed; waste exits externally."
        "Pressurization from low pressure using gas from an EQII-BD donor."
        "Further pressurization using gas from an EQI-BD donor."
        "Final pressurization using gas from a bed undergoing AD&PP."
    ];

    operationFamily = [
        "adsorption"
        "adsorption_and_backfill_donor"
        "first_pressure_equalization"
        "provide_purge"
        "second_pressure_equalization"
        "blowdown"
        "purge"
        "second_pressure_equalization"
        "first_pressure_equalization"
        "backfill"
    ];

    roleClass = [
        "external_single"
        "compound_donor"
        "donor"
        "donor"
        "donor"
        "external_waste_single"
        "receiver_with_external_waste"
        "receiver"
        "receiver"
        "receiver"
    ];

    pStart = ["PF"; "PF"; "PF"; "P1"; "P2"; "P3"; "P4"; "P4"; "P5"; "P6"];
    pEnd   = ["PF"; "PF"; "P1"; "P2"; "P3"; "P4"; "P4"; "P5"; "P6"; "PF"];
    pressureMode = pStart + " -> " + pEnd;

    isCompound = [false; true; false; false; false; false; false; false; false; false];
    requiresPairMap = [false; true; true; true; true; false; true; true; true; true];

    directTransferFamily = [
        "none"
        "ADPP_BF"
        "EQI"
        "PP_PU"
        "EQII"
        "none"
        "PP_PU"
        "EQII"
        "EQI"
        "ADPP_BF"
    ];

    externalFeed = [true; true; false; false; false; false; false; false; false; false];
    externalProduct = [true; true; false; false; false; false; false; false; false; false];
    externalWaste = [false; false; false; false; false; true; true; false; false; false];

    internalTransferCategory = [
        "none"
        "backfill_donor"
        "equalization_donor"
        "provide_purge_donor"
        "equalization_donor"
        "none"
        "provide_purge_receiver"
        "equalization_receiver"
        "equalization_receiver"
        "backfill_receiver"
    ];

    alias = [
        ""
        "AD and PP"
        ""
        ""
        ""
        ""
        "PG"
        ""
        ""
        ""
    ];

    notes = [
        "External adsorption/product operation; no WP2 pair identity is required."
        "Compound operation: external adsorption/product plus internal BF donor semantics."
        "EQI must remain distinct from EQII in manifest and ledger metadata."
        "PP means provide-purge, not generic product pressurization."
        "EQII must remain distinct from EQI in manifest and ledger metadata."
        "External waste step."
        "Schedule label is PU; Yang prose may refer to purge as PG. Step d and boundary-condition notation support PP->PU; a prose cross-reference ambiguity is tracked in KNOWN_UNCERTAINTIES."
        "Receiver role for second equalization."
        "Receiver role for first equalization."
        "Receiver role for AD&PP backfill gas."
    ];

    glossary = table( ...
        yangLabel, ...
        sourceStepLetter, ...
        sourceStepName, ...
        meaning, ...
        operationFamily, ...
        roleClass, ...
        pressureMode, ...
        pStart, ...
        pEnd, ...
        isCompound, ...
        requiresPairMap, ...
        directTransferFamily, ...
        externalFeed, ...
        externalProduct, ...
        externalWaste, ...
        internalTransferCategory, ...
        alias, ...
        notes, ...
        'VariableNames', [
            "yang_label"
            "source_step_letter"
            "source_step_name"
            "meaning"
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
            "alias"
            "notes"
        ]);
end
