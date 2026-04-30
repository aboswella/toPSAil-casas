function [terminalLocalStates, report] = makeYangTemporaryCaseRunnerSpy(tempCase)
%MAKEYANGTEMPORARYCASERUNNERSPY Deterministic WP4 runner test double.

    result = validateYangTemporaryCase(tempCase);
    if ~result.pass
        error('WP4:InvalidTemporaryCase', ...
            'Spy runner received an invalid temporary case.');
    end

    terminalLocalStates = cell(tempCase.nLocalBeds, 1);
    for i = 1:tempCase.nLocalBeds
        terminalLocalStates{i} = struct( ...
            "terminalMarker", "terminal_local_" + string(i), ...
            "globalBed", string(tempCase.localMap.global_bed(i)), ...
            "localIndex", tempCase.localMap.local_index(i), ...
            "yangLabel", string(tempCase.localMap.yang_label(i)), ...
            "pairId", string(tempCase.pairId));
    end

    report = struct();
    report.callCount = 1;
    report.didInvokeNative = false;
    report.localOrder = tempCase.localMap.local_index(:);
    report.globalBeds = string(tempCase.localMap.global_bed);
end
