% waveformTrackVsHist.m
% 進捗報告用。N本の溝（N周分）から作った音声の波形を、溝の選び方で比べる図を作る。
%   track: N本をそれぞれ自動追跡（grooveTrack_Ncycle.m）
%          experiments/<DATE>/cycleResult_<UPSAMPLING>_track<N>_<DATE>.mat
%   hist : 1本目だけ自動追跡し、2本目以降をヒストグラムで取り出す（grooveHist_Ncycle.m）
%          experiments/<DATE>/cycleResult_<UPSAMPLING>_hist<N>_<DATE>.mat
% 全時間を重ねて描き、hist を上に描く。凡例をクリックすると線の表示を切り替えられる
% （togglevisibility）。results/figures/progress/multiGroove/ に png と fig で保存する。
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

Y_VIEW = [-1 1];        % Amplitudeの範囲
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
if audioTrack.fs ~= audioHist.fs
    error("waveformTrackVsHist:fsMismatch", ...
        "trackとhistでサンプリング周波数が違います（%g Hz と %g Hz）。", ...
        audioTrack.fs, audioHist.fs);
end
fs = audioTrack.fs;
tTrack = (1:numel(audioTrack.signal))' / fs; % AudioData.plotWaveformと同じ時刻
tHist = (1:numel(audioHist.signal))' / fs;

%% 描画
fig = createFigure([0 0 FIG_SIZE]);
ax = axes(fig);
% 後に描いた線が上になるので、track を先、hist を後に描く（凡例も比較の Vs と同じ順）
plot(ax,tTrack,audioTrack.signal,DisplayName=LABEL.track);
hold(ax,"on");
plot(ax,tHist,audioHist.signal,DisplayName=LABEL.hist);
hold(ax,"off");
axis(ax,"tight");
ylim(ax,Y_VIEW);
xlabel(ax,"Time [s]");
ylabel(ax,"Amplitude");
title(ax,"Waveform: " + LABEL.track + " vs " + LABEL.hist + " (" + LABEL.(UPSAMPLING) + ", " + ...
    LABEL.(METHOD) + ", " + NUM_GROOVES + " cycles, data " + DATE + ")");
lgd = legend(ax,Location="northeast"); % プロット領域内（波形にかぶってもよい）
lgd.ItemHitFcn = @togglevisibility;

%% 保存
saveFigure(fig,saveDir,"waveform_trackVsHist_" + UPSAMPLING + "_" + METHOD + "_" + ...
    NUM_GROOVES + "cyc_" + DATE,Overwrite=OVERWRITE);

fprintf("振幅の最大 |x|：track %.3f、hist %.3f（Y_VIEW の外は図では切れる）\n", ...
    max(abs(audioTrack.signal)), max(abs(audioHist.signal)));
