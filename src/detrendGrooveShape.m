function pointsDetrended = detrendGrooveShape(points, opts)
% pointsのy座標にopts.PolyDegree次の多項式をpolyfitし、その多項式を差し引いて
% デトレンドしたあとy座標の平均を0にする（x座標は変更しない）
    arguments
        points (:,2) double
        opts.PolyDegree (1,1) double {mustBeInteger,mustBeNonnegative} = 3
    end

    p = polyfit(points(:,1), points(:,2), opts.PolyDegree);

    pointsDetrended = points;
    pointsDetrended(:,2) = points(:,2) - polyval(p, points(:,1));
    pointsDetrended(:,2) = pointsDetrended(:,2) - mean(pointsDetrended(:,2));
end
