function css = computeYangFourBedCssResiduals(initialContainer, finalContainer, varargin)
%COMPUTEYANGFOURBEDCSSRESIDUALS Compute all-bed WP5 CSS residuals.

    initialResult = validateYangFourBedStateContainer(initialContainer);
    if ~initialResult.pass
        error('WP5:InvalidInitialContainer', ...
            'Initial container failed WP3 validation: %s', ...
            char(strjoin(initialResult.failures, " | ")));
    end
    finalResult = validateYangFourBedStateContainer(finalContainer);
    if ~finalResult.pass
        error('WP5:InvalidFinalContainer', ...
            'Final container failed WP3 validation: %s', ...
            char(strjoin(finalResult.failures, " | ")));
    end

    parser = inputParser;
    addParameter(parser, 'Params', []);
    addParameter(parser, 'AbsTol', 1e-8);
    addParameter(parser, 'RelTol', 1e-6);
    addParameter(parser, 'NormType', "max_abs_relative");
    addParameter(parser, 'CycleIndex', NaN);
    parse(parser, varargin{:});
    opts = parser.Results;

    rows = table( ...
        zeros(0, 1), strings(0, 1), strings(0, 1), strings(0, 1), ...
        zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), ...
        false(0, 1), strings(0, 1), ...
        'VariableNames', [
            "cycle_index"
            "bed"
            "state_field"
            "family"
            "n_values"
            "max_abs"
            "rms_abs"
            "relative_norm"
            "pass"
            "notes"
        ]);

    bedLabels = string(initialContainer.bedLabels(:));
    for i = 1:numel(bedLabels)
        bed = bedLabels(i);
        stateField = "state_" + bed;
        bedRows = computeYangStateFamilyResiduals( ...
            initialContainer.(char(stateField)), ...
            finalContainer.(char(stateField)), ...
            'Params', opts.Params, ...
            'CycleIndex', opts.CycleIndex, ...
            'Bed', bed, ...
            'StateField', stateField, ...
            'AbsTol', opts.AbsTol, ...
            'RelTol', opts.RelTol);
        rows = [rows; bedRows]; %#ok<AGROW>
    end

    residuals = rows.relative_norm;
    residualsForControl = residuals;
    residualsForControl(isnan(residualsForControl)) = Inf;
    if isempty(residualsForControl)
        aggregateResidual = NaN;
        controllingBed = "none";
        controllingFamily = "none";
        pass = false;
    else
        [aggregateResidual, idx] = max(residualsForControl);
        controllingBed = string(rows.bed(idx));
        controllingFamily = string(rows.family(idx));
        pass = all(rows.pass);
    end

    css = struct();
    css.version = "WP5-Yang2009-css-residual-v1";
    css.pass = logical(pass);
    css.aggregateResidual = aggregateResidual;
    css.controllingBed = controllingBed;
    css.controllingFamily = controllingFamily;
    css.rows = rows;
    css.tolerances = struct( ...
        "absTol", opts.AbsTol, ...
        "relTol", opts.RelTol, ...
        "normType", string(opts.NormType));
    css.notes = "All persistent named beds A/B/C/D are checked over physical adsorber state only; temporary local cases and boundary counters are not CSS evidence.";
end
