function soundCheck(y,fs,titleName,dir,append)

len = length(y);
tidx = ((1:len)/fs)';

fig=createFigure([0 0 6 4]);
% figure;
plot(tidx,y);xlim([tidx(1) tidx(end)]);ylim([-1 1]);
% title(titleName);
xlabel("Time [s]");ylabel("Amplitude");
% exportgraphics(fig,dir+"Amp_"+append+".pdf","ContentType","vector");
exportgraphics(fig,dir+"Amp_"+append+".png","Resolution",600);
saveas(fig,dir+"Amp_"+append+".fig");


% fft
fidx = (1:len) / len * fs;
Y = fft(y);
Y = Y / len * 2;
fig=createFigure([0 0 6 4]);
% figure;
plot(fidx,20*log10(abs(Y)));
% title("FFT of "+titleName)
xlabel("frequency[Hz]");ylabel("power[dB]")
% xlim([0 2e3])
xlim([0 1e4])
ylim([-120 0])
% exportgraphics(fig,dir+"FFT_"+append+".pdf","ContentType","vector")
exportgraphics(fig,dir+"FFT_"+append+".png","Resolution",600);
saveas(fig,dir+"FFT_"+append+".fig");

% stft
% fsが大きいので窓はかなり大きめ
[s,f,t] = stft(y,fs,"Window",hann(8192),"OverlapLength",8192/2,'FrequencyRange','onesided');
s = s * 2 / size(s,1);

fig=createFigure([0 0 6 6]);
% figure;
ax=gca;
mesh(t,f,20*log10(abs(s)));
xlim([0 max(t)]);ylim([0 5e3]);clim([-120 0]);
% title("spectrogram of "+titleName);
xlabel("Time [s]");ylabel("Frequency [Hz]")
view(0,90)
colormap jet; c=colorbar;
c.TickLabelInterpreter = "latex"; c.Label.String = "Magintude [dB]";
c.Label.Interpreter = "latex";
ax.YAxis.Exponent = 3;
% exportgraphics(fig,dir+"Stft_"+append+".pdf","ContentType","image","Resolution",600)
exportgraphics(fig,dir+"Stft_"+append+".png","Resolution",600)
saveas(fig,dir+"Stft_"+append+".fig");

end
