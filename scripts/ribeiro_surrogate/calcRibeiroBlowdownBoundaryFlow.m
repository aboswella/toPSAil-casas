function volFlowRat = calcRibeiroBlowdownBoundaryFlow(params, col, ~, ~, ~, ~, nCo)
%CALCRIBEIROBLOWDOWNBOUNDARYFLOW Pressure-relief flow to a fixed 1 bar sink.

gasConTot = col.(params.sColNums{nCo}).gasConsTot(:, 1);
tempNorm = col.(params.sColNums{nCo}).temps.cstr(:, 1);
pressureBar = gasConTot .* tempNorm .* params.presColHigh;
deltaBar = max(0, pressureBar - params.presColLow);
reliefMolSec = params.ribeiroBoundary.blowdownGainMolSecBar .* deltaBar;
reliefMolSec = min(reliefMolSec, params.ribeiroBoundary.maxBoundaryMolarFlowMolSec);
volFlowRat = molarFlowToBoundaryVolFlowNorm(params, reliefMolSec, gasConTot, -1);

end
