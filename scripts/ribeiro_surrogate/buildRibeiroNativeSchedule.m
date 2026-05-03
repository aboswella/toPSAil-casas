function schedule = buildRibeiroNativeSchedule(varargin)
%BUILDRIBEIRONATIVESCHEDULE Build the native 4-column Ribeiro slot schedule.

parser = inputParser;
parser.FunctionName = mfilename;
addParameter(parser, 'TFeedSec', 40, @mustBePositiveNumericScalar);
parse(parser, varargin{:});
opts = parser.Results;

nCols = 4;
nNativeSteps = 16;
baseSlotSec = opts.TFeedSec / 4;

phase = [
    "FEED"
    "FEED"
    "FEED"
    "FEED"
    "EQ_D1"
    "EQ_D1"
    "EQ_D2"
    "EQ_D2"
    "BLOWDOWN"
    "PURGE"
    "EQ_P1"
    "EQ_P1"
    "EQ_P2"
    "EQ_P2"
    "PRESSURIZATION"
    "PRESSURIZATION"
];
offsets = [0; 4; 8; 12];
columnNames = ["A"; "B"; "C"; "D"];

logicalLabelsByCol = strings(nCols, nNativeSteps);
nativeStepCol = strings(nCols, nNativeSteps);
flowDirCol = zeros(nCols, nNativeSteps);
typeDaeModel = ones(nCols, nNativeSteps);
numAdsEqPrEnd = zeros(nCols, nNativeSteps);
numAdsEqFeEnd = zeros(nCols, nNativeSteps);
eqRoleByCol = repmat("none", nCols, nNativeSteps);
eqPairBySlot = repmat("none", nNativeSteps, 2);
eqPairRoleBySlot = repmat("none", nNativeSteps, 2);

for slot = 1:nNativeSteps
    for col = 1:nCols
        phaseIndex = mod((slot - 1) - offsets(col), nNativeSteps) + 1;
        label = phase(phaseIndex);
        logicalLabelsByCol(col, slot) = label;

        [nativeStep, flowDir, eqRole, daeType] = mapLogicalLabel(label);
        nativeStepCol(col, slot) = nativeStep;
        flowDirCol(col, slot) = flowDir;
        eqRoleByCol(col, slot) = eqRole;
        typeDaeModel(col, slot) = daeType;
    end

    eqCols = find(nativeStepCol(:, slot) == "EQ-XXX-APR");
    if ~isempty(eqCols)
        if numel(eqCols) ~= 2
            error('RibeiroSurrogate:InvalidEqualizationSlot', ...
                'Native slot %d must contain exactly two equalizing columns.', slot);
        end
        numAdsEqPrEnd(eqCols(1), slot) = eqCols(2);
        numAdsEqPrEnd(eqCols(2), slot) = eqCols(1);
        eqPairBySlot(slot, :) = columnNames(eqCols).';
        eqPairRoleBySlot(slot, :) = eqRoleByCol(eqCols, slot).';
    end
end

schedule = struct();
schedule.version = "Ribeiro2008-native-four-column-schedule-v1";
schedule.nCols = nCols;
schedule.nNativeSteps = nNativeSteps;
schedule.nLogicalSteps = 8;
schedule.tFeedSec = opts.TFeedSec;
schedule.baseSlotSec = baseSlotSec;
schedule.durStep = baseSlotSec * ones(1, nNativeSteps);
schedule.columnNames = columnNames;
schedule.phaseByBaseSlot = phase;
schedule.offsetsBaseSlots = offsets;
schedule.logicalLabelsByCol = logicalLabelsByCol;
schedule.nativeStepCol = nativeStepCol;
schedule.flowDirCol = flowDirCol;
schedule.typeDaeModel = typeDaeModel;
schedule.numAdsEqPrEnd = numAdsEqPrEnd;
schedule.numAdsEqFeEnd = numAdsEqFeEnd;
schedule.eqRoleByCol = eqRoleByCol;
schedule.eqPairBySlot = eqPairBySlot;
schedule.eqPairRoleBySlot = eqPairRoleBySlot;
schedule.slotMetadata = makeSlotMetadata(schedule);
schedule.pressurizationSource = "raffinate_product_tank";
schedule.notes = [
    "16 native slots represent the eight logical Ribeiro steps."
    "Product-end equalization uses EQ-XXX-APR and explicit receiver flow direction."
    "Final pressurization uses RP-XXX-RAF as a product-end H2-rich surrogate."
];

validateSchedule(schedule);

end

function metadata = makeSlotMetadata(schedule)

metadata = repmat(struct( ...
    'slotIndex', NaN, ...
    'logicalRolesByColumn', strings(1, 0), ...
    'nativeStepLabelsByColumn', strings(1, 0), ...
    'equalizationPair', strings(1, 0), ...
    'equalizationRoles', strings(1, 0), ...
    'depressurizingBed', "", ...
    'pressurizingBed', ""), schedule.nNativeSteps, 1);

for slot = 1:schedule.nNativeSteps
    metadata(slot).slotIndex = slot;
    metadata(slot).logicalRolesByColumn = schedule.logicalLabelsByCol(:, slot).';
    metadata(slot).nativeStepLabelsByColumn = schedule.nativeStepCol(:, slot).';

    eqCols = find(schedule.nativeStepCol(:, slot) == "EQ-XXX-APR");
    if isempty(eqCols)
        continue;
    end

    metadata(slot).equalizationPair = schedule.columnNames(eqCols).';
    metadata(slot).equalizationRoles = schedule.eqRoleByCol(eqCols, slot).';

    donorMask = startsWith(schedule.eqRoleByCol(eqCols, slot), "donor");
    receiverMask = startsWith(schedule.eqRoleByCol(eqCols, slot), "receiver");
    if any(donorMask)
        metadata(slot).depressurizingBed = schedule.columnNames(eqCols(donorMask));
    end
    if any(receiverMask)
        metadata(slot).pressurizingBed = schedule.columnNames(eqCols(receiverMask));
    end
end

end

function [nativeStep, flowDir, eqRole, daeType] = mapLogicalLabel(label)

daeType = 1;
eqRole = "none";

switch string(label)
    case "FEED"
        nativeStep = "HP-FEE-RAF";
        flowDir = 0;
        daeType = 0;
    case "EQ_D1"
        nativeStep = "EQ-XXX-APR";
        flowDir = 0;
        eqRole = "donor_d1";
    case "EQ_D2"
        nativeStep = "EQ-XXX-APR";
        flowDir = 0;
        eqRole = "donor_d2";
    case "BLOWDOWN"
        nativeStep = "DP-ATM-XXX";
        flowDir = 1;
    case "PURGE"
        nativeStep = "LP-ATM-RAF";
        flowDir = 1;
        daeType = 0;
    case "EQ_P1"
        nativeStep = "EQ-XXX-APR";
        flowDir = 1;
        eqRole = "receiver_p1";
    case "EQ_P2"
        nativeStep = "EQ-XXX-APR";
        flowDir = 1;
        eqRole = "receiver_p2";
    case "PRESSURIZATION"
        nativeStep = "RP-XXX-RAF";
        flowDir = 1;
    otherwise
        error('RibeiroSurrogate:UnknownLogicalStep', ...
            'Unknown Ribeiro logical label: %s.', char(label));
end

end

function validateSchedule(schedule)

if ~isequal(size(schedule.logicalLabelsByCol), [4, 16])
    error('RibeiroSurrogate:InvalidScheduleSize', ...
        'Ribeiro schedule must be 4 columns by 16 native slots.');
end

for slot = 1:schedule.nNativeSteps
    nFeed = nnz(schedule.nativeStepCol(:, slot) == "HP-FEE-RAF");
    nEq = nnz(schedule.nativeStepCol(:, slot) == "EQ-XXX-APR");
    if nFeed ~= 1
        error('RibeiroSurrogate:InvalidFeedCoverage', ...
            'Native slot %d must have exactly one feed column.', slot);
    end
    if ~(nEq == 0 || nEq == 2)
        error('RibeiroSurrogate:InvalidEqualizationCoverage', ...
            'Native slot %d must have zero or two equalization columns.', slot);
    end
    if nEq == 2
        roles = schedule.eqRoleByCol(schedule.nativeStepCol(:, slot) == "EQ-XXX-APR", slot);
        if any(roles == "donor_d1") && ~any(roles == "receiver_p2")
            error('RibeiroSurrogate:InvalidEqualizationPairing', ...
                'Native slot %d must pair D1 with P2.', slot);
        end
        if any(roles == "donor_d2") && ~any(roles == "receiver_p1")
            error('RibeiroSurrogate:InvalidEqualizationPairing', ...
                'Native slot %d must pair D2 with P1.', slot);
        end
    end
end

expectedPairs = [
    "B", "D"
    "B", "D"
    "C", "D"
    "C", "D"
    "A", "C"
    "A", "C"
    "A", "D"
    "A", "D"
    "B", "D"
    "B", "D"
    "A", "B"
    "A", "B"
    "A", "C"
    "A", "C"
    "B", "C"
    "B", "C"
];
if any(schedule.eqPairBySlot ~= expectedPairs, 'all')
    error('RibeiroSurrogate:UnexpectedEqualizationPairs', ...
        'Equalization pair sequence does not match the Ribeiro guide.');
end

end

function mustBePositiveNumericScalar(value)

if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || value <= 0
    error('RibeiroSurrogate:InvalidPositiveScalar', ...
        'Value must be a positive numeric scalar.');
end

end
