function [terminalLocalStates, adapterReport] = runYangDirectCouplingAdapter(tempCase, templateParams, adapterConfig)
%RUNYANGDIRECTCOUPLINGADAPTER Dispatch Yang custom direct-coupling adapters.
%
% PP->PU and AD&PP->BF stay in separate adapter implementations so their
% stream accounting cannot collapse into one generic direct-transfer path.

    if nargin < 1 || ~isstruct(tempCase) || ~isfield(tempCase, 'directTransferFamily')
        error('FI4:InvalidTemporaryCase', ...
            'tempCase must be a Yang temporary case with directTransferFamily.');
    end
    if nargin < 2
        templateParams = struct();
    end
    if nargin < 3
        adapterConfig = struct();
    end

    family = string(tempCase.directTransferFamily);
    switch family
        case "PP_PU"
            [terminalLocalStates, adapterReport] = runYangPpPuAdapter( ...
                tempCase, templateParams, adapterConfig);
        case "ADPP_BF"
            [terminalLocalStates, adapterReport] = runYangAdppBfAdapter( ...
                tempCase, templateParams, adapterConfig);
        otherwise
            error('FI5:UnsupportedDirectCouplingFamily', ...
                'Unsupported directTransferFamily %s.', char(family));
    end
end
