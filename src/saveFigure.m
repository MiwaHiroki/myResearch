function files = saveFigure(fig, saveDir, name, opts)
% saveFigure  作業用・進捗用の図を、名前を確かめてから saveDir に png（と fig）で保存する。
%
% 保存の前に checkFigureName で名前を確かめ、命名規則（docs/rules/figures.md）から
% 外れていれば警告を出す（保存はする）。同じ名前のファイルがあれば、過去の結果を
% 消さないよう、保存せずにエラー saveFigure:fileExists を出す（Overwrite=true で上書き）。
% 図の大きさは変えない（作業用・進捗用は自由）。スライド用は saveSlideFigure、
% 原稿用は savePaperFigure を使う。
%
% 使い方:
%   saveFigure(fig, mkdirFromDate(rootFolder, date), "waveform_origD_centroid_track_1014");
%   saveFigure(fig, saveDir, name, SaveFig=false, Resolution=150);
%
% 戻り値 files は、保存したファイルのフルパス（string の列ベクトル。png、fig の順）。
%
% 関連: checkFigureName, saveSlideFigure, savePaperFigure

    arguments
        fig (1,1) matlab.ui.Figure
        saveDir (1,1) string
        name (1,1) string
        opts.Resolution (1,1) double {mustBePositive} = 300 % png の解像度 [dpi]
        opts.SaveFig (1,1) logical = true                     % fig も保存するか
        opts.Overwrite (1,1) logical = false                  % 同じ名前のファイルを上書きするか
    end

    checkFigureName(name);

    files = fullfile(saveDir, name + ".png");
    if opts.SaveFig
        files(end+1,1) = fullfile(saveDir, name + ".fig");
    end
    existing = files(isfile(files));
    if ~opts.Overwrite && ~isempty(existing)
        error("saveFigure:fileExists", ...
            "同じ名前のファイルがあるので保存しません（上書きするなら Overwrite=true）。\n%s", ...
            join(existing, newline));
    end

    exportgraphics(fig, files(1), Resolution=opts.Resolution);
    if opts.SaveFig
        savefig(fig, files(2));
    end
end
