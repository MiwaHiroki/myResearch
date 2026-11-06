function [shapes, info] = extractMultiGroove(pks, seed, xQuery, numGrooves, opts)
% 写真1枚分の溝底の点群から、seed（クリック）を通る溝を1本目として、レコードの内側
% （y座標が小さい側）へ順に numGrooves 本の溝の形状を返す。1本目は trackGroove で追跡し、
% 2本目以降は、1本目の多項式で写真全体の点の傾きを補正した y のヒストグラムの山
% （findGrooveCenters）の帯から取り出す（extractGrooveBands）。各溝に detrendTrackedShape を
% かける。1周目のクリックだけで N周分の溝を得るため（issue #30）。
% 山の高さのしきい値を列の数に対する割合（MinPeakRatio）にするのは、1つの溝は1列に1点
% なので山の高さが列の数に比例し、高解像度化で列が増えても同じ値を使えるようにするため。
% numGrooves == 1 のときはヒストグラムを作らない（#25 の trackGroove → detrendTrackedShape と同じ）。
%
% 出力:
%   shapes - (1, numGrooves) cell。各 (numel(xQuery),2) [xQuery, y]（デトレンド後、平均0）
%   info   - struct
%            track            1本目の trackGroove の info
%            trend            1本目の多項式（detrendTrackedShape の2つ目の出力）
%            centers          (numGrooves,1) 補正後の山の中心（numGrooves == 1 なら []）
%            hist             findGrooveCenters の info（numGrooves == 1 なら []）
%            minPeakHeight    MinPeakRatio * numel(xQuery)
%            yAbs             (numel(xQuery), numGrooves) デトレンド前・補間済みの y（元の画像のpx）
%            found            (numel(xQuery), numGrooves) logical。1列目は trackGroove の found、
%                             2列目以降は帯の中に点があった列
%            numDuplicateCols (1, numGrooves) 帯の中に2点以上あった列の数（1列目は0）
% エラーは部品の識別子のまま出す（trackGroove:seedNotFound、findGrooveCenters:*、
% extractGrooveBands:tooFewPoints）。
    arguments
        pks (:,2) double              % [x y]。元の画像のpx（mergeSegmentPoints の出力）
        seed (1,2) double             % [x y]。1本目のクリック位置（元の画像のpx）
        xQuery (:,1) double           % 昇順の列の座標[px]
        numGrooves (1,1) double {mustBeInteger,mustBePositive}
        % 1本目の追跡（trackGroove の引数。名前の Tolerance は帯と区別するため TrackTolerance）
        opts.TrackTolerance (1,1) double {mustBePositive} = 2
        opts.FitLength (1,1) double {mustBePositive} = 60
        opts.SnapRadius (1,1) double {mustBePositive} = 10
        opts.InitLength (1,1) double {mustBePositive} = 20
        opts.MaxGapLength (1,1) double {mustBePositive} = 40
        % デトレンド（すべての溝で同じ次数。issue #30 Q2）
        opts.PolyDegree (1,1) double {mustBeInteger,mustBeNonnegative} = 9
        % 2本目以降（issue #30 Q1）。長さは元の画像のpx
        opts.BinWidth (1,1) double {mustBePositive} = 1           % ヒストグラムのビンの幅[px]
        opts.MinPeakRatio (1,1) double {mustBePositive} = 0.3     % 山とみなす高さ ＝ MinPeakRatio × numel(xQuery)
        opts.BandTolerance (1,1) double {mustBePositive} = 3      % 帯の半分の幅[px]
    end

    n = numel(xQuery);

    % 1. 1本目を追跡する（#25 と同じ）
    [points1, found1, infoTrack] = trackGroove(pks, seed, xQuery, Tolerance=opts.TrackTolerance, ...
        FitLength=opts.FitLength, SnapRadius=opts.SnapRadius, InitLength=opts.InitLength, ...
        MaxGapLength=opts.MaxGapLength);

    % 2. 1本目をデトレンドし、その多項式を写真全体の点の補正に使う
    shapes = cell(1, numGrooves);
    [shapes{1}, trend] = detrendTrackedShape(points1, PolyDegree=opts.PolyDegree);

    info = struct();
    info.track = infoTrack;
    info.trend = trend;
    info.centers = [];
    info.hist = [];
    info.minPeakHeight = opts.MinPeakRatio * n;
    info.yAbs = points1(:,2);
    info.found = found1;
    info.numDuplicateCols = 0;

    if numGrooves == 1
        return
    end

    % 3〜4. 補正後の y のヒストグラムから、1本目（y≈0）と y の小さい側の N-1 個の山を選ぶ
    pksCor = [pks(:,1), pks(:,2) - polyval(trend.p, pks(:,1), trend.S, trend.mu)];
    [centers, infoHist] = findGrooveCenters(pksCor, numGrooves, BinWidth=opts.BinWidth, ...
        MinPeakHeight=info.minPeakHeight);

    % 5. 2本目以降の帯の点を、元の画像の y で並べて補間する
    [bands, foundBands, infoBands] = extractGrooveBands(pks, trend, centers(2:end), xQuery, ...
        Tolerance=opts.BandTolerance);

    % 6. 2本目以降も、溝ごとに同じ次数でデトレンドする
    yAbs = zeros(n, numGrooves);
    yAbs(:,1) = points1(:,2);
    for j = 2:numGrooves
        shapes{j} = detrendTrackedShape(bands{j-1}, PolyDegree=opts.PolyDegree);
        yAbs(:,j) = bands{j-1}(:,2);
    end

    info.centers = centers;
    info.hist = infoHist;
    info.yAbs = yAbs;
    info.found = [found1, foundBands];
    info.numDuplicateCols = [0, infoBands.numDuplicateCols];
end
