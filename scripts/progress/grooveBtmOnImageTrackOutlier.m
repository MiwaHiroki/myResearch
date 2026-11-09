% grooveBtmOnImageTrackOutlier.m
% 進捗報告用。自動追跡（track）の音声が手動選択（manual）から大きく外れた時刻について、
% その原因となった撮影画像の部分に、溝底点（重心法の候補点）を重ねた図を作る。
%   manual: experiments/<DATE>/cycleResult_origD_<DATE>.mat       （pkCentroid_1cycle.m）
%   track : experiments/<DATE>/cycleResult_origD_track_<DATE>.mat （grooveTrack_1cycle.m）
% T_WINDOW の中で |track − manual| が最大のサンプルを探し、それがどの写真・セグメント・
% 列から来たかを求め、その列と追跡したyを中心に画像を切り出す。
% png と fig の両方で results/figures/progress/grooveTracking/ に保存する。
%
% 前提：Research.prj を開いていること（撮影画像が MATLAB のパス上にあること。
%       reconstructImage で読み直す）。
% 2026/11/09作成

setDefaultIntrpr();
proj = currentProject();
rootFolder = proj.RootFolder;

%% パラメータ
DATE = "1014";       % 読み込む結果の日付（experiments/<DATE>/）
METHOD = "centroid"; % 溝底の抽出法（追跡のデトレンド前のyは重心法の yAbsCnt を使う）
T_WINDOW = [0.715 0.716]; % 外れを探す時間[s]

X_HALF = 35; % 切り出す幅の半分[px]（外れた列を中心に、溝に平行な方向）
Y_HALF = 32; % 切り出す高さの半分[px]（追跡したyを中心に、溝を横切る方向。上下の隣の溝も入る）

MARKER_SIZE = 15;     % 溝底点の大きさ（scatterのSizeData）
FIG_SIZE = [14.8 11.1]; % 図の大きさ[cm]（waveformManualVsTrack.mの図と同じ）
RESOLUTION = 300;       % pngの解像度[dpi]

saveDir = fullfile(rootFolder,"results","figures","progress","grooveTracking");
if ~isfolder(saveDir)
    mkdir(saveDir);
end

%% 読み込み
manual = loadCycleResult(cycleResultPath(rootFolder,"origD",DATE));
track = loadCycleResult(fullfile(experimentDir(rootFolder,DATE,Create=false), ...
    "cycleResult_origD_track_" + DATE + ".mat"));

%% 外れたサンプルが、どの写真・セグメント・列から来たかを求める
% audio.signal は vertcat(ycoords{:}) を並べたものなので、セグメントごとの列数の累積和で
% サンプル番号をセグメント k とその中の列 col に対応づける
fs = track.(METHOD).audio.fs;
sigTrack = track.(METHOD).audio.signal;
sigManual = manual.(METHOD).audio.signal;
nSamples = (1:numel(sigTrack))';
inWin = find(nSamples/fs >= T_WINDOW(1) & nSamples/fs <= T_WINDOW(2));
[~,iMax] = max(abs(sigTrack(inWin) - sigManual(inWin)));
nOutlier = inWin(iMax);

counts = cellfun(@numel,track.(METHOD).ycoords);
lastIdx = cumsum(counts);
k = find(lastIdx >= nOutlier,1);
col = nOutlier - (lastIdx(k) - counts(k));
numSegments = track.conditions.numSegments;
iImg = ceil(k/numSegments);
jSegment = k - (iImg-1)*numSegments;

% 追跡したデトレンド前のy（写真ごとの配列）から、その列のyを取り出す
kFirst = (iImg-1)*numSegments + 1;
yAbsTrack = track.grooveSelection.tracking.yAbsCnt{iImg};
yOutlier = yAbsTrack(sum(counts(kFirst:k-1)) + col);

fprintf("外れ：t = %.6f s（track %.3f、manual %.3f）\n", ...
    nOutlier/fs, sigTrack(nOutlier), sigManual(nOutlier));
fprintf("      写真%d（%s）・セグメント%d・%d列目、追跡したy = %.2f px\n", ...
    iImg, string(track.conditions.filenames(iImg)), jSegment, col, yOutlier);

%% 画像と溝底点
imgs = reconstructImage(track.conditions,iImg);
img = imgs(jSegment).img;
xRange = max(1,col-X_HALF) : min(size(img,2),col+X_HALF);
yRange = max(1,round(yOutlier)-Y_HALF) : min(size(img,1),round(yOutlier)+Y_HALF);

pks = vertcat(track.(METHOD).pts(k).peakCells{:});
inView = pks(:,1) >= xRange(1) & pks(:,1) <= xRange(end) & ...
    pks(:,2) >= yRange(1) & pks(:,2) <= yRange(end);

%% 描画
fig = createFigure([0 0 FIG_SIZE]);
ax = axes(fig);
imagesc(ax,img(yRange,xRange),XData=xRange([1 end]),YData=yRange([1 end]));
% 濃淡の範囲は画素値の全範囲 [0 255] に固定する。切り出した範囲に合わせて
% コントラストを変えると、実験データ（撮影画像）を改変したことになるため
colormap(ax,gray); clim(ax,[0 255]);
axis(ax,"image");
hold(ax,"on");
scatter(ax,pks(inView,1),pks(inView,2),MARKER_SIZE,"cyan","o");
hold(ax,"off");
xlabel(ax,"$x$ [px]");
ylabel(ax,"$y$ [px]");
title(ax,sprintf("photo %d (%s), segment %d, %s (date:%s)", ...
    iImg,string(track.conditions.filenames(iImg)),jSegment,METHOD,DATE));

%% 保存
% ファイル名：表示したもの（画像と溝底点）・抽出法・高解像度化の有無・データの日付・
% 写真とセグメント・外れを探した時間
name = sprintf("grooveBtmOnImage_%s_origD_%s_photo%d_seg%d_%g-%gms", ...
    METHOD,DATE,iImg,jSegment,round(T_WINDOW(1)*1e3),round(T_WINDOW(2)*1e3));
exportgraphics(fig,fullfile(saveDir,name + ".png"),Resolution=RESOLUTION);
savefig(fig,fullfile(saveDir,name + ".fig"));
fprintf("保存：%s（.png / .fig）\n",fullfile(saveDir,name));
