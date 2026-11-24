% figureDir（完成した図の置き場所）の単体テスト
%
% 一時フォルダをプロジェクトのルートに見立てて、その中だけに作る。
classdef FigureDirTest < matlab.unittest.TestCase

    properties
        root   % 一時フォルダ（プロジェクトのルートに見立てる）
    end

    methods (TestClassSetup)
        function addToPath(testCase)
            import matlab.unittest.fixtures.PathFixture
            thisDir = fileparts(mfilename('fullpath'));
            srcDir  = fullfile(thisDir, '..', '..', 'src');
            testCase.applyFixture(PathFixture(srcDir));
        end
    end

    methods (TestMethodSetup)
        function makeRoot(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture = testCase.applyFixture(TemporaryFolderFixture);
            testCase.root = string(fixture.Folder);
        end
    end

    methods (Test)

        function testPathsAndCreation(testCase)
            figRoot = fullfile(testCase.root, "results", "figures");
            p = figureDir(testCase.root, "progress", "multiGroove");
            testCase.verifyClass(p, "string");
            testCase.verifyEqual(p, fullfile(figRoot, "progress", "multiGroove"));
            testCase.verifyEqual(figureDir(testCase.root, "slides", "202702thesis"), ...
                fullfile(figRoot, "202702thesis", "slides"));
            testCase.verifyEqual(figureDir(testCase.root, "paper", "202609asj"), ...
                fullfile(figRoot, "202609asj", "paper"));
            testCase.verifyTrue(isfolder(fullfile(figRoot, "progress", "multiGroove")));
            testCase.verifyTrue(isfolder(fullfile(figRoot, "202702thesis", "slides")));
            testCase.verifyTrue(isfolder(fullfile(figRoot, "202609asj", "paper")));
            testCase.verifyFalse(endsWith(p, filesep), "末尾に区切り文字が付いている");
        end

        function testExistingFolderKeepsFiles(testCase)
            % すでにあるフォルダはそのまま使い、中のファイルを消さない
            p = figureDir(testCase.root, "slides", "202609asj");
            writelines("x", fullfile(p, "old.png"));
            p2 = figureDir(testCase.root, "slides", "202609asj");
            testCase.verifyEqual(p2, p);
            testCase.verifyTrue(isfile(fullfile(p, "old.png")));
        end

        function testInvalidNames(testCase)
            for v = ["202609", "asj202609", "2026asj", "202609ASJ", "202609-asj", "202609asj2", ""]
                testCase.verifyError(@() figureDir(testCase.root, "paper", v), "figureDir:invalidVenue", ...
                    "発表名 """ + v + """");
            end
            for t = ["Grooves", "groove-tracking", "groove_tracking", "202609asj", ""]
                testCase.verifyError(@() figureDir(testCase.root, "progress", t), "figureDir:invalidTheme", ...
                    "テーマ """ + t + """");
            end
            testCase.verifyError(@() figureDir(testCase.root, "figures", "202609asj"), ?MException);
            testCase.verifyFalse(isfolder(fullfile(testCase.root, "results")), "エラーなのにフォルダを作った");
        end
    end
end
