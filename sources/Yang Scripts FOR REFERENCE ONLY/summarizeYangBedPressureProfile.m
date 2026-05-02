function pressure = summarizeYangBedPressureProfile(params, localStatePayload)
%SUMMARIZEYANGBEDPRESSUREPROFILE Summarize dimensionless bed pressure ratios.
%
% Pressure ratio is represented by sum(c_i)*T for each CSTR in the native
% nondimensional state basis.

    physical = extractYangPhysicalBedState(params, localStatePayload);
    [gas, ~, temps] = parsePhysicalState(params, physical.physicalStateVector);

    pressureRatio = sum(gas, 2) .* temps(:, 1);
    pressure = struct();
    pressure.version = "FI4-Yang2009-bed-pressure-profile-summary-v1";
    pressure.unitBasis = "native_pressure_ratio_sum_c_times_T";
    pressure.profile = pressureRatio(:);
    pressure.minPressureRatio = min(pressureRatio);
    pressure.maxPressureRatio = max(pressureRatio);
    pressure.feedEndPressureRatio = pressureRatio(1);
    pressure.productEndPressureRatio = pressureRatio(end);
    pressure.meanPressureRatio = mean(pressureRatio);
    pressure.hasNaN = any(isnan(pressureRatio));
    pressure.hasInf = any(isinf(pressureRatio));
    pressure.hasNegativePressure = any(pressureRatio < 0);
end

function [gas, ads, temps] = parsePhysicalState(params, stateVector)
    stateVector = stateVector(:);
    nComs = params.nComs;
    nVols = params.nVols;
    nStates = 2*nComs + 2;
    if isfield(params, 'nStates')
        nStates = params.nStates;
    end

    if numel(stateVector) < nStates*nVols
        error('FI4:StateLengthMismatch', ...
            'Physical state has %d entries; expected at least %d.', ...
            numel(stateVector), nStates*nVols);
    end

    reshaped = reshape(stateVector(1:nStates*nVols), nStates, nVols).';
    gas = reshaped(:, 1:nComs);
    ads = reshaped(:, nComs+1:2*nComs);
    temps = reshaped(:, 2*nComs+1:2*nComs+2);
end
