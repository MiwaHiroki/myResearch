function points = extractGrooveWaveform(pksCor, prevCenter, xQuery, opts)
% findGrooveCenter -> extractGrooveShape -> detrendGrooveShapeを順に呼び出し、
% fitGrooveで傾き補正済みの点群pksCorから溝1本分のデトレンド済みy座標を得る
%
% groove1Centerやfillmissing前の疎な点群が個別に必要な場合は、
% findGrooveCenter/extractGrooveShape/detrendGrooveShapeを直接呼び出すこと
% （例: scripts/pkCentroid_resample.mは疎な点群だけを使う）。
    arguments
        pksCor (:,2) double
        prevCenter (1,1) double
        xQuery (:,1) double
        opts.BinWidth (1,1) double {mustBePositive}
        opts.MinPeakHeight (1,1) double {mustBePositive}
        opts.Tolerance (1,1) double {mustBePositive}
        opts.PolyDegree (1,1) double {mustBeInteger,mustBeNonnegative} = 3
    end

    grooveCenter = findGrooveCenter(pksCor, prevCenter, ...
        BinWidth=opts.BinWidth, MinPeakHeight=opts.MinPeakHeight);
    points = extractGrooveShape(pksCor, grooveCenter, xQuery, Tolerance=opts.Tolerance);
    points = detrendGrooveShape(points, PolyDegree=opts.PolyDegree);
end
