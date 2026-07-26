% darknessをsurf()とwaterfall()で表示

setDefaultIntrpr();

proj = currentProject;
date = "0725";
mkdirFromDate(proj.RootFolder,date);
dir = "results/"+date+"/";

%% 画像を読み込み、DarknessValueオブジェクトをセットアップする
img = imread("DSC1111-00001-ori.png");
img_gray = rgb2gray(img);

pixels = 100;

heightIdx = 101:101+pixels-1;
widthIdx = 1001:1001+pixels-1;

img_small = img_gray(heightIdx,widthIdx);
imgData = ImageData(img_small,[1,1]);

D_THRESH = 0.6;

origD = DarknessValue(imgData);
origD = origD.ddiff(D_THRESH);
origdMat = origD.dMat;

% pts_cnt = GrooveCandidates(origD);
% 
% 
% for x=1:pixels
%     [startIdx, endIdx] = getStartEndIdx(origD, x);
% 
%     W_TH = 8;
%     [origD,~,~,pksNum] = ...
%         getGrooveBtmIdx(origD,x,startIdx,endIdx,W_TH);
%     % startIdx_btm, endIdx_btm, pksNumは今後不要になる予定
% 
%     cnt_x = origD.extractGrv_cnt(x);
%     pts_cnt.pksCell{x} = [x*ones(pksNum,1), cnt_x];
% end
%
% ptsXY = vertcat(pts_cnt.pksCell{:});
% ptsX = ptsXY(:,1);ptsY = ptsXY(:,2);
% ptsZ = zeros(length(ptsXY),1);
% for i=1:length(ptsXY)
%     ptsZ(i) = dMat(round(ptsY(i)),ptsX(i)); % waterfallを使うときに転置してるから
% end

%% (origDについて)waterfallを使ってdMatを3次元で表示する

X = (1:pixels);Y = (1:pixels)';

fig=createFigure([0 0 8 6]);p = waterfall(X,Y,origdMat',"Marker",".");
xlim([1,60]);
ylim([1,10]);
zlim([0.3 1]);
clim([0 1]);
p.MarkerSize = 5;
colormap(flipud(gray));%colorbar;
title("Darkness: Original (Unprocessed)");
% xlabel("Row Index");ylabel("Column Index");zlabel("$D$");
xlabel("$y$");ylabel("$x$");zlabel("$D$");
% p.EdgeColor = "none";
view(30,30)
saveas(fig,dir+"3d-darkness(original)_labelxy.png");saveas(fig,dir+"3d-darkness(original)_labelxy.fig");

%% (rsmplDについて)waterfallを使ってdMatを3次元で表示する

p_rsmpl = 8; q_rsmpl = 1;
rsmplD = dResample(origD,p_rsmpl,q_rsmpl);
rsmplD = rsmplD.ddiff(D_THRESH);
rsmpldMat = rsmplD.dMat;

[nRows_rsmpl,nCols_rsmpl] = size(rsmpldMat);
X_rsmpl = (1:nRows_rsmpl);
Y_rsmpl = (1:nCols_rsmpl)';

fig=createFigure([0 0 8 6]);p = waterfall(X_rsmpl,Y_rsmpl,rsmpldMat',"Marker",".");
xlim([1,(60-1)*rsmplD.rRatio(1)+1]);
ylim([1,(10-1)*rsmplD.rRatio(2)+1]);
zlim([0.3 1]);
clim([0 1]);
p.MarkerSize = 5;
colormap(flipud(gray));%colorbar;
title("Darkness: After 1-D Resampling");
xlabel("Row Index");ylabel("Column Index");zlabel("$D$");
% p.EdgeColor = "none";
view(30,30)

saveas(fig,dir+"3d-darkness(rsmpl).png");saveas(fig,dir+"3d-darkness(rsmpl).fig");

%% (intpDについて)waterfallを使ってdMatを3次元で表示する

step = 0.25;
INTERP_METHOD = "spline"; % method for interpolation
intpD = dInterp(origD,step,INTERP_METHOD);
intpD = intpD.ddiff(D_THRESH);
intpdMat = intpD.dMat;

[nRows_intp,nCols_intp] = size(intpdMat);
X_intp = (1:nRows_intp);
Y_intp = (1:nCols_intp)';

fig=createFigure([0 0 8 6]);p = waterfall(X_intp,Y_intp,intpdMat',"Marker",".");
xlim([1,(60-1)*intpD.rRatio(1)+1]);
ylim([1,(10-1)*intpD.rRatio(2)+1]);
zlim([0.3 1]);
clim([0 1]);
p.MarkerSize = 5;
colormap(flipud(gray));%colorbar;
title("Darkness: After 2-D Interpolation");
xlabel("Row Index");ylabel("Column Index");zlabel("$D$");
% p.EdgeColor = "none";
view(30,30)
saveas(fig,dir+"3d-darkness(intp).png");saveas(fig,dir+"3d-darkness(intp).fig");

%% ---------------以下不要-------------------- 

%{
% surfを使用する

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

%}