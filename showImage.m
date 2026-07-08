
img_1x = imread("../../2025JM/発表資料/_DSC1111_00003_ori_tri.png");
img_8x = imread("../../2025JM/発表資料/_DSC1111_00003_8x_tri.png");

img_1x_g = rgb2gray(img_1x);
img_8x_g = rgb2gray(img_8x);

%%
set(0,'defaultTextInterpreter','latex');
set(0,'defaultAxesTickLabelInterpreter','latex');
set(0,'defaultLegendInterpreter','latex');
set(0,'defaultColorbarTickLabelInterpreter','latex');

fig = figure;
fig_pos = [0 0 8 6];
set(fig,"Units","centimeters");
set(fig,"Position",fig_pos);
fig.PaperSize = [fig_pos(3) fig_pos(4)];

tiledlayout(1,2,"Padding","none");
nexttile;
imshow(img_1x_g(2:41,2:41));
axis on;
set(gca,'YDir','reverse','TickDir','out','xAxisLocation','top');
title("Original Image","FontSize",10);xlabel("$x$","FontSize",10);ylabel("$y$","FontSize",10);
xticks(0:10:40);yticks(0:10:40);

nexttile;
imshow(img_8x_g(1:320,1:320));
axis on;
set(gca,'YDir','reverse','TickDir','out','xAxisLocation','top')
title("Processed Image","FontSize",10);xlabel("$x$","FontSize",10);ylabel("$y$","FontSize",10)
xticks(0:100:320);yticks(0:100:320);

dir = "C:\Users\MiwaR\Documents\尋希ドキュメント4\及川研\アナログレコード\"+...
    "2025JM\原稿資料\";

exportgraphics(gcf, dir+"1x8xImgs.pdf","ContentType","vector")

% ax = gca;
% outerpos = ax.OuterPosition;
% ti = ax.TightInset;
% left = outerpos(1) + ti(1);
% bottom = outerpos(2) + ti(2);
% ax_width = outerpos(3) - ti(1) - ti(3);
% ax_height = outerpos(4) - ti(2) - ti(4);
% ax.Position = [left bottom ax_width ax_height];
% 
% saveas(gcf,"1x8xImgs.pdf")
