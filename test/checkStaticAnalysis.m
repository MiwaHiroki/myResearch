function report = checkStaticAnalysis(target, opts)
% checkStaticAnalysis  MATLAB Code Analyzer(checkcode)を実行し、
% 構文エラー相当（実行前に確実に壊れているとわかるもの）だけを
% fatal=true としてマークしたレポートを返す。
%
% checkcodeは未使用変数や命名規則などのスタイル指摘も同列で返し、
% severity情報を持たない。src/archive・scripts/archiveには意図的に
% 配線されていない旧コードが残っており、そこにスタイル指摘があっても
% 壊れているわけではないため、fatalとみなすのは「構文解析自体が
% 通らない」ケース（id: SYNER）だけに絞る。
%
% 使い方:
%   % 1ファイルだけ確認する（編集直後の簡易チェックに便利）
%   report = checkStaticAnalysis("src/omitMask.m");
%
%   % フォルダ配下を再帰的にチェックする（archive配下は既定で除外）
%   report = checkStaticAnalysis("src");
%
%   fatalReport = report(report.fatal, :);
%
% 入力:
%   target - .mファイル1件、またはフォルダのパス（string/char）
%
% name-value 引数:
%   ExcludeDirs - パスの一部として含まれていたら除外するフォルダ名
%                 （既定: "archive"）。target がファイル1件のときは無視される。
%
% 出力:
%   report - table。列は file, id, line, column, message, fatal
%            （指摘が1件も無ければ 0 行）

    arguments
        target (1,1) string
        opts.ExcludeDirs (1,:) string = "archive"
    end

    FATAL_IDS = ["SYNER"];

    if isfolder(target)
        files = collectMFiles(target, opts.ExcludeDirs);
    elseif isfile(target)
        files = target;
    else
        error("checkStaticAnalysis:targetNotFound", ...
            "指定されたパスが見つかりません: %s", target);
    end

    file = strings(0,1); id = strings(0,1); line = zeros(0,1);
    column = zeros(0,1); message = strings(0,1); fatal = false(0,1);

    for k = 1:numel(files)
        issues = checkcode(char(files(k)), '-id');
        for j = 1:numel(issues)
            file(end+1,1)    = files(k); %#ok<AGROW>
            id(end+1,1)      = string(issues(j).id); %#ok<AGROW>
            line(end+1,1)    = issues(j).line(1); %#ok<AGROW>
            column(end+1,1)  = issues(j).column(1); %#ok<AGROW>
            message(end+1,1) = string(issues(j).message); %#ok<AGROW>
            fatal(end+1,1)   = ismember(string(issues(j).id), FATAL_IDS); %#ok<AGROW>
        end
    end

    report = table(file, id, line, column, message, fatal);
end


function files = collectMFiles(folder, excludeDirs)
    listing = dir(fullfile(folder, "**", "*.m"));
    files = strings(0,1);
    for k = 1:numel(listing)
        parts = split(string(listing(k).folder), filesep);
        if any(ismember(excludeDirs, parts))
            continue
        end
        files(end+1,1) = string(fullfile(listing(k).folder, listing(k).name)); %#ok<AGROW>
    end
end
