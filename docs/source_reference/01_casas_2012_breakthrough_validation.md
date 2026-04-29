# Stage 2 - Casas 2012 Breakthrough Validation Sheet

## Codex task role

Use this file for the Casas-lite fixed-bed CO2/H2 breakthrough sanity case. The objective is not exact detector-piping reproduction. The objective is a credible AP3-60 activated-carbon breakthrough simulation with physically plausible timing, thermal response, and solver behaviour.

Primary parameter-pack target:

```text
params/casas2012_ap360_sips_binary/
```

`ap360` in the planned path should be read as the project label for the AP3-60 activated carbon used in the Casas/Schell papers.

## Source anchors and check status

| Item | Source anchor | Check status |
|---|---|---|
| Column and bed parameters | Casas 2012, Table 2, rendered `casas2012/page-08.png`, text lines 466-489 | Text extraction + rendered table checked. |
| Experiment matrix | Casas 2012, Table 1, rendered `casas2012/page-08.png`, text lines 542-552 | Rendered table checked. |
| Sips/Langmuir parameters | Casas 2012, Table 4, rendered `casas2012/page-10.png`, text lines 584-604 | Text extraction + rendered table checked. |
| Dynamic heat/mass parameters | Casas 2012, Table 3, rendered `casas2012/page-10.png`, text lines 575-580 | Text extraction + rendered table checked. |
| Reference breakthrough timing | Casas 2012, Figure 4 and text, rendered `casas2012/page-09.png`, text lines 554-568 | Text-anchored H2 time; CO2 timing is plot-read only. |

## Stage goal

Build a one-column fixed-bed breakthrough case using the source geometry, AP3-60 adsorbent properties, Sips isotherm, LDF kinetics, and reference operating condition:

```text
feed = 50/50 CO2/H2
T = 25 degC
p = 15 bar
feed flow = 10 cm3/s
initial gas = He
```

Use this as a smoke/sanity validation before full PSA cycle validation. Do not overfit the front shape.

## Experimental system

| Quantity | Value | Notes |
|---|---:|---|
| Adsorbent | AP3-60 activated carbon | Chemviron Carbon, Germany. |
| Pellet/particle size | 3 mm | Source material description and Table 2. |
| Skeletal/material density | 1.97 g/cm3 | Measured by helium pycnometer. Do not confuse with particle density below. |
| Column length | 1.2 m | Stainless steel column. |
| Inner diameter | 2.5 cm | Corresponds to `Ri = 0.0125 m`. |
| Thermocouple positions | 10, 35, 60, 85, 110 cm from inlet | Used for thermal-front sanity checks. |
| Feed-flow controller | MFC | Source reports flow as `10 cm3/s`; be careful before converting to molar flow because the source discusses pressure/composition effects. |
| Outlet composition measurement | Mass spectrometer after piping | Detector/piping reproduction is not a Casas-lite objective. |

## Reference operating condition

Use this case first:

| Quantity | Value |
|---|---:|
| Feed composition | 50 mol% CO2, 50 mol% H2 |
| Pressure | 15 bar |
| Temperature | 25 degC = 298.15 K |
| Feed flow rate | 10 cm3/s |
| Initial pressurisation gas | He |
| Regeneration before experiment | Vacuum for 45 min |

The more severe regeneration procedure is 150 degC under vacuum for 1 h 30 min after a maximum of four experiments. That is experimental context, not a simulation boundary condition unless explicitly modelled.

## Experiment matrix from Table 1

The source tested the following pressure/temperature/feed-composition combinations. Use this table only for optional expanded validation after the reference case.

| Feed CO2/H2 | T = 25 degC | T = 45 degC | T = 65 degC | T = 100 degC |
|---|---|---|---|---|
| 25/75 | 1, 5, 10, 15, 20, 25, 35 bar | 5, 10, 15, 25 bar | 15 bar | 15 bar |
| 50/50 | 5, 10, 15, 20, 25, 35 bar | 5, 10, 15, 25 bar | 15 bar | 15 bar |
| 75/25 | 5, 10, 15, 20, 25, 35 bar | 5, 10, 15, 25 bar | 15 bar | 15 bar |

Important guardrail: the source says the heating system was inadequate above 60 degC, so the 65 degC and 100 degC data should not be treated as strict validation targets.

## Column, bed, and thermal parameters

Source: Casas 2012 Table 2.

| Parameter | Symbol | Value | Units | Implementation note |
|---|---:|---:|---|---|
| Column length | L | 1.20 | m | Hard transcription. |
| Inner column radius | Ri | 0.0125 | m | From 2.5 cm inner diameter. |
| Outer column radius, lumped | R0 | 0.020 | m | Includes wall/heating lump. |
| Bed porosity | eps_b | 0.403 | dimensionless | Measured. |
| Total porosity | eps_t | 0.742 | dimensionless | Calculated. |
| Bulk density of packing | rho_b | 507 | kg/m3 | Measured. |
| Particle density | rho_p | 850 | kg/m3 | Manufacturer value. |
| Particle size | dp | 0.003 | m | Manufacturer value. |
| Specific surface area | a_p | 8.5e8 | m2/m3 | Manufacturer value. |
| Solid heat capacity | C_s | 1000 | J/(kg K) | Manufacturer value. |
| Lumped wall heat capacity | C_w | 4.0e6 | J/(m3 K) | Manufacturer value. |
| Molecular diffusion | D_m | 4.3e-6 | m2/s | Calculated for 50/50 CO2/H2 at 298 K and 15 bar. |
| Piping diffusion | D_L_pipe | 0 | m2/s | Diagnostic piping model only. |
| Heat of adsorption, CO2 | DeltaH_CO2 | -26000 | J/mol | Casas breakthrough value. Do not replace with Schell PSA value. |
| Heat of adsorption, H2 | DeltaH_H2 | -9800 | J/mol | Hard transcription. |

Fluid heat capacity in Table 2 is not given as a single numeric value. The source says it is calculated as an average over 298-373 K at 15 bar. Do not invent a number here; use the simulator's gas-property handling or an explicitly documented calculation.

## Dynamic mass and heat-transfer parameters

Source: Casas 2012 Table 3.

| Parameter set | k_CO2 | k_H2 | hW | eta1 | eta2 |
|---|---:|---:|---:|---:|---:|
| Correlation estimate | 0.33 s^-1 | 0.33 s^-1 | 8.8 J/(m2 s K) | 0.813 | 0.9 |
| Fitted to reference experiment | 0.15 s^-1 | 1.0 s^-1 | 5 J/(m2 s K) | 41.13 | 0.32 |

For Casas-lite, use the fitted values unless the task explicitly asks to compare the correlation estimate.

The source axial dispersion correlation is:

```text
D_L = gamma1 * D_m + gamma2 * dp * u / eps
```

with typical values:

```text
gamma1 = 0.7
gamma2 = 0.5
```

Exact axial-dispersion/front-shape reproduction is not a Casas-lite objective, so do not destabilise a toPSAil-native case merely to match detector-tail shape.

## Sips adsorption model

Use the competitive Sips form as the preferred Casas breakthrough equilibrium model:

```text
q_i_star = q_s_i * (K_i * p_i)^s_i / (1 + sum_j (K_j * p_j)^s_j)
q_s_i = omega_i * exp(-theta_i / (R*T))
K_i = Omega_i * exp(-Theta_i / (R*T))
s_i = s1_i * atan(s2_i * (T - Tref_i)) + sref_i
```

`T` is in K, `p_i` is in Pa, `R` is the gas constant.

### Sips parameters

Source: Casas 2012 Table 4.

| Component | omega_i | theta_i | Omega_i | Theta_i | s1_i | s2_i | sref_i | Tref_i |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| CO2 | 1.38 mol/kg | -5628 J/mol | 16.80e-9 1/Pa | -9159 J/mol | 0.072 | 0.106 1/K | 0.827 | 329 K |
| H2 | 6.66 mol/kg | 0 J/mol | 0.70e-9 1/Pa | -9826 J/mol | 0 | 0 1/K | 0.9556 | 273 K |

### Langmuir parameters, optional only

Do not use these for the default Casas-lite case unless the task explicitly requests a Langmuir comparison.

| Component | omega_i | theta_i | Omega_i | Theta_i |
|---|---:|---:|---:|---:|
| CO2 | 2.07 mol/kg | -4174 J/mol | 5.59e-9 1/Pa | -13133 J/mol |
| H2 | 5.35 mol/kg | 0 J/mol | 0.88e-9 1/Pa | -10162 J/mol |

## Model assumptions to preserve

Use these assumptions when mapping the source case to a simulator case:

| Assumption | Implementation consequence |
|---|---|
| One-dimensional column model | Do not add radial gradients. |
| Thermal equilibrium between gas and adsorbent particles | Single gas/solid bed temperature is acceptable in Casas-lite. |
| Lumped wall/heating system | Use source wall lump only if thermal wall model exists or is added deliberately. |
| Environment temperature equals heating set point | `Tamb = T_set`. |
| Temperature-independent mass-transfer coefficients, heats of adsorption, solid/wall heat capacities | Do not tune these over the breakthrough run. |
| LDF mass transfer | Use `k_i * (q_i_star - q_i)`. |
| Piping to MS modelled as isothermal plugflow in source | Treat as diagnostic only, not default Casas-lite requirement. |

## Validation targets

### Hard textual target

For the reference case, the source states that the 110 cm temperature peak for H2 is measured at about 110 s and corresponds to the H2 breakthrough time.

Use this only as an approximate timing sanity check:

```text
H2 breakthrough time: about 110 s
```

### Soft plot-read targets from Figure 4

These values are approximate and should not be used as strict pass/fail thresholds unless the figure is digitised in a separate task.

| Quantity | Approximate behaviour |
|---|---|
| H2 outlet mole fraction | Rises from near 0 to near 1 around 110-130 s. |
| Pure-H2 production window | After H2 breakthrough and before CO2 breakthrough. |
| CO2 breakthrough | Begins roughly around 430-460 s by visual plot read. |
| Final outlet composition | Approaches 50/50 feed after the CO2 front and thermal tail settle. |
| Temperature profiles | Small H2 heat front first; larger CO2 heat front later; fronts move through 10, 35, 60, 85, 110 cm thermocouples. |

## Casas-lite acceptance guidance

A first successful case should report:

- source parameter file used;
- solver mode and grid count;
- feed composition, pressure, temperature, and flow units;
- approximate H2 breakthrough time;
- approximate CO2 breakthrough time if computed;
- whether a temperature rise is observed and whether the front order is plausible;
- whether mass balance residuals are sane;
- whether detector piping was omitted, included, or postponed.

Do not tune isotherm or kinetic parameters to force the smoke test to match Figure 4. That would be less validation and more numerically assisted wishful thinking.

## Do not mix with other stages

| Do not import | Reason |
|---|---|
| Schell PSA CO2 heat of adsorption `-21000 J/mol` | Casas breakthrough Table 2 uses `-26000 J/mol`. |
| Delgado BPL/13X Langmuir-Freundlich parameters | Different adsorbents and gas system. |
| Casas thesis adiabatic PSA assumptions | Casas 2012 breakthrough includes wall heat transfer. |
| Schell two-bed cycle timings | Different experiment and objective. |
