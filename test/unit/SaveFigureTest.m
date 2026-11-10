% 図の保存関数（saveFigure, saveSlideFigure, savePaperFigure）の単体テスト
%
% 保存されるファイル、同じ名前のファイルがあるときの扱い、名前が命名規則から
% 外れているときの警告（checkFigureName:invalidName）を確かめる。
classdef SaveFigureTest < matlab.unittest.TestCase

    properties (Constant)
        VALID_NAME = "waveform_origD_centroid_manual_1014"
        INVALID_NAME = "amp_centroid_method"
    end

    properties
        saveDir
        fig
    end

    methods (TestClassSetup)
        function addToPath(testCase)
            import matlab.unittest.fixtures.PathFixture
            thisDir = fileparts(mfilename('fullpath'));
            testCase.applyFixture(PathFixture(fullfile(thisDir, '..', '..', 'src')));
        end
    end

    methods (TestMethodSetup)
        function makeTempDir(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture = testCase.applyFixture(TemporaryFolderFixture);
            testCase.saveDir = string(fixture.Folder);
        end

        function makeFigure(testCase)
            testCase.fig = figure('Visible', 'off');
            testCase.addTeardown(@close, testCase.fig);
            plot(axes(testCase.fig), 1:10, rand(1,10));
        end
    end

    methods (Test)
        %% saveFigure
        function testSavesPngAndFig(testCase)
            files = testCase.verifyWarningFree( ...
                @() saveFigure(testCase.fig, testCase.saveDir, testCase.VALID_NAME));
            testCase.verifyEqual(files, ...
                fullfile(testCase.saveDir, testCase.VALID_NAME + [".png"; ".fig"]));
            testCase.verifyTrue(all(isfile(files)));
        end

        function testSaveFigFalseSavesPngOnly(testCase)
            files = saveFigure(testCase.fig, testCase.saveDir, testCase.VALID_NAME, SaveFig=false);
            testCase.verifyEqual(files, fullfile(testCase.saveDir, testCase.VALID_NAME + ".png"));
            testCase.verifyFalse(isfile(fullfile(testCase.saveDir, testCase.VALID_NAME + ".fig")));
        end

        function testDoesNotOverwriteByDefault(testCase)
            saveFigure(testCase.fig, testCase.saveDir, testCase.VALID_NAME);
            testCase.verifyError( ...
                @() saveFigure(testCase.fig, testCase.saveDir, testCase.VALID_NAME), ...
                "saveFigure:fileExists");
        end

        function testOverwriteTrue(testCase)
            saveFigure(testCase.fig, testCase.saveDir, testCase.VALID_NAME);
            files = testCase.verifyWarningFree(@() saveFigure(testCase.fig, ...
                testCase.saveDir, testCase.VALID_NAME, Overwrite=true));
            testCase.verifyTrue(all(isfile(files)));
        end

        function testWarnsButSavesInvalidName(testCase)
            files = testCase.verifyWarning( ...
                @() saveFigure(testCase.fig, testCase.saveDir, testCase.INVALID_NAME), ...
                "checkFigureName:invalidName");
            testCase.verifyTrue(all(isfile(files)));
        end

        %% saveSlideFigure・savePaperFigure の名前の確認
        function testSlideFigureWarnsInvalidName(testCase)
            testCase.verifyWarning(@() saveSlideFigure(testCase.fig, testCase.saveDir, ...
                testCase.INVALID_NAME, 8, 8), "checkFigureName:invalidName");
            testCase.verifyTrue(isfile(fullfile(testCase.saveDir, testCase.INVALID_NAME + ".png")));
        end

        function testPaperFigureWarnsInvalidName(testCase)
            testCase.verifyWarning(@() savePaperFigure(testCase.fig, testCase.saveDir, ...
                testCase.INVALID_NAME, 7.9, 5), "checkFigureName:invalidName");
        end

        function testPaperFigureStillErrorsOnLatexChars(testCase)
            testCase.verifyError(@() savePaperFigure(testCase.fig, testCase.saveDir, ...
                "waveform_(origD)", 7.9, 5), "savePaperFigure:invalidName");
        end
    end
end
