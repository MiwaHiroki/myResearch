% 手動で作成した平行四辺形内にある点群を直線近似したあと
% その傾きを使ってpksの傾きを直したpks_corを出力する

function [p1,p2,pks_cor] = fitGroove(j,fig,p2,w,h,pks)
figure(fig);

%平行四辺形をつくる
vertices = zeros(4,2); % 頂点

if j==1 % l枚のうちの左端の画像だったら
    p1 = ginput(1); % 左端の溝の中心を選ぶ
else
    p1 = p2; % 引数のp2
end

% 左側
vertices(1,:) = [1,p1(2) + h/2]';
vertices(2,:) = [1,p1(2) - h/2]';
line(vertices(1:2,1),vertices(1:2,2),'LineWidth',3)

% 右側，新しくp2を選ぶ
p2 = ginput(1);
vertices(3,:) = [w,p2(2) - h/2]';
vertices(4,:) = [w,p2(2) + h/2]';
line(vertices(3:4,1),vertices(3:4,2),'LineWidth',3)

pgon = polyshape(vertices);
plot(pgon);

% pause(0.5);

hold off;
close(gcf);


% 平行四辺形の内部または辺上にある点を選ぶ
[in, on] = inpolygon(pks(:,1), pks(:,2), ...
    vertices(:,1), vertices(:,2));
selected_points = pks(in | on, :);

n = 1; % polyfitの次数
x = selected_points(:,1);
y = selected_points(:,2);
p = polyfit(x,y,n);

x_ = (1:pks(end,1))';
y_fit = polyval(p,x_);

pks_cor = pks;
pks_cor(:,2) = pks_cor(:,2) - y_fit(pks_cor(:,1)) + p(1,end); 
% ヒストグラムを作るために切片だけはそのままにしておく
end