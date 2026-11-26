function meta = collectMeta(scriptName, opts)
% collectMeta  実行した環境（日時・スクリプト名・MATLAB の版・PC・git）の情報を集める。
%
% どのコードで作った結果かを後から特定するため、saveCycleResult は cycleResult の
% result.meta に、resultDir は runInfo.json の meta に、この出力を使う。
% git の情報は、MATLAB プロジェクトのルート（開いていなければ今のフォルダ）で調べる。
%
% 使い方:
%   meta = collectMeta(conditions.scriptName);                  % saveCycleResult
%   meta = collectMeta("grooveHist_Ncycle", IncludeBranch=true); % resultDir
%
% name-value 引数:
%   IncludeBranch - true なら meta.gitBranch（今のブランチ）を最後に足す（既定: false）。
%                   saveCycleResult は渡さないので、保存する meta の形は変わらない
%
% 出力 meta のフィールド（この順）:
%   savedAt (datetime), scriptName, matlabRelease（例 "2024b"）, matlabVersion,
%   computerName, rootFolder, gitCommit, gitDirty, gitBranch（IncludeBranch=true のときだけ）
%
% 関連: gitState, saveCycleResult, resultDir

    arguments
        scriptName (1,1) string
        opts.IncludeBranch (1,1) logical = false
    end

    meta = struct();
    meta.savedAt        = datetime("now");
    meta.scriptName     = scriptName;
    meta.matlabRelease  = string(version("-release"));
    meta.matlabVersion  = string(version);
    meta.computerName   = string(getenv("COMPUTERNAME"));

    try
        rootFolder = string(currentProject().RootFolder);
    catch
        rootFolder = string(pwd);
    end
    meta.rootFolder = rootFolder;

    if opts.IncludeBranch
        [meta.gitCommit, meta.gitDirty, meta.gitBranch] = gitState(rootFolder);
    else
        [meta.gitCommit, meta.gitDirty] = gitState(rootFolder);
    end
end
