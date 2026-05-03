function volFlowRat = calcRibeiroFixedPurgeBoundaryFlow(params, col, ~, ~, ~, ~, nCo)
%CALCRIBEIROFIXEDPURGEBOUNDARYFLOW Prescribed pure-H2 purge at product end.

normalMolarVolM3PerKmol = 22.414;
purgeMolSec = params.ribeiroBasis.purge.sourceFlowNm3Hr ...
    / 3600 / normalMolarVolM3PerKmol * 1000;
gasConTot = col.(params.sColNums{nCo}).gasConsTot(:, params.nVols);
volFlowRat = molarFlowToBoundaryVolFlowNorm(params, purgeMolSec, gasConTot, -1);

end
