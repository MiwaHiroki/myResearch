% issue #30（写真ごとに1回のクリックからN本の溝を抽出し、N周分の音声を作る）の受け入れテスト
%
% docs/issues/closed/30-multi-groove/plan.md 4.2 のインターフェースと要求仕様を、関数の外側から
% 確かめる（findGrooveCenters, extractGrooveBands, extractMultiGroove,
% detrendTrackedShape の2つ目の出力, cycleMethodResult の (TOTAL_SEGMENTS x N),
% 保存・読み込みでの 80xN と grooveSelection.multiGroove）。
% 内部の手順や途中の変数には依存させない（それは実装担当の unit テストの役目）。
% 評価担当が作成した。実装担当は変更しない（docs/rules/evaluation.md）。
%
% 合成データ：溝 g = -1..5 を、y が小さい側（レコードの内側）へ GROOVE_PITCH px おきに並べる。
% g = 0 をクリックする溝（1本目）とし、その外側（y が大きい側）にも溝 g = -1 を置く
% （実データと同じく、1本目の山がヒストグラムの端に来ないようにするため）。
% 各溝のy座標は真の式から作るので、取り出した溝は真の値と厳密に一致するはず。
classdef MultiGrooveAcceptanceTest < matlab.unittest.TestCase

    properties (Constant)
        N_COLS       = 600
        GROOVE_PITCH = 27    % 溝の間隔[px]（実データは25.5〜28.4px）
        GROOVES      = -1:5  % 合成データの溝の番号（0がクリックする溝。番号が大きいほどyが小さい）
    end

    methods (TestClassSetup)
        function addToPath(testCase)
            import matlab.unittest.fixtures.PathFixture
            thisDir = fileparts(mfilename('fullpath'));
            srcDir  = fullfile(thisDir, '..', '..', 'src');
            testCase.applyFixture(PathFixture(srcDir));
        end
    end

    %% detrendTrackedShape の2つ目の出力
    methods (Test)

        function testSecondOutputKeepsFirstOutputUnchanged(testCase)
            % 2つ目の出力を受け取っても、1つ目の出力は今と同じ（1出力で呼んだときと同じ）
            x = (1:1000)';
            y = 0.5*sin(2*pi*x/37) + 1e-5*(x-500).^2 + 0.01*x + 3;

            outOne = detrendTrackedShape([x, y], PolyDegree=5);
            [outTwo, ~] = detrendTrackedShape([x, y], PolyDegree=5);

            testCase.verifyEqual(outTwo, outOne);
        end

        function testTrendReproducesTheFittedPolynomial(testCase)
            % trend.p・S・mu で polyval した値を引いて平均を引くと、1つ目の出力のyになる
            x = (1:1000)';
            y = 0.5*sin(2*pi*x/37) + 1e-5*(x-500).^2 + 0.01*x + 3;

            [out, trend] = detrendTrackedShape([x, y], PolyDegree=5);

            testCase.verifyTrue(isstruct(trend) && isscalar(trend));
            testCase.verifyTrue(all(isfield(trend, ["p","S","mu","degree"])));
            testCase.verifyEqual(trend.degree, 5);
            r = y - polyval(trend.p, x, trend.S, trend.mu);
            testCase.verifyEqual(out(:,2), r - mean(r), "AbsTol", 1e-10);
        end

        function testTrendDegreeDefaultsToNine(testCase)
            x = (1:4000)';
            y = sin(2*pi*x/37) + 1e-3*x;

            [~, trend] = detrendTrackedShape([x, y]);

            testCase.verifyEqual(trend.degree, 9);
            testCase.verifyNumElements(trend.p, 10);
        end
    end

    %% findGrooveCenters
    methods (Test)

        function testReturnsCentersTowardSmallerY(testCase)
            % 補正後の y = 0.3, -26.7, -53.7, ...（各600点、±0.4 のゆらぎ）＋溝の間の偽の点。
            % 1本目は 0 に最も近い山、2本目以降は y の小さい側へ順に、ビンの中心を返す
            trueCenters = testCase.correctedCenters(0.3);
            pksCor = testCase.correctedPoints(trueCenters);

            centers = findGrooveCenters(pksCor, 4, BinWidth=1, MinPeakHeight=0.3*testCase.N_COLS);

            testCase.verifySize(centers, [4 1]);
            expected = trueCenters(testCase.GROOVES >= 0 & testCase.GROOVES <= 3);
            testCase.verifyLessThanOrEqual(abs(centers - expected), 0.5 + 1e-9);
            testCase.verifyTrue(all(diff(centers) < 0));
        end

        function testFirstCenterOnBinEdgeIsFound(testCase)
            % 1本目の中心がビンの端（y=0）にあり、点が2つのビンに分かれても選べる
            trueCenters = testCase.correctedCenters(0);
            pksCor = testCase.correctedPoints(trueCenters);

            centers = findGrooveCenters(pksCor, 3, BinWidth=1, MinPeakHeight=0.3*testCase.N_COLS);

            testCase.verifyLessThanOrEqual(abs(centers - [0; -27; -54]), 0.5 + 1e-9);
        end

        function testFirstCenterOptionShiftsTheStart(testCase)
            % FirstCenter=-27 なら、-27 の山を1本目として、そこから y の小さい側へ数える
            trueCenters = testCase.correctedCenters(0.3);
            pksCor = testCase.correctedPoints(trueCenters);

            centers = findGrooveCenters(pksCor, 3, BinWidth=1, ...
                MinPeakHeight=0.3*testCase.N_COLS, FirstCenter=-27);

            testCase.verifyLessThanOrEqual(abs(centers - [-26.7; -53.7; -80.7]), 0.5 + 1e-9);
        end

        function testBinWidthBoundsTheCenterError(testCase)
            % BinWidth=2 では、ビンの中心と溝の中心の差は BinWidth/2 以内
            trueCenters = testCase.correctedCenters(0.3);
            pksCor = testCase.correctedPoints(trueCenters);

            centers = findGrooveCenters(pksCor, 4, BinWidth=2, MinPeakHeight=0.3*testCase.N_COLS);

            expected = trueCenters(testCase.GROOVES >= 0 & testCase.GROOVES <= 3);
            testCase.verifyLessThanOrEqual(abs(centers - expected), 1 + 1e-9);
        end

        function testSingleGrooveNeedsNoInnerPeaks(testCase)
            % numGrooves=1 なら、1本目の山だけを返す
            trueCenters = testCase.correctedCenters(0.3);
            pksCor = testCase.correctedPoints(trueCenters);

            centers = findGrooveCenters(pksCor, 1, BinWidth=1, MinPeakHeight=0.3*testCase.N_COLS);

            testCase.verifySize(centers, [1 1]);
            testCase.verifyLessThanOrEqual(abs(centers - 0.3), 0.5 + 1e-9);
        end

        function testInfoDescribesTheHistogram(testCase)
            % info：peakCenters は昇順で、peakCenters(firstIdx) が centers(1)
            trueCenters = testCase.correctedCenters(0.3);
            pksCor = testCase.correctedPoints(trueCenters);

            [centers, info] = findGrooveCenters(pksCor, 4, BinWidth=1, ...
                MinPeakHeight=0.3*testCase.N_COLS);

            testCase.verifyTrue(all(isfield(info, ...
                ["binCenters","counts","peakCenters","peakHeights","firstIdx"])));
            testCase.verifyTrue(all(diff(info.peakCenters) > 0));
            testCase.verifyEqual(info.peakCenters(info.firstIdx), centers(1));
            testCase.verifyEqual(numel(info.peakHeights), numel(info.peakCenters));
            testCase.verifyEqual(numel(info.counts), numel(info.binCenters));
            % 合成データの7本の溝がすべて山になり、偽の点（1か所12点）は山にならない
            testCase.verifyNumElements(info.peakCenters, numel(testCase.GROOVES));
            testCase.verifyGreaterThanOrEqual(min(info.peakHeights), 0.3*testCase.N_COLS);
        end

        function testNotEnoughPeaksErrors(testCase)
            % 1本目より y の小さい側に山が5個しかない → 7本は選べない
            pksCor = testCase.correctedPoints(testCase.correctedCenters(0.3));

            testCase.verifyError(@() findGrooveCenters(pksCor, 7, BinWidth=1, ...
                MinPeakHeight=0.3*testCase.N_COLS), "findGrooveCenters:notEnoughPeaks");
        end

        function testNoPeaksErrors(testCase)
            pksCor = testCase.correctedPoints(testCase.correctedCenters(0.3));

            testCase.verifyError(@() findGrooveCenters(pksCor, 2, BinWidth=1, ...
                MinPeakHeight=1e4), "findGrooveCenters:noPeaksFound");
        end

        function testMissingFirstPeakErrors(testCase)
            % 1本目（y≈0）の溝の点が無いとき、隣の山（±27px）を1本目にせずエラーにする
            trueCenters = testCase.correctedCenters(0.3);
            pksCor = testCase.correctedPoints(trueCenters, Omit=0);

            testCase.verifyError(@() findGrooveCenters(pksCor, 2, BinWidth=1, ...
                MinPeakHeight=0.3*testCase.N_COLS), "findGrooveCenters:firstPeakNotFound");
        end

        function testMaxFirstOffsetIsUsed(testCase)
            % FirstCenter=6 から1本目の山（0.3付近）までは5px以上：既定（5px）ではエラー、
            % MaxFirstOffset=10 なら 0.3 付近の山を1本目にする
            trueCenters = testCase.correctedCenters(0.3);
            pksCor = testCase.correctedPoints(trueCenters);

            testCase.verifyError(@() findGrooveCenters(pksCor, 2, BinWidth=1, ...
                MinPeakHeight=0.3*testCase.N_COLS, FirstCenter=6), ...
                "findGrooveCenters:firstPeakNotFound");
            centers = findGrooveCenters(pksCor, 2, BinWidth=1, ...
                MinPeakHeight=0.3*testCase.N_COLS, FirstCenter=6, MaxFirstOffset=10);
            testCase.verifyLessThanOrEqual(abs(centers - [0.3; -26.7]), 0.5 + 1e-9);
        end
    end

    %% extractGrooveBands
    methods (Test)

        function testBandsReturnOriginalY(testCase)
            % 2次式の trend を足した溝から、補正後の中心 -27, -54, -81 の帯の点を取り出す。
            % 返す y は元の画像の y のまま
            x = (1:testCase.N_COLS)';
            [pks, trend, yTrue] = testCase.bandData(x);

            [bands, found, info] = extractGrooveBands(pks, trend, [-27; -54; -81], x, Tolerance=3);

            testCase.verifySize(bands, [3 1]);
            testCase.verifyClass(found, "logical");
            testCase.verifySize(found, [numel(x) 3]);
            testCase.verifyTrue(all(found(:)));
            for k = 1:3
                testCase.verifyEqual(bands{k}(:,1), x);
                testCase.verifyEqual(bands{k}(:,2), yTrue(:,k+1), "AbsTol", 1e-12);
            end
            testCase.verifyEqual(info.numDuplicateCols, [0 0 0]);
            testCase.verifyEqual(info.numMissing, [0 0 0]);
        end

        function testGapIsInterpolatedInOriginalY(testCase)
            % x=200〜220 で -54 の溝の点を消す → found=false、元の y で線形補間する
            % （補正後の y で補間して trend を足し戻した値とは、2次式の分だけ違う）
            x = (1:testCase.N_COLS)';
            gapX = (200:220)';
            [pks, trend, yTrue] = testCase.bandData(x, RemoveX=gapX, RemoveFrom=2);

            [bands, found, info] = extractGrooveBands(pks, trend, [-27; -54; -81], x, Tolerance=3);

            isGap = ismember(x, gapX);
            testCase.verifyFalse(any(found(isGap,2)));
            testCase.verifyTrue(all(found(~isGap,2)));
            testCase.verifyTrue(all(found(:,[1 3]), "all"));
            yLinear = interp1([199; 221], yTrue([199; 221], 3), gapX);
            testCase.verifyEqual(bands{2}(isGap,2), yLinear, "AbsTol", 1e-9);
            testCase.verifyEqual(bands{2}(~isGap,2), yTrue(~isGap,3), "AbsTol", 1e-12);
            testCase.verifyEqual(info.numMissing, [0 numel(gapX) 0]);
        end

        function testNearestPointWinsInTheSameColumn(testCase)
            % x=300 で -27 の溝の点を、中心から 0.3px と 2px の2点に置き換える
            % （近い点を先、遠い点を後に並べる）→ 近い点を採り、2点の列を1と数える
            x = (1:testCase.N_COLS)';
            [pks, trend] = testCase.bandData(x, RemoveX=300, RemoveFrom=1);
            t300 = polyval(trend.p, 300, trend.S, trend.mu);
            pks = [pks; 300, t300 - 27 + 0.3; 300, t300 - 27 - 2];

            [bands, found, info] = extractGrooveBands(pks, trend, [-27; -54], x, Tolerance=3);

            testCase.verifyTrue(found(300,1));
            testCase.verifyEqual(bands{1}(300,2), t300 - 27 + 0.3, "AbsTol", 1e-9);
            testCase.verifyEqual(info.numDuplicateCols, [1 0]);
        end

        function testPointOutsideToleranceIsNotTaken(testCase)
            % x=310 で -27 の溝の点を、中心から 3.5px の点に置き換える → Tolerance=3 では採らない
            x = (1:testCase.N_COLS)';
            [pks, trend, yTrue] = testCase.bandData(x, RemoveX=310, RemoveFrom=1);
            t310 = polyval(trend.p, 310, trend.S, trend.mu);
            pks = [pks; 310, t310 - 27 + 3.5];

            [bands, found] = extractGrooveBands(pks, trend, [-27; -54], x, Tolerance=3);

            testCase.verifyFalse(found(310,1));
            yLinear = interp1([309; 311], yTrue([309; 311], 2), 310);
            testCase.verifyEqual(bands{1}(310,2), yLinear, "AbsTol", 1e-9);
        end

        function testToleranceArgumentIsUsed(testCase)
            % 中心から 2.5px の点は、Tolerance=3 なら採り、Tolerance=2 なら採らない
            x = (1:testCase.N_COLS)';
            [pks, trend] = testCase.bandData(x, RemoveX=320, RemoveFrom=1);
            t320 = polyval(trend.p, 320, trend.S, trend.mu);
            pks = [pks; 320, t320 - 27 - 2.5];

            [bandsWide, foundWide] = extractGrooveBands(pks, trend, -27, x, Tolerance=3);
            [~, foundNarrow] = extractGrooveBands(pks, trend, -27, x, Tolerance=2);

            testCase.verifyTrue(foundWide(320));
            testCase.verifyEqual(bandsWide{1}(320,2), t320 - 27 - 2.5, "AbsTol", 1e-9);
            testCase.verifyFalse(foundNarrow(320));
        end

        function testPointsOffTheQueryGridAreIgnored(testCase)
            % x=100 の点を消し、x=100.5（xQuery に無い）に帯の中の点を置く → 使わない
            x = (1:testCase.N_COLS)';
            [pks, trend, yTrue] = testCase.bandData(x, RemoveX=100, RemoveFrom=1);
            pks = [pks; 100.5, polyval(trend.p, 100.5, trend.S, trend.mu) - 27];

            [bands, found] = extractGrooveBands(pks, trend, -27, x, Tolerance=3);

            testCase.verifyFalse(found(100));
            yLinear = interp1([99; 101], yTrue([99; 101], 2), 100);
            testCase.verifyEqual(bands{1}(100,2), yLinear, "AbsTol", 1e-9);
        end

        function testTooFewPointsErrors(testCase)
            % 帯の中の点が1つしか無い → 補間できないのでエラー
            x = (1:testCase.N_COLS)';
            [pks, trend] = testCase.bandData(x);
            pks = [pks; 300, polyval(trend.p, 300, trend.S, trend.mu) - 150];

            testCase.verifyError(@() extractGrooveBands(pks, trend, [-27; -150], x, Tolerance=3), ...
                "extractGrooveBands:tooFewPoints");
        end

        function testFractionalQueryGrid(testCase)
            % 列の間隔 0.25px でも使える
            x = (1:0.25:testCase.N_COLS)';
            [pks, trend, yTrue] = testCase.bandData(x);

            [bands, found] = extractGrooveBands(pks, trend, [-27; -54], x, Tolerance=3);

            testCase.verifyTrue(all(found(:)));
            testCase.verifyEqual(bands{1}(:,1), x);
            testCase.verifyEqual(bands{1}(:,2), yTrue(:,2), "AbsTol", 1e-12);
            testCase.verifyEqual(bands{2}(:,2), yTrue(:,3), "AbsTol", 1e-12);
        end
    end

    %% extractMultiGroove
    methods (Test)

        function testExtractsGroovesTowardSmallerY(testCase)
            % 溝 g=0 の左端付近（+1px）をクリック → 1〜4本目が溝 g=0,1,2,3（y の小さい側）。
            % 各溝は detrendTrackedShape（既定9次）をかけた真の形状と一致する
            x = (1:testCase.N_COLS)';
            pks = testCase.photoPoints(x);
            seed = [1, testCase.grooveY(1, 0) + 1];

            [shapes, info] = extractMultiGroove(pks, seed, x, 4);

            testCase.verifySize(shapes, [1 4]);
            for j = 1:4
                expected = detrendTrackedShape([x, testCase.grooveY(x, j-1)]);
                testCase.verifyEqual(shapes{j}(:,1), x);
                testCase.verifyEqual(shapes{j}(:,2), expected(:,2), "AbsTol", 1e-9);
                testCase.verifyEqual(info.yAbs(:,j), testCase.grooveY(x, j-1), "AbsTol", 1e-9);
            end
        end

        function testDirectionWithGroovesOnBothSides(testCase)
            % 溝 g=1 をクリック（外側に g=0 と g=-1、内側に g=2..5 がある）→ 2本目は g=2
            % （y の大きい側の g=0 ではない）
            x = (1:testCase.N_COLS)';
            pks = testCase.photoPoints(x);
            seed = [1, testCase.grooveY(1, 1) - 1];

            [shapes, info] = extractMultiGroove(pks, seed, x, 3);

            for j = 1:3
                testCase.verifyEqual(info.yAbs(:,j), testCase.grooveY(x, j), "AbsTol", 1e-9);
                expected = detrendTrackedShape([x, testCase.grooveY(x, j)]);
                testCase.verifyEqual(shapes{j}(:,2), expected(:,2), "AbsTol", 1e-9);
            end
        end

        function testInfoFieldsAndSizes(testCase)
            x = (1:testCase.N_COLS)';
            pks = testCase.photoPoints(x);
            seed = [1, testCase.grooveY(1, 0) + 1];
            n = numel(x);

            [shapes, info] = extractMultiGroove(pks, seed, x, 4);

            testCase.verifyTrue(all(isfield(info, ["track","trend","centers","hist", ...
                "minPeakHeight","yAbs","found","numDuplicateCols"])));
            testCase.verifySize(info.centers, [4 1]);
            testCase.verifySize(info.yAbs, [n 4]);
            testCase.verifyClass(info.found, "logical");
            testCase.verifySize(info.found, [n 4]);
            testCase.verifyTrue(all(info.found(:)));
            testCase.verifyEqual(info.numDuplicateCols, zeros(1,4));
            testCase.verifyEqual(info.minPeakHeight, 0.3*n, "AbsTol", 1e-9);
            testCase.verifyEqual(info.trend.degree, 9);
            testCase.verifyEqual(info.track.seedIdx, 1);
            % 補正後の山の中心：1本目が 0 付近、以後 27px おき（ビンの幅の半分＋あてはめの残差以内）
            testCase.verifyLessThanOrEqual(abs(info.centers - (0:-27:-81)'), 0.6);
            % trend は1本目の多項式（1本目の y から引くと、平均0で1つ目の出力と同じ）
            r = info.yAbs(:,1) - polyval(info.trend.p, x, info.trend.S, info.trend.mu);
            testCase.verifyEqual(shapes{1}(:,2), r - mean(r), "AbsTol", 1e-9);
        end

        function testFirstGrooveMatchesTrackGroove(testCase)
            % 1本目は trackGroove の結果そのもの（#25 と同じ）
            x = (1:testCase.N_COLS)';
            pks = testCase.photoPoints(x, RemoveX=(250:262)', RemoveFrom=0);
            seed = [1, testCase.grooveY(1, 0) + 1];

            [points, found] = trackGroove(pks, seed, x);
            [shapes, info] = extractMultiGroove(pks, seed, x, 3);

            testCase.verifyEqual(info.yAbs(:,1), points(:,2));
            testCase.verifyEqual(info.found(:,1), found);
            expected = detrendTrackedShape(points);
            testCase.verifyEqual(shapes{1}, expected);
        end

        function testSingleGrooveIsTrackingOnly(testCase)
            % numGrooves=1 → trackGroove → detrendTrackedShape と同じで、centers は空
            x = (1:testCase.N_COLS)';
            pks = testCase.photoPoints(x);
            seed = [1, testCase.grooveY(1, 0) + 1];

            [shapes, info] = extractMultiGroove(pks, seed, x, 1);

            points = trackGroove(pks, seed, x);
            expected = detrendTrackedShape(points);
            testCase.verifySize(shapes, [1 1]);
            testCase.verifyEqual(shapes{1}, expected);
            testCase.verifyEmpty(info.centers);
            testCase.verifySize(info.yAbs, [numel(x) 1]);
        end

        function testMissingColumnsOfInnerGroove(testCase)
            % 溝 g=2（3本目）の x=200〜215 の点を消す → info.found(:,3) のその列だけ false、
            % その列は元の y で線形補間
            x = (1:testCase.N_COLS)';
            gapX = (200:215)';
            pks = testCase.photoPoints(x, RemoveX=gapX, RemoveFrom=2);
            seed = [1, testCase.grooveY(1, 0) + 1];

            [~, info] = extractMultiGroove(pks, seed, x, 4);

            isGap = ismember(x, gapX);
            testCase.verifyFalse(any(info.found(isGap,3)));
            testCase.verifyTrue(all(info.found(~isGap,3)));
            testCase.verifyTrue(all(info.found(:,[1 2 4]), "all"));
            yTrue = testCase.grooveY(x, 2);
            yLinear = interp1([199; 216], yTrue([199; 216]), gapX);
            testCase.verifyEqual(info.yAbs(isGap,3), yLinear, "AbsTol", 1e-9);
        end

        function testPolyDegreeAppliesToEveryGroove(testCase)
            % PolyDegree はすべての溝のデトレンドに使う（Q2）
            x = (1:testCase.N_COLS)';
            pks = testCase.photoPoints(x);
            seed = [1, testCase.grooveY(1, 0) + 1];

            shapes = extractMultiGroove(pks, seed, x, 3, PolyDegree=5);

            for j = 1:3
                expected = detrendTrackedShape([x, testCase.grooveY(x, j-1)], PolyDegree=5);
                testCase.verifyEqual(shapes{j}(:,2), expected(:,2), "AbsTol", 1e-9);
            end
        end

        function testAcceptsAllOptions(testCase)
            % plan.md 4.2 の name-value 引数をすべて受け付ける（既定値と同じ値なら結果も同じ）
            x = (1:testCase.N_COLS)';
            pks = testCase.photoPoints(x);
            seed = [1, testCase.grooveY(1, 0) + 1];

            shapesDefault = extractMultiGroove(pks, seed, x, 3);
            shapesAll = extractMultiGroove(pks, seed, x, 3, TrackTolerance=2, FitLength=60, ...
                SnapRadius=10, InitLength=20, MaxGapLength=40, PolyDegree=9, ...
                BinWidth=1, MinPeakRatio=0.3, BandTolerance=3);

            testCase.verifyEqual(shapesAll, shapesDefault);
        end

        function testTrackToleranceIsForwarded(testCase)
            % 1本目の追跡には TrackTolerance を使う：ゆらぎの無い溝 g=0 の x=300 の点を +1.5px
            % ずらす → TrackTolerance=2 なら採り、1 なら採らない
            x = (1:testCase.N_COLS)';
            pks = testCase.parallelPoints(x);
            yShift = testCase.parallelY(300, 0) + 1.5;
            pks(pks(:,1) == 300 & abs(pks(:,2) - testCase.parallelY(300, 0)) < 1e-9, 2) = yShift;
            seed = [1, testCase.parallelY(1, 0)];

            [~, infoWide] = extractMultiGroove(pks, seed, x, 2, TrackTolerance=2);
            [~, infoNarrow] = extractMultiGroove(pks, seed, x, 2, TrackTolerance=1);

            testCase.verifyTrue(infoWide.found(300,1));
            testCase.verifyEqual(infoWide.yAbs(300,1), yShift, "AbsTol", 1e-9);
            testCase.verifyFalse(infoNarrow.found(300,1));
        end

        function testBandToleranceIsUsed(testCase)
            % ゆらぎの無い平行な溝（補正後の中心が -27.4g）で、溝 g=2 の x=300 の点を +2px ずらす
            % （帯の中心＝ビンの中心は溝から BinWidth/2 以内なので、中心からは 1.5〜2.5px）
            % → BandTolerance=3 なら採り、1.2 なら採らない
            x = (1:testCase.N_COLS)';
            pks = testCase.parallelPoints(x);
            yShift = testCase.parallelY(300, 2) + 2;
            pks(pks(:,1) == 300 & abs(pks(:,2) - testCase.parallelY(300, 2)) < 1e-9, 2) = yShift;
            seed = [1, testCase.parallelY(1, 0)];

            [~, infoWide] = extractMultiGroove(pks, seed, x, 4, BandTolerance=3);
            [~, infoNarrow] = extractMultiGroove(pks, seed, x, 4, BandTolerance=1.2);

            testCase.verifyTrue(infoWide.found(300,3));
            testCase.verifyEqual(infoWide.yAbs(300,3), yShift, "AbsTol", 1e-9);
            testCase.verifyFalse(infoNarrow.found(300,3));
            testCase.verifyTrue(all(infoNarrow.found(x ~= 300, 3)));
        end

        function testMinPeakRatioIsRelativeToColumns(testCase)
            % 山の高さのしきい値は MinPeakRatio × 列の数。1つの溝は1列に1点なので、
            % 1を超える割合ではどの溝も山にならない（点の数そのものとして使うと、偽の点も山になる）
            x = (1:testCase.N_COLS)';
            pks = testCase.photoPoints(x);
            seed = [1, testCase.grooveY(1, 0) + 1];

            [~, info] = extractMultiGroove(pks, seed, x, 3, MinPeakRatio=0.2);
            testCase.verifyEqual(info.minPeakHeight, 0.2*numel(x), "AbsTol", 1e-9);
            testCase.verifyEqual(info.yAbs(:,3), testCase.grooveY(x, 2), "AbsTol", 1e-9);

            testCase.verifyError(@() extractMultiGroove(pks, seed, x, 3, MinPeakRatio=1.5), ...
                "findGrooveCenters:noPeaksFound");
        end

        function testFractionalQueryGridMatchesIntegerGrid(testCase)
            % 列の間隔 0.25px（列が約4倍）でも、同じ引数で同じ溝を選び、整数のxでの
            % デトレンド前の y が列の間隔1pxのときと一致する（MinPeakRatio が割合であることの確認）
            xInt  = (1:testCase.N_COLS)';
            xFrac = (1:0.25:testCase.N_COLS)';
            seed = [1, testCase.grooveY(1, 0) + 1];

            [~, infoInt]  = extractMultiGroove(testCase.photoPoints(xInt), seed, xInt, 4);
            [~, infoFrac] = extractMultiGroove(testCase.photoPoints(xFrac), seed, xFrac, 4);

            isInt = ismember(xFrac, xInt);
            testCase.verifyEqual(infoFrac.yAbs(isInt,:), infoInt.yAbs, "AbsTol", 1e-9);
            testCase.verifyTrue(all(infoFrac.found(:)));
            testCase.verifyLessThanOrEqual(abs(infoFrac.centers - infoInt.centers), 1 + 1e-9);
        end

        function testTooManyGroovesErrors(testCase)
            % 1本目より y の小さい側に溝は5本 → 8本は選べない（識別子付きのエラーで止まる）
            x = (1:testCase.N_COLS)';
            pks = testCase.photoPoints(x);
            seed = [1, testCase.grooveY(1, 0) + 1];

            testCase.verifyError(@() extractMultiGroove(pks, seed, x, 8), ...
                "findGrooveCenters:notEnoughPeaks");
        end

        function testSeedFarFromAnyGrooveErrors(testCase)
            % 溝と溝の真ん中（どちらからも13.5px）をクリック → trackGroove の識別子のまま
            x = (1:testCase.N_COLS)';
            pks = testCase.photoPoints(x);
            seed = [1, testCase.grooveY(1, 0) + 13.5];

            testCase.verifyError(@() extractMultiGroove(pks, seed, x, 3), ...
                "trackGroove:seedNotFound");
        end
    end

    %% cycleMethodResult（N周分）
    methods (Test)

        function testMethodResultAcceptsSegmentsByCycles(testCase)
            % (4 x 2) の xcoords・ycoords（j列目が j周目）、pts は (4 x 1)
            [pts, xc, yc] = testCase.cycleCells(4, 2);
            yComb = vertcat(yc{:});

            res = cycleMethodResult("centroid", pts, xc, yc, yComb, AudioData("a", yComb, 10));

            testCase.verifySize(res.ycoords, [4 2]);
            testCase.verifySize(res.xcoords, [4 2]);
            testCase.verifyEqual(res.ycoords, yc);
            testCase.verifyEqual(res.y_comb, yComb);
            testCase.verifyNumElements(res.pts, 4);
        end

        function testMethodResultRejectsMismatchedShapes(testCase)
            [pts, xc, yc] = testCase.cycleCells(4, 2);
            yComb = vertcat(yc{:});
            audio = AudioData("a", yComb, 10);
            [~, xc3] = testCase.cycleCells(4, 3);

            % xcoords と ycoords の形が違う
            testCase.verifyError(@() cycleMethodResult("centroid", pts, xc3, yc, yComb, audio), ...
                "cycleMethodResult:sizeMismatch");
            % pts の数が size(ycoords,1) と違う
            testCase.verifyError(@() cycleMethodResult("centroid", pts(1:3), xc, yc, yComb, audio), ...
                "cycleMethodResult:sizeMismatch");
        end

        function testMethodResultChecksYCombOverAllCycles(testCase)
            % y_comb が1周目だけ（vertcat(ycoords{:,1})）なら、長さが合わずエラー
            [pts, xc, yc] = testCase.cycleCells(4, 2);
            yFirst = vertcat(yc{:,1});

            testCase.verifyError(@() cycleMethodResult("centroid", pts, xc, yc, yFirst, ...
                AudioData("a", yFirst, 10)), "cycleMethodResult:yCombLength");
        end

        function testMethodResultRowCellStillBecomesColumn(testCase)
            % 1周分の行の cell は、今と同じく列に直されて通る
            [pts, xc, yc] = testCase.cycleCells(4, 1);
            yComb = vertcat(yc{:});

            res = cycleMethodResult("centroid", pts, xc', yc', yComb, AudioData("a", yComb, 10));

            testCase.verifySize(res.ycoords, [4 1]);
            testCase.verifySize(res.xcoords, [4 1]);
            testCase.verifyEqual(res.ycoords, yc);
        end
    end

    %% 保存・読み込み（N周分と grooveSelection.multiGroove）
    methods (Test)

        function testCyclesAndMultiGrooveSurviveSaveAndLoad(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            tmp = testCase.applyFixture(TemporaryFolderFixture);
            saveDir = string(tmp.Folder);

            numImages = 2; numSegments = 2; numGrooves = 3; n = numImages*numSegments;
            [cond, allImg, pts] = testCase.minimalImages(saveDir, numImages, numSegments);
            [~, xc, yc] = testCase.cycleCells(n, numGrooves);
            yComb = vertcat(yc{:});
            resCnt = cycleMethodResult("centroid", pts, xc, yc, yComb, ...
                AudioData("acceptance multi cnt", yComb/1.5, 100));
            resMax = cycleMethodResult("localMax", pts, xc, yc, 2*yComb, ...
                AudioData("acceptance multi max", 2*yComb/1.5, 100));

            [~, trend] = detrendTrackedShape([(1:6)', (1:6)'.^2], PolyDegree=2);
            mg = struct();
            mg.numGrooves = numGrooves; mg.binWidth = 1; mg.thHistRatio = 0.3; mg.bandTol = 3;
            mg.polyDegree = 9; mg.detrendScope = "photo"; mg.ampDivisor = 1.5;
            mg.centersCnt = [0.5 -27.5 -53.5; -0.5 -26.5 -52.5];
            mg.centersMax = mg.centersCnt;
            mg.yAbsCnt = {(1:6)', (1:6)'+27, (1:6)'+54; (1:6)'+1, (1:6)'+28, (1:6)'+55};
            mg.yAbsMax = mg.yAbsCnt;
            mg.foundCnt = {true(6,1), [true; false; true(4,1)], true(6,1); ...
                true(6,1), true(6,1), true(6,1)};
            mg.foundMax = mg.foundCnt;
            mg.numDupCnt = zeros(numImages, numGrooves);
            mg.numDupMax = zeros(numImages, numGrooves);
            mg.trendCnt = {trend; trend};
            mg.trendMax = {trend; trend};
            seeds = [1 20; 1 30];
            gs = struct();
            gs.p1 = [ones(n,1), (1:n)'+10];
            gs.p2 = [3*ones(n,1), (1:n)'+11];
            gs.method = "histogram";
            gs.seeds = seeds;
            gs.multiGroove = mg;

            matPath = saveCycleResult(cond, allImg, [resCnt resMax], GrooveSelection=gs, ...
                FileName="cycleResult_origD_hist3_0101", Overwrite=false);
            result = loadCycleResult(matPath);

            testCase.verifySize(result.centroid.ycoords, [n numGrooves]);
            testCase.verifySize(result.localMax.xcoords, [n numGrooves]);
            testCase.verifyEqual(result.centroid.ycoords, yc);
            testCase.verifyEqual(result.centroid.y_comb, yComb);
            testCase.verifyEqual(result.localMax.y_comb, 2*yComb);
            testCase.verifyEqual(result.centroid.audio.signal, yComb/1.5, "AbsTol", 1e-12);
            testCase.verifyEqual(result.grooveSelection.method, "histogram");
            testCase.verifyEqual(result.grooveSelection.multiGroove, mg);
            % 読み込んだ grooveSelection から、ginput なしで1本目の始点を取り出せる
            testCase.verifyEqual(trackingSeeds(result.grooveSelection, numSegments), seeds);
        end

        function testTwoPhotoPipelineOrdersCyclesByColumn(testCase)
            % 写真2枚（各3セグメント）を mergeSegmentPoints → extractMultiGroove で処理し、
            % ycoords(ks, j) = mat2cell(shapes{j}(:,2), counts) とすると、
            % vertcat(ycoords{:}) が「1本目の写真1・写真2 → 2本目の写真1・写真2 → …」
            % （再生順）になり、cycleMethodResult がそのまま受け付ける
            numImages = 2; numSeg = 3; segWidth = 200; numGrooves = 3;
            n = numImages*numSeg;
            pts(n,1) = GroovePointCloud();
            xc = cell(n, numGrooves);
            yc = cell(n, numGrooves);
            expected = cell(numImages, numGrooves);
            for i = 1:numImages
                ks = (i-1)*numSeg + (1:numSeg);
                for jSeg = 1:numSeg
                    xLocal = (1:segWidth)';
                    xGlobal = xLocal + (jSeg-1)*segWidth;
                    cells = cell(1, segWidth);
                    for c = 1:segWidth
                        ys = testCase.grooveY(xGlobal(c), testCase.GROOVES', Photo=i);
                        cells{c} = [xLocal(c)*ones(numel(ys),1), ys];
                    end
                    pts(ks(jSeg)) = testCase.cloud(segWidth, cells);
                end
                [pks, xQuery, counts] = mergeSegmentPoints(pts(ks));
                seed = [xQuery(1), testCase.grooveY(1, 0, Photo=i) + 1];
                shapes = extractMultiGroove(pks, seed, xQuery, numGrooves);
                for j = 1:numGrooves
                    yc(ks, j) = mat2cell(shapes{j}(:,2), counts);
                    xc(ks, j) = {(1:segWidth)'};
                    e = detrendTrackedShape([xQuery, testCase.grooveY(xQuery, j-1, Photo=i)]);
                    expected{i,j} = e(:,2);
                end
            end
            yComb = vertcat(yc{:});

            res = cycleMethodResult("centroid", pts, xc, yc, yComb, AudioData("a", yComb, 10));

            testCase.verifyEqual(yComb, vertcat(expected{:}), "AbsTol", 1e-9);
            testCase.verifyEqual(res.y_comb, yComb);
            testCase.verifySize(res.ycoords, [n numGrooves]);
        end
    end

    %% 合成データ
    methods (Access = private)

        function c = correctedCenters(testCase, offset)
            % 補正後の溝の中心（GROOVES の順。g=0 が offset、g が1増えるごとに -27px）
            c = offset - testCase.GROOVE_PITCH*testCase.GROOVES';
        end

        function pksCor = correctedPoints(testCase, centers, opts)
            % 補正後の点群：各溝 N_COLS 点（±0.4 の正弦波のゆらぎ）＋ 溝の間と、いちばん外側・
            % 内側の溝のさらに外の偽の点（各12点。端の溝の山がヒストグラムの端に来ないように）。
            % Omit に溝の番号を書くと、その溝の点を入れない
            arguments
                testCase
                centers (:,1) double
                opts.Omit (1,:) double = zeros(1,0)
            end
            x = (1:testCase.N_COLS)';
            pksCor = zeros(0,2);
            for k = 1:numel(testCase.GROOVES)
                g = testCase.GROOVES(k);
                if ismember(g, opts.Omit)
                    continue
                end
                y = centers(k) + 0.4*sin(2*pi*x/(37 + 5*k));
                pksCor = [pksCor; x, y]; %#ok<AGROW>
            end
            xFake = (25:50:575)';
            edges = [centers(1) + testCase.GROOVE_PITCH; centers; centers(end) - testCase.GROOVE_PITCH];
            yMid = (edges(1:end-1) + edges(2:end)) / 2;
            for k = 1:numel(yMid)
                pksCor = [pksCor; xFake, yMid(k)*ones(size(xFake))]; %#ok<AGROW>
            end
        end

        function [pks, trend, yTrue] = bandData(testCase, x, opts)
            % extractGrooveBands 用：2次式の trend に、補正後の中心 0, -27, -54, -81 の溝
            % （±0.4 のゆらぎ）を足した点群。yTrue の列 k は中心 -(k-1)*27 の溝。
            % RemoveFrom（1〜3：中心 -27・-54・-81）の溝から RemoveX の列の点を消す
            arguments
                testCase
                x (:,1) double
                opts.RemoveX (:,1) double = zeros(0,1)
                opts.RemoveFrom (1,1) double = 0
            end
            base = 300 + 0.02*(x - 300) + 1e-4*(x - 300).^2;
            [p, S, mu] = polyfit(x, base, 2);
            trend = struct();
            trend.p = p;
            trend.S = S;
            trend.mu = mu;
            trend.degree = 2;
            trendY = polyval(p, x, S, mu);
            yTrue = zeros(numel(x), 4);
            pks = zeros(0,2);
            for k = 1:4
                yTrue(:,k) = trendY - testCase.GROOVE_PITCH*(k-1) + 0.4*sin(2*pi*x/(37 + 5*k));
                keep = true(size(x));
                if k - 1 == opts.RemoveFrom
                    keep = ~ismember(x, opts.RemoveX);
                end
                pks = [pks; x(keep), yTrue(keep,k)]; %#ok<AGROW>
            end
        end

        function y = grooveY(testCase, x, g, opts)
            % 溝 g の真の y：曲がった溝（2次式）＋溝ごとに違う正弦波（±0.4px）＋1px以下の平行でなさ。
            % Photo=2 では、写真ごとに違う位置・傾きにする
            arguments
                testCase
                x (:,1) double
                g (:,1) double
                opts.Photo (1,1) double = 1
            end
            base = 300 + 0.02*(x - 300) + 1e-4*(x - 300).^2 + 7*(opts.Photo - 1) ...
                - 0.01*(opts.Photo - 1)*(x - 300);
            if isscalar(g)
                y = base - testCase.GROOVE_PITCH*g + 0.4*sin(2*pi*x/(37 + 5*g)) + 5e-4*g*(x - 300);
            else
                % x がスカラー、g が列ベクトル（1列分の全部の溝）
                y = base - testCase.GROOVE_PITCH*g + 0.4*sin(2*pi*x./(37 + 5*g)) + 5e-4*g.*(x - 300);
            end
        end

        function pks = photoPoints(testCase, x, opts)
            % 写真1枚分の点群：溝 g=-1..5 の全部の点＋溝 g=0 と g=1 の間の偽の点（50列ごと）。
            % RemoveFrom の溝から RemoveX の列の点を消す
            arguments
                testCase
                x (:,1) double
                opts.RemoveX (:,1) double = zeros(0,1)
                opts.RemoveFrom (1,1) double = NaN
            end
            pks = zeros(0,2);
            for g = testCase.GROOVES
                keep = true(size(x));
                if g == opts.RemoveFrom
                    keep = ~ismember(x, opts.RemoveX);
                end
                pks = [pks; x(keep), testCase.grooveY(x(keep), g)]; %#ok<AGROW>
            end
            xFake = (25:50:575)';
            pks = [pks; xFake, testCase.grooveY(xFake, 0) - testCase.GROOVE_PITCH/2];
        end

        function y = parallelY(~, x, g)
            % ゆらぎの無い平行な溝（2次式）。1本目（g=0）で補正すると中心は -27.4g になる
            % （g>=1 の中心をビンの端から離すため、間隔を 27.4px にする）
            y = 300 + 0.02*(x - 300) + 1e-4*(x - 300).^2 - 27.4*g;
        end

        function pks = parallelPoints(testCase, x)
            pks = zeros(0,2);
            for g = testCase.GROOVES
                pks = [pks; x, testCase.parallelY(x, g)]; %#ok<AGROW>
            end
        end
    end

    methods (Static, Access = private)

        function pc = cloud(width, cells)
            % 幅 width（元の画像の幅）の GroovePointCloud に、点群 cells を直接入れる
            pc = GroovePointCloud();
            pc.imgID = [1; 1];
            pc.width = width;
            pc.height = 600;
            pc.peakCells = cells;
        end

        function [pts, xc, yc] = cycleCells(numSeg, numCycles)
            % (numSeg x numCycles) の xcoords・ycoords（各セル3点、周ごとに違う値）と pts
            pts(numSeg,1) = GroovePointCloud();
            xc = cell(numSeg, numCycles);
            yc = cell(numSeg, numCycles);
            for j = 1:numCycles
                for k = 1:numSeg
                    xc{k,j} = (1:3)';
                    yc{k,j} = sin((1:3)' + k) + 10*j;
                end
            end
        end

        function [cond, allImg, pts] = minimalImages(saveDir, numImages, numSegments)
            % saveCycleResult に渡せる最小の画像・点群・実験条件（写真 numImages 枚 x numSegments）
            n = numImages*numSegments;
            allImg(n,1) = ImageData();
            pts(n,1) = GroovePointCloud();
            for k = 1:n
                img = 255*ones(10, 3);
                img(5,:) = 0;
                allImg(k) = ImageData(img, [ceil(k/numSegments); mod(k-1,numSegments)+1]);
                pts(k) = GroovePointCloud(DarknessMap(allImg(k)));
            end
            cond = cycleConditions(Upsampling="origD", Date="0101", ...
                SaveDir=saveDir, NumImages=numImages, NumSegments=numSegments, ...
                LMask=20, ThHist=NaN, DThresh=0.6, WTh=8, ...
                Tol=3, BinWidth=1, HPrl=NaN, PolyDegree=9, ...
                ScriptName="MultiGrooveAcceptanceTest");
        end
    end
end
