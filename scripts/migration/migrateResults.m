function actions = migrateResults(rootFolder, mappingFile, opts)
% migrateResults  対応表（CSV）を読み、古い形の results/・experiments/ のフォルダと
%                 ファイルを、新しい形の名前へ移す。
%
% migrateResults.m（scripts/migration/。2026-11-24 作成、issue #28）
%
% 手で移すと移し忘れや打ち間違いが起きやすいので、対応表を1行ずつ読んで移す。
% 過去の出力を失わないよう、次のようにする。
%   - 既定は試し（DryRun=true）で、何をするかの表を返すだけで、ファイルを何も動かさない。
%   - 全部の行について何をするかを先に決め、1つでもエラーがあれば何も動かさずに止める。
%   - 行き先にすでにあるものは上書きしない（エラーにする）。
%   - 移し終えた行は飛ばすので、途中で止まっても、もう一度呼べば続きを移せる。
%
% 使い方（MATLAB プロジェクトのパスに scripts/migration/ は入っていないので addpath する）:
%   root = string(currentProject().RootFolder);
%   addpath(fullfile(root,"scripts","migration"));
%   csv = fullfile(root,"scripts","migration","resultsMapping.csv");
%   actions = migrateResults(root, csv, Phase="results");                % 試し
%   actions = migrateResults(root, csv, Phase="results", DryRun=false);  % 移す
%
% 対応表の列（1行目は見出し。UTF-8）:
%   phase        "results"（results/ と原稿用の図）か "experiments"
%   kind         "dir"         フォルダごと移す（行き先はフォルダの新しいパス）
%                "files"       source の最後の要素をパターン（* だけを使う。大文字・小文字を
%                              区別しない）とし、合うファイルを行き先のフォルダへ移す
%                "file"        1ファイルを、名前を変えて移す（行き先はファイルの新しいパス）
%                "deleteEmpty" その行までの移動で空になったフォルダを消す（destination は空）
%   source       プロジェクトのルートからの "/" 区切りの相対パス。phase と同じ名前で始める
%   destination  同じく相対パス
%   note         メモ（省略できる。半角のカンマを書かない）
%
% 行ごとの status:
%   move    移す（元があり、行き先が無い）
%   done    移し終えている（元が無く、行き先がある）。deleteEmpty では、フォルダがもう無い
%   missing 元も行き先も無い（警告 migrateResults:sourceMissing を出して飛ばす。
%           一部のフォルダが無い PC でも動かせるようにするため）
%   delete  空になるので消す（deleteEmpty）
%
% name-value 引数:
%   Phase  - "results" か "experiments"（必須）。その phase の行だけを、CSV の順に扱う
%   DryRun - true（既定）なら表を返すだけ。false なら表の順に移し、空のフォルダを消す
%
% 出力:
%   actions - 行ごとの phase・kind・source・destination・status・count（移すファイルの数）の
%             table。表示もする
%
% エラー:
%   migrateResults:missingPhase      Phase を渡していない
%   migrateResults:invalidMapping    列が足りない、知らない phase・kind、パスの形が違う
%   migrateResults:destinationExists 元も行き先もある（上書きしない）
%   migrateResults:unmatchedFiles    deleteEmpty のフォルダに、どの行にも当たらないファイルが残る
%   migrateResults:moveFailed        movefile・rmdir が失敗した（そこで止まる。もう一度呼べば続きから）
%
% 関連: docs/issues/closed/28-results-by-experiment/plan.md 4.2.6、README の「対応表」

    arguments
        rootFolder (1,1) string
        mappingFile (1,1) string
        opts.Phase (1,1) string {mustBeMember(opts.Phase,["results","experiments"])}
        opts.DryRun (1,1) logical = true
    end

    if ~isfield(opts, "Phase")
        error("migrateResults:missingPhase", ...
            "Phase=""results"" か Phase=""experiments"" を指定してください。");
    end

    % --- 1. 対応表を読み、列と値を確かめる ---
    map = readMapping(mappingFile);
    map = map(map.phase == opts.Phase, :);
    nRows = height(map);

    % --- 2. 全部の行について、何をするかを先に決める（ファイルはまだ動かさない） ---
    status = strings(nRows, 1);
    count  = zeros(nRows, 1);
    moves  = cell(nRows, 1);       % 行ごとの [元 行き先] の組（絶対パス）
    claimedFiles = strings(0,1);   % 移すことに決めたファイル（元のパス）
    claimedDirs  = strings(0,1);   % 移すことに決めたフォルダ（元のパス）
    plannedDest  = strings(0,1);   % 移した後にできるファイル・フォルダ（行き先のパス）
    problems = struct("id", {}, "message", {});

    for r = 1:nRows
        kind = map.kind(r);
        src  = absPath(rootFolder, map.source(r));
        moves{r} = strings(0, 2);
        switch kind
            case {"dir", "file"}
                dst = absPath(rootFolder, map.destination(r));
                if kind == "dir"
                    srcExists = isfolder(src);
                else
                    srcExists = isfile(src);
                end
                % 前の行で移すことに決めたもの（とその中）は、移した後には無いものとして扱う
                srcExists = srcExists && ~isClaimed(src, claimedFiles, claimedDirs);
                dstExists = isfolder(dst) || isfile(dst) || ismember(key(dst), key(plannedDest));
                if srcExists && ~dstExists
                    status(r) = "move";
                    moves{r} = [src dst];
                    plannedDest(end+1,1) = dst; %#ok<AGROW>
                    if kind == "dir"
                        claimedDirs(end+1,1) = src; %#ok<AGROW>
                        count(r) = numel(filesUnder(src));
                    else
                        claimedFiles(end+1,1) = src; %#ok<AGROW>
                        count(r) = 1;
                    end
                elseif ~srcExists && dstExists
                    status(r) = "done";
                elseif ~srcExists && ~dstExists
                    status(r) = "missing";
                else
                    status(r) = "move";
                    problems(end+1) = problem("migrateResults:destinationExists", ...
                        map.destination(r) + " はすでにあります（元 " + map.source(r) + "）。上書きしません。"); %#ok<AGROW>
                end

            case "files"
                [srcFolder, pattern] = splitPattern(src);
                dstFolder = absPath(rootFolder, map.destination(r));
                names = matchingFiles(srcFolder, pattern);
                if ~isempty(names)
                    % 前の行で移すことに決めたファイルは、もう数えない（1ファイルを2行で移さない）
                    names = names(~isClaimed(srcFolder + filesep + names, claimedFiles, claimedDirs));
                end
                for k = 1:numel(names)
                    from = srcFolder + filesep + names(k);
                    to   = dstFolder + filesep + names(k);
                    claimedFiles(end+1,1) = from; %#ok<AGROW>
                    if isfile(to) || isfolder(to) || ismember(key(to), key(plannedDest))
                        problems(end+1) = problem("migrateResults:destinationExists", ...
                            relPath(rootFolder, to) + " はすでにあります（元 " + ...
                            relPath(rootFolder, from) + "）。上書きしません。"); %#ok<AGROW>
                    else
                        moves{r}(end+1,:) = [from to];
                        plannedDest(end+1,1) = to; %#ok<AGROW>
                    end
                end
                count(r) = size(moves{r}, 1);
                if ~isempty(names)
                    status(r) = "move";
                elseif ~isempty(matchingFiles(dstFolder, pattern))
                    status(r) = "done";
                else
                    status(r) = "missing";
                end

            case "deleteEmpty"
                if ~isfolder(src)
                    status(r) = "done";
                else
                    status(r) = "delete";
                    left = filesUnder(src);
                    left = left(~isClaimed(left, claimedFiles, claimedDirs));
                    if ~isempty(left)
                        problems(end+1) = problem("migrateResults:unmatchedFiles", ...
                            map.source(r) + " に、どの行にも当たらないファイルが残ります：" + ...
                            strjoin(relPath(rootFolder, left), "、")); %#ok<AGROW>
                    end
                end
        end
        if status(r) == "missing"
            warning("migrateResults:sourceMissing", "%s", ...
                map.source(r) + " も " + map.destination(r) + " もありません。この行は飛ばします。");
        end
    end

    actions = table(map.phase, map.kind, map.source, map.destination, status, count, ...
        VariableNames=["phase","kind","source","destination","status","count"]);

    % --- 3. エラーが1つでもあれば、何も動かさずに止める ---
    if ~isempty(problems)
        error(problems(1).id, "%s", "何も動かしていません。" + newline + ...
            strjoin("- " + string({problems.message}), newline));
    end

    disp(actions);

    % --- 4. 試しなら表を返して終える。そうでなければ表の順に移す ---
    if opts.DryRun
        return
    end
    for r = 1:nRows
        switch status(r)
            case "move"
                for k = 1:size(moves{r}, 1)
                    moveOne(moves{r}(k,1), moves{r}(k,2));
                end
            case "delete"
                removeEmpty(absPath(rootFolder, map.source(r)), rootFolder);
        end
    end
    fprintf("移し終えました（%s の段階、%d 行）。\n", opts.Phase, nRows);
end


function map = readMapping(mappingFile)
% 対応表の CSV を読み、列と値を確かめて string の table にする
    REQUIRED_COLUMNS = ["phase","kind","source","destination"];
    KINDS = ["dir","files","file","deleteEmpty"];

    if ~isfile(mappingFile)
        error("migrateResults:invalidMapping", "対応表がありません：%s", mappingFile);
    end
    lines = readlines(mappingFile, Encoding="UTF-8");
    lines = lines(strtrim(lines) ~= "");
    if isempty(lines)
        error("migrateResults:invalidMapping", "対応表が空です：%s", mappingFile);
    end
    lines(1) = erase(lines(1), char(65279));   % BOM 付きで保存された CSV にも対応する

    header = splitCsvLine(lines(1));
    missingColumns = REQUIRED_COLUMNS(~ismember(REQUIRED_COLUMNS, header));
    if ~isempty(missingColumns)
        error("migrateResults:invalidMapping", ...
            "対応表に列 %s がありません（列は phase,kind,source,destination,note）。", ...
            strjoin(missingColumns, ", "));
    end

    nRows = numel(lines) - 1;
    cols = strings(nRows, numel(header));
    for r = 1:nRows
        fields = splitCsvLine(lines(r+1));
        if numel(fields) ~= numel(header)
            error("migrateResults:invalidMapping", ...
                "対応表の %d 行目の列の数（%d）が見出し（%d）と違います：%s", ...
                r + 1, numel(fields), numel(header), lines(r+1));
        end
        cols(r, :) = fields;
    end

    map = table();
    for c = REQUIRED_COLUMNS
        map.(c) = strip(replace(cols(:, header == c), "\", "/"), "right", "/");
    end
    for r = 1:nRows
        row = "対応表の " + (r + 1) + " 行目：";
        if ~ismember(map.phase(r), ["results","experiments"])
            error("migrateResults:invalidMapping", "%s", row + "知らない phase """ + map.phase(r) + """");
        end
        if ~ismember(map.kind(r), KINDS)
            error("migrateResults:invalidMapping", "%s", row + "知らない kind """ + map.kind(r) + ...
                """（使えるのは " + strjoin(KINDS, ", ") + "）");
        end
        paths = map.source(r);
        if map.kind(r) ~= "deleteEmpty"
            paths(2) = map.destination(r);
        end
        for p = paths
            if ~isValidRelative(p, map.phase(r))
                error("migrateResults:invalidMapping", "%s", row + "パス """ + p + ...
                    """ は、""" + map.phase(r) + "/"" で始まるルートからの相対パスにしてください（.. は使えません）。");
            end
        end
    end
end


function tf = isValidRelative(p, phase)
% ルートの外や、別の段階のフォルダを指さないこと
    parts = split(p, "/");
    tf = p ~= "" && parts(1) == phase && numel(parts) >= 2 && ~any(ismember(parts, ["", ".", ".."]));
end


function fields = splitCsvLine(line)
% CSV の1行を列に分ける（" で囲んだ列の中のカンマと "" に対応する）
    chars = char(line);
    fields = strings(1, 0);
    cur = '';
    inQuote = false;
    k = 1;
    while k <= numel(chars)
        ch = chars(k);
        if inQuote
            if ch == '"' && k < numel(chars) && chars(k+1) == '"'
                cur(end+1) = '"'; %#ok<AGROW>
                k = k + 1;
            elseif ch == '"'
                inQuote = false;
            else
                cur(end+1) = ch; %#ok<AGROW>
            end
        elseif ch == '"'
            inQuote = true;
        elseif ch == ','
            fields(end+1) = strtrim(string(cur)); %#ok<AGROW>
            cur = '';
        else
            cur(end+1) = ch; %#ok<AGROW>
        end
        k = k + 1;
    end
    fields(end+1) = strtrim(string(cur));
end


function p = absPath(rootFolder, rel)
    p = rootFolder + filesep + replace(rel, "/", filesep);
end


function r = relPath(rootFolder, p)
% 表示用に、ルートからの "/" 区切りのパスにする
    r = replace(extractAfter(p, strlength(rootFolder) + 1), filesep, "/");
end


function [folder, pattern] = splitPattern(src)
    [folder, name, ext] = fileparts(src);
    pattern = name + ext;
end


function names = matchingFiles(folder, pattern)
% folder の直下で、パターン（* だけを使う。大文字・小文字を区別しない）に合うファイルの名前
    names = strings(0, 1);
    if ~isfolder(folder)
        return
    end
    listing = dir(folder);
    listing = listing(~[listing.isdir]);
    if isempty(listing)
        return
    end
    allNames = string({listing.name})';
    rx = "^" + replace(regexptranslate("escape", pattern), "\*", ".*") + "$";
    names = allNames(~cellfun(@isempty, regexp(cellstr(allNames), rx, "once", "ignorecase")));
end


function files = filesUnder(folder)
% folder の下（サブフォルダも含む）のすべてのファイルの絶対パス
    listing = dir(fullfile(folder, "**", "*"));
    listing = listing(~[listing.isdir]);
    files = strings(0, 1);
    for k = 1:numel(listing)
        files(end+1, 1) = string(fullfile(listing(k).folder, listing(k).name)); %#ok<AGROW>
    end
end


function tf = isClaimed(paths, claimedFiles, claimedDirs)
% 前の行で移すことに決めたファイルか、移すことに決めたフォルダそのものか、その中にあるか
    k = key(paths);
    tf = ismember(k, key([claimedFiles; claimedDirs]));
    for d = key(claimedDirs)'
        tf = tf | startsWith(k, d + filesep);
    end
end


function k = key(p)
% パスを比べるときの形（Windows のパスは大文字・小文字を区別せず、/ と \ を同じに扱う）
    if ispc
        k = lower(replace(p, "/", "\"));
    else
        k = p;
    end
end


function s = problem(id, message)
    s = struct("id", id, "message", message);
end


function moveOne(from, to)
    parent = fileparts(to);
    if ~isfolder(parent)
        mkdir(parent);
    end
    [ok, msg] = movefile(from, to);
    if ~ok
        error("migrateResults:moveFailed", "%s", ...
            "移せませんでした：" + from + " → " + to + "（" + msg + "）。" + ...
            "原因を直してからもう一度呼べば、移し終えたものを飛ばして続きを移します。");
    end
end


function removeEmpty(folder, rootFolder)
% 空になったフォルダを消す。消す直前にもう一度、ファイルが無いことを確かめる
    if ~isfolder(folder)
        return
    end
    left = filesUnder(folder);
    if ~isempty(left)
        error("migrateResults:unmatchedFiles", "%s", relPath(rootFolder, folder) + ...
            " にファイルが残っているので消しません：" + strjoin(relPath(rootFolder, left), "、"));
    end
    [ok, msg] = rmdir(folder, "s");
    if ~ok
        error("migrateResults:moveFailed", "%s", "フォルダを消せませんでした：" + folder + "（" + msg + "）");
    end
end
