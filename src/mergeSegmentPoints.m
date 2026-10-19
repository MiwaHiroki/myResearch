function [pks, xQuery, counts, xOffsets] = mergeSegmentPoints(ptsArray, opts)
% 写真1枚分（NumSegments個）の GroovePointCloud の点群を、x方向にずらしながら
% 1つの [x y] 配列に連結し、写真1枚分の xQuery も作る。trackGroove に写真1枚分の
% 点群を渡すため。ずらし量は各セグメントの幅（GroovePointCloud.width = 元の画像の幅）の
% 累積和にする。omitMask で落とした列は詰めて連結する（既存スクリプトが ycoords を
% 連結するのと同じ並び）。
%
% 出力:
%   pks      - (:,2) セグメントjの点のxに xOffsets(j) を足して縦に連結したもの
%   xQuery   - (:,1) 各セグメントの (1:QueryStep:width_j)' + xOffsets(j) を縦に連結したもの。
%              間隔はセグメントの中で QueryStep、境目で1px
%   counts   - (N,1) 各セグメントの列の数。mat2cell でセグメントごとに分け直すときに使う
%   xOffsets - (N,1) 各セグメントのxのずらし量。xOffsets(1)=0
    arguments
        ptsArray (:,1) GroovePointCloud
        opts.QueryStep (1,1) double {mustBePositive} = 1   % 列の間隔[px]。origD・rsmplDは1、intpDはdInterpのstep
    end

    numSeg = numel(ptsArray);
    widths = reshape([ptsArray.width], [], 1);
    xOffsets = [0; cumsum(widths(1:end-1))];

    segPks = cell(numSeg,1);
    segQuery = cell(numSeg,1);
    counts = zeros(numSeg,1);
    for j = 1:numSeg
        p = vertcat(ptsArray(j).peakCells{:});
        if isempty(p)
            % 点が1つも無いセグメント（vertcat の結果が 0x0 になる）
            p = zeros(0,2);
        end
        segPks{j} = [p(:,1) + xOffsets(j), p(:,2)];

        xLocal = (1:opts.QueryStep:widths(j))';
        segQuery{j} = xLocal + xOffsets(j);
        counts(j) = numel(xLocal);
    end

    pks = vertcat(zeros(0,2), segPks{:});
    xQuery = vertcat(zeros(0,1), segQuery{:});
end
