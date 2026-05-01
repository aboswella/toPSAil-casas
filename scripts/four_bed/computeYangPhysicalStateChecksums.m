function checksums = computeYangPhysicalStateChecksums(params, localStates, localMap)
%COMPUTEYANGPHYSICALSTATECHECKSUMS Compact terminal-state audit summary.

    if nargin < 2 || ~iscell(localStates)
        error('FI8:InvalidStateChecksumInput', ...
            'localStates must be supplied as a cell array.');
    end
    if nargin < 3
        localMap = table();
    end

    checksums = struct();
    for i = 1:numel(localStates)
        key = "local_" + string(i);
        try
            physical = extractYangPhysicalBedState(params, localStates{i});
            vec = physical.physicalStateVector(:);
            checksums.(char(key)) = makeChecksum(vec, localMap, i);
        catch ME
            checksums.(char(key)) = struct( ...
                "localIndex", i, ...
                "globalBed", "unknown", ...
                "localRole", "unknown", ...
                "recordId", "unknown", ...
                "nValues", NaN, ...
                "sum", NaN, ...
                "norm", NaN, ...
                "min", NaN, ...
                "max", NaN, ...
                "status", "failed", ...
                "reason", string(ME.identifier));
        end
    end
end

function checksum = makeChecksum(vec, localMap, localIndex)
    checksum = struct();
    checksum.localIndex = localIndex;
    checksum.globalBed = getMapValue(localMap, localIndex, "global_bed", "unknown");
    checksum.localRole = getMapValue(localMap, localIndex, "local_role", "unknown");
    checksum.recordId = getMapValue(localMap, localIndex, "record_id", "unknown");
    checksum.nValues = numel(vec);
    checksum.sum = sum(vec);
    checksum.norm = norm(vec);
    checksum.min = min(vec);
    checksum.max = max(vec);
    checksum.status = "ok";
end

function value = getMapValue(localMap, localIndex, variableName, defaultValue)
    value = string(defaultValue);
    if istable(localMap) && ismember(variableName, string(localMap.Properties.VariableNames)) && ...
            height(localMap) >= localIndex
        value = string(localMap.(char(variableName))(localIndex));
    end
end
