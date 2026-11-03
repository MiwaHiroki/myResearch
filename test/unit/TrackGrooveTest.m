% trackGroove の単体テスト
% （受け入れテスト GrooveTrackingAcceptanceTest で見ていない細部を確かめる）
%
% 合成データ：溝を5本、間隔25px で並べる。y = 50 + 25*(k-1) + slope*x
classdef TrackGrooveTest < matlab.unittest.TestCase

    properties (Constant)
        NUM_GROOVES  = 5
        GROOVE_PITCH = 25
        Y_FIRST      = 50
        TARGET       = 3
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

        function testLeftTrackingStartsFromRightTakenPoints(testCase)
            % 始点のすぐ左に FitLength より長い欠損があっても、左向きの予測は
            % 右向きで採った点の直線から始まるので、欠損の左で同じ溝に戻る
            % （窓が空から始まると、y0 のままで 0.2*31 = 6.2px ずれて見失う）
            xq = (1:600)';
            slope = 0.2;
            gapX = (270:299)';
            pks = testCase.linePoints(xq, slope, gapX);
            yTrue = testCase.lineGroove(xq, testCase.TARGET, slope);

            [points, found] = trackGroove(pks, [300, yTrue(300)], xq, ...
                FitLength=10, InitLength=5);

            before = xq < 270;
            testCase.verifyTrue(all(found(before)));
            testCase.verifyEqual(points(before,2), yTrue(before), "AbsTol", 1e-9);
        end

        function testY0IsMedianOfNearestCandidates(testCase)
            % 初期化の y0 は、InitLength 未満の列で seed(2) に最も近い候補の中央値
            xq = (1:100)';
            slope = 0.1;
            pks = testCase.linePoints(xq, slope, zeros(0,1));
            yTrue = testCase.lineGroove(xq, testCase.TARGET, slope);

            [~, ~, info] = trackGroove(pks, [10, yTrue(10)+3], xq, InitLength=5);

            % 列10〜14（10からの距離が5未満）の真の値の中央値
            testCase.verifyEqual(info.y0, median(yTrue(10:14)), "AbsTol", 1e-12);
        end

        function testNearestCandidateWithinToleranceIsTaken(testCase)
            % 許容幅の中に候補が2つあれば、予測に近いほうを採る
            xq = (1:200)';
            slope = 0;
            yTrue = testCase.lineGroove(xq, testCase.TARGET, slope);
            pks = testCase.linePoints(xq, slope, zeros(0,1));
            pks(pks(:,1) == 100 & abs(pks(:,2) - yTrue(100)) < 1e-9, :) = [];
            pks = [pks; 100, yTrue(100) - 1.5; 100, yTrue(100) + 0.5];

            [points, found] = trackGroove(pks, [1, yTrue(1)], xq);

            testCase.verifyTrue(found(100));
            testCase.verifyEqual(points(100,2), yTrue(100) + 0.5, "AbsTol", 1e-12);
        end

        function testMaxGapLengthIsLongestRun(testCase)
            % 欠損が複数あるとき、info.maxGapLength は最も長いもの
            xq = (1:300)';
            slope = 0.05;
            pks = testCase.linePoints(xq, slope, [(50:54)'; (150:161)'; (250:252)']);
            yTrue = testCase.lineGroove(xq, testCase.TARGET, slope);

            [~, found, info] = trackGroove(pks, [1, yTrue(1)], xq);

            testCase.verifyEqual(info.numMissing, 5 + 12 + 3);
            testCase.verifyEqual(info.maxGapLength, 12);
            testCase.verifyEqual(nnz(~found), 20);
        end

        function testGapLengthUsesMedianSpacingAcrossSegmentJumps(testCase)
            % intpD を写真1枚分につないだ xQuery（セグメントの中は0.25px、境目は1px）でも、
            % 欠損の長さは「列の数 × 列の間隔の中央値（0.25）」で数える
            xq = [(1:0.25:100)'; (101:0.25:200)'];
            slope = 0.05;
            gapX = xq(xq >= 120 & xq < 125);   % 20列
            pks = testCase.linePoints(xq, slope, gapX);
            yTrue = testCase.lineGroove(xq, testCase.TARGET, slope);

            [points, found, info] = trackGroove(pks, [1, yTrue(1)], xq);

            testCase.verifyEqual(info.maxGapLength, numel(gapX) * 0.25, "AbsTol", 1e-12);
            testCase.verifyTrue(all(found(~ismember(xq, gapX))));
            testCase.verifyEqual(points(:,2), yTrue, "AbsTol", 1e-9);
        end

        function testLongGapWarningReportsPosition(testCase)
            % 警告の文に、欠損の始まりのx座標が入っている
            xq = (1:300)';
            slope = 0.05;
            pks = testCase.linePoints(xq, slope, (150:199)');
            yTrue = testCase.lineGroove(xq, testCase.TARGET, slope);

            testCase.verifyWarning(@() trackGroove(pks, [1, yTrue(1)], xq), "trackGroove:longGap");
            lastwarn("");
            warnState = warning("off", "trackGroove:longGap");
            testCase.addTeardown(@() warning(warnState));
            trackGroove(pks, [1, yTrue(1)], xq);
            msg = lastwarn();
            testCase.verifySubstring(msg, "x=150");
        end

        function testSeedBeyondLastColumnUsesLastColumn(testCase)
            % クリックのxが xQuery の範囲の外なら、最も近い端の列から始める
            xq = (1:100)';
            slope = 0.1;
            pks = testCase.linePoints(xq, slope, zeros(0,1));
            yTrue = testCase.lineGroove(xq, testCase.TARGET, slope);

            [points, found, info] = trackGroove(pks, [130, yTrue(100)], xq);

            testCase.verifyEqual(info.seedIdx, 100);
            testCase.verifyTrue(all(found));
            testCase.verifyEqual(points(:,2), yTrue, "AbsTol", 1e-9);
        end

        function testSeedNotFoundOutsideInitLength(testCase)
            % 始点の列から InitLength 以上離れた列にしか点が無ければエラー
            xq = (1:100)';
            pks = testCase.linePoints(xq, 0, (1:30)');
            yTrue = testCase.lineGroove(xq, testCase.TARGET, 0);

            testCase.verifyError(@() trackGroove(pks, [1, yTrue(1)], xq, InitLength=20), ...
                "trackGroove:seedNotFound");
        end
    end

    methods (Access = private)
        function y = lineGroove(testCase, x, k, slope)
            y = testCase.Y_FIRST + (k-1)*testCase.GROOVE_PITCH + slope*x;
        end

        function pks = linePoints(testCase, xq, slope, removeX)
            % 全部の溝の点（removeX の列では全部の溝の点を消す）
            keep = ~ismember(xq, removeX);
            pks = zeros(0,2);
            for k = 1:testCase.NUM_GROOVES
                pks = [pks; xq(keep), testCase.lineGroove(xq(keep), k, slope)]; %#ok<AGROW>
            end
        end
    end
end
