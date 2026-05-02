function units = zeroYangAdapterAuxiliaryVolFlows(params, units, nS)
%ZEROYANGADAPTERAUXILIARYVOLFLOWS Keep native auxiliary tanks inert.
%
% The PP->PU transfer is direct bed-to-bed. Native tank structures may exist
% for shape compatibility only; their volumetric flows stay zero.

    %#ok<INUSD> nS is kept for the native funcVolUnits signature.
    nRows = params.nRows;
    nCols = params.nCols;
    zerosToColumnsAndReservoir = zeros(nRows, nCols + 1);

    units.feTa.n1.volFlRat = zerosToColumnsAndReservoir;
    units.raTa.n1.volFlRat = zerosToColumnsAndReservoir;
    units.exTa.n1.volFlRat = zerosToColumnsAndReservoir;
end
