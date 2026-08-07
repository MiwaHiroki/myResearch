% checkStaticAnalysis を使い、src/・scripts/（archiveを除く）に
% 構文エラー相当（checkcodeのid: SYNER）の指摘が無いことを確認する。
% 未使用変数などのスタイル指摘は失敗条件に含めない（checkStaticAnalysis.m参照）。
% 編集直後に1ファイルだけ確認したいときは checkStaticAnalysis を直接呼べばよい。
classdef StaticAnalysisTest < matlab.unittest.TestCase

    properties
        rootDir
    end

    methods (TestClassSetup)
        function addToPath(testCase)
            import matlab.unittest.fixtures.PathFixture
            thisDir = fileparts(mfilename('fullpath'));
            testDir = fullfile(thisDir, '..');
            testCase.applyFixture(PathFixture(testDir)); % checkStaticAnalysis.m を使えるようにする
            testCase.rootDir = fullfile(testDir, '..');
        end
    end

    methods (Test)
        function testNoFatalIssuesInSrc(testCase)
            report = checkStaticAnalysis(fullfile(testCase.rootDir, "src"));
            testCase.verifyNoFatalIssues(report);
        end

        function testNoFatalIssuesInScripts(testCase)
            report = checkStaticAnalysis(fullfile(testCase.rootDir, "scripts"));
            testCase.verifyNoFatalIssues(report);
        end
    end

    methods (Access = private)
        function verifyNoFatalIssues(testCase, report)
            fatalReport = report(report.fatal, :);
            diagLines = compose("%s:%d - [%s] %s", ...
                fatalReport.file, fatalReport.line, fatalReport.id, fatalReport.message);
            testCase.verifyEmpty(fatalReport, strjoin(diagLines, newline));
        end
    end
end
