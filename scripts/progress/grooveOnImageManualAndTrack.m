% grooveOnImageManualAndTrack.m
% 進捗報告用。1周分の結果について、次の2種類の図を作り、results/figures/progress/grooveTracking/ に
% 保存する。
%   1. 写真に、すべての溝底点を重ねた図
%   2. 1 の上に、次の2通りで取り出した溝底点を色を変えて重ねた図。凡例のクリックで、
%      点の表示を切り替えられる（togglevisibility）
%      - 従来法（manual。fitGroove で区間ごとにクリックして溝を選ぶ。1周で80回以上の ginput）
%      - 自動追跡（track。trackGroove。写真1枚につき1回のクリック）
%      2つの点はほとんど同じ位置にあり、後に描く track が上に来る。manual だけにある点は
%      manual の色で見える。
%   3. 1 の上に、溝底範囲（各列で溝底とみなした区間の始めと終わり）と、自動追跡で取り出した溝底点を
%      この順に重ねた図（切り出しだけ）。凡例は 2 と同じく togglevisibility。
%      溝底範囲は cycleResult に保存していないので、写真から _1cycle スクリプトと同じ処理で求め直し、
%      そこから計算した溝底点が、保存した溝底点と一致することを確かめる。始めと終わりの色は、
%      results/figures/slides/202609asj/darknessProfile_grooveBtmRange.png（darknessProfile.m）と同じ。
%   4. 3 から自動追跡の点を除いた図（切り出しだけ）。溝底範囲が実際の溝底より広く求まり、溝底点が
%      ずれていることを、取り出した点に隠されずに見るため（issue #35 の資料）。
%      1 と同じ条件なので、名前の最後に表示の語 grooveBtmRange を付けて区別する。
%   5. 1〜4 と同じ範囲の写真だけの図（切り出しだけ）。点に隠されずに写真の濃淡を見るため。
%      溝底点を描かないので、種類は grooveOnImage ではなく image にし、写真が依存しない条件
%      （溝底の判定・抽出法）は書かない。切り出す場所は、データの日付と時間の範囲で示す
%      （docs/rules/figures.md「種類と条件は、描いたものに合わせる」）。
% 1・2 をそれぞれ、次の2つの範囲で作る（3〜5 は切り出しだけ）。
%   写真全体  ：IMG_INDICES の写真（1/8周分）ごと（MAKE_PHOTO_FIGS が true のときだけ）
%   切り出し  ：T_WINDOWS の時間ごとに、|track − manual| が最大のサンプルが来た列と、追跡した y を
%               中心に切り出した範囲（grooveBtmOnImageTrackOutlier.m の図と同じ範囲。座標は区間の中の px）。
%               MAKE_CROP_FIGS で、作る図を選ぶ
% 2 の点は、音声に使った点のうち、実際に検出した点だけ（欠損を補間した列の点は描かない）。
%   manual: experiments/<DATE>/cycleResult_<UPSAMPLING>_<DATE>.mat       （pkCentroid_1cycle.m）
%           保存したクリック位置 grooveSelection.p1/p2 で fitGroove を ginput なしで呼び直し、
%           findGrooveCenter で選んだ溝の中心から Tolerance 以内の点を取り出す
%           （extractGrooveShape と同じ選び方）。その点を補間・デトレンドした y が、
%           保存した ycoords と一致することを確かめる。
%   track : experiments/<DATE>/cycleResult_<UPSAMPLING>_track_<DATE>.mat （grooveTrack_1cycle.m）
%           保存した追跡の y（grooveSelection.tracking.yAbs*。デトレンド前）のうち、
%           点を採れた列（found*）だけ
% 2つのファイルの溝底点は同じ（同じ写真を同じパラメータで検出している）。スクリプトの中で確かめる。
% 写真全体の図の描き方（大きさ・点の大きさ）は multiGrooveOnePhoto.m の
% grooveOnImage_origD_centroid_1104_img2 と、切り出した図の大きさ・点の大きさは
% grooveBtmOnImageTrackOutlier.m の grooveBtmOnImage_centroid_origD_1014_photo8_seg5_715-716ms と同じ。
%
% 前提：Research.prj を開いていること（撮影画像が MATLAB のパス上にあること。
%       reconstructImage で読み直す）。
% 2026/11/11作成
% 2026/11/12 3 の図を追加
% 2026/11/13 4・5 の図を追加

setDefaultIntrpr();
proj = currentProject();
rootFolder = proj.RootFolder;

%% パラメータ
DATE = "1014";         % 読み込む結果の日付（experiments/<DATE>/）
UPSAMPLING = "origD";  % 高解像度化（自動追跡は origD だけ）
BOUND = "inclBound";   % 溝底の判定。1014のデータは ad46b44 以降のコード（3261e62）で作ったので、
                       % 境界値を含める判定（meta.gitCommit で確かめた）
METHOD = "centroid";   % 溝底の抽出法（"centroid" または "localMax"）

% 写真全体の図
MAKE_PHOTO_FIGS = false; % 作るか。2026/11/11 に作成済みなので、作り直すときだけ true にする
IMG_INDICES = 1:8;       % 図にする写真の番号（1〜8）
FIG_SIZE_PHOTO = [30 7]; % 図の大きさ[cm]（写真は横に長い）
MARKER_SIZE_PHOTO = 1;   % 溝底点の大きさ（scatterのSizeData）

% 切り出した図（grooveBtmOnImageTrackOutlier.m と同じ値）
T_WINDOWS = [0.715 0.716]; % 外れを探す時間[s]（1行が1か所）。zeros(0,2) なら作らない
X_HALF = 35;               % 切り出す幅の半分[px]（外れた列を中心に、溝に平行な方向）
Y_HALF = 32;               % 切り出す高さの半分[px]（追跡したyを中心に、溝を横切る方向。上下の隣の溝も入る）
FIG_SIZE_CROP = [14.8 11.1]; % 図の大きさ[cm]
MARKER_SIZE_CROP = 15;     % 溝底点の大きさ（scatterのSizeData）
LEGEND_LOCATION_CROP = "best"; % 凡例の位置。右上だと上隣の溝の点を隠すので、点の少ない所に置く
% 作る図（上の 1〜5）。1・2 は 2026/11/11、3 は 2026/11/12、4 は 2026/11/13 に作成済みなので、
% 作り直すときだけ true にする
MAKE_CROP_FIGS = struct("allPoints",false,"manualVsTrack",false,"trackWithRange",false, ...
    "allPointsWithRange",false,"image",true);

% 凡例の点は SizeData によらず見える大きさで描かれる
COLOR_ALL = "cyan";    % すべての溝底点の色
COLOR_SELECTION = struct("manual","yellow","track","magenta"); % 取り出した溝底点の色（溝の選び方ごと）
COLOR_RANGE = struct("start","red","end","yellow"); % 溝底範囲の始めと終わりの色（darknessProfile.m と同じ）
OVERWRITE = true;      % 進捗報告用の図なので、作り直したときは上書きする

saveDir = fullfile(rootFolder,"results","figures","progress","grooveTracking");
if ~isfolder(saveDir)
    mkdir(saveDir);
end

% タイトル・凡例の表記（docs/rules/figures.md の語彙表の「表記」の列）
LABEL = struct("origD","original","inclBound","inclusive bounds","exclBound","exclusive bounds", ...
    "centroid","centroid","localMax","local maximum","manual","manual","track","tracking");

%% 読み込み
expDir = experimentDir(rootFolder,DATE,Create=false);
manual = loadCycleResult(fullfile(expDir,"cycleResult_" + UPSAMPLING + "_" + DATE + ".mat"));
track = loadCycleResult(fullfile(expDir,"cycleResult_" + UPSAMPLING + "_track_" + DATE + ".mat"));

% grooveSelection.tracking のフィールド名は、抽出法ごとに Cnt / Max で終わる
if METHOD == "centroid"
    suffix = "Cnt";
else
    suffix = "Max";
end
condManual = manual.conditions;
condTrack = track.conditions;
selManual = manual.grooveSelection;
trk = track.grooveSelection.tracking;
numSegments = condManual.numSegments;

% 名前・タイトルに共通の部分
condName = UPSAMPLING + "_" + BOUND + "_" + METHOD;
condTitle = LABEL.(UPSAMPLING) + ", " + LABEL.(BOUND) + ", " + LABEL.(METHOD);
vsTitle = "Groove on image: " + LABEL.manual + " vs " + LABEL.track; % 2 のタイトルの、種類と比較
style = struct("colorAll",COLOR_ALL,"colorSelection",COLOR_SELECTION,"colorRange",COLOR_RANGE,"label",LABEL);

%% 切り出す範囲（grooveBtmOnImageTrackOutlier.m と同じ求め方）
% audio.signal は vertcat(ycoords{:}) を並べたものなので、セグメントごとの列数の累積和で
% サンプル番号をセグメント k とその中の列 col に対応づける
fs = track.(METHOD).audio.fs;
sigTrack = track.(METHOD).audio.signal;
sigManual = manual.(METHOD).audio.signal;
nSamples = (1:numel(sigTrack))';
countsAll = cellfun(@numel,track.(METHOD).ycoords);
lastIdxAll = cumsum(countsAll);

numCrops = size(T_WINDOWS,1);
crops = struct("tWin",cell(1,numCrops),"iImg",[],"jSegment",[],"col",[],"y",[]);
for iCrop = 1:numCrops
    tWin = T_WINDOWS(iCrop,:);
    inWin = find(nSamples/fs >= tWin(1) & nSamples/fs <= tWin(2));
    [~,iMax] = max(abs(sigTrack(inWin) - sigManual(inWin)));
    nOutlier = inWin(iMax);

    k = find(lastIdxAll >= nOutlier,1);
    col = nOutlier - (lastIdxAll(k) - countsAll(k));
    iImg = ceil(k/numSegments);
    jSegment = k - (iImg-1)*numSegments;

    % 追跡したデトレンド前のy（写真ごとの配列）から、その列のyを取り出す
    kFirst = (iImg-1)*numSegments + 1;
    yAbsPhoto = trk.("yAbs" + suffix){iImg};
    yOutlier = yAbsPhoto(sum(countsAll(kFirst:k-1)) + col);

    crops(iCrop) = struct("tWin",tWin,"iImg",iImg,"jSegment",jSegment,"col",col,"y",yOutlier);
    fprintf("%g-%g ms の外れ：t = %.6f s、写真%d・区間%d・%d列目、追跡したy = %.2f px\n", ...
        tWin*1e3,nOutlier/fs,iImg,jSegment,col,yOutlier);
end

%% 写真ごとに、溝底点を取り出して図を作る
if MAKE_PHOTO_FIGS
    imgList = union(IMG_INDICES,[crops.iImg]); %#ok<UNRCH> MAKE_PHOTO_FIGS で切り替える
else
    imgList = unique([crops.iImg]);
end

for iImg = imgList
    ks = (iImg-1)*numSegments + (1:numSegments);

    %% 溝底点（写真1枚分）
    [pks,xQuery,~,xOffsets] = mergeSegmentPoints(manual.(METHOD).pts(ks),QueryStep=trk.queryStep);
    pksTrackFile = mergeSegmentPoints(track.(METHOD).pts(ks),QueryStep=trk.queryStep);
    if ~isequal(pks,pksTrackFile)
        error("grooveOnImageManualAndTrack:pointsMismatch", ...
            "写真%d：manual と track のファイルで溝底点が違います。",iImg);
    end

    imgs = reconstructImage(condManual,iImg);
    photoImg = [imgs.img]; % 高さは同じなので横に連結できる
    if size(photoImg,2) ~= numel(xQuery)
        error("grooveOnImageManualAndTrack:widthMismatch", ...
            "写真%d：画像の幅(%d)が xQuery の長さ(%d)と違います。",iImg,size(photoImg,2),numel(xQuery));
    end

    %% 従来法（manual）で取り出した溝底点
    pksManualCells = cell(numSegments,1);
    for jSegment = 1:numSegments
        k = ks(jSegment);
        segPts = manual.(METHOD).pts(k);
        segPks = vertcat(segPts.peakCells{:});
        [p1,~,pksCorCell] = fitGroove(jSegment,[],zeros(1,2),segPts.width,condManual.hPrl,{segPks}, ...
            P1=selManual.p1(k,:),P2=selManual.p2(k,:));
        pksCor = pksCorCell{1};
        grooveCenter = findGrooveCenter(pksCor,p1(2), ...
            BinWidth=condManual.binWidth,MinPeakHeight=condManual.thHist);
        % extractGrooveShape と同じ範囲の点を選ぶ
        inGroove = (pksCor(:,2) >= grooveCenter - condManual.tol) & ...
            (pksCor(:,2) <= grooveCenter + condManual.tol);

        % 選んだ点から音声の y を作り直し、保存した ycoords と一致するかを確かめる
        shape = extractGrooveShape(pksCor,grooveCenter,(1:segPts.width)',Tolerance=condManual.tol);
        shape = detrendGrooveShape(shape,PolyDegree=condManual.polyDegree);
        if max(abs(shape(:,2) - manual.(METHOD).ycoords{k})) > 1e-9
            error("grooveOnImageManualAndTrack:manualMismatch", ...
                "写真%d・区間%d：作り直した y が、保存した ycoords と違います。",iImg,jSegment);
        end

        % 傾きを補正する前の、写真1枚分の座標に戻す
        pksManualCells{jSegment} = [segPks(inGroove,1) + xOffsets(jSegment), segPks(inGroove,2)];
    end
    pksManual = vertcat(pksManualCells{:});

    %% 自動追跡（track）で取り出した溝底点
    yAbs = trk.("yAbs" + suffix){iImg};
    found = trk.("found" + suffix){iImg};
    pksTrack = [xQuery(found), yAbs(found)];
    if ~all(ismember(pksTrack,pks,"rows"))
        error("grooveOnImageManualAndTrack:trackNotDetected", ...
            "写真%d：追跡で採った点の中に、溝底点に無い点があります。",iImg);
    end

    fprintf("写真%d：溝底点 %d 点、manual %d 点、track %d 点（列の数 %d）\n", ...
        iImg,size(pks,1),size(pksManual,1),size(pksTrack,1),numel(xQuery));

    %% 写真全体の図
    if MAKE_PHOTO_FIGS && ismember(iImg,IMG_INDICES)
        partName = "_" + DATE + "_img" + iImg; %#ok<UNRCH> MAKE_PHOTO_FIGS で切り替える
        partTitle = "data " + DATE + ", photo " + iImg;
        xRange = 1:size(photoImg,2);
        yRange = 1:size(photoImg,1);

        % 1. すべての溝底点
        fig = plotPointsOnImage(photoImg,xRange,yRange,pks,FIG_SIZE_PHOTO,MARKER_SIZE_PHOTO,COLOR_ALL, ...
            "Groove on image (" + condTitle + ", " + partTitle + ")");
        saveFigure(fig,saveDir,"grooveOnImage_" + condName + partName,Overwrite=OVERWRITE);
        close(fig);

        % 2. 1 の上に、従来法と自動追跡で取り出した溝底点
        fig = plotManualVsTrack(photoImg,xRange,yRange,pks,pksManual,pksTrack, ...
            FIG_SIZE_PHOTO,MARKER_SIZE_PHOTO,style,"northeast", ...
            vsTitle + " (" + condTitle + ", " + partTitle + ")");
        saveFigure(fig,saveDir,"grooveOnImage_manualVsTrack_" + condName + partName,Overwrite=OVERWRITE);
        close(fig);
    end

    %% 切り出した図（座標は区間の中の px）
    for crop = crops([crops.iImg] == iImg)
        j = crop.jSegment;
        segImg = imgs(j).img;
        xRange = max(1,crop.col-X_HALF) : min(size(segImg,2),crop.col+X_HALF);
        yRange = max(1,round(crop.y)-Y_HALF) : min(size(segImg,1),round(crop.y)+Y_HALF);
        toSegment = @(p) [p(:,1) - xOffsets(j), p(:,2)]; % 写真1枚分の座標から、区間の中の座標へ

        rangeMs = round(crop.tWin*1e3);
        partName = sprintf("_%s_img%d_seg%d_%d-%dms",DATE,iImg,j,rangeMs);
        partTitle = sprintf("data %s, photo %d, segment %d, %d-%d ms",DATE,iImg,j,rangeMs);

        % タイトルは図の幅に収まらないので2行に分ける（書く情報と順は写真全体の図と同じ）
        % 1. すべての溝底点
        if MAKE_CROP_FIGS.allPoints
            fig = plotPointsOnImage(segImg,xRange,yRange,toSegment(pks),FIG_SIZE_CROP,MARKER_SIZE_CROP, ...
                COLOR_ALL,["Groove on image", "(" + condTitle + ", " + partTitle + ")"]);
            saveFigure(fig,saveDir,"grooveOnImage_" + condName + partName,Overwrite=OVERWRITE);
            close(fig);
        end

        % 2. 1 の上に、従来法と自動追跡で取り出した溝底点
        if MAKE_CROP_FIGS.manualVsTrack
            fig = plotManualVsTrack(segImg,xRange,yRange,toSegment(pks),toSegment(pksManual), ...
                toSegment(pksTrack),FIG_SIZE_CROP,MARKER_SIZE_CROP,style,LEGEND_LOCATION_CROP, ...
                [vsTitle, "(" + condTitle + ", " + partTitle + ")"]);
            saveFigure(fig,saveDir,"grooveOnImage_manualVsTrack_" + condName + partName,Overwrite=OVERWRITE);
            close(fig);
        end

        if MAKE_CROP_FIGS.trackWithRange || MAKE_CROP_FIGS.allPointsWithRange
            [rangeStart,rangeEnd] = grooveBottomRange(imgs(j),condTrack,track.(METHOD).pts(ks(j)),METHOD);
        end

        % 3. 1 の上に、溝底範囲と、自動追跡で取り出した溝底点
        if MAKE_CROP_FIGS.trackWithRange
            fig = plotTrackWithRange(segImg,xRange,yRange,toSegment(pks),rangeStart,rangeEnd, ...
                toSegment(pksTrack),FIG_SIZE_CROP,MARKER_SIZE_CROP,style,LEGEND_LOCATION_CROP, ...
                ["Groove on image", "(" + condTitle + ", " + LABEL.track + ", " + partTitle + ")"]);
            saveFigure(fig,saveDir,"grooveOnImage_" + condName + "_track" + partName,Overwrite=OVERWRITE);
            close(fig);
        end

        % 4. 1 の上に、溝底範囲だけ（3 から自動追跡の点を除いた図）
        if MAKE_CROP_FIGS.allPointsWithRange
            fig = plotPointsWithRange(segImg,xRange,yRange,toSegment(pks),rangeStart,rangeEnd, ...
                FIG_SIZE_CROP,MARKER_SIZE_CROP,style,LEGEND_LOCATION_CROP, ...
                ["Groove on image", "(" + condTitle + ", " + partTitle + ")"]);
            saveFigure(fig,saveDir,"grooveOnImage_" + condName + partName + "_grooveBtmRange", ...
                Overwrite=OVERWRITE);
            close(fig);
        end

        % 5. 写真だけ（1〜4 と同じ範囲）。溝底点を描かないので種類は image にし、条件は書かない。
        % タイトルは1行に収まるが、1〜4 と描画領域の大きさをそろえるために2行にする
        if MAKE_CROP_FIGS.image
            fig = plotImageInRange(segImg,xRange,yRange,FIG_SIZE_CROP,["Image", "(" + partTitle + ")"]);
            saveFigure(fig,saveDir,"image" + partName,Overwrite=OVERWRITE);
            close(fig);
        end
    end
end


%% ローカル関数
function fig = plotImageInRange(img,xRange,yRange,figSize,titleStr)
% 写真 img の yRange 行・xRange 列を、座標 xRange・yRange で描く。
% 写真の表示範囲は [0 255] に固定する（docs/rules/figures.md「撮影画像の表示」）
    fig = createFigure([0 0 figSize]);
    tl = tiledlayout(fig,1,1,Padding="compact");
    ax = nexttile(tl);
    imagesc(ax,img(yRange,xRange),XData=xRange([1 end]),YData=yRange([1 end]));
    colormap(ax,gray); clim(ax,[0 255]);
    axis(ax,"image");
    xlabel(ax,"$x$ [px]");
    ylabel(ax,"$y$ [px]");
    title(ax,titleStr);
end

function [fig,hPoints] = plotPointsOnImage(img,xRange,yRange,pks,figSize,markerSize,color,titleStr)
% plotImageInRange の図に、その範囲の溝底点を重ねる
    fig = plotImageInRange(img,xRange,yRange,figSize,titleStr);
    ax = fig.CurrentAxes;
    hold(ax,"on");
    pks = pointsInView(pks,xRange,yRange);
    hPoints = scatter(ax,pks(:,1),pks(:,2),markerSize,color,"filled","o");
    hold(ax,"off");
end

function fig = plotManualVsTrack(img,xRange,yRange,pks,pksManual,pksTrack,figSize,markerSize,style, ...
    legendLocation,titleStr)
% plotPointsOnImage の図に、従来法と自動追跡で取り出した溝底点を重ね、凡例のクリックで
% 表示を切り替えられるようにする
    label = style.label;
    [fig,hAll] = plotPointsOnImage(img,xRange,yRange,pks,figSize,markerSize,style.colorAll,titleStr);
    ax = fig.CurrentAxes;
    hold(ax,"on");
    pksManual = pointsInView(pksManual,xRange,yRange);
    pksTrack = pointsInView(pksTrack,xRange,yRange);
    hManual = scatter(ax,pksManual(:,1),pksManual(:,2),markerSize,style.colorSelection.manual,"filled","o");
    hTrack = scatter(ax,pksTrack(:,1),pksTrack(:,2),markerSize,style.colorSelection.track,"filled","o");
    hold(ax,"off");
    lgd = legend(ax,[hAll hManual hTrack],["all groove-bottom points", label.manual, label.track], ...
        Location=legendLocation);
    lgd.ItemHitFcn = @togglevisibility;
end

function [fig,hPoints,labels] = plotPointsWithRange(img,xRange,yRange,pks,rangeStart,rangeEnd,figSize, ...
    markerSize,style,legendLocation,titleStr)
% plotPointsOnImage の図に、溝底範囲の始めと終わりをこの順に重ね、凡例のクリックで表示を
% 切り替えられるようにする。hPoints・labels は凡例に渡した点のハンドルと名前（点を足すときに使う）
    [fig,hAll] = plotPointsOnImage(img,xRange,yRange,pks,figSize,markerSize,style.colorAll,titleStr);
    ax = fig.CurrentAxes;
    hold(ax,"on");
    rangeStart = pointsInView(rangeStart,xRange,yRange);
    rangeEnd = pointsInView(rangeEnd,xRange,yRange);
    hStart = scatter(ax,rangeStart(:,1),rangeStart(:,2),markerSize,style.colorRange.start,"filled","o");
    hEnd = scatter(ax,rangeEnd(:,1),rangeEnd(:,2),markerSize,style.colorRange.end,"filled","o");
    hold(ax,"off");
    hPoints = [hAll hStart hEnd];
    labels = ["all groove-bottom points", "groove-bottom range: start", "groove-bottom range: end"];
    lgd = legend(ax,hPoints,labels,Location=legendLocation);
    lgd.ItemHitFcn = @togglevisibility;
end

function fig = plotTrackWithRange(img,xRange,yRange,pks,rangeStart,rangeEnd,pksTrack,figSize,markerSize, ...
    style,legendLocation,titleStr)
% plotPointsWithRange の図に、自動追跡で取り出した溝底点を重ね、凡例のクリックで表示を
% 切り替えられるようにする
    [fig,hPoints,labels] = plotPointsWithRange(img,xRange,yRange,pks,rangeStart,rangeEnd,figSize, ...
        markerSize,style,legendLocation,titleStr);
    ax = fig.CurrentAxes;
    hold(ax,"on");
    pksTrack = pointsInView(pksTrack,xRange,yRange);
    hTrack = scatter(ax,pksTrack(:,1),pksTrack(:,2),markerSize,style.colorSelection.track,"filled","o");
    hold(ax,"off");
    lgd = legend(ax,[hPoints hTrack],[labels style.label.track],Location=legendLocation);
    lgd.ItemHitFcn = @togglevisibility;
end

function [rangeStart,rangeEnd] = grooveBottomRange(imgData,cond,segPts,method)
% 区間の写真 imgData から、各列の溝底範囲（暗さが cond.dThresh 以上の区間のうち、幅が cond.wTh 以下の
% もの）の始めと終わりの点 [x y] を求め直す（_1cycle スクリプトと同じ処理）。
% 求めた範囲から溝底点を計算し直し、保存した溝底点 segPts と一致することを確かめる
    map = DarknessMap(imgData);
    map = map.setDiffTF(cond.dThresh);
    extractor = GrooveExtractor(map);
    for x = 1:map.nCols
        [firstIdx,lastIdx] = extractor.findThresholdIntervals(map,x);
        extractor = extractor.findGrooveBottomIntervals(map,x,firstIdx,lastIdx,cond.wTh);
        if method == "centroid"
            y = extractor.extractByCentroid(map,x);
        else
            y = extractor.extractByLocalMax(map,x);
        end
        ySaved = segPts.peakCells{x}(:,2);
        if numel(y) ~= numel(ySaved) || any(abs(y - ySaved) > 1e-9)
            error("grooveOnImageManualAndTrack:rangeMismatch", ...
                "%d列目：求め直した溝底範囲から計算した溝底点が、保存した溝底点と違います。",x);
        end
    end
    rangeStart = vertcat(extractor.startIdxCells{:});
    rangeEnd = vertcat(extractor.endIdxCells{:});
    % dMat の行番号を、元の写真の y に戻す（高解像度化しないときは同じ値）
    rangeStart(:,2) = (rangeStart(:,2) - 1)/map.scaleFactor.row + 1;
    rangeEnd(:,2) = (rangeEnd(:,2) - 1)/map.scaleFactor.row + 1;
end

function pks = pointsInView(pks,xRange,yRange)
% 描く範囲（xRange・yRange の端を含む）にある点だけを残す
    inView = pks(:,1) >= xRange(1) & pks(:,1) <= xRange(end) & ...
        pks(:,2) >= yRange(1) & pks(:,2) <= yRange(end);
    pks = pks(inView,:);
end
