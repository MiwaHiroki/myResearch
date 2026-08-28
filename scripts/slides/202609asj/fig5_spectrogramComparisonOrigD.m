% fig5_spectrogramComparisonOrigD.m (スライド用)
% 音響学会2026年9月 スライド用
% scripts/paper/202609asj/fig5_spectrogramComparisonOrigD.mと同じデータ
% (origD、局所的最大値法・重心法)を使い、各音声の波形とスペクトログラムを
% 1図1ファイルのpngとして書き出す（計4枚）
% スライド用の図の様式はmemory: slide-figure-size / slide-figure-dirs を参照
% （tiledlayoutでまとめない、タイトル無し、カラーバーは図ごとに必須、pngのみ保存）

setDefaultIntrpr();

proj = currentProject();
saveDir = fullfile(proj.RootFolder,"results","figures","slides","202609asj");
if ~isfolder(saveDir)
    mkdir(saveDir);
end

%% パラメータ
% 読み込む結果.mat（experiments/<日付>/cycleResult_<条件>_<日付>.mat）
DATE = "0731";
UPSAMPLING = "origD";

WIN_SIZE = 1024;   % stftの窓長
F_VIEW = [0 5e3];  % 表示する周波数の範囲[Hz]
C_VIEW = [-120 0]; % 表示するレベルの範囲[dB]
C_STEP = 30;       % カラーバーの目盛り間隔[dB]
T_STEP = 0.2;      % 時間軸の目盛り間隔[s]
Y_VIEW = [-1 1];   % 表示するAmplitudeの範囲

% 図のサイズ[cm]とフォントサイズ[pt]（スライド用の標準値）
FIG_W = 12; FIG_H = 8;
FONT_TICK = 14; FONT_LABEL = 16;

%% 音声データを読み込む
matPath = cycleResultPath(proj.RootFolder,UPSAMPLING,DATE);
result = loadCycleResult(matPath);

for methodName = ["localMax","centroid"]
    if ~isfield(result,methodName) || isempty(result.(methodName).audio)
        error("fig5:noAudio", ...
            "%s に %s の音声が入っていません。", matPath, methodName);
    end
end

audioCell = {result.localMax.audio, result.centroid.audio};
% ファイル名はスクリプト名から由来が分かるので接頭辞は付けず、
% 区別に必要な条件（upsampling=origD固定＋抽出手法）だけを名前にする
audioNames = ["origD_localMax","origD_centroid"];

%% 描画・保存（音声ごとに波形・スペクトログラムを別ファイルにする）
for k = 1:numel(audioCell)
    audio = audioCell{k};
    name = audioNames(k);

    % 波形
    fig = createFigure([0 0 FIG_W FIG_H]);
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

    saveSlideFigure(fig,saveDir,name+"_waveform",FIG_W,FIG_H);

    % スペクトログラム（カラーバーは図ごとに必須なのでShowColorbar=true）
    fig = createFigure([0 0 FIG_W FIG_H]);
    ax = gca;
    audio.plotSpectrogram(WIN_SIZE,ShowTitle=false,ShowColorbar=true);

    tData = findobj(ax,"Type","surface").XData;
    xlim(ax,[0 max(tData(:))]);
    ylim(ax,F_VIEW); clim(ax,C_VIEW);

    ax.YAxis.Exponent = 3;
    yticks(ax,F_VIEW(1):1e3:F_VIEW(2));
    xticks(ax,0:T_STEP:max(xlim(ax)));
    ax.TickLabelInterpreter = "latex";
    box(ax,"on");

    xlabel(ax,"Time [s]"); ylabel(ax,"Frequency [Hz]");
    ax.FontSize = FONT_TICK;
    ax.XLabel.FontSize = FONT_LABEL;
    ax.YLabel.FontSize = FONT_LABEL;

    c = colorbar(ax);
    c.Ticks = C_VIEW(1):C_STEP:C_VIEW(2);
    c.FontSize = FONT_TICK;
    c.TickLabelInterpreter = "latex";
    c.Label.String = "Magnitude [dB]";
    c.Label.Interpreter = "latex";
    c.Label.FontSize = FONT_LABEL;

    saveSlideFigure(fig,saveDir,name+"_spectrogram",FIG_W,FIG_H);
end
