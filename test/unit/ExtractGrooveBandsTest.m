% extractGrooveBands の単体テスト
% （受け入れテスト MultiGrooveAcceptanceTest で見ていない細部を確かめる）
%
% 合成データ：2次式の trend に、補正後の中心 0, -27, -54 の溝（±0.4 のゆらぎ）を足した点群。
classdef ExtractGrooveBandsTest < matlab.unittest.TestCase

    properties (Constant)
        N_COLS = 400
    end

    methods (TestClassSetup)
        function addToPath(testCase)
            import matlab.unittest.fixtures.PathFixture
            thisDir = fileparts(mfilename('fullpath'));
            srcDir  = fullfile(thisDir, '..', '..', 'src');
            testCase.applyFixture(PathFixture(srcDir));
        end
    end

    methods (Test)

        function testDuplicateNearestWinsRegardlessOfOrder(testCase)
            % 同じ列の2点（中心から 0.3px と 2px）は、並びの順によらず近い点を採る
            x = (1:testCase.N_COLS)';
            [pks, trend] = testCase.data(x);
            t = polyval(trend.p, 50, trend.S, trend.mu);
            near = [50, t - 27 + 0.3];
            far  = [50, t - 27 - 2];
            pks = pks(~(pks(:,1) == 50 & abs(pks(:,2) - (t - 27)) < 1), :);

            bandsA = extractGrooveBands([pks; near; far], trend, -27, x, Tolerance=3);
            bandsB = extractGrooveBands([pks; far; near], trend, -27, x, Tolerance=3);

            testCase.verifyEqual(bandsA{1}(50,2), near(2), "AbsTol", 1e-12);
            testCase.verifyEqual(bandsB{1}(50,2), near(2), "AbsTol", 1e-12);
        end

        function testDuplicatesCountedPerBand(testCase)
            % 2列で2点（帯1）、1列で3点（帯2）→ numDuplicateCols = [2 1]
            x = (1:testCase.N_COLS)';
            [pks, trend] = testCase.data(x);
            extra = [10, polyval(trend.p, 10, trend.S, trend.mu) - 27 + 1; ...
                     20, polyval(trend.p, 20, trend.S, trend.mu) - 27 - 1; ...
                     30, polyval(trend.p, 30, trend.S, trend.mu) - 54 + 1; ...
                     30, polyval(trend.p, 30, trend.S, trend.mu) - 54 - 1.5];

            [~, ~, info] = extractGrooveBands([pks; extra], trend, [-27; -54], x, Tolerance=3);

            testCase.verifyEqual(info.numDuplicateCols, [2 1]);
            testCase.verifyEqual(info.numMissing, [0 0]);
        end

        function testToleranceBoundaryIsInclusive(testCase)
            % 中心からちょうど Tolerance の点は採る（誤差が出ないよう、trend は 0 の多項式にして
            % y を整数にする）
            x = (1:testCase.N_COLS)';
            [~, trend] = detrendTrackedShape([x, zeros(size(x))], PolyDegree=0);
            pks = [x, -27*ones(size(x))];
            pks(77,2) = -25;
            pks(78,2) = -24;

            [bands, found] = extractGrooveBands(pks, trend, -27, x, Tolerance=2);

            testCase.verifyTrue(found(77));
            testCase.verifyEqual(bands{1}(77,2), -25);
            testCase.verifyFalse(found(78));
        end

        function testMissingAtEdgesIsExtrapolated(testCase)
            % 両端の列が欠損しても、fillmissing の線形の外挿で埋まる（trackGroove と同じ）
            x = (1:testCase.N_COLS)';
            [pks, trend, yTrue] = testCase.data(x, RemoveX=[1; 2; 400], RemoveFrom=1);

            [bands, found, info] = extractGrooveBands(pks, trend, -27, x, Tolerance=3);

            testCase.verifyFalse(any(found([1 2 400])));
            testCase.verifyEqual(info.numMissing, 3);
            testCase.verifyFalse(any(isnan(bands{1}(:,2))));
            yExtrap = interp1([3; 4], yTrue([3; 4], 2), [1; 2], "linear", "extrap");
            testCase.verifyEqual(bands{1}([1 2],2), yExtrap, "AbsTol", 1e-9);
        end

        function testCentersOrderIsKept(testCase)
            % bands と found の列は centers の順（並べ替えない）
            x = (1:testCase.N_COLS)';
            [pks, trend, yTrue] = testCase.data(x, RemoveX=(100:105)', RemoveFrom=2);

            [bands, found] = extractGrooveBands(pks, trend, [-54; -27], x, Tolerance=3);

            testCase.verifyEqual(bands{1}(1:50,2), yTrue(1:50,3), "AbsTol", 1e-12);
            testCase.verifyEqual(bands{2}(:,2), yTrue(:,2), "AbsTol", 1e-12);
            testCase.verifyFalse(any(found(100:105,1)));
            testCase.verifyTrue(all(found(:,2)));
        end

        function testEmptyCentersReturnsEmpty(testCase)
            x = (1:testCase.N_COLS)';
            [pks, trend] = testCase.data(x);

            [bands, found, info] = extractGrooveBands(pks, trend, zeros(0,1), x, Tolerance=3);

            testCase.verifySize(bands, [0 1]);
            testCase.verifySize(found, [numel(x) 0]);
            testCase.verifySize(info.numMissing, [1 0]);
        end

        function testNoPointsInBandErrors(testCase)
            x = (1:testCase.N_COLS)';
            [pks, trend] = testCase.data(x);

            testCase.verifyError(@() extractGrooveBands(pks, trend, -200, x, Tolerance=3), ...
                "extractGrooveBands:tooFewPoints");
        end
    end

    methods (Access = private)

        function [pks, trend, yTrue] = data(~, x, opts)
            % yTrue の列 k は補正後の中心 -(k-1)*27 の溝（元の画像の y）。
            % RemoveFrom（0〜2）の溝から RemoveX の列の点を消す
            arguments
                ~
                x (:,1) double
                opts.RemoveX (:,1) double = zeros(0,1)
                opts.RemoveFrom (1,1) double = -1
            end
            base = 250 - 0.03*(x - 200) + 2e-4*(x - 200).^2;
            [p, S, mu] = polyfit(x, base, 2);
            trend = struct();
            trend.p = p;
            trend.S = S;
            trend.mu = mu;
            trend.degree = 2;
            trendY = polyval(p, x, S, mu);
            yTrue = zeros(numel(x), 3);
            pks = zeros(0,2);
            for k = 1:3
                yTrue(:,k) = trendY - 27*(k-1) + 0.4*sin(2*pi*x/(31 + 7*k));
                keep = true(size(x));
                if k - 1 == opts.RemoveFrom
                    keep = ~ismember(x, opts.RemoveX);
                end
                pks = [pks; x(keep), yTrue(keep,k)]; %#ok<AGROW>
            end
        end
    end
end
