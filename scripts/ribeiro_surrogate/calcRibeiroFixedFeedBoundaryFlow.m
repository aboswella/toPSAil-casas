function volFlowRat = calcRibeiroFixedFeedBoundaryFlow(params, col, ~, ~, ~, ~, nCo)
%CALCRIBEIROFIXEDFEEDBOUNDARYFLOW Prescribed feed molar flow at feed end.

feedMolSec = params.ribeiroBasis.feed.totalMolarFlowMolSec;
gasConTot = col.(params.sColNums{nCo}).gasConsTot(:, 1);
volFlowRat = molarFlowToBoundaryVolFlowNorm(params, feedMolSec, gasConTot, +1);

end
