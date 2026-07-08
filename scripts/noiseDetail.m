%%
set(0,'defaultTextInterpreter','latex');
set(0,'defaultAxesTickLabelInterpreter','latex');
set(0,'defaultLegendInterpreter','latex');
set(0,'defaultColorbarTickLabelInterpreter','latex');
% set(0,'defaultAxesFontSize',16)

%%
% ノイズの原因を説明する図を作成する
img = imread("./pictures/old/8x/DSC0116_8x.png");
img_1x = imread("./pictures/old/DSC0116_2.png");

% img_small = img(1001:2000,14801:15800);
% 
% minh = 0.0;
% mind = 50;
% th_prd = 30;
% z = double(img_small) * (-2/255) + 1;
% pksCell = cell(1000,1);
% h = 300;
% w = 300;
% xs = 1;
% ys = 521;
% % img_tri = img(1481:1780,15001:15300);
% img_tri = img_small(ys:ys+h-1,xs:xs+w-1);

img_small = img(901:1900,13001:14000);
minh = 0.0;mind=50;th_prd=30;
z=double(img_small)*(-2/255)+1;
pksCell = cell(1000,1);
h=250;w=250;xs=26;ys=256;
img_tri = img_small(ys:ys+h-1,xs:xs+w-1);

rect = [[xs,ys];[xs,ys+h-1];[xs+w-1,ys+h-1];[xs+w-1,ys]];
pgon=polyshape(rect);

for k=1:1000 % 各x座標についてピークを見つけ、pksCellに格納
    [tmpPks,tmpLocs,width,p] = findpeaks(z(:,k),...
        'MinPeakHeight',minh,...
        'MinPeakDistance',mind);

    % idx=find(tmpPks<maxh);

    product = width.*p;
    idx = find(product < th_prd);

    num = length(idx);

    tmpPksX = k * ones(num,1);
    tmpPksY = zeros(num,1);
    tmpPksY(:,1) = tmpLocs(idx);

    pksCell{k,1} = [tmpPksX tmpPksY];

end

pks = vertcat(pksCell{:,:});

fig = createFigure([0 0 12 8]);
tiledlayout(1,2,"Padding","tight","TileSpacing","tight");

ax=nexttile;
imshow(img_small);
hold on;
scatter(pks(:,1),pks(:,2),1,'c','filled');
plot(pgon,"FaceColor","none","EdgeColor","r","LineWidth",2);
xlabel("$x$");ylabel("$y$");
set(gca,'YDir','reverse','TickDir','out','xAxisLocation','top');


nexttile;
imshow(img_small);
hold on;
scatter(pks(:,1),pks(:,2),1,'c','filled');
plot(pgon,"FaceColor","none","EdgeColor","r","LineWidth",2);
set(gca,'YDir','reverse','TickDir','out','xAxisLocation','top');
xlabel("$x$");ylabel("$y$");
xlim([xs xs+w-1]);ylim([ys ys+h-1]);


img_1x_tri = img_1x(145:176,1628:1660);
figure;imshow(img_1x_tri);

%%
img = imread("./pictures/1111/DSC1111-00002-8x.png");



