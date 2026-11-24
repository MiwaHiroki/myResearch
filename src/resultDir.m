function [outDir, runInfo] = resultDir(rootFolder, experiment, date, conditions, opts)
% resultDir  実行フォルダ results/<実験名>/<YYYY-MMDD>[_<説明>][_<N>]/ を作り、
%            実行記録 runInfo.json を書いて、そのパスを返す。
%
% スクリプトの冒頭で1回だけ呼ぶ。フォルダ名を見ればいつ・何の実験かが分かるようにし、
% どのスクリプト・コード・入力・条件で作ったかを後からたどれるように、出力を作る前に
% 実行記録を残す。同じ名前のフォルダがあれば、上書きしないよう _2、_3… を付けて警告する
% （saveCycleResult が既存のファイルを上書きしないのと同じ考え方）。
% 実験名の一覧と runInfo.json の項目は README の「結果の置き場所と実行記録」にある。
%
% 使い方:
%   EXPERIMENT_NAME = "multiGroove";   % README の「実験名の一覧」から選ぶ
%   date = "YYYY-MMDD";                % 実行した日（例 "2026-1124"）に書き換える
%   LABEL = "hist5";                   % 説明（付けないなら ""）
%   runCond = runConditions(LMask=L_MASK, Upsampling="origD", ...);
%   outDir = resultDir(proj.RootFolder, EXPERIMENT_NAME, date, runCond, Label=LABEL, ...
%       ScriptName="grooveHist_Ncycle", Images=filenames_new, InputFiles=PREV_RESULT_PATH);
%   saveas(fig, outDir + "grooveHist_img1.png");   % 戻り値の末尾には区切り文字が付く
%
% 入力:
%   rootFolder - プロジェクトのルート（currentProject().RootFolder）
%   experiment - 実験名。英語の camelCase（"figures" は図の置き場所なので使えない）
%   date       - 実行した日 "YYYY-MMDD"（例 "2026-1124"）
%   conditions - runConditions の出力（条件を書かないなら struct()）
%
% name-value 引数:
%   Label      - 説明（既定 ""）。詳細は "_" でつなぐ（"evaluation_polyDegree"）。
%                各部分は英数字だけで、数字だけの部分は使えない（_2 などの番号と
%                見分けるため）
%   ScriptName - スクリプトの名前（拡張子なし。既定 ""）。scripts/ の下（archive を除く）
%                から探し、ルートからのパスを runInfo.json の script に書く
%   Images     - 使った撮影画像のファイル名（既定 空）
%   InputFiles - 読んだファイル（cycleResult など。既定 空）。"" は除く
%   Note       - 一言の説明、別の文書への参照（既定 ""）
%
% 出力:
%   outDir  - 作った実行フォルダの絶対パス（string）。末尾に区切り文字が付く
%             （今までの出力先と同じ形。outDir + "name.png" で使えるようにするため）
%   runInfo - runInfo.json に書いた内容の struct
%
% runInfo.json は jsonencode（PrettyPrint）で UTF-8（BOM なし）で書く。一覧は要素が1つでも
% JSON の配列にし、ルートの下のパス（inputs.files と conditions の中の文字列）は
% ルートからの "/" 区切りの相対パスにする。
%
% エラー・警告:
%   resultDir:dateNotSet        date が "YYYY-MMDD" のまま（エラー）
%   resultDir:invalidDate       date が YYYY-MMDD の形でないか、暦に無い日付（エラー）
%   resultDir:invalidExperiment 実験名が camelCase でないか "figures"（エラー）
%   resultDir:invalidLabel      説明の形が違う（エラー）
%   resultDir:folderExists      同じ名前のフォルダがあり、_<N> を付けた（警告）
%   resultDir:scriptNotFound    ScriptName のスクリプトが見つからないか2つ以上ある（警告）
% JSON にできない値（関数ハンドルなど）が conditions にあれば、jsonencode のエラーで止まり、
% フォルダは作らない。
%
% 関連: runConditions, collectMeta, experimentDir, figureDir

    arguments
        rootFolder (1,1) string
        experiment (1,1) string
        date (1,1) string
        conditions (1,1) struct
        opts.Label (1,1) string = ""
        opts.ScriptName (1,1) string = ""
        opts.Images string = strings(0,1)
        opts.InputFiles string = strings(0,1)
        opts.Note (1,1) string = ""
    end

    SCHEMA_VERSION = 1;   % runInfo.json の形の版。キーの名前や入れ子を変えたら上げる（README の版の表）

    % --- 1〜3. 日付・実験名・説明を確かめる（何も作る前に） ---
    checkDate(date);
    checkExperiment(experiment);
    checkLabel(opts.Label);

    % --- 4. フォルダ名を決める ---
    baseName = date;
    if opts.Label ~= ""
        baseName = date + "_" + opts.Label;
    end
    expFolder = fullfile(rootFolder, "results", experiment);
    runName = baseName;
    if isTaken(fullfile(expFolder, runName))
        k = 2;
        while isTaken(fullfile(expFolder, baseName + "_" + k))
            k = k + 1;
        end
        runName = baseName + "_" + k;
        warning("resultDir:folderExists", "%s", ...
            "results/" + experiment + "/" + baseName + " はすでにあるので、" + ...
            runName + " に出力します（上書きしないため）。");
    end
    runFolder = fullfile(expFolder, runName);

    % --- 5. 実行記録を組み立てて、JSON の文字列にする ---
    % フォルダを作る前に変換するのは、変換できない値があったときに空のフォルダを残さないため
    meta = collectMeta(opts.ScriptName, IncludeBranch=true);

    inputFiles = opts.InputFiles(:);
    inputFiles = inputFiles(inputFiles ~= "");

    runInfo = struct();
    runInfo.schemaVersion = SCHEMA_VERSION;
    runInfo.experiment    = experiment;
    runInfo.run           = runName;
    runInfo.script        = scriptPath(rootFolder, opts.ScriptName);
    runInfo.note          = opts.Note;
    runInfo.inputs        = struct( ...
        "images", {asList(opts.Images)}, ...
        "files",  {asList(relativePaths(inputFiles, rootFolder))});
    runInfo.conditions    = relativePaths(conditions, rootFolder);
    runInfo.meta          = struct( ...
        "createdAt",     string(meta.savedAt, "yyyy-MM-dd'T'HH:mm:ss"), ...
        "git",           struct("commit", meta.gitCommit, "branch", meta.gitBranch, ...
                                "dirty", meta.gitDirty), ...
        "matlabRelease", "R" + meta.matlabRelease, ...
        "computerName",  meta.computerName);

    txt = jsonencode(runInfo, PrettyPrint=true);

    % --- 6. フォルダを作り、runInfo.json を書く ---
    mkdir(runFolder);
    try
        writelines(txt, fullfile(runFolder, "runInfo.json"), Encoding="UTF-8");
    catch err
        rmdir(runFolder, "s");   % 作ったばかりで、ほかには何も無い
        rethrow(err);
    end

    outDir = string(runFolder) + filesep;
end


function tf = isTaken(p)
% 同じ名前のフォルダかファイルがあれば、その名前では作れない
    tf = isfolder(p) || isfile(p);
end


function checkDate(date)
% 実行した日を "YYYY-MMDD" の形で書いているか確かめる。スクリプトに出力の日付を
% 書き込まず、実行のたびに書き換えてもらうため、"YYYY-MMDD" のままなら止める。
    if date == "YYYY-MMDD"
        error("resultDir:dateNotSet", ...
            "date が ""YYYY-MMDD"" のままです。実行した日を ""2026-1124"" の形で書いてください。");
    end
    isValid = ~isempty(regexp(date, "^\d{4}-\d{4}$", "once"));
    if isValid
        try
            % 暦に無い日付（2026-0230 など）は datetime が読めない
            isValid = string(datetime(date, "InputFormat", "yyyy-MMdd"), "yyyy-MMdd") == date;
        catch
            isValid = false;
        end
    end
    if ~isValid
        error("resultDir:invalidDate", ...
            "date ""%s"" は YYYY-MMDD の形の、暦にある日付ではありません（例 ""2026-1124""）。", date);
    end
end


function checkExperiment(experiment)
    if isempty(regexp(experiment, "^[a-z][a-zA-Z0-9]*$", "once")) || experiment == "figures"
        error("resultDir:invalidExperiment", ...
            "実験名 ""%s"" は使えません。英語の camelCase（例 ""grooveTracking""）にしてください" + ...
            "（""figures"" は図の置き場所なので使えません）。", experiment);
    end
end


function checkLabel(label)
    if label == ""
        return
    end
    parts = split(label, "_");
    isAlnum = ~cellfun(@isempty, regexp(cellstr(parts), "^[A-Za-z0-9]+$", "once"));
    isDigits = ~cellfun(@isempty, regexp(cellstr(parts), "^\d+$", "once"));
    if ~all(isAlnum) || any(isDigits)
        error("resultDir:invalidLabel", ...
            "説明 ""%s"" は使えません。""_"" で区切った各部分を英数字だけにし、" + ...
            "数字だけの部分を作らないでください（例 ""evaluation_polyDegree""）。", label);
    end
end


function p = scriptPath(rootFolder, scriptName)
% scripts/ の下（archive を除く）から <scriptName>.m を探し、ルートからの "/" 区切りの
% パスを返す。見つからないか2つ以上あれば、名前だけを返して警告する。
    if scriptName == ""
        p = "";
        return
    end
    found = dir(fullfile(rootFolder, "scripts", "**", scriptName + ".m"));
    rel = strings(0,1);
    for k = 1:numel(found)
        r = relativePaths(string(fullfile(found(k).folder, found(k).name)), rootFolder);
        if ~any(split(r, "/") == "archive")
            rel(end+1,1) = r; %#ok<AGROW>
        end
    end
    if isscalar(rel)
        p = rel;
    else
        p = scriptName + ".m";
        warning("resultDir:scriptNotFound", "%s", ...
            "scripts/ の下（archive を除く）に " + scriptName + ".m が " + numel(rel) + ...
            " 個あるので、runInfo.json の script には名前だけを書きます。");
    end
end


function v = relativePaths(v, rootFolder)
% v（struct・cell・文字列）の中の、rootFolder の下を指す文字列を、ルートからの
% "/" 区切りの相対パスにする。ほかの値はそのまま返す。
    if isstruct(v)
        for f = string(fieldnames(v))'
            for k = 1:numel(v)
                v(k).(f) = relativePaths(v(k).(f), rootFolder);
            end
        end
    elseif iscell(v)
        for k = 1:numel(v)
            v{k} = relativePaths(v{k}, rootFolder);
        end
    elseif isstring(v)
        for k = 1:numel(v)
            v(k) = toRelative(v(k), rootFolder);
        end
    elseif ischar(v) && (isrow(v) || isempty(v))
        v = char(toRelative(string(v), rootFolder));
    end
end


function p = toRelative(p, rootFolder)
    if ismissing(p)
        return
    end
    root = replace(rootFolder, "\", "/");
    if endsWith(root, "/")
        root = extractBefore(root, strlength(root));
    end
    q = replace(p, "\", "/");
    prefix = root + "/";
    if ispc
        isUnder = startsWith(lower(q), lower(prefix));   % Windows のパスは大文字・小文字を区別しない
    else
        isUnder = startsWith(q, prefix);
    end
    if isUnder
        p = extractAfter(q, strlength(prefix));
    end
end


function c = asList(x)
% 一覧を cell の行にする（要素が1つでも JSON の配列にするため）
    c = num2cell(x(:)');
end
