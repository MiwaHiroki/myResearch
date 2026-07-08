% fitGroove.mのコピー
% 一つの溝につき複数個検出されたピークの平均を取って
% 一つのピーク点にまとめ、今までと同じ処理を行う

function [p1,p2,pks_cor] = fitGroove_multiPeaks(i,j,fig,p2,w,h,pks)
figure(fig);

% saveas(fig,"./data/1223/peak dots/DSC1111-0000"+num2str(i)+"-8x-peak-"+num2str(j)+".fig");

%平行四辺形をつくる
vertices = zeros(4,2); % 頂点

if j==1 % l枚のうちの左端の画像だったら
    p1 = ginput(1); % 左端の溝の中心を選ぶ
else
    p1 = p2; % 引数のp2
end
vertices(1,:) = [1,p1(2) + h/2]';
vertices(2,:) = [1,p1(2) - h/2]';
line(vertices(1:2,1),vertices(1:2,2),'LineWidth',3)

% 新しくp2を選ぶ
p2 = ginput(1);
vertices(3,:) = [w,p2(2) - h/2]';
vertices(4,:) = [w,p2(2) + h/2]';
line(vertices(3:4,1),vertices(3:4,2),'LineWidth',3)

pgon = polyshape(vertices);
plot(pgon,"FaceColor","m","FaceAlpha",0.1);

% 発表資料作成用
% if j==5
%     saveas(gcf,"./data/1129/peak dots with parallelogram (j=5) i="+num2str(i)+".png") 
% end
% pause(0.5);

close(gcf);
hold off

% 平行四辺形の内部または辺上にある点を選ぶ
[in, on] = inpolygon(pks(:,1), pks(:,2), ...
    vertices(:,1), vertices(:,2));
selected_points = pks(in | on, :);

% selected_pointsのうち、重複するxを一つに平均化
[x_u,~,idx] = unique(selected_points(:,1));
y_u = accumarray(idx,selected_points(:,2),[],@mean);

n = 3; % polyfitの次数
p = polyfit(x_u,y_u,n);

x_ = (1:pks(end,1))';
y_fit = polyval(p,x_);

pks_cor = pks;
pks_cor(:,2) = pks_cor(:,2) - y_fit(pks_cor(:,1)) + p(1,end); 
% ヒストグラムを作るために切片だけはそのままにしておく
end