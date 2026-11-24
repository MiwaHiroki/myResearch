function [commit, isDirty, branch] = gitState(rootFolder)
% gitState  git のコミット・作業ツリーの変更の有無・ブランチを返す。
%
% どのコードで作った結果かを後から特定するために、saveCycleResult と resultDir が
% 実行記録に書く（collectMeta から呼ばれる）。git が無い環境や、git のリポジトリでない
% フォルダでも保存自体は成功させたいので、失敗しても空の値（""・false・""）を返す。
%
% 使い方:
%   [commit, isDirty] = gitState(rootFolder);          % ブランチは調べない
%   [commit, isDirty, branch] = gitState(rootFolder);  % ブランチも調べる
%
% 出力:
%   commit  - HEAD のコミット（短い形。例 "c7d2460"）。取れなければ ""
%   isDirty - git status --porcelain が空でなければ true（未追跡のファイルも含む）
%   branch  - 今のブランチ（git rev-parse --abbrev-ref HEAD）。3つ目の出力を
%             求めたときだけ調べる。取れなければ ""
%
% 関連: collectMeta, saveCycleResult, resultDir

    arguments
        rootFolder (1,1) string
    end

    commit  = "";
    isDirty = false;
    branch  = "";
    try
        [status, out] = system(sprintf('git -C "%s" rev-parse --short HEAD', rootFolder));
        if status == 0
            commit = string(strtrim(out));
        end
        [status, out] = system(sprintf('git -C "%s" status --porcelain', rootFolder));
        if status == 0
            isDirty = ~isempty(strtrim(out));
        end
        if nargout >= 3
            [status, out] = system(sprintf('git -C "%s" rev-parse --abbrev-ref HEAD', rootFolder));
            if status == 0
                branch = string(strtrim(out));
            end
        end
    catch
        % git の情報は無くても構わない
    end
end
