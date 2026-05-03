function volFlowNorm = molarFlowToBoundaryVolFlowNorm( ...
    params, molFlowMolSec, gasConTotBoundaryNorm, signValue)
%MOLARFLOWTOBOUNDARYVOLFLOWNORM Convert mol/s to native boundary vol flow.

molFlowNorm = molFlowMolSec ./ (params.gConScaleFac .* params.volScaleFac);
volFlowNorm = signValue .* molFlowNorm ./ ...
    max(gasConTotBoundaryNorm, params.numZero);

end
