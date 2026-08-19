function result = loadCycleResult(matPath, opts)
% loadCycleResult  saveCycleResult で保存した1周分の実験結果を読み込む。
%
% 図の作成スクリプトはこの関数で結果を読むだけにし、fitGroove の手動操作を
% 伴う解析を再実行しなくて済むようにする。
%
% 使い方:
%   proj = currentProject();
%   matPath = cycleResultPath(proj.RootFolder, "intpD", "0731");
%   result = loadCycleResult(matPath);
%
%   figure; result.centroid.audio.spectrogramPlot(4096);
%
%   % DarknessMap（別ファイルに保存した dMat）も要るとき
%   result = loadCycleResult(matPath, LoadDarknessValues=true);
%   figure; result.allD(1).plotDarknessColumn(100);
%
%   % fitGroove で選んだ p1,p2 を使って別の高解像度化条件を ginput なしで
%   % 再解析する（result.grooveSelection.p1/p2 を再利用する）
%   prev = loadCycleResult(prevMatPath);
%   [~,~,pksCorCell] = fitGroove(jSegment,fig,p2,w,h,{pks_max,pks_cnt}, ...
%       P1=prev.grooveSelection.p1(kImgSmall,:), P2=prev.grooveSelection.p2(kImgSmall,:));
%
% 入力:
%   matPath - 結果.matのパス
%
% name-value 引数:
%   LoadDarknessValues - true のとき "<結果ファイル名>_dValue.mat" も読み込み、
%                        result.allD に格納する（既定: false）。
%                        _dValue.mat は結果.matと同じフォルダにあるものとする。
%
% 出力:
%   result - saveCycleResult が保存した result（構成は saveCycleResult のヘルプ参照）
%
% 関連: saveCycleResult, cycleResultPath, cycleResultFileName

    arguments
        matPath (1,1) string
        opts.LoadDarknessValues (1,1) logical = false
    end

    if ~isfile(matPath)
        error("loadCycleResult:fileNotFound", ...
            "結果ファイルが見つかりません: %s\n" + ...
            "saveCycleResult で保存済みか、日付とアップサンプリング条件が" + ...
            "合っているか確認してください。", matPath);
    end

    loaded = load(matPath, "result");
    if ~isfield(loaded, "result")
        error("loadCycleResult:invalidFile", ...
            "%s に変数 result が含まれていません。" + ...
            "saveCycleResult で保存した.matを指定してください。", matPath);
    end
    result = loaded.result;

    if ~opts.LoadDarknessValues
        return
    end

    if ~isfield(result, "dValueFile") || result.dValueFile == ""
        error("loadCycleResult:noDarknessValues", ...
            "%s には DarknessMap が保存されていません。\n" + ...
            "保存するには saveCycleResult に SaveDarknessValues=true を指定してください。", ...
            matPath);
    end

    dValuePath = fullfile(fileparts(matPath), result.dValueFile);
    if ~isfile(dValuePath)
        error("loadCycleResult:dValueFileNotFound", ...
            "DarknessMap のファイルが見つかりません: %s", dValuePath);
    end

    loadedD = load(dValuePath, "allD");
    if ~isfield(loadedD, "allD")
        error("loadCycleResult:invalidDValueFile", ...
            "%s に変数 allD が含まれていません。", dValuePath);
    end
    result.allD = loadedD.allD;
end
