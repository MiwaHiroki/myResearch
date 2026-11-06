function [bands, found, info] = extractGrooveBands(pks, trend, centers, xQuery, opts)
% 1本目の多項式 trend で傾きを補正した y が、centers のそれぞれから ±Tolerance の帯にある点を
% 取り出し、補正前（元の画像）の y で xQuery 全体に並べて、欠損を線形補間する。
% extractGrooveShape と同じ考え方だが、同じ列に2点以上あれば中心に最も近い点を採る
% （extractGrooveShape はエラーになる）。元の y で補間するのは、同じ点を採ったときに
% trackGroove で追跡した結果と完全に同じにするため（issue #30）。
%
% 出力:
%   bands - (numel(centers),1) cell。各 (numel(xQuery),2) [xQuery, y]（元の画像のpx、補間済み）
%   found - (numel(xQuery), numel(centers)) logical。その列で帯の中に点があったか
%   info  - struct。numDuplicateCols（帯の中に2点以上あった列の数）、
%           numMissing（帯の中に点が無かった列の数）。どちらも (1, numel(centers))
    arguments
        pks (:,2) double              % [x y]。元の画像のpx（mergeSegmentPoints の出力）
        trend (1,1) struct            % detrendTrackedShape の2つ目の出力（.p .S .mu）
        centers (:,1) double          % 補正後のyでの帯の中心（findGrooveCenters の出力の2本目以降）
        xQuery (:,1) double           % 昇順の列の座標[px]
        opts.Tolerance (1,1) double {mustBePositive}   % 必須。帯の半分の幅[px]
    end

    n = numel(xQuery);
    numBands = numel(centers);

    yCor = pks(:,2) - polyval(trend.p, pks(:,1), trend.S, trend.mu);
    [tf, col] = ismember(pks(:,1), xQuery);   % xQuery に無いxの点は使わない（trackGroove と同じ）

    bands = cell(numBands,1);
    found = false(n, numBands);
    info = struct();
    info.numDuplicateCols = zeros(1, numBands);
    info.numMissing = zeros(1, numBands);

    for k = 1:numBands
        dist = abs(yCor - centers(k));
        idx = find(tf & dist <= opts.Tolerance);

        % 中心から遠い順に代入すると、同じ列では最後に代入した、最も近い点が残る
        [~, ord] = sort(dist(idx), 'descend');
        idx = idx(ord);
        y = NaN(n,1);
        y(col(idx)) = pks(idx,2);

        if nnz(~isnan(y)) < 2
            error("extractGrooveBands:tooFewPoints", ...
                "帯 %d（中心 %g px、±%g px）の中に点のある列が %d 列しかなく、補間できません。", ...
                k, centers(k), opts.Tolerance, nnz(~isnan(y)));
        end

        info.numDuplicateCols(k) = nnz(accumarray(col(idx), 1, [n 1]) >= 2);
        found(:,k) = ~isnan(y);
        info.numMissing(k) = n - nnz(found(:,k));
        bands{k} = [xQuery, fillmissing(y, "linear")];
    end
end
