function cvEff = resolveYangValveCoefficient(rawCv, params, controls, name)
%RESOLVEYANGVALVECOEFFICIENT Convert top-level Yang Cv controls for adapters.
%
% Top-level Yang controls use dimensional native-style valve coefficients by
% default. Custom adapters operate on the same scaled coefficient basis as
% native toPSAil boundary laws, so dimensional controls are multiplied by
% params.valScaleFac exactly once. The scaled_dimensionless basis is an
% explicit escape hatch for synthetic tests or advanced callers.

    if nargin < 2 || isempty(params)
        params = struct();
    end
    if nargin < 3 || isempty(controls)
        controls = struct();
    end
    if nargin < 4 || isempty(name)
        name = "Cv";
    end
    name = string(name);

    validateRawCv(rawCv, name);
    basis = resolveBasis(controls);

    switch basis
        case "dimensional_kmol_per_bar_s"
            cvEff = rawCv .* resolveScaleFactor(params, rawCv, name);
        case "scaled_dimensionless"
            cvEff = rawCv;
        otherwise
            error('FI8:UnknownValveCoefficientBasis', ...
                'Unknown valve coefficient basis %s for %s.', ...
                char(basis), char(name));
    end
    cvEff = double(cvEff);
end

function validateRawCv(rawCv, name)
    if ~isnumeric(rawCv) || ~isscalar(rawCv) || ~isreal(rawCv) || ...
            ~isfinite(rawCv) || rawCv < 0
        error('FI8:InvalidValveCoefficient', ...
            '%s must be a finite nonnegative real scalar.', char(name));
    end
end

function basis = resolveBasis(controls)
    basis = "dimensional_kmol_per_bar_s";
    if isstruct(controls) && isfield(controls, 'adapterCvBasis') && ...
            ~isempty(controls.adapterCvBasis)
        basis = string(controls.adapterCvBasis);
    elseif isstruct(controls) && isfield(controls, 'valveCoefficientBasis') && ...
            ~isempty(controls.valveCoefficientBasis)
        basis = string(controls.valveCoefficientBasis);
    end
    if ~isscalar(basis) || strlength(basis) == 0
        error('FI8:UnknownValveCoefficientBasis', ...
            'Valve coefficient basis must be a nonempty scalar string.');
    end
end

function scale = resolveScaleFactor(params, rawCv, name)
    if rawCv == 0 && (~isstruct(params) || ~isfield(params, 'valScaleFac') || ...
            isempty(params.valScaleFac))
        scale = 1.0;
        return;
    end
    if ~isstruct(params) || ~isfield(params, 'valScaleFac') || ...
            isempty(params.valScaleFac)
        error('FI8:MissingValveScaleFactor', ...
            'params.valScaleFac is required to resolve dimensional valve coefficient %s.', ...
            char(name));
    end
    scale = params.valScaleFac;
    if ~isnumeric(scale) || ~isscalar(scale) || ~isreal(scale) || ...
            ~isfinite(scale) || scale <= 0
        error('FI8:InvalidValveScaleFactor', ...
            'params.valScaleFac must be a finite positive scalar.');
    end
    scale = double(scale);
end
