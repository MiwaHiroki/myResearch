%%
set(0,'defaultTextInterpreter','latex');
set(0,'defaultAxesTickLabelInterpreter','latex');
set(0,'defaultLegendInterpreter','latex');
set(0,'defaultColorbarTickLabelInterpreter','latex');
% set(0,'defaultAxesFontSize',16)

%%
% ノイズの原因を説明する図を作成する
% img = imread("./pictures/old/8x/DSC0116_8x.png");
img = imread("./pictures/8x_old/DSC0116_8x.png");
img = rgb2gray(img);

img_1x = imread("./pictures/DSC0116_2.png");
img_1x = rgb2gray(img_1x);

img_small = img(901:1900,13001:14000);

img_1x_tri = img_1x(143:174,1710:1741);

saveDir = "../../2026卒論/原稿資料/";

minh = 0.0;
maxh = 0.5;
mind = 50;
max_prd = 30; % th_prd
% min_prd = 1;

z = double(img_small) * (-2/255) + 1;
pksCell = cell(1000,1);
h = 250;
w = 250;
xs = 26;
ys = 246;
% img_tri = img(1481:1780,15001:15300);
img_tri = img_small(ys:ys+h-1,xs:xs+w-1);

rect = [[xs,ys];[xs,ys+h-1];[xs+w-1,ys+h-1];[xs+w-1,ys]];
pgon=polyshape(rect);

for k=1:1000 % 各x座標についてピークを見つけ、pksCellに格納
    [tmpPks,tmpLocs,width,p] = findpeaks(z(:,k),...
        'MinPeakHeight',minh,...
        'MinPeakDistance',mind);

    % idx=find(tmpPks<maxh);

    product = width.*p;
    idx = find((tmpPks<maxh) & (product < max_prd));
    % idx = find((product < max_prd));
    num = length(idx);

    tmpPksX = k * ones(num,1);
    tmpPksY = zeros(num,1);
    tmpPksY(:,1) = tmpLocs(idx);

    pksCell{k,1} = [tmpPksX tmpPksY];

end

pks = vertcat(pksCell{:,:});

% fig = createFigure([0 0 16 6]);
% tiledlayout(1,4,"Padding","tight","TileSpacing","tight");

pos = [0 0 6 6]; % 1枚ずつexportするときのfigureのpos

% ax=nexttile;
fig = createFigure(pos);ax=gca;
imshow(img_small,"InitialMagnification","fit");
axis on;
set(ax,'YDir','reverse','TickDir','out','xAxisLocation','top');
xlabel("$x$");ylabel("$y$");
% ax.XTickLabelRotation = 45;ax.YTickLabelRotation = 0;
% xticks(0:200:1000);yticks(0:200:1000);
hold on;
scatter(pks(:,1),pks(:,2),1,'c','filled');
plot(pgon,"FaceColor","none","EdgeColor","r","LineWidth",2);
exportgraphics(fig,saveDir+"Old_Noise.pdf","ContentType","vector");
exportgraphics(fig,saveDir+"Old_Noise.png","Resolution",600);

% ax=nexttile;
fig = createFigure(pos);ax=gca;
imshow(img_small,"InitialMagnification","fit");
axis on;hold on;
scatter(pks(:,1),pks(:,2),1,'c','filled');
plot(pgon,"FaceColor","none","EdgeColor","r","LineWidth",2);
set(ax,'YDir','reverse','TickDir','out','xAxisLocation','top');
xlabel("$x$");ylabel("$y$");
% ax.XTickLabelRotation = 45;ax.YTickLabelRotation = 0;
xlim([xs xs+w-1]);ylim([ys ys+h-1]);
exportgraphics(fig,saveDir+"Old_Noise_zoom.pdf","ContentType","vector");
exportgraphics(fig,saveDir+"Old_Noise_zoom.png","Resolution",600);

% ax=nexttile;
fig = createFigure(pos);ax=gca;
% imshow(img_small);xlabel("$x$");ylabel("$y$");
imshow(img_tri,"InitialMagnification","fit");
axis on;
set(ax,'YDir','reverse','TickDir','out','xAxisLocation','top');
xlabel("$x$");ylabel("$y$");
% ax.XTickLabelRotation = 45;ax.YTickLabelRotation = 0;
exportgraphics(fig,saveDir+"Old_Noise_8x.pdf","ContentType","vector")
exportgraphics(fig,saveDir+"Old_Noise_8x.png","Resolution",600)

fig =createFigure(pos);ax=gca;
% ax=nexttile;
imshow(img_1x_tri,"InitialMagnification","fit");
axis on;
xlabel("$x$");ylabel("$y$");
% ax.XTickLabelRotation = 45;ax.YTickLabelRotation = 0;
set(ax,'YDir','reverse','TickDir','out','xAxisLocation','top');
exportgraphics(fig,saveDir+"Old_Noise_1x.pdf","ContentType","vector")
exportgraphics(fig,saveDir+"Old_Noise_1x.png","Resolution",600)

% exportgraphics(fig,saveDir+"Old_Noise1x4.pdf","ContentType","vector");

%%
img = imread("./pictures/1111/DSC1111-00007-8x.png");
img = rgb2gray(img);
img_small = img(1001:2000,15001:16000);

img_1x = imread("./pictures/_DSC1111_00007_ori.png");
img_1x = rgb2gray(img_1x);
img_1x_tri = img_1x(186:217,2005:2036);

minh = 0.2;
maxh = 0.5;
mind = 50;
max_prd = 30; % th_prd
% min_prd = 1;

z = double(img_small) * (-2/255) + 1;
pksCell = cell(1000,1);
h = 250;
w = 250;
xs = 1;
ys = 481;
% img_tri = img(1481:1780,15001:15300);
img_tri = img_small(ys:ys+h-1,xs:xs+w-1);

rect = [[xs,ys];[xs,ys+h-1];[xs+w-1,ys+h-1];[xs+w-1,ys]];
pgon=polyshape(rect);

for k=1:1000 % 各x座標についてピークを見つけ、pksCellに格納
    [tmpPks,tmpLocs,width,p] = findpeaks(z(:,k),...
        'MinPeakHeight',minh,...
        'MinPeakDistance',mind);

    % idx=find(tmpPks<maxh);

    product = width.*p;
    idx = find((tmpPks<maxh) & (product < max_prd));
    % idx = find((product < max_prd));
    num = length(idx);

    tmpPksX = k * ones(num,1);
    tmpPksY = zeros(num,1);
    tmpPksY(:,1) = tmpLocs(idx);

    pksCell{k,1} = [tmpPksX tmpPksY];

end


pks = vertcat(pksCell{:,:});

% fig = createFigure([0 0 16 6]);
% tiledlayout(1,4,"Padding","tight","TileSpacing","tight");

pos = [0 0 6 6]; % 1枚ずつexportするときのfigureのpos

% ax=nexttile;
fig = createFigure(pos);ax=gca;
imshow(img_small,"InitialMagnification","fit");
axis on;
set(ax,'YDir','reverse','TickDir','out','xAxisLocation','top');
xlabel("$x$");ylabel("$y$");
% ax.XTickLabelRotation = 45;ax.YTickLabelRotation = 0;
% xticks(0:200:1000);yticks(0:200:1000);
hold on;
scatter(pks(:,1),pks(:,2),1,'c','filled');
plot(pgon,"FaceColor","none","EdgeColor","r","LineWidth",2);
exportgraphics(fig,saveDir+"New_Noise.pdf","ContentType","vector");
exportgraphics(fig,saveDir+"New_Noise.png","Resolution",600);

% ax=nexttile;
fig = createFigure(pos);ax=gca;
imshow(img_small,"InitialMagnification","fit");
axis on;hold on;
scatter(pks(:,1),pks(:,2),1,'c','filled');
plot(pgon,"FaceColor","none","EdgeColor","r","LineWidth",2);
set(ax,'YDir','reverse','TickDir','out','xAxisLocation','top');
xlabel("$x$");ylabel("$y$");
% ax.XTickLabelRotation = 45;ax.YTickLabelRotation = 0;
xlim([xs xs+w-1]);ylim([ys ys+h-1]);
exportgraphics(fig,saveDir+"New_Noise_zoom.pdf","ContentType","vector");
exportgraphics(fig,saveDir+"New_Noise_zoom.png","Resolution",600);

% ax = nexttile;
fig = createFigure(pos);ax=gca;
imshow(img_small,"InitialMagnification","fit");
axis on;
xlabel("$x$");ylabel("$y$");
xlim([xs xs+w-1]);ylim([ys ys+h-1]);
% ax.XTickLabelRotation = 45;ax.YTickLabelRotation = 0;
set(ax,'YDir','reverse','TickDir','out','xAxisLocation','top');
exportgraphics(fig,saveDir+"New_Noise_8x.pdf","ContentType","vector")
exportgraphics(fig,saveDir+"New_Noise_8x.png","Resolution",600)

% ax=nexttile;
imshow(img_1x_tri,"InitialMagnification","fit");
axis on;
xlabel("$x$");ylabel("$y$");
set(ax,'YDir','reverse','TickDir','out','xAxisLocation','top');
exportgraphics(fig,saveDir+"New_Noise_1x.pdf","ContentType","vector")
exportgraphics(fig,saveDir+"New_Noise_1x.png","Resolution",600)

% exportgraphics(fig,saveDir+"New_Noise1x4.pdf","ContentType","vector");

