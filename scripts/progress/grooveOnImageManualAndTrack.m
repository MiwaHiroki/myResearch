% grooveOnImageManualAndTrack.m
% 進捗報告用。1周分の結果について、写真1枚（1/8周分）ごとに次の2枚の図を作り、
% results/figures/progress/grooveTracking/ に保存する。
%   1. 写真に、すべての溝底点を重ねた図（MAKE_POINTS_FIG が true のときだけ）
%   2. 1 の上に、次の2通りで取り出した溝底点を色を変えて重ねた図。凡例のクリックで、
%      点の表示を切り替えられる（togglevisibility）
%      - 従来法（manual。fitGroove で区間ごとにクリックして溝を選ぶ。1周で80回以上の ginput）
%      - 自動追跡（track。trackGroove。写真1枚につき1回のクリック）
%      2つの点はほとんど同じ位置にあり、後に描く track が上に来る。manual だけにある点は
%      manual の色で見える。
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
% 図の描き方（大きさ・点の大きさ・色）は multiGrooveOnePhoto.m の
% grooveOnImage_origD_centroid_1104_img2 と同じ。
%
% 前提：Research.prj を開いていること（撮影画像が MATLAB のパス上にあること。
%       reconstructImage で読み直す）。
% 2026/11/11作成

setDefaultIntrpr();
proj = currentProject();
rootFolder = proj.RootFolder;

%% パラメータ
DATE = "1014";         % 読み込む結果の日付（experiments/<DATE>/）
UPSAMPLING = "origD";  % 高解像度化（自動追跡は origD だけ）
BOUND = "inclBound";   % 溝底の判定。1014のデータは ad46b44 以降のコード（3261e62）で作ったので、
                       % 境界値を含める判定（meta.gitCommit で確かめた）
METHOD = "centroid";   % 溝底の抽出法（"centroid" または "localMax"）
IMG_INDICES = 1:8;     % 図にする写真の番号（1〜8）
MAKE_POINTS_FIG = false; % 1（すべての溝底点だけの図）も作るか。2026/11/11 に作成済みなので、
                         % 作り直すときだけ true にする

FIG_SIZE = [30 7];     % 図の大きさ[cm]（写真は横に長い。grooveOnImage_origD_centroid_1104_img2 と同じ）
MARKER_SIZE = 1;       % 溝底点の大きさ（scatterのSizeData。grooveOnImage_origD_centroid_1104_img2 と同じ）
                       % 凡例の点は SizeData によらず見える大きさで描かれる
COLOR_ALL = "cyan";    % すべての溝底点の色
COLOR_SELECTION = struct("manual","yellow","track","magenta"); % 取り出した溝底点の色（溝の選び方ごと）
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
selManual = manual.grooveSelection;
trk = track.grooveSelection.tracking;
numSegments = condManual.numSegments;

% 名前・タイトルに共通の部分
condName = UPSAMPLING + "_" + BOUND + "_" + METHOD;
condTitle = LABEL.(UPSAMPLING) + ", " + LABEL.(BOUND) + ", " + LABEL.(METHOD);

for iImg = IMG_INDICES
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

    partName = "_" + DATE + "_img" + iImg;
    partTitle = "data " + DATE + ", photo " + iImg;

    %% 1. すべての溝底点
    if MAKE_POINTS_FIG
        titlePoints = "Groove on image (" + condTitle + ", " + partTitle + ")"; %#ok<UNRCH> MAKE_POINTS_FIG で切り替える
        fig = plotPointsOnImage(photoImg,pks,FIG_SIZE,MARKER_SIZE,COLOR_ALL,titlePoints);
        saveFigure(fig,saveDir,"grooveOnImage_" + condName + partName,Overwrite=OVERWRITE);
        close(fig);
    end

    %% 2. 1 の上に、従来法と自動追跡で取り出した溝底点
    [fig,hAll] = plotPointsOnImage(photoImg,pks,FIG_SIZE,MARKER_SIZE,COLOR_ALL, ...
        "Groove on image: " + LABEL.manual + " vs " + LABEL.track + " (" + condTitle + ", " + partTitle + ")");
    ax = fig.CurrentAxes;
    hold(ax,"on");
    hManual = scatter(ax,pksManual(:,1),pksManual(:,2),MARKER_SIZE,COLOR_SELECTION.manual,"filled","o");
    hTrack = scatter(ax,pksTrack(:,1),pksTrack(:,2),MARKER_SIZE,COLOR_SELECTION.track,"filled","o");
    hold(ax,"off");
    lgd = legend(ax,[hAll hManual hTrack],["all groove-bottom points", LABEL.manual, LABEL.track], ...
        Location="northeast");
    lgd.ItemHitFcn = @togglevisibility;
    saveFigure(fig,saveDir,"grooveOnImage_manualVsTrack_" + condName + partName,Overwrite=OVERWRITE);
    close(fig);
end


%% ローカル関数
function [fig,hPoints] = plotPointsOnImage(img,pks,figSize,markerSize,color,titleStr)
% 写真に溝底点を重ねる。写真の表示範囲は [0 255] に固定する（docs/rules/figures.md「撮影画像の表示」）
    fig = createFigure([0 0 figSize]);
    tl = tiledlayout(fig,1,1,Padding="compact");
    ax = nexttile(tl);
    imagesc(ax,img);
    colormap(ax,gray); clim(ax,[0 255]);
    axis(ax,"image");
    hold(ax,"on");
    hPoints = scatter(ax,pks(:,1),pks(:,2),markerSize,color,"filled","o");
    hold(ax,"off");
    xlabel(ax,"$x$ [px]");
    ylabel(ax,"$y$ [px]");
    title(ax,titleStr);
end
