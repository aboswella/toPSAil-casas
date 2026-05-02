function [feedDelta, productDelta] = splitYangBoundaryCounterTail(params, counterDelta)
%SPLITYANGBOUNDARYCOUNTERTAIL Split native feed/product boundary counters.

    counterDelta = counterDelta(:);
    nComs = params.nComs;
    if numel(counterDelta) ~= 2*nComs
        error('FI8:UnexpectedCounterTailLength', ...
            'Expected 2*nComs counter entries; got %d.', numel(counterDelta));
    end

    feedDelta = counterDelta(1:nComs);
    productDelta = counterDelta(nComs+1:2*nComs);
end
