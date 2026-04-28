%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Function   : calcIsothermSchellSips.m
%Source     : common
%Description: optional, non-default Schell 2013 competitive Sips isotherm.
%             The source equation uses p in Pa, T in K, and loadings in
%             mol/kg. This function converts to those units locally and
%             returns adsorbed states in toPSAil's active normalization.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function newStates = calcIsothermSchellSips(params,states,nAds)

    %---------------------------------------------------------------------%
    %Unpack params
    nStates = params.nStates;
    nColStT = params.nColStT;
    nComs = params.nComs;
    sComNums = params.sComNums;
    nVols = params.nVols;
    nRows = params.nRows;
    gasCons = params.gasCons;
    gConScaleFac = params.gConScaleFac;
    teScaleFac = params.teScaleFac;

    nInfA = params.schellSipsNInfA_molPerKg;
    nInfB = params.schellSipsNInfB_JPerMol;
    affA = params.schellSipsAffA_invPa;
    affB = params.schellSipsAffB_JPerMol;
    alpha = params.schellSipsAlpha;
    beta = params.schellSipsBeta_invK;
    sRef = params.schellSipsSref;
    tRef = params.schellSipsTref_K;

    if isfield(params, 'aConScaleFac')
        aConScaleFac = params.aConScaleFac;
    else
        aConScaleFac = 1;
    end
    %---------------------------------------------------------------------%



    %---------------------------------------------------------------------%
    %Determine the index for the adsorber number
    if nAds == 0
        nAdsInd = 1;
    else
        nAdsInd = nAds;
    end
    %---------------------------------------------------------------------%



    %---------------------------------------------------------------------%
    %Handle a single CSTR call or a full adsorber call
    if nAds == 0
        colGasCons = convert2ColGasConc(params,states);
        colTemps = convert2ColTemps(params,states);
        nVols = 1;
    else
        colGasCons = convert2ColGasConc(params,states,nAds);
        colTemps = convert2ColTemps(params,states,nAds);
    end
    %---------------------------------------------------------------------%



    %---------------------------------------------------------------------%
    %Initialize arrays
    newStates = states;
    tempK = colTemps.cstr .* teScaleFac;
    gasConsJ = gasCons/10;
    terms = zeros(nRows,nVols*nComs);
    satLoadings = zeros(nRows,nVols*nComs);
    %---------------------------------------------------------------------%



    %---------------------------------------------------------------------%
    %Calculate source-dimensional Sips terms
    for i = 1:nComs
        n0 = nVols*(i-1)+1;
        nf = nVols*i;

        partialPressurePa = colGasCons.(sComNums{i}) ...
            .* gConScaleFac .* gasCons .* tempK .* 1e5;
        satLoadings(:,n0:nf) = nInfA(i) ...
            .* exp(-nInfB(i)./(gasConsJ.*tempK));
        sipsAffinityInvPa = affA(i) ...
            .* exp(-affB(i)./(gasConsJ.*tempK));
        sipsExponent = alpha(i) ...
            .* atan(beta(i).*(tempK - tRef(i))) + sRef(i);
        terms(:,n0:nf) = (sipsAffinityInvPa .* partialPressurePa) ...
            .^ sipsExponent;
    end
    %---------------------------------------------------------------------%



    %---------------------------------------------------------------------%
    %Evaluate competitive Sips loading and update adsorbed states
    denominator = ones(nRows,nVols);
    for i = 1:nComs
        n0 = nVols*(i-1)+1;
        nf = nVols*i;
        denominator = denominator + terms(:,n0:nf);
    end

    for i = 1:nComs
        n0 = nVols*(i-1)+1;
        nf = nVols*i;

        loading = satLoadings(:,n0:nf) .* terms(:,n0:nf) ...
            ./ denominator ./ aConScaleFac;

        nSt0 = nColStT*(nAdsInd-1) + nComs+i;
        nStf = nColStT*(nAdsInd-1) + nStates*(nVols-1)+nComs+i;

        newStates(:,nSt0:nStates:nStf) = loading;
    end
    %---------------------------------------------------------------------%

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%End function
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
