function volFlowRat = calcRibeiroPressurizationBoundaryFlow(params, col, ~, ~, ~, ~, nCo)
%CALCRIBEIROPRESSURIZATIONBOUNDARYFLOW Pure-H2 source toward high pressure.

gasConTot = col.(params.sColNums{nCo}).gasConsTot(:, params.nVols);
tempNorm = col.(params.sColNums{nCo}).temps.cstr(:, params.nVols);
pressureBar = gasConTot .* tempNorm .* params.presColHigh;
deltaBar = max(0, params.presColHigh - pressureBar);
pressMolSec = params.ribeiroBoundary.pressurizationGainMolSecBar .* deltaBar;
pressMolSec = min(pressMolSec, params.ribeiroBoundary.maxBoundaryMolarFlowMolSec);
volFlowRat = molarFlowToBoundaryVolFlowNorm(params, pressMolSec, gasConTot, -1);

end
