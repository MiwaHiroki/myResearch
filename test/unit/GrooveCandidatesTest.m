% GrooveCandidates クラスの単体テスト
classdef GrooveCandidatesTest < matlab.unittest.TestCase

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
            testCase.dValue = DarknessValue(imgData);
        end

        function openHiddenFigure(testCase)
            testCase.fig = figure('Visible', 'off');
            testCase.addTeardown(@() close(testCase.fig));
        end
    end

    methods (Test)
        function testConstructorCopiesMetaFromDarknessValue(testCase)
            gc = GrooveCandidates(testCase.dValue);
            testCase.verifyEqual(gc.imgID, [3; 4]);
            testCase.verifyEqual(gc.width, 3);
            testCase.verifyEqual(gc.height, 6);
            testCase.verifyFalse(gc.rsmplTF);
            testCase.verifyEqual(gc.rRatio, [1; 1]);
        end

        function testConstructorInitializesEmptyPksCell(testCase)
            gc = GrooveCandidates(testCase.dValue);
            testCase.verifySize(gc.pksCell, [1, 3]);
            testCase.verifyTrue(all(cellfun(@isempty, gc.pksCell)), ...
                "pksCell は初期状態では全て空であるべき");
        end

        function testDefaultConstructorIsEmpty(testCase)
            gc = GrooveCandidates();
            testCase.verifyEmpty(gc.pksCell);
        end

        function testShowCandidatesDrawsScatter(testCase)
            gc = GrooveCandidates(testCase.dValue);
            gc.pksCell{1} = [1, 3];
            gc.pksCell{2} = [2, 4];
            gc.showCandidates();
            testCase.verifyNotEmpty(findobj(testCase.fig, 'Type', 'scatter'), ...
                "showCandidates は scatter を描画すべき");
        end

        function testShowCandidatesWithOneArg(testCase)
            gc = GrooveCandidates(testCase.dValue);
            gc.pksCell{1} = [1, 3];
            gc.pksCell{2} = [2, 4];
            gc.showCandidates();
            s = findobj(testCase.fig, 'Type', 'scatter');
            testCase.verifyEqual(s.SizeData, 5);
            testCase.verifyEqual(s.CData, validatecolor("cyan"));
            testCase.verifyEqual(s.Marker, 'o');
            testCase.verifyEqual(s.MarkerFaceColor, 'flat');
        end

        function testShowCandidatesWithTwoArgs(testCase)
            gc = GrooveCandidates(testCase.dValue);
            gc.pksCell{1} = [1, 3];
            gc.pksCell{2} = [2, 4];
            gc.showCandidates("red");
            s = findobj(testCase.fig, 'Type', 'scatter');
            testCase.verifyEqual(s.SizeData, 5);
            testCase.verifyEqual(s.CData, validatecolor("red"));
            testCase.verifyEqual(s.Marker, 'o');
            testCase.verifyEqual(s.MarkerFaceColor, 'flat');
        end

        function testShowCandidatesWithThreeArgs(testCase)
            gc = GrooveCandidates(testCase.dValue);
            gc.pksCell{1} = [1, 3];
            gc.pksCell{2} = [2, 4];
            gc.showCandidates("green", 12);
            s = findobj(testCase.fig, 'Type', 'scatter');
            testCase.verifyEqual(s.SizeData, 12);
            testCase.verifyEqual(s.CData, validatecolor("green"));
            testCase.verifyEqual(s.Marker, 'o');
            testCase.verifyEqual(s.MarkerFaceColor, 'flat');
        end
    end
end
