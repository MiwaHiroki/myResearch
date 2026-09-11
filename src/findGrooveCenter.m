function groove1Center = findGrooveCenter(pksCor, prevCenter, opts)
% pksCorのy座標のヒストグラムからピークを探し、prevCenterに最も近いものを
% 追跡対象の溝の中心として返す
%
% pksCorはfitGrooveが返す傾き補正済みの1データセット分の点群（pksCorCell{k}）。
% prevCenterはfitGrooveのp1(2)などを渡す（前回の溝選択位置に一番近いピークを選ぶため）。
%
% ヒストグラムにopts.MinPeakHeight以上のピークが1つも見つからない場合はエラーになる。
    arguments
        pksCor (:,2) double
        prevCenter (1,1) double
        opts.BinWidth (1,1) double {mustBePositive}
        opts.MinPeakHeight (1,1) double {mustBePositive}
    end

    [counts,edges] = histcounts(pksCor(:,2),'BinWidth',opts.BinWidth);
    centers = edges(1:end-1) + diff(edges)/2; % ピークの中心

    [~,histPkLocs] = findpeaks(counts,'MinPeakHeight',opts.MinPeakHeight);

    if isempty(histPkLocs)
        error("findGrooveCenter:noPeaksFound", ...
            "findGrooveCenter(): ヒストグラムにMinPeakHeight=%g以上のピークが" + ...
            "見つかりませんでした。BinWidthかMinPeakHeightを見直してください。", ...
            opts.MinPeakHeight);
    end

    [~,idx_hist] = min(abs(prevCenter - centers(histPkLocs)));
    groove1Center = centers(histPkLocs(idx_hist));
end
