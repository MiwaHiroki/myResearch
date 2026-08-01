function dirPath = experimentDir(rootFolder, date, opts)
% experimentDir  1周分の実験結果(.mat)を置く experiments/<日付>/ のパスを返す。
%
% results/ は図・音声の出力先で、消しても実験結果.matから作り直せる。一方
% experiments/ の.matは fitGroove の手動操作(80セグメント)なしには作り直せない。
% 寿命の違うものとしてフォルダを分けており、バックアップの対象は data/ と
% experiments/ の2つになる。
%
% 使い方:
%   proj = currentProject();
%   expDir = experimentDir(proj.RootFolder, "0731");                % 無ければ作る
%   expDir = experimentDir(proj.RootFolder, "0731", Create=false);  % パスを組むだけ
%
% name-value 引数:
%   Create - true（既定）ならフォルダが無いときに作る。読み込み側で
%            パスを組むだけのときは false にして空フォルダを作らない。
%
% 関連: mkdirFromDate, cycleResultPath, saveCycleResult

    arguments
        rootFolder (1,1) string
        date (1,1) string
        opts.Create (1,1) logical = true
    end

    dirPath = fullfile(rootFolder, "experiments", date);
    if opts.Create && ~isfolder(dirPath)
        mkdir(dirPath);
    end
end
