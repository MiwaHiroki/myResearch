% 針で再生した音についての解析

%%
% 発表資料作成用
set(0,'defaultTextInterpreter','latex');
set(0,'defaultAxesTickLabelInterpreter','latex');
set(0,'defaultLegendInterpreter','latex');
set(0,'defaultColorbarTickLabelInterpreter','latex');

%%
% フル尺
[y_ori,fs_stylus] = audioread("audio files\Audio 1_01.wav");

% 「畢竟するに、砂上の楼閣に」
% [y,fs_stylus] = audioread("./audio files/Audio 1_01_01.wav");
% [y2,~] = audioread("./audio files/Audio 1_01_tri(20260113).wav");

% soundCheck(y,fs_stylus,"Sound from Stylus")

% StylusPlayback = AudioData("StylusPlayback",y,fs_stylus);
% StylusPlayback_tri = AudioData("StylusPlayback_tri",y2,fs_stylus);

% y_oriの65秒から88秒まで
% 「しかし、地上の建築が ~ すぎずと言うべし」
tlim = [65,88];
y_tri = y_ori(tlim(1)*fs_stylus:tlim(2)*fs_stylus);
StylusPlayback = AudioData("StylusPlayback(1sentence)",y_tri,fs_stylus);
StylusPlayback.saveAudio("./audio files/")

%%
% 「クレムリン宮殿は」の「wa」だけ解析、保存する
dir = "./data/0623/";
tlim2 = [16.1,16.9];
sampleLim = round(tlim2*fs_stylus);
y_wa = y_tri(sampleLim(1):sampleLim(2));
StylusPlayback_wa = AudioData("StylusPlayback(wa)",y_wa,fs_stylus);

StylusPlayback_wa.saveAudio("./audio files/")

fig = createFigure([0 0 6 4]);
StylusPlayback_wa.audioPlot();
saveas(fig,dir+StylusPlayback_wa.name+"_amp.fig");saveas(fig,dir+StylusPlayback_wa.name+"_amp.png");

fig = createFigure([0 0 6 4]);
StylusPlayback_wa.FFTPlot();
saveas(fig,dir+StylusPlayback_wa.name+"_fft.fig");saveas(fig,dir+StylusPlayback_wa.name+"_fft.png");

fig = createFigure([0 0 6 6]);
StylusPlayback_wa.spectrogramPlot();
saveas(fig,dir+StylusPlayback_wa.name+"_stft.fig");saveas(fig,dir+StylusPlayback_wa.name+"_stft.png");

%%
y_wa_highpass = highpass(y_wa,100,fs_stylus);
StylusPlayback_wa_highpass = AudioData("StylusPlayback(wa)(highpass)",y_wa_highpass,fs_stylus);
tmpName = StylusPlayback_wa_highpass.filename;

fig = createFigure([0 0 6 4]);
StylusPlayback_wa_highpass.audioPlot();
saveas(fig,dir+tmpName+"_amp.fig");saveas(fig,dir+tmpName+"_amp.png");

fig = createFigure([0 0 6 4]);
StylusPlayback_wa_highpass.FFTPlot();
saveas(fig,dir+tmpName+"_fft.fig");saveas(fig,dir+tmpName+"_fft.png");

fig = createFigure([0 0 6 6]);
StylusPlayback_wa_highpass.spectrogramPlot();
saveas(fig,dir+tmpName+"_stft.fig");saveas(fig,dir+tmpName+"_stft.png");

%%
% 0615作成の音声データとの比較
[audio_0615,fs] = audioread("./data/0615/audio_from_centroid_method_(resampled).wav");
tidx_0615 = (0:length(audio_0615)-1)'/fs;


figure;
plot(tidx_0615,audio_0615);hold on;
StylusPlayback_wa_highpass.audioPlot();
title("Produced Audio and Stylus Playback");
legend(["Produced Audio (0615)","Stylus Playback"]);
lgd = legend;
lgd.ItemHitFcn = @togglevisibility;

%%
% スペクトログラムの表示（AudioDataクラスを使わない）
%{
titleName = "Sound from Stylus";
[s,f,t] = stft(y,fs_stylus,"Window",hann(2048),"OverlapLength",2048/2,'FrequencyRange','onesided');
s = s * 2 / size(s,1);

figure;
mesh(t,f,20*log10(abs(s)));
xlim([0 max(t)]);ylim([0 1e4]);clim([-120 0]);
% title("spectrogram of "+titleName);xlabel("time[s]");ylabel("frequency[Hz]")
view(0,90)
colormap jet; c=colorbar;
c.TickLabelInterpreter = "latex"; c.Label.String = "Magintude [dB]";
c.Label.Interpreter = "latex";
f = gcf;ax = gca;
mySaveForPapers(f,ax,[0 0 9 6],"Spectrogram of "+titleName,"Time [s]","Frequency [Hz]","Stft_"+titleName+"_9x6cm");
% mySave(f,dir+"stft")
%}

%%

y_highPass = highpass(y2,100,fs_stylus);
[s,f,t] = stft(y_highPass,fs_stylus,"Window",hann(2048),"OverlapLength",2048/2,'FrequencyRange','onesided');
s = s * 2 / size(s,1);
figure;plot(y_highPass);
figure;
mesh(t,f,20*log10(abs(s)));
xlim([0 max(t)]);ylim([0 1e4]);clim([-120 0]);
view(0,90);
colormap jet; colorbar;

%%

y_highPass2 = y2(round(0.3*fs_stylus):round((0.3+3.85)*fs_stylus));
y_highPass2 = highpass(y_highPass2,100,fs_stylus);
[s,f,t] = stft(y_highPass2,fs_stylus,"Window",hann(2048),"OverlapLength",2048/2,'FrequencyRange','onesided');
s = s * 2 / size(s,1);

dir = "C:\Users\owner\Documents\HirokiMiwa\原稿\2026卒論\原稿資料\";

len = length(y_highPass2);

tidx = (1:len)/fs_stylus;
fig = createFigure([0 0 6 4]);
plot(tidx,y_highPass2);axis tight
xlabel("Time [s]");ylabel("Amplitude");
xlim([tidx(1) tidx(end)]);ylim([-1 1]);
exportgraphics(fig,dir+"Stylus_Amp.pdf","ContentType","vector")
exportgraphics(fig,dir+"Stylus_Amp.png","Resolution",600)

fig=createFigure([0 0 6 6]);
mesh(t,f,20*log10(abs(s)));
xlim([0 max(t)]);ylim([0 5e3]);clim([-120 0]);
view(0,90);
colormap jet; c=colorbar;
c.TickLabelInterpreter = "latex"; c.Label.String = "Magintude [dB]";
c.Label.Interpreter = "latex";
xlabel("Time [s]");ylabel("Frequency [Hz]");
ax = gca;
ax.YAxis.Exponent = 3;
exportgraphics(fig,dir+"Stylus_Stft.pdf","ContentType","image","Resolution",600)
exportgraphics(fig,dir+"Stylus_Stft.png","Resolution",600)

