function [matName, dValueName] = cycleResultFileName(upsampling, date)
% cycleResultFileName  1周分の実験結果を保存する.matのファイル名を返す。
%
% 保存側（saveCycleResult）と読み込み側（loadCycleResult を呼ぶスクリプト）で
% 同じ命名規則を使うための関数。
%
% 使い方:
%   [matName, dName] = cycleResultFileName("intpD", "0730");
%   % matName = "cycleResult_intpD_0730.mat"
%   % dName   = "cycleResult_intpD_0730_dValue.mat"
%
%   matPath = fullfile(experimentDir(rootFolder,"0730"), matName);
%
% 読み込み側はフォルダも含めて解決する cycleResultPath を使うほうが簡単。
%
% 関連: saveCycleResult, loadCycleResult, cycleResultPath, experimentDir

    arguments
        upsampling (1,1) string {mustBeMember(upsampling,["origD","rsmplD","intpD"])}
        date (1,1) string
    end

    base = "cycleResult_" + upsampling + "_" + date;
    matName    = base + ".mat";
    dValueName = base + "_dValue.mat";
end
