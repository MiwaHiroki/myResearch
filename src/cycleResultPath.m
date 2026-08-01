function [matPath, dValuePath] = cycleResultPath(rootFolder, upsampling, date)
% cycleResultPath  1周分の実験結果.matのパスを返す（読み込み側用）。
%
% 既定の置き場は experiments/<日付>/ だが、そこに無ければ移行前の置き場である
% results/<日付>/ も探す。どちらにも無い場合は experiments/ 側のパスを返すので、
% loadCycleResult のエラーメッセージは新しい置き場を指す。
%
% 図の作成スクリプトがパスを直書きしないようにするための関数。
%
% 使い方:
%   proj = currentProject();
%   matPath = cycleResultPath(proj.RootFolder, "intpD", "0731");
%   result  = loadCycleResult(matPath);
%
% 出力:
%   matPath    - 結果.matのパス
%   dValuePath - 同じフォルダにある "..._dValue.mat" のパス
%
% 関連: cycleResultFileName, experimentDir, loadCycleResult

    arguments
        rootFolder (1,1) string
        upsampling (1,1) string {mustBeMember(upsampling,["origD","rsmplD","intpD"])}
        date (1,1) string
    end

    [matName, dValueName] = cycleResultFileName(upsampling, date);

    searchDirs = [ experimentDir(rootFolder, date, Create=false)
                   fullfile(rootFolder, "results", date) ]; % 移行前の置き場

    matPath = fullfile(searchDirs(1), matName); % 見つからなければこれを返す
    for k = 1:numel(searchDirs)
        candidate = fullfile(searchDirs(k), matName);
        if isfile(candidate)
            matPath = candidate;
            break
        end
    end

    % _dValue.mat は結果.matと同じフォルダにあるものとする（loadCycleResult も同じ前提）
    dValuePath = fullfile(fileparts(matPath), dValueName);
end
