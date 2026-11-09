% waveformManualVsTrack.m
% 進捗報告用。1本の溝から作った1周分の音声の波形を、溝の選び方で比べる図を作る。
%   manual: 手動選択（pkCentroid_1cycle.m）   experiments/<DATE>/cycleResult_origD_<DATE>.mat
%   track : 自動追跡（grooveTrack_1cycle.m）  experiments/<DATE>/cycleResult_origD_track_<DATE>.mat
% どちらも高解像度化なし（origD）の重心法（centroid）の音声（result.centroid.audio）を使う。
% 全時間の図1枚と、時間を切り出した図（T_WINDOWS）を、png と fig の両方で
% results/figures/progress/grooveTracking/ に保存する。凡例をクリックすると線の表示を切り替えられる
% （togglevisibility）。
%
% 前提：Research.prj を開いていること。
% 2026/11/09作成

setDefaultIntrpr();
proj = currentProject();
rootFolder = proj.RootFolder;

%% パラメータ
DATE = "1014";      % 読み込む結果の日付（experiments/<DATE>/）
METHOD = "centroid"; % 溝底の抽出法（"centroid" または "localMax"）

Y_VIEW_FULL = [-1 1];              % 全時間の図のAmplitudeの範囲
T_WINDOWS = [0 0.020; 0.590 0.630; 0.710 0.720]; % 切り出す時間[s]（1行が1枚）

FIG_SIZE = [14.8 11.1]; % 図の大きさ[cm]（以前の図 compare_..._track_and_manual.fig と同じ）
RESOLUTION = 300;       % pngの解像度[dpi]

saveDir = fullfile(rootFolder,"results","figures","progress","grooveTracking");
if ~isfolder(saveDir)
    mkdir(saveDir);
end

%% 読み込み
manualPath = cycleResultPath(rootFolder,"origD",DATE);
trackPath = fullfile(experimentDir(rootFolder,DATE,Create=false), ...
    "cycleResult_origD_track_" + DATE + ".mat");
manual = loadCycleResult(manualPath);
track = loadCycleResult(trackPath);

audioManual = manual.(METHOD).audio;
audioTrack = track.(METHOD).audio;
if audioManual.fs ~= audioTrack.fs
    error("waveformManualVsTrack:fsMismatch", ...
        "manualとtrackでサンプリング周波数が違います（%g Hz と %g Hz）。", ...
        audioManual.fs, audioTrack.fs);
end
fs = audioManual.fs;
tManual = (1:numel(audioManual.signal))' / fs; % AudioData.plotWaveformと同じ時刻
tTrack = (1:numel(audioTrack.signal))' / fs;

% ファイル名：比べたもの（manualとtrack）・抽出法・高解像度化の有無・データの日付
baseName = "waveform_manualVsTrack_" + METHOD + "_origD_" + DATE;
titleStr = "manual vs track (" + METHOD + ", origD, date:" + DATE + ")";

%% 全時間の図
[fig,ax] = plotManualVsTrack(tManual,audioManual.signal,tTrack,audioTrack.signal,FIG_SIZE,titleStr);
axis(ax,"tight");
ylim(ax,Y_VIEW_FULL);
saveBoth(fig,saveDir,baseName + "_full",RESOLUTION);

%% 時間を切り出した図
% 線は全時間を描いたまま、表示範囲だけを切り出す（figを開いたときに前後も見られる）。
% yの範囲は、切り出した時間の中のデータに合わせ、y=0が中央になるよう上下対称にする
for iWin = 1:size(T_WINDOWS,1)
    tWin = T_WINDOWS(iWin,:);
    [fig,ax] = plotManualVsTrack(tManual,audioManual.signal,tTrack,audioTrack.signal,FIG_SIZE,titleStr);
    axis(ax,"tight");
    xlim(ax,tWin);

    inWinManual = tManual >= tWin(1) & tManual <= tWin(2);
    inWinTrack = tTrack >= tWin(1) & tTrack <= tWin(2);
    yAbsMax = max(abs([audioManual.signal(inWinManual); audioTrack.signal(inWinTrack)]));
    ylim(ax,[-yAbsMax yAbsMax]);

    winName = sprintf("_%g-%gms",round(tWin(1)*1e3),round(tWin(2)*1e3));
    saveBoth(fig,saveDir,baseName + winName,RESOLUTION);
end


%% ローカル関数
function [fig,ax] = plotManualVsTrack(tManual,yManual,tTrack,yTrack,figSize,titleStr)
% manualとtrackの波形を重ねて描く。凡例のクリックで線の表示を切り替えられるようにする
    fig = createFigure([0 0 figSize]);
    ax = axes(fig);
    plot(ax,tManual,yManual,DisplayName="manual");
    hold(ax,"on");
    plot(ax,tTrack,yTrack,DisplayName="track");
    hold(ax,"off");
    xlabel(ax,"$t$ [s]");
    ylabel(ax,"Amplitude");
    title(ax,titleStr);
    lgd = legend(ax,Location="northeast"); % プロット領域内（波形にかぶってもよい）
    lgd.ItemHitFcn = @togglevisibility;
end

function saveBoth(fig,saveDir,name,resolution)
% pngとfigの両方で保存する
    exportgraphics(fig,fullfile(saveDir,name + ".png"),Resolution=resolution);
    savefig(fig,fullfile(saveDir,name + ".fig"));
    fprintf("保存：%s（.png / .fig）\n",fullfile(saveDir,name));
end
