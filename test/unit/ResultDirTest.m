% resultDir（実行フォルダと実行記録 runInfo.json）の単体テスト
%
% 一時フォルダをプロジェクトのルートに見立てて、その中だけに作る（実データは読まない）。
% 外側から見た仕様は ResultLayoutAcceptanceTest が確かめるので、ここでは実装の細部
% （番号の付け方、パスの書き換えの境目、戻り値の struct など）を確かめる。
classdef ResultDirTest < matlab.unittest.TestCase

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

        function testFolderNameAndTrailingSeparator(testCase)
            outDir = resultDir(testCase.root, "bilateralFilter", "2026-0924", struct(), Label="1cycle");
            expected = fullfile(testCase.root, "results", "bilateralFilter", "2026-0924_1cycle");
            testCase.verifyClass(outDir, "string");
            testCase.verifyEqual(outDir, expected + filesep);
            testCase.verifyTrue(endsWith(outDir, filesep));
            testCase.verifyTrue(isfolder(expected));
        end

        function testNumberingSkipsTakenNames(testCase)
            % _2 が埋まっていれば _3 にする。同じ名前のファイルがあっても、その名前は使わない
            expFolder = fullfile(testCase.root, "results", "multiGroove");
            mkdir(fullfile(expFolder, "2026-1028_hist5"));
            mkdir(fullfile(expFolder, "2026-1028_hist5_2"));
            outDir = testCase.verifyWarning(@() resultDir(testCase.root, "multiGroove", "2026-1028", ...
                struct(), Label="hist5"), "resultDir:folderExists");
            testCase.verifyEqual(outDir, fullfile(expFolder, "2026-1028_hist5_3") + filesep);

            writelines("x", fullfile(expFolder, "2026-1104"));   % フォルダではなくファイル
            outDir2 = testCase.verifyWarning(@() resultDir(testCase.root, "multiGroove", "2026-1104", ...
                struct()), "resultDir:folderExists");
            testCase.verifyEqual(outDir2, fullfile(expFolder, "2026-1104_2") + filesep);
        end

        function testFolderExistsMessageNamesBothFolders(testCase)
            resultDir(testCase.root, "grooveTracking", "2026-1014", struct(), Label="evaluation");
            lastwarn("");
            warnState = warning("off", "resultDir:folderExists");
            testCase.addTeardown(@() warning(warnState));
            resultDir(testCase.root, "grooveTracking", "2026-1014", struct(), Label="evaluation");
            msg = string(lastwarn);
            testCase.verifySubstring(msg, "2026-1014_evaluation");
            testCase.verifySubstring(msg, "2026-1014_evaluation_2");
        end

        function testDateErrors(testCase)
            testCase.verifyError(@() resultDir(testCase.root, "grooveTracking", "YYYY-MMDD", struct()), ...
                "resultDir:dateNotSet");
            for d = ["1028", "2026-1328", "2026-0230", "2026-0229", "20261124", "2026-1124 "]
                testCase.verifyError(@() resultDir(testCase.root, "grooveTracking", d, struct()), ...
                    "resultDir:invalidDate", "日付 """ + d + """");
            end
            % うるう年の 2 月 29 日は暦にある
            outDir = resultDir(testCase.root, "grooveTracking", "2028-0229", struct());
            testCase.verifyTrue(isfolder(outDir));
            testCase.verifyFalse(isfolder(fullfile(testCase.root, "results", "grooveTracking", "2026-1328")));
        end

        function testExperimentAndLabelErrors(testCase)
            for e = ["figures", "MultiGroove", "multi-groove", "multi_groove", ""]
                testCase.verifyError(@() resultDir(testCase.root, e, "2026-1124", struct()), ...
                    "resultDir:invalidExperiment", "実験名 """ + e + """");
            end
            for lb = ["a b", "hist_2", "hist__5", "_hist5", "hist5_", "hist.5"]
                testCase.verifyError(@() resultDir(testCase.root, "grooveTracking", "2026-1124", struct(), ...
                    Label=lb), "resultDir:invalidLabel", "説明 """ + lb + """");
            end
            % 数字で始まっても、数字だけでなければ使える（mapping-draft.md の 2026-0924_1cycle）
            outDir = resultDir(testCase.root, "bilateralFilter", "2026-0924", struct(), Label="1cycle_photoshop8x");
            testCase.verifyTrue(endsWith(outDir, "2026-0924_1cycle_photoshop8x" + filesep));
            testCase.verifyFalse(isfolder(fullfile(testCase.root, "results", "figures")));
        end

        function testReturnedRunInfoMatchesFile(testCase)
            cond = runConditions(LMask=20, Upsampling="origD", Methods="centroid", DThresh=0.6);
            [outDir, info] = resultDir(testCase.root, "grooveTracking", "2026-1124", cond, ...
                Label="check", ScriptName="", Images=["a";"b"], Note="メモ");
            fromFile = jsondecode(fileread(fullfile(outDir, "runInfo.json"), Encoding="UTF-8"));
            testCase.verifyEqual(string(fieldnames(info))', string(fieldnames(fromFile))');
            testCase.verifyEqual(info.schemaVersion, 1);
            testCase.verifyEqual(info.run, "2026-1124_check");
            testCase.verifyEqual(info.note, "メモ");
            testCase.verifyEqual(string(fromFile.inputs.images), ["a";"b"]);
            testCase.verifyEqual(fromFile.conditions.segmentation.lMask, 20);
            testCase.verifyEqual(string(fromFile.conditions.upsampling.kind), "origD");
        end

        function testEmptyInputsAreEmptyArrays(testCase)
            [outDir, info] = resultDir(testCase.root, "grooveTracking", "2026-1124", struct(), InputFiles="");
            txt = fileread(fullfile(outDir, "runInfo.json"), Encoding="UTF-8");
            testCase.verifyEmpty(info.inputs.images);
            testCase.verifyEmpty(info.inputs.files, """"" の入力ファイルが除かれていない");
            testCase.verifyNotEmpty(regexp(txt, '"images":\s*\[\s*\]', "once"), "空の images が [] になっていない");
            testCase.verifyNotEmpty(regexp(txt, '"files":\s*\[\s*\]', "once"), "空の files が [] になっていない");
        end

        function testRelativePathBoundaries(testCase)
            % ルートの下のパスだけを相対パスにする。名前がルートで始まる隣のフォルダは変えない。
            % / で書いたパスも、cell の中のパスも同じに扱う
            sibling = testCase.root + "Extra" + filesep + "x.mat";
            slashed = replace(testCase.root, "\", "/") + "/experiments/2026-1014/a.mat";
            other = struct("inputs", {{fullfile(testCase.root, "data", "pictures", "p.png"), "plain text"}}, ...
                "sibling", sibling, "slashed", slashed, "number", 3);
            cond = struct("other", other);
            [~, info] = resultDir(testCase.root, "grooveTracking", "2026-1124", cond, ...
                InputFiles=[slashed; sibling]);
            testCase.verifyEqual(info.conditions.other.inputs{1}, "data/pictures/p.png");
            testCase.verifyEqual(info.conditions.other.inputs{2}, "plain text");
            testCase.verifyEqual(info.conditions.other.sibling, sibling, "ルートの外のパスを書き換えた");
            testCase.verifyEqual(info.conditions.other.slashed, "experiments/2026-1014/a.mat");
            testCase.verifyEqual(info.conditions.other.number, 3);
            testCase.verifyEqual(string(info.inputs.files), ["experiments/2026-1014/a.mat", sibling]);
        end

        function testScriptPathCandidates(testCase)
            % 2つ以上見つかれば、名前だけを書いて警告する。archive の中は数えない
            for d = ["scripts/a", "scripts/b", "scripts/archive", "scripts/paper/x/archive"]
                folder = fullfile(testCase.root, d);
                mkdir(folder);
                writelines("x = 1;", fullfile(folder, "dupScript.m"));
            end
            writelines("x = 1;", fullfile(testCase.root, "scripts", "paper", "x", "archive", "arcOnly.m"));
            [~, info] = testCase.verifyWarning(@() resultDir(testCase.root, "grooveTracking", "2026-1124", ...
                struct(), ScriptName="dupScript"), "resultDir:scriptNotFound");
            testCase.verifyEqual(info.script, "dupScript.m");
            [~, info2] = testCase.verifyWarning(@() resultDir(testCase.root, "grooveTracking", "2026-1125", ...
                struct(), ScriptName="arcOnly"), "resultDir:scriptNotFound");
            testCase.verifyEqual(info2.script, "arcOnly.m");
        end

        function testMetaValues(testCase)
            [~, info] = resultDir(testCase.root, "grooveTracking", "2026-1124", struct());
            m = info.meta;
            testCase.verifyEqual(string(fieldnames(m))', ["createdAt","git","matlabRelease","computerName"]);
            testCase.verifyEqual(m.matlabRelease, "R" + string(version("-release")));
            created = datetime(m.createdAt, "InputFormat", "yyyy-MM-dd'T'HH:mm:ss");
            testCase.verifyLessThan(abs(seconds(datetime("now") - created)), 60);
            testCase.verifyClass(m.git.commit, "string");
            testCase.verifyClass(m.git.branch, "string");
            testCase.verifyClass(m.git.dirty, "logical");
        end

        function testUnencodableValueCreatesNothing(testCase)
            cond = struct("other", struct("f", @sin));
            testCase.verifyError(@() resultDir(testCase.root, "grooveTracking", "2026-1124", cond), ?MException);
            testCase.verifyFalse(isfolder(fullfile(testCase.root, "results")), ...
                "JSON にできない値で止まったのに、results/ を作った");
        end
    end
end
