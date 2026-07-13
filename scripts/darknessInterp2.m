clear;

% img_new = imread("./pictures/1111/original/DSC1111-00001-ori.png");
img_new = imread("DSC1111-00001-ori.png");
img_gray = rgb2gray(img_new);

imgSize = 50;
idx_x = 101:101+imgSize-1;
idx_y = 101:101+imgSize-1;
img_small = img_gray(idx_y,idx_x);

%% 
% normalize
z = 1-double(img_small)/255;

figure;h = surf(z);
h.EdgeColor = 'none';
colormap(flipud(gray))
title("original image")
xlabel('x');ylabel('y')
view(80,45)
% view(180,90);

%%
% img_smallをinterp2で「疑似高解像度化」
method = "spline";

x_q = 1:0.25:imgSize;
y_q = (1:0.25:imgSize)';
z_interp = interp2(1:imgSize,1:imgSize,z,x_q,y_q,method);

figure;h_new = surf(z_interp);
h_new.EdgeColor = 'none';
colormap(flipud(gray))
title("interpolated image (method: "+method+")")
xlabel('x');ylabel('y')
% view(80,45)
view(180,90)

%%




%%

% contour3を使った表示
%{
xx = (1:size((z),1))';
yy = (1:size((z),2))';
[XX,YY] = meshgrid(xx,yy);
%figure;contour3(XX,YY,z_new,[0.5 0.5])
figure;contour3(XX,YY,z,30)
%}

%%



