% omitMask 関数の単体テスト
classdef OmitMaskTest < matlab.unittest.TestCase

    methods (TestClassSetup)
        function addToPath(testCase)
            import matlab.unittest.fixtures.PathFixture
            thisDir = fileparts(mfilename('fullpath'));
            srcDir  = fullfile(thisDir, '..', '..', 'src');
            testCase.applyFixture(PathFixture(srcDir));
        end
    end

    methods (Test)
        function testTrimsLowLuminanceBorderColumns(testCase)
            % 左2列・右1列は閾値以下の画素を含む -> 中央3列だけ残る
            img = [ 5  5 50 60 55  5;
                    5  8 52 61 54  3;
                    5  9 51 59 56  9];
            th = 10;

            [imgOut, newWidth] = omitMask(img, th);

            testCase.verifyEqual(imgOut, img(:, 3:5));
            testCase.verifyEqual(newWidth, 3);
        end

        function testNoTrimmingWhenAllColumnsAboveThreshold(testCase)
            % すべての画素が閾値超え -> 何もトリムされない
            img = 50 * ones(3, 4);
            th = 10;

            [imgOut, newWidth] = omitMask(img, th);

            testCase.verifyEqual(imgOut, img);
            testCase.verifyEqual(newWidth, 4);
        end

        function testAllColumnsAtOrBelowThresholdErrors(testCase)
            % 全列が閾値以下だとmaskLが列範囲を超えてインデックスエラーになる
            % (無限ループにはならず、幅+1回目のインデックス参照で即座に失敗する)
            img = 5 * ones(3, 6);
            th = 10;

            testCase.verifyError(@() omitMask(img, th), "MATLAB:badsubscript");
        end

        function testBoundaryPixelExactlyAtThresholdIsMasked(testCase)
            % <= th のとき「マスク対象」。境界値ちょうどでも1列トリムされる
            img = [10 50 50;
                   10 50 50];
            th = 10;

            [imgOut, newWidth] = omitMask(img, th);

            testCase.verifyEqual(imgOut, img(:, 2:3));
            testCase.verifyEqual(newWidth, 2);
        end
    end
end
