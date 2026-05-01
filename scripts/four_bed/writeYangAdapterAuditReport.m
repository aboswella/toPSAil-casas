function auditStatus = writeYangAdapterAuditReport(adapterReport, auditDir, varargin)
%WRITEYANGADAPTERAUDITREPORT Write compact FI-7 adapter audit artifact.

    parser = inputParser;
    addParameter(parser, 'CycleIndex', getReportField(adapterReport, 'cycleIndex', NaN));
    addParameter(parser, 'SlotIndex', getReportField(adapterReport, 'slotIndex', NaN));
    addParameter(parser, 'OperationGroupId', getReportField(adapterReport, 'operationGroupId', "not_supplied"));
    addParameter(parser, 'OperationFamily', getReportField(adapterReport, 'directTransferFamily', "not_supplied"));
    addParameter(parser, 'DonorBed', getReportField(adapterReport, 'donorBed', "none"));
    addParameter(parser, 'ReceiverBed', getReportField(adapterReport, 'receiverBed', "none"));
    addParameter(parser, 'LocalMap', getReportField(adapterReport, 'localMap', table()));
    addParameter(parser, 'OutputMode', "compact");
    addParameter(parser, 'IncludeStateHistory', false);
    addParameter(parser, 'FileStem', "");
    parse(parser, varargin{:});
    opts = parser.Results;

    if nargin < 2 || strlength(string(auditDir)) == 0
        error('FI7:MissingAuditDir', ...
            'auditDir must be supplied for adapter audit output.');
    end

    if ~exist(string(auditDir), 'dir')
        mkdir(string(auditDir));
    end

    fileStem = string(opts.FileStem);
    if strlength(fileStem) == 0
        fileStem = sprintf('cycle%03d_slot%02d_%s', double(opts.CycleIndex), ...
            double(opts.SlotIndex), sanitizeFileToken(string(opts.OperationGroupId)));
    end
    path = fullfile(string(auditDir), fileStem + ".json");

    audit = makeAuditStruct(adapterReport, opts);
    encoded = jsonencode(audit, PrettyPrint=true);
    fid = fopen(path, 'w');
    if fid < 0
        error('FI7:AuditWriteFailed', ...
            'Unable to open adapter audit path %s.', char(path));
    end
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, '%s', encoded);
    clear cleanup;

    info = dir(path);
    auditStatus = struct();
    auditStatus.version = "FI7-Yang2009-adapter-audit-status-v1";
    auditStatus.path = string(path);
    auditStatus.bytesWritten = info.bytes;
    auditStatus.outputMode = string(opts.OutputMode);
    auditStatus.warnings = strings(0, 1);
    auditStatus.pass = info.bytes > 0;
end

function audit = makeAuditStruct(report, opts)
    audit = struct();
    audit.version = "FI7-Yang2009-adapter-audit-v1";
    audit.outputMode = string(opts.OutputMode);
    audit.cycleIndex = opts.CycleIndex;
    audit.slotIndex = opts.SlotIndex;
    audit.operationGroupId = string(opts.OperationGroupId);
    audit.operationFamily = string(opts.OperationFamily);
    audit.directTransferFamily = string(getReportField(report, 'directTransferFamily', opts.OperationFamily));
    audit.donorBed = string(opts.DonorBed);
    audit.receiverBed = string(opts.ReceiverBed);
    audit.localMap = tableToStructSafe(opts.LocalMap);
    audit.durationSec = getReportField(report, 'durationSeconds', []);
    audit.durationDimless = getReportField(report, 'durationDimless', []);
    audit.timeBasis = string(getReportField(report, 'timeBasis', "not_supplied"));
    audit.valveCoefficients = collectValveCoefficients(report);
    pressure = getReportField(report, 'pressureDiagnostics', struct());
    audit.initialPressureSummary = getStructField(pressure, 'initial', struct());
    audit.terminalPressureSummary = getStructField(pressure, 'terminal', struct());
    audit.flowBasis = inferFlowBasis(report);
    audit.integratedFlowsByComponent = getReportField(report, 'flows', struct());
    audit.effectiveSplit = getReportField(report, 'effectiveSplit', ...
        getNestedField(report, ["flowReport", "effectiveSplit"], struct()));
    audit.conservationResiduals = getReportField(report, 'conservation', struct());
    audit.sanityDiagnostics = getReportField(report, 'sanity', struct());
    audit.warnings = string(getReportField(report, 'warnings', strings(0, 1)));
    audit.architectureFlags = struct( ...
        "noDynamicInternalTanks", logical(getReportField(report, 'noDynamicInternalTanks', true)), ...
        "noSharedHeaderInventory", logical(getReportField(report, 'noSharedHeaderInventory', true)), ...
        "noFourBedRhsDae", logical(getReportField(report, 'noFourBedRhsDae', true)), ...
        "noCoreAdsorberPhysicsRewrite", logical(getReportField(report, 'noCoreAdsorberPhysicsRewrite', true)));
    audit.surrogateBasis = "Yang-inspired H2/CO2 homogeneous activated-carbon surrogate";

    if logical(opts.IncludeStateHistory) && isfield(report, 'debugStateHistory')
        audit.debugStateHistory = report.debugStateHistory;
    end
end

function coeffs = collectValveCoefficients(report)
    coeffs = struct();
    names = [
        "Cv_PP_PU_internal"
        "Cv_PU_waste"
        "Cv_ADPP_feed"
        "Cv_ADPP_product"
        "Cv_ADPP_BF_internal"
    ];
    for i = 1:numel(names)
        name = char(names(i));
        if isfield(report, name)
            coeffs.(name) = report.(name);
        end
    end
end

function basis = inferFlowBasis(report)
    basis = struct();
    basis.basis = "unknown";
    basis.units = "unknown";
    basis.sourceField = "adapterReport.flows";
    if isfield(report, 'flowReport') && isstruct(report.flowReport)
        if isfield(report.flowReport, 'moles') && isstruct(report.flowReport.moles) && ...
                isfield(report.flowReport.moles, 'unitBasis')
            basis.molesUnitBasis = string(report.flowReport.moles.unitBasis);
        end
        if isfield(report.flowReport, 'native') && isstruct(report.flowReport.native) && ...
                isfield(report.flowReport.native, 'unitBasis')
            basis.nativeUnitBasis = string(report.flowReport.native.unitBasis);
            basis.basis = "native_counter_units";
            basis.units = "native_integrated_units";
            basis.sourceField = "adapterReport.flowReport.native";
        end
    elseif isfield(report, 'flows') && isstruct(report.flows) && isfield(report.flows, 'unitBasis')
        basis.basis = string(report.flows.unitBasis);
    end
end

function s = tableToStructSafe(value)
    if istable(value)
        s = table2struct(value);
    else
        s = value;
    end
end

function token = sanitizeFileToken(value)
    token = regexprep(char(value), '[^A-Za-z0-9_-]', '_');
end

function value = getReportField(s, name, defaultValue)
    value = defaultValue;
    if isstruct(s) && isfield(s, char(name)) && ~isempty(s.(char(name)))
        value = s.(char(name));
    end
end

function value = getStructField(s, name, defaultValue)
    value = defaultValue;
    if isstruct(s) && isfield(s, name)
        value = s.(name);
    end
end

function value = getNestedField(s, names, defaultValue)
    value = defaultValue;
    current = s;
    for i = 1:numel(names)
        name = char(names(i));
        if ~isstruct(current) || ~isfield(current, name)
            return;
        end
        current = current.(name);
    end
    value = current;
end
