function units = parseYangDurationLabel(label)
%PARSEYANGDURATIONLABEL Convert Yang Table 2 duration labels to t_c/24 units.
%
% This parser intentionally supports only the labels used in the Yang 2009
% four-bed schedule manifest. Unknown labels are source-transcription errors.

    label = string(label);
    if ~isscalar(label)
        error('WP1:DurationLabelNotScalar', ...
            'Yang duration label must be a scalar string.');
    end

    label = strtrim(label);

    switch label
        case "t_c/24"
            units = 1;
        case "t_c/4"
            units = 6;
        case "t_c/6"
            units = 4;
        case "5t_c/24"
            units = 5;
        otherwise
            error('WP1:UnknownYangDurationLabel', ...
                'Unknown Yang duration label: %s', char(label));
    end
end
