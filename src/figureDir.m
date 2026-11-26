function saveDir = figureDir(rootFolder, purpose, name)
% figureDir  完成した図の置き場所を作り、そのパスを返す。
%
% 図のスクリプトが保存先を組み立てる4行（fullfile と mkdir）を1行にし、置き場所の
% 決まり（docs/rules/figures.md）をここだけに持たせる。図のフォルダは完成品の置き場所
% なので、日付で分けず、実行記録も作らない（実験の出力は resultDir を使う）。
%
%   進捗報告用         results/figures/progress/<テーマ>       （git で追跡）
%   スライド用・原稿用 results/figures/<発表名>/{slides,paper} （slides だけ git で追跡）
%
% 使い方:
%   saveDir = figureDir(rootFolder, "progress", THEME);         % THEME = "grooveTracking"
%   saveDir = figureDir(rootFolder, "slides", "202609asj");
%   saveDir = figureDir(rootFolder, "paper", "202609asj");
%
% 入力:
%   rootFolder - プロジェクトのルート（currentProject().RootFolder）
%   purpose    - "progress"・"slides"・"paper"
%   name       - 進捗報告用はテーマ（camelCase。例 "grooveTracking"）、スライド用・原稿用は
%                発表名（年月6桁と略称。例 "202609asj"、"202702thesis"）
%
% 出力:
%   saveDir - フォルダの絶対パス（string）。今の図のスクリプトの saveDir と同じく、
%             末尾に区切り文字を付けない（fullfile(saveDir, ...) で使う）
%
% エラー:
%   figureDir:invalidTheme  進捗報告用のテーマが camelCase でない
%   figureDir:invalidVenue  発表名が「年月6桁と略称」の形でない
%
% 関連: resultDir, saveFigure, saveSlideFigure, savePaperFigure

    arguments
        rootFolder (1,1) string
        purpose (1,1) string {mustBeMember(purpose,["progress","slides","paper"])}
        name (1,1) string
    end

    figRoot = fullfile(rootFolder, "results", "figures");
    if purpose == "progress"
        if isempty(regexp(name, "^[a-z][a-zA-Z0-9]*$", "once"))
            error("figureDir:invalidTheme", ...
                "進捗報告用の図のテーマ ""%s"" は camelCase にしてください（例 ""grooveTracking""）。", name);
        end
        saveDir = fullfile(figRoot, "progress", name);
    else
        if isempty(regexp(name, "^\d{6}[a-z]+$", "once"))
            error("figureDir:invalidVenue", ...
                "発表名 ""%s"" は、年月6桁と小文字の略称をつなげてください（例 ""202609asj""）。", name);
        end
        saveDir = fullfile(figRoot, name, purpose);
    end

    if ~isfolder(saveDir)
        mkdir(saveDir);
    end
    saveDir = string(saveDir);
end
