function pointsDetrended = detrendTrackedShape(points, opts)
% trackGroove で追跡した写真1枚分の溝のy座標に、opts.PolyDegree 次の多項式を
% あてはめて差し引き、平均を0にする（x座標は変えない）。
% 約4000列に高い次数をあてはめるので、polyfit の [p,S,mu] 形式（xのセンタリングと
% スケーリング）を使う（detrendGrooveShape は使わない。issue #25）。
% xは元の画像のpxのまま渡すので、高解像度化（intpD）しても同じ次数が同じ
% 周波数の範囲を消す（列の数にはよらない）。
    arguments
        points (:,2) double
        opts.PolyDegree (1,1) double {mustBeInteger,mustBeNonnegative} = 9   % 写真ごとの次数（issue #25 Q2）。評価の結果で見直すことがある
    end

    [p, S, mu] = polyfit(points(:,1), points(:,2), opts.PolyDegree);

    pointsDetrended = points;
    pointsDetrended(:,2) = points(:,2) - polyval(p, points(:,1), S, mu);
    pointsDetrended(:,2) = pointsDetrended(:,2) - mean(pointsDetrended(:,2));
end
