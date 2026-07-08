% 1x, 2x, 4x, 8xの画像の比較
% 2026/04/09作成

%%
set(0,'defaultTextInterpreter','latex');
set(0,'defaultAxesTickLabelInterpreter','latex');
set(0,'defaultLegendInterpreter','latex');
set(0,'defaultColorbarTickLabelInterpreter','latex');

%%
i=2; % 1~8

dirBase = "C:\Users\owner\Documents\HirokiMiwa\photoshop@Miwa\";

img_1x = imread(dirBase+"original pictures\rect\_DSC1111_0000"+num2str(i)+"_ori.png");
img_2x = imread(dirBase+"2x\_DSC1111_0000"+num2str(i)+"_2x.png");
img_4x = imread(dirBase+"4x\_DSC1111_0000"+num2str(i)+"_4x.png");
img_8x = imread(dirBase+"8x\_DSC1111_0000"+num2str(i)+"_8x.png");

%%
figure;imshow(img_1x);axis on;
title("Original Image");xlabel("$x$");ylabel("$y$");

figure;imshow(img_2x);axis on;
title("2x Image");xlabel("$x$");ylabel("$y$");

figure;imshow(img_4x);axis on;
title("4x Image");xlabel("$x$");ylabel("$y$");

figure;imshow(img_8x);axis on;
title("8x Image");xlabel("$x$");ylabel("$y$");



%%
xmin = 2001; xmax = xmin + 100;
ymin = 1; ymax = ymin+100;

pos = [0 0 10 10];

fig_1 = createFigure(pos);
imshow(img_1x(ymin:ymax,xmin:xmax),"InitialMagnification","fit");
axis on;ax=gca;
set(ax,'YDir','reverse','TickDir','out')
set(ax,"XAxisLocation","top")
title("Original Image");xlabel("$x$");ylabel("$y$");

fig_2 = createFigure(pos);
imshow(img_2x(ymin*2:ymax*2,xmin*2:xmax*2),"InitialMagnification","fit");
axis on;ax=gca;
set(ax,'YDir','reverse','TickDir','out')
set(ax,"XAxisLocation","top")
title("2x Image");xlabel("$x$");ylabel("$y$");

fig_4 = createFigure(pos);
imshow(img_4x(ymin*4:ymax*4,xmin*4:xmax*4),"InitialMagnification","fit");
axis on;ax=gca;
set(ax,'YDir','reverse','TickDir','out')
set(ax,"XAxisLocation","top")
title("4x Image");xlabel("$x$");ylabel("$y$");

fig_8 = createFigure(pos);
imshow(img_8x(ymin*8:ymax*8,xmin*8:xmax*8),"InitialMagnification","fit")
axis on;ax=gca;
set(ax,'YDir','reverse','TickDir','out')
set(ax,"XAxisLocation","top")
title("8x Image");xlabel("$x$");ylabel("$y$");
    
%%

