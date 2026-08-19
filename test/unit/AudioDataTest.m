% AudioData クラスの単体テスト
classdef AudioDataTest < matlab.unittest.TestCase

    properties
        fig
        fs   = 8000
        signal
        name = "sin wave (500Hz)"
        audio
    end

    methods (TestClassSetup)
        function addToPath(testCase)
            import matlab.unittest.fixtures.PathFixture
            thisDir = fileparts(mfilename('fullpath'));
            srcDir  = fullfile(thisDir, '..', '..', 'src');
            testCase.applyFixture(PathFixture(srcDir));
        end
    end

    methods (TestMethodSetup)
        function buildAudio(testCase)
            % 0.5 秒の正弦波（列ベクトル）
            t = (0:1/testCase.fs:0.5)';
            testCase.signal = sin(2*pi*500*t);
            testCase.audio  = AudioData(testCase.name, testCase.signal, testCase.fs);
        end

        function openHiddenFigure(testCase)
            testCase.fig = figure('Visible', 'off');
            testCase.addTeardown(@() close(testCase.fig));
        end
    end

    methods (Test)
        function testConstructorStoresNameSignalFs(testCase)
            testCase.verifyEqual(testCase.audio.name, testCase.name);
            testCase.verifyEqual(testCase.audio.fs, testCase.fs);
            testCase.verifyEqual(testCase.audio.signal, testCase.signal, 'AbsTol', 1e-12);
        end

        function testSignalStoredAsColumn(testCase)
            testCase.verifySize(testCase.audio.signal, [numel(testCase.signal), 1], ...
                "signal は列ベクトルとして保持されるべき");
        end

        function testFilenameReplacesSpacesWithUnderscore(testCase)
            testCase.verifyEqual(testCase.audio.filename, "sin_wave_(500Hz)");
        end

        function testFilenameWithoutSpaces(testCase)
            a = AudioData("clip01", testCase.signal, testCase.fs);
            testCase.verifyEqual(a.filename, "clip01");
        end

        function testPropertiesAreReadOnly(testCase)
            % SetAccess = private のため外部からの代入はエラー
            testCase.verifyError(@() setFsExternally(testCase.audio), ...
                "MATLAB:class:SetProhibited");
        end

        function testSaveAudioWritesWavFile(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            f = testCase.applyFixture(TemporaryFolderFixture);
            dir = string(f.Folder) + filesep;

            testCase.audio.saveAudio(dir);

            expectedFile = dir + testCase.audio.filename + ".wav";
            testCase.assertTrue(isfile(expectedFile), "wav ファイルが作成されるべき");

            [y, fsRead] = audioread(expectedFile);
            testCase.verifyEqual(fsRead, testCase.fs);
            testCase.verifyEqual(numel(y), numel(testCase.signal));
        end

        function testPlotWaveformDrawsLine(testCase)
            testCase.audio.plotWaveform();
            testCase.verifyNotEmpty(findobj(testCase.fig, 'Type', 'line'));
        end

        function testPlotFFTDrawsLine(testCase)
            testCase.audio.plotFFT();
            testCase.verifyNotEmpty(findobj(testCase.fig, 'Type', 'line'));
        end

        function testPlotSpectrogramRuns(testCase)
            % stft は Signal Processing Toolbox が必要
            testCase.assumeNotEmpty(which("stft"), ...
                "stft が利用できないためスキップ");
            longAudio = AudioData("chirp", sin(2*pi*500*(0:1/testCase.fs:1)'), testCase.fs);
            longAudio.plotSpectrogram();
            testCase.verifyNotEmpty(findobj(testCase.fig, 'Type', 'surface'));
        end
    end
end

% --- ローカル関数 -------------------------------------------------------
function setFsExternally(audio)
    audio.fs = 1;   %#ok<NASGU>  SetAccess=private のためエラーになるはず
end
