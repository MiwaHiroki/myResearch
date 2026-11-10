% waveformTrackVsHist.m
% 進捗報告用。N本の溝（N周分）から作った音声の波形を、溝の選び方で比べる図を作る。
%   track: N本をそれぞれ自動追跡（grooveTrack_Ncycle.m）
%          experiments/<DATE>/cycleResult_<UPSAMPLING>_track<N>_<DATE>.mat
%   hist : 1本目だけ自動追跡し、2本目以降をヒストグラムで取り出す（grooveHist_Ncycle.m）
%          experiments/<DATE>/cycleResult_<UPSAMPLING>_hist<N>_<DATE>.mat
% 次の2枚を、重ねて描き（hist を上）、results/figures/progress/multiGroove/ に png と fig で保存する。
% 凡例をクリックすると線の表示を切り替えられる（togglevisibility）。
%   1. 全時間
%   2. |hist − track| が最大のサンプルの時刻を中心に、±T_HALF_WINDOW を切り出した図
%      （ヒストグラムを使ったことによる違いを見るため）
%
% 前提：Research.prj を開いていること。
% 2026/11/10作成

setDefaultIntrpr();
proj = currentProject();
rootFolder = proj.RootFolder;

%% パラメータ
DATE = "1104";        % 読み込む結果の日付（experiments/<DATE>/）
UPSAMPLING = "origD"; % 高解像度化（今は origD の結果だけがある）
METHOD = "centroid";  % 溝底の抽出法（"centroid" または "localMax"）
NUM_GROOVES = 5;      % 溝の本数（cycleResult_..._track<N>/_hist<N>_... の N）

Y_VIEW_FULL = [-1 1];   % 全時間の図のAmplitudeの範囲
T_HALF_WINDOW = 0.005;  % 切り出す時間の半分[s]（差が最大の時刻 ± これ）
FIG_SIZE = [14.8 11.1]; % 図の大きさ[cm]（waveformManualVsTrack.m の図と同じ）
OVERWRITE = true;       % 進捗報告用の図なので、作り直したときは上書きする

saveDir = fullfile(rootFolder,"results","figures","progress","multiGroove");
if ~isfolder(saveDir)
    mkdir(saveDir);
end

% タイトル・凡例の表記（docs/rules/figures.md の語彙表の「表記」の列）
LABEL = struct("origD","original","centroid","centroid","localMax","local maximum", ...
    "track","tracking","hist","histogram");

%% 読み込み
expDir = experimentDir(rootFolder,DATE,Create=false);
trackRes = loadCycleResult(fullfile(expDir, ...
    "cycleResult_" + UPSAMPLING + "_track" + NUM_GROOVES + "_" + DATE + ".mat"));
histRes = loadCycleResult(fullfile(expDir, ...
    "cycleResult_" + UPSAMPLING + "_hist" + NUM_GROOVES + "_" + DATE + ".mat"));

audioTrack = trackRes.(METHOD).audio;
audioHist = histRes.(METHOD).audio;
if audioTrack.fs ~= audioHist.fs || numel(audioTrack.signal) ~= numel(audioHist.signal)
    error("waveformTrackVsHist:audioMismatch", ...
        "trackとhistで、サンプリング周波数（%g Hz と %g Hz）かサンプル数（%d と %d）が違います。", ...
        audioTrack.fs,audioHist.fs,numel(audioTrack.signal),numel(audioHist.signal));
end
fs = audioTrack.fs;
t = (1:numel(audioTrack.signal))' / fs; % AudioData.plotWaveformと同じ時刻

% 名前・タイトルに共通の部分
baseName = "waveform_trackVsHist_" + UPSAMPLING + "_" + METHOD + "_" + NUM_GROOVES + "cyc_" + DATE;
condTitle = LABEL.(UPSAMPLING) + ", " + LABEL.(METHOD) + ", " + NUM_GROOVES + " cycles, data " + DATE;
compTitle = "Waveform: " + LABEL.track + " vs " + LABEL.hist;

%% 1. 全時間
[fig,ax] = plotTrackVsHist(t,audioTrack.signal,audioHist.signal,FIG_SIZE,LABEL, ...
    compTitle + " (" + condTitle + ")");
axis(ax,"tight");
ylim(ax,Y_VIEW_FULL);
saveFigure(fig,saveDir,baseName,Overwrite=OVERWRITE);

fprintf("振幅の最大 |x|：track %.3f、hist %.3f（Y_VIEW_FULL の外は図では切れる）\n", ...
    max(abs(audioTrack.signal)),max(abs(audioHist.signal)));

%% 2. 差が最大の時刻の前後を切り出す
% 線は全時間を描いたまま、表示範囲だけを切り出す（figを開いたときに前後も見られる）。
% yの範囲は、切り出した時間の中のデータに合わせ、y=0が中央になるよう上下対称にする
[~,iMax] = max(abs(audioHist.signal - audioTrack.signal));
tWin = t(iMax) + [-T_HALF_WINDOW T_HALF_WINDOW];
inWin = t >= tWin(1) & t <= tWin(2);
yAbsMax = max(abs([audioTrack.signal(inWin); audioHist.signal(inWin)]));

% 名前の範囲は整数の ms にする（figures.md「小数点を使わない」）。実際の表示範囲とは
% 丸めた分（1 ms 未満）だけ違う
winMs = round(tWin*1e3);
[fig,ax] = plotTrackVsHist(t,audioTrack.signal,audioHist.signal,FIG_SIZE,LABEL, ...
    compTitle + " (" + condTitle + sprintf(", %d-%d ms)",winMs));
axis(ax,"tight");
xlim(ax,tWin);
ylim(ax,[-yAbsMax yAbsMax]);
saveFigure(fig,saveDir,baseName + sprintf("_%d-%dms",winMs),Overwrite=OVERWRITE);

fprintf("差が最大：t = %.7f s（|hist − track| = %.3f）。切り出した範囲 %.4f〜%.4f ms（名前は %d-%dms）\n", ...
    t(iMax),abs(audioHist.signal(iMax) - audioTrack.signal(iMax)),tWin*1e3,winMs);


%% ローカル関数
function [fig,ax] = plotTrackVsHist(t,yTrack,yHist,figSize,label,titleStr)
% track と hist の波形を重ねて描く。後に描いた線が上になるので、track を先、hist を後に描く
% （凡例も比較の Vs と同じ順）。凡例のクリックで線の表示を切り替えられるようにする
    fig = createFigure([0 0 figSize]);
    ax = axes(fig);
    plot(ax,t,yTrack,DisplayName=label.track);
    hold(ax,"on");
    plot(ax,t,yHist,DisplayName=label.hist);
    hold(ax,"off");
    xlabel(ax,"Time [s]");
    ylabel(ax,"Amplitude");
    title(ax,titleStr);
    lgd = legend(ax,Location="northeast"); % プロット領域内（波形にかぶってもよい）
    lgd.ItemHitFcn = @togglevisibility;
end
