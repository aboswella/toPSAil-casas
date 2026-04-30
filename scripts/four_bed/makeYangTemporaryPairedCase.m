function tempCase = makeYangTemporaryPairedCase(selection, varargin)
%MAKEYANGTEMPORARYPAIREDCASE Build a WP4 two-local-bed case.

    if ~isstruct(selection) || ~isfield(selection, 'selectionType') || ...
            string(selection.selectionType) ~= "paired_direct_transfer"
        error('WP4:InvalidPairedSelection', ...
            'makeYangTemporaryPairedCase requires a paired_direct_transfer selection.');
    end

    tempCase = makeYangTemporaryCase(selection, varargin{:});
end
