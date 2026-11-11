% compareInclBoundToExclBound.m
% 溝底の判定で境界値を含めるかどうか（コミット ad46b44、2026-08-14 で変更）によって、
% 溝底点（重心法）がどう変わるかを、写真1枚について図にする。
%   exclBound：境界値を含めない（暗さ D > D_THRESH、区間の幅 < WIDTH_THRESH）。ad46b44 より前の
%              DarknessValue の判定で、0731のデータ（pkCentroid_1cycle.m）はこれで作った。
%              今の src/ には無いので、ローカル関数 detectExclBound で同じ判定を書き直している
%   inclBound：境界値を含める（D >= D_THRESH、幅 <= WIDTH_THRESH）。今の DarknessMap・GrooveExtractor
%              で、1104のデータ（grooveHist_Ncycle.m など）はこれで作った
% パラメータの値（L_MASK・D_THRESH・WIDTH_THRESH）はどちらも同じにする。
% 同じ列で y の差が MATCH_TOL 未満の点を「両方にある点」とし、片方だけにある点の色を変えて
% 写真に重ねる。写真全体の図と、区間 SEG_INDEX を切り出した図を results/<date>/ に保存する。
% 前提：Research.prj を開いていること（撮影画像が MATLAB のパス上にあること）。
% 2026/11/11作成

setDefaultIntrpr();
proj = currentProject();
rootFolder = proj.RootFolder;

%% パラメータ
IMG_INDEX = 2;          % 図にする写真の番号（1〜8）
SEG_INDEX = 5;          % 切り出して拡大する区間の番号（1〜10）。写真2では inclBound だけの点が最も多い
NUM_IMAGES = 8;         % レコードを8回に分けて撮影しているので8枚
NUM_SEGMENTS = 10;      % 細長い画像を10等分する
L_MASK = 20;            % Maskを取るためのluminanceのthreshold（pkCentroid_1cycle.m・grooveHist_Ncycle.m と同じ）
D_THRESH = 0.6;         % 暗さのしきい値（同上）
WIDTH_THRESH = 8;       % 溝底区間の幅のしきい値[px]（同上）
MATCH_TOL = 0.5;        % 同じ列で y の差がこれ未満なら「両方にある点」とする[px]
MAX_WIDTH_SHOWN = 19;   % 区間の幅の分布を表示する最大の幅[px]

% inclBound の点が保存済みの cycleResult の点と一致するかを確かめる（"" なら確かめない）
CHECK_RESULT_FILE = "cycleResult_origD_hist5_1104.mat";
CHECK_DATE = "1104";

FIG_SIZE_PHOTO = [30 7];    % 写真全体の図の大きさ[cm]（写真は横に長い）
FIG_SIZE_SEG = [16 19];     % 区間を切り出した図の大きさ[cm]
LEGEND_LOCATION = "northeast"; % 凡例の位置（描画領域の中。docs/rules/figures.md「凡例」）
LEGEND_ORIENT_PHOTO = "horizontal"; % 写真全体の図の凡例の向き（写真が横に長く、縦に並べると隠れる溝が多いため）
LEGEND_ORIENT_SEG = "vertical";     % 区間を切り出した図の凡例の向き
MARKER_SIZE_PHOTO = 1;      % 写真全体の図の点の大きさ（scatterのSizeData。multiGrooveOnePhoto.m と同じ）
MARKER_SIZE_SEG = 6;        % 区間を切り出した図の点の大きさ
MARKER_SIZE_LEGEND = 5;     % 凡例の印の大きさ（点が小さいと凡例で見えないため、別に描く）
COLOR_BOTH = "cyan";
COLOR_EXCL = "yellow";
COLOR_INCL = "red";

% 保存用
date = "1111";          % 実行日。図は results/<日付>/
OVERWRITE = false;      % results/<日付>/ に同じ名前の図があるときに上書きするか
outDir = mkdirFromDate(rootFolder,date);

% タイトル・凡例の表記（docs/rules/figures.md の語彙表の「表記」の列）
LABEL = struct("origD","original","centroid","centroid", ...
    "exclBound","exclusive bounds","inclBound","inclusive bounds");

%% 写真を読み、両方の判定で溝底点を求める
filenames = strings(NUM_IMAGES,1);
for i=1:NUM_IMAGES
    filenames(i) = "DSC1111-0000" + num2str(i) + "-ori";
end
% reconstructImage が使うフィールドだけを持つ conditions
cond = struct("numImages",NUM_IMAGES,"numSegments",NUM_SEGMENTS,"lMask",L_MASK,"filenames",filenames);
imgs = reconstructImage(cond,IMG_INDEX);

widths = [imgs.width]';
xOffsets = [0; cumsum(widths(1:end-1))];
ptsExcl = cell(NUM_SEGMENTS,1);   % [x y 区間の幅]（xは写真の中の列）
ptsIncl = cell(NUM_SEGMENTS,1);
numErrCols = 0;                   % 旧コードならエラーで止まった列の数
intervalWidths = cell(NUM_SEGMENTS,1); % inclBound の暗さの判定での、すべての区間の幅

for jSegment = 1:NUM_SEGMENTS
    map = DarknessMap(imgs(jSegment));
    map = map.setDiffTF(D_THRESH);

    % inclBound：今の GrooveExtractor（grooveHist_Ncycle.m と同じ呼び方）
    extractor = GrooveExtractor(map);
    segPts = cell(map.nCols,1);
    segWidths = cell(map.nCols,1);
    for x = 1:map.nCols
        [firstIdx,lastIdx] = extractor.findThresholdIntervals(map,x);
        [extractor,btmFirstIdx,btmLastIdx,numPeaks] = ...
            extractor.findGrooveBottomIntervals(map,x,firstIdx,lastIdx,WIDTH_THRESH);
        centroidY = extractor.extractByCentroid(map,x);
        segPts{x} = [(x + xOffsets(jSegment))*ones(numPeaks,1), centroidY, btmLastIdx - btmFirstIdx];
        segWidths{x} = lastIdx - firstIdx;
    end
    ptsIncl{jSegment} = vertcat(segPts{:});
    intervalWidths{jSegment} = vertcat(segWidths{:});

    % exclBound：ad46b44 より前の DarknessValue の判定
    [pts,nErr] = detectExclBound(map.dMat,D_THRESH,WIDTH_THRESH);
    pts(:,1) = pts(:,1) + xOffsets(jSegment);
    ptsExcl{jSegment} = pts;
    numErrCols = numErrCols + nErr;
end
ptsExcl = vertcat(ptsExcl{:});
ptsIncl = vertcat(ptsIncl{:});
intervalWidths = vertcat(intervalWidths{:});

%% 保存済みの cycleResult と照らす（inclBound が、そのデータを作った判定と同じことを確かめる）
if CHECK_RESULT_FILE ~= ""
    res = loadCycleResult(fullfile(experimentDir(rootFolder,CHECK_DATE,Create=false),CHECK_RESULT_FILE));
    ks = (IMG_INDEX-1)*NUM_SEGMENTS + (1:NUM_SEGMENTS);
    savedPks = mergeSegmentPoints(res.centroid.pts(ks));
    isSame = isequal(size(savedPks,1),size(ptsIncl,1)) && ...
        max(abs(sortrows(savedPks) - sortrows(ptsIncl(:,1:2))),[],"all") < 1e-9;
    if ~isSame
        error("compareInclBoundToExclBound:savedPointsMismatch", ...
            "inclBound の点（%d点）が %s の写真%dの点（%d点）と一致しません。", ...
            size(ptsIncl,1),CHECK_RESULT_FILE,IMG_INDEX,size(savedPks,1));
    end
    fprintf("inclBound の点は %s の写真%dの点（重心法）と一致しました。\n",CHECK_RESULT_FILE,IMG_INDEX);
    clear res
end

%% 両方にある点と、片方だけにある点に分ける
[isMatchedExcl,isMatchedIncl] = matchPoints(ptsExcl,ptsIncl,MATCH_TOL);
onlyExcl = ptsExcl(~isMatchedExcl,:);
onlyIncl = ptsIncl(~isMatchedIncl,:);
both = ptsIncl(isMatchedIncl,:);

numCols = sum(widths);
fprintf("\n写真%d（%d列）の溝底点（重心法）\n",IMG_INDEX,numCols);
fprintf("  exclBound：%d点（1列あたり %.2f点）\n",size(ptsExcl,1),size(ptsExcl,1)/numCols);
fprintf("  inclBound：%d点（1列あたり %.2f点）\n",size(ptsIncl,1),size(ptsIncl,1)/numCols);
fprintf("  両方にある点：%d、exclBound だけ：%d、inclBound だけ：%d（うち区間の幅がちょうど %d px：%d）\n", ...
    size(both,1),size(onlyExcl,1),size(onlyIncl,1),WIDTH_THRESH,nnz(onlyIncl(:,3) == WIDTH_THRESH));
fprintf("  旧コードならエラーで止まった列（閾値を超える区間が無い列など）：%d\n",numErrCols);
fprintf("  inclBound だけの点の、区間ごとの数：%s\n", ...
    mat2str(accumarray(segmentOf(onlyIncl(:,1),xOffsets),1,[NUM_SEGMENTS 1])'));
fprintf("\n暗さが D_THRESH 以上の区間の幅（最後の行 − 最初の行）[px] の分布（inclBound の暗さの判定、すべての区間）\n");
widthCounts = histcounts(intervalWidths,-0.5:1:MAX_WIDTH_SHOWN+0.5);
fprintf("  幅 %2d：%6d\n",[0:MAX_WIDTH_SHOWN; widthCounts]);
fprintf("  幅 %d 以上：%d\n",MAX_WIDTH_SHOWN+1,nnz(intervalWidths > MAX_WIDTH_SHOWN));

%% 図
condName = "exclBoundVsInclBound_origD_centroid";
condTitle = LABEL.exclBound + " vs " + LABEL.inclBound + " (" + LABEL.origD + ", " + LABEL.centroid;
photoImg = ImageData([imgs.img],[IMG_INDEX;0]); % 高さは同じなので横に連結できる

% 写真全体
[fig,ax] = plotPointsOnImage(photoImg.img,1,FIG_SIZE_PHOTO,both,onlyExcl,onlyIncl,MARKER_SIZE_PHOTO, ...
    MARKER_SIZE_LEGEND,[COLOR_BOTH COLOR_EXCL COLOR_INCL],LABEL,LEGEND_LOCATION,LEGEND_ORIENT_PHOTO);
title(ax,"Groove on image: " + condTitle + ", photo " + IMG_INDEX + ")");
saveFigure(fig,outDir,"grooveOnImage_" + condName + "_img" + IMG_INDEX,Overwrite=OVERWRITE);

% 区間 SEG_INDEX を切り出す（x は写真全体の図と同じ、写真の中の列）
xRange = xOffsets(SEG_INDEX) + [1 widths(SEG_INDEX)];
inSeg = @(p) p(p(:,1) >= xRange(1) & p(:,1) <= xRange(2),:);
[fig,ax] = plotPointsOnImage(imgs(SEG_INDEX).img,xRange(1),FIG_SIZE_SEG,inSeg(both),inSeg(onlyExcl), ...
    inSeg(onlyIncl),MARKER_SIZE_SEG,MARKER_SIZE_LEGEND,[COLOR_BOTH COLOR_EXCL COLOR_INCL],LABEL, ...
    LEGEND_LOCATION,LEGEND_ORIENT_SEG);
title(ax,["Groove on image: " + LABEL.exclBound + " vs " + LABEL.inclBound, ...
    "(" + LABEL.origD + ", " + LABEL.centroid + ", photo " + IMG_INDEX + ", segment " + SEG_INDEX + ")"]);
saveFigure(fig,outDir,"grooveOnImage_" + condName + "_img" + IMG_INDEX + "_seg" + SEG_INDEX, ...
    Overwrite=OVERWRITE);


%% ローカル関数
function [pts,numErrCols] = detectExclBound(dMat,D_THRESH,WIDTH_THRESH)
% ad46b44 より前の DarknessValue（setDiffTF・getStartEndIdx・getGrooveBtmIdx・extractGrv_cnt）と
% 同じ判定で、溝底点を重心法で求める。高解像度化しない画像（scaleFactor.row = 1）だけを考える。
% 旧コードは、閾値を超える区間が無い列などでエラーになった（numErrCols に数える）。ここでは
% その列の点を無しとして続ける。
% 出力 pts は [x y 区間の幅]（x は dMat の列）。
    diffTF = diff(dMat > D_THRESH);
    nCols = size(dMat,2);
    colPts = cell(nCols,1);
    numErrCols = 0;
    for x = 1:nCols
        startIdx = find(diffTF(:,x)==1)+1;
        endIdx = find(diffTF(:,x)==-1);
        if isempty(startIdx) || isempty(endIdx)
            numErrCols = numErrCols + 1;
            continue
        end
        if endIdx(1)<startIdx(1)
            endIdx = endIdx(2:end);
        end
        if isempty(endIdx)
            numErrCols = numErrCols + 1;
            continue
        end
        if endIdx(end)<startIdx(end)
            startIdx = startIdx(1:end-1);
        end

        btmIdx = find((endIdx-startIdx) < WIDTH_THRESH);
        D_x = dMat(:,x);
        centroidY = zeros(numel(btmIdx),1);
        for k = 1:numel(btmIdx)
            rows = (startIdx(btmIdx(k)):endIdx(btmIdx(k)))';
            centroidY(k) = sum(rows .* D_x(rows)) / sum(D_x(rows));
        end
        colPts{x} = [x*ones(numel(btmIdx),1), centroidY, endIdx(btmIdx)-startIdx(btmIdx)];
    end
    pts = vertcat(colPts{:});
end

function [isMatchedA,isMatchedB] = matchPoints(ptsA,ptsB,tol)
% 同じ列（x が同じ）の点どうしで、y の差が tol 未満のものを1対1で対応づける。
% B の点ごとに、まだ対応していない A の点のうち最も近いものを選ぶ。
    isMatchedA = false(size(ptsA,1),1);
    isMatchedB = false(size(ptsB,1),1);
    [colsA,~,groupA] = unique(ptsA(:,1));
    rowsA = accumarray(groupA,(1:size(ptsA,1))',[],@(r) {r});
    for b = 1:size(ptsB,1)
        iCol = find(colsA == ptsB(b,1),1);
        if isempty(iCol)
            continue
        end
        candidates = rowsA{iCol};
        candidates = candidates(~isMatchedA(candidates));
        [dy,iMin] = min(abs(ptsA(candidates,2) - ptsB(b,2)));
        if ~isempty(dy) && dy < tol
            isMatchedA(candidates(iMin)) = true;
            isMatchedB(b) = true;
        end
    end
end

function iSeg = segmentOf(x,xOffsets)
% 写真の中の列 x が、何番目の区間にあるかを返す
    iSeg = discretize(x,[xOffsets; Inf]);
end

function [fig,ax] = plotPointsOnImage(img,x0,figSize,both,onlyExcl,onlyIncl,markerSize,legendMarkerSize, ...
    colors,label,legendLocation,legendOrientation)
% 撮影画像（左端の列が x0）に、両方にある点・exclBound だけの点・inclBound だけの点を重ねる。
% 片方だけの点が見えるよう、両方にある点を先に描く。凡例は、点が小さくても見えるよう別に描いた印で示し、
% 描画領域の中（legendLocation）に置く
    fig = createFigure([0 0 figSize]);
    tl = tiledlayout(fig,1,1,Padding="compact");
    ax = nexttile(tl);
    imagesc(ax,[x0, x0 + size(img,2) - 1],[1, size(img,1)],img);
    % 撮影画像の表示範囲は [0 255] に固定する（docs/rules/figures.md「撮影画像の表示」）
    colormap(ax,gray); clim(ax,[0 255]);
    axis(ax,"image");
    hold(ax,"on");
    groups = {onlyExcl, onlyIncl};
    names = [label.exclBound + " only", label.inclBound + " only"];
    scatter(ax,both(:,1),both(:,2),markerSize,colors(1),"filled",HandleVisibility="off");
    for k = 1:2
        scatter(ax,groups{k}(:,1),groups{k}(:,2),markerSize,colors(k+1),"filled",HandleVisibility="off");
    end
    % 凡例の順は、比較の Vs と同じ（exclBound → inclBound）
    hLegend = gobjects(3,1);
    for k = 1:2
        hLegend(k) = plot(ax,NaN,NaN,"o",LineStyle="none",MarkerSize=legendMarkerSize, ...
            MarkerFaceColor=colors(k+1),MarkerEdgeColor="none",DisplayName=names(k));
    end
    hLegend(3) = plot(ax,NaN,NaN,"o",LineStyle="none",MarkerSize=legendMarkerSize, ...
        MarkerFaceColor=colors(1),MarkerEdgeColor="none",DisplayName="both");
    hold(ax,"off");
    xlabel(ax,"$x$ [px]");
    ylabel(ax,"$y$ [px]");
    legend(ax,hLegend,Location=legendLocation,Orientation=legendOrientation);
    % 書き出すときにマウスが図の上にあると、座標軸ツールバーが png に写り込むので消す
    ax.Toolbar.Visible = "off";
end
