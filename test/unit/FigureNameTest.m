% 図のファイル名の検査（checkFigureName, figureVocabulary）の単体テスト
%
% docs/rules/figures.md の例が通ること、外れた名前に理由が返ること、
% figures.md の語彙表と figureVocabulary の一覧が一致していることを確かめる。
classdef FigureNameTest < matlab.unittest.TestCase

    properties
        rulesFile % docs/rules/figures.md のパス
    end

    methods (TestClassSetup)
        function addToPath(testCase)
            import matlab.unittest.fixtures.PathFixture
            thisDir = fileparts(mfilename('fullpath'));
            rootDir = fullfile(thisDir, '..', '..');
            testCase.applyFixture(PathFixture(fullfile(rootDir, 'src')));
            testCase.rulesFile = fullfile(rootDir, 'docs', 'rules', 'figures.md');
        end
    end

    methods (Test)
        %% 規則に沿った名前
        function testExamplesInRulesPass(testCase)
            % figures.md の「例」の表の名前（拡張子を除く）
            names = [
                "waveform_manualVsTrack_origD_centroid_1014_0-20ms"
                "spectrogram_origD_localMax_hist_5cyc_1104"
                "grooveOnImage_origD_centroid_track_1022_img3"
                "spectrogram_origDVsRsmplDVsIntpD_centroid_manual_0731_0-5kHz"
                "fig2-1_darknessProfile_origD_img1_seg5"
                ];
            for name = names'
                testCase.verifyEmpty(checkFigureName(name, Warn=false), name);
            end
        end

        function testOtherValidForms(testCase)
            names = [
                "image_img3_seg5"                                  % 条件もデータの日付も無い
                "fig5_spectrogram_origD_centroid_manual_0731"      % 枝番の無い図番号
                "waveform_manualVsStylus_origD_centroid_1014"      % 分類の違う語の比較
                "spectrogram_1014Vs1022_origD_centroid_track"      % データの日付の比較
                "waveform_rsmplD4xVsRsmplD8x_centroid_manual_0807" % 倍率付きの語
                "grooveShape_intpD_bilateralK5_centroid_manual_0924_img2_seg3"
                "spectrogram_origD_centroid_track_1014_0-5kHz_noColorbar"
                "grooveOnImage_origD_localMax_hist_5cyc_1104_img1_groove2"
                ];
            for name = names'
                testCase.verifyEmpty(checkFigureName(name, Warn=false), name);
            end
        end

        function testNoWarningForValidName(testCase)
            testCase.verifyWarningFree( ...
                @() checkFigureName("waveform_origD_centroid_manual_1014"));
        end

        %% 外れた名前
        function testWarningForInvalidName(testCase)
            testCase.verifyWarning( ...
                @() checkFigureName("audio_(centroid_method)(original)_amp"), ...
                "checkFigureName:invalidName");
        end

        function testInvalidCharacters(testCase)
            issues = checkFigureName("waveform_origD (centroid)", Warn=false);
            testCase.verifyTrue(any(contains(issues, "使えない文字")));
        end

        function testEmptyAndRepeatedSeparators(testCase)
            testCase.verifyNotEmpty(checkFigureName("", Warn=false));
            issues = checkFigureName("waveform__origD", Warn=false);
            testCase.verifyTrue(any(contains(issues, "_ が続いている")));
        end

        function testUnknownType(testCase)
            issues = checkFigureName("amp_origD_centroid_manual_1014", Warn=false);
            testCase.verifyTrue(any(contains(issues, "種類の語ではありません")));
        end

        function testUnknownWord(testCase)
            issues = checkFigureName("waveform_original_centroid_manual_1014", Warn=false);
            testCase.verifyTrue(any(contains(issues, "語彙表に無い語")));
        end

        function testForbiddenWords(testCase)
            issues = checkFigureName("waveform_origD_centroid_manual_1014_zoom", Warn=false);
            testCase.verifyTrue(any(contains(issues, "使わない語")));
            issues = checkFigureName("waveform_origD_centroid_manual_1014_2", Warn=false);
            testCase.verifyTrue(any(contains(issues, "数字だけの要素")));
        end

        function testConditionOrder(testCase)
            issues = checkFigureName("waveform_centroid_origD_manual_1014", Warn=false);
            testCase.verifyTrue(any(contains(issues, "位置が違います")));
        end

        function testElementOrder(testCase)
            issues = checkFigureName("waveform_origD_centroid_manual_0-20ms_1014", Warn=false);
            testCase.verifyTrue(any(contains(issues, "位置が違います")));
            issues = checkFigureName("waveform_origD_manualVsTrack_centroid_1014", Warn=false);
            testCase.verifyTrue(any(contains(issues, "位置が違います")));
        end

        function testComparisonNeedsCapital(testCase)
            issues = checkFigureName("waveform_manualVstrack_origD_centroid_1014", Warn=false);
            testCase.verifyTrue(any(contains(issues, "Vs の後ろの語の先頭")));
        end

        function testComparisonUnknownWord(testCase)
            issues = checkFigureName("waveform_manualVsAuto_origD_centroid_1014", Warn=false);
            testCase.verifyTrue(any(contains(issues, "'auto'")));
        end

        function testComparedCategoryRepeated(testCase)
            issues = checkFigureName("waveform_manualVsTrack_origD_centroid_track_1014", Warn=false);
            testCase.verifyTrue(any(contains(issues, "比較に出した分類")));
        end

        function testOneCycleNotWritten(testCase)
            issues = checkFigureName("waveform_origD_centroid_track_1cyc_1104", Warn=false);
            testCase.verifyTrue(any(contains(issues, "1周のとき")));
        end

        function testInvalidDate(testCase)
            issues = checkFigureName("waveform_origD_centroid_manual_1314", Warn=false);
            testCase.verifyTrue(any(contains(issues, "MMDD")));
            issues = checkFigureName("waveform_origD_centroid_manual_1014_1022", Warn=false);
            testCase.verifyTrue(any(contains(issues, "1つずつ")));
        end

        function testDuplicateElement(testCase)
            issues = checkFigureName("waveform_origD_origD_centroid_manual_1014", Warn=false);
            testCase.verifyTrue(any(contains(issues, "2回以上")));
        end

        %% figures.md の語彙表との一致
        function testVocabularyMatchesRules(testCase)
            lines = splitlines(string(fileread(testCase.rulesFile)));
            vocab = figureVocabulary();

            testCase.verifyEqual(tableColumn(lines, "種類", "語"), vocab.types, ...
                "figures.md の「種類」の表と figureVocabulary の types が違います。");
            testCase.verifyEqual(tableColumn(lines, "条件", "語"), vocab.conditions, ...
                "figures.md の「条件」の表と figureVocabulary の conditions が違います（順も比べる）。");
            testCase.verifyEqual(tableColumn(lines, "条件", "分類"), vocab.conditionCats, ...
                "figures.md の「条件」の表と figureVocabulary の conditionCats が違います。");
            testCase.verifyEqual(tableColumn(lines, "部分", "語"), vocab.parts, ...
                "figures.md の「部分」の表と figureVocabulary の parts が違います（順も比べる）。");
            testCase.verifyEqual(tableColumn(lines, "表示", "語"), vocab.displays, ...
                "figures.md の「表示」の表と figureVocabulary の displays が違います。");

            % 「使わない語」の段落のうち、_2 のような番号と作成日を除いた語
            forbidden = backtickWords(lines, "使わない語");
            forbidden = forbidden(~startsWith(forbidden, "_"));
            testCase.verifyEqual(sort(forbidden), sort(vocab.forbidden), ...
                "figures.md の「使わない語」と figureVocabulary の forbidden が違います。");
        end
    end
end

function values = tableColumn(lines, heading, columnName)
% 見出し「### <heading>」の直後にある表から、columnName の列を取り出す。
% セルの中が `...` なら、その中身を返す
    iHead = find(strtrim(lines) == "### " + heading, 1);
    assert(~isempty(iHead), "figures.md に見出し「### %s」がありません。", heading);
    iStart = iHead + find(startsWith(lines(iHead+1:end), "|"), 1);
    header = tableCells(lines(iStart));
    iCol = find(header == columnName, 1);
    assert(~isempty(iCol), "「%s」の表に列「%s」がありません。", heading, columnName);

    values = strings(0,1);
    iLine = iStart + 2; % 見出しの行と区切りの行を飛ばす
    while iLine <= numel(lines) && startsWith(lines(iLine), "|")
        cells = tableCells(lines(iLine));
        value = cells(iCol);
        inner = regexp(char(value), "^`([^`]+)`$", "tokens", "once");
        if ~isempty(inner)
            value = string(inner{1});
        end
        values(end+1,1) = value; %#ok<AGROW>
        iLine = iLine + 1;
    end
end

function cells = tableCells(line)
% "| a | b |" を ["a"; "b"] にする
    cells = strtrim(split(strtrim(line), "|"));
    cells = cells(2:end-1);
end

function words = backtickWords(lines, heading)
% 見出し「### <heading>」の後の最初の文（「。」まで）から、`...` で囲まれた語を取り出す
    iHead = find(strtrim(lines) == "### " + heading, 1);
    assert(~isempty(iHead), "figures.md に見出し「### %s」がありません。", heading);
    iText = iHead + find(strtrim(lines(iHead+1:end)) ~= "", 1);
    firstSentence = extractBefore(lines(iText), "。");
    tokens = regexp(char(firstSentence), "`([^`]+)`", "tokens");
    words = string(cellfun(@(c) c{1}, tokens, "UniformOutput", false))';
end
