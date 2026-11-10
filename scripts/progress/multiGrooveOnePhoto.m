% multiGrooveOnePhoto.m
% 進捗報告用。写真1枚（1/8周分）から取り出した NUM_GROOVES 本の溝について、次の4枚の図を作り、
% すべて results/figures/progress/multiGroove/ に保存する。
%   1-1. NUM_GROOVES 本すべてを自動追跡した溝を写真に重ねた図（grooveTrack_Ncycle.m の結果。
%        複数本の溝の抽出を比べるための正解データ）
%   1-2. 1本目を自動追跡し、2本目以降をヒストグラムで取り出した溝を写真に重ねた図
%        （grooveHist_Ncycle.m の結果）
%   2.   写真のすべての溝底点を、1本目の溝の多項式でデトレンドした点（scatter）
%   3.   2 の点の y のヒストグラムに、選んだ山（1本目と、2本目以降）の頂点を〇で示した図
% 2・3 のデトレンドでは、多項式の値そのものではなく、写真の左端（xQuery(1)）での多項式の値との
% 差を引く。左端の溝底点の y は変わらず、点は元の画像の y の近くに残る。
% （extractMultiGroove は多項式の値そのものを引くので、1本目が y≈0 になる。ここでの y は、
% それに yShift ＝ 左端での多項式の値 を足したもの。ヒストグラムのビンも同じだけずらすので、
% ビンの点の数と山の位置は extractMultiGroove と同じ）
%
% 前提：Research.prj を開いていること（撮影画像が MATLAB のパス上にあること。
%       reconstructImage で読み直す）。
% 2026/11/10作成

setDefaultIntrpr();
proj = currentProject();
rootFolder = proj.RootFolder;

%% パラメータ
DATE = "1104";        % 読み込む結果の日付（experiments/<DATE>/）
UPSAMPLING = "origD"; % 高解像度化（今は origD の結果だけがある）
METHOD = "centroid";  % 溝底の抽出法（"centroid" または "localMax"）
NUM_GROOVES = 5;      % 溝の本数（cycleResult_<UPSAMPLING>_track<N>/_hist<N>_<DATE>.mat の N）
IMG_INDEX = 1;        % 図にする写真の番号（1〜8）

FIG_SIZE_IMAGE = [30 7];   % 写真に溝を重ねた図の大きさ[cm]（写真は横に長い）
FIG_SIZE_POINTS = [30 10]; % デトレンドした点の図の大きさ[cm]
FIG_SIZE_HIST = [10 10];   % ヒストグラムの図の大きさ[cm]（高さを点の図とそろえる）
MARKER_SIZE_POINTS = 1;    % デトレンドした点の大きさ（scatterのSizeData）
MARKER_SIZE_PEAK = 6;      % ヒストグラムの山の頂点の〇の大きさ（grooveHist_Ncycle.m の図と同じ）
OVERWRITE = true;          % 進捗報告用の図なので、作り直したときは上書きする

saveDirMulti = fullfile(rootFolder,"results","figures","progress","multiGroove");
if ~isfolder(saveDirMulti)
    mkdir(saveDirMulti);
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

% grooveSelection.multiGroove のフィールド名は、抽出法ごとに Cnt / Max で終わる
if METHOD == "centroid"
    suffix = "Cnt";
else
    suffix = "Max";
end
mgTrack = trackRes.grooveSelection.multiGroove;
mgHist = histRes.grooveSelection.multiGroove;

numSegments = histRes.conditions.numSegments;
ks = (IMG_INDEX-1)*numSegments + (1:numSegments);
queryStep = histRes.grooveSelection.tracking.queryStep;
[pks,xQuery] = mergeSegmentPoints(histRes.(METHOD).pts(ks),QueryStep=queryStep);

imgs = reconstructImage(histRes.conditions,IMG_INDEX);
photoImg = ImageData([imgs.img],[IMG_INDEX;0]); % 高さは同じなので横に連結できる

% 名前・タイトルに共通の部分
condName = UPSAMPLING + "_" + METHOD;
condTitle = LABEL.(UPSAMPLING) + ", " + LABEL.(METHOD);
partName = "_" + DATE + "_img" + IMG_INDEX;
partTitle = "data " + DATE + ", photo " + IMG_INDEX;

%% 1-1. すべてを自動追跡した溝
yAbsTrack = [mgTrack.("yAbs" + suffix){IMG_INDEX,:}];
seedsTrack = [xQuery(1)*ones(NUM_GROOVES,1), mgTrack.seedsY(IMG_INDEX,:)'];
fig = plotGroovesOnImage(photoImg,xQuery,yAbsTrack,seedsTrack,FIG_SIZE_IMAGE, ...
    "Groove on image (" + condTitle + ", " + LABEL.track + ", " + NUM_GROOVES + " cycles, " + partTitle + ")");
saveFigure(fig,saveDirMulti, ...
    "grooveOnImage_" + condName + "_track_" + NUM_GROOVES + "cyc" + partName,Overwrite=OVERWRITE);

%% 1-2. 1本目を自動追跡し、2本目以降をヒストグラムで取り出した溝
yAbsHist = [mgHist.("yAbs" + suffix){IMG_INDEX,:}];
seedHist = histRes.grooveSelection.seeds(IMG_INDEX,:);
fig = plotGroovesOnImage(photoImg,xQuery,yAbsHist,seedHist,FIG_SIZE_IMAGE, ...
    "Groove on image (" + condTitle + ", " + LABEL.hist + ", " + NUM_GROOVES + " cycles, " + partTitle + ")");
saveFigure(fig,saveDirMulti, ...
    "grooveOnImage_" + condName + "_hist_" + NUM_GROOVES + "cyc" + partName,Overwrite=OVERWRITE);

%% 2. 1本目の溝の多項式でデトレンドした溝底点
trend = mgHist.("trend" + suffix){IMG_INDEX};
yTrend = polyval(trend.p,pks(:,1),trend.S,trend.mu);
yShift = polyval(trend.p,xQuery(1),trend.S,trend.mu); % 左端での多項式の値
yCor = pks(:,2) - yTrend;   % extractMultiGroove と同じ補正（1本目が y≈0）
yDet = yCor + yShift;       % 左端の点の y が変わらないようにした補正
yLimPoints = [min(yDet) max(yDet)];

fig = createFigure([0 0 FIG_SIZE_POINTS]);
ax = axes(fig);
scatter(ax,pks(:,1),yDet,MARKER_SIZE_POINTS,"blue","filled");
axis(ax,"tight");
ylim(ax,yLimPoints);
set(ax,"YDir","reverse","Box","on");
xlabel(ax,"$x$ [px]");
ylabel(ax,"$y$ [px]");
title(ax,"Groove-bottom points (" + condTitle + ", " + LABEL.hist + ", " + partTitle + ")");
saveFigure(fig,saveDirMulti,"pointCloud_" + condName + "_hist" + partName,Overwrite=OVERWRITE);

%% 3. デトレンドした点の y のヒストグラム
% extractMultiGroove と同じ引数で findGrooveCenters を呼び直し、保存した山の中心と同じかを確かめる
minPeakHeight = mgHist.thHistRatio * numel(xQuery);
[centers,infoHist] = findGrooveCenters([pks(:,1) yCor],NUM_GROOVES, ...
    BinWidth=mgHist.binWidth,MinPeakHeight=minPeakHeight);
savedCenters = mgHist.("centers" + suffix)(IMG_INDEX,:)';
if max(abs(centers - savedCenters)) > 1e-9
    error("multiGrooveOnePhoto:centersMismatch", ...
        "呼び直した山の中心 %s が、保存した値 %s と違います。", ...
        mat2str(centers',4),mat2str(savedCenters',4));
end
binEdges = [infoHist.binCenters - mgHist.binWidth/2, infoHist.binCenters(end) + mgHist.binWidth/2];

fig = createFigure([0 0 FIG_SIZE_HIST]);
ax = axes(fig);
histogram(ax,BinEdges=binEdges + yShift,BinCounts=infoHist.counts,Orientation="horizontal", ...
    FaceColor="blue",FaceAlpha=1,EdgeColor="none",HandleVisibility="off");
hold(ax,"on");
% 選んだ山（findGrooveCenters の peakCenters の、1本目から y の小さい側へ NUM_GROOVES 個）の
% 頂点に〇を描く。1本目（追跡した溝の位置の山）と、2本目以降（ヒストグラムで選んだ山）で色を変える
selIdx = infoHist.firstIdx:-1:infoHist.firstIdx-NUM_GROOVES+1;
peakX = infoHist.peakHeights(selIdx);
peakY = infoHist.peakCenters(selIdx) + yShift;
hFirst = plot(ax,peakX(1),peakY(1),"o",Color="black",MarkerSize=MARKER_SIZE_PEAK);
hOthers = plot(ax,peakX(2:end),peakY(2:end),"o",Color="red",MarkerSize=MARKER_SIZE_PEAK);
hold(ax,"off");
ylim(ax,yLimPoints);
set(ax,"YDir","reverse","Box","on");
xlabel(ax,"Number of points");
ylabel(ax,"$y$ [px]");
% 図の幅に収まらないので2行に分ける（書く情報と順はほかの図と同じ）
title(ax,["Groove histogram", "(" + condTitle + ", " + LABEL.hist + ", " + NUM_GROOVES + " cycles, " + partTitle + ")"]);
legend(ax,[hFirst hOthers], ...
    ["groove 1 (" + LABEL.track + ")", sprintf("grooves 2-%d (%s)",NUM_GROOVES,LABEL.hist)], ...
    Location="southeast");
saveFigure(fig,saveDirMulti, ...
    "grooveHistogram_" + condName + "_hist_" + NUM_GROOVES + "cyc" + partName,Overwrite=OVERWRITE);

fprintf("写真%d：左端での多項式の値 yShift = %.2f px、溝の位置（デトレンド後）= %s px\n", ...
    IMG_INDEX,yShift,mat2str([yShift; centers(2:end) + yShift]',5));


%% ローカル関数
function fig = plotGroovesOnImage(photoImg,xQuery,yAbs,seeds,figSize,titleStr)
% 写真に溝（デトレンド前のy）を色を変えて重ね、始点のクリックを黄色の三角で示す。
% 凡例のクリックで線の表示を切り替えられるようにする
    % showImage は x 軸を上に置くので、単体の axes だとタイトルが図の上にはみ出す。
    % tiledlayout にして、タイトル・目盛り・凡例の余白を自動で取る
    fig = createFigure([0 0 figSize]);
    tl = tiledlayout(fig,1,1,Padding="compact");
    ax = nexttile(tl); % showImage は gca に描くので先に作る
    photoImg.showImage("fit"); % imshow(uint8) なので表示範囲は [0 255]
    hold(ax,"on");
    numGrooves = size(yAbs,2);
    colors = lines(numGrooves);
    for jGroove = 1:numGrooves
        plot(ax,xQuery,yAbs(:,jGroove),"-",Color=colors(jGroove,:),LineWidth=0.5, ...
            DisplayName="groove " + jGroove);
    end
    plot(ax,seeds(:,1),seeds(:,2),"^",Color="yellow",MarkerFaceColor="yellow",MarkerSize=5, ...
        DisplayName="click");
    hold(ax,"off");
    xlabel(ax,"$x$ [px]");
    ylabel(ax,"$y$ [px]");
    title(ax,titleStr);
    lgd = legend(ax,Location="southoutside",Orientation="horizontal");
    lgd.ItemHitFcn = @togglevisibility;
end
