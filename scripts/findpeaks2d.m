% 発表資料作成用
setDefaultIntrpr();
set(0,'defaultAxesFontSize',16)

%%
try
    proj = currentProject;
    rootFolder = proj.RootFolder;
catch
    scriptPath = fileparts(mfilename('fullpath'));
    rootFolder = fileparts(scriptPath);
end

imgPath = fullfile(rootFolder, 'data', 'pictures', '1111', '8x', 'DSC1111-00002-8x.png');
img = imread(imgPath);
if size(img, 3) == 3
    img = rgb2gray(img);
end

[xmax,ymax] = size(img);

widthIdx = 1001:1600;
heightIdx = 1001:1600;
img_small = img(heightIdx,widthIdx);
% figure;imshow(img_small);title("DSC1111-00002-8x");

% 1. ImageData クラスを使用する
imgData = ImageData(double(img_small), [1111; 2]);

%画素値の大きなピーク
% figure;findpeaks(imgData.img(:,500),'MinPeakDistance',10)


%%
%{
tmp = 1;
n = 50; % 各yについて、ピークを最大何個記録するか
pksX = zeros(n*ymax,1); % ピークのx座標を格納
pksY = zeros(n*ymax,1); % ピークのy座標を格納

thresh1 = 0.2;thresh2 = 0.5; % 溝の底を抽出するには二つの閾値が必要
    
for i=1:xmax
    [pks,locs] = findpeaks(z_new(:,i),'MinPeakHeight',thresh1);
    num = nnz(pks<thresh2);
    idx = find(pks<thresh2); % ピークの位置が<0.5のもののindex
    locs = locs(idx);

    % [pks,locs] = findpeaks(z_new(:,i));
    % num = length(pks);
    % 
    pksX(tmp:tmp+num-1) = i;
    pksY(tmp:tmp+num-1) = locs;
    tmp = tmp+num;
end

pksX = pksX(1:tmp); % 値のある範囲のみを選択
pksY = pksY(1:tmp);

figure;
imshow(img_small)
hold on
scatter(pksX,pksY,1,'filled');
xlabel('X');ylabel('Y')
title('peak(z new)')
hold off
%}

%%
% 画像をそのまま（トリミングせずに）行う処理
% 1/8周の画像の左右の端に、溝から大きく外れたピーク点が現れる

%{
pksCell = cell(xmax,1);

thresh1 = 0.2;thresh2 = 0.6; % ピークの高さについての閾値
d = 20; % MinPeakDistance
minw = 20; % MinPeakWidth
minp = 0.2; % MinPeakProminence
maxp = 0.7; % MaxPeakProminence


for i=1:xmax
    [tmpPks,tmpLocs,w,p] = findpeaks(z_new(:,i),...
        'MinPeakProminence',minp,...
        'MinPeakHeight',thresh1);...
        %,'MinPeakDistance',d);
    
    % num = nnz(tmpPks < thresh2);
    % idx = find(tmpPks < thresh2); % ピークの位置が<0.5のもののindex

    idx = find(p < maxp); % ピークのプロミネンスが<maxpのもののindex
    num = length(idx);

    tmpPksX = zeros(num,1);
    tmpPksY = tmpPksX;

    tmpPksX(:,1) = i;
    tmpPksY(:,1) = tmpLocs(idx);

    pksCell{i,1} = [tmpPksX tmpPksY];

end

pks = vertcat(pksCell{:,:});

figure;
imshow(img_small);
set(gca,'YDir','reverse')
title('peaks')
xlabel('X');ylabel('Y');
hold on
axis equal
scatter(pks(:,1),pks(:,2),3,'filled');
hold off
%}

%% 
% マスク部分=輝度値が0のところを取り除く
% 輝度値が0の部分に内接する長方形を作成し
% その内側を新しい画像(img_omitMask)として処理を行う

th = 20; % 閾値
img_omitMask = omitMask(imgData.img, th);
% figure;imshow(img_omitMask)

% マスク処理後の画像データに対しても ImageData クラスを使用する
imgData_omit = ImageData(img_omitMask, [1111; 2]);


%%
% 2. DarknessValue クラスを使用する
dValue = DarknessValue(imgData_omit, 0.5);

% z = double(img_omitMask)*(-2/255)+1 と等価な計算を dValue.dMat を用いて行う
z = 2 * dValue.dMat - 1;

% 3. GrooveCandidates クラスを使用する
candidates = GrooveCandidates(dValue);

thresh1 = 0.3;
thresh2 = 0.6;
minWidth = 50;
minw = 20; % MinPeakWidth
minp = 0.2; % MinPeakProminence
maxp = 0.8; % MaxPeakProminence


for i=1:imgData_omit.width
    [tmpPks,tmpLocs,w,p] = findpeaks(z(:,i),...
        'MinPeakProminence',minp);

    product = w.*p;
    % 溝底のproductは10~20くらい

    idx = find(product < 20);
    num = length(idx);

    tmpPksX = i*ones(num,1);
    tmpPksY = tmpLocs(idx);

    % GrooveCandidates.pksCell に格納する
    candidates.pksCell{i} = [tmpPksX tmpPksY];
end

pks = vertcat(candidates.pksCell{:});

%%
% ImageData.showImg() メソッドを使用して画像を表示する
figure;
imgData_omit.showImg();
title('peak dots on a image')
hold on
axis equal
scatter(pks(:,1),pks(:,2),10,'filled','cyan');
hold off


%%
% 4. AudioData クラスを使用する
% 検出したピークのy座標から簡易的に音溝形状としての音声を生成し、描画や試聴を行う
y_signal = zeros(imgData_omit.width, 1);
for i = 1:imgData_omit.width
    col_pks = candidates.pksCell{i};
    if ~isempty(col_pks)
        % 最初のピークのy座標を使用
        y_signal(i) = col_pks(1, 2);
    else
        % ピークがない場合は直前の値で補完
        if i > 1
            y_signal(i) = y_signal(i-1);
        else
            y_signal(i) = 0;
        end
    end
end

% 直流成分の除去と正規化
y_signal = y_signal - mean(y_signal);
if max(abs(y_signal)) > 0
    y_signal = y_signal / max(abs(y_signal));
end

% 信号が短い（1024サンプル未満）と stft でエラーになるため、10回繰り返して十分な長さにする
y_signal_extended = repmat(y_signal, 10, 1);

% サンプリング周波数 8000Hz で AudioData クラスを作成
fs = 8000;
audio = AudioData("Restored Audio from findpeaks2d", y_signal_extended, fs);

% AudioData クラスの描画メソッドを使用する
figure;
audio.audioPlot();

figure;
audio.FFTPlot();

figure;
audio.spectrogramPlot();

