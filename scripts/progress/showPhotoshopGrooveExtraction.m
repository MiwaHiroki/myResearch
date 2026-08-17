% showPhotoshopGrooveExtraction.m
% scripts/archive/showImage.mをもとに作成。
% Photoshopで8xに高解像度化した画像に対して重心法・局所的最大値法を適用し、
% 元画像（高解像度化前）と比較するスライド掲載用の図を3枚作成する。
%
% 出力（すべてPNG）:
%   1. 高解像度化を行った画像の一部分
%   2. 1に重心法・局所的最大値法の抽出点を重ねた画像
%   3. 高解像度化を行う前の画像の対応部分

setDefaultIntrpr();
proj = currentProject();
rootFolder = proj.RootFolder;

IMG_INDEX = 3; % DSC1111-00003（showImage.mと同じ画像）

oriPath = fullfile(rootFolder,"data","pictures","1111","original", ...
    "DSC1111-0000"+num2str(IMG_INDEX)+"-ori.png");
x8Path = fullfile(rootFolder,"data","pictures","1111","8x", ...
    "DSC1111-0000"+num2str(IMG_INDEX)+"-8x.png");

imgOri_g = rgb2gray(imread(oriPath));
img8x_g = rgb2gray(imread(x8Path));

[hOri,wOri] = size(imgOri_g);
[h8x,w8x] = size(img8x_g);
rowScale = h8x/hOri; % 縦方向(溝を横切る方向)の拡大率
colScale = w8x/wOri; % 横方向の拡大率

% 元画像上での切り出し範囲（溝が複数本きれいに写る範囲を選定済み）
ROW_RANGE = 90:170;
COL_RANGE = 1000:1080;

% 対応する高解像度画像上の範囲（scaleFactorと同じ「(idx-1)*scale+1」の対応付け）
rowRange8x = (round((ROW_RANGE(1)-1)*rowScale)+1) : (round((ROW_RANGE(end)-1)*rowScale)+1);
colRange8x = (round((COL_RANGE(1)-1)*colScale)+1) : (round((COL_RANGE(end)-1)*colScale)+1);

cropOri = imgOri_g(ROW_RANGE, COL_RANGE);
crop8x = img8x_g(rowRange8x, colRange8x);

imgDataOri = ImageData(cropOri, [IMG_INDEX;0]);
imgData8x = ImageData(crop8x, [IMG_INDEX;0]);

% 保存先
date = "0817";
dir = mkdirFromDate(rootFolder,date);

%% 図1: 高解像度化を行った画像の一部分
% ImageData.showImg()はXAxisLocationを上にするため、title()だとx軸ラベルと
% 重なる。そのため図の下にテキストボックスでキャプションを付ける。
fig1 = createFigure([0 0 10 10]);
imgData8x.showImg();
addCaptionBelow(fig1,"Photoshop 8x upscaled image (segment)");
exportgraphics(fig1, dir+"1_photoshopHighRes_segment.png","Resolution",300,"BackgroundColor","white");
close(fig1);

%% 溝底候補点の抽出（重心法・局所的最大値法）
% CLAUDE.mdのGrooveExtractor呼び出し方に準拠。
% Photoshopで既に高解像度化済みの画像なので、DarknessMap側の
% dResample/dInterpによる再アップサンプリングは行わない（scaleFactorは1のまま）。
D_THRESH = 0.6;
WIDTH_THRESH = 80; % 高解像度画像(8x)上での溝底幅の上限[px]

map = DarknessMap(imgData8x);
map = map.setDiffTF(D_THRESH);
extractor = GrooveExtractor(map);

ptsCentroid = GroovePointCloud(map);
ptsLocalMax = GroovePointCloud(map);

for x = 1:map.nCols
    [firstIdx,lastIdx] = extractor.findThresholdIntervals(map,x);
    [extractor,~,~,numPeaks] = extractor.findGrooveBottomIntervals(map,x,firstIdx,lastIdx,WIDTH_THRESH);
    centroidY = extractor.extractByCentroid(map,x);
    localMaxY = extractor.extractByLocalMax(map,x);
    ptsCentroid.pksCell{x} = [x*ones(numPeaks,1), centroidY];
    ptsLocalMax.pksCell{x} = [x*ones(numPeaks,1), localMaxY];
end

pksCentroid = vertcat(ptsCentroid.pksCell{:});
pksLocalMax = vertcat(ptsLocalMax.pksCell{:});

%% 図2: 高解像度画像に重心法・局所的最大値法の抽出点を重ねる
fig2 = createFigure([0 0 10 10]);
imgData8x.showImg();
hold on;
hCentroid = scatter(pksCentroid(:,1),pksCentroid(:,2),10,'red','filled','o');
hLocalMax = scatter(pksLocalMax(:,1),pksLocalMax(:,2),18,'cyan','x','LineWidth',1.0);
legend([hCentroid,hLocalMax],{'centroid method','local maximum method'}, ...
    'Location','southoutside','Orientation','horizontal');
addCaptionBelow(fig2,"Groove extraction on the upscaled image");
exportgraphics(fig2, dir+"2_photoshopHighRes_centroid_localMax.png","Resolution",300,"BackgroundColor","white");
close(fig2);

%% 図3: 高解像度化を行う前の画像の対応部分
fig3 = createFigure([0 0 10 10]);
imgDataOri.showImg();
addCaptionBelow(fig3,"Original image before upscaling (corresponding segment)");
exportgraphics(fig3, dir+"3_original_segment.png","Resolution",300,"BackgroundColor","white");
close(fig3);

%% ローカル関数
function addCaptionBelow(fig,str)
% title()はImageData.showImg()のXAxisLocation="top"と重なるため、
% 図の下にキャプションを付ける。
annotation(fig,"textbox",[0 0 1 0.08],"String",str, ...
    "EdgeColor","none","HorizontalAlignment","center", ...
    "VerticalAlignment","middle","FontSize",10,"Interpreter","latex");
end
