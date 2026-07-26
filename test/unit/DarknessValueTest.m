% DarknessValue クラスの単体テスト
classdef DarknessValueTest < matlab.unittest.TestCase

    properties
        fig
        dMat        % 既知の暗さ行列（6行3列）
        imgData
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
        function buildDarknessValue(testCase)
            % 各列に「明・明・暗・暗・明・明」というパターンを持つ合成画像
            dcol = [0.1; 0.1; 0.9; 0.9; 0.1; 0.1];
            testCase.dMat = repmat(dcol, 1, 3);        % 6x3
            img = 255 * (1 - testCase.dMat);           % dMat = 1 - img/255 の逆変換
            testCase.imgData = ImageData(img, [3; 4]);
            testCase.dValue  = DarknessValue(testCase.imgData);
        end

        function openHiddenFigure(testCase)
            testCase.fig = figure('Visible', 'off');
            testCase.addTeardown(@() close(testCase.fig));
        end
    end

    methods (Test)
        function testConstructorComputesDMat(testCase)
            testCase.verifyEqual(testCase.dValue.dMat, testCase.dMat, 'AbsTol', 1e-10);
        end

        function testConstructorCopiesImageMeta(testCase)
            testCase.verifyEqual(testCase.dValue.imgID, [3; 4]);
            testCase.verifyEqual(testCase.dValue.imgWidth, 3);
            testCase.verifyEqual(testCase.dValue.imgHeight, 6);
            testCase.verifyEqual(testCase.dValue.nRows, 6);
            testCase.verifyEqual(testCase.dValue.nCols, 3);
        end

        function testConstructorDefaults(testCase)
            testCase.verifyFalse(testCase.dValue.rsmplTF);
            testCase.verifyEqual(testCase.dValue.scaleFactor, struct('row',1,'col',1));
            testCase.verifySize(testCase.dValue.sIdxC, [1, 3]);
            testCase.verifySize(testCase.dValue.eIdxC, [1, 3]);
        end

        function testPropertiesAreReadOnly(testCase)
            testCase.verifyError(@() setDMatExternally(testCase.dValue), ...
                "MATLAB:class:SetProhibited");
        end

        function testDResample(testCase)
            testCase.assumeNotEmpty(which("resample"), ...
                "resample が利用できないためスキップ");
            newObj = testCase.dValue.dResample(2, 1);

            testCase.verifyTrue(newObj.rsmplTF);
            testCase.verifyEqual(newObj.scaleFactor.row, 2);
            testCase.verifyEqual(newObj.nRows, size(newObj.dMat, 1));
            % 値クラスなので元オブジェクトは不変
            testCase.verifyFalse(testCase.dValue.rsmplTF);
        end

        function testDInterpIdentityForStepOne(testCase)
            newObj = testCase.dValue.dInterp(1, "linear");
            testCase.verifyEqual(size(newObj.dMat), [6, 3]);
            testCase.verifyEqual(newObj.dMat, testCase.dMat, 'AbsTol', 1e-10);
            testCase.verifyEqual(newObj.scaleFactor, struct('row',1,'col',1));
        end

        function testDInterpDownsamplesForStepTwo(testCase)
            newObj = testCase.dValue.dInterp(2, "linear");
            % y_q = 1:2:6 -> 3 行, x_q = 1:2:3 -> 2 列
            testCase.verifyEqual(newObj.nRows, 3);
            testCase.verifyEqual(newObj.nCols, 2);
            testCase.verifyEqual(newObj.scaleFactor, struct('row',0.5,'col',0.5));
        end

        function testSetDiffTF(testCase)
            obj = testCase.dValue.setDiffTF(0.5);
            expected = int8(diff(testCase.dMat > 0.5));
            testCase.verifyEqual(obj.diffTF, expected);
        end

        function testGetStartEndIdx(testCase)
            obj = testCase.dValue.setDiffTF(0.5);
            [startIdx, endIdx] = obj.getStartEndIdx(1);
            testCase.verifyEqual(startIdx, 3);   % 暗領域は 3〜4 行目
            testCase.verifyEqual(endIdx, 4);
        end

        function testGetGrooveBtmIdx(testCase)
            obj = testCase.dValue.setDiffTF(0.5);
            [obj, sb, eb, pksNum] = obj.getGrooveBtmIdx(1, 3, 4, 5);
            testCase.verifyEqual(sb, 3);
            testCase.verifyEqual(eb, 4);
            testCase.verifyEqual(pksNum, 1);
            testCase.verifyEqual(obj.sIdxC{1, 1}, [1, 3]);
            testCase.verifyEqual(obj.eIdxC{1, 1}, [1, 4]);
        end

        function testExtractGrvCnt(testCase)
            obj = testCase.dValue.setDiffTF(0.5);
            obj = obj.getGrooveBtmIdx(1, 3, 4, 5);
            cnt = obj.extractGrv_cnt(1);
            % 重心 = (3*0.9 + 4*0.9) / (0.9 + 0.9) = 3.5
            testCase.verifyEqual(cnt, 3.5, 'AbsTol', 1e-10);
        end

        function testExtractGrvMax(testCase)
            obj = testCase.dValue.setDiffTF(0.5);
            obj = obj.getGrooveBtmIdx(1, 3, 4, 5);
            mx = obj.extractGrv_max(1);
            % 3,4 行目とも 0.9 なので最初の最大値 = 3 行目
            testCase.verifyEqual(mx, 3);
        end

        function testPlotDxDrawsLine(testCase)
            testCase.dValue.plotD_x(1);
            testCase.verifyNotEmpty(findobj(testCase.fig, 'Type', 'line'));
        end
    end
end

% --- ローカル関数 -------------------------------------------------------
function setDMatExternally(dValue)
    dValue.imgWidth = 999;   %#ok<NASGU>  SetAccess=private のためエラーになるはず
end
