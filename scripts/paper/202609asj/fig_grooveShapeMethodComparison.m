% fig_grooveShapeMethodComparison.m
% 音響学会2026年9月 原稿用のFigure（fig_grooveShapeComparisonと2枚で1段=79mm）
% 1枚のimg_small（I_IMG枚目の写真をNUM_SEGMENTS等分したI_SEGMENT番目）の
% origD(高解像度化なし)から、局所的最大値法と重心法で溝1本ぶんの形状を抽出し
% 重ねてプロットする
% fig_grooveShapeComparison.m が高解像度化の条件を比べるのに対し、
% こちらは溝底抽出の手法を比べる。定数と描画の設定はそちらに合わせてある
%
% 溝1本の選び方は1周分のパイプライン（pkCentroidAndLocalMax_resample_1cycle.m）と
% 変えてある。パイプラインはfitGrooveのginputで溝中心をクリックさせるが、
% ここでは表示するxの範囲が狭く溝の傾きが無視できるので、
% 溝中心のy座標をY_GROOVEで直接与え、±TOL_DISTANCE内の候補点を採る

setDefaultIntrpr();

proj = currentProject();
saveDir = fullfile(proj.RootFolder,"results","figures","paper","202609asj");
if ~isfolder(saveDir)
    mkdir(saveDir);
end
figName = "fig_grooveShapeMethodComparison";

%% パラメータ
% 画像の指定
NUM_IMAGES = 8;    % レコードを8回に分けて撮影している
NUM_SEGMENTS = 10; % 細長い画像を10等分する
I_IMG = 1;         % 何枚目の写真か
I_SEGMENT = 1;     % その写真を10等分したうちの何番目か

% 1周分のパイプラインから引き継ぐ定数
L_MASK = 20;       % omitMaskで端の黒いマスクを落とすluminanceの閾値
TOL_DISTANCE = 4;  % 溝中心からこの距離[px]以内の候補点を同じ溝とみなす

% 他の202609asjスクリプトと同じ溝底検出の定数
D_TH = 0.6; % 暗度の閾値
W_TH = 8;   % 溝底とみなす区間幅の上限[px]

% 追いかける溝の中心のy座標[px]。この画像では溝が約27px間隔で並ぶので、
% 別の溝にしたいときは±27ずつずらす（端に寄りすぎない溝を選ぶこと）
Y_GROOVE = 205;

X_VIEW = [1,50]; % 表示するxの範囲[px]

% 図のサイズ[cm]とフォントサイズ[pt]
% fig_grooveShapeComparisonと横に並べて1段=79mmに収めるので、正方形で38mm
FIG_W = 3.92; FIG_H = 3.95;
FONT_TICK = 8; FONT_LABEL = 9;

%% 画像を読み込んでimg_smallを切り出す
% 1周分のパイプラインと同じく、I_IMG=1が最後のファイルに対応する
filenames = "DSC1111-0000" + string((1:NUM_IMAGES)') + "-ori";
img_gray = rgb2gray(imread(filenames(NUM_IMAGES+1-I_IMG) + ".png"));

imgWidth = size(img_gray,2);
divImgWidth = round(imgWidth / NUM_SEGMENTS);
xarray = [1:divImgWidth:imgWidth imgWidth+1]';
img_small = img_gray(:, xarray(I_SEGMENT):xarray(I_SEGMENT+1)-1);

img_omitMask = omitMask(img_small,L_MASK);
imgData = ImageData(img_omitMask,[I_IMG;I_SEGMENT]);

%% 溝1本の形状を2つの手法で抽出する
% 高解像度化はしないのでorigDだけを使う
origD = DarknessMap(imgData);
lgdNames = ["local maximum","centroid"];

d = setDiffTF(origD,D_TH);

% dMatの列インデックスを元画像のx座標に直す（origDなのでscaleFactorは1）
xCoord = 1 + (0:d.nCols-1)/d.scaleFactor.col;
colIdx = find(xCoord >= X_VIEW(1) & xCoord <= X_VIEW(2));

% 列1が局所的最大値法、列2が重心法。2手法とも同じ溝底区間から求めるので
% 1回のループでまとめて計算する
y = NaN(numel(colIdx),numel(lgdNames));

extractor = GrooveExtractor(d);
for i = 1:numel(colIdx)
    x = colIdx(i);
    [firstIdx,lastIdx] = extractor.findThresholdIntervals(d,x);
    [extractor,~,~,numPeaks] = extractor.findGrooveBottomIntervals(d,x,firstIdx,lastIdx,W_TH);
    if numPeaks == 0
        continue % この列では溝底が見つからなかった
    end

    % extractByLocalMax/extractByCentroidは元画像のy座標を返すのでそのまま比較できる
    candCell = {extractor.extractByLocalMax(d,x), extractor.extractByCentroid(d,x)};

    for m = 1:numel(lgdNames)
        cand = candCell{m};
        [dist,iNear] = min(abs(cand - Y_GROOVE));
        if dist <= TOL_DISTANCE
            y(i,m) = cand(iNear);
        end
    end
end

grvX = cell(numel(lgdNames),1);
grvY = cell(numel(lgdNames),1);

for m = 1:numel(lgdNames)
    % 抽出に失敗した列を埋める（パイプラインと同じ扱い）
    nMissing = sum(isnan(y(:,m)));
    if nMissing > 0
        fprintf("%s: %d/%d 列で溝底が採れなかったので線形補間しました\n", ...
            lgdNames(m), nMissing, size(y,1));
    end

    grvX{m} = xCoord(colIdx)';
    grvY{m} = fillmissing(y(:,m),"linear");
end

%% 描画
fig = createFigure([0 0 FIG_W FIG_H]);
ax = axes(fig);
hold(ax,"on");
for m = 1:numel(lgdNames)
    plot(ax,grvX{m},grvY{m},"-"); % 線種は実線、色は既定の順番
end
hold(ax,"off");

% 原稿ではキャプションを付けるので図中のタイトルは出さない
xlim(ax,X_VIEW);
xlabel(ax,"$x$"); ylabel(ax,"$y$");
% boxがoffだと右と上に軸線が無く、exportgraphicsがデータや凡例の右端で
% 切るため出力幅が安定しない。枠を付けて切り取り位置を確定させる
box(ax,"on");

% 凡例はTightInsetに含まれないのでaxesの内側に置く
lgd = legend(ax,lgdNames,Location="best");
lgd.FontSize = FONT_TICK;
lgd.ItemTokenSize = [10 10]; % 凡例の線の部分を詰める
legend(ax,"boxoff");

% フォントサイズ（原稿に等倍で貼る前提）
ax.FontSize = FONT_TICK;
ax.LabelFontSizeMultiplier = 1; % 既定の1.1倍を無効にして明示指定を効かせる
ax.XLabel.FontSize = FONT_LABEL;
ax.YLabel.FontSize = FONT_LABEL;

tightenAxes(ax); % フォントサイズ確定後に呼ぶ

%% 保存
savePaperFigure(fig,saveDir,figName,FIG_W,FIG_H);
