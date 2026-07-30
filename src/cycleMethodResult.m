function res = cycleMethodResult(method, pts, xcoords, ycoords, y_comb, audio)
% cycleMethodResult  溝底抽出手法1つ分の1周データをstructにまとめる。
%
% saveCycleResult に渡す methodResults の要素を作る。
% 配列・cellの要素数がそろっているかをここで検証するので、
% 保存後に「どのセグメントの座標か分からない」状態になるのを防げる。
%
% 使い方:
%   res_cnt = cycleMethodResult("centroid", allPts_cnt_intpD, ...
%       xcoords, ycoords, y_comb, intpAudio);
%   res_max = cycleMethodResult("localMax", allPts_max_intpD, ...
%       xcoords_max, ycoords_max, y_comb_max, maxAudio);
%
%   % 溝底候補点だけを求めて音声は作っていない手法（比較用に点群だけ残す場合）
%   res_max = cycleMethodResult("localMax", allPts_max_intpD);
%
% 入力:
%   method  - "centroid"（重心法）または "localMax"（局所的最大値法）
%   pts     - (TOTAL_SEGMENTS x 1) GrooveCandidates
%   xcoords - (TOTAL_SEGMENTS x 1) cell。各セルは1セグメント分のx座標
%   ycoords - (TOTAL_SEGMENTS x 1) cell。各セルは1セグメント分のy座標（デトレンド後）
%   y_comb  - ycoords を縦に連結した1周分のy座標
%   audio   - (1x1) AudioData
%
% xcoords 以降は省略できる（その手法では音声を作っていない場合）。
% 省略するときは4つすべてを省略する。
%
% 関連: cycleConditions, saveCycleResult, loadCycleResult

    arguments
        method (1,1) string {mustBeMember(method,["centroid","localMax"])}
        pts (:,1) GrooveCandidates
        xcoords (:,1) cell = {}
        ycoords (:,1) cell = {}
        y_comb (:,1) double = []
        audio (:,1) AudioData = AudioData.empty(0,1)
    end

    given = [~isempty(xcoords), ~isempty(ycoords), ~isempty(y_comb), ~isempty(audio)];
    if ~any(given)
        % 溝底候補点だけを保存する
        res = struct();
        res.method  = method;
        res.pts     = pts;
        res.xcoords = {};
        res.ycoords = {};
        res.y_comb  = [];
        res.audio   = AudioData.empty(0,1);
        return
    end
    if ~all(given)
        error("cycleMethodResult:partialWaveform", ...
            "xcoords, ycoords, y_comb, audio は4つすべて指定するか、" + ...
            "4つすべて省略してください。");
    end
    if ~isscalar(audio)
        error("cycleMethodResult:notScalarAudio", ...
            "audio は 1x1 の AudioData を指定してください（%d 個渡されました）。", ...
            numel(audio));
    end

    nSeg = numel(ycoords);
    if numel(xcoords) ~= nSeg
        error("cycleMethodResult:sizeMismatch", ...
            "xcoords(%d) と ycoords(%d) の要素数が一致しません。", numel(xcoords), nSeg);
    end
    if numel(pts) ~= nSeg
        error("cycleMethodResult:sizeMismatch", ...
            "pts(%d) と ycoords(%d) の要素数が一致しません。", numel(pts), nSeg);
    end

    nComb = sum(cellfun(@numel, ycoords));
    if numel(y_comb) ~= nComb
        error("cycleMethodResult:yCombLength", ...
            "y_comb の長さ(%d)が ycoords の合計長(%d)と一致しません。" + ...
            "y_comb = vertcat(ycoords{:}) を渡してください。", numel(y_comb), nComb);
    end

    if numel(audio.signal) ~= numel(y_comb)
        warning("cycleMethodResult:audioLength", ...
            "audio.signal の長さ(%d)が y_comb の長さ(%d)と異なります。" + ...
            "平滑化などで長さが変わった音声を渡していないか確認してください。", ...
            numel(audio.signal), numel(y_comb));
    end

    res = struct();
    res.method  = method;
    res.pts     = pts;
    res.xcoords = xcoords;
    res.ycoords = ycoords;
    res.y_comb  = y_comb;
    res.audio   = audio;
end
