% DarknessMap クラスの単体テスト
classdef DarknessMapTest < matlab.unittest.TestCase

    properties
        fig
        dMat        % 既知の暗さ行列（6行3列）
        imgData
        dMap
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
        function buildDarknessMap(testCase)
            % 各列に「明・明・暗・暗・明・明」というパターンを持つ合成画像
            dcol = [0.1; 0.1; 0.9; 0.9; 0.1; 0.1];
            testCase.dMat = repmat(dcol, 1, 3);        % 6x3
            img = 255 * (1 - testCase.dMat);           % dMat = 1 - img/255 の逆変換
            testCase.imgData = ImageData(img, [3; 4]);
            testCase.dMap  = DarknessMap(testCase.imgData);
        end

        function openHiddenFigure(testCase)
            testCase.fig = figure('Visible', 'off');
            testCase.addTeardown(@() close(testCase.fig));
        end
    end

    methods (Test)
        function testConstructorComputesDMat(testCase)
            testCase.verifyEqual(testCase.dMap.dMat, testCase.dMat, 'AbsTol', 1e-10);
        end

        function testConstructorCopiesImageMeta(testCase)
            testCase.verifyEqual(testCase.dMap.imgID, [3; 4]);
            testCase.verifyEqual(testCase.dMap.width, 3);
            testCase.verifyEqual(testCase.dMap.height, 6);
            testCase.verifyEqual(testCase.dMap.nRows, 6);
            testCase.verifyEqual(testCase.dMap.nCols, 3);
        end

        function testConstructorDefaults(testCase)
            testCase.verifyFalse(testCase.dMap.isResampled);
            testCase.verifyEqual(testCase.dMap.scaleFactor, struct('row',1,'col',1));
        end

        function testPropertiesAreReadOnly(testCase)
            testCase.verifyError(@() setDMatExternally(testCase.dMap), ...
                "MATLAB:class:SetProhibited");
        end

        function testDResample(testCase)
            testCase.assumeNotEmpty(which("resample"), ...
                "resample が利用できないためスキップ");
            newObj = testCase.dMap.dResample(2, 1);

            testCase.verifyTrue(newObj.isResampled);
            testCase.verifyEqual(newObj.scaleFactor.row, 2);
            testCase.verifyEqual(newObj.nRows, size(newObj.dMat, 1));
            % 値クラスなので元オブジェクトは不変
            testCase.verifyFalse(testCase.dMap.isResampled);
        end

        function testDInterpIdentityForStepOne(testCase)
            newObj = testCase.dMap.dInterp(1, "linear");
            testCase.verifyEqual(size(newObj.dMat), [6, 3]);
            testCase.verifyEqual(newObj.dMat, testCase.dMat, 'AbsTol', 1e-10);
            testCase.verifyEqual(newObj.scaleFactor, struct('row',1,'col',1));
        end

        function testDInterpDownsamplesForStepTwo(testCase)
            newObj = testCase.dMap.dInterp(2, "linear");
            % y_q = 1:2:6 -> 3 行, x_q = 1:2:3 -> 2 列
            testCase.verifyEqual(newObj.nRows, 3);
            testCase.verifyEqual(newObj.nCols, 2);
            testCase.verifyEqual(newObj.scaleFactor, struct('row',0.5,'col',0.5));
        end

        function testSetDiffTF(testCase)
            obj = testCase.dMap.setDiffTF(0.5);
            expected = int8(diff(testCase.dMat > 0.5));
            testCase.verifyEqual(obj.diffTF, expected);
        end

        function testPlotDxDrawsLine(testCase)
            testCase.dMap.plotD_x(1);
            testCase.verifyNotEmpty(findobj(testCase.fig, 'Type', 'line'));
        end
    end
end

% --- ローカル関数 -------------------------------------------------------
function setDMatExternally(dMap)
    dMap.width = 999;   %#ok<NASGU>  SetAccess=private のためエラーになるはず
end
