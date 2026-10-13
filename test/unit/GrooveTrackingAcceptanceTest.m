% issue #25（写真1枚の範囲で1本の溝を自動追跡する）の受け入れテスト
%
% docs/issues/25-groove-tracking/plan.md 4.2 のインターフェースと要求仕様を、
% 関数の外側から確かめる（trackGroove, detrendTrackedShape, mergeSegmentPoints,
% trackingSeeds、および grooveSelection の追加フィールドの保存・読み込み）。
% 内部の手順や途中の変数には依存させない（それは実装担当の unit テストの役目）。
% 評価担当が作成した。実装担当は変更しない（docs/rules/evaluation.md）。
%
% 合成データ：溝を NUM_GROOVES 本、間隔 GROOVE_PITCH px で並べる。
% 各溝のy座標は真の式から作るので、追跡結果は真の値と厳密に一致するはず。
classdef GrooveTrackingAcceptanceTest < matlab.unittest.TestCase

    properties (Constant)
        NUM_GROOVES  = 5
        GROOVE_PITCH = 25    % 溝の間隔[px]（実データは25〜30px）
        Y_FIRST      = 50    % 一番上の溝のy座標[px]（x=0での値）
        TARGET       = 3     % 追跡する溝（真ん中）
        N_COLS       = 600
    end

    methods (TestClassSetup)
        function addToPath(testCase)
            import matlab.unittest.fixtures.PathFixture
            thisDir = fileparts(mfilename('fullpath'));
            srcDir  = fullfile(thisDir, '..', '..', 'src');
            testCase.applyFixture(PathFixture(srcDir));
        end
    end

    %% trackGroove
    methods (Test)

        function testTracksTargetGrooveFromLeftClick(testCase)
            % 左端付近のクリック（+1px ずれ）から、その溝を右端まで追跡する
            xq = (1:testCase.N_COLS)';
            pks = testCase.wavyPoints(xq);
            yTrue = testCase.wavyGroove(xq, testCase.TARGET);

            [points, found, info] = trackGroove(pks, [1, yTrue(1)+1], xq);

            testCase.verifySize(points, [numel(xq) 2]);
            testCase.verifyEqual(points(:,1), xq);
            testCase.verifyEqual(points(:,2), yTrue, "AbsTol", 1e-9);
            testCase.verifyClass(found, "logical");
            testCase.verifySize(found, [numel(xq) 1]);
            testCase.verifyTrue(all(found));
            testCase.verifyEqual(info.numFound, numel(xq));
            testCase.verifyEqual(info.numMissing, 0);
            testCase.verifyTrue(all(isfield(info, ...
                ["y0","seedIdx","numFound","numMissing","maxGapLength"])));
            testCase.verifyEqual(info.seedIdx, 1);
        end

        function testClickOffsetIsAbsorbed(testCase)
            % クリックが溝から +4px / -4px ずれても同じ溝を追跡する（SnapRadius=10 以内）
            xq = (1:testCase.N_COLS)';
            pks = testCase.wavyPoints(xq);
            yTrue = testCase.wavyGroove(xq, testCase.TARGET);

            pointsUp   = trackGroove(pks, [1, yTrue(1)+4], xq);
            pointsDown = trackGroove(pks, [1, yTrue(1)-4], xq);

            testCase.verifyEqual(pointsUp(:,2),   yTrue, "AbsTol", 1e-9);
            testCase.verifyEqual(pointsDown(:,2), yTrue, "AbsTol", 1e-9);
        end

        function testTracksBothDirectionsFromMiddleClick(testCase)
            % 写真の真ん中をクリックしても、左側（x=1〜299）も同じ溝で埋まる
            xq = (1:testCase.N_COLS)';
            pks = testCase.wavyPoints(xq);
            yTrue = testCase.wavyGroove(xq, testCase.TARGET);

            [points, found, info] = trackGroove(pks, [300, yTrue(300)+1], xq);

            testCase.verifyEqual(points(:,2), yTrue, "AbsTol", 1e-9);
            testCase.verifyTrue(all(found));
            testCase.verifyEqual(info.seedIdx, 300);
        end

        function testSeedColumnIsNearestToClickX(testCase)
            % クリックのxが列の座標と一致しなくても、最も近い列から始める
            xq = (1:testCase.N_COLS)';
            pks = testCase.wavyPoints(xq);
            yTrue = testCase.wavyGroove(xq, testCase.TARGET);

            [points, ~, info] = trackGroove(pks, [250.3, yTrue(250)], xq);

            testCase.verifyEqual(info.seedIdx, 250);
            testCase.verifyEqual(points(:,2), yTrue, "AbsTol", 1e-9);
        end

        function testGapIsMarkedAndLinearlyInterpolated(testCase)
            % x=200〜220 で追跡する溝の点を消す → found=false、両端の点を結ぶ直線で補間、
            % 欠損の後は元の溝に戻る
            xq = (1:testCase.N_COLS)';
            gapX = (200:220)';
            pks = testCase.wavyPoints(xq, RemoveX=gapX);
            yTrue = testCase.wavyGroove(xq, testCase.TARGET);

            [points, found, info] = trackGroove(pks, [1, yTrue(1)+1], xq);

            isGap = ismember(xq, gapX);
            testCase.verifyFalse(any(found(isGap)));
            testCase.verifyTrue(all(found(~isGap)));
            testCase.verifyEqual(points(~isGap,2), yTrue(~isGap), "AbsTol", 1e-9);
            yLinear = interp1([199; 221], yTrue([199; 221]), gapX);
            testCase.verifyEqual(points(isGap,2), yLinear, "AbsTol", 1e-9);
            testCase.verifyEqual(info.numMissing, numel(gapX));
            testCase.verifyEqual(info.numFound, numel(xq) - numel(gapX));
            testCase.verifyEqual(info.maxGapLength, 21, "AbsTol", 1e-9);
        end

        function testNoNaNInOutputEvenWithEdgeGap(testCase)
            % 右端の欠損も補間（外挿）され、出力にNaNが残らない
            xq = (1:testCase.N_COLS)';
            pks = testCase.wavyPoints(xq, RemoveX=(591:600)');
            yTrue = testCase.wavyGroove(xq, testCase.TARGET);

            [points, found] = trackGroove(pks, [1, yTrue(1)], xq);

            testCase.verifyFalse(any(isnan(points(:,2))));
            testCase.verifyFalse(any(found(591:600)));
            testCase.verifyTrue(all(found(1:590)));
        end

        function testPointWithinToleranceIsTaken(testCase)
            % ある列で真の点を消し、溝から1.5pxの位置に点を置く → Tolerance(2)以内なので採る
            xq = (1:testCase.N_COLS)';
            yTrue = testCase.wavyGroove(xq, testCase.TARGET);
            pks = testCase.wavyPoints(xq, RemoveTargetX=300);
            pks = [pks; 300, yTrue(300)+1.5];

            [points, found] = trackGroove(pks, [1, yTrue(1)], xq);

            testCase.verifyTrue(found(300));
            testCase.verifyEqual(points(300,2), yTrue(300)+1.5, "AbsTol", 1e-9);
            others = xq ~= 300;
            testCase.verifyEqual(points(others,2), yTrue(others), "AbsTol", 1e-9);
        end

        function testPointOutsideToleranceIsRejected(testCase)
            % 溝から5pxの位置の点は採らない（found=false、その列は補間）
            xq = (1:testCase.N_COLS)';
            yTrue = testCase.wavyGroove(xq, testCase.TARGET);
            pks = testCase.wavyPoints(xq, RemoveTargetX=300);
            pks = [pks; 300, yTrue(300)+5];

            [points, found] = trackGroove(pks, [1, yTrue(1)], xq);

            testCase.verifyFalse(found(300));
            yLinear = interp1([299; 301], yTrue([299; 301]), 300);
            testCase.verifyEqual(points(300,2), yLinear, "AbsTol", 1e-9);
        end

        function testToleranceArgumentIsUsed(testCase)
            % 同じ外れ点（溝から1.5px）でも Tolerance=1 なら採らない
            xq = (1:testCase.N_COLS)';
            yTrue = testCase.wavyGroove(xq, testCase.TARGET);
            pks = testCase.wavyPoints(xq, RemoveTargetX=300);
            pks = [pks; 300, yTrue(300)+1.5];

            [~, found] = trackGroove(pks, [1, yTrue(1)], xq, Tolerance=1);

            testCase.verifyFalse(found(300));
        end

        function testPointsOffTheQueryGridAreIgnored(testCase)
            % xQuery のどの値とも一致しないxの点は使わない
            xq = (1:testCase.N_COLS)';
            yTrue = testCase.wavyGroove(xq, testCase.TARGET);
            pks = testCase.wavyPoints(xq);
            pks = [pks; 100.5, testCase.wavyGroove(100.5, testCase.TARGET) + 0.3];

            [points, found] = trackGroove(pks, [1, yTrue(1)], xq);

            testCase.verifyEqual(points(:,2), yTrue, "AbsTol", 1e-9);
            testCase.verifyTrue(all(found));
        end

        function testFractionalQueryGridMatchesIntegerGrid(testCase)
            % 高解像度化（列の間隔0.25px）でも、同じ引数（pxの値）で同じ溝を追跡でき、
            % 整数のxでの値が列の間隔1pxのときの結果と一致する
            xqInt  = (1:testCase.N_COLS)';
            xqFrac = (1:0.25:testCase.N_COLS)';
            yTrueFrac = testCase.wavyGroove(xqFrac, testCase.TARGET);
            seed = [1, yTrueFrac(1)+1];

            pointsInt = trackGroove(testCase.wavyPoints(xqInt), seed, xqInt);
            [pointsFrac, foundFrac] = trackGroove(testCase.wavyPoints(xqFrac), seed, xqFrac);

            testCase.verifyEqual(pointsFrac(:,1), xqFrac);
            testCase.verifyEqual(pointsFrac(:,2), yTrueFrac, "AbsTol", 1e-9);
            testCase.verifyTrue(all(foundFrac));
            isInt = ismember(xqFrac, xqInt);
            testCase.verifyEqual(pointsFrac(isInt,2), pointsInt(:,2), "AbsTol", 1e-9);
        end

        function testGapLengthIsMeasuredInPixels(testCase)
            % 列の間隔0.25pxで x=200〜220 の点を消す（81列、長さ約20px）。
            % 欠損の長さを px で判定していれば、MaxGapLength=25 では警告が出ず、
            % 15 では trackGroove:longGap が出る（列数で判定すると 81>25 で出てしまう）
            xq = (1:0.25:testCase.N_COLS)';
            gapX = xq(xq >= 200 & xq <= 220);
            pks = testCase.wavyPoints(xq, RemoveX=gapX);
            yTrue = testCase.wavyGroove(xq, testCase.TARGET);
            seed = [1, yTrue(1)];

            testCase.verifyWarningFree(@() trackGroove(pks, seed, xq, MaxGapLength=25));
            testCase.verifyWarning(@() trackGroove(pks, seed, xq, MaxGapLength=15), ...
                "trackGroove:longGap");

            [~, found, info] = trackGroove(pks, seed, xq, MaxGapLength=25);
            testCase.verifyEqual(info.numMissing, numel(gapX));
            testCase.verifyFalse(any(found(ismember(xq, gapX))));
            % 長さは「欠損した列の数 × 列の間隔」（plan.md 4.2 手順6）
            testCase.verifyEqual(info.maxGapLength, numel(gapX)*0.25, "AbsTol", 1e-9);
        end

        function testDefaultMaxGapLengthIs40px(testCase)
            % 既定の MaxGapLength は 40px：35pxの欠損では警告なし、45pxでは警告
            % （欠損の後で確実に溝に戻れるよう、傾きのある直線の溝で作る）
            xq = (1:testCase.N_COLS)';
            slope = 0.05;
            yTrue = testCase.lineGroove(xq, testCase.TARGET, slope);
            seed = [1, yTrue(1)];
            pks35 = testCase.linePoints(xq, slope, RemoveX=(200:234)');
            pks45 = testCase.linePoints(xq, slope, RemoveX=(200:244)');

            testCase.verifyWarningFree(@() trackGroove(pks35, seed, xq));
            testCase.verifyWarning(@() trackGroove(pks45, seed, xq), "trackGroove:longGap");
        end

        function testRecoversAfterGapLongerThanFitLength(testCase)
            % 傾き0.2の直線の溝で、FitLength=10 より長い欠損（x=200〜230）を作る。
            % 予測の窓の基準が「最後に採った点」なら、欠損の後で同じ溝に戻る
            % （今の列を基準にすると、最後の点のyで予測して約6pxずれ、見失う）
            xq = (1:testCase.N_COLS)';
            slope = 0.2;
            gapX = (200:230)';
            pks = testCase.linePoints(xq, slope, RemoveX=gapX);
            yTrue = testCase.lineGroove(xq, testCase.TARGET, slope);

            [points, found] = trackGroove(pks, [1, yTrue(1)], xq, ...
                FitLength=10, InitLength=5);

            after = xq > 230;
            testCase.verifyTrue(all(found(after)));
            testCase.verifyEqual(points(after,2), yTrue(after), "AbsTol", 1e-9);
        end

        function testSeedFarFromAnyPointErrors(testCase)
            % クリックから SnapRadius(10px) 以内に点が無ければエラー
            % （溝と溝の真ん中＝どちらの溝からも12.5px）
            xq = (1:testCase.N_COLS)';
            pks = testCase.wavyPoints(xq);
            yMid = (testCase.wavyGroove(1, 2) + testCase.wavyGroove(1, 3)) / 2;

            testCase.verifyError(@() trackGroove(pks, [1, yMid], xq), ...
                "trackGroove:seedNotFound");
        end

        function testAcceptsAllLengthOptions(testCase)
            % plan.md 4.2 の name-value 引数をすべて受け付ける
            xq = (1:testCase.N_COLS)';
            pks = testCase.wavyPoints(xq);
            yTrue = testCase.wavyGroove(xq, testCase.TARGET);

            points = trackGroove(pks, [1, yTrue(1)], xq, Tolerance=2, FitLength=60, ...
                SnapRadius=10, InitLength=20, MaxGapLength=40);

            testCase.verifyEqual(points(:,2), yTrue, "AbsTol", 1e-9);
        end
    end

    %% detrendTrackedShape
    methods (Test)

        function testDefaultDegreeRemovesNinthOrderPolynomial(testCase)
            % 既定の次数は9（Q2）：約4000列の9次の多項式が取り除かれ、警告も出ない
            x = (1:4000)';
            t = (x - mean(x)) / std(x);
            y = 0.3*t.^9 - 0.5*t.^8 + 0.2*t.^7 + t.^5 - 2*t.^3 + 4*t + 100;

            out = testCase.verifyWarningFree(@() detrendTrackedShape([x, y]));

            testCase.verifySize(out, [numel(x) 2]);
            testCase.verifyEqual(out(:,1), x);
            testCase.verifyEqual(out(:,2), zeros(size(x)), "AbsTol", 1e-6);
        end

        function testHighDegreeOnLongInputIsWarningFree(testCase)
            % detrendGrooveShape では警告が出る長さ・次数（約4000列、15次）でも警告が出ない
            x = (1:4000)';
            y = sin(2*pi*x/37) + 1e-3*x;
            testCase.verifyWarningFree(@() detrendTrackedShape([x, y], PolyDegree=15));
        end

        function testResultIsZeroMeanAndXUnchanged(testCase)
            x = (1:1000)';
            y = 0.5*sin(2*pi*x/37) + 0.01*x + 3;

            out = detrendTrackedShape([x, y], PolyDegree=9);

            testCase.verifyEqual(out(:,1), x);
            testCase.verifyEqual(mean(out(:,2)), 0, "AbsTol", 1e-10);
        end

        function testPolynomialTrendDoesNotChangeResult(testCase)
            % 3次式 + 正弦波を3次でデトレンドした結果は、正弦波だけをデトレンドした結果と同じ
            x = (1:2000)';
            t = (x - 1000) / 1000;
            s = 0.5*sin(2*pi*x/37);
            trend = 2*t.^3 - t.^2 + 5*t + 7;

            outWithTrend = detrendTrackedShape([x, s + trend], PolyDegree=3);
            outSineOnly  = detrendTrackedShape([x, s], PolyDegree=3);

            testCase.verifyEqual(outWithTrend(:,2), outSineOnly(:,2), "AbsTol", 1e-9);
        end

        function testFractionalXIsAccepted(testCase)
            % 高解像度化した列（分数刻みのx、元の画像のpx）にもかけられる
            x = (1:0.125:500)';
            t = (x - 250) / 250;
            y = 3*t.^3 - t + 2;

            out = detrendTrackedShape([x, y], PolyDegree=3);

            testCase.verifyEqual(out(:,1), x);
            testCase.verifyEqual(out(:,2), zeros(size(x)), "AbsTol", 1e-8);
        end
    end

    %% mergeSegmentPoints
    methods (Test)

        function testMergesSegmentsWithOffsets(testCase)
            % 幅 [3 4 2] の3セグメントを横につなぐ
            clouds = [ ...
                testCase.cloud(3, {[1 10], [2 11; 2 20], [3 12]}); ...
                testCase.cloud(4, {[1 13], [], [3 14], [4 15]}); ...
                testCase.cloud(2, {[1 16], [2 17]})];

            [pks, xQuery, counts, xOffsets] = mergeSegmentPoints(clouds);

            testCase.verifyEqual(xOffsets, [0; 3; 7]);
            testCase.verifyEqual(counts, [3; 4; 2]);
            testCase.verifyEqual(xQuery, (1:9)');
            expected = [1 10; 2 11; 2 20; 3 12; 4 13; 6 14; 7 15; 8 16; 9 17];
            testCase.verifyEqual(sortrows(pks), sortrows(expected));
        end

        function testQueryStepBuildsFractionalGrid(testCase)
            % QueryStep=0.5：セグメントの中は0.5刻み、境目は1px
            clouds = [ ...
                testCase.cloud(3, {[1 10; 1.5 10.5], [], [], [], [3 12]}); ...
                testCase.cloud(4, {[2.5 13], [], [], [], [], [], []}); ...
                testCase.cloud(2, {[], [], [2 17]})];

            [pks, xQuery, counts, xOffsets] = mergeSegmentPoints(clouds, QueryStep=0.5);

            testCase.verifyEqual(counts, [5; 7; 3]);
            testCase.verifyEqual(xOffsets, [0; 3; 7]);
            expectedQuery = [1 1.5 2 2.5 3, 4 4.5 5 5.5 6 6.5 7, 8 8.5 9]';
            testCase.verifyEqual(xQuery, expectedQuery, "AbsTol", 1e-12);
            expected = [1 10; 1.5 10.5; 3 12; 5.5 13; 9 17];
            testCase.verifyEqual(sortrows(pks), sortrows(expected), "AbsTol", 1e-12);
            % 点のxはすべて xQuery のどれかに一致する（trackGroove で対応がつく）
            testCase.verifyTrue(all(ismembertol(pks(:,1), xQuery, 1e-12)));
        end

        function testEmptySegmentIsAllowed(testCase)
            % 点が1つも無いセグメントがあってもエラーにならない
            clouds = [ ...
                testCase.cloud(3, {[1 10], [2 11], [3 12]}); ...
                testCase.cloud(4, {[], [], [], []}); ...
                testCase.cloud(2, {[1 16], [2 17]})];

            [pks, xQuery, counts, xOffsets] = mergeSegmentPoints(clouds);

            testCase.verifyEqual(counts, [3; 4; 2]);
            testCase.verifyEqual(xOffsets, [0; 3; 7]);
            testCase.verifyEqual(sum(counts), numel(xQuery));
            testCase.verifyEqual(sortrows(pks), [1 10; 2 11; 3 12; 8 16; 9 17]);
        end
    end

    %% trackingSeeds
    methods (Test)

        function testReturnsSeedsForNewFormat(testCase)
            seeds = [26 260; 30 289];
            gs = struct('p1', zeros(20,2), 'p2', zeros(20,2), ...
                'method', "tracking", 'seeds', seeds);

            testCase.verifyEqual(trackingSeeds(gs, 10), seeds);
        end

        function testReturnsFirstSegmentP1ForOldFormat(testCase)
            % 手動選択の p1（写真2枚 x 10セグメント）から、各写真の最初のセグメントの p1
            p1 = [(1:20)', 100 + (1:20)'];
            gs = struct('p1', p1, 'p2', p1 + [300 0]);

            testCase.verifyEqual(trackingSeeds(gs, 10), p1([1 11], :));
        end

        function testEmptySeedsFallsBackToP1(testCase)
            p1 = [(1:20)', 100 + (1:20)'];
            gs = struct('p1', p1, 'p2', p1, 'seeds', zeros(0,2));

            testCase.verifyEqual(trackingSeeds(gs, 10), p1([1 11], :));
        end

        function testNoSelectionErrors(testCase)
            gs = struct('p1', zeros(0,2), 'p2', zeros(0,2));
            testCase.verifyError(@() trackingSeeds(gs, 10), "trackingSeeds:noSelection");
        end
    end

    %% grooveSelection の追加フィールドの保存・読み込み（saveCycleResult/loadCycleResult は変えない）
    methods (Test)

        function testTrackingSelectionSurvivesSaveAndLoad(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            tmp = testCase.applyFixture(TemporaryFolderFixture);
            saveDir = string(tmp.Folder);

            numImages = 2; numSegments = 2; n = numImages*numSegments;
            [cond, allImg, res] = testCase.minimalCycle(saveDir, numImages, numSegments);

            trk = struct();
            trk.tolerance = 2; trk.fitLength = 60; trk.snapRadius = 10;
            trk.initLength = 20; trk.maxGapLength = 40; trk.minFitPoints = 5;
            trk.queryStep = 1; trk.polyDegree = 9; trk.detrendScope = "photo";
            trk.ampDivisor = 1.5;
            trk.yAbsCnt = {(1:6)'+0.5; (1:6)'+1.5};
            trk.yAbsMax = {(1:6)'; (1:6)'+1};
            trk.foundCnt = {true(6,1); [true; false; true(4,1)]};
            trk.foundMax = {true(6,1); true(6,1)};
            seeds = [1 20; 2 30];
            p1 = [ones(n,1), (1:n)'+10];
            p2 = [3*ones(n,1), (1:n)'+11];
            gs = struct('p1', p1, 'p2', p2, 'method', "tracking", ...
                'seeds', seeds, 'tracking', trk);

            matPath = saveCycleResult(cond, allImg, res, GrooveSelection=gs, ...
                FileName="cycleResult_origD_track_0101", Overwrite=false);
            result = loadCycleResult(matPath);

            loaded = result.grooveSelection;
            testCase.verifyEqual(loaded.p1, p1);
            testCase.verifyEqual(loaded.p2, p2);
            testCase.verifyEqual(loaded.method, "tracking");
            testCase.verifyEqual(loaded.seeds, seeds);
            testCase.verifyEqual(loaded.tracking, trk);
            % 読み込んだ grooveSelection から、ginput なしで同じ始点を取り出せる
            testCase.verifyEqual(trackingSeeds(loaded, numSegments), seeds);
        end
    end

    %% 写真1枚分を通した確認（mergeSegmentPoints → trackGroove → detrendTrackedShape）
    methods (Test)

        function testPhotoPipelineFromSegmentClouds(testCase)
            % 10セグメント（幅60px）に分かれた点群を写真1枚分につなぎ、1回のクリックで
            % 右端まで追跡し、写真ごとにデトレンドしてセグメントごとに分け直せる
            numSeg = 10; segWidth = 60;
            clouds(numSeg,1) = GroovePointCloud();
            for j = 1:numSeg
                xLocal = (1:segWidth)';
                xGlobal = xLocal + (j-1)*segWidth;
                cells = cell(1, segWidth);
                for c = 1:segWidth
                    ys = arrayfun(@(g) testCase.wavyGroove(xGlobal(c), g), ...
                        (1:testCase.NUM_GROOVES)');
                    cells{c} = [xLocal(c)*ones(numel(ys),1), ys];
                end
                clouds(j) = testCase.cloud(segWidth, cells);
            end
            xAll = (1:numSeg*segWidth)';
            yTrue = testCase.wavyGroove(xAll, testCase.TARGET);

            [pks, xQuery, counts] = mergeSegmentPoints(clouds);
            [points, found] = trackGroove(pks, [2, yTrue(2)+2], xQuery);
            detrended = detrendTrackedShape(points);

            testCase.verifyEqual(xQuery, xAll);
            testCase.verifyTrue(all(found));
            testCase.verifyEqual(points(:,2), yTrue, "AbsTol", 1e-9);
            testCase.verifyEqual(mean(detrended(:,2)), 0, "AbsTol", 1e-10);
            segs = mat2cell(detrended(:,2), counts);
            testCase.verifyNumElements(segs, numSeg);
            testCase.verifyEqual(cellfun(@numel, segs), segWidth*ones(numSeg,1));
        end
    end

    %% 合成データ
    methods (Access = private)

        function y = wavyGroove(testCase, x, k)
            % k本目の溝の真のy座標：ゆるい傾き＋周期37pxの正弦波（振幅0.5px）
            y = testCase.Y_FIRST + (k-1)*testCase.GROOVE_PITCH + 0.01*x + 0.5*sin(2*pi*x/37);
        end

        function y = lineGroove(testCase, x, k, slope)
            y = testCase.Y_FIRST + (k-1)*testCase.GROOVE_PITCH + slope*x;
        end

        function pks = wavyPoints(testCase, xq, opts)
            % 全部の溝の点（各列 NUM_GROOVES 点）。RemoveX の列では全部の溝の点を、
            % RemoveTargetX の列では追跡する溝の点だけを消す
            arguments
                testCase
                xq (:,1) double
                opts.RemoveX (:,1) double = zeros(0,1)
                opts.RemoveTargetX (:,1) double = zeros(0,1)
            end
            pks = zeros(0,2);
            for k = 1:testCase.NUM_GROOVES
                keep = ~ismember(xq, opts.RemoveX);
                if k == testCase.TARGET
                    keep = keep & ~ismember(xq, opts.RemoveTargetX);
                end
                pks = [pks; xq(keep), testCase.wavyGroove(xq(keep), k)]; %#ok<AGROW>
            end
        end

        function pks = linePoints(testCase, xq, slope, opts)
            arguments
                testCase
                xq (:,1) double
                slope (1,1) double
                opts.RemoveX (:,1) double = zeros(0,1)
            end
            keep = ~ismember(xq, opts.RemoveX);
            pks = zeros(0,2);
            for k = 1:testCase.NUM_GROOVES
                pks = [pks; xq(keep), testCase.lineGroove(xq(keep), k, slope)]; %#ok<AGROW>
            end
        end
    end

    methods (Static, Access = private)

        function pc = cloud(width, cells)
            % 幅 width（元の画像の幅）の GroovePointCloud に、点群 cells を直接入れる
            pc = GroovePointCloud();
            pc.imgID = [1; 1];
            pc.width = width;
            pc.height = 100;
            pc.peakCells = cells;
        end

        function [cond, allImg, res] = minimalCycle(saveDir, numImages, numSegments)
            % saveCycleResult に渡せる最小の1周分（写真 numImages 枚 x numSegments）
            n = numImages*numSegments;
            imgW = 3;
            allImg(n,1) = ImageData();
            pts(n,1) = GroovePointCloud();
            xcoords = cell(n,1);
            ycoords = cell(n,1);
            for k = 1:n
                img = 255*ones(10, imgW);
                img(5,:) = 0;
                allImg(k) = ImageData(img, [ceil(k/numSegments); mod(k-1,numSegments)+1]);
                pts(k) = GroovePointCloud(DarknessMap(allImg(k)));
                xcoords{k} = (1:imgW)';
                ycoords{k} = sin((1:imgW)');
            end
            yComb = vertcat(ycoords{:});
            audio = AudioData("acceptance test audio", yComb/1.5, 100);
            res = cycleMethodResult("centroid", pts, xcoords, ycoords, yComb, audio);
            cond = cycleConditions(Upsampling="origD", Date="0101", ...
                SaveDir=saveDir, NumImages=numImages, NumSegments=numSegments, ...
                LMask=20, ThHist=NaN, DThresh=0.6, WTh=8, ...
                Tol=NaN, BinWidth=NaN, HPrl=NaN, PolyDegree=9, ...
                ScriptName="GrooveTrackingAcceptanceTest");
        end
    end
end
