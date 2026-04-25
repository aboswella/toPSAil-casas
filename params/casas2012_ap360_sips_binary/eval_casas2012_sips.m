function [qStar, details] = eval_casas2012_sips(p, partialPressurePa, temperatureK)
%EVAL_CASAS2012_SIPS Evaluate the Casas 2012 competitive Sips isotherm.
% Pressures are component partial pressures in Pa. Temperatures are in K.

    if nargin < 3
        error("eval_casas2012_sips:NotEnoughInputs", ...
              "Expected parameter pack, partial pressures, and temperature.");
    end

    partialPressurePa = double(partialPressurePa);
    if isvector(partialPressurePa)
        partialPressurePa = reshape(partialPressurePa, 1, []);
    end

    nComps = numel(p.components);
    if size(partialPressurePa, 2) ~= nComps
        error("eval_casas2012_sips:BadPressureSize", ...
              "Partial-pressure matrix must have one column per component.");
    end

    nRows = size(partialPressurePa, 1);
    temperatureK = double(temperatureK);
    if isscalar(temperatureK)
        temperatureK = repmat(temperatureK, nRows, 1);
    else
        temperatureK = reshape(temperatureK, [], 1);
    end

    if numel(temperatureK) ~= nRows
        error("eval_casas2012_sips:BadTemperatureSize", ...
              "Temperature must be scalar or have one row per pressure row.");
    end

    R = 8.31446261815324;
    pp = max(partialPressurePa, 0);

    omega = p.isotherm.omega_mol_kg;
    theta = p.isotherm.theta_J_mol;
    Omega = p.isotherm.Omega_1_Pa;
    Theta = p.isotherm.Theta_J_mol;
    s1 = p.isotherm.s1;
    s2 = p.isotherm.s2_1_K;
    sref = p.isotherm.sref;
    Tref = p.isotherm.Tref_K;

    qSat = zeros(nRows, nComps);
    affinity = zeros(nRows, nComps);
    sExp = zeros(nRows, nComps);
    terms = zeros(nRows, nComps);

    for i = 1:nComps
        qSat(:, i) = omega(i) .* exp(-theta(i) ./ (R .* temperatureK));
        affinity(:, i) = Omega(i) .* exp(-Theta(i) ./ (R .* temperatureK));
        sExp(:, i) = s1(i) .* atan(s2(i) .* (temperatureK - Tref(i))) + sref(i);
        terms(:, i) = (affinity(:, i) .* pp(:, i)) .^ sExp(:, i);
    end

    denominator = 1 + sum(terms, 2);
    qStar = qSat .* terms ./ denominator;

    details = struct();
    details.qSat_mol_kg = qSat;
    details.K_1_Pa = affinity;
    details.s = sExp;
    details.terms = terms;
    details.denominator = denominator;
end
