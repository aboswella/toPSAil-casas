# Schell 2013 source-extraction audit

## Audit result

The existing repo source-reference sheet is broadly aligned with the attached Schell 2013 paper and SI for geometry, step timings, performance targets, Sips parameters, transport/thermal parameters, piping diagnostics, and product-performance calculation logic.

It is not yet implementation-safe without semantic tightening. The main danger is not wrong numbers. It is right-looking numbers with the wrong meaning, which is the preferred habitat of simulation bugs.

## Values confirmed against the paper/SI

| Area | Confirmed values |
|---|---|
| Geometry | `L = 1.2 m`, `Ri = 0.0125 m`, `R0 = 0.02 m`, thermocouples at `0.10, 0.35, 0.60, 0.85, 1.10 m`. |
| Bed/adsorbent | `rho_M = 1965 kg/m3`, `rho_p = 850 kg/m3`, `rho_b = 480 kg/m3`, `dp = 0.003 m`, `Cs = 1000 J/(kg K)`, `Cw = 4e6 J/(m3 K)`, about `0.280 kg` adsorbent per bed. |
| Feed/procedure | Equimolar CO2/H2 feed, `T = 298.15 K`, `p_low = 1 bar`, adsorption pressures 10/20/30 bar, 20-30 cycles to CSS. |
| Step timings | Table 2 cases transcribed into `validation/targets/schell_2013_validation_targets.csv`. |
| Performance targets | 20 bar Table 2 purity/recovery values transcribed exactly. |
| Sips equation | Competitive Sips form from SI Table 2. |
| Sips parameters | SI Table 3 values transcribed into canonical JSON. |
| Transport/thermal | LDF `0.15/1.0 s^-1`, heat capacities `42.5/29.0 J/(mol K)`, viscosity `1.46e-5 Pa s`, thermal conductivity `0.04 W/(m K)`, `hW = 5 W/(m2 K)`, Leva `eta1 = 0.813`, `eta2 = 0.9`. |
| Piping diagnostic | `L1 = 1.5 m`, `L2 = 4.0 m`, `d_pipe = 0.008 m`, `T_pipe = 298 K`, `D_pipe = 0.001 m2/s`, optional stagnant tank `2e-5 m3` and exchange fraction `0.98`. |

## Corrections and cautions Codex must apply

### 1. Do not confuse LDF `k_i` with Sips `k_i`

Schell main Table 3 reports `k_i [1/s]` as LDF mass-transfer coefficients. The SI Sips equation also uses `k_i`, but that `k_i` is an adsorption affinity with units `1/Pa` after temperature correction. Use different internal names, for example:

- `ldf_rate_per_s`
- `sips_affinity_inv_Pa`

### 2. `K_L` is thermal conductivity for heat transfer, not axial dispersion

The repo source-reference wording should call `K_L = 0.04 W/(m K)` a fluid thermal conductivity used in the Nusselt/heat-transfer correlation. Do not call it axial thermal conductivity in a way that implies an axial conduction term is active in the PSA balance.

### 3. Flow-rate basis is a first-order ambiguity

The paper reports 20 cm3/s for adsorption and 50 cm3/s for purge, and explicitly says adsorption molar flow changes with pressure. The source pack therefore treats the primary conversion as actual volumetric flow at step pressure and 298.15 K:

```text
n_dot = P * Q / (R * T)
```

At 20 bar and 298.15 K, 20 cm3/s is approximately `0.01614 mol/s`; at 1 bar it is approximately `0.000807 mol/s`. A standard-volume interpretation would change the central feed molar flow by about a factor of 20. That is not a rounding error. That is a different experiment wearing the same hat.

### 4. Do not invent `p_peq`

The intermediate pressure after pressure equalization is not given as a simple table parameter. Use native toPSAil equalization first, or create a separate diagnostic task to digitize/derive the Figure 7 values or inspect the prior Casas pressure-equalization method.

### 5. Piping/stagnant tank is diagnostic, not default validation

The paper explicitly warns that MS concentration traces are distorted by piping and possible stagnant volume. The default validation should prioritise temperature profiles and table performance metrics. Add piping only in a labelled detector diagnostic mode.

### 6. Product-performance metrics are reconstructed from the H2-rich product

The paper does not directly measure CO2-rich stream performance. It integrates feed and H2-rich product, then calculates CO2-rich product by subtraction. Validation extractors must preserve that accounting basis.

### 7. The first three Table 2 cases have no purity/recovery metrics

Cases at 10, 20, and 30 bar in the first Table 2 block are useful for pressure/temperature profile validation. Do not fabricate scalar performance targets for them.

## Recommended source-reference edits

Update `docs/source_reference/02_schell_2013_two_bed_psa_validation.md` to:

- rename `K_L` note to "fluid thermal conductivity used in heat-transfer correlation";
- explicitly distinguish LDF `k_i [1/s]` from Sips affinity `k_i [1/Pa]`;
- add the flow-rate conversion warning and example molar flows;
- state that `p_peq` is unresolved and not to be invented;
- state that the Sips source pack JSON is canonical;
- state that detector piping is excluded from default validation.

Do not touch unrelated Delgado ledger issues inside Schell tasks. Humans already made enough stage boundaries; use them.
