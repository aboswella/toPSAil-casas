function testYangNormalizedSlotDurations()
%TESTYANGNORMALIZEDSLOTDURATIONS T-STATIC-01: executable duration policy.
%
% Tier: Static/source. Runtime class: < 5 s. Default smoke: yes.
% Failure modes caught: SCHED-04 raw 24-unit basis revived for execution
% and SCHED-01 duration-unit transcription drift.

    cycleTimeSec = 250;
    units = [1; 6; 1; 4; 1; 1; 4; 1; 1; 5];

    d = getYangNormalizedSlotDurations(cycleTimeSec);

    assert(isequal(d.durationUnits(:), units));
    assert(abs(sum(d.durationFractions) - 1) < 1e-12);
    assert(abs(sum(d.durationSeconds) - cycleTimeSec) < 1e-12);
    assert(isequal(d.durationSeconds(:), cycleTimeSec * units / 25));
    assert(d.normalizationPolicy == ...
        "executable_fractions_sum_to_one_duration_units_over_25");
    assert(contains(d.rawDurationPolicy, "metadata"));

    expectInvalidCycleTime(0);
    expectInvalidCycleTime(-1);
    expectInvalidCycleTime(NaN);
    expectInvalidCycleTime([250, 251]);

    fprintf('T-STATIC-01 duration helper passed: executable Yang durations use units/25.\n');
end

function expectInvalidCycleTime(cycleTimeSec)
    failedAsExpected = false;
    try
        getYangNormalizedSlotDurations(cycleTimeSec);
    catch
        failedAsExpected = true;
    end

    assert(failedAsExpected);
end
