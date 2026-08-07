% 2026/06/03作成
% 音声信号の簡単な処理を行うAudioDataクラス
%
% 2026/06/15書き換え: MediaDataを継承しない
% 2026/08/07: 継承元だったMediaDataは誰にも継承されず孤立していたため
%   src/archive/へ退避した（rename-proposal.mdのP3）。
%   src/のデータクラスはいずれも継承関係を持たない独立した値クラスとする。

classdef AudioData
    properties (SetAccess = private)
        name (1,1) string
        signal (:,1) double
        fs (1,1) double
        filename (1,1) string
    end

    methods
        function audio = AudioData(name,signal,fs)
            audio.name = name;
            audio.signal = signal;
            audio.fs = fs;
            audio.filename = replace(name," ","_");
        end

        function audioPlot(audio)
            tidx = (1:length(audio.signal))'/audio.fs;
            % figure;
            plot(tidx,audio.signal);
            title(audio.name);
            xlabel("$t$ [s]");ylabel("Amplitude");
            xlim([tidx(1) tidx(end)]);ylim([-1 1]);
        end

        function FFTPlot(audio)
            len = length(audio.signal);
            fidx = (1:len) / len * audio.fs;
            Y = fft(audio.signal);
            Y = Y / len * 2;
            % figure;
            plot(fidx,20*log10(abs(Y)));
            title("FFT of "+audio.name)
            xlabel("frequency[Hz]");ylabel("power[dB]")
            % xlim([0 2e3])
            xlim([0 1e4]);ylim([-120 0]);
            % exportgraphics(fig,dir+"FFT_"+append+".pdf","ContentType","vector")
            % exportgraphics(fig,dir+"FFT_"+append+".png","Resolution",600);
            % saveas(fig,dir+"FFT_"+append+".fig");
        end

        function spectrogramPlot(audio,winSize,opts)
            % ShowTitle,ShowColorbarは原稿用の図で不要なときにfalseにする
            arguments
                audio
                winSize (1,1) double = 1024
                opts.ShowTitle (1,1) logical = true
                opts.ShowColorbar (1,1) logical = true
            end

            [s,f,t] = stft(audio.signal,audio.fs,...
                "Window",hann(winSize),"OverlapLength",winSize/2,'FrequencyRange','onesided');
            s = s * 2 / size(s,1);

            % figure;
            ax=gca;
            mesh(t,f,20*log10(abs(s)));
            xlim([0 max(t)]);ylim([0 5e3]);clim([-120 0]);
            if opts.ShowTitle
                title("Spectrogram of "+audio.name);
            end
            xlabel("Time [s]");ylabel("Frequency [Hz]")
            view(0,90)
            colormap jet;
            if opts.ShowColorbar
                c=colorbar;
                c.TickLabelInterpreter = "latex"; c.Label.String = "Magintude [dB]";
                c.Label.Interpreter = "latex";
            end
            ax.YAxis.Exponent = 3;
            % exportgraphics(fig,dir+"Stft_"+append+".pdf","ContentType","image","Resolution",600)
            % exportgraphics(fig,dir+"Stft_"+append+".png","Resolution",600)
            % saveas(fig,dir+"Stft_"+append+".fig");
        end

        function saveAudio(audio,dir)
            audiowrite(dir+audio.filename+".wav", audio.signal, audio.fs);
        end

        function playAudio(audio)
            sound(audio.signal,audio.fs);
        end
    end
end