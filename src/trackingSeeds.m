function seeds = trackingSeeds(grooveSelection, numSegments)
% cycleResult の grooveSelection から、写真ごとの追跡の始点（numImages x 2）を返す。
% 新しい形式（.seeds がある）ならそれを返す。古い形式（手動選択の .p1 が
% (numImages*numSegments x 2)）なら、各写真の最初のセグメントの p1 を返す。
% 古い結果ファイルの手動選択を使って、ginput なしで追跡を再現するため。
% 古い形式の p1 のxはセグメントの中の座標だが、各写真の最初のセグメントでは
% xのずらし量が0なので、写真1枚分を連結した座標と同じになる。
    arguments
        grooveSelection (1,1) struct
        numSegments (1,1) double {mustBeInteger,mustBePositive}
    end

    gs = grooveSelection;
    if isfield(gs, "seeds") && ~isempty(gs.seeds)
        seeds = gs.seeds;
        return
    end

    if isfield(gs, "p1")
        numRows = size(gs.p1, 1);
        if numRows >= 1 && mod(numRows, numSegments) == 0
            seeds = gs.p1(1:numSegments:end, :);
            return
        end
    end

    error("trackingSeeds:noSelection", ...
        "grooveSelection に追跡の始点（seeds）も、手動選択の p1（%d の倍数の行）もありません。", ...
        numSegments);
end
