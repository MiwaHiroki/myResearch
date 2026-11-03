% detrendTrackedShape の単体テスト
% （受け入れテスト GrooveTrackingAcceptanceTest で見ていない細部を確かめる）
classdef DetrendTrackedShapeTest < matlab.unittest.TestCase

    methods (TestClassSetup)
        function addToPath(testCase)
            import matlab.unittest.fixtures.PathFixture
            thisDir = fileparts(mfilename('fullpath'));
            srcDir  = fullfile(thisDir, '..', '..', 'src');
            testCase.applyFixture(PathFixture(srcDir));
        end
    end

    methods (Test)

        function testSineWithCubicMatchesSineAlone(testCase)
            % 3次式 + 正弦波を3次でデトレンド → 正弦波を同じ方法でデトレンドしたものと一致、平均0
            x = (1:3000)';
            t = (x - 1500) / 1500;
            s = 0.3*sin(2*pi*x/53);
            y = s + 4*t.^3 + t.^2 - 2*t + 10;

            out = detrendTrackedShape([x, y], PolyDegree=3);
            ref = detrendTrackedShape([x, s], PolyDegree=3);

            testCase.verifyEqual(mean(out(:,2)), 0, "AbsTol", 1e-10);
            testCase.verifyEqual(out(:,2), ref(:,2), "AbsTol", 1e-9);
        end

        function testDegreeZeroOnlyRemovesMean(testCase)
            x = (1:50)';
            y = sin(x) + 7;

            out = detrendTrackedShape([x, y], PolyDegree=0);

            testCase.verifyEqual(out(:,2), y - mean(y), "AbsTol", 1e-12);
        end

        function testSameResultForShiftedX(testCase)
            % xを平行移動しても（写真の中の位置をずらしても）結果は同じ。
            % [p,S,mu] 形式でセンタリングしているため
            x = (1:4000)';
            y = 0.5*sin(2*pi*x/37) + 1e-3*x;

            out1 = detrendTrackedShape([x, y]);
            out2 = detrendTrackedShape([x + 10000, y]);

            testCase.verifyEqual(out2(:,2), out1(:,2), "AbsTol", 1e-9);
        end

        function testHighDegreeIsWarningFree(testCase)
            % detrendGrooveShape では警告が出る長さ・次数でも出ない
            x = (1:4000)';
            y = sin(2*pi*x/37);
            testCase.verifyWarningFree(@() detrendTrackedShape([x, y], PolyDegree=9));
        end

        function testRejectsNonIntegerDegree(testCase)
            testCase.verifyError(@() detrendTrackedShape([(1:10)', (1:10)'], PolyDegree=2.5), ...
                "MATLAB:validators:mustBeInteger");
        end
    end
end
