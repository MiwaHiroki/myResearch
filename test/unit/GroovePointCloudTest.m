% GroovePointCloud クラスの単体テスト
classdef GroovePointCloudTest < matlab.unittest.TestCase

    properties
        fig
        dValue
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
        function buildDependencies(testCase)
            dcol = [0.1; 0.1; 0.9; 0.9; 0.1; 0.1];
            dMat = repmat(dcol, 1, 3);     % 6x3
            img  = 255 * (1 - dMat);
            imgData = ImageData(img, [3; 4]);
            testCase.dValue = DarknessMap(imgData);
        end

        function openHiddenFigure(testCase)
            testCase.fig = figure('Visible', 'off');
            testCase.addTeardown(@() close(testCase.fig));
        end
    end

    methods (Test)
        function testConstructorCopiesMetaFromDarknessMap(testCase)
            gpc = GroovePointCloud(testCase.dValue);
            testCase.verifyEqual(gpc.imgID, [3; 4]);
            testCase.verifyEqual(gpc.width, 3);
            testCase.verifyEqual(gpc.height, 6);
            testCase.verifyFalse(gpc.rsmplTF);
            testCase.verifyEqual(gpc.scaleFactor, struct('row',1,'col',1));
        end

        function testConstructorInitializesEmptyPksCell(testCase)
            gpc = GroovePointCloud(testCase.dValue);
            testCase.verifySize(gpc.pksCell, [1, 3]);
            testCase.verifyTrue(all(cellfun(@isempty, gpc.pksCell)), ...
                "pksCell は初期状態では全て空であるべき");
        end

        function testDefaultConstructorIsEmpty(testCase)
            gpc = GroovePointCloud();
            testCase.verifyEmpty(gpc.pksCell);
        end

        function testShowPointsDrawsScatter(testCase)
            gpc = GroovePointCloud(testCase.dValue);
            gpc.pksCell{1} = [1, 3];
            gpc.pksCell{2} = [2, 4];
            gpc.showPoints();
            testCase.verifyNotEmpty(findobj(testCase.fig, 'Type', 'scatter'), ...
                "showPoints は scatter を描画すべき");
        end

        function testShowPointsWithOneArg(testCase)
            gpc = GroovePointCloud(testCase.dValue);
            gpc.pksCell{1} = [1, 3];
            gpc.pksCell{2} = [2, 4];
            gpc.showPoints();
            s = findobj(testCase.fig, 'Type', 'scatter');
            testCase.verifyEqual(s.SizeData, 5);
            testCase.verifyEqual(s.CData, validatecolor("cyan"));
            testCase.verifyEqual(s.Marker, 'o');
            testCase.verifyEqual(s.MarkerFaceColor, 'flat');
        end

        function testShowPointsWithTwoArgs(testCase)
            gpc = GroovePointCloud(testCase.dValue);
            gpc.pksCell{1} = [1, 3];
            gpc.pksCell{2} = [2, 4];
            gpc.showPoints("red");
            s = findobj(testCase.fig, 'Type', 'scatter');
            testCase.verifyEqual(s.SizeData, 5);
            testCase.verifyEqual(s.CData, validatecolor("red"));
            testCase.verifyEqual(s.Marker, 'o');
            testCase.verifyEqual(s.MarkerFaceColor, 'flat');
        end

        function testShowPointsWithThreeArgs(testCase)
            gpc = GroovePointCloud(testCase.dValue);
            gpc.pksCell{1} = [1, 3];
            gpc.pksCell{2} = [2, 4];
            gpc.showPoints("green", 12);
            s = findobj(testCase.fig, 'Type', 'scatter');
            testCase.verifyEqual(s.SizeData, 12);
            testCase.verifyEqual(s.CData, validatecolor("green"));
            testCase.verifyEqual(s.Marker, 'o');
            testCase.verifyEqual(s.MarkerFaceColor, 'flat');
        end
    end
end
