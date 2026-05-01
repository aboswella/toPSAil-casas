function report = testYangAcDslMapping(varargin)
%TESTYANGACDSLMAPPING Compare source Yang DSL against native toPSAil DSL.
%
% The primary pass flag covers the isothermal/reference-temperature mapping.
% The broader temperature grid is reported separately because FI-2 does not
% modify core isotherm temperature-dependence machinery.

    parser = inputParser;
    parser.FunctionName = "testYangAcDslMapping";
    addParameter(parser, "Params", [], @(x) isempty(x) || isstruct(x));
    addParameter(parser, "Tolerance", 1e-8, @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x > 0);
    addParameter(parser, "TemperaturesK", [293.15, 303.15, 323.15], @(x) isnumeric(x) && isvector(x));
    addParameter(parser, "PressuresAtm", [1.3, 3.0, 9.0], @(x) isnumeric(x) && isvector(x));
    addParameter(parser, "YGrid", [0.7697228145, 0.2302771855; 0.95, 0.05; 0.50, 0.50], @(x) isnumeric(x) && size(x, 2) == 2);
    parse(parser, varargin{:});
    opts = parser.Results;

    if isempty(opts.Params)
        params = buildYangH2Co2AcTemplateParams("NVols", 1);
    else
        params = opts.Params;
    end

    basis = params.yangBasis;
    temperaturesK = opts.TemperaturesK(:);
    pressuresAtm = opts.PressuresAtm(:);
    yGrid = opts.YGrid;

    nRows = numel(temperaturesK) * numel(pressuresAtm) * size(yGrid, 1);
    temperatureK = zeros(nRows, 1);
    pressureAtm = zeros(nRows, 1);
    yH2 = zeros(nRows, 1);
    yCO2 = zeros(nRows, 1);
    directH2 = zeros(nRows, 1);
    directCO2 = zeros(nRows, 1);
    nativeH2 = zeros(nRows, 1);
    nativeCO2 = zeros(nRows, 1);
    maxAbsResidual = zeros(nRows, 1);

    row = 0;
    for iT = 1:numel(temperaturesK)
        for iP = 1:numel(pressuresAtm)
            for iy = 1:size(yGrid, 1)
                row = row + 1;
                T = temperaturesK(iT);
                P = pressuresAtm(iP);
                y = yGrid(iy, :).';
                direct = evaluateYangSourceDslLoading(basis, P, T, y);
                native = evaluateNativeTopsailDslLoading(params, P, T, y);

                temperatureK(row) = T;
                pressureAtm(row) = P;
                yH2(row) = y(1);
                yCO2(row) = y(2);
                directH2(row) = direct(1);
                directCO2(row) = direct(2);
                nativeH2(row) = native(1);
                nativeCO2(row) = native(2);
                maxAbsResidual(row) = max(abs(native - direct));
            end
        end
    end

    pointTable = table(temperatureK, pressureAtm, yH2, yCO2, ...
        directH2, directCO2, nativeH2, nativeCO2, ...
        abs(nativeH2 - directH2), abs(nativeCO2 - directCO2), maxAbsResidual, ...
        'VariableNames', {'temperatureK', 'pressureAtm', 'yH2', 'yCO2', ...
        'directH2MolPerKg', 'directCO2MolPerKg', ...
        'nativeH2MolPerKg', 'nativeCO2MolPerKg', ...
        'absResidualH2MolPerKg', 'absResidualCO2MolPerKg', 'maxAbsResidualMolPerKg'});

    refMask = abs(pointTable.temperatureK - basis.referenceTemperatureK) < 1e-10;
    referenceMaxResidual = max(pointTable.maxAbsResidualMolPerKg(refMask));
    fullGridMaxResidual = max(pointTable.maxAbsResidualMolPerKg);

    report = struct();
    report.version = "FI2-Yang-H2CO2-AC-DSL-mapping-v1";
    report.scope = "isothermal_reference_temperature_mapping";
    report.tolerance = opts.Tolerance;
    report.referenceTemperatureK = basis.referenceTemperatureK;
    report.referenceTemperaturePass = referenceMaxResidual <= opts.Tolerance;
    report.fullTemperatureGridPass = fullGridMaxResidual <= opts.Tolerance;
    report.pass = report.referenceTemperaturePass;
    report.maxResidual = fullGridMaxResidual;
    report.referenceMaxResidual = referenceMaxResidual;
    report.pointTable = pointTable;
    report.caveat = params.nativeDslMapping.temperatureDependenceCaveat;
end

function q = evaluateYangSourceDslLoading(basis, pressureAtm, temperatureK, y)
    y = y(:);
    b1 = basis.dsl.siteOne.affinityPreExponentialPerAtm ...
        .* exp(basis.dsl.siteOne.affinityExponentK ./ temperatureK);
    b2 = basis.dsl.siteTwo.affinityPreExponentialPerAtm ...
        .* exp(basis.dsl.siteTwo.affinityExponentK ./ temperatureK);
    term1 = b1 .* pressureAtm .* y;
    term2 = b2 .* pressureAtm .* y;
    q = basis.dsl.siteOne.qSatMolPerKg .* term1 ./ (1 + sum(term1)) ...
      + basis.dsl.siteTwo.qSatMolPerKg .* term2 ./ (1 + sum(term2));
end

function q = evaluateNativeTopsailDslLoading(params, pressureAtm, temperatureK, y)
    pressureBar = pressureAtm * params.yangBasis.constants.atmToBar;
    totalGasConcentration = pressureBar / (params.gasCons * temperatureK);
    gasConDimless = y(:).' .* totalGasConcentration ./ params.gasConT;

    state = zeros(1, params.nStates);
    state(1:params.nComs) = gasConDimless;
    state(2 * params.nComs + 1) = temperatureK / params.tempAmbi;
    state(2 * params.nComs + 2) = temperatureK / params.tempAmbi;

    localParams = params;
    localParams.nRows = 1;
    nativeState = calcIsothermExtDuSiLangFreu(localParams, state, 0);
    q = nativeState(params.nComs + 1:2 * params.nComs).' .* params.adsConT;
end
