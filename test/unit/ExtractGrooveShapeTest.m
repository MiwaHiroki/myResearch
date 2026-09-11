% extractGrooveShape の単体テスト
classdef ExtractGrooveShapeTest < matlab.unittest.TestCase

    methods (TestClassSetup)
        function addToPath(testCase)
            import matlab.unittest.fixtures.PathFixture
            thisDir = fileparts(mfilename('fullpath'));
            srcDir  = fullfile(thisDir, '..', '..', 'src');
            testCase.applyFixture(PathFixture(srcDir));
        end
    end

    methods (Test)
        function testIntegerXQueryPassesThroughAndFillsGaps(testCase)
            % x=1,3,5にだけ点があり、x=2,4は欠損 -> 線形補間で埋まるはず
            pksCor = [1,10; 3,30; 5,50];
            xQuery = (1:5)';

            points = extractGrooveShape(pksCor, 30, xQuery, Tolerance=25);

            testCase.verifyEqual(points(:,1), xQuery);
            testCase.verifyEqual(points(:,2), [10;20;30;40;50], 'AbsTol', 1e-9);
        end

        function testFractionalXQueryUsesIsmemberAlignment(testCase)
            % QUERY_STEP=0.5相当の分数刻み。直接インデックス版では使えないケース
            xQuery = (1:0.5:3)'; % [1 1.5 2 2.5 3]
            pksCor = [1,10; 2,20; 3,30]; % 1.5,2.5は欠損

            points = extractGrooveShape(pksCor, 20, xQuery, Tolerance=15);

            testCase.verifyEqual(points(:,1), xQuery);
            testCase.verifyEqual(points(:,2), [10;15;20;25;30], 'AbsTol', 1e-9);
        end

        function testNoPointsWithinToleranceDoesNotError(testCase)
            pksCor = [1,1000; 2,1000; 3,1000];
            xQuery = (1:3)';

            points = extractGrooveShape(pksCor, 0, xQuery, Tolerance=1);

            testCase.verifyEqual(points(:,1), xQuery);
            % fillmissingは全てNaNの入力に対してはNaNのまま返す
            testCase.verifyEqual(points(:,2), NaN(3,1));
        end
    end
end
