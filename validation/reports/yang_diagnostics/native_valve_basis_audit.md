# Yang native valve basis audit

- Created: 2026-05-02 13:54:19
- MATLAB version: 26.1.0.3203278 (R2026a)
- Runtime seconds: 5.62061
- Branch: `codex/yang`
- Commit SHA: `3028bda948c25e5ac52115dca30368a84cfd4b01`
- Git status short:

```text
?? diagnostic_outputs/
?? scripts/four_bed/diagnoseYangNativeValveBasis.m
?? scripts/four_bed/diagnostics/
?? validation/reports/yang_diagnostics/
```

- Recent commits:

```text
3028bda Revert native Cv sentinel pinning
aca7c2d Cull Yang Cv controls to direct transfers
15da510 Add fixed ADPP BF split control
46f9aa1 Apply Yang surrogate scaling corrections
c02a200 Set aggressive Yang solver tolerances
```

## Static audit result

- Adapter Cvs are raw/direct: `true`
- Native Cvs are scaled by `params.valScaleFac`: `true`
- `params.valScaleFac`: 2176282.464083839
- Runtime default `NativeValveCoefficient`: 1e-06
- Resolved default native valve: 2.176282464083839
- Unique default `valFeedColNorm`: [2.176282464083839]
- Unique default `valProdColNorm`: [2.176282464083839]

## Native preparation result

- Operation group: `EQII-B-to-A`
- Native family: `EQII`
- `prepReport.valveReport.defaultDimensionlessValve`: 2.176282464083839
- `prepReport.valveReport.valFeedColNorm`: [0, 0]
- `prepReport.valveReport.valProdColNorm`: [2.176282464083839, 2.176282464083839]
- `localParams.valFeedCol`: [0, 0]
- `localParams.valProdCol`: [1e-06, 1e-06]
- `localParams.valFeedColNorm`: [0, 0]
- `localParams.valProdColNorm`: [2.176282464083839, 2.176282464083839]

## Raw NativeValveCoefficient = 1 preparation

- Raw native coefficient supplied: 1
- Raw-1 `valScaleFac`: 2176282.464083839
- Resolved raw-1 native valve: 2176282.464083839
- Error identifier: none
- Raw-1 `prepReport.valveReport.defaultDimensionlessValve`: 2176282.464083839
- Raw-1 `prepReport.valveReport.valProdColNorm`: [2176282.464083839, 2176282.464083839]
- Raw native 1 safe to integrate: `false`

## Source snippets

### Cv_directTransfer default

File: `scripts/four_bed/normalizeYangFourBedControls.m`

```text
21:     [controls.Cv_directTransfer, controls.Cv_directTransferAliasReport] = ...
22:         getDirectTransferCv(controlsIn, defaults.Cv_directTransfer);
23:     controls.ADPP_BF_internalSplitFraction = getFractionField(controlsIn, ...
62:     defaults.feedVelocityCmSec = 5.2;
63:     defaults.Cv_directTransfer = 1.0e-6;
64:     defaults.ADPP_BF_internalSplitFraction = 1.0 / 3.0;
```

### ADPP_BF_internalSplitFraction default

File: `scripts/four_bed/normalizeYangFourBedControls.m`

```text
23:     controls.ADPP_BF_internalSplitFraction = getFractionField(controlsIn, ...
24:         'ADPP_BF_internalSplitFraction', defaults.ADPP_BF_internalSplitFraction);
25:     controls.adapterCoefficientBasis = "scaled_dimensionless_raw_direct";
63:     defaults.Cv_directTransfer = 1.0e-6;
64:     defaults.ADPP_BF_internalSplitFraction = 1.0 / 3.0;
65: end
```

### adapterCoefficientBasis value

File: `scripts/four_bed/normalizeYangFourBedControls.m`

```text
24:         'ADPP_BF_internalSplitFraction', defaults.ADPP_BF_internalSplitFraction);
25:     controls.adapterCoefficientBasis = "scaled_dimensionless_raw_direct";
26:     controls.derivedConductancePolicy = ...
```

### legacy adapter Cv alias handling

File: `scripts/four_bed/normalizeYangFourBedControls.m`

```text
113:     else
114:         [candidateValues, aliasNames] = collectAdapterAliasCandidates(s);
115:         if isempty(candidateValues)
121:                 error('FI6:ConflictingLegacyCvAliases', ...
122:                     ['Legacy adapter Cv aliases must collapse to one Cv_directTransfer ' ...
123:                     'value; conflicting aliases: %s.'], ...
148: 
149: function [values, names] = collectAdapterAliasCandidates(s)
150:     values = [];
```

### ignored native Cv control fields

File: `scripts/four_bed/normalizeYangFourBedControls.m`

```text
107:     aliasReport.ignoredControlBasisFields = strings(0, 1);
108:     aliasReport.ignoredNativeCvFields = strings(0, 1);
109:     aliasReport.PP_PU_wasteDerivedMultiplier = 2.0;
138: 
139:         nativeFields = ["Cv_EQI"; "Cv_EQII"; "Cv_AD_feed"; "Cv_BD_waste"];
140:         for i = 1:numel(nativeFields)
142:             if isfield(s, name) && ~isempty(s.(name))
143:                 aliasReport.ignoredNativeCvFields(end+1, 1) = nativeFields(i); %#ok<AGROW>
144:             end
```

### PP->PU raw adapter basis

File: `scripts/four_bed/validateYangDirectCouplingAdapterInputs.m`

```text
133:     cv = adapterConfig.Cv_directTransfer;
134:     adapterConfig.adapterCoefficientBasis = "scaled_dimensionless_raw_direct";
135:     adapterConfig.valveCoefficientBasis = adapterConfig.adapterCoefficientBasis;
136:     adapterConfig.rawCv = struct("Cv_directTransfer", cv);
137:     adapterConfig.effectiveCv = struct("Cv_directTransfer", cv);
138:     adapterConfig.adapterCvScalingApplied = false;
139:     adapterConfig.valScaleFac = NaN;
```

### AD&PP->BF raw adapter basis

File: `scripts/four_bed/validateYangAdppBfAdapterInputs.m`

```text
124:     cv = adapterConfig.Cv_directTransfer;
125:     adapterConfig.adapterCoefficientBasis = "scaled_dimensionless_raw_direct";
126:     adapterConfig.valveCoefficientBasis = adapterConfig.adapterCoefficientBasis;
127:     adapterConfig.rawCv = struct("Cv_directTransfer", cv);
128:     adapterConfig.effectiveCv = struct("Cv_directTransfer", cv);
129:     adapterConfig.adapterCvScalingApplied = false;
130:     adapterConfig.valScaleFac = NaN;
```

### NativeValveCoefficient default

File: `params/yang_h2co2_ac_surrogate/finalizeYangH2Co2AcTemplateParams.m`

```text
14:         (isscalar(x) || isvector(x)) && all(isfinite(x(:))) && all(x(:) > 0));
15:     addParameter(parser, "NativeValveCoefficient", 1e-6, @(x) isnumeric(x) && ...
16:         isscalar(x) && isfinite(x) && x > 0);
156:         "ldfBasis", "commissioning_design_default_not_source", ...
157:         "nativeValveCoefficient", opts.NativeValveCoefficient, ...
158:         "nativeValveBasis", "commissioning_design_default_not_source", ...
218: 
219: function params = ensureRuntimeBoundaryDefaults(params, nativeValveCoefficient)
220:     params.nSteps = max(1, params.nSteps);
231:     params.numAdsEqFeEnd = zeros(params.nCols, params.nSteps);
232:     params.valFeedColNorm = nativeValveCoefficient * params.valScaleFac * ...
233:         ones(params.nCols, params.nSteps);
234:     params.valProdColNorm = nativeValveCoefficient * params.valScaleFac * ...
235:         ones(params.nCols, params.nSteps);
```

### runtime valFeedColNorm scaling

File: `params/yang_h2co2_ac_surrogate/finalizeYangH2Co2AcTemplateParams.m`

```text
231:     params.numAdsEqFeEnd = zeros(params.nCols, params.nSteps);
232:     params.valFeedColNorm = nativeValveCoefficient * params.valScaleFac * ...
233:         ones(params.nCols, params.nSteps);
234:     params.valProdColNorm = nativeValveCoefficient * params.valScaleFac * ...
235:         ones(params.nCols, params.nSteps);
```

### prepare valScaleFac scaling

File: `scripts/four_bed/prepareYangNativeLocalRunParams.m`

```text
47: 
48:     [params.valFeedColNorm, params.valProdColNorm, valveReport] = ...
49:         resolveNativeValveMatrices(tempCase, controls, params);
50:     if isfield(params, 'valScaleFac') && isfinite(params.valScaleFac) && params.valScaleFac > 0
51:         params.valFeedCol = params.valFeedColNorm ./ params.valScaleFac;
52:         params.valProdCol = params.valProdColNorm ./ params.valScaleFac;
53:     end
174:         case "AD"
175:             valFeed(:) = getControlValve(controls, 'Cv_AD_feed', defaultCv, params);
176:         case "BD"
177:             valFeed(:) = getControlValve(controls, 'Cv_BD_waste', defaultCv, params);
178:         case "EQI"
179:             valProd(:) = getControlValve(controls, 'Cv_EQI', defaultCv, params);
180:         case "EQII"
181:             valProd(:) = getControlValve(controls, 'Cv_EQII', defaultCv, params);
182:         otherwise
186: 
187:     report.valFeedColNorm = valFeed;
188:     report.valProdColNorm = valProd;
189:     report.controlValveBasis = ...
190:         "controls Cv values are dimensional and multiplied by params.valScaleFac";
191:     report.nativeControlsWired = true;
193: 
194: function value = getControlValve(controls, fieldName, defaultValue, params)
195:     value = defaultValue;
197:             ~isempty(controls.(fieldName)) && isfinite(controls.(fieldName))
198:         value = controls.(fieldName) .* params.valScaleFac;
199:     end
206:             isfield(params.yangRuntimeDefaults, 'nativeValveCoefficient') && ...
207:             isfield(params, 'valScaleFac') && isfinite(params.valScaleFac)
208:         value = params.yangRuntimeDefaults.nativeValveCoefficient .* params.valScaleFac;
209:     end
```

### prepare defaultNativeValveCoefficient behaviour

File: `scripts/four_bed/prepareYangNativeLocalRunParams.m`

```text
49:         resolveNativeValveMatrices(tempCase, controls, params);
50:     if isfield(params, 'valScaleFac') && isfinite(params.valScaleFac) && params.valScaleFac > 0
51:         params.valFeedCol = params.valFeedColNorm ./ params.valScaleFac;
52:         params.valProdCol = params.valProdColNorm ./ params.valScaleFac;
53:     end
189:     report.controlValveBasis = ...
190:         "controls Cv values are dimensional and multiplied by params.valScaleFac";
191:     report.nativeControlsWired = true;
197:             ~isempty(controls.(fieldName)) && isfinite(controls.(fieldName))
198:         value = controls.(fieldName) .* params.valScaleFac;
199:     end
202: 
203: function value = defaultNativeValveCoefficient(params)
204:     value = 1.0;
205:     if isfield(params, 'yangRuntimeDefaults') && ...
206:             isfield(params.yangRuntimeDefaults, 'nativeValveCoefficient') && ...
207:             isfield(params, 'valScaleFac') && isfinite(params.valScaleFac)
208:         value = params.yangRuntimeDefaults.nativeValveCoefficient .* params.valScaleFac;
209:     end
```

### resolved native valve equal-to-1 rejection

File: `scripts/four_bed/prepareYangNativeLocalRunParams.m`

```text
217:     end
218:     if abs(value - 1) < 1e-12
219:         error('FI8:InvalidNativeValveCoefficient', ...
220:             '%s resolved to 1, which toPSAil uses as a non-Cv flag.', char(label));
221:     end
```

### test coverage for raw/direct adapter basis

File: `tests/four_bed/testYangValveCoefficientScaling.m`

```text
12: 
13:     fprintf('FI-8 Yang valve coefficient scaling passed: custom adapters use raw Cv_directTransfer.\n');
14: end
37:     assert(any(override.Cv_directTransferAliasReport.ignoredControlBasisFields == "adapterCvBasis"));
38:     assert(any(override.Cv_directTransferAliasReport.ignoredNativeCvFields == "Cv_EQI"));
39: end
58:     [params, ppCase] = buildAdapterContext("PP_PU");
59:     params.valScaleFac = 123.0;
60: 
67:     assert(~normalized.adapterCvScalingApplied);
68:     assert(isnan(normalized.valScaleFac));
69:     assert(normalized.derivedConductance.PU_waste == 2.0 * config.Cv_directTransfer);
80:     [params, adppCase] = buildAdapterContext("ADPP_BF");
81:     params.valScaleFac = 123.0;
82: 
89:     assert(~normalized.adapterCvScalingApplied);
90:     assert(isnan(normalized.valScaleFac));
91:     assert(normalized.derivedConductance.ADPP_feed == config.Cv_directTransfer);
```

## Conclusions

- A. current branch uses raw adapter Cv and scaled native Cv as intended
- C. raw NativeValveCoefficient=1 would produce an unsafe huge native valve

Short conclusion: adapter direct-transfer Cv stays raw/direct, native valve coefficients resolve through `params.valScaleFac`, and a raw native coefficient of 1 is not a harmless neutral setting.
