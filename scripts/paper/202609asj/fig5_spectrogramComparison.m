% fig5_spectrogramComparison.m
% 音響学会2026年9月 原稿用のFigure 5（2枚で1段=79mm）
% origD(アップサンプリングなし)から局所的最大値法・重心法で作成した音声の
% スペクトログラムを、それぞれ別のfigureとして保存する
% カラーバーは右に置く重心法の図にのみ付ける（clim は2枚とも同じ）
%
% 音声はAudioDataオブジェクトとして.matファイルから読み込む
% .matが未作成の場合は、1周分の音声を作成して以下の変数名で保存しておくこと
%   VAR_MAX: 局所的最大値法のAudioData
%   VAR_CNT: 重心法のAudioData

setDefaultIntrpr();

proj = currentProject();
saveDir = fullfile(proj.RootFolder,"results","figures","paper","202609asj");
if ~isfolder(saveDir)
    mkdir(saveDir);
end

%% パラメータ
% 音声データの.matファイル（実際の保存先に合わせて変更する）
MAT_FILE = fullfile(proj.RootFolder,"results","audio","audio_orig.mat");
VAR_MAX = "audio_max"; % 局所的最大値法のAudioData
VAR_CNT = "audio_cnt"; % 重心法のAudioData

WIN_SIZE = 8192; % stftの窓長。fsが大きいので長めにとる
F_VIEW = [0 5e3];  % 表示する周波数の範囲[Hz]
C_VIEW = [-120 0]; % 表示するレベルの範囲[dB]

% 図のサイズ[cm]とフォントサイズ[pt]（1段=79mmを2枚で分ける）
% 右の図はカラーバーのぶんだけ広くとり、プロット面の大きさを左右でそろえる
FIG_W_MAX = 3.4; % 局所的最大値法（カラーバーなし）
FIG_W_CNT = 4.4; % 重心法（カラーバーあり）
FIG_H = 3.4;
FONT_TICK = 8; FONT_LABEL = 9;

%% 音声データを読み込む
if ~isfile(MAT_FILE)
    error("音声データの.matが見つかりません: %s\n" + ...
        "1周分の音声を作成し、%s と %s という変数名で保存してから実行してください。", ...
        MAT_FILE,VAR_MAX,VAR_CNT);
end

S = load(MAT_FILE);
for varName = [VAR_MAX VAR_CNT]
    if ~isfield(S,varName)
        error("%s に変数 %s がありません。",MAT_FILE,varName);
    end
end

audioCell = {S.(VAR_MAX), S.(VAR_CNT)};
figNames = ["fig5-1_spectrogramLocalMax", "fig5-2_spectrogramCentroid"];
figWidths = [FIG_W_MAX, FIG_W_CNT];
showColorbar = [false, true];

%% 描画
% カラーバーはTightInsetに含まれないので、tiledlayoutのPadding="tight"に
% 余白を任せる（カラーバーをレイアウトに置くと、そのぶんの余白が確保される）
for k = 1:numel(audioCell)
    fig = createFigure([0 0 figWidths(k) FIG_H]);
    t = tiledlayout(fig,1,1,"TileSpacing","tight","Padding","tight");
    ax = nexttile(t);

    % 原稿ではキャプションを付けるので図中のタイトルは出さない
    audioCell{k}.spectrogramPlot(WIN_SIZE, ...
        ShowTitle=false,ShowColorbar=showColorbar(k));

    ylim(ax,F_VIEW); clim(ax,C_VIEW);

    % 38mm幅では"Frequency [Hz]"と10^3の指数表示が場所を取るのでkHz表記にする
    ax.YAxis.Exponent = 0;
    yticks(ax,0:1e3:F_VIEW(2));
    yticklabels(ax,string((0:1e3:F_VIEW(2))/1e3));
    xlabel(ax,"$t$ [s]"); ylabel(ax,"$f$ [kHz]");

    if showColorbar(k)
        c = ax.Colorbar;
        c.Layout.Tile = "east";
        c.Label.String = ""; % 縦に長いラベルは入らないのでキャプションで説明する
        c.Ticks = C_VIEW(1):60:C_VIEW(2);
        c.FontSize = FONT_TICK;
    end

    % フォントサイズ（原稿に等倍で貼る前提）
    ax.FontSize = FONT_TICK;
    ax.LabelFontSizeMultiplier = 1; % 既定の1.1倍を無効にして明示指定を効かせる
    ax.XLabel.FontSize = FONT_LABEL;
    ax.YLabel.FontSize = FONT_LABEL;

    % スペクトログラムはベクタにすると重いのでpdfもラスタで書き出す
    savePaperFigure(fig,saveDir,figNames(k),figWidths(k),FIG_H, ...
        ContentType="image");
end
