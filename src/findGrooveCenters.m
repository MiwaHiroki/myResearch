function [centers, info] = findGrooveCenters(pksCor, numGrooves, opts)
% 1本目の溝で傾きを補正した点群 pksCor の y のヒストグラムから、FirstCenter に最も近い山を
% 1本目とし、そこから y の小さい側（レコードの内側）へ続く numGrooves-1 個の山を選んで、
% それぞれのビンの中心を返す。写真1枚の中の複数本の溝を、1回のクリックから数えるため
% （旧 scripts/archive/Ncycle_omitMask.m のヒストグラムによる溝の選択と同じ考え方）。
% 1本目の山が FirstCenter から MaxFirstOffset より離れていたらエラーにする（隣の山を
% 1本目にすると、以後の周がすべて1本ずれるため）。
%
% 出力:
%   centers - (numGrooves,1) 選んだ山のビンの中心（補正後のy）。centers(1) が1本目で、
%             以後 y が小さくなる
%   info    - struct。binCenters・counts（ヒストグラム）、peakCenters（昇順）・
%             peakHeights（MinPeakHeight 以上の山）、firstIdx（1本目の山の peakCenters での番号）
    arguments
        pksCor (:,2) double                                  % [x y]。yは補正後の値（1本目が y≈0）
        numGrooves (1,1) double {mustBeInteger,mustBePositive}
        opts.BinWidth (1,1) double {mustBePositive}          % 必須。ヒストグラムのビンの幅[px]
        opts.MinPeakHeight (1,1) double {mustBePositive}     % 必須。山とみなす高さ（点の数）
        opts.FirstCenter (1,1) double = 0                    % 1本目の山を探す基準のy[px]
        opts.MaxFirstOffset (1,1) double {mustBePositive} = 5   % 1本目の山がFirstCenterからこれより離れていたらエラー[px]
    end

    [counts, edges] = histcounts(pksCor(:,2), 'BinWidth', opts.BinWidth);
    binCenters = edges(1:end-1) + diff(edges)/2;

    % MinPeakHeight を超えるビンが無いと findpeaks が警告を出すので、先に確かめる
    if isempty(counts) || max(counts) < opts.MinPeakHeight
        locs = zeros(1,0);
        pkHeights = zeros(1,0);
    else
        [pkHeights, locs] = findpeaks(counts, 'MinPeakHeight', opts.MinPeakHeight);
    end
    if isempty(locs)
        error("findGrooveCenters:noPeaksFound", ...
            "ヒストグラムに MinPeakHeight=%g 以上の山が見つかりませんでした。" + ...
            "BinWidth か MinPeakHeight を見直してください。", opts.MinPeakHeight);
    end

    peakCenters = binCenters(locs);
    [d, i0] = min(abs(peakCenters - opts.FirstCenter));
    if d > opts.MaxFirstOffset
        error("findGrooveCenters:firstPeakNotFound", ...
            "1本目の山が見つかりません。FirstCenter=%g に最も近い山まで %g px あり、" + ...
            "MaxFirstOffset=%g px を超えています（1本目の溝の点が少なすぎる可能性）。", ...
            opts.FirstCenter, d, opts.MaxFirstOffset);
    end

    if i0 - numGrooves + 1 < 1
        error("findGrooveCenters:notEnoughPeaks", ...
            "1本目より y の小さい側に山が %d 個しかなく、%d 個に足りません" + ...
            "（内側の溝が画像の上端に近い可能性）。", i0 - 1, numGrooves - 1);
    end

    centers = peakCenters(i0:-1:i0-numGrooves+1).';

    info = struct();
    info.binCenters = binCenters;
    info.counts = counts;
    info.peakCenters = peakCenters;
    info.peakHeights = pkHeights;
    info.firstIdx = i0;
end
