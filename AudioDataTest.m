% 2026/06/03作成
% AudioData.mのテストを行う

%%
set(0,'defaultTextInterpreter','latex');
set(0,'defaultAxesTickLabelInterpreter','latex');
set(0,'defaultLegendInterpreter','latex');
set(0,'defaultColorbarTickLabelInterpreter','latex');
%%

fs = 48000;
tmax = 1;
t = 0:1/fs:tmax;
f = 500;
A = 1;
y = A * sin(2*pi*f*t);
name = "sin wave ("+num2str(f)+"Hz)";

sinAudio = AudioData(name,y,fs);
% sinAudio.audioPlot;
% sinAudio.FFTPlot;
% sinAudio.spectrogramPlot;
% sinAudio.save("./data/OOP_test/")
% copy_signal = sinAudio.Signal;

sinAudio.changeFs(fs/2);
