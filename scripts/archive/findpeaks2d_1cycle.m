%%
% 発表資料作成用
set(0,'defaultTextInterpreter','latex');
set(0,'defaultAxesTickLabelInterpreter','latex');
set(0,'defaultLegendInterpreter','latex');
set(0,'defaultColorbarTickLabelInterpreter','latex');
% set(0,'defaultAxesFontSize',16)



%%
filenameC = cell(8,1);
for j=1:8
    % filenameC{j} = "DSC0" + num2str(j+112) + "_8x";
    filenameC{j} = "DSC1111-0000" + num2str(j) + "-8x";
end

% 画像8枚分のデータを1枚分ずつ格納するCell
amplitudeC = cell(8,1);
x_combC = cell(8,1);
y_combC = cell(8,1);

% 発表資料作成用
% imgWidth = 1000;

imgWidth = 3000; % 1回でimgWidth(pixel)分のx座標を処理
xarray = [1:imgWidth:30000 30001];
% 切り出す画像(img_small)の左端のx座標
% 便宜的に（画像の横のサイズ+1）を加えておく

minh = 0.0; maxh = 0.7; % 溝の底を抽出するには二つの閾値が必要
d = 50; % MinPeakDistance
mind = 50; % MinPeakDistance
minw = 10; % MinPeakWidth
minp = 0.2; % MinPeakProminence
maxp = 0.7; % MaxPeakProminence
th_mask = 20; % Maskを取るためのthreshold, 0付近に設定する
th_prd = 30; % threshold of product (=p.*w)

th_hist = 1000; % threshold of the peak height in the histogram
%%

l = length(xarray)-1;

% 処理の流れ
%{
i番目(i=1~8)の画像をl分割
    -->l分割したうちのj番目(j=1~l)の画像(img_small)について
       x=k(x=1~imgWidth)でピークを見つける
       -->そのx座標におけるピークのx,y座標をtmpPksX,tmpPksYに格納
       -->pksCellのk番目のセルに格納
    -->pksCellを結合してpks（img_smallのピークの座標データ）に格納
    -->平行四辺形を作ってその範囲内の点のx,y座標をxcoords,ycoordsに格納
-->i番目の画像の指定範囲内の点群データをx_combなどに格納
%}


% DSC0113-0120(計8枚)をそれぞれl分割した画像から得たx,y座標をそれぞれ格納
xcoords = cell(8*l,1);
ycoords = cell(8*l,1);
p2 = zeros(2,1);

for i=2:2
    % DSC0120から0113まで1枚ずつ
    % img = imread("./pictures/old/8x/" + filenameC{9-i} + ".png");
    img = imread("./pictures/1111/" + filenameC{9-i} + ".png");
    img_gray = rgb2gray(img);

    for j=1:l % imgWidth(pixel)ごとの画像でピークを見つけ、半自動で点群をグループ化
        img_small = img_gray(:, xarray(j):xarray(j+1)-1);

        % 発表資料作成用
        % img_small = img_gray(901:1900, xarray(j):xarray(j+1)-1);

        % 2026合同発表会ポスター用
        % 写真の切れ目を示した図を作成する
        % img_small = img_gray(:, xarray(j):xarray(j+1)-1);

        [img_omitMask,newWidth] = omitMask(img_small,th_mask);
        z = double(img_omitMask) * (-2/255) + 1;

        pksCell = cell(newWidth,1); % 各x座標におけるピークの(x,y)の組

        for k=1:newWidth % 各x座標についてピークを見つけ、pksCellに格納
            [tmpPks,tmpLocs,w,p] = findpeaks(z(:,k),...
                'MinPeakDistance',d,...
                'MinPeakProminence',minp,...
                'MinPeakHeight',minh);

             % [tmpPks,tmpLocs,w,p] = findpeaks(z(:,k),...
             %    'MinPeakDistance',d,...
             %    'MinPeakHeight',minh);

            % idx = find(p < maxp);

            product = p.*w;
            idx = find(product < th_prd);
            num = length(idx);

            tmpPksX = k * ones(num,1);
            tmpPksY = zeros(num,1);
            tmpPksY(:,1) = tmpLocs(idx);

            pksCell{k,1} = [tmpPksX tmpPksY];
        end

        pks = vertcat(pksCell{:,:}); % pksCellを結合して行列に

        % if j==12
        %     fig = createFigure([0 0 6 6]);
        % else
            fig = figure;
        % end
        % imshow(img_omitMask,"InitialMagnification","fit");
        imshow(img_omitMask);
        axis on;ax=gca;
        set(ax,'YDir','reverse','TickDir','out')
        set(ax,"XAxisLocation","top")
        xlabel("$x$");ylabel("$y$")
        % set(gca,'YDir','normal')
        % title(gca,num2str(filenameC{9-i})+" peak "+num2str(j),'Interpreter','latex');
        hold on;
        scatter(pks(:,1),pks(:,2),3,'filled','c');

        % 発表資料作成用
        % saveas(fig,"./1125/peak dots on DSC1111-00006-peak10.png")

        w_prl = imgWidth; % 平行四辺形の高さ
        h_prl = 60; % 平行四辺形の底辺

        % pksの傾きを補正したpks_corを得る
        [p1,p2,pks_cor] = fitGroove(j,fig,p2,w_prl,h_prl,pks);
        hold off

        binWidth = 5; % BinWidth
        [counts,edges] = histcounts(pks_cor(:,2),'BinWidth',binWidth);
        centers = edges(1:end-1) + diff(edges)/2; % ピークの中心

        [~,histPkLocs] = findpeaks(counts,'MinPeakHeight',th_hist);

        [~,idx_hist] = min(abs(p1(2) - centers(histPkLocs)));
        groove1Center = centers(histPkLocs(idx_hist));
        % p1のy座標に最も近いヒストグラムのピークの位置を見つける。
        % そのhistPkLocsのインデックスがidx。
        % そのピークを含む階級の中心をgroove1Center(1周目の溝の中心)とする
        % 厳密には溝の中心には合致していないと思われる。ほかにいい方法あるかなあ、、

        tol = 25;
        % そのピークの中心からtol(pixel)以内にあるy座標
        y_min = groove1Center - tol;
        y_max = groove1Center + tol;

        idxs = (pks_cor(:,2) >= y_min) & (pks_cor(:,2)<=y_max);
        selected_points_new = pks_cor(idxs,:);

        % i枚目の画像をl分割したうちのj番目の画像のデータをxcoords,ycoordsに格納
        % あとで複数の画像をまとめて正規化するため、ycoordsは0付近にしておく
        xcoords{(i-1)*l+j,1} = selected_points_new(:,1);
        % ycoords{(i-1)*l+j,1} = selected_points_new(:,2) - groove1Center;
        ycoords{(i-1)*l+j,1} = selected_points_new(:,2) - mean(selected_points_new(:,2));

        % 資料作成用
        % %{
        if j==6
            img_j = img_omitMask;
            pks_j = pks(:,1:2);
            pks_cor_j = pks_cor(:,1:2);
            centers_j = centers;
            counts_j = counts;
            idx_tmp_j = histPkLocs(idx_hist)-2:histPkLocs(idx_hist)+2;
            y_min_j = y_min; y_max_j = y_max;
            s_points_j = selected_points_new;

            break;

            %{
            % pkDots (傾き補正前)
            f=figure;
            scatter(pks(:,1),pks(:,2),0.5,'filled');
            ax = gca;
            set(gca,'YDir','reverse','xAxisLocation','top');box on
            xlim([0 1000]);ylim([0 1000]);xticks(0:200:1000);yticks(0:200:1000)
            mySaveForPapers(f,ax,[0 0 5 5],"Peak Dots","$x$","$y$","PkDots_tilted");

            % pkDots (傾き補正後)
            f=figure;
            scatter(pks_cor(:,1),pks_cor(:,2),0.5,'filled');
            ax=gca;
            set(gca,'YDir','reverse','xAxisLocation','top');box on
            xlim([0 1000]);ylim([0 1000]);xticks(0:200:1000);yticks(0:200:1000)
            mySaveForPapers(f,ax,[0 0 5 5],"Peak Dots (tilt corrected)","$x$","$y$","PkDots_tiltCorrected");

            % hist (溝1本分patch+棒グラフの色変更)
            f=figure; barh(centers,counts); ax = gca;
            set(gca,'YDir','reverse','xAxisLocation','top');box on
            xlim([0 1000]);ylim([0 1000]);xticks(0:200:1000);yticks(0:200:1000)
            hold on;
            idx_tmp = histPkLocs(idx_hist)-2:histPkLocs(idx_hist)+2;
            b=barh(centers(idx_tmp),counts(idx_tmp),'r');
            b.EdgeColor = "none";
            yline(y_min);yline(y_max);
            patch([0 1000 1000 0],[y_min y_min y_max y_max],'m',"EdgeColor","none","FaceAlpha",0.1);
            hold off;
            mySaveForPapers(f,ax,[0 0 5 5],"Histogram of $y$ Coordinates","counts","$y$","Hist_1gSelected");

            % pkDots (溝1本分色変更)
            f=figure;ax=gca;
            scatter(pks_cor(:,1),pks_cor(:,2),0.5,'filled')
            set(gca,'YDir','reverse','xAxisLocation','top');box on
            xlim([0 1000]);ylim([0 1000]);xticks(0:200:1000);yticks(0:200:1000)
            hold on
            scatter(selected_points_new(:,1),selected_points_new(:,2),0.5,'filled','r');
            yline(y_min); yline(y_max);
            patch([0 1000 1000 0],[y_min y_min y_max y_max],'m',"EdgeColor","none","FaceAlpha",0.1);
            hold off
            mySaveForPapers(f,ax,[0 0 5 5],"Peak Dots (selected)","$x$","$y$","PkDots_1gSelected");
            %}
        end
        %}
    end

    % 分割したi番目の画像をすべて結合
    x_combC{i} = vertcat(xcoords{(i-1)*l+1:(i-1)*l+l});
    y_combC{i} = vertcat(ycoords{(i-1)*l+1:(i-1)*l+l});

    % 画像1枚分のy座標データを-1から1に正規化
    amplitudeC{i} = (y_combC{i} - min(y_combC{i})) / (max(y_combC{i}) - min(y_combC{i})) * 2 - 1;
end

%%
figure;
plot(selected_points_new(:,2));
xlabel("$x$");ylabel("$y$");
title("Groove Coordinates (centroid method)");
dir = "./data/0325/";
saveas(gcf,dir + "grvCoords_findPeaks.fig");
saveas(gcf,dir + "grvCoords_findPeaks.png");


%%
% データの保存

% save("./data/0106/data.mat","pks_j","pks_cor_j","centers_j","counts_j","idx_tmp_j","y_min_j","y_max_j");

%%
% 2026合同発表会原稿作成用
% D on x=1 & PkDotsOnImg
% colorbarつき 
% colorbarの位置はpositionで良い位置に指定できると思われるが
% めんどくさいのでサボった

% pos = [0 0 12 8];
% fig=createFigure(pos);
% tiledlayout(1,2,"Padding","tight","TileSpacing","tight");
label = ["\textsl{D}","Detected Peaks"]; % legend()の引数
dir="C:\Users\owner\Documents\HirokiMiwa\原稿\2026卒論\発表資料\";

% ax1=nexttile;
% plot(z(1:1000),1:1000);
% hold on;
% scatter(z(pks(1:4,2),1),pks(1:4,2),10,'c','filled','MarkerEdgeColor','k');
% hold off;
% set(ax1,'YDir','reverse')
% set(ax1,'XAxisLocation','top')
% xlim([-1 1])
% 
% colormap(flip(gray));
% colorbar("north","TickLabels","");
% clim([-1 1]);
% xlabel("\textsl{D}")
% ylabel("$y$ ($x$=1)")
% pbaspect([1 1 1])
% 

pos=[0 0 8 7];
% ax1=nexttile;
fig = createFigure(pos);ax1=gca;
plot(z(1:1000))
hold on;
scatter(pks(1:4,2),z(pks(1:4,2),1),10,'c','filled','MarkerEdgeColor','k');
hold off;
ylim([-1 1])

colormap(flip(gray));
c=colorbar("westoutside");
clim([-1 1]);c.TickLabels="";
xticks(ax1,0:200:1000)
ax1.XTickLabelRotation = 45;
% title("$D$ on $x=1$")
xlabel("$y$ ($x=1$)","Interpreter","latex");
ylabel("\textsl{D}","Interpreter","latex");
% legend(label,"Interpreter","latex","FontSize",7);
exportgraphics(fig,dir+"DonX1_west.png","Resolution",600);


pos=[0 0 5 7];
% ax2=nexttile;
fig=createFigure(pos);ax2=gca;
imshow(uint8(img_omitMask),"InitialMagnification","fit");
axis on;
hold on
axis tight
scatter(pks(:,1),pks(:,2),0.5,'cyan','filled');
hold off

% title("Peak Dots on a Image")
xlabel("$x$","Interpreter","latex");
ylabel("$y$","Interpreter","latex");

set(ax2,'YDir','reverse','TickDir','out')
set(ax2,"XAxisLocation","top")
xticks(0:200:1000);yticks(0:200:1000);
ax2.XTickLabelRotation = 45;
exportgraphics(fig,dir+"PkDotsOnImg.png","Resolution",600);


% exportgraphics(fig,dir+"DPeak_PkDotsOnImg.pdf",'ContentType','vector')
% exportgraphics(fig,dir+"DPeak_PkDotsOnImg.png","Resolution",600)


%%
% 2025JM
% POMA原稿用
% D on x=1 & PkDotsOnImg
% colorbarつき 

pos = [0 0 8 7];

fig = createFigure(pos);

label = ["\textsl{D}","Detected Peaks"]; % legend()の引数

ax1=gca;
plot(z(1:1000))
hold on;
scatter(pks(1:4,2),z(pks(1:4,2),1),10,'c','filled','MarkerEdgeColor','k');
hold off;
ylim([-1 1])

colormap(flip(gray));
colorbar("eastoutside");
clim([-1 1])
xticks(ax1,0:200:1000)
ax1.XTickLabelRotation = 45;
% title("$D$ on $x=1$")
xlabel("$y$ ($x=1$)","Interpreter","latex");
ylabel("\textsl{D}","Interpreter","latex");
% legend(label,"Interpreter","latex","FontSize",7);

dir = "C:\Users\MiwaR\Documents\尋希ドキュメント4\及川研\アナログレコード\"+...
    "2025JM\原稿資料\";

exportgraphics(fig,dir+"DOnX=1.pdf",'ContentType','vector')


pos = [0 0 7 7];
fig = createFigure(pos);

ax2=gca;
imshow(uint8(img_omitMask));
axis on;
hold on
axis equal tight
scatter(pks(:,1),pks(:,2),0.5,'cyan','filled');
hold off

% title("Peak Dots on a Image")
xlabel("$x$","Interpreter","latex");
ylabel("$y$","Interpreter","latex");

set(ax2,'YDir','reverse','TickDir','out')
set(ax2,"XAxisLocation","top")
xticks(0:200:1000);yticks(0:200:1000);
ax2.XTickLabelRotation = 45;

set(ax2,"OuterPosition",[0 0 1 1])

exportgraphics(fig,dir+"PkDotsOnImg.pdf",'ContentType','vector')

%%
% asj2026原稿作成用
% pkDots(傾き補正前/後)，Histogramの3枚の図を並べて表示

% 合同発表会2026原稿作成用
% pkDots(傾き補正前), Histogram, を並べて表示(pkDots2x2.pdf)

% POMA原稿作成用
% PkDots(傾き補正後), Histogram, PkDots1gSelected, MeanZero

% 卒論発表資料
% 1つずつ保存

% fig=createFigure([0 0 10 10]);
% t = tiledlayout(2,2,"Padding","none","TileSpacing","tight");
% ylabel(t,"$y$","Interpreter","latex","FontSize",9.25);
tickVec = 0:500:1000;
pos=[0 0 6 8];
sz = 0.5; % MarkerSize
dir = "C:\Users\owner\Documents\HirokiMiwa\原稿\2026卒論\発表資料\";

% pkDots (傾き補正前)
% nexttile;
fig=createFigure(pos);
scatter(pks_j(:,1),pks_j(:,2),0.2,'filled');
% hold on;
% vertices = zeros(4,2);
% vertices(1,:) = [1,p1(2) + h/2]';
% vertices(2,:) = [1,p1(2) - h/2]';
% vertices(3,:) = [w,p2(2) - h/2]';
% vertices(4,:) = [w,p2(2) + h/2]';
% pgon = polyshape(vertices);
% plot(pgon,"FaceColor","m","FaceAlpha",0.1);
set(gca,'YDir','reverse','xAxisLocation','top');box on;axis equal tight
xlim([0 1000]);ylim([0 1000]);%xticks(tickVec);yticks(tickVec)
xlabel("$x$");ylabel("$y$");
exportgraphics(fig,dir+"PkDotsTilt.png","Resolution",600);

% pkDots (傾き補正後)
% nexttile;
fig=createFigure(pos);
scatter(pks_cor_j(:,1),pks_cor_j(:,2),sz,'filled');
set(gca,'YDir','reverse','xAxisLocation','top');box on;axis equal tight
xlim([0 1000]);ylim([0 1000]);%xticks(tickVec);yticks(tickVec)
xlabel("$x$");ylabel("$y$")
% title(["(a) Peak Dots" "(tilt corrected)"])
exportgraphics(fig,dir+"PkDots2x2_1.png","Resolution",600);

% hist 
% nexttile;
fig=createFigure(pos);
barh(centers_j,counts_j);
set(gca,'YDir','reverse','xAxisLocation','top');box on;axis equal tight
xlim([0 1000]);ylim([0 1000]);%xticks(tickVec);yticks(tickVec)
xlabel("counts");ylabel("$y$")
% title(["(b) Histogram of" "$y$ Coordinates"])
hold on; %(溝1本分patch+棒グラフの色変更)
b=barh(centers_j(idx_tmp_j),counts_j(idx_tmp_j),'r');
b.EdgeColor = "none";
yline(y_min_j);yline(y_max_j);
patch([0 1000 1000 0],[y_min_j y_min_j y_max_j y_max_j],...
    'm',"EdgeColor","none","FaceAlpha",0.1);
hold off;
exportgraphics(fig,dir+"PkDots2x2_2.png","Resolution",600);

% pkDots (溝1本分色変更)
% nexttile;
fig=createFigure(pos);
scatter(pks_cor_j(:,1),pks_cor_j(:,2),sz,'filled');axis equal tight
set(gca,'YDir','reverse','xAxisLocation','top');box on
xlim([0 1000]);ylim([0 1000]);%xticks(tickVec);yticks(tickVec)
xlabel("$x$");ylabel("$y$")
% title(["(c) Peak Dots" "(one groove selected)"])
hold on
scatter(s_points_j(:,1),s_points_j(:,2),sz,'filled','r');
% yline(y_min); yline(y_max);
% patch([0 1000 1000 0],[y_min y_min y_max y_max],'m',"EdgeColor","none","FaceAlpha",0.1);
hold off
exportgraphics(fig,dir+"PkDots2x2_3.png","Resolution",600);

% 直流成分を引いたもの
% ax=nexttile;
fig=createFigure(pos);ax=gca;
y_rmDC = s_points_j(:,2) - mean(s_points_j(:,2));
plot(s_points_j(:,1),y_rmDC);
hold on;yline(0);hold off;
set(ax,'YDir','reverse','xAxisLocation','top');
%xticks(tickVec);ax.XTickLabelRotation = 45;
xlabel("$x$");ylabel("$y$")
% title(["(d) Coordinates of" "One Groove"])
pbaspect([1 1 1])
exportgraphics(fig,dir+"PkDots2x2_4.png","Resolution",600);

% exportgraphics(fig,dir+"PkDots1x4.pdf",'ContentType','vector')
% exportgraphics(fig,dir+"PkDots2x2.png")


%%
% 2026合同発表会ポスター用
% 写真??枚分の溝形状+画像の切れ目に縦線

% 2026卒論発表用にも使用


y_imgs = vertcat(ycoords{31:33,1});
fig=createFigure([0 0 7 6]);ax=gca;
plot(y_imgs);%axis tight
imgEnd=1;
hold on;
for i=1:3
    % if i==2
    %     plot(imgEnd:imgEnd+length(ycoords{32})-1,ycoords{32},'r')
    % end
    imgEnd = imgEnd + length(ycoords{30+i})-1;
    xline(imgEnd);
end
% set(ax,'YDir','reverse','xAxisLocation','top');
hold off
xlabel("$x$");ylabel("$y$");
ylim([-10 10]);
exportgraphics(fig,dir+"y_3imgs6x7.png","Resolution",600);

% そのもとになった，画像一つ分のyを表示
fig=createFigure([0 0 5 6]);ax=gca;
y_1imgOf3 = vertcat(ycoords{32,1});
y_rmDC = y_1imgOf3 - mean(y_1imgOf3);
plot(y_rmDC);
hold on;yline(0);hold off;
% set(ax,'YDir','reverse','xAxisLocation','top');
%xticks(tickVec);ax.XTickLabelRotation = 45;
xlabel("$x$");ylabel("$y$")
% title(["(d) Coordinates of" "One Groove"])
pbaspect([1 1 1])
ylim([-10 10]);
exportgraphics(fig,dir+"y_1imgOf3.png","Resolution",600);


%%
% asj202603原稿作成用
% tiledlayoutを使わず，一枚ずつexportしてみる

% 2025JM原稿用にも

pos=[0 0 4 7];
tickVec = 0:200:1000;
dir = "C:\Users\MiwaR\Documents\尋希ドキュメント4\及川研\アナログレコード\"+...
    "2025JM\原稿資料\";

% pkDots (傾き補正後)
fig=createFigure(pos);
scatter(pks_cor_j(:,1),pks_cor_j(:,2),sz,'filled');
set(gca,'YDir','reverse','xAxisLocation','top');box on;axis equal tight
xlim([0 1000]);ylim([0 1000]);%xticks(tickVec);yticks(tickVec)
xlabel("$x$");ylabel("$y$")
% title(["(a) Peak Dots" "(tilt corrected)"])
exportgraphics(fig,dir+"PkDots1x4_1.pdf",'ContentType','vector')

% hist 
fig=createFigure(pos);
barh(centers_j,counts_j);
set(gca,'YDir','reverse','xAxisLocation','top');box on;axis equal tight
xlim([0 1000]);ylim([0 1000]);%xticks(tickVec);yticks(tickVec)
xlabel("$counts$");ylabel("$y$")
% title(["(b) Histogram of" "$y$ Coordinates"])
hold on; %(溝1本分patch+棒グラフの色変更)
b=barh(centers_j(idx_tmp_j),counts_j(idx_tmp_j),'r');
b.EdgeColor = "none";
yline(y_min_j);yline(y_max_j);
patch([0 1000 1000 0],[y_min_j y_min_j y_max_j y_max_j],...
    'm',"EdgeColor","none","FaceAlpha",0.1);
hold off;
exportgraphics(fig,dir+"PkDots1x4_2.pdf",'ContentType','vector')

% pkDots (溝1本分色変更)
fig=createFigure(pos);
scatter(pks_cor_j(:,1),pks_cor_j(:,2),sz,'filled');axis equal tight
set(gca,'YDir','reverse','xAxisLocation','top');box on
xlim([0 1000]);ylim([0 1000]);%xticks(tickVec);yticks(tickVec)
xlabel("$x$");ylabel("$y$")
% title(["(c) Peak Dots" "(one groove selected)"])
hold on
scatter(s_points_j(:,1),s_points_j(:,2),sz,'filled','r');
% yline(y_min); yline(y_max);
% patch([0 1000 1000 0],[y_min y_min y_max y_max],'m',"EdgeColor","none","FaceAlpha",0.1);
hold off
exportgraphics(fig,dir+"PkDots1x4_3.pdf",'ContentType','vector')

% 直流成分を引いたもの
fig=createFigure(pos);
y_rmDC = s_points_j(:,2) - mean(s_points_j(:,2));
plot(s_points_j(:,1),y_rmDC);
ax=gca;
set(ax,'YDir','reverse','xAxisLocation','top');
%xticks(tickVec);ax.XTickLabelRotation = 45;
xlabel("$x$");ylabel("$y$")
% title(["(d) Coordinates of" "One Groove"])
pbaspect([1 1 1])

exportgraphics(fig,dir+"PkDots1x4_4.pdf",'ContentType','vector')

%%
% 溝1本分のデータを抽出できたことを示す
%{
f = figure; barh(centers,counts); ax = gca;
set(gca,'YDir','reverse','xAxisLocation','top');box on
xlim([0 1000]);ylim([0 1000]);xticks(0:200:1000);yticks(0:200:1000)
hold on;
idx_hist = histPkLocs(1)-3:histPkLocs(1)+3;
b=barh(centers(idx_hist),counts(idx_hist),'r');
b.EdgeColor = "none";
yline(y_min);yline(y_max);
patch([0 1000 1000 0],[y_min y_min y_max y_max],'m',"EdgeColor","none","FaceAlpha",0.1);
hold off;
mySaveForPapers(f,ax,[0 0 6 6], "Histogram of $y$ Coordinates of the Peak Dots",...
    "counts","$y$",[],"Hist_PkDots_1GSelected")
% title('histgram of y coords of the peak dots','FontSize',20);xlabel('counts');ylabel('y')


f=figure;
scatter(pks_cor(:,1),pks_cor(:,2),3,'filled');ax=gca;
set(gca,'YDir','reverse','xAxisLocation','top');box on
xlim([0 1000]);ylim([0 1000]);xticks(0:200:1000);yticks(0:200:1000)
hold on
scatter(selected_points_new(:,1),selected_points_new(:,2),3,'filled','r');
yline(y_min); yline(y_max);
patch([0 1000 1000 0],[y_min y_min y_max y_max],'m',"EdgeColor","none","FaceAlpha",0.1);
hold off
mySaveForPapers(f,ax,[0 0 6 6],"Peak Dots (Tilt Corrected)","$x$","$y$",[],"PkDots_tiltCorrected");
%}

%%
% 複数行分の溝データを抽出できたことを示す
%{
cVec = ['b' 'b' 'b' 'r'];

figure;
barh(centers,counts);
set(gca,'YDir','reverse','xAxisLocation','top');box on
xlim([0 1000]);ylim([0 1000]);xticks(0:200:1000);yticks(0:200:1000)
hold on;
for i=1:length(histPkLocs)
    idx_hist = histPkLocs(i)-3:histPkLocs(i)+3;
    b = barh(centers(idx_hist),counts(idx_hist),cVec(i));
    b.EdgeColor = "none";
    tmpGrooveCenter = centers(histPkLocs(i));
    y_min = tmpGrooveCenter - tol; y_max = tmpGrooveCenter + tol;
    yline(y_min);yline(y_max);
    patch([0 1000 1000 0],[y_min y_min y_max y_max],'m',"EdgeColor","none","FaceAlpha",0.1);
    title('histgram of y coords of the peak dots','FontSize',20);xlabel('counts');ylabel('y')
end
hold off;


figure;
scatter(pks_cor(:,1),pks_cor(:,2),3,'filled')
set(gca,'YDir','reverse','xAxisLocation','top');box on
xlim([0 1000]);ylim([0 1000]);xticks(0:200:1000);yticks(0:200:1000)
hold on
for i=1:length(histPkLocs)
    tmpGrooveCenter = centers(histPkLocs(i));
    y_min = tmpGrooveCenter - tol; y_max = tmpGrooveCenter + tol;
    yline(y_min); yline(y_max);
    idxs = (pks_cor(:,2) >= y_min) & (pks_cor(:,2)<=y_max);
    selected_points_new = pks_cor(idxs,:);

    scatter(selected_points_new(:,1),selected_points_new(:,2),3,'filled',cVec(i));
    patch([0 1000 1000 0],[y_min y_min y_max y_max],'m',"EdgeColor","none","FaceAlpha",0.1);
    title('peak dots (tilt corrected)','FontSize',20)
    xlabel('x');ylabel('y')
end
hold off;
%}

%%
% 8枚の画像を結合
amplitude_comb8 = vertcat(amplitudeC{:});
x_comb8 = vertcat(x_combC{:});
y_comb8 = vertcat(y_combC{:});

% 画像8枚分のy座標をつなげてから-1から1に正規化
amplitude2 = (y_comb8 - min(y_comb8)) / (max(y_comb8) - min(y_comb8)) * 2 - 1;
amplitude2 = -1 * amplitude2;

num_samples = length(amplitude_comb8);
fs = round(num_samples /(60/78));

% figure;plot(amplitude_comb8);
% title('amplitude(each)')

figure;plot(amplitude2);
title('amplitude2')
%%
% audiowrite("./audio files/DSC0113-0120_1cycle_0721_each.wav",amplitude_comb8,fs);
% audiowrite("./audio files/DSC0113-0120_1cycle_0721_2.wav",amplitude2,fs);


%%
fidx = (1:length(amplitude2)) / length(amplitude2) * fs;
Y = fft(amplitude2);
Y = Y / length(Y) * 2;
figure;plot(fidx,20*log10(abs(Y)));
% xlim([0 fs/2])
xlim([0 2e4])
ylim([-120 0])


%%

% fsが大きいので窓はかなり大きめ
[s,f,t] = stft(amplitude,"Window",hann(8192*2),"OverlapLength",8192,'FrequencyRange','onesided');
s = s * 2 / size(s,1);
figure;
mesh(t,f,20*log10(abs(s)))
xlim([0 max(t)]);ylim([0 1e4]);clim([-120 0]);
xlabel("time[s]");ylabel("frequency[Hz]")
view(0,90)
colorbar;


%%
% figure;spectrogram(amplitude,'yaxis')
% colormap jet

