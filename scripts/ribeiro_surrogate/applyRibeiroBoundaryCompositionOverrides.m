function units = applyRibeiroBoundaryCompositionOverrides(params, units, nS)
%APPLYRIBEIROBOUNDARYCOMPOSITIONOVERRIDES Impose fixed non-EQ boundary gas.

pureH2 = zeros(params.nComs, 1);
pureH2(1) = 1;

for nCo = 1:params.nCols
    label = string(params.sStepCol{nCo, nS});
    colName = params.sColNums{nCo};

    switch label
        case "HP-FEE-RAF"
            gasConTot = units.col.(colName).gasConsTot(:, 1);
            units = imposeBoundaryComposition( ...
                params, units, colName, 'feEnd', params.yFeC(:), ...
                gasConTot, params.tempFeedNorm);

        case "LP-ATM-RAF"
            gasConTot = units.col.(colName).gasConsTot(:, params.nVols);
            units = imposeBoundaryComposition( ...
                params, units, colName, 'prEnd', pureH2, ...
                gasConTot, params.tempFeedNorm);

        case "RP-XXX-RAF"
            gasConTot = units.col.(colName).gasConsTot(:, params.nVols);
            units = imposeBoundaryComposition( ...
                params, units, colName, 'prEnd', pureH2, ...
                gasConTot, params.tempFeedNorm);

        case "DP-ATM-XXX"
            units = imposeLocalFeedEndComposition(params, units, colName);

        case "EQ-XXX-APR"
            % Native equalization boundary composition is left untouched.
    end
end

end

function units = imposeBoundaryComposition( ...
    params, units, colName, endName, moleFractions, gasConTot, tempNorm)

units.col.(colName).(endName).gasConsTot = gasConTot;
units.col.(colName).(endName).temps = tempNorm .* ones(size(gasConTot));

for j = 1:params.nComs
    comName = params.sComNums{j};
    units.col.(colName).(endName).gasCons.(comName) = ...
        moleFractions(j) .* gasConTot;
end

end

function units = imposeLocalFeedEndComposition(params, units, colName)

units.col.(colName).feEnd.gasConsTot = ...
    units.col.(colName).gasConsTot(:, 1);
units.col.(colName).feEnd.temps = ...
    units.col.(colName).temps.cstr(:, 1);

for j = 1:params.nComs
    comName = params.sComNums{j};
    units.col.(colName).feEnd.gasCons.(comName) = ...
        units.col.(colName).gasCons.(comName)(:, 1);
end

end
