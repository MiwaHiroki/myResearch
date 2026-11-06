% extractMultiGroove の単体テスト
% （受け入れテスト MultiGrooveAcceptanceTest で見ていない細部を確かめる）
%
% 合成データ（plan.md 6章）：x = 1..N_COLS、曲がった溝 base に、溝 g ごとに違う「音」と
% 1px 以下の平行でなさを足したもの。g = -1（クリックする溝の外側）〜5。溝0と溝1の間に、
% 50列ごとに偽の点を足す。
classdef ExtractMultiGrooveTest < matlab.unittest.TestCase

    properties (Constant)
        N_COLS  = 600
        GROOVES = -1:5
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

        function testShapesMatchDetrendedTruth(testCase)
            x = (1:testCase.N_COLS)';
            seed = [1, testCase.y(1, 0) + 1];

            shapes = extractMultiGroove(testCase.points(x), seed, x, 4);

            for j = 1:4
                expected = detrendTrackedShape([x, testCase.y(x, j-1)]);
                testCase.verifyEqual(shapes{j}, expected, "AbsTol", 1e-9);
            end
            % 2本目は溝1（y の小さい側）
            testCase.verifyLessThan(mean(testCase.y(x, 1)), mean(testCase.y(x, 0)));
        end

        function testHistInfoIsFromFindGrooveCenters(testCase)
            % info.hist は補正後の点群に findGrooveCenters をかけた info と同じ
            x = (1:testCase.N_COLS)';
            pks = testCase.points(x);
            seed = [1, testCase.y(1, 0) + 1];

            [~, info] = extractMultiGroove(pks, seed, x, 3);

            pksCor = [pks(:,1), pks(:,2) - polyval(info.trend.p, pks(:,1), info.trend.S, info.trend.mu)];
            [centers, hist] = findGrooveCenters(pksCor, 3, BinWidth=1, MinPeakHeight=0.3*numel(x));
            testCase.verifyEqual(info.centers, centers);
            testCase.verifyEqual(info.hist, hist);
            testCase.verifyEqual(info.hist.peakCenters(info.hist.firstIdx), info.centers(1));
        end

        function testFirstGrooveGapDoesNotAffectInnerGrooves(testCase)
            % 1本目の x=300〜310 の点を消す → found(:,1) のその列だけ false、2本目以降は全列 true
            x = (1:testCase.N_COLS)';
            gapX = (300:310)';
            seed = [1, testCase.y(1, 0) + 1];

            [~, info] = extractMultiGroove(testCase.points(x, RemoveX=gapX, RemoveFrom=0), seed, x, 3);

            isGap = ismember(x, gapX);
            testCase.verifyFalse(any(info.found(isGap,1)));
            testCase.verifyTrue(all(info.found(~isGap,1)));
            testCase.verifyTrue(all(info.found(:,2:3), "all"));
            testCase.verifyEqual(info.yAbs(:,3), testCase.y(x, 2), "AbsTol", 1e-9);
        end

        function testDuplicateInInnerBandIsCounted(testCase)
            % 溝2（3本目）の x=400 に、溝から 1.2px の点を足す → 溝の点を採り、2点の列を数える
            x = (1:testCase.N_COLS)';
            pks = [testCase.points(x); 400, testCase.y(400, 2) + 1.2];
            seed = [1, testCase.y(1, 0) + 1];

            [~, info] = extractMultiGroove(pks, seed, x, 4);

            testCase.verifyEqual(info.numDuplicateCols, [0 0 1 0]);
            testCase.verifyEqual(info.yAbs(400,3), testCase.y(400, 2), "AbsTol", 1e-9);
        end

        function testSingleGrooveSkipsHistogram(testCase)
            % numGrooves=1 ならヒストグラムを作らないので、他の溝が無くてもエラーにならない
            x = (1:testCase.N_COLS)';
            pks = [x, testCase.y(x, 0)];
            seed = [1, testCase.y(1, 0)];

            [shapes, info] = extractMultiGroove(pks, seed, x, 1);

            testCase.verifyEqual(shapes{1}, detrendTrackedShape(pks), "AbsTol", 1e-9);
            testCase.verifyEmpty(info.hist);
            testCase.verifyEmpty(info.centers);
            testCase.verifyEqual(info.numDuplicateCols, 0);
            testCase.verifyEqual(info.yAbs, pks(:,2));
            testCase.verifyEqual(info.found, true(numel(x),1));
        end

        function testFractionalGridMatchesIntegerGrid(testCase)
            % xQuery = (1:0.25:600)' でも、整数の x での yAbs が xQuery = (1:600)' と一致する
            xInt = (1:testCase.N_COLS)';
            xFrac = (1:0.25:testCase.N_COLS)';
            seed = [1, testCase.y(1, 0) + 1];

            [~, infoInt] = extractMultiGroove(testCase.points(xInt), seed, xInt, 4);
            [~, infoFrac] = extractMultiGroove(testCase.points(xFrac), seed, xFrac, 4);

            testCase.verifyEqual(infoFrac.yAbs(ismember(xFrac, xInt),:), infoInt.yAbs, "AbsTol", 1e-9);
            testCase.verifyEqual(infoFrac.minPeakHeight, 0.3*numel(xFrac), "AbsTol", 1e-9);
            testCase.verifyLessThanOrEqual(abs(infoFrac.centers - infoInt.centers), 1 + 1e-9);
        end

        function testBinWidthIsForwarded(testCase)
            % BinWidth=2 なら山の中心は 2px のビンの中心（奇数）になる
            x = (1:testCase.N_COLS)';
            seed = [1, testCase.y(1, 0) + 1];

            [~, info] = extractMultiGroove(testCase.points(x), seed, x, 3, BinWidth=2);

            testCase.verifyEqual(mod(info.centers, 2), ones(3,1), "AbsTol", 1e-12);
            testCase.verifyEqual(info.hist.binCenters(2) - info.hist.binCenters(1), 2, "AbsTol", 1e-12);
        end

        function testTooManyGroovesErrors(testCase)
            % 溝が 1本目を含めて6本しかない → 8本は notEnoughPeaks
            x = (1:testCase.N_COLS)';
            seed = [1, testCase.y(1, 0) + 1];

            testCase.verifyError(@() extractMultiGroove(testCase.points(x), seed, x, 8), ...
                "findGrooveCenters:notEnoughPeaks");
        end
    end

    methods (Access = private)

        function yy = y(~, x, g)
            % 溝 g の真の y
            base = 300 + 0.02*(x - 300) + 1e-4*(x - 300).^2;
            yy = base - 27*g + 0.4*sin(2*pi*x/(37 + 5*g)) + 5e-4*g*(x - 300);
        end

        function pks = points(testCase, x, opts)
            % 全部の溝の点＋溝0と溝1の間の偽の点。RemoveFrom の溝から RemoveX の列の点を消す
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
                pks = [pks; x(keep), testCase.y(x(keep), g)]; %#ok<AGROW>
            end
            xFake = (25:50:575)';
            pks = [pks; xFake, testCase.y(xFake, 0) - 13.5];
        end
    end
end
