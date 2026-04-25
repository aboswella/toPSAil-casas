function dqdt = eval_casas2012_ldf(p, q, qStar)
%EVAL_CASAS2012_LDF Evaluate Casas LDF rates, dq/dt = k*(qStar - q).

    q = double(q);
    qStar = double(qStar);

    if ~isequal(size(q), size(qStar))
        error("eval_casas2012_ldf:SizeMismatch", ...
              "q and qStar must have the same size.");
    end

    k = p.kinetics.k_LDF_s;
    if size(q, 2) ~= numel(k)
        error("eval_casas2012_ldf:BadComponentCount", ...
              "q must have one column per component.");
    end

    dqdt = (qStar - q) .* k;
end
