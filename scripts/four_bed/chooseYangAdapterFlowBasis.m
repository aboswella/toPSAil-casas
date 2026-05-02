function flowBasis = chooseYangAdapterFlowBasis(adapterReport, varargin)
%CHOOSEYANGADAPTERFLOWBASIS Pick the best integrated adapter-flow basis.

    parser = inputParser;
    addParameter(parser, 'RequiredFields', strings(0, 1));
    parse(parser, varargin{:});
    opts = parser.Results;

    flowBasis = struct();
    flowBasis.values = struct();
    flowBasis.basis = "unavailable";
    flowBasis.units = "unknown";
    flowBasis.warning = "";
    flowBasis.sourceField = "";

    if nargin < 1 || ~isstruct(adapterReport)
        error('FI7:InvalidAdapterReport', ...
            'adapterReport must be a scalar struct.');
    end

    requiredFields = string(opts.RequiredFields(:));
    if isempty(requiredFields)
        requiredFields = [
            "internalTransferOutByComponent"
            "internalTransferInByComponent"
        ];
    end

    if isfield(adapterReport, 'flowReport') && isstruct(adapterReport.flowReport) && ...
            isfield(adapterReport.flowReport, 'moles') && ...
            isUsableFlowStruct(adapterReport.flowReport.moles, requiredFields)
        flowBasis.values = adapterReport.flowReport.moles;
        flowBasis.basis = "physical_moles";
        flowBasis.units = "mol";
        flowBasis.sourceField = "adapterReport.flowReport.moles";
        if isfield(adapterReport.flowReport.moles, 'unitBasis')
            flowBasis.unitBasis = string(adapterReport.flowReport.moles.unitBasis);
        end
        if isfield(adapterReport.flowReport, 'primaryBasis')
            flowBasis.primaryBasis = string(adapterReport.flowReport.primaryBasis);
        end
        return;
    end

    if isfield(adapterReport, 'flowReport') && isstruct(adapterReport.flowReport) && ...
            isfield(adapterReport.flowReport, 'native') && ...
            isUsableFlowStruct(adapterReport.flowReport.native, requiredFields)
        flowBasis.values = adapterReport.flowReport.native;
        flowBasis.basis = "native_counter_units";
        flowBasis.units = "native_integrated_units";
        flowBasis.sourceField = "adapterReport.flowReport.native";
        flowBasis.warning = "adapter flow basis is native/nondimensional, not physical moles";
        if isfield(adapterReport.flowReport.native, 'unitBasis')
            flowBasis.unitBasis = string(adapterReport.flowReport.native.unitBasis);
        end
        if isfield(adapterReport.flowReport, 'primaryBasis')
            flowBasis.primaryBasis = string(adapterReport.flowReport.primaryBasis);
        end
        return;
    end

    if isfield(adapterReport, 'flows') && isstruct(adapterReport.flows) && ...
            isUsableFlowStruct(adapterReport.flows, requiredFields)
        flowBasis.values = adapterReport.flows;
        flowBasis.basis = "unknown_adapter_units";
        flowBasis.units = "unknown";
        flowBasis.sourceField = "adapterReport.flows";
        flowBasis.warning = "adapterReport.flows basis is ambiguous";
        return;
    end

    error('FI7:AdapterFlowBasisUnavailable', ...
        'Adapter report does not contain complete integrated branch flows.');
end

function tf = isUsableFlowStruct(s, requiredFields)
    tf = isstruct(s);
    if ~tf
        return;
    end
    for i = 1:numel(requiredFields)
        fieldName = char(requiredFields(i));
        if ~isfield(s, fieldName)
            tf = false;
            return;
        end
        value = s.(fieldName);
        if ~isnumeric(value) || isempty(value) || ~all(isfinite(value(:)))
            tf = false;
            return;
        end
    end
end
