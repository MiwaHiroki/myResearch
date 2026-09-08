% stylusPlayback.m (スライド用)
% 音響学会2026年9月 スライド用
% data/stylus_playback/StylusPlayback(wa)(highpass).wavを読み込み
% 各音声の波形とスペクトログラムを
% 1図1ファイルのpngとして書き出す（計2枚）

%%
setDefaultIntrpr();

proj = currentProject();
saveDir = fullfile(proj.RootFolder,"results","figures","slides","202609asj");
if ~isfolder(saveDir)
    mkdir(saveDir);
end

%% パラメータ
% 読み込む音声
STYLUS_NAME = "stylus"; % 表示・ログ用の名前
STYLUS_FILENAME = "StylusPlayback(wa)(highpass)" + ".wav"; % 読み込むファイルの名前
stylusDir = fullfile(proj.RootFolder, "data", "stylus_playback", STYLUS_FILENAME);

% 読み込む音声のサンプリング周波数は44.1kHz
% --> だいたいorigDから作成した音声のサンプリング周波数に近いので窓も同じ長さで
WIN_SIZE = 1024;

F_VIEW_5k = [0 5e3];  % 表示する周波数の範囲[Hz]
F_VIEW_20k = [0 2e4];  % 20kHzまで表示する場合
C_VIEW = [-120 0]; % 表示するレベルの範囲[dB]
C_STEP = 30;       % カラーバーの目盛り間隔[dB]
T_STEP = 0.2;      % 時間軸の目盛り間隔[s]
Y_VIEW = [-1 1];   % 表示するAmplitudeの範囲

% 図のサイズ[cm]とフォントサイズ[pt]（スライド用の標準値）
% 波形表示figure、スペクトログラム表示figureの大きさ
FIG_W = [9, 8] ; FIG_H = [6, 10];
FONT_TICK = 14; FONT_LABEL = 16;

%% 音声データを読み込む
[y, fs] = audioread(stylusDir);
audio = AudioData(STYLUS_NAME, y, fs);
% どの音声を読んだかを残す（保存時に手法を取り違えていないかの確認用）

fprintf("%s: name=""%s"", fs=%d Hz\n", ...
    STYLUS_NAME, STYLUS_FILENAME, fs);

%% 描画・保存（音声ごとに波形・スペクトログラムを別ファイルにする）

% 波形
fig = createFigure([0 0 FIG_W(1) FIG_H(1)]);
ax = gca;
audio.plotWaveform();

% 右端はデータのあるところまでに詰める。左端は0のままにしないと
% xticksの0が範囲外になって表示されない
tData = findobj(ax,"Type","line").XData;
xlim(ax,[0 max(tData(:))]);
ylim(ax,Y_VIEW);

xticks(ax,0:T_STEP:max(xlim(ax)));
ax.TickLabelInterpreter = "latex";
box(ax,"on");

% plotWaveformは強制的にタイトルを付けるのでスライド用に消す
title(ax,"");
xlabel(ax,"Time [s]"); ylabel(ax,"Amplitude");

ax.FontSize = FONT_TICK;
ax.XLabel.FontSize = FONT_LABEL;
ax.YLabel.FontSize = FONT_LABEL;

saveSlideFigure(fig,saveDir,STYLUS_NAME+"_waveform",FIG_W(1),FIG_H(1));


% スペクトログラム1: ylimが5kHzまで（カラーバーは図ごとに必須）
% tiledlayout+Padding="tight"でカラーバー分の余白を確保する。単体axesの
% 自動レイアウトはfigureを縮めるとカラーバーのラベルが見切れることがある
fig = createFigure([0 0 FIG_W(2) FIG_H(2)]);
t = tiledlayout(fig,1,1,"Padding","tight");
ax = nexttile(t); % plotSpectrogramはgcaに描くのでnexttileを先に呼ぶ
audio.plotSpectrogram(WIN_SIZE,ShowTitle=false,ShowColorbar=false);

tData = findobj(ax,"Type","surface").XData;
xlim(ax,[0 max(tData(:))]);
ylim(ax,F_VIEW_5k); clim(ax,C_VIEW);

ax.YAxis.Exponent = 3;
yticks(ax,F_VIEW_5k(1):1e3:F_VIEW_5k(2));
xticks(ax,0:T_STEP:max(xlim(ax)));
ax.TickLabelInterpreter = "latex";
box(ax,"on");

xlabel(ax,"Time [s]"); ylabel(ax,"Frequency [Hz]");
ax.FontSize = FONT_TICK;
ax.XLabel.FontSize = FONT_LABEL;
ax.YLabel.FontSize = FONT_LABEL;

% c = colorbar(ax);
% c.Layout.Tile = "east";
% c.Ticks = C_VIEW(1):C_STEP:C_VIEW(2);
% c.FontSize = FONT_TICK;
% c.TickLabelInterpreter = "latex";
% c.Label.String = "Magnitude [dB]";
% c.Label.Interpreter = "latex";
% c.Label.FontSize = FONT_LABEL;

saveSlideFigure(fig,saveDir,STYLUS_NAME+"_spectrogram_noColorbar_5kHz",FIG_W(2),FIG_H(2));


% スペクトログラム2: ylimが20kHzまで（カラーバーは図ごとに必須）
% tiledlayout+Padding="tight"でカラーバー分の余白を確保する。単体axesの
% 自動レイアウトはfigureを縮めるとカラーバーのラベルが見切れることがある
fig = createFigure([0 0 FIG_W(2) FIG_H(2)]);
t = tiledlayout(fig,1,1,"Padding","tight");
ax = nexttile(t); % plotSpectrogramはgcaに描くのでnexttileを先に呼ぶ
audio.plotSpectrogram(WIN_SIZE,ShowTitle=false,ShowColorbar=false);

tData = findobj(ax,"Type","surface").XData;
xlim(ax,[0 max(tData(:))]);
ylim(ax,F_VIEW_20k); clim(ax,C_VIEW);

ax.YAxis.Exponent = 3;
yticks(ax,F_VIEW_20k(1):5e3:F_VIEW_20k(2)); % F_VIEWが20kHzまでのとき
xticks(ax,0:T_STEP:max(xlim(ax)));
ax.TickLabelInterpreter = "latex";
box(ax,"on");

xlabel(ax,"Time [s]"); ylabel(ax,"Frequency [Hz]");
ax.FontSize = FONT_TICK;
ax.XLabel.FontSize = FONT_LABEL;
ax.YLabel.FontSize = FONT_LABEL;

% c = colorbar(ax);
% c.Layout.Tile = "east";
% c.Ticks = C_VIEW(1):C_STEP:C_VIEW(2);
% c.FontSize = FONT_TICK;
% c.TickLabelInterpreter = "latex";
% c.Label.String = "Magnitude [dB]";
% c.Label.Interpreter = "latex";
% c.Label.FontSize = FONT_LABEL;

saveSlideFigure(fig,saveDir,STYLUS_NAME+"_spectrogram_noColorbar_20kHz",FIG_W(2),FIG_H(2));
