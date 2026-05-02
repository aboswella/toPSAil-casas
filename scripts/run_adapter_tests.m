fprintf('Running Yang adapter tests...\n');
testYangValveCoefficientScaling();
testYangPpPuAdapterContract();
testYangPpPuAdapterConservation();
testYangAdppBfAdapterContract();
testYangAdppBfAdapterSplitConservation();
fprintf('Yang adapter tests passed.\n');
