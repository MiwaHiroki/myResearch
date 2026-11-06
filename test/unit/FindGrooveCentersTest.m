% findGrooveCenters の単体テスト
% （受け入れテスト MultiGrooveAcceptanceTest で見ていない細部を確かめる）
%
% 合成データ：補正後の y の中心が OUTER, 0, -27, ..., -135 の溝（各 N_COLS 点、±0.4 の
% 正弦波のゆらぎ）。1本目（0）の外側（y が大きい側）にも溝を1本置き、ヒストグラムの
% 両端に偽の点を置く（findpeaks は配列の両端のビンを山にしないため）。
classdef FindGrooveCentersTest < matlab.unittest.TestCase

    properties (Constant)
        N_COLS = 600
        PITCH  = 27
    end

    methods (TestClassSetup)
        function addToPath(testCase)
            import matlab.unittest.fixtures.PathFixture
            thisDir = fileparts(mfilename('fullpath'));
            srcDir  = fullfile(thisDir, '..', '..', 'src');
            testCase.applyFixture(PathFixture(srcDir));
        end
    end

    methods (Test)

        function testCentersAreBinCentersOfPeaks(testCase)
            % 返す値は、選んだ山のビンの中心そのもの（info.binCenters の要素）
            pksCor = testCase.points(0.3);

            [centers, info] = findGrooveCenters(pksCor, 4, BinWidth=1, MinPeakHeight=0.3*testCase.N_COLS);

            testCase.verifyTrue(all(ismember(centers, info.binCenters)));
            testCase.verifyEqual(centers, info.peakCenters(info.firstIdx:-1:info.firstIdx-3).');
            % ビンの端は BinWidth の整数倍なので、中心は 0.5 の奇数倍
            testCase.verifyEqual(mod(centers, 1), 0.5*ones(4,1), "AbsTol", 1e-12);
        end

        function testSelectsDescendingAndSkipsOuterGroove(testCase)
            % 外側（y が大きい側）の溝は選ばない
            pksCor = testCase.points(0.3);

            centers = findGrooveCenters(pksCor, 6, BinWidth=1, MinPeakHeight=0.3*testCase.N_COLS);

            testCase.verifyLessThanOrEqual(abs(centers - (0.3 - testCase.PITCH*(0:5))'), 0.5 + 1e-9);
            testCase.verifyTrue(all(centers < 1));
        end

        function testFakePointsBetweenGroovesAreNotPeaks(testCase)
            % 溝と溝の間の偽の点（MinPeakHeight より少ない）は山にならず、数えない
            pksCor = testCase.points(0.3, NumFake=30);

            [centers, info] = findGrooveCenters(pksCor, 3, BinWidth=1, MinPeakHeight=0.3*testCase.N_COLS);

            testCase.verifyNumElements(info.peakCenters, 7);   % 外側1本 + 6本
            testCase.verifyLessThanOrEqual(abs(centers - [0.3; -26.7; -53.7]), 0.5 + 1e-9);
        end

        function testLowMinPeakHeightCountsFakePeaks(testCase)
            % MinPeakHeight を偽の点より低くすると、偽の山を数えて2本目がずれる
            % （しきい値の役目の確認。実データの写真2の偽の山に相当する）
            pksCor = testCase.points(0.3, NumFake=30);

            centers = findGrooveCenters(pksCor, 2, BinWidth=1, MinPeakHeight=20);

            testCase.verifyLessThanOrEqual(abs(centers(2) - (0.3 - testCase.PITCH/2)), 0.5 + 1e-9);
        end

        function testNoPeaksIsWarningFree(testCase)
            % MinPeakHeight が最も高いビンより高いとき、findpeaks の警告を出さずにエラーにする
            pksCor = testCase.points(0.3);

            testCase.verifyWarningFree(@() testCase.callAndCatch(pksCor, 1e5));
            testCase.verifyError(@() findGrooveCenters(pksCor, 2, BinWidth=1, MinPeakHeight=1e5), ...
                "findGrooveCenters:noPeaksFound");
        end

        function testEmptyPointsErrors(testCase)
            testCase.verifyError(@() findGrooveCenters(zeros(0,2), 1, BinWidth=1, MinPeakHeight=1), ...
                "findGrooveCenters:noPeaksFound");
        end

        function testExactlyEnoughPeaks(testCase)
            % 1本目より y の小さい側の山は5個：6本は選べ、7本は notEnoughPeaks
            pksCor = testCase.points(0.3);

            centers = findGrooveCenters(pksCor, 6, BinWidth=1, MinPeakHeight=0.3*testCase.N_COLS);
            testCase.verifyNumElements(centers, 6);
            testCase.verifyError(@() findGrooveCenters(pksCor, 7, BinWidth=1, ...
                MinPeakHeight=0.3*testCase.N_COLS), "findGrooveCenters:notEnoughPeaks");
        end

        function testFirstPeakWithinMaxFirstOffset(testCase)
            % 1本目の山が FirstCenter から 4.5px（MaxFirstOffset=5 以内）なら選ぶ
            pksCor = testCase.points(4.3);

            centers = findGrooveCenters(pksCor, 2, BinWidth=1, MinPeakHeight=0.3*testCase.N_COLS);

            testCase.verifyEqual(centers(1), 4.5, "AbsTol", 1e-12);
        end
    end

    methods (Access = private)

        function pksCor = points(testCase, offset, opts)
            % 補正後の点群。中心 offset + 27, offset, offset-27, ..., offset-135 の溝と、
            % 溝の間・両端の偽の点（NumFake 点ずつ）
            arguments
                testCase
                offset (1,1) double
                opts.NumFake (1,1) double = 12
            end
            x = (1:testCase.N_COLS)';
            ctrs = offset - testCase.PITCH*(-1:5);
            pksCor = zeros(0,2);
            for k = 1:numel(ctrs)
                pksCor = [pksCor; x, ctrs(k) + 0.4*sin(2*pi*x/(37 + 5*k))]; %#ok<AGROW>
            end
            edges = [ctrs(1) + testCase.PITCH, ctrs, ctrs(end) - testCase.PITCH];
            yMid = (edges(1:end-1) + edges(2:end)) / 2;
            xFake = linspace(10, testCase.N_COLS - 10, opts.NumFake)';
            for k = 1:numel(yMid)
                pksCor = [pksCor; xFake, yMid(k)*ones(size(xFake))]; %#ok<AGROW>
            end
        end

        function callAndCatch(~, pksCor, minPeakHeight)
            % エラーは捕まえて、警告だけを確かめる
            try
                findGrooveCenters(pksCor, 2, BinWidth=1, MinPeakHeight=minPeakHeight);
            catch
            end
        end
    end
end
