function audit = auditRibeiroIsothermBasis(varargin)
%AUDITRIBEIROISOTHERMBASIS Check Ribeiro AC isotherm ordering and units.

parser = inputParser;
parser.FunctionName = mfilename;
addParameter(parser, 'FeedBasisMode', "full_total_renormalized_binary", ...
    @mustBeValidFeedBasisMode);
parse(parser, varargin{:});
opts = parser.Results;

params = buildRibeiroSurrogateTemplateParams( ...
    "FeedBasisMode", opts.FeedBasisMode, ...
    "FinalizeForRuntime", true);
basis = params.ribeiroBasis;
msl = basis.adsorbent.multisiteLangmuir;

gasConstantJMolK = 8.31446261815324;
temperatureK = basis.feed.temperatureK;
kBarInv = msl.kInfPaInv(:) * 1e5;
heatFactor = exp((1000 * msl.heatOfAdsorptionKJMol(:)) ...
    ./ (gasConstantJMolK * temperatureK));
directEffectiveKBarInv = msl.a(:) .* kBarInv .* heatFactor;
nativeEffectiveKBarInv = params.KC(:);

cases = [
    makeCase("feed_7bar", basis.pressure.highBarAbs, basis.feed.moleFractions)
    makeCase("pure_h2_1bar", basis.pressure.lowBarAbs, [1; 0])
    makeCase("purge_tail_1bar", basis.pressure.lowBarAbs, [0.95; 0.05])
    makeCase("pure_co2_1bar", basis.pressure.lowBarAbs, [0; 1])
];

audit = struct();
audit.version = "Ribeiro2008-isotherm-basis-audit-v1";
audit.feedBasisMode = string(opts.FeedBasisMode);
audit.componentOrder = basis.componentOrder(:);
audit.nativeComponentOrder = params.componentOrder(:);
audit.ldfMassTransferPerSec = params.ldfMassTransferPerSec(:);
audit.expectedLdfMassTransferPerSec = [8.89e-2; 1.24e-2];
audit.directEffectiveKBarInv = directEffectiveKBarInv;
audit.nativeEffectiveKBarInv = nativeEffectiveKBarInv;
audit.maxEffectiveKAbsDiff = max(abs(directEffectiveKBarInv - nativeEffectiveKBarInv));
audit.componentOrderPass = isequal(string(audit.componentOrder), ["H2"; "CO2"]) && ...
    isequal(string(audit.nativeComponentOrder), ["H2"; "CO2"]);
audit.ldfOrderPass = max(abs(audit.ldfMassTransferPerSec ...
    - audit.expectedLdfMassTransferPerSec)) < 1e-14;
audit.effectiveKPass = audit.maxEffectiveKAbsDiff < 1e-12;
audit.cases = addCaseNumerators(cases, msl, directEffectiveKBarInv, ...
    nativeEffectiveKBarInv);
audit.pass = audit.componentOrderPass && audit.ldfOrderPass && ...
    audit.effectiveKPass;

end

function caseStruct = makeCase(name, pressureBar, moleFractions)

caseStruct = struct( ...
    'name', string(name), ...
    'pressureBar', pressureBar, ...
    'moleFractions', moleFractions(:), ...
    'partialPressureBar', pressureBar .* moleFractions(:), ...
    'directNumerator', NaN(2, 1), ...
    'nativeNumerator', NaN(2, 1), ...
    'maxNumeratorAbsDiff', NaN);

end

function cases = addCaseNumerators(cases, msl, directK, nativeK)

for idx = 1:numel(cases)
    partialPressureBar = cases(idx).partialPressureBar(:);
    cases(idx).directNumerator = ...
        msl.qMaxMolKg(:) .* directK(:) .* partialPressureBar;
    cases(idx).nativeNumerator = ...
        msl.qMaxMolKg(:) .* nativeK(:) .* partialPressureBar;
    cases(idx).maxNumeratorAbsDiff = max(abs( ...
        cases(idx).directNumerator - cases(idx).nativeNumerator));
end

end

function mustBeValidFeedBasisMode(value)

validatestring(char(value), ...
    {'full_total_renormalized_binary', 'source_h2co2_partial_flow'});

end
