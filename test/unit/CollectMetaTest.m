% collectMeta・gitState（実行した環境の情報）の単体テスト
%
% saveCycleResult のローカル関数から切り出したもの。フィールドの名前と順が切り出す前と
% 同じであること、git が使えない場所でもエラーにならないことを確かめる。
classdef CollectMetaTest < matlab.unittest.TestCase

    properties (Constant)
        % 切り出す前の saveCycleResult のローカル関数 collectMeta と同じ順
        META_FIELDS = ["savedAt","scriptName","matlabRelease","matlabVersion","computerName", ...
            "rootFolder","gitCommit","gitDirty"]
    end

    properties
        repoRoot   % このリポジトリのルート
    end

    methods (TestClassSetup)
        function addToPath(testCase)
            import matlab.unittest.fixtures.PathFixture
            thisDir = fileparts(mfilename('fullpath'));
            srcDir  = fullfile(thisDir, '..', '..', 'src');
            testCase.applyFixture(PathFixture(srcDir));
            testCase.repoRoot = string(fullfile(thisDir, '..', '..'));
        end
    end

    methods (Test)

        function testFieldsAndTypes(testCase)
            m = collectMeta("someScript");
            testCase.verifyEqual(string(fieldnames(m))', testCase.META_FIELDS);
            testCase.verifyClass(m.savedAt, "datetime");
            testCase.verifyEqual(m.scriptName, "someScript");
            testCase.verifyEqual(m.matlabRelease, string(version("-release")));
            testCase.verifyEqual(m.matlabVersion, string(version));
            for f = ["computerName","rootFolder","gitCommit"]
                testCase.verifyClass(m.(f), "string", f + " が string でない");
            end
            testCase.verifyClass(m.gitDirty, "logical");
        end

        function testIncludeBranch(testCase)
            m = collectMeta("someScript", IncludeBranch=true);
            testCase.verifyEqual(string(fieldnames(m))', [testCase.META_FIELDS "gitBranch"]);
            testCase.verifyClass(m.gitBranch, "string");
            m2 = collectMeta("someScript", IncludeBranch=false);
            testCase.verifyFalse(isfield(m2, "gitBranch"));
        end

        function testGitStateOutsideRepository(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture = testCase.applyFixture(TemporaryFolderFixture);
            [commit, isDirty] = gitState(fixture.Folder);
            testCase.verifyEqual(commit, "");
            testCase.verifyEqual(isDirty, false);
            [commit, isDirty, branch] = gitState(fixture.Folder);
            testCase.verifyEqual([commit, branch], ["", ""]);
            testCase.verifyFalse(isDirty);
        end

        function testGitStateInRepository(testCase)
            % このリポジトリの中では、コミットとブランチが取れる（git が無い環境では飛ばす）
            [status, out] = system(sprintf('git -C "%s" rev-parse --is-inside-work-tree', testCase.repoRoot));
            testCase.assumeTrue(status == 0 && strtrim(out) == "true", "git のリポジトリとして読めない");
            [commit, ~, branch] = gitState(testCase.repoRoot);
            testCase.verifyMatches(commit, "^[0-9a-f]{4,}$");
            testCase.verifyNotEqual(branch, "");
        end
    end
end
