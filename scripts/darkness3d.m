% darknessをsurf()とwaterfall()で表示

setDefaultIntrpr();

%% read image
img = imread("DSC1111-00001-ori.png");
img_gray = rgb2gray(img);

pixels = 100;

heightIdx = 101:101+pixels-1;
widthIdx = 1001:1001+pixels-1;

img_small = img_gray(heightIdx,widthIdx);
imgData = ImageData(img_small,[1,1]);

origD = DarknessValue(imgData);
origdMat = origD.dMat;



%% waterfallを使ってdMatを3次元で表示する

X = (1:pixels);Y = (1:pixels)';

figure;p = waterfall(X,Y,origdMat',"Marker",".");
xlim([1,60]);
ylim([1,10]);
% zlim([0 1]);
clim([0 1]);
p.MarkerSize = 5;
colormap(flipud(gray));colorbar;
% p.EdgeColor = "none";
view(30,30)


%% surfを使用する

figure;h=surf(origdMat);
h.EdgeColor = "none";
colormap(flipud(gray));
colorbar; clim([0 1])
xlim([1,10]);
ylim([1,60]);
xlabel('$x$');ylabel('$y$');
view(-80,45)

%% ribbonを使用する
figure;ribbon(origdMat);
xlim([1,10]);
ylim([1,60]);
% zlim([0 1]);
clim([0 1]);
colormap(flipud(gray));colorbar;
