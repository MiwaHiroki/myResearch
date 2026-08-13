% GrooveExtractor クラスの単体テスト
classdef GrooveExtractorTest < matlab.unittest.TestCase

    properties
        dMat        % 既知の暗さ行列（6行3列）
        imgData
        dMap
        extractor
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
        function buildFixtures(testCase)
            % 各列に「明・明・暗・暗・明・明」というパターンを持つ合成画像
            dcol = [0.1; 0.1; 0.9; 0.9; 0.1; 0.1];
            testCase.dMat = repmat(dcol, 1, 3);        % 6x3
            img = 255 * (1 - testCase.dMat);           % dMat = 1 - img/255 の逆変換
            testCase.imgData = ImageData(img, [3; 4]);
            testCase.dMap = DarknessMap(testCase.imgData).setDiffTF(0.5);
            testCase.extractor = GrooveExtractor(testCase.dMap);
        end
    end

    methods (Test)
        function testConstructorSizesCells(testCase)
            testCase.verifySize(testCase.extractor.startIdxCells, [1, 3]);
            testCase.verifySize(testCase.extractor.endIdxCells, [1, 3]);
        end

        function testFindThresholdIntervals(testCase)
            [firstIdx, lastIdx] = testCase.extractor.findThresholdIntervals(testCase.dMap, 1);
            testCase.verifyEqual(firstIdx, 3);   % 暗領域は 3〜4 行目
            testCase.verifyEqual(lastIdx, 4);
        end

        function testFindGrooveBottomIntervals(testCase)
            [obj, btmFirstIdx, btmLastIdx, numPeaks] = ...
                testCase.extractor.findGrooveBottomIntervals(testCase.dMap, 1, 3, 4, 5);
            testCase.verifyEqual(btmFirstIdx, 3);
            testCase.verifyEqual(btmLastIdx, 4);
            testCase.verifyEqual(numPeaks, 1);
            testCase.verifyEqual(obj.startIdxCells{1, 1}, [1, 3]);
            testCase.verifyEqual(obj.endIdxCells{1, 1}, [1, 4]);
        end

        function testExtractByCentroid(testCase)
            obj = testCase.extractor.findGrooveBottomIntervals(testCase.dMap, 1, 3, 4, 5);
            centroidY = obj.extractByCentroid(testCase.dMap, 1);
            % 重心 = (3*0.9 + 4*0.9) / (0.9 + 0.9) = 3.5
            testCase.verifyEqual(centroidY, 3.5, 'AbsTol', 1e-10);
        end

        function testExtractByLocalMax(testCase)
            obj = testCase.extractor.findGrooveBottomIntervals(testCase.dMap, 1, 3, 4, 5);
            maxY = obj.extractByLocalMax(testCase.dMap, 1);
            % 3,4 行目とも最大値 0.9 なので、タイの平均 = 3.5 行目
            testCase.verifyEqual(maxY, 3.5);
        end
    end
end
