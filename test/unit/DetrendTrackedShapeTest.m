% detrendTrackedShape の単体テスト
% （受け入れテスト GrooveTrackingAcceptanceTest・MultiGrooveAcceptanceTest で見ていない
% 細部を確かめる）
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

        function testTrendOutputKeepsFirstOutput(testCase)
            % 2つ目の出力を受け取っても、1つ目の出力は1出力で呼んだときと同じ（issue #30）
            x = (1:4000)';
            y = 0.5*sin(2*pi*x/37) + 1e-6*(x-2000).^2 + 250;

            outOne = detrendTrackedShape([x, y]);
            [outTwo, trend] = detrendTrackedShape([x, y]);

            testCase.verifyEqual(outTwo, outOne);
            testCase.verifyEqual(trend.degree, 9);
        end

        function testTrendReproducesDetrendedShape(testCase)
            % y から trend の値を引いて平均を引くと、1つ目の出力の y と一致する。
            % trend は写真1枚の外のxでも評価できる（同じ多項式を他の溝の点にかけるため）
            x = (1:3000)';
            y = 0.3*sin(2*pi*x/53) + 2e-4*(x-1500) + 1e-7*(x-1500).^2 + 100;

            [out, trend] = detrendTrackedShape([x, y], PolyDegree=3);

            r = y - polyval(trend.p, x, trend.S, trend.mu);
            testCase.verifyEqual(out(:,2), r - mean(r), "AbsTol", 1e-10);
            testCase.verifyEqual(trend.degree, 3);
            testCase.verifyNumElements(trend.p, 4);
            testCase.verifyEqual(trend.mu, [mean(x); std(x)], "AbsTol", 1e-9);
            testCase.verifyTrue(isstruct(trend.S));
        end

        function testRejectsNonIntegerDegree(testCase)
            testCase.verifyError(@() detrendTrackedShape([(1:10)', (1:10)'], PolyDegree=2.5), ...
                "MATLAB:validators:mustBeInteger");
        end
    end
end
