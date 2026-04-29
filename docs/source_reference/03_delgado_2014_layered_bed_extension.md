# Stage 4 - Delgado 2014 Layered-Bed Extension Sheet

## Codex task role

Use this file only after the Casas-lite and Schell validation stages are stable. Delgado 2014 is not an experimental PSA validation for this project. It is a simulation-to-simulation extension target for layered beds, four-component H2 purification, and contaminant polishing.

Primary parameter-pack target:

```text
params/delgado2014_bpl13x_lf_four_component/
```

This stage introduces different adsorbents, a different isotherm family, and different gases. Do not contaminate the AP3-60 Casas/Schell parameter files with Delgado values. Truly, let one parameter pack stay pure in this fallen world.

## Source anchors and check status

| Item | Source anchor | Check status |
|---|---|---|
| Adsorbent properties | Delgado 2014 Table 1, rendered `delgado2014/page-02.png` | Rendered table checked. |
| Langmuir-Freundlich parameters | Delgado 2014 Table 4, rendered `delgado2014/page-08.png`, text lines 449-461 | Rendered table + text checked. |
| PSA cycle and operating conditions | Delgado 2014 Figure 8 and text, rendered `delgado2014/page-09.png`, text lines 520-563 | Text extraction + figure crop checked. |
| PSA model equations | Delgado 2014 Table 6, rendered `delgado2014/page-10.png`, text lines 566-623 | Text extraction + rendered table checked. |
| Performance targets | Delgado 2014 text lines 626-649 and conclusions lines 666-681 | Text extraction checked. |
| Diffusion/Henry data | Delgado SI Tables S1-S2, rendered `delgado2014_si/page-1.png` to `page-4.png` | Rendered SI tables checked. |

## Stage goal

Add or exercise toPSAil functionality for:

```text
components = H2, CO, CO2, CH4
adsorbents = BPL 4X10 activated carbon, 13X zeolite pellets
bed structure = BPL from feed end followed by 13X
feed = 76% H2, 4% CO, 17% CO2, 3% CH4
T_feed = 298 K
p_high = 16 bar
p_low = 1 bar
```

The target process is a four-column layered-bed PSA for H2 purification from SMR off-gas.

## Adsorbent physical properties

Source: Delgado 2014 Table 1.

| Adsorbent | Particle density | Particle size | Particle porosity | Micropore volume | Average pore diameter | BET surface area |
|---|---:|---:|---:|---:|---:|---:|
| BPL 4X10 activated carbon | 0.916 g/cm3 | 1.3 mm | 0.35 | 0.36 cm3/g | 0.64 nm | 859 m2/g |
| 13X zeolite pellets | 1.357 g/cm3 | 1.5 mm | 0.47 | 0.17 cm3/g | 0.87 nm | 392 m2/g |

Experimental regeneration context:

| Adsorbent | Regeneration before pulse experiments |
|---|---|
| BPL 4X10 | Overnight at 423 K under helium flow for pulse experiments; 10 h at 423 K under vacuum before volumetric adsorption. |
| 13X | Overnight at 623 K under helium flow for pulse experiments; 10 h at 593 K under vacuum before volumetric adsorption. |

## Langmuir-Freundlich adsorption model

Source: Delgado 2014 Table 6 and Table 4.

Use the extended Langmuir-Freundlich form:

```text
n_i_star = nmax_i * (k_i * p_i)^m_i / (1 + sum_j (k_j * p_j)^m_j)
nmax_i = a_i + b_i / T
k_i = k0_i * exp(Q_i / T)
```

`T` is in K and `p_i` is in Pa. Table 4 provides `m` per component, so use component-specific exponents rather than one global exponent unless a toPSAil implementation deliberately documents otherwise.

## Langmuir-Freundlich parameters

Source: Delgado 2014 Table 4.

| Adsorbent | Gas | a mol/kg | b mol K/kg | k0 1/Pa | Q K | m | Qst kJ/mol |
|---|---|---:|---:|---:|---:|---:|---:|
| BPL | H2 | 7.3775 | 0 | 1.6068e-9 | 919.96 | 1 | 7.6 |
| BPL | CH4 | 3.2220 | 0 | 1.9903e-9 | 2216.2 | 1 | 18.4 |
| BPL | CO | 3.3201 | 0 | 1.6169e-9 | 1965.9 | 1 | 16.3 |
| BPL | CO2 | -2.4532 | 3095.0 | 3.2373e-9 | 1964.0 | 0.8666 | 20.9 |
| 13X | H2 | 6.8776 | 0 | 6.0504e-10 | 1142.1 | 1 | 9.5 |
| 13X | CH4 | 7.5284 | 0 | 7.2149e-10 | 2018.2 | 1 | 16.8 |
| 13X | CO | 2.2088 | 0 | 4.0290e-10 | 2804.5 | 1 | 23.3 |
| 13X | CO2 | 2.5093 | 691.69 | 1.0778e-9 | 3354.4 | 0.8608 | 31.6 |

## PSA process configuration

Source: Delgado 2014 Figure 8 and text.

| Quantity | Value | Notes |
|---|---:|---|
| Number of columns | 4 | Simulated with one-column state sequence and stored connecting streams. |
| Column length | 8 m | Hard transcription. |
| Column radius | 0.8 m | Hard transcription. |
| Feed composition | 76% H2, 4% CO, 17% CO2, 3% CH4 | SMR off-gas example. |
| Feed temperature | 298 K | Hard transcription. |
| High cycle pressure | 16 bar | Hard transcription. |
| Low cycle pressure | 1 bar | Hard transcription. |
| Initial pressure of blowdown | 2.8 bar | Used as final pressure of DEQ2 in trial-error equalization setup. |
| Bed layers | BPL from feed end, then 13X | Source wording says BPL activated carbon layer starting from feed end followed by 13X layer. |
| Best activated-carbon proportion | 55% | Interpreted as column/layer proportion unless implementation documents another basis. |
| Best feed superficial velocity | 0.097 m/s | Case 1 result. |
| Process bed porosity | 0.4 | Same bed porosity assumed in both layers for PSA simulation. |
| Particle radius in PSA paragraph | 0.7 cm | Conflicts with Table 1 particle sizes of 1.3-1.5 mm; see ambiguity note below. |
| Axial heat/mass Peclet numbers | 500 | Set high to approximate plug flow. |
| H2 reciprocal diffusion time constant | 30 s^-1 | Assumed high value; little effect on simulation results. |

### Particle-radius ambiguity

The source paragraph for the PSA model says the same particle radius `0.7 cm` is assumed in both adsorbent layers. This conflicts with Table 1 particle sizes of 1.3 mm and 1.5 mm, which imply radii around 0.65-0.75 mm. The rendered source really reads `0.7 cm`, not an OCR artefact.

Implementation instruction:

- Do not silently correct this.
- Record which value is used.
- Prefer adding two explicit options in the Delgado parameter file:

```text
particle_radius_source_literal_m = 0.007
particle_radius_table_consistent_m = 0.0007
```

Then require a task-level decision before using one as a hard reproduction setting.

## Cycle sequence

The source sequence is:

```text
ADS -> DEQ1 -> PP -> DEQ2 -> BD -> RP -> PEQ2 -> PEQ1 -> BF
```

| Step | Meaning |
|---|---|
| ADS | Adsorption. Feed gas enters at high cycle pressure. |
| DEQ1 | Depressurizing equalization 1 through light end; released gas pressurizes another column. |
| PP | Provide purge. Column depressurizes through light end; released gas purges another column. |
| DEQ2 | Depressurizing equalization 2, like DEQ1, starting from final PP pressure. |
| BD | Blowdown to low pressure through feed end; waste gas obtained. |
| RP | Receive purge through light end with feed end open at low pressure; waste gas exits feed end. |
| PEQ2 | Pressurizing equalization 2 through light end using gas from another column undergoing DEQ2. |
| PEQ1 | Pressurizing equalization 1 through light end using gas from another column undergoing DEQ1. |
| BF | Backfill through light end with light product up to high cycle pressure. |

## Cycle timing from Figure 8

The figure has a four-column staggered schedule with duration intervals:

```text
30, 180, 30, 30, 180, 30, 30, 180, 30, 30, 180, 30 s
```

total schedule length:

```text
960 s
```

A Column 1 reading of Figure 8 gives:

| Segment | Duration | Step |
|---:|---:|---|
| 1 | 30 s | Idle/blank alignment interval before ADS in the figure row |
| 2 | 240 s | ADS |
| 3 | 30 s | DEQ1 |
| 4 | 180 s | PP |
| 5 | 30 s | DEQ2 |
| 6 | 30 s | BD |
| 7 | 180 s | RP |
| 8 | 30 s | PEQ2 |
| 9 | 30 s | PEQ1 |
| 10 | 180 s | BF |

The text explicitly says adsorption is 4 min and equalization/blowdown steps are 30 s. The 180 s PP/RP/BF durations are figure-derived. Treat this schedule as a reproduced-source configuration, not as a generic toPSAil default.

## Pressure and boundary implementation notes

Source text states:

| Feature | Source handling |
|---|---|
| Component molar flow and heat flow on gas introduction | Danckwerts boundary conditions. |
| Steps with fixed final pressure | Linear pressure variations for DEQ1, DEQ2, BD, and BF. |
| PEQ1 and PEQ2 final pressures | Not known beforehand; determined by trial and error so PEQ final pressures match corresponding DEQ pressures. |
| DEQ1, DEQ2, PP discharged streams | Stored and reused as boundary histories for PEQ1, PEQ2, and RP, respectively. |
| Interpolation of stored streams | Hermite cubic polynomials. |
| Numerical method in source | Orthogonal collocation on finite elements; DLSODIS in ODEPACK. |

Do not try to force all of this into the default workflow before proving toPSAil can support layered beds and four components in a simpler case.

## Diffusion and kinetic constants

Source text says reciprocal diffusion time constants at 298 K were taken from SI Tables S1 and S2, with H2 set to 30 s^-1. The SI tables do not provide exact 298 K rows for every gas/adsorbent pair. They provide temperature series. The estimates below are derived by using the source-reported activation energies and listed `Dc/rc^2` values to extrapolate/interpolate to 298 K. These are therefore **derived implementation estimates**, not direct table entries.

### Suggested 298 K reciprocal diffusion constants for implementation tests

| Adsorbent | Gas | Suggested `Dc/rc^2` at 298 K | Status |
|---|---|---:|---|
| BPL | H2 | 30 s^-1 | Source assumption. |
| BPL | CH4 | 0.109 s^-1 | Derived from SI S1. |
| BPL | CO | 0.464 s^-1 | Derived from SI S1. |
| BPL | CO2 | 0.030 s^-1 | Derived from SI S1; source text separately notes approx 0.031 s^-1. |
| 13X | H2 | 30 s^-1 | Source assumption. |
| 13X | CH4 | 0.216 s^-1 | Derived from SI S2. |
| 13X | CO | 0.101 s^-1 | Derived from SI S2. |
| 13X | CO2 | 2.60e-4 s^-1 | Derived from SI S2. |

### Raw SI diffusion series, compact reference

Use this if a task asks to reconstruct or revise the 298 K estimates.

| Adsorbent | Gas | Source temperatures K | Listed `Dc/rc^2` s^-1 | E_diff kJ/mol | Notes |
|---|---|---|---|---:|---|
| BPL | H2 | 288, 308, 323 | insensitive/infinite | not listed | Use 30 s^-1 in PSA. |
| BPL | CH4 | 288, 308, 323, 343 | 0.09, 0.12, 0.18, 0.25 | 15.6 | Multiple flow rows at each T. |
| BPL | CO | 289, 323 | 0.44, 0.53 | 4.2 | Multiple flow rows at each T. |
| BPL | CO2 | 308, 322-323, 341-342 | 0.04, 0.05, 0.08 | 18.4 | Multiple flow rows at each T. |
| 13X | H2 | 289, 323 | insensitive/infinite | not listed | Use 30 s^-1 in PSA. |
| 13X | CH4 | 289, 309, 322-324 | 0.18, 0.27, 0.33 | 13.8 | Multiple flow rows at each T. |
| 13X | CO | 287, 308, 322, 342 | 0.08, 0.12, 0.16, 0.26 | 17.1 | Multiple flow rows at each T. |
| 13X | CO2 | 323, 343 | 0.00044, 0.00059 | 16.2 | Very slow. |

## Performance targets

Primary Delgado case, called case 1 in the source:

| Quantity | Value |
|---|---:|
| Feed superficial velocity | 0.097 m/s |
| Activated-carbon proportion | 55% |
| H2 purity | 99.993% |
| Calculated CO concentration in H2 product | 63 ppm |
| H2 recovery | 90.3% |
| H2 productivity | 7.2 mol H2 kg^-1 h^-1 |

Sensitivity/comparison values from the same source discussion:

| Case | Difference from case 1 | Reported result |
|---|---|---|
| Case 2 | 60% activated carbon | H2 purity 99.991% |
| Case 3 | 50% activated carbon | H2 purity 99.951% |
| Case 4 | Replace 13X layer with 5A zeolite | H2 purity 99.81%, H2 recovery 92.6%, productivity 7.4 mol H2 kg^-1 h^-1 |

Qualitative profile target:

- methane should be removed by the activated-carbon layer;
- carbon monoxide should penetrate into the 13X layer and be captured before contaminating the H2 product;
- carbon dioxide may accumulate in the zeolite layer, but not enough in case 1 to destroy CO polishing capacity.

## Performance definitions

Source: Delgado 2014 Table 6.

```text
H2 purity = [(moles H2 out during ADS) - (moles H2 in during BF)]
            / [(total moles out during ADS) - (total moles in during BF)] * 100

H2 recovery = [(moles H2 out during ADS) - (moles H2 in during BF)]
              / [(moles H2 in during ADS)] * 100

H2 productivity = [(moles H2 out during ADS) - (moles H2 in during BF)]
                  / [(cycle time) * (mass of adsorbents in one column)]
```

## Delgado implementation guardrails

1. Do not use Delgado as proof that the Schell AP3-60 validation works. It is not the same system.
2. Do not implement Delgado until the code audit confirms whether toPSAil supports layered beds or spatially varying adsorbent properties.
3. Do not silently collapse BPL and 13X into one pseudo-adsorbent.
4. Do not silently replace the source Langmuir-Freundlich form with Sips.
5. Do not ignore the particle-radius ambiguity.
6. Do not use the 5A comparison case unless 5A parameters from Park et al. are separately supplied or authorised.
