function report = checkYangLedgerPhysicalMoleCompatibility(rows, scopes)
%CHECKYANGLEDGERPHYSICALMOLECOMPATIBILITY Guard physical mole accounting.

    report = struct();
    report.version = "FI8-Yang2009-ledger-physical-mole-compatibility-v1";
    report.pass = true;
    report.reason = "";
    report.scopes = string(scopes(:));
    report.nRowsChecked = 0;
    report.units = strings(0, 1);
    report.basis = strings(0, 1);

    if nargin < 1 || ~istable(rows)
        report = fail(report, "rows must be a ledger stream-row table");
        return;
    end
    if nargin < 2 || isempty(scopes)
        scopes = unique(string(rows.stream_scope));
    end
    scopes = string(scopes(:));

    required = ["stream_scope", "basis", "units", "moles"];
    if ~all(ismember(required, string(rows.Properties.VariableNames)))
        report = fail(report, "rows are missing required stream-row basis fields");
        return;
    end

    mask = ismember(string(rows.stream_scope), scopes);
    selected = rows(mask, :);
    report.nRowsChecked = height(selected);
    if height(selected) == 0
        return;
    end

    report.units = unique(string(selected.units));
    report.basis = unique(string(selected.basis));

    if any(~isfinite(selected.moles))
        report = fail(report, "selected rows contain non-finite moles");
        return;
    end

    if any(string(selected.units) ~= "mol")
        report = fail(report, "selected rows are not all in physical mol units");
        return;
    end

    basisText = lower(string(selected.basis));
    incompatibleTokens = [
        "native"
        "unknown"
        "not_available"
        "validation_only"
        "dimensionless"
    ];
    for i = 1:numel(incompatibleTokens)
        if any(contains(basisText, incompatibleTokens(i)))
            report = fail(report, ...
                "selected rows contain incompatible basis token '" + incompatibleTokens(i) + "'");
            return;
        end
    end
end

function report = fail(report, reason)
    report.pass = false;
    report.reason = string(reason);
end
