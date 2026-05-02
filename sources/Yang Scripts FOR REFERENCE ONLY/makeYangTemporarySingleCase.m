function tempCase = makeYangTemporarySingleCase(selection, varargin)
%MAKEYANGTEMPORARYSINGLECASE Build a WP4 one-local-bed case.

    if ~isstruct(selection) || ~isfield(selection, 'selectionType') || ...
            string(selection.selectionType) ~= "single_bed_operation"
        error('WP4:InvalidSingleSelection', ...
            'makeYangTemporarySingleCase requires a single_bed_operation selection.');
    end

    tempCase = makeYangTemporaryCase(selection, varargin{:});
end
