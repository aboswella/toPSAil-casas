% Tier 2 equation-local checks.
% Failure mode caught: incorrect Casas Sips competition or LDF sign.

p = load_casas2012_ap360_sips_binary();
P = p.operating.P_feed_Pa;
T = p.operating.T_feed_K;

[qRef, detailsRef] = eval_casas2012_sips(p, P .* [0.5, 0.5], T);
assert(all(isfinite(qRef), "all"));
assert(all(qRef >= 0, "all"));
assert(qRef(p.component_order.CO2) > qRef(p.component_order.H2));

qLowCO2 = eval_casas2012_sips(p, P .* [0.25, 0.50], T);
qHighCO2 = eval_casas2012_sips(p, P .* [0.75, 0.50], T);
assert(qHighCO2(p.component_order.CO2) > qLowCO2(p.component_order.CO2));

qLowH2 = eval_casas2012_sips(p, P .* [0.50, 0.25], T);
qHighH2 = eval_casas2012_sips(p, P .* [0.50, 0.75], T);
assert(qHighH2(p.component_order.H2) > qLowH2(p.component_order.H2));

[qNoH2, detailsNoH2] = eval_casas2012_sips(p, P .* [0.5, 0], T);
assert(abs(detailsRef.denominator - (1 + sum(detailsRef.terms, 2))) < 1e-12);
assert(detailsRef.denominator > detailsNoH2.denominator);
assert(qRef(p.component_order.CO2) < qNoH2(p.component_order.CO2));

qCool = eval_casas2012_sips(p, P .* [0.5, 0.5], 288.15);
qHot = eval_casas2012_sips(p, P .* [0.5, 0.5], 318.15);
assert(all(isfinite(qCool), "all") && all(isfinite(qHot), "all"));
assert(abs(qCool(p.component_order.CO2) - qHot(p.component_order.CO2)) > 1e-6);
assert(qCool(p.component_order.CO2) > qHot(p.component_order.CO2));

qBelow = 0.25 .* qRef;
qAbove = 1.25 .* qRef;
ratePositive = eval_casas2012_ldf(p, qBelow, qRef);
rateNegative = eval_casas2012_ldf(p, qAbove, qRef);
rateZero = eval_casas2012_ldf(p, qRef, qRef);
assert(all(ratePositive > 0, "all"));
assert(all(rateNegative < 0, "all"));
assert(all(abs(rateZero) <= 10 * eps, "all"));

assert(all(p.thermal.DeltaH_J_mol < 0));
assert(p.thermal.hW_J_m2_s_K == 5);
assert(p.thermal.Cw_J_m3_K == 4.0e6);

fprintf("Tier 2 Casas equation-local tests passed.\n");
