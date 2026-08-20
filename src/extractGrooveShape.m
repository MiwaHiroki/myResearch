function points = extractGrooveShape(pksCor, grooveCenter, xQuery, opts)
% grooveCenterからopts.Tolerance以内にあるpksCorの点をxQuery全体のNaN埋め配列
% points(:, [x,y])に展開し、欠損をfillmissingで線形補間する
%
% xQueryはpksCorが取りうるx座標の全域を渡す（整数刻みでも、interp2の
% QUERY_STEP刻みのような分数刻みでもよい）。ismemberで対応付けるため、
% どちらの刻みでも同じロジックで正しく動く
% （直接インデックス版 points(points_x,2)=... は分数刻みでは使えない）。
    arguments
        pksCor (:,2) double
        grooveCenter (1,1) double
        xQuery (:,1) double
        opts.Tolerance (1,1) double {mustBePositive}
    end

    y_min = grooveCenter - opts.Tolerance;
    y_max = grooveCenter + opts.Tolerance;

    idxs = (pksCor(:,2) >= y_min) & (pksCor(:,2) <= y_max);
    clusteredPoints = pksCor(idxs,:);

    points = [xQuery, NaN(numel(xQuery),1)];
    Lia = ismember(points(:,1), clusteredPoints(:,1));
    % Lia: 「points(:,1)の各要素がclusteredPoints(:,1)に見つかったか」
    points(Lia,2) = clusteredPoints(:,2);

    % 形状抽出に失敗した点を埋める（波形表示時の各信号の長さを揃えるため）
    points(:,2) = fillmissing(points(:,2),"linear");
end
