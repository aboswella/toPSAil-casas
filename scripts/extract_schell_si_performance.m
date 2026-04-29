function si = extract_schell_si_performance(params, sol, cycleIndex)
%EXTRACT_SCHELL_SI_PERFORMANCE Reconstruct Schell SI subtraction accounting.
%
% Schell SI basis:
%   1. integrate component inventory entering pressurization, adsorption,
%      and purge,
%   2. integrate the H2-rich adsorption product directly from the column
%      product-end boundary,
%   3. calculate the CO2-rich product by component subtraction.
%
% This extractor is reporting-only. It does not change native toPSAil
% boundary conditions, purge semantics, source parameters, or thresholds.

    if nargin < 3 || isempty(cycleIndex)
        cycleIndex = floor(sol.lastStep / params.nSteps);
    end
    validateCycleIndex(params, sol, cycleIndex);

    components = string(params.sCom);
    h2Index = componentIndex(components, "H2");
    co2Index = componentIndex(components, "CO2");

    records = struct([]);
    totals = zeroTotals(params);
    nativeExternal = zeroNativeExternal(params);

    stepInit = (cycleIndex - 1) * params.nSteps + 1;
    stepFinal = cycleIndex * params.nSteps;

    for globalStep = stepInit:stepFinal
        step = sol.("Step" + globalStep);
        cycleStepIndex = mod(globalStep - 1, params.nSteps) + 1;
        stepNames = columnStepNames(params, step);
        feedTankAttribution = zeros(params.nCols, params.nComs);

        nativeExternal.feed_tank = nativeExternal.feed_tank ...
            + step.feTa.n1.cumMol.feed(end, :) .* params.nScaleFac;
        nativeExternal.raffinate_product = ...
            nativeExternal.raffinate_product ...
            + step.raTa.n1.cumMol.prod(end, :) .* params.nScaleFac;
        nativeExternal.extract_product = nativeExternal.extract_product ...
            + step.exTa.n1.cumMol.prod(end, :) .* params.nScaleFac;

        for columnIndex = 1:params.nCols
            columnName = params.sColNums{columnIndex};
            column = step.col.(columnName);
            stepName = stepNames(columnIndex);
            feedBoundary = column.cumMol.feed(end, :) .* params.nScaleFac;
            productBoundary = column.cumMol.prod(end, :) ...
                .* params.nScaleFac;

            record = makeEmptyRecord(params, cycleIndex, globalStep, ...
                cycleStepIndex, columnIndex, stepName, feedBoundary, ...
                productBoundary, feedTankAttribution(columnIndex, :));

            if stepName == "RP-FEE-XXX"
                record.pressurisation_input_moles_by_component = ...
                    positiveMoles(-feedBoundary);
                record.pressurization_input_moles_by_component = ...
                    record.pressurisation_input_moles_by_component;
                record.feed_tank_external_feed_moles_by_component = ...
                    record.pressurisation_input_moles_by_component;
            elseif stepName == "HP-FEE-RAF"
                record.adsorption_feed_input_moles_by_component = ...
                    positiveMoles(-feedBoundary);
                record.H2_rich_adsorption_product_moles_by_component = ...
                    positiveMoles(productBoundary);
                record.feed_tank_external_feed_moles_by_component = ...
                    record.adsorption_feed_input_moles_by_component;
            elseif stepName == "HP-ATM-FEE"
                record.purge_input_moles_by_component = ...
                    positiveMoles(-productBoundary);
                record.feed_tank_external_feed_moles_by_component = ...
                    record.purge_input_moles_by_component;
            elseif stepName == "LP-EXT-RAF"
                record.purge_input_moles_by_component = ...
                    positiveMoles(-productBoundary);
            end

            records = appendRecord(records, record);
            totals.pressurisation = totals.pressurisation ...
                + record.pressurisation_input_moles_by_component;
            totals.adsorption = totals.adsorption ...
                + record.adsorption_feed_input_moles_by_component;
            totals.purge = totals.purge ...
                + record.purge_input_moles_by_component;
            totals.H2_product = totals.H2_product ...
                + record.H2_rich_adsorption_product_moles_by_component;
            totals.feed_tank_external_attributed = ...
                totals.feed_tank_external_attributed ...
                + record.feed_tank_external_feed_moles_by_component;
        end
    end

    feedInput = totals.pressurisation + totals.adsorption + totals.purge;
    subtractionProduct = cleanTiny(feedInput - totals.H2_product, params);
    massBalanceResidual = cleanTiny(feedInput - totals.H2_product ...
        - subtractionProduct, params);
    aggregateMetrics = makeMetrics(feedInput, totals.H2_product, ...
        subtractionProduct, h2Index, co2Index);

    records = addColumnSubtractionMetrics(params, records, h2Index, co2Index);

    si.schema_version = "0.1.0";
    si.metrics_role = "validation_basis_candidate_schell_si";
    si.classification = "not_final_validation";
    si.metrics_basis = ...
        "Schell SI subtraction basis: H2-rich product from HP-FEE-RAF column product-end boundary; CO2-rich product by component-feed inventory minus H2-rich product.";
    si.validation_limitation = ...
        "Purge source uses native HP-ATM-FEE feed-tank inventory; metrics remain candidate validation outputs pending full soft-validation review.";
    si.cycle_index = cycleIndex;
    si.component_order = components;
    si.pressurisation_input_moles_by_component = totals.pressurisation;
    si.pressurization_input_moles_by_component = totals.pressurisation;
    si.adsorption_feed_input_moles_by_component = totals.adsorption;
    si.purge_input_moles_by_component = totals.purge;
    si.feed_input_moles_by_component = feedInput;
    si.H2_rich_adsorption_product_moles_by_component = totals.H2_product;
    si.Schell_basis_CO2_product_by_subtraction = subtractionProduct;
    si.mass_balance_residual_by_component = massBalanceResidual;
    si.native_feed_tank_external_feed_moles_by_component = ...
        nativeExternal.feed_tank;
    si.native_raffinate_external_product_moles_by_component = ...
        nativeExternal.raffinate_product;
    si.native_extract_external_product_moles_by_component = ...
        nativeExternal.extract_product;
    si.feed_tank_external_feed_attributed_to_press_ads_purge_moles_by_component = ...
        totals.feed_tank_external_attributed;
    si.feed_tank_external_feed_attributed_to_press_ads_moles_by_component = ...
        totals.pressurisation + totals.adsorption;
    si.aggregate = aggregateMetrics;
    si.native_direct_purity_recovery = nativeDirectMetrics(sol, cycleIndex);
    si.Schell_basis_purity_recovery = aggregateMetrics;
    si.column_records = records;
    si.accounting_notes = [
        "Feed inventory includes pressurisation and adsorption feed-end inflow plus HP-ATM-FEE purge inflow at the product-end boundary."
        "The native feed tank supplies Schell equimolar purge; native HP-ATM-FEE routes the feed-end purge outlet to extract waste rather than the extract product tank."
        "CO2-rich product is calculated by subtraction and is not taken from the native extract tank metric."
    ];
end

function validateCycleIndex(params, sol, cycleIndex)
    cyclesCompleted = floor(sol.lastStep / params.nSteps);
    if ~(isnumeric(cycleIndex) && isscalar(cycleIndex) ...
            && isfinite(cycleIndex) && cycleIndex == floor(cycleIndex) ...
            && cycleIndex >= 1 && cycleIndex <= cyclesCompleted)
        error("extract_schell_si_performance:badCycleIndex", ...
            "cycleIndex must select a complete simulated cycle.");
    end
end

function idx = componentIndex(components, name)
    idx = find(components == name, 1);
    if isempty(idx)
        error("extract_schell_si_performance:missingComponent", ...
            "Expected component %s in params.sCom.", name);
    end
end

function totals = zeroTotals(params)
    zerosRow = zeros(1, params.nComs);
    totals.pressurisation = zerosRow;
    totals.adsorption = zerosRow;
    totals.purge = zerosRow;
    totals.H2_product = zerosRow;
    totals.feed_tank_external_attributed = zerosRow;
end

function nativeExternal = zeroNativeExternal(params)
    zerosRow = zeros(1, params.nComs);
    nativeExternal.feed_tank = zerosRow;
    nativeExternal.raffinate_product = zerosRow;
    nativeExternal.extract_product = zerosRow;
end

function stepNames = columnStepNames(params, step)
    stepNames = strings(1, params.nCols);
    for columnIndex = 1:params.nCols
        stepNames(columnIndex) = string(step.timeFlags{end, columnIndex});
    end
end

function attribution = feedTankExternalAttribution(params, step, stepNames)
    attribution = zeros(params.nCols, params.nComs);
    feedConnected = stepNames == "RP-FEE-XXX" | stepNames == "HP-FEE-RAF";
    nFeedConnected = nnz(feedConnected);
    if nFeedConnected == 0
        return
    end

    stepFeed = step.feTa.n1.cumMol.feed(end, :) .* params.nScaleFac;
    for columnIndex = find(feedConnected)
        attribution(columnIndex, :) = stepFeed ./ nFeedConnected;
    end
end

function record = makeEmptyRecord(params, cycleIndex, globalStep, ...
    cycleStepIndex, columnIndex, stepName, feedBoundary, productBoundary, ...
    feedTankExternalFeed)

    zerosRow = zeros(1, params.nComs);
    record.cycle_index = cycleIndex;
    record.global_step_index = globalStep;
    record.cycle_step_index = cycleStepIndex;
    record.column_index = columnIndex;
    record.step_name = stepName;
    record.feed_end_boundary_moles_by_component = feedBoundary;
    record.product_end_boundary_moles_by_component = productBoundary;
    record.feed_tank_external_feed_moles_by_component = ...
        feedTankExternalFeed;
    record.pressurisation_input_moles_by_component = zerosRow;
    record.pressurization_input_moles_by_component = zerosRow;
    record.adsorption_feed_input_moles_by_component = zerosRow;
    record.purge_input_moles_by_component = zerosRow;
    record.feed_input_moles_by_component = zerosRow;
    record.H2_rich_adsorption_product_moles_by_component = zerosRow;
    record.Schell_basis_CO2_product_by_subtraction = zerosRow;
    record.mass_balance_residual_by_component = zerosRow;
    record.Schell_basis_purity_recovery = emptyMetrics();
end

function records = appendRecord(records, record)
    if isempty(records)
        records = record;
    else
        records(end + 1, 1) = record;
    end
end

function values = positiveMoles(values)
    values(values < 0) = 0;
end

function records = addColumnSubtractionMetrics(params, records, ...
    h2Index, co2Index)

    for i = 1:numel(records)
        feedInput = records(i).pressurisation_input_moles_by_component ...
            + records(i).adsorption_feed_input_moles_by_component ...
            + records(i).purge_input_moles_by_component;
        h2Product = records(i).H2_rich_adsorption_product_moles_by_component;
        subtractionProduct = cleanTiny(feedInput - h2Product, params);

        records(i).feed_input_moles_by_component = feedInput;
        records(i).Schell_basis_CO2_product_by_subtraction = ...
            subtractionProduct;
        records(i).mass_balance_residual_by_component = cleanTiny( ...
            feedInput - h2Product - subtractionProduct, params);
        records(i).Schell_basis_purity_recovery = makeMetrics( ...
            feedInput, h2Product, subtractionProduct, h2Index, co2Index);
    end
end

function metrics = makeMetrics(feedInput, h2Product, subtractionProduct, ...
    h2Index, co2Index)

    metrics.feed_input_moles_by_component = feedInput;
    metrics.H2_rich_adsorption_product_moles_by_component = h2Product;
    metrics.Schell_basis_CO2_product_by_subtraction = subtractionProduct;
    metrics.h2_purity_fraction = safeDivide(h2Product(h2Index), ...
        sum(h2Product));
    metrics.h2_recovery_fraction = safeDivide(h2Product(h2Index), ...
        feedInput(h2Index));
    metrics.co2_purity_fraction = safeDivide(subtractionProduct(co2Index), ...
        sum(subtractionProduct));
    metrics.co2_recovery_fraction = safeDivide(subtractionProduct(co2Index), ...
        feedInput(co2Index));
    metrics.h2_purity_pct = safePct(metrics.h2_purity_fraction);
    metrics.h2_recovery_pct = safePct(metrics.h2_recovery_fraction);
    metrics.co2_purity_pct = safePct(metrics.co2_purity_fraction);
    metrics.co2_recovery_pct = safePct(metrics.co2_recovery_fraction);
end

function native = nativeDirectMetrics(sol, cycleIndex)
    native.metrics_role = "diagnostic_native_direct";
    native.metrics_basis = ...
        "direct toPSAil native raffinate/extract external tank product metrics";
    native.h2_purity_pct = safePct(sol.perMet.productPurity(cycleIndex, 1));
    native.h2_recovery_pct = safePct( ...
        sol.perMet.productRecovery(cycleIndex, 1));
    native.co2_purity_pct = safePct(sol.perMet.productPurity(cycleIndex, 2));
    native.co2_recovery_pct = safePct( ...
        sol.perMet.productRecovery(cycleIndex, 2));
end

function metrics = emptyMetrics()
    metrics.feed_input_moles_by_component = [];
    metrics.H2_rich_adsorption_product_moles_by_component = [];
    metrics.Schell_basis_CO2_product_by_subtraction = [];
    metrics.h2_purity_fraction = missing;
    metrics.h2_recovery_fraction = missing;
    metrics.co2_purity_fraction = missing;
    metrics.co2_recovery_fraction = missing;
    metrics.h2_purity_pct = missing;
    metrics.h2_recovery_pct = missing;
    metrics.co2_purity_pct = missing;
    metrics.co2_recovery_pct = missing;
end

function value = safeDivide(numerator, denominator)
    if isfinite(numerator) && isfinite(denominator) && abs(denominator) > eps
        value = numerator ./ denominator;
    else
        value = missing;
    end
end

function value = safePct(fraction)
    if isnumeric(fraction) && isscalar(fraction) && isfinite(fraction)
        value = 100 .* fraction;
    else
        value = missing;
    end
end

function values = cleanTiny(values, params)
    tolerance = max(params.numZero, eps) * 100;
    values(abs(values) < tolerance) = 0;
end
