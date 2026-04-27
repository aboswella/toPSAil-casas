# Stage 3 - Schell 2013 Two-Bed PSA Validation Sheet

## Codex task role

Use this file for the primary experimental full-cycle validation: a two-column AP3-60 activated-carbon PSA separating an equimolar CO2/H2 feed. This is the main validation stage after the Casas-lite breakthrough sanity case.

Primary parameter-pack target:

```text
params/schell2013_ap360_sips_binary/
```

Canonical implementation source pack once added:

```text
params/schell2013_ap360_sips_binary/schell_2013_source_pack.json
```

JSON is the canonical hand-edited source pack for Schell. Do not maintain a parallel YAML duplicate.

Keep this pack separate from Casas 2012 even though both use AP3-60. Schell 2013 changes the PSA heat-of-adsorption value for CO2 and uses full-cycle timing/performance data.

## Source anchors and check status

| Item | Source anchor | Check status |
|---|---|---|
| Bed/setup parameters | Schell 2013 Table 1, rendered `schell2013/page-03.png`, text lines 127-143 | Text extraction + rendered table checked. |
| Cycle steps | Schell 2013 Figure 3 and text, rendered `schell2013/page-03.png`, text lines 156-177 | Text extraction + rendered figure checked. |
| Cycle timings/performance | Schell 2013 Table 2, rendered `schell2013/page-04.png`, text lines 195-206 | Text extraction + rendered table checked. |
| Feed flows and CSS procedure | Schell 2013 text lines 208-232 | Text extraction checked. |
| Model parameters | Schell 2013 Table 3, rendered `schell2013/page-05.png` | Rendered table checked. |
| Sips isotherm parameters | Schell 2013 SI Table 3, rendered `schell2013_si/page-04.png` | Rendered SI table checked. |
| Performance definitions | Schell 2013 SI product calculation section | Text extraction checked. |

## Stage goal

Construct and validate a two-bed PSA case with:

```text
components = CO2, H2
adsorbent = AP3-60 activated carbon
feed = 50/50 CO2/H2
T_feed = 25 degC
p_low = 1 bar
p_high = 10, 20, or 30 bar depending on case
```

The default implementation should use native toPSAil cycle and boundary machinery. A source-specific Schell reproduction mode may be added later, but it must be labelled separately.

## Experimental setup and physical parameters

Source: Schell 2013 Table 1.

| Parameter | Symbol | Value | Units | Notes |
|---|---:|---:|---|---|
| Column length | L | 1.2 | m | Same nominal column length as Casas. |
| Internal radius | Ri | 0.0125 | m | Inner diameter 2.5 cm. |
| External radius | R0 | 0.02 | m | Wall/heating lump. |
| Wall heat capacity | Cw | 4.0e6 | J/(K m3) | Lumped wall/heating layers. |
| Material density | rho_M | 1965 | kg/m3 | Helium pycnometry. |
| Particle density | rho_p | 850 | kg/m3 | Manufacturer value. |
| Bed density | rho_b | 480 | kg/m3 | Different from Casas 2012 value. Do not silently substitute. |
| Particle diameter | dp | 0.003 | m | Cylindrical pellets. |
| Adsorbent heat capacity | Cs | 1.0e3 | J/(K kg) | Hard transcription. |
| Adsorbent mass per bed | m_ads | about 280 | g | Per bed. |
| Thermocouple positions | - | 10, 35, 60, 85, 110 | cm from bottom | Used for profile validation. |

## Experimental feed and procedure

| Quantity | Value | Source use |
|---|---:|---|
| Feed gas | equimolar CO2/H2 | Used for adsorption, pressurization, and purge. |
| Adsorption feed flow | 20 cm3/s | Constant volumetric setpoint. Molar flow changes with pressure. |
| Purge feed flow | 50 cm3/s | Same equimolar feed, not pure H2 purge. |
| Pressurization flow setpoint | same as adsorption | Actual flow only approximately 20 cm3/s because MFC response changes with pressure/properties. |
| Feed temperature | 25 degC | Ambient/wall environment also 25 degC in model assumptions. |
| Low/desorption pressure | 1 bar | All cases. |
| Cycles run | 20-30 cycles | Experiments run to periodic steady state. |
| Reproducibility | each condition repeated at least once | Important for validation reporting. |
| Initial full regeneration | 150 degC under vacuum for 8 h before first experiment | Experimental context. |
| Between-experiment regeneration | vacuum for 45 min | Experimental context. |

Flow-rate conversion warning:

```text
n_dot = P * Q / (R * T)
```

The canonical source pack treats the reported volumetric flows as actual volumetric setpoints at step pressure and 298.15 K because the paper states that molar feed flow changes with pressure. Under this assumption, `20 cm3/s` corresponds to approximately `0.01614 mol/s` at 20 bar and `0.000807 mol/s` at 1 bar. A standard-volume interpretation changes the central feed molar flow by about a factor of 20, so it must be a labelled sensitivity or diagnostic choice rather than a silent substitution.

## Cycle steps

The one-column step sequence is:

| Step | Direction and role |
|---|---|
| Adsorption | At `p_high`; constant volumetric feed; H2-rich high-pressure product; bottom-up flow. |
| Pressure equalization, Peq | High-pressure column after adsorption connects to low-pressure column after purge until intermediate pressure `p_peq`; same directions as pressurization and blowdown. |
| Blowdown | Pressure reduced from `p_peq` to `p_low`; countercurrent to adsorption; CO2-rich low-pressure product. |
| Purge | At `p_low`; constant equimolar feed; countercurrent to adsorption; CO2-rich low-pressure product. |
| Pressurization | Pressure increased from `p_peq` to `p_high`; cocurrent with adsorption. |

Idle steps exist in the two-column schedule and depend on the timings. Preserve them if toPSAil cycle scheduling requires explicit idle periods.

The intermediate equalization pressure `p_peq` is not given as a simple table parameter. Use native toPSAil equalization first. Do not invent `p_peq`; derive or digitize it only in a separate authorised task.

## Cycle timing and experimental performance

Source: Schell 2013 Table 2.

| Case | p_high bar | t_press s | t_ads s | t_peq s | t_blow s | t_purge s | H2 purity % | H2 recovery % | CO2 purity % | CO2 recovery % |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 10 | 30 | 40 | 3 | 30 | 15 | not measured | not measured | not measured | not measured |
| 2 | 20 | 24 | 40 | 3 | 50 | 15 | not measured | not measured | not measured | not measured |
| 3 | 30 | 28 | 35 | 3 | 55 | 15 | not measured | not measured | not measured | not measured |
| 4 | 20 | 24 | 20 | 3 | 50 | 15 | 95.2 +/- 1.5 | 62.0 +/- 5.8 | 71.9 +/- 4.3 | 96.9 +/- 5.8 |
| 5 | 20 | 24 | 40 | 3 | 50 | 15 | 93.4 +/- 1.5 | 74.4 +/- 5.7 | 78.7 +/- 4.7 | 94.8 +/- 5.7 |
| 6 | 20 | 24 | 60 | 3 | 50 | 15 | 88.5 +/- 1.5 | 93.0 +/- 5.5 | 92.6 +/- 5.7 | 88.0 +/- 5.4 |
| 7 | 20 | 24 | 100 | 3 | 50 | 15 | 71.8 +/- 1.5 | 93.8 +/- 3.5 | 91.1 +/- 5.1 | 63.1 +/- 3.5 |
| 8 | 20 | 24 | 100 | 3 | 50 | 15 | 72.5 +/- 1.5 | 95.4 +/- 3.7 | 93.4 +/- 5.4 | 63.9 +/- 3.7 |

Cases 7 and 8 are a repeat at `t_ads = 100 s`. Cases 1-3 provide pressure/cycle profile validation but no purity/recovery table metrics.

## Recommended validation progression

1. Implement the 20 bar `t_ads = 40 s` case first because it has both timing and performance metrics and matches the central operating condition.
2. Add the other 20 bar performance cases with `t_ads = 20, 60, 100 s`.
3. Add 10 bar and 30 bar profile cases after the central 20 bar case is stable.

Do not tune physics separately for each adsorption time. The series is meant to test prediction over changing cycle time, not your ability to fit four unrelated stories.

## Model parameters from Schell 2013 Table 3

| Parameter | CO2 | H2 | Units | Notes |
|---|---:|---:|---|---|
| LDF mass-transfer coefficient `k_i` | 0.15 | 1.0 | s^-1 | Values from Casas breakthrough fitting. |
| Gas heat capacity `Cg_i` | 42.5 | 29.0 | J/(K mol) | Average values for encountered conditions. |
| Fluid viscosity `mu` | 1.46e-5 | 1.46e-5 | Pa s | Average for equimolar CO2/H2 at 30 degC and 15 bar. |
| Fluid thermal conductivity `K_L` | 0.04 | 0.04 | W/(m K) | Used in the heat-transfer correlation; do not treat it as an active axial-dispersion coefficient. |
| Wall heat-transfer coefficient `hW` | 5 | 5 | W/(m2 K) | Hard transcription. |
| Nusselt eta1 | 0.813 | 0.813 | dimensionless | Original Leva value used in PSA model. |
| Nusselt eta2 | 0.9 | 0.9 | dimensionless | Original Leva value used in PSA model. |

The paper discusses using a nonzero heat-transfer coefficient during idle steps because the velocity-based Leva correlation would otherwise produce zero heat exchange. If this detail is implemented, label it as a Schell reproduction detail.

Implementation naming rule: keep Table 3 LDF rates separate from the Sips affinity term. Recommended internal names are `ldf_rate_per_s` for the Table 3 mass-transfer coefficient and `sips_affinity_inv_Pa` for the temperature-corrected Sips affinity.

## Sips adsorption model and parameters

Source: Schell 2013 SI Table 3.

Use the competitive Sips form:

```text
n_i_star = n_inf_i * (k_i * y_i * p)^s_i / (1 + sum_j (k_j * y_j * p)^s_j)
n_inf_i = a_i * exp(-b_i / (R*T))
k_i = A_i * exp(-B_i / (R*T))
s_i = alpha_i * atan(beta_i * (T - Tref_i)) + sref_i
```

`T` is in K and `p` is in Pa.

The symbol `k_i` in the Sips equation is the temperature-corrected adsorption affinity with units `1/Pa`, not the Table 3 LDF mass-transfer coefficient with units `s^-1`.

| Component | a_i | b_i | A_i | B_i | alpha_i | beta_i | sref_i | Tref_i | DeltaH_i |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| CO2 | 1.38 mol/kg | -5628 J/mol | 1.68e-8 1/Pa | -9159 J/mol | 0.072 | 0.106 1/K | 0.83 | 329 K | -21000 J/mol |
| H2 | 6.66 mol/kg | 0 J/mol | 6.97e-10 1/Pa | -9826 J/mol | 0 | 0 1/K | 0.96 | 273 K | -9800 J/mol |

Important distinction: use `DeltaH_CO2 = -21000 J/mol` for Schell PSA. Casas 2012 breakthrough used `-26000 J/mol`.

## Source-specific pressure boundary functions

These are diagnostic/reproduction details, not default toPSAil-native settings.

Schell gives these forms for pressure-changing steps:

```text
Blowdown:
p(x = 0, t) = p_low + (p_peq - p_low) * exp(-xi * t)

Pressurization:
p(x = 0, t) = p_peq + ((p_high - p_peq) / t_press) * t
```

The fitted blowdown factor reported in the paper is:

```text
xi = 0.28
```

Only implement these in a labelled Schell reproduction mode.

`p_peq` is intentionally unresolved in the source pack. For the default validation path, let toPSAil-native equalization determine the intermediate pressure and report the endpoint. A source-reproduction task may later digitize Figure 7 or inspect the prior Casas equalization method.

## Piping and stagnant-tank diagnostics

Do not include these in default validation unless the task specifically targets detector/composition profile reproduction. Piping and stagnant-tank effects are diagnostic-only by default because the source uses them to explain distorted detector concentration traces, not to define the table-performance validation.

Source: Schell 2013 Table 4 and discussion.

| Diagnostic parameter | Symbol | Value | Units |
|---|---:|---:|---|
| Pipe length before BPR | L1 | 1.5 | m |
| Pipe length after BPR | L2 | 4.0 | m |
| Pipe diameter | d_pipe | 0.008 | m |
| Pipe temperature | T_pipe | 298 | K |
| Pipe dispersion coefficient | D_pipe | 0.001 | m2/s |
| Optional stagnant tank volume | V_Tank | 2.0e-5 | m3 |
| Optional tank exchange rate | - | 98 | % |

The paper explicitly treats the stagnant tank as a cautionary diagnostic to explain profile discrepancies. It is not a required physical element of the default model.

## Product-performance calculation logic

Source: Schell 2013 SI.

For performance cases at 20 bar:

1. Integrate the feed through both MFCs over pressurization, adsorption, and purge to obtain component input amounts.
2. Determine H2-rich product component amounts during adsorption from product flow and composition.
3. Compute CO2-rich product amounts by subtraction from the component input amounts.
4. Report mean values from the two columns over three process cycles, giving six values.

Use the table metrics above as validation targets. For the `t_ads = 40 s` example, the SI calculation gives CO2 purity 78.7% and capture/recovery 94.8%, matching Table 2.

## Model assumptions to preserve

| Assumption | Implementation consequence |
|---|---|
| 1D nonisothermal nonequilibrium model | Do not add radial gradients or equilibrium shortcuts. |
| Ideal gas | Acceptable in source because compressibility remained >0.9 under the tested conditions. |
| Thermal equilibrium between gas and adsorbent | One bed temperature field is acceptable unless toPSAil separates phases. |
| Axial dispersion/conductivity neglected in PSA | Do not import Casas breakthrough axial-dispersion requirements into the default Schell PSA case. |
| Lumped column wall/heating layers | Use Schell Table 1 wall values if wall heat model exists. |
| Ambient temperature fixed at 25 degC | `Tamb = 298.15 K`. |
| LDF mass transfer | Use `k_i` values in Table 3. |
| Constant mass-transfer coefficients, heat of adsorption, and heat capacities | Do not make them temperature-dependent unless separately justified. |

## Validation reporting requirements

Every Schell validation report should state:

- case number and `t_ads`;
- parameter pack path;
- whether the run is toPSAil-native or Schell-reproduction mode;
- number of cycles simulated;
- CSS residual or equivalent convergence metric;
- H2 purity and recovery;
- CO2 purity and recovery/capture;
- whether table uncertainty bands are met;
- whether pressure and temperature histories are qualitatively plausible;
- any omitted diagnostic details such as piping or stagnant tank.

## Do not mix with other stages

| Do not import | Reason |
|---|---|
| Casas 2012 CO2 heat `-26000 J/mol` | Schell PSA SI uses `-21000 J/mol`. |
| Delgado BPL/13X Langmuir-Freundlich parameters | Different adsorbents, feed, and validation purpose. |
| Casas thesis adiabatic optimisation assumptions | Schell experimental setup includes wall/heating effects. |
| Detector piping as default validation | It is a diagnostic detail, not the primary table-performance validation. |
