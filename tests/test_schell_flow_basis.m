% Tier 1/3 flow-basis regression test for the Schell native adapter.
%
% Failure modes caught: using Schell's reported actual 20 cm3/s source
% adsorption flow directly as toPSAil's native volFlowFeed normalisation;
% losing the calcVolFlowFeed basis factor
% (tempCol / presColHigh) * (presStan / tempStan); or relabelling source
% actual flow and native toPSAil flow so they are easy to confuse again.
%
% Source/policy basis: docs/source_reference/02_schell_2013_two_bed_psa_validation.md
% and 3_source/4_rhs/1_volumetricFlowRates/4_pre_computations/calcVolFlowFeed.m.
%
% Runtime class: build-only, no simulation.
% Not included in default smoke/sanity runners.

repoRoot = fileparts(fileparts(mfilename("fullpath")));
addpath(genpath(repoRoot));

fprintf("Tier 1/3 flow basis: checking Schell adapter native volFlowFeed conversion.\n");

caseId = "schell_20bar_tads40_performance_central";
[~, fullParams, runConfig] = build_schell_runnable_params(caseId, 1);

expectedConverted = 20 * (298.15 / 20) * (1.01325 / 273.15);
assertClose(expectedConverted, 1.10598750686436, 1e-13, ...
    "central converted native volFlowFeed target");

assertClose(runConfig.source_adsorption_actual_flow_cm3_per_s, ...
    20, 1e-12, "Schell source actual adsorption flow");
assertClose(runConfig.topsail_native_adsorption_flow_target_cm3_per_s, ...
    expectedConverted, 1e-12, "runConfig native adsorption target");
assertClose(fullParams.volFlowFeed, expectedConverted, 1e-10, ...
    "fullParams.volFlowFeed");
assertClose(runConfig.topsail_native_adsorption_flow_observed_cm3_per_s, ...
    fullParams.volFlowFeed, 1e-12, "observed native adsorption flow");

assert(abs(fullParams.volFlowFeed - 20) > 10, ...
    "test_schell_flow_basis:oldDirectTargetStillAccepted", ...
    "fullParams.volFlowFeed must match the converted native basis, not the source actual 20 cm3/s.");
assert(contains(runConfig.topsail_native_flow_conversion_formula, ...
        "(tempCol / presColHigh) * (presStan / tempStan)"), ...
    "test_schell_flow_basis:missingCalcVolFlowFeedFactor", ...
    "Run config must document the calcVolFlowFeed basis factor.");

oldFactor = runConfig.flow_basis_old_to_converted_factor;
assert(oldFactor > 10 && oldFactor < 25, ...
    "test_schell_flow_basis:oldFactorNotDecisive", ...
    "The old direct-20 interpretation should remain an obvious factor-of-pressure error.");

fprintf("Tier 1/3 flow basis passed: source actual 20 cm3/s maps to native %.14g cm3/s.\n", ...
    fullParams.volFlowFeed);

function assertClose(actual, expected, tolerance, context)
    assert(isnumeric(actual) && isscalar(actual) && isfinite(actual), ...
        "test_schell_flow_basis:expectedNumericScalar", ...
        "Expected numeric scalar at %s.", context);
    if abs(double(actual) - double(expected)) > tolerance
        error("test_schell_flow_basis:numericMismatch", ...
            "%s expected %.16g, got %.16g.", context, expected, actual);
    end
end
