% wideBottomOutlierWaveform.m
% 進捗報告用。issue #35 の素材 M1。
% 溝底区間の幅の上限を直す前（8 px）の1周分のデータ（1014）で、従来法（manual。pkCentroid_1cycle.m。
% 区間ごとにクリックで溝を選ぶ）と自動追跡（track。grooveTrack_1cycle.m。写真ごとに溝を自動で追跡する）の
% 音声（重心法）の波形を、時間 T_WINDOW で重ね、results/figures/progress/grooveBottomDetection/ に保存する。
% 自動追跡の音声の 715.4 ms 付近に出た、振幅が1を超える鋭い外れ値を示すため。
% scripts/progress/waveformManualVsTrack.m（2026/11/09）の 710-720 ms の図と同じ中身を、今の図のルール
% （docs/rules/figures.md）の名前・タイトル・凡例で作り直したもの。元のスクリプトは、名前を本文で組み立てて
% いて、前に作った図を作り直せるように変えずに残した。元の図との違いは、名前・タイトル・凡例の表記、
% 時間の軸を ms にしたこと、振幅のピークが見切れないように y の範囲に余白を取ったこと、saveFigure で
% 保存したことである。線は全時間を描き、表示する範囲だけを切り出す（fig を開いたときに前後も見られる）。
% experiments/ は読むだけで、何も保存しない。
%
% 前提：Research.prj を開いていること。
% 2026/11/23作成

setDefaultIntrpr();
proj = currentProject();
rootFolder = proj.RootFolder;

%% パラメータ
DATE = "1014";          % 読み込む結果の日付（experiments/<DATE>/）
UPSAMPLING = "origD";   % 高解像度化（自動追跡は origD だけ）
BOUND = "inclBound";    % 溝底の判定。1014 のデータは2つとも ad46b44 以降のコード（3261e62）で作ったので、
                        % 境界値を含める判定（meta.gitCommit で確かめた）
METHOD = "centroid";    % 溝底の抽出法（この素材は重心法だけ）
W_BEFORE = 8;           % 読み込む結果の溝底区間の幅の上限 [px]（直す前の値。conditions.wTh と照らす）
T_WINDOW = [710 720];   % 表示する時間 [ms]（元の図と同じ）
Y_MARGIN = 0.05;        % 振幅の範囲の余白。範囲は ±(表示する時間の中の |振幅| の最大 + 余白) を 0.1 単位に切り上げる
FIG_SIZE = [14.8 11.1]; % 図の大きさ [cm]（元の図と同じ）
LEGEND_LOCATION = "northeast"; % 凡例の位置（元の図と同じ。波形にかぶってもよい）
OVERWRITE = false;      % 同じ名前の図を上書きするか（作り直すときだけ true にする）

THEME = "grooveBottomDetection";
saveDir = fullfile(rootFolder,"results","figures","progress",THEME);
if ~isfolder(saveDir)
    mkdir(saveDir);
end

% タイトル・凡例の表記（docs/rules/figures.md の語彙表の「表記」の列）
LABEL = struct("origD","original","inclBound","inclusive bounds","centroid","centroid", ...
    "manual","manual","track","tracking");

%% 読み込み
expDir = experimentDir(rootFolder,DATE,Create=false);
results = struct();
results.manual = loadCycleResult(fullfile(expDir,"cycleResult_" + UPSAMPLING + "_" + DATE + ".mat"));
results.track = loadCycleResult(fullfile(expDir,"cycleResult_" + UPSAMPLING + "_track_" + DATE + ".mat"));
for sel = ["manual","track"]
    r = results.(sel);
    fprintf("%s：commit %s、gitDirty %d、スクリプト %s、wTh %g\n", ...
        sel,r.meta.gitCommit,r.meta.gitDirty,r.meta.scriptName,r.conditions.wTh);
    if r.conditions.wTh ~= W_BEFORE
        error("wideBottomOutlierWaveform:widthThreshMismatch", ...
            "%s の幅の上限（%g）が、W_BEFORE（%g）と違います。",sel,r.conditions.wTh,W_BEFORE);
    end
end
audioManual = results.manual.(METHOD).audio;
audioTrack = results.track.(METHOD).audio;
if audioManual.fs ~= audioTrack.fs || numel(audioManual.signal) ~= numel(audioTrack.signal)
    error("wideBottomOutlierWaveform:audioMismatch", ...
        "manual と track で、サンプリング周波数かサンプルの数が違います。");
end
fs = audioManual.fs;
tMs = (1:numel(audioManual.signal))'/fs*1e3; % AudioData.plotWaveform と同じ時刻（ms にした）

%% 表示する時間の中の、振幅の最大
inWin = tMs >= T_WINDOW(1) & tMs <= T_WINDOW(2);
idxWin = find(inWin);
yAbsMax = 0;
for sel = ["manual","track"]
    sig = results.(sel).(METHOD).audio.signal;
    [v,iMax] = max(abs(sig(inWin)));
    fprintf("%s：%d-%d ms の |振幅| の最大 %.4f（%.2f ms）、|振幅| > 1 のサンプル %d\n", ...
        sel,T_WINDOW,v,tMs(idxWin(iMax)),nnz(abs(sig(inWin)) > 1));
    yAbsMax = max(yAbsMax,v);
end
yLim = ceil((yAbsMax + Y_MARGIN)*10)/10;

%% 図
fig = createFigure([0 0 FIG_SIZE]);
tl = tiledlayout(fig,1,1,Padding="compact");
ax = nexttile(tl);
plot(ax,tMs,audioManual.signal);
hold(ax,"on");
plot(ax,tMs,audioTrack.signal);
hold(ax,"off");
xlim(ax,T_WINDOW);
ylim(ax,[-yLim yLim]);
xlabel(ax,"Time [ms]");
ylabel(ax,"Amplitude");
% タイトルは図の幅に収まらないので2行に分ける
title(ax,["Waveform: " + LABEL.manual + " vs " + LABEL.track, ...
    "(" + LABEL.(UPSAMPLING) + ", " + LABEL.(BOUND) + ", " + LABEL.(METHOD) + ", data " + DATE + ...
    sprintf(", %d-%d ms)",T_WINDOW)]);
lgd = legend(ax,[LABEL.manual, LABEL.track],Location=LEGEND_LOCATION);
lgd.ItemHitFcn = @togglevisibility;
saveFigure(fig,saveDir,"waveform_manualVsTrack_" + UPSAMPLING + "_" + BOUND + "_" + METHOD + "_" + DATE + ...
    sprintf("_%d-%dms",T_WINDOW),Overwrite=OVERWRITE);
close(fig);
