function duration = getYangNormalizedSlotDurations(cycleTimeSec)
%GETYANGNORMALIZEDSLOTDURATIONS Return executable Yang slot durations.
%
% Yang Table 2 raw duration labels are retained as source metadata, but the
% executable fixed-duration policy normalizes the displayed units over their
% 25-unit sum.

    validateattributes(cycleTimeSec, {'numeric'}, ...
        {'scalar', 'real', 'finite', 'positive'}, mfilename, 'cycleTimeSec');

    sourceCol = (1:10)';
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
    durationUnits = [1; 6; 1; 4; 1; 1; 4; 1; 1; 5];
    durationFractions = durationUnits ./ sum(durationUnits);
    durationSeconds = cycleTimeSec .* durationFractions;

    duration = struct();
    duration.version = "FI1-Yang2009-normalized-slot-durations-v1";
    duration.sourceName = "Yang et al. 2009 Table 2";
    duration.cycleTimeSec = cycleTimeSec;
    duration.sourceCol = sourceCol;
    duration.durationLabelRaw = durationLabelRaw;
    duration.durationUnits = durationUnits;
    duration.durationFractions = durationFractions;
    duration.durationSeconds = durationSeconds;
    duration.normalizationPolicy = ...
        "executable_fractions_sum_to_one_duration_units_over_25";
    duration.cycleTimeMappingPolicy = ...
        "durationSeconds = cycleTimeSec * durationFractions";
    duration.rawDurationPolicy = ...
        "raw_t_c_over_24_labels_are_source_metadata_not_execution_basis";
    duration.slotTable = table( ...
        sourceCol, ...
        durationLabelRaw, ...
        durationUnits, ...
        durationFractions, ...
        durationSeconds, ...
        'VariableNames', [
            "source_col"
            "duration_label_raw"
            "duration_units"
            "duration_fraction"
            "duration_seconds"
        ]);
end
