% Tier 0 smoke test: run the unchanged toPSAil case_study_1.0 example.
% Failure mode caught: baseline toPSAil example cannot run or emits nonfinite final outputs.

scriptDir = fileparts(mfilename("fullpath"));
repoRoot = fileparts(scriptDir);
caseName = "case_study_1.0";
outputRel = fullfile("4_example", caseName, "2_simulation_outputs");
outputDataDir = fullfile(repoRoot, outputRel, "2_data");

assertNoPreexistingSmokeDirt(repoRoot, outputRel);
cleanupObj = onCleanup(@() cleanupSmokeArtifacts(repoRoot, outputRel));

fprintf("Tier 0 smoke: running unchanged toPSAil %s example.\n", caseName);

originalDir = pwd;
dirCleanup = onCleanup(@() cd(originalDir));
cd(fullfile(repoRoot, "2_run"));
runPsaProcessSimulation(caseName);
cd(originalDir);

assertFiniteCsvOutputs(outputDataDir);

fprintf("Tier 0 smoke passed: %s completed and key CSV outputs are finite.\n", caseName);

function assertNoPreexistingSmokeDirt(repoRoot, outputRel)
    cmd = sprintf('git -C "%s" status --porcelain -- "%s" "CW.txt" "2_run/CW.txt"', ...
        repoRoot, outputRel);
    [status, out] = system(cmd);
    if status ~= 0
        error("run_smoke:gitStatusFailed", ...
            "Could not inspect smoke output state before running:%s%s", newline, out);
    end
    if strlength(strtrim(out)) > 0
        error("run_smoke:dirtySmokeOutputs", ...
            "Smoke output paths are already dirty. Resolve these before running smoke:%s%s", ...
            newline, out);
    end
end

function assertFiniteCsvOutputs(outputDataDir)
    requiredFiles = [
        "productPurity.csv"
        "productRecovery.csv"
        "productivity.csv"
        "energyEfficiency.csv"
        "time.csv"
    ];
    numericColumns = {
        []
        []
        []
        []
        1
    };

    for i = 1:numel(requiredFiles)
        filePath = fullfile(outputDataDir, requiredFiles(i));
        if ~isfile(filePath)
            error("run_smoke:missingOutput", "Expected smoke output is missing: %s", filePath);
        end
        values = readmatrix(filePath);
        if isempty(values)
            error("run_smoke:emptyOutput", "Expected smoke output is empty: %s", filePath);
        end
        columnsToCheck = numericColumns{i};
        if isempty(columnsToCheck)
            columnsToCheck = find(any(isfinite(values), 1));
        end
        if isempty(columnsToCheck)
            error("run_smoke:noNumericOutput", ...
                "Smoke output does not contain any numeric values: %s", filePath);
        end
        finalValues = values(end, columnsToCheck);
        if any(~isfinite(finalValues), "all")
            error("run_smoke:nonfiniteOutput", ...
                "Smoke output final row contains NaN or Inf: %s", filePath);
        end
    end
end

function cleanupSmokeArtifacts(repoRoot, outputRel)
    cmd = sprintf('git -C "%s" restore -- "%s"', repoRoot, outputRel);
    [status, out] = system(cmd);
    if status ~= 0
        warning("run_smoke:cleanupFailed", ...
            "Could not restore smoke output directory after run:%s%s", newline, out);
    end

    diaryFiles = [
        fullfile(repoRoot, "CW.txt")
        fullfile(repoRoot, "2_run", "CW.txt")
    ];
    for i = 1:numel(diaryFiles)
        if isfile(diaryFiles(i))
            delete(diaryFiles(i));
        end
    end
end
