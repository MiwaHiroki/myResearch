% findGrooveCenter の単体テスト
classdef FindGrooveCenterTest < matlab.unittest.TestCase

    methods (TestClassSetup)
        function addToPath(testCase)
            import matlab.unittest.fixtures.PathFixture
            thisDir = fileparts(mfilename('fullpath'));
            srcDir  = fullfile(thisDir, '..', '..', 'src');
            testCase.applyFixture(PathFixture(srcDir));
        end
    end

    methods (Test)
        function testReturnsPeakClosestToPrevCenter(testCase)
            % y=10付近とy=100付近に2つのクラスタを作る（どちらもヒストグラムの
            % ピークがMinPeakHeightを超える点数を持つ）。
            % findpeaksは配列の端にあるピークを検出しないため、両端に単発の
            % アンカー点を置いてクラスタを内側のピークにする。
            x = (1:40)';
            yLow = 10 + 0.1*(mod((0:39)',5)-2);   % 10の周りに40点
            yHigh = 100 + 0.1*(mod((0:39)',5)-2); % 100の周りに40点
            pksCor = [x, yLow; x, yHigh; 1,-50; 1,210];

            groove1Center = findGrooveCenter(pksCor, 8, BinWidth=2, MinPeakHeight=20);
            testCase.verifyEqual(groove1Center, 10, 'AbsTol', 2);

            groove1Center = findGrooveCenter(pksCor, 95, BinWidth=2, MinPeakHeight=20);
            testCase.verifyEqual(groove1Center, 100, 'AbsTol', 2);
        end

        function testErrorsWhenNoPeakReachesMinPeakHeight(testCase)
            % ヒストグラムのビンは複数あるが、どれもMinPeakHeightに届かない
            x = (1:5)';
            y = [10;12;14;16;18];
            pksCor = [x, y];

            testCase.verifyError(@() findGrooveCenter(pksCor, 10, ...
                BinWidth=2, MinPeakHeight=100), ...
                "findGrooveCenter:noPeaksFound");
        end
    end
end
