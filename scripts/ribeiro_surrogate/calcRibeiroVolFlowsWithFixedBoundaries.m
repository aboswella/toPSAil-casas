function units = calcRibeiroVolFlowsWithFixedBoundaries(params, units, nS)
%CALCRIBEIROVOLFLOWSWITHFIXEDBOUNDARIES Apply Ribeiro BC overlay, then native flow model.

if ~isfield(params, 'ribeiroBoundary') || ...
        ~isfield(params.ribeiroBoundary, 'nativeFuncVol') || ...
        isempty(params.ribeiroBoundary.nativeFuncVol)
    error('RibeiroSurrogate:MissingNativeFuncVol', ...
        'Ribeiro boundary mode requires params.ribeiroBoundary.nativeFuncVol.');
end

units = applyRibeiroBoundaryCompositionOverrides(params, units, nS);
units = params.ribeiroBoundary.nativeFuncVol(params, units, nS);

end
