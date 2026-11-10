function issues = checkFigureName(name, opts)
% checkFigureName  図のファイル名が命名規則（docs/rules/figures.md）に沿っているかを確かめる。
%
% 確かめるのは形と語だけ：使える文字、語彙表（figureVocabulary）にある語か、
% 要素の並び順、使わない語。図が依存する条件をすべて書いたか、データの日付が
% 読み込んだデータと合っているかは確かめられない。
% 外れている点を issues に返し、Warn=true（既定）なら警告 checkFigureName:invalidName
% を1つ出す。保存関数（saveFigure・saveSlideFigure・savePaperFigure）が保存の前に呼ぶ。
% 作業を止めないよう、エラーにはしない。
%
% 使い方:
%   checkFigureName("waveform_manualVsTrack_origD_centroid_1014_0-20ms"); % 警告なし
%   issues = checkFigureName("audio_(centroid_method)_amp", Warn=false);  % 外れている点だけを得る
%
% name は拡張子を付けずに渡す。
%
% 関連: figureVocabulary, saveFigure, saveSlideFigure, savePaperFigure

    arguments
        name (1,1) string
        opts.Warn (1,1) logical = true
    end

    issues = strings(0,1);
    if strlength(name) == 0
        issues = "名前が空です。";
    else
        badChars = unique(string(regexp(char(name), "[^A-Za-z0-9_\-]", "match")));
        if ~isempty(badChars)
            issues(end+1,1) = "使えない文字 " + join("'" + badChars + "'", " ") + ...
                " があります（英数字と _ - だけを使う）。";
        end
        elements = split(name, "_");
        if any(elements == "")
            issues(end+1,1) = "_ が続いているか、先頭か末尾にあります。";
            elements(elements == "") = [];
        end
        issues = [issues; checkElements(elements, figureVocabulary())];
    end

    if opts.Warn && ~isempty(issues)
        warning("checkFigureName:invalidName", ...
            "図の名前 '%s' が命名規則（docs/rules/figures.md）に沿っていません。\n- %s", ...
            name, join(issues, newline + "- "));
    end
end

function issues = checkElements(elements, vocab)
% 要素を前から順に分類し、語彙表の語か、並び順が合っているかを確かめる。
% 並び順は「位置」の数で表し、前の要素より小さくなったら順が違うとする。
%   比較 1、条件 2+行番号/100、データの日付 3、部分 4+行番号/10、範囲 5、表示 6
    issues = strings(0,1);
    nEl = numel(elements);

    [uniqueEls, ~, idx] = unique(elements, "stable");
    counts = accumarray(idx, 1);
    for dupEl = uniqueEls(counts > 1)'
        issues(end+1,1) = "'" + dupEl + "' が2回以上あります。"; %#ok<AGROW>
    end

    % 原稿の図番号（任意）
    iEl = 1;
    if nEl >= 1 && matches(elements(1), regexpPattern("fig\d+(-\d+)?"))
        iEl = 2;
    end

    % 種類（必須）
    if iEl > nEl
        issues(end+1,1) = "種類の語がありません。";
        return
    end
    if ~ismember(elements(iEl), vocab.types)
        issues(end+1,1) = "'" + elements(iEl) + "' は種類の語ではありません（" + ...
            join(vocab.types, ", ") + "）。";
    end

    lastPos = 0;
    compCats = strings(0,1); % 比較に出した条件の分類
    for iEl = iEl+1:nEl
        el = elements(iEl);
        [pos, cats, msg] = classifyElement(el, vocab);
        if msg ~= ""
            issues(end+1,1) = msg; %#ok<AGROW>
            continue
        end

        if pos == lastPos && ismember(pos, [1 3])
            issues(end+1,1) = "'" + el + "'：比較とデータの日付は1つずつしか書けません。"; %#ok<AGROW>
        elseif pos < lastPos
            issues(end+1,1) = "'" + el + "' の位置が違います（並び順：種類 → 比較 → " + ...
                "条件（語彙表の順）→ データの日付 → 部分 → 範囲 → 表示）。"; %#ok<AGROW>
        end
        lastPos = max(lastPos, pos);

        if pos == 1
            compCats = [compCats; cats]; %#ok<AGROW>
        elseif pos > 2 && pos < 3
            dupCats = intersect(cats, compCats);
            if ~isempty(dupCats)
                issues(end+1,1) = "'" + el + "'：比較に出した分類（" + join(dupCats, "・") + ...
                    "）の語を、条件にも書いています。"; %#ok<AGROW>
            end
        end
    end
end

function [pos, cats, msg] = classifyElement(el, vocab)
% 1つの要素がどの位置の語かを決める。語彙表に無いなどで使えなければ、msg に理由を入れる
    pos = 0;
    cats = strings(0,1);
    msg = "";

    if ismember(lower(el), vocab.forbidden)
        msg = "'" + el + "' は使わない語です（何が違うのかを書く。範囲は 0-20ms の形、" + ...
            "比べた図は Vs でつなぐ）。";
        return
    end

    if contains(el, "Vs")
        pos = 1;
        [cats, msg] = classifyComparison(el, vocab);
        return
    end

    iRow = matchTemplate(el, vocab.conditions);
    if iRow > 0
        pos = 2 + iRow/100;
        cats = vocab.conditionCats(iRow);
        if vocab.conditions(iRow) == "<N>cyc" && str2double(extractBefore(el, "cyc")) < 2
            msg = "'" + el + "'：1周のときは周数を書きません。";
        end
        return
    end

    if matches(el, regexpPattern("\d+"))
        if isMMDD(el)
            pos = 3;
        elseif strlength(el) == 4
            msg = "'" + el + "' はデータの日付（MMDD）になっていません。";
        else
            msg = "数字だけの要素 '" + el + "' は、データの日付（MMDD の4桁）にだけ使います" + ...
                "（_2 のような番号は使わず、何が違うのかを書く）。";
        end
        return
    end

    iPart = matchTemplate(el, vocab.parts);
    if iPart > 0
        pos = 4 + iPart/10;
        return
    end

    if matches(el, regexpPattern("\d+-\d+(ms|s|Hz|kHz)"))
        pos = 5;
        return
    end

    if ismember(el, vocab.displays)
        pos = 6;
        return
    end

    msg = "'" + el + "' は語彙表に無い語です（新しい語なら docs/rules/figures.md と " + ...
        "figureVocabulary.m の両方に足す）。";
end

function [cats, msg] = classifyComparison(el, vocab)
% 比較（manualVsTrack など）を語に分け、それぞれが条件の語かデータの日付かを確かめる
    cats = strings(0,1);
    msg = "";

    parts = string(regexp(char(el), "Vs(?=[A-Z0-9])", "split"));
    if numel(parts) < 2 || any(parts == "")
        msg = "比較 '" + el + "' は、語彙表の語を Vs でつなぎ、Vs の後ろの語の先頭を" + ...
            "大文字にします（manualVsTrack）。";
        return
    end

    % Vs の後ろで大文字にした先頭を、語彙表の形（小文字始まり）に戻す
    parts = lower(extractBefore(parts, 2)) + extractAfter(parts, 1);
    for part = parts
        iRow = matchTemplate(part, vocab.conditions);
        if iRow > 0
            cats(end+1,1) = vocab.conditionCats(iRow); %#ok<AGROW>
        elseif ~isMMDD(part)
            msg = "比較 '" + el + "' の '" + part + "' が、語彙表の条件の語でもデータの日付でもありません。";
            return
        end
    end
    cats = unique(cats);
end

function iRow = matchTemplate(el, templates)
% templates の "<N>" を数字として el と照らし、合った行番号を返す（無ければ 0）
    iRow = 0;
    for k = 1:numel(templates)
        if matches(el, regexpPattern(replace(templates(k), "<N>", "\d+")))
            iRow = k;
            return
        end
    end
end

function tf = isMMDD(s)
% s が MMDD の形の日付（4桁、月 1〜12、日 1〜31）か
    tf = matches(s, regexpPattern("\d{4}"));
    if tf
        month = str2double(extractBefore(s, 3));
        day = str2double(extractAfter(s, 2));
        tf = month >= 1 && month <= 12 && day >= 1 && day <= 31;
    end
end
