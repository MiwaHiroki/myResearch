function result = loadCycleResult(matPath, opts)
% loadCycleResult  saveCycleResult で保存した1周分の実験結果を読み込む。
%
% 図の作成スクリプトはこの関数で結果を読むだけにし、fitGroove の手動操作を
% 伴う解析を再実行しなくて済むようにする。
%
% 使い方:
%   proj = currentProject();
%   matPath = fullfile(proj.RootFolder, "results", "0730", ...
%       cycleResultFileName("intpD","0730"));
%   result = loadCycleResult(matPath);
%
%   figure; result.centroid.audio.spectrogramPlot(4096);
%
%   % DarknessValue（別ファイルに保存した dMat）も要るとき
%   result = loadCycleResult(matPath, LoadDarknessValues=true);
%   figure; result.allD(1).plotD_x(100);
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
% 関連: saveCycleResult, cycleResultFileName

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
            "%s には DarknessValue が保存されていません。\n" + ...
            "保存するには saveCycleResult に SaveDarknessValues=true を指定してください。", ...
            matPath);
    end

    dValuePath = fullfile(fileparts(matPath), result.dValueFile);
    if ~isfile(dValuePath)
        error("loadCycleResult:dValueFileNotFound", ...
            "DarknessValue のファイルが見つかりません: %s", dValuePath);
    end

    loadedD = load(dValuePath, "allD");
    if ~isfield(loadedD, "allD")
        error("loadCycleResult:invalidDValueFile", ...
            "%s に変数 allD が含まれていません。", dValuePath);
    end
    result.allD = loadedD.allD;
end
