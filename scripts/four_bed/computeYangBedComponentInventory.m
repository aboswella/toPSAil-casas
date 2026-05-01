function inventory = computeYangBedComponentInventory(params, localStatePayload)
%COMPUTEYANGBEDCOMPONENTINVENTORY Gas-plus-adsorbed inventory by component.

    physical = extractYangPhysicalBedState(params, localStatePayload);
    [gas, ads] = parsePhysicalState(params, physical.physicalStateVector);

    cstrHt = getCstrHeights(params);
    partCoefHp = getScalarField(params, 'partCoefHp', 1);

    nativeGas = sum(gas .* cstrHt(:), 1).';
    nativeAds = partCoefHp .* sum(ads .* cstrHt(:), 1).';
    nativeTotal = nativeGas + nativeAds;

    inventory = struct();
    inventory.version = "FI4-Yang2009-bed-component-inventory-v1";
    inventory.native = struct();
    inventory.native.unitBasis = "native_column_balance_scaled_inventory";
    inventory.native.gasByComponent = nativeGas;
    inventory.native.adsorbedByComponent = nativeAds;
    inventory.native.totalByComponent = nativeTotal;
    inventory.usedPhysicalMoles = false;

    if hasPhysicalMoleScale(params)
        gasMoles = sum(gas .* params.gConScaleFac .* params.overVoid .* ...
            params.colVol .* cstrHt(:), 1).';
        adsMoles = sum(ads .* params.aConScaleFac .* params.pellDens .* ...
            (1 - params.voidFracBed) .* params.colVol .* cstrHt(:), 1).';
        inventory.moles = struct();
        inventory.moles.unitBasis = "physical_moles_from_available_scale_factors";
        inventory.moles.gasByComponent = gasMoles;
        inventory.moles.adsorbedByComponent = adsMoles;
        inventory.moles.totalByComponent = gasMoles + adsMoles;
        inventory.usedPhysicalMoles = true;
    else
        inventory.moles = struct();
        inventory.moles.unitBasis = "not_available_missing_scale_factors";
        inventory.moles.gasByComponent = [];
        inventory.moles.adsorbedByComponent = [];
        inventory.moles.totalByComponent = [];
    end
end

function tf = hasPhysicalMoleScale(params)
    required = ["gConScaleFac", "aConScaleFac", "overVoid", ...
        "colVol", "cstrHt", "pellDens", "voidFracBed"];
    fields = string(fieldnames(params));
    tf = all(ismember(required, fields));
end

function cstrHt = getCstrHeights(params)
    if isfield(params, 'cstrHt') && ~isempty(params.cstrHt)
        cstrHt = params.cstrHt(:);
    else
        cstrHt = ones(params.nVols, 1) ./ params.nVols;
    end
    if numel(cstrHt) ~= params.nVols
        error('FI4:InvalidInventoryParams', ...
            'params.cstrHt must have one entry per CSTR.');
    end
end

function value = getScalarField(params, fieldName, defaultValue)
    value = defaultValue;
    if isfield(params, fieldName) && ~isempty(params.(fieldName))
        value = params.(fieldName);
    end
    if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value)
        error('FI4:InvalidInventoryParams', ...
            'params.%s must be a finite numeric scalar.', fieldName);
    end
end

function [gas, ads] = parsePhysicalState(params, stateVector)
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
end
