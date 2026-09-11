% detrendGrooveShape の単体テスト
classdef DetrendGrooveShapeTest < matlab.unittest.TestCase

    methods (TestClassSetup)
        function addToPath(testCase)
            import matlab.unittest.fixtures.PathFixture
            thisDir = fileparts(mfilename('fullpath'));
            srcDir  = fullfile(thisDir, '..', '..', 'src');
            testCase.applyFixture(PathFixture(srcDir));
        end
    end

    methods (Test)
        function testRemovesKnownCubicTrendAndZeroMeans(testCase)
            x = (1:20)';
            y = 2*x.^3 - 3*x.^2 + 5*x - 7;
            points = [x, y];

            pointsDetrended = detrendGrooveShape(points, PolyDegree=3);

            testCase.verifyEqual(pointsDetrended(:,2), zeros(20,1), 'AbsTol', 1e-6);
            testCase.verifyEqual(mean(pointsDetrended(:,2)), 0, 'AbsTol', 1e-9);
        end

        function testXCoordinatesUnchanged(testCase)
            x = (1:10)';
            y = x.^2;
            points = [x, y];

            pointsDetrended = detrendGrooveShape(points, PolyDegree=2);

            testCase.verifyEqual(pointsDetrended(:,1), x);
        end

        function testNonDefaultPolyDegree(testCase)
            x = (1:10)';
            y = 4*x + 1; % 直線
            points = [x, y];

            % 1次で十分近似できる直線を0次（定数）でデトレンドすると
            % 残差は0にならないが、平均は必ず0になる
            pointsDetrended = detrendGrooveShape(points, PolyDegree=0);

            testCase.verifyEqual(mean(pointsDetrended(:,2)), 0, 'AbsTol', 1e-9);
            testCase.verifyNotEqual(pointsDetrended(:,2), zeros(10,1));

            % 1次なら残差はほぼ0
            pointsDetrended1 = detrendGrooveShape(points, PolyDegree=1);
            testCase.verifyEqual(pointsDetrended1(:,2), zeros(10,1), 'AbsTol', 1e-9);
        end

        function testDefaultPolyDegreeIsThree(testCase)
            x = (1:20)';
            y = x.^3;
            points = [x, y];

            pointsDetrended = detrendGrooveShape(points);

            testCase.verifyEqual(pointsDetrended(:,2), zeros(20,1), 'AbsTol', 1e-6);
        end
    end
end
