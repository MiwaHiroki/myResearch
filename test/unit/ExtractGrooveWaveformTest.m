% extractGrooveWaveform の単体テスト
% findGrooveCenter -> extractGrooveShape -> detrendGrooveShapeの合成であることを検証する
classdef ExtractGrooveWaveformTest < matlab.unittest.TestCase

    methods (TestClassSetup)
        function addToPath(testCase)
            import matlab.unittest.fixtures.PathFixture
            thisDir = fileparts(mfilename('fullpath'));
            srcDir  = fullfile(thisDir, '..', '..', 'src');
            testCase.applyFixture(PathFixture(srcDir));
        end
    end

    methods (Test)
        function testEqualsManualChainingOfSubFunctions(testCase)
            % findpeaksは配列の端にあるピークを検出しないため、両端に単発の
            % アンカー点を置いてクラスタを内側のピークにする（FindGrooveCenterTestと同様）
            x = (1:40)';
            yLow = 10 + 0.1*(mod((0:39)',5)-2);
            yHigh = 100 + 0.1*(mod((0:39)',5)-2);
            pksCor = [x, yLow; x, yHigh; 1,-50; 1,210];
            xQuery = (1:40)';

            actual = extractGrooveWaveform(pksCor, 8, xQuery, ...
                BinWidth=2, MinPeakHeight=20, Tolerance=3, PolyDegree=2);

            groove1Center = findGrooveCenter(pksCor, 8, BinWidth=2, MinPeakHeight=20);
            expectedPoints = extractGrooveShape(pksCor, groove1Center, xQuery, Tolerance=3);
            expected = detrendGrooveShape(expectedPoints, PolyDegree=2);

            testCase.verifyEqual(actual, expected);
        end

        function testNoPeaksFoundErrorPropagates(testCase)
            x = (1:5)';
            y = [10;12;14;16;18];
            pksCor = [x, y];
            xQuery = (1:5)';

            testCase.verifyError(@() extractGrooveWaveform(pksCor, 10, xQuery, ...
                BinWidth=2, MinPeakHeight=100, Tolerance=3), ...
                "findGrooveCenter:noPeaksFound");
        end
    end
end
