function pressureClasses = getYangPressureClassMap()
%GETYANGPRESSURECLASSMAP Return symbolic pressure classes for WP1.
%
% Only PF and P4 have numeric anchors in WP1. Intermediate classes remain
% symbolic until a later task authorizes source-backed values.

    pressureClass = ["PF"; "P1"; "P2"; "P3"; "P4"; "P5"; "P6"];

    meaning = [
        "adsorption/feed pressure"
        "first equalization donor terminal pressure"
        "provide-purge donor terminal pressure"
        "second equalization donor terminal pressure"
        "lowest purge/blowdown pressure"
        "second equalization receiver terminal pressure"
        "first equalization receiver terminal pressure"
    ];

    numericValue = [9.0; NaN; NaN; NaN; 1.3; NaN; NaN];
    numericUnit = ["atm"; ""; ""; ""; "atm"; ""; ""];

    basis = [
        "Yang experimental operating condition"
        "symbolic intermediate pressure; no WP1 numeric value"
        "symbolic intermediate pressure; no WP1 numeric value"
        "symbolic intermediate pressure; no WP1 numeric value"
        "Yang experimental operating condition"
        "symbolic intermediate pressure; no WP1 numeric value"
        "symbolic intermediate pressure; no WP1 numeric value"
    ];

    pressureClasses = table( ...
        pressureClass, ...
        meaning, ...
        numericValue, ...
        numericUnit, ...
        basis, ...
        'VariableNames', [
            "pressure_class"
            "meaning"
            "numeric_value"
            "numeric_unit"
            "basis"
        ]);
end
