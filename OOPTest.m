% 2026/06/03作成
% --> 2026/06/11修正
% 各種クラスのテストを行う

%%
set(0,'defaultTextInterpreter','latex');
set(0,'defaultAxesTickLabelInterpreter','latex');
set(0,'defaultLegendInterpreter','latex');
set(0,'defaultColorbarTickLabelInterpreter','latex');
%%
% AudioDataのテスト

fs = 48000;
tmax = 1;
t = 0:1/fs:tmax;
f = 500;
A = 1;
y = A * sin(2*pi*f*t);
name = "sin wave ("+num2str(f)+"Hz)";



sinAudio = AudioData(name,y,fs);
sinAudio.audioPlot;
sinAudio.FFTPlot;
sinAudio.spectrogramPlot;
% sinAudio.save("./data/OOP_test/")
% copy_signal = sinAudio.Signal;

sinAudio.changeFs(fs/2);


%%
% DarknessValueのテスト

img = imread("pictures\1111\original\DSC1111-00001-ori.png");
img_gray = rgb2gray(img);
img_omitMask = omitMask(img_gray,20);

dValue = DarknessValue(img_omitMask,[1;1]);
dValue_r = dValue.dResample(8,1);

% figure;
% dValue.plotD_x(100);
% hold on;
% dValue_r.plotD_x(100);
% hold off;

D_th = 0.6;
w_th = 5;

TF = (dValue.dMat > D_th);
diff_TF = diff(TF);

w_th_r = w_th * dValue.rRatio; % 「山」の幅の最大値

startIdxC = cell(1,dValue.width);
endIdxC = cell(1,dValue.width);
pksNums = zeros(1,dValue.width);

for x=1:dValue.width % 溝底のstartIdx, endIdxを求める
    startIdx = find(diff_TF(:,x)==1)+1;
    endIdx = find(diff_TF(:,x)==-1);

    if endIdx(1)<startIdx(1)
        endIdx = endIdx(2:length(endIdx));
    end

    if endIdx(end)<startIdx(end)
        startIdx = startIdx(1:length(startIdx)-1);
    end

    btmIdx = find((endIdx-startIdx) < w_th_r); % 溝底に対応するstartIdxのIdxを調べる
    startIdx_btm = startIdx(btmIdx);
    endIdx_btm = endIdx(btmIdx);

    pksNum = length(btmIdx);

    startIdxC{1,x} = [x*ones(pksNum,1), startIdx_btm];
    endIdxC{1,x} = [x*ones(pksNum,1), endIdx_btm];
    pksNums(1,x) = pksNum;
end

sIdxs = vertcat(startIdxC{:});
eIdxs = vertcat(endIdxC{:});

% sIdxs(:,2) = 1 + (sIdxs(:,2)-1)/dValue.rRatio;
% eIdxs(:,2) = 1 + (eIdxs(:,2)-1)/dValue.rRatio;

%%
dots_localMax = GrooveCandidates(dValue,pksNums,startIdxC,endIdxC,"localMax");


