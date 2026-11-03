function [points, found, info] = trackGroove(pks, seed, xQuery, opts)
% 写真1枚分の溝底の点群 pks から、seed（クリック位置）を通る溝1本を
% 左右に1列ずつ追跡し、xQuery 全体のy座標（欠損は線形補間）を返す。
% fitGroove（溝の選択・傾き補正）と extractGrooveShape（点の抽出・欠損の補間）を
% 兼ねる。セグメントごとの平行四辺形の選択（1周80回のginput）を、
% 写真ごとに1回のクリックに減らすため。
% 長さの引数はすべて元の画像のpxで指定する（高解像度化して列の間隔が
% 変わっても、同じ値が溝に沿った同じ長さを表すように）。
%
% 各列では、直近に採った点（最後に採った点から FitLength 未満）に直線をあてはめて
% その列のyを予測し、予測から Tolerance 以内で最も近い点を採る。窓の基準を
% 「今の列」ではなく「最後に採った点」にするのは、FitLength より長い欠損の後でも
% 欠損の前の点で予測を続けられるようにするため。
%
% 出力:
%   points - (numel(xQuery),2) [xQuery, y]。採れなかった列は fillmissing(y,"linear") で補間
%   found  - (numel(xQuery),1) logical。その列で点を採れたか
%   info   - struct。y0（初期化で決めた始点のy）、seedIdx（始点の列の番号）、
%            numFound・numMissing（列の数）、maxGapLength（最も長い連続欠損の長さ[px]。
%            欠損した列の数 × 列の間隔 median(diff(xQuery))）
    arguments
        pks (:,2) double              % [x y]。元の画像のpx。xはxQueryのいずれかの値（mergeSegmentPointsの出力）
        seed (1,2) double             % [x y]。クリック位置（元の画像のpx。xは写真1枚分を連結した座標）
        xQuery (:,1) double           % 昇順の列の座標[px]。origDなら (1:nCols)'、intpDなら分数刻み
        opts.Tolerance (1,1) double {mustBePositive} = 2        % 予測位置から採る点までの最大距離（y方向）[px]
        opts.FitLength (1,1) double {mustBePositive} = 60       % 予測の直線あてはめに使う範囲。最後に採った点から x方向にこの長さ未満の採用点を使う[px]
        opts.SnapRadius (1,1) double {mustBePositive} = 10      % 初期化でseed(2)から探す範囲（y方向）[px]
        opts.InitLength (1,1) double {mustBePositive} = 20      % 初期化に使う範囲。始点の列から右へこの長さ未満の列[px]
        opts.MaxGapLength (1,1) double {mustBePositive} = 40    % 連続した欠損がこの長さを超えたら警告する[px]
    end

    % 直線あてはめに必要な、窓の中の採用点の最小数（1点の外れ値に引きずられないように）。
    % 長さではなく点の数の問題なので、引数にはしない
    MIN_FIT_POINTS = 5;

    n = numel(xQuery);

    % 1. 列ごとに候補のy座標を cell にまとめる（xQuery に無いxの点は使わない）
    [tf, col] = ismember(pks(:,1), xQuery);
    cands = accumarray(col(tf), pks(tf,2), [n 1], @(v){v}, {[]});

    % 2. 始点の列
    [~, s] = min(abs(xQuery - seed(1)));

    % 3. 初期化：始点から InitLength 未満の列で seed(2) に最も近い候補の中央値
    initVals = zeros(0,1);
    for c = s:n
        if xQuery(c) - xQuery(s) >= opts.InitLength
            break
        end
        [d, ii] = min(abs(cands{c} - seed(2)));
        if ~isempty(d) && d <= opts.SnapRadius
            initVals(end+1,1) = cands{c}(ii); %#ok<AGROW>
        end
    end
    if isempty(initVals)
        error("trackGroove:seedNotFound", ...
            "クリック位置 (x=%g, y=%g) から y方向に %g px 以内、x方向に %g px 以内に溝底の点がありません。", ...
            seed(1), seed(2), opts.SnapRadius, opts.InitLength);
    end
    y0 = median(initVals);

    y = NaN(n,1);

    % 4. 右向きに進む
    y = followGroove(y, cands, xQuery, s:n, zeros(0,1), zeros(0,1), y0, opts, MIN_FIT_POINTS);

    % 5. 左向きに進む。窓の初期値は、右向きで採った点のうち最も左の点から
    %    FitLength 未満のものを、xの大きい順に並べたもの（最後の要素が最も左の点）
    takenIdx = find(~isnan(y));
    if isempty(takenIdx)
        accX = zeros(0,1);
        accY = zeros(0,1);
    else
        sel = takenIdx(xQuery(takenIdx) - xQuery(takenIdx(1)) < opts.FitLength);
        sel = flipud(sel);
        accX = xQuery(sel);
        accY = y(sel);
    end
    y = followGroove(y, cands, xQuery, s-1:-1:1, accX, accY, y0, opts, MIN_FIT_POINTS);

    % 6. 欠損の長さを確かめ、補間する
    found = ~isnan(y);
    if n >= 2
        dx = median(diff(xQuery));
    else
        dx = 1;
    end
    [runLen, runStart] = longestMissingRun(found);
    info = struct();
    info.y0 = y0;
    info.seedIdx = s;
    info.numFound = nnz(found);
    info.numMissing = n - info.numFound;
    info.maxGapLength = runLen * dx;
    if info.maxGapLength > opts.MaxGapLength
        warning("trackGroove:longGap", ...
            "x=%g px から %g px にわたって溝底の点を採れませんでした（MaxGapLength=%g px）。" + ...
            "溝を見失っていないか確かめてください。", ...
            xQuery(runStart), info.maxGapLength, opts.MaxGapLength);
    end

    points = [xQuery, fillmissing(y, "linear")];
end


function y = followGroove(y, cands, xQuery, colOrder, accX, accY, y0, opts, minFitPoints)
% colOrder の順に1列ずつ進み、予測から Tolerance 以内で最も近い候補を y に入れる。
% accX, accY は採った点を採った順に並べたもの（xは単調なので、窓は末尾の連続した範囲になる）。

    numCols = numel(colOrder);
    accX = [accX; zeros(numCols,1)];
    accY = [accY; zeros(numCols,1)];
    numAcc = numel(accX) - numCols;
    winStart = 1;

    for c = colOrder
        % 窓：最後に採った点から FitLength 未満の採用点
        if numAcc > 0
            while abs(accX(winStart) - accX(numAcc)) >= opts.FitLength
                winStart = winStart + 1;
            end
        end
        numWin = numAcc - winStart + 1;

        if numAcc > 0 && numWin >= minFitPoints
            % 条件が悪くならないよう、xから今の列のxを引いてからあてはめる
            pp = polyfit(accX(winStart:numAcc) - xQuery(c), accY(winStart:numAcc), 1);
            yp = pp(2);
        elseif numAcc > 0
            yp = accY(numAcc);
        else
            yp = y0;
        end

        [d, ii] = min(abs(cands{c} - yp));
        if ~isempty(d) && d <= opts.Tolerance
            y(c) = cands{c}(ii);
            numAcc = numAcc + 1;
            accX(numAcc) = xQuery(c);
            accY(numAcc) = y(c);
        end
    end
end


function [runLen, runStart] = longestMissingRun(found)
% found が false の連続の、最長の長さ（列の数）と開始位置を返す（無ければ 0, 1）

    isMissing = [false; ~found(:); false];
    edges = diff(isMissing);
    starts = find(edges == 1);
    ends = find(edges == -1) - 1;
    if isempty(starts)
        runLen = 0;
        runStart = 1;
        return
    end
    [runLen, iMax] = max(ends - starts + 1);
    runStart = starts(iMax);
end
