% wideBottomOutlier.m
% 進捗報告用。issue #35 の素材 M2・M3。
% 溝底区間の幅の上限を直す前（8 px）の、1周分の自動追跡の結果（1014）で、音声の 715 ms に出た振幅1付近の
% 外れ値（写真8、x=1862〜1865）の付近を、次の2枚の図にして results/figures/progress/grooveBottomDetection/
% に保存する。
%   M2：写真の切り出し。上の段は写真だけ、下の段は写真に、すべての溝底点、溝底範囲（各列で溝底とみなした
%       区間）の始めと終わり、自動追跡で選んだ溝底点を重ねる（描き方は docs/groove-on-image.md）。
%       選んだ溝底点は、溝底区間の幅が WIDE_MIN 以上かどうかで色を分ける。幅の広い区間の溝底点が、
%       溝底の暗い線からずれていることを見るため。
%   M3：列ごとの暗さの分布（折れ線）に、しきい値の線と、選んだ溝底点（重心）の線を重ねる。
%       しきい値すれすれの行がつながって溝底区間が広がり、重心がずれる仕組みを見るため。
% 溝底範囲と幅は cycleResult に保存していないので、写真を reconstructImage で読み直し、保存した
% conditions（溝底区間の幅の上限 wTh、暗さのしきい値 dThresh）で、自動追跡のスクリプトの検出のループと
% 同じ処理（ローカル関数 detectPhoto）で求め直す。求め直した溝底点が、保存した溝底点（pts）と一致する
% ことを確かめてから描く。今の自動追跡のスクリプト（幅の上限 4）は実行しない。
% 選んだ溝底点は、保存した追跡の結果（grooveSelection.tracking の、デトレンド前の y と点を採れた列）の
% うち、点を採れた列だけを描く（欠損を補間した列は描かない）。
% experiments/ は読むだけで、何も保存しない。
% 検出のローカル関数は scripts/evaluation/grooveBottomDetection/compareWidthThresh.m の detectPhoto から、
% 図の描き方は scripts/progress/grooveOnImageManualAndTrack.m から写した。
%
% 前提：Research.prj を開いていること（撮影画像が MATLAB のパス上にあること。reconstructImage で読み直す）。
% 2026/11/23作成
% 2026/11/23 ユーザーの決定で、この試行の図の体裁をそろえた。文字を MATLAB の既定（目盛り 9 pt、軸ラベルと
%            タイトル 9.9 pt、凡例 8.1 pt）にし、M2 の点をすべて 18 にした（15 から）。OVERWRITE=true で
%            M2・M3 を作り直した
% 2026/11/23 ユーザーの決定で、凡例の位置を右上（northeast）にそろえ、OVERWRITE=true で M2 だけを作り直した
%            （MAKE_FIGS.profile=false）。M3 は右上にすると凡例が折れ線の山を隠すので、右下のまま残した
% 2026/11/23 ユーザーの決定で、M3 の凡例を右上（2列）にし、暗さの軸を 0.35〜1.0（目盛りの間隔 0.05。
%            D_TICK）にした。凡例が重心の破線の上の部分にかかるのは、ユーザーが受け入れた。OVERWRITE=true で
%            M3 だけを作り直した（MAKE_FIGS.crop=false）

setDefaultIntrpr();
proj = currentProject();
rootFolder = proj.RootFolder;

%% パラメータ
DATE = "1014";          % 読み込む結果の日付（experiments/<DATE>/）
UPSAMPLING = "origD";   % 高解像度化（自動追跡は origD だけ）
SELECTION = "track";    % 溝の選び方（自動追跡。grooveTrack_1cycle.m の結果を読む）
BOUND = "inclBound";    % 溝底の判定。1014 のデータは ad46b44 以降のコード（3261e62）で作ったので、
                        % 境界値を含める判定（meta.gitCommit で確かめた）
METHOD = "centroid";    % 溝底の抽出法（この素材は重心法だけ）
W_BEFORE = 8;           % 読み込む結果の溝底区間の幅の上限 [px]（直す前の値。conditions.wTh と照らす）
WIDE_MIN = 5;           % 選んだ溝底点のうち、幅がこれ以上のものの色を変える [px]（直した後の上限 4 より広い）
I_IMG = 8;              % 写真の番号
TARGET_X = [1862 1865]; % 外れ値の列の範囲（写真の中の px）。切り出しの中心と、名前の時間の範囲を決める

% M2：写真の切り出し
X_HALF = 35;              % 切り出す幅の半分 [px]（外れ値の列の中心から、溝に平行な方向）
Y_HALF = 14;              % 切り出す高さの半分 [px]（中心の列の選んだ y から、溝を横切る方向。隣の溝の手前まで）
FIG_SIZE_CROP = [16 13];  % 図の大きさ [cm]
MARKER_SIZE = 18;         % 点の大きさ（scatter の SizeData。すべての種類で同じ。ユーザーの決定、2026-11-23）
LEGEND_LOCATION_CROP = "northeast"; % 凡例の位置（描画領域の右上。ユーザーの決定、2026-11-23）

% M3：暗さの分布
PROFILE_X = [1861 1862 1865]; % 暗さの分布を描く列（写真の中の px）。1861 は幅3のふつうの列
PROFILE_Y = [280 295];        % 描く y の範囲 [px]
D_LIM = [0.35 1.0];           % 暗さの軸の範囲。上限は、右上の凡例が折れ線の最大（約 0.74）より上に来るように
                              % 0.8 から上げた（ユーザーの決定、2026-11-23）
D_TICK = 0.05;                % 暗さの軸の目盛りの間隔
FIG_SIZE_PROFILE = [16 10];   % 図の大きさ [cm]
LEGEND_LOCATION_PROFILE = "northeast"; % 凡例の位置（右上、2列。同じ色の折れ線と重心の破線が同じ行に並ぶ）。
                                       % 凡例が重心の破線3本の上の部分にかかるのは、ユーザーが受け入れた
                                       % （ユーザーの決定、2026-11-23）

% 色（docs/groove-on-image.md と同じ。幅の広い選んだ点の色だけ、このスクリプトで決めた）
COLOR_ALL = "cyan";                                  % すべての溝底点
COLOR_RANGE = struct("start","red","end","yellow");  % 溝底範囲の始めと終わり
COLOR_TRACK = "magenta";                             % 自動追跡で選んだ溝底点（幅が WIDE_MIN 未満）
COLOR_WIDE = "green";                                % 自動追跡で選んだ溝底点（幅が WIDE_MIN 以上）
FONT_SIZE = 9;          % 目盛りの文字 [pt]。軸ラベル・タイトルはその 1.1 倍、凡例は 0.9 倍（MATLAB の既定）
MAKE_FIGS = struct("crop",true,"profile",true); % 作る図（crop は M2、profile は M3）。片方だけ作り直すときに使う
OVERWRITE = false;      % 同じ名前の図を上書きするか（作り直すときだけ true にする）

THEME = "grooveBottomDetection";
saveDir = fullfile(rootFolder,"results","figures","progress",THEME);
if ~isfolder(saveDir)
    mkdir(saveDir);
end

% タイトル・凡例の表記（docs/rules/figures.md の語彙表の「表記」の列）
LABEL = struct("origD","original","inclBound","inclusive bounds","centroid","centroid","track","tracking");

%% 読み込み
expDir = experimentDir(rootFolder,DATE,Create=false);
result = loadCycleResult(fullfile(expDir,"cycleResult_" + UPSAMPLING + "_" + SELECTION + "_" + DATE + ".mat"));
cond = result.conditions;
trk = result.grooveSelection.tracking;
fprintf("読み込んだ結果：commit %s、gitDirty %d、wTh %g、dThresh %g\n", ...
    result.meta.gitCommit,result.meta.gitDirty,cond.wTh,cond.dThresh);
if cond.wTh ~= W_BEFORE || cond.upsampling.kind ~= UPSAMPLING
    error("wideBottomOutlier:conditionsMismatch", ...
        "読み込んだ結果の幅の上限（%g）か高解像度化（%s）が、パラメータと違います。", ...
        cond.wTh,cond.upsampling.kind);
end

% grooveSelection.tracking のフィールド名は、抽出法ごとに Cnt / Max で終わる
if METHOD == "centroid"
    suffix = "Cnt";
else
    suffix = "Max";
end
yAbs = trk.("yAbs" + suffix){I_IMG};    % 追跡した、デトレンド前の y（欠損を補間した列も含む）
found = trk.("found" + suffix){I_IMG};  % その列で点を採れたか

% 1周分の音声は、写真1〜8の列を順に並べたもの。列から時刻を求めて、名前・タイトルの範囲にする
counts = cellfun(@numel,trk.("yAbs" + suffix));
fs = result.(METHOD).audio.fs;
if sum(counts) ~= numel(result.(METHOD).audio.signal)
    error("wideBottomOutlier:sampleCount","列の数の合計が、音声のサンプルの数と違います。");
end
toMs = @(x) (sum(counts(1:I_IMG-1)) + x)/fs*1e3;
msRangeOf = @(xs) [floor(toMs(min(xs))), max(ceil(toMs(max(xs))), floor(toMs(min(xs))) + 1)];

%% 溝底点と溝底範囲を求め直す（写真 I_IMG の1枚分）
imgs = reconstructImage(cond,I_IMG);
photoImg = [imgs.img];   % 高さは同じなので横に連結できる
det = detectPhoto(imgs,cond.dThresh,cond.wTh,trk.queryStep);
if size(photoImg,2) ~= numel(det.xQuery) || numel(yAbs) ~= numel(det.xQuery)
    error("wideBottomOutlier:widthMismatch","写真の幅、列の数、追跡した y の数が合いません。");
end

% 求め直した溝底点が、保存した溝底点と一致するか（compareWidthThresh.m の R1 と同じ確かめ方）
ks = (I_IMG-1)*cond.numSegments + (1:cond.numSegments);
saved = mergeSegmentPoints(result.(METHOD).pts(ks),QueryStep=trk.queryStep);
if ~isequal(size(saved),size(det.pks)) || max(abs(saved - det.pks),[],"all") > 1e-9
    error("wideBottomOutlier:pointsMismatch","求め直した溝底点が、保存した溝底点と違います。");
end
fprintf("写真%d：求め直した溝底点 %d 点が、保存した溝底点と一致した。\n",I_IMG,size(det.pks,1));

% 自動追跡で選んだ溝底点（点を採れた列だけ）と、その点の溝底区間の幅
pksSel = [det.xQuery(found), yAbs(found)];
[isDetected,locSel] = ismember(pksSel,det.pks,"rows");
if ~all(isDetected)
    error("wideBottomOutlier:trackNotDetected","選んだ点の中に、求め直した溝底点に無い点があります。");
end
widthSel = det.width(locSel);
isWide = widthSel >= WIDE_MIN;

% 名前・タイトルに共通の部分
condName = UPSAMPLING + "_" + BOUND + "_" + METHOD;
condTitle = LABEL.(UPSAMPLING) + ", " + LABEL.(BOUND) + ", " + LABEL.(METHOD);

%% M2：写真の切り出しに、溝底点・溝底範囲・選んだ溝底点を重ねる
xc = round(mean(TARGET_X));
xRange = max(1,xc-X_HALF) : min(size(photoImg,2),xc+X_HALF);
yc = round(yAbs(xc));
yRange = max(1,yc-Y_HALF) : min(size(photoImg,1),yc+Y_HALF);
msRange = msRangeOf(TARGET_X);

inTarget = pksSel(:,1) >= TARGET_X(1) & pksSel(:,1) <= TARGET_X(2);
fprintf("\nM2：外れ値の列 x=%d〜%d（%.2f〜%.2f ms）\n",TARGET_X,toMs(TARGET_X(1)),toMs(TARGET_X(2)));
disp(table(pksSel(inTarget,1),pksSel(inTarget,2),widthSel(inTarget),'VariableNames',["x","y","width"]));
inCrop = pksSel(:,1) >= xRange(1) & pksSel(:,1) <= xRange(end);
fprintf("切り出しの中の選んだ点：%d 点（幅%d以上 %d 点：x = %s）\n",nnz(inCrop),WIDE_MIN, ...
    nnz(inCrop & isWide),mat2str(pksSel(inCrop & isWide,1)'));

style = struct("figSize",FIG_SIZE_CROP,"markerSize",MARKER_SIZE,"colorAll",COLOR_ALL, ...
    "colorRange",COLOR_RANGE,"colorTrack",COLOR_TRACK,"colorWide",COLOR_WIDE, ...
    "legendLocation",LEGEND_LOCATION_CROP,"fontSize",FONT_SIZE);
labels = ["all groove-bottom points", "groove-bottom range: start", "groove-bottom range: end", ...
    LABEL.(SELECTION) + ", width $\leq$ " + (WIDE_MIN - 1), LABEL.(SELECTION) + ", width $\geq$ " + WIDE_MIN];
if MAKE_FIGS.crop
    % タイトルは図の幅に収まらないので2行に分ける
    fig = plotCrop(photoImg,xRange,yRange,det,pksSel(~isWide,:),pksSel(isWide,:),style,labels, ...
        ["Groove on image", "(" + condTitle + ", " + LABEL.(SELECTION) + ", data " + DATE + ...
        ", photo " + I_IMG + sprintf(", %d-%d ms)",msRange)]);
    saveFigure(fig,saveDir,"grooveOnImage_" + condName + "_" + SELECTION + "_" + DATE + "_img" + I_IMG + ...
        sprintf("_%d-%dms",msRange) + "_grooveBtmRange",Overwrite=OVERWRITE);
    close(fig);
end

%% M3：列ごとの暗さの分布に、しきい値と重心を重ねる
% 各列で、選んだ溝底点の溝底区間（始め・終わり・幅・重心）を取り出す
numCols = numel(PROFILE_X);
info = table('Size',[numCols 5],'VariableTypes',repmat("double",1,5), ...
    'VariableNames',["x","rangeStart","rangeEnd","width","centroid"]);
for k = 1:numCols
    x = PROFILE_X(k);
    r = locSel(pksSel(:,1) == x);
    if isempty(r)
        error("wideBottomOutlier:noSelectedPoint","x=%d では、追跡で点を採れていません。",x);
    end
    info(k,:) = {x, det.rangeStart(r,2), det.rangeEnd(r,2), det.width(r), det.pks(r,2)};
end
darkness = 1 - double(photoImg)/255;   % DarknessMap.dMat と同じ式（高解像度化しない）
yProfile = (PROFILE_Y(1):PROFILE_Y(2))';
fprintf("\nM3：選んだ溝底点の溝底区間\n");
disp(info);
fprintf("暗さ（行 = y、列 = x）\n");
disp(array2table([yProfile, darkness(yProfile,PROFILE_X)],'VariableNames',["y", "x" + PROFILE_X]));

msRange = msRangeOf(PROFILE_X);
styleProfile = struct("figSize",FIG_SIZE_PROFILE,"dLim",D_LIM,"dTick",D_TICK,"legendLocation",LEGEND_LOCATION_PROFILE, ...
    "fontSize",FONT_SIZE);
if MAKE_FIGS.profile
    fig = plotProfiles(darkness,yProfile,info,cond.dThresh,styleProfile, ...
        ["Darkness profile", "(" + condTitle + ", data " + DATE + ", photo " + I_IMG + sprintf(", %d-%d ms)",msRange)]);
    saveFigure(fig,saveDir,"darknessProfile_" + condName + "_" + DATE + "_img" + I_IMG + ...
        sprintf("_%d-%dms",msRange),Overwrite=OVERWRITE);
    close(fig);
end


%% ローカル関数
function det = detectPhoto(imgs,dThresh,widthThresh,queryStep)
% 写真1枚分（区間の ImageData の配列 imgs）の溝底点（重心法）を、自動追跡のスクリプトの検出のループ
% （scripts/grooveTrack_1cycle.m など）と同じ処理で求め、mergeSegmentPoints で写真1枚分の座標にする。
% 溝底範囲と幅は cycleResult に保存していないので、ここで一緒に求める。
% compareWidthThresh.m の detectPhoto から写し、重心法だけにして、溝底範囲の始めと終わりを足した。
% 出力 det のフィールド（pks・rangeStart・rangeEnd・width は同じ並び）：
%   pks        溝底点 [x y]
%   rangeStart 溝底範囲の始め [x y]（溝底区間の最初の行）
%   rangeEnd   溝底範囲の終わり [x y]（溝底区間の最後の行）
%   width      溝底区間の幅（最後の行 − 最初の行 [px]）
%   xQuery     写真1枚分の列
    numSeg = numel(imgs);
    allPts(numSeg,1) = GroovePointCloud();
    startCells = cell(numSeg,1);
    endCells = cell(numSeg,1);
    for jSegment = 1:numSeg
        map = DarknessMap(imgs(jSegment));
        map = map.setDiffTF(dThresh);
        pts = GroovePointCloud(map);
        extractor = GrooveExtractor(map);
        for x = 1:imgs(jSegment).width
            [firstIdx,lastIdx] = extractor.findThresholdIntervals(map,x);
            [extractor,~,~,numPeaks] = extractor.findGrooveBottomIntervals(map,x,firstIdx,lastIdx,widthThresh);
            pts.peakCells{x} = [x*ones(numPeaks,1), extractor.extractByCentroid(map,x)];
        end
        allPts(jSegment) = pts;
        % 溝底範囲の行を、元の画像の y に戻す（高解像度化しないときは同じ値）
        toY = @(c) [c(:,1), (c(:,2) - 1)/map.scaleFactor.row + 1];
        startCells{jSegment} = toY(vertcat(zeros(0,2),extractor.startIdxCells{:}));
        endCells{jSegment} = toY(vertcat(zeros(0,2),extractor.endIdxCells{:}));
    end
    [pks,xQuery,~,xOffsets] = mergeSegmentPoints(allPts,QueryStep=queryStep);
    for jSegment = 1:numSeg   % 区間の中の x を、写真1枚分の x にする（mergeSegmentPoints と同じずらし方）
        startCells{jSegment}(:,1) = startCells{jSegment}(:,1) + xOffsets(jSegment);
        endCells{jSegment}(:,1) = endCells{jSegment}(:,1) + xOffsets(jSegment);
    end
    det = struct();
    det.pks = pks;
    det.rangeStart = vertcat(startCells{:});
    det.rangeEnd = vertcat(endCells{:});
    det.width = det.rangeEnd(:,2) - det.rangeStart(:,2);
    det.xQuery = xQuery;
    if ~isequal(size(det.rangeStart),size(pks)) || ~isequal(det.rangeStart(:,1),pks(:,1))
        error("wideBottomOutlier:rangeCount","溝底範囲の並びが、溝底点の並びと合いません。");
    end
end

function fig = plotCrop(photoImg,xRange,yRange,det,pksNarrow,pksWide,style,labels,titleLines)
% 上の段に写真だけ、下の段に写真と、すべての溝底点・溝底範囲の始めと終わり・選んだ溝底点（幅の狭い点と
% 広い点）を、この順に重ねる（docs/groove-on-image.md の順）。凡例のクリックで表示を切り替えられる。
% 写真の表示範囲は [0 255] に固定する（docs/rules/figures.md「撮影画像の表示」）
    fig = createFigure([0 0 style.figSize]);
    tl = tiledlayout(fig,2,1,Padding="compact",TileSpacing="compact");
    for t = 1:2
        ax = nexttile(tl);
        imagesc(ax,photoImg(yRange,xRange),XData=xRange([1 end]),YData=yRange([1 end]));
        colormap(ax,gray); clim(ax,[0 255]);
        axis(ax,"image");
        ax.FontSize = style.fontSize;   % tiledlayout が小さくしないように、目盛りの大きさを決める
        ylabel(ax,"$y$ [px]");
    end
    title(tl,titleLines,Interpreter="latex",FontSize=style.fontSize*1.1);   % 軸のタイトルと同じ大きさ
    hold(ax,"on");
    h = gobjects(5,1);
    pts = pointsInView(det.pks,xRange,yRange);
    h(1) = scatter(ax,pts(:,1),pts(:,2),style.markerSize,style.colorAll,"filled","o");
    pts = pointsInView(det.rangeStart,xRange,yRange);
    h(2) = scatter(ax,pts(:,1),pts(:,2),style.markerSize,style.colorRange.start,"filled","o");
    pts = pointsInView(det.rangeEnd,xRange,yRange);
    h(3) = scatter(ax,pts(:,1),pts(:,2),style.markerSize,style.colorRange.end,"filled","o");
    pts = pointsInView(pksNarrow,xRange,yRange);
    h(4) = scatter(ax,pts(:,1),pts(:,2),style.markerSize,style.colorTrack,"filled","o");
    pts = pointsInView(pksWide,xRange,yRange);
    h(5) = scatter(ax,pts(:,1),pts(:,2),style.markerSize,style.colorWide,"filled","o");
    hold(ax,"off");
    xlabel(ax,"$x$ [px]");
    lgd = legend(ax,h,labels,Location=style.legendLocation,NumColumns=3,FontSize=style.fontSize*0.9);
    lgd.ItemHitFcn = @togglevisibility;
end

function fig = plotProfiles(darkness,yProfile,info,dThresh,style,titleLines)
% info の列ごとに、yProfile の行の暗さを折れ線で描き、選んだ溝底点（重心）の y に、同じ色の破線を引く。
% しきい値 dThresh に点線を引く。凡例は、左の列に暗さの分布（溝底区間と幅）としきい値、右の列に重心を並べる
    fig = createFigure([0 0 style.figSize]);
    tl = tiledlayout(fig,1,1,Padding="compact");
    ax = nexttile(tl);
    ax.FontSize = style.fontSize;
    colors = ax.ColorOrder;
    numCols = height(info);
    hLine = gobjects(numCols,1);
    hCentroid = gobjects(numCols,1);
    hold(ax,"on");
    for k = 1:numCols
        c = colors(k,:);
        hLine(k) = plot(ax,yProfile,darkness(yProfile,info.x(k)),"-o",Color=c,LineWidth=1,MarkerSize=4);
        hCentroid(k) = xline(ax,info.centroid(k),"--",Color=c,LineWidth=1);
    end
    hThresh = yline(ax,dThresh,"k:",LineWidth=1);
    hold(ax,"off");
    grid(ax,"on");
    xlim(ax,yProfile([1 end]));
    xticks(ax,yProfile);
    ylim(ax,style.dLim);
    yticks(ax,style.dLim(1):style.dTick:style.dLim(2));
    xlabel(ax,"$y$ [px]");
    ylabel(ax,"Darkness $D$");
    title(ax,titleLines);
    lineNames = compose("$x$ = %d (range %d-%d, width %d)",info.x,info.rangeStart,info.rangeEnd,info.width);
    centroidNames = compose("centroid %.2f",info.centroid);
    lgd = legend(ax,[hLine; hThresh; hCentroid], ...
        [lineNames; "$D_\mathrm{th}$ = " + dThresh; centroidNames], ...
        Location=style.legendLocation,NumColumns=2,FontSize=style.fontSize*0.9);
    lgd.ItemHitFcn = @togglevisibility;
end

function pks = pointsInView(pks,xRange,yRange)
% 描く範囲（xRange・yRange の端を含む）にある点だけを残す
    inView = pks(:,1) >= xRange(1) & pks(:,1) <= xRange(end) & ...
        pks(:,2) >= yRange(1) & pks(:,2) <= yRange(end);
    pks = pks(inView,:);
end
