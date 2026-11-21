% issue #35（溝底区間の幅が広い溝底点による、正規化した振幅が1付近の外れ値）の受け入れテスト
%
% 自動追跡の3つのスクリプト（grooveTrack_1cycle.m・grooveHist_Ncycle.m・grooveTrack_Ncycle.m）の
% 本文から、溝底区間の幅の上限 WIDTH_THRESH の値を読み取り、その値で合成データの溝底点を
% スクリプトと同じループで検出し、そのスクリプトの溝の選び方（trackGroove、または
% extractMultiGroove の帯）まで通して、次の2つを確かめる
% （docs/issues/closed/35-wide-bottom-outliers/plan-2.md 6.1）。
%   - 溝底の線の片側に、暗さがしきい値すれすれの行がつながった幅5の区間を、溝底点にしない。
%     溝の選択ではその列の点を採らず、前後の列から補間する（直す前の値 8 では失敗する）
%   - 上下に1行ずつ広がった幅4の区間（重心はずれない）は、溝底点として残す
%     （幅の上限を下げすぎていないことの確認）
% 両方が通るのは、WIDTH_THRESH が 4 以上 5 未満のときだけである。
% スクリプトは実行しない（ginput と実データが要るため）。値を読むだけである。
% 値の読み取り（widthThreshOf）を検出から分けてあるのは、評価基準の段階で、スクリプトを
% 変えずに別の値（3・4・5）を渡して試すため（criteria.md 3.3）。
% 評価担当が作成した。実装担当は変更しない（docs/rules/evaluation.md）。
%
% 合成データ（plan-2.md 6.1、付録 B.5）：高さ100・幅200。暗さ D の画素の値は 255*(1-D)
% （DarknessMap は暗さを 1 - 画素値/255 にするため）。背景の暗さ 0.45、溝は y = 20・45・70・95 の
% 4本で、中心の行と上下1行を暗さ 0.73 にする（区間の幅2、重心は中心の行）。y = 45 の溝の
% 列100〜103 だけ中心より下の3行（y = 47〜49）を、列150〜153 だけ y = 43 と y = 47 を、
% 暗さ 0.62（しきい値 0.6 をわずかに上回る）にする。
classdef WideBottomOutlierAcceptanceTest < matlab.unittest.TestCase

    properties (TestParameter)
        % 確かめるスクリプトと、その溝の選び方
        Script = struct( ...
            "grooveTrack_1cycle", struct("file","grooveTrack_1cycle.m","selection","track"), ...
            "grooveHist_Ncycle",  struct("file","grooveHist_Ncycle.m","selection","hist"), ...
            "grooveTrack_Ncycle", struct("file","grooveTrack_Ncycle.m","selection","track"))
    end

    properties (Constant)
        D_THRESH     = 0.6           % 暗さのしきい値（3つのスクリプトと同じ）
        IMG_HEIGHT   = 100
        IMG_WIDTH    = 200
        D_BACKGROUND = 0.45          % 溝と溝の間の暗さ
        D_GROOVE     = 0.73          % 溝底の線の暗さ
        D_SHOULDER   = 0.62          % しきい値すれすれの薄暗い行の暗さ
        GROOVES      = [20 45 70 95] % 溝の中心の y [px]
        TARGET_Y     = 45            % 確かめる溝の中心の y [px]
        WIDE_COLS    = 100:103       % 片側だけ広がった列（区間 y = 44〜49、幅5。重心は約 46.38）
        WIDTH4_COLS  = 150:153       % 上下に1行ずつ広がった列（区間 y = 43〜47、幅4。重心は 45）
        NEAR_TOL     = 3             % 「その溝の点」とみなす y の範囲 [px]（帯の BAND_TOL と同じ）
    end

    methods (TestClassSetup)
        function addToPath(testCase)
            import matlab.unittest.fixtures.PathFixture
            thisDir = fileparts(mfilename('fullpath'));
            srcDir  = fullfile(thisDir, '..', '..', 'src');
            testCase.applyFixture(PathFixture(srcDir));
        end
    end

    %% 溝底点の検出
    methods (Test)

        function testWideOneSidedIntervalIsNotDetected(testCase, Script)
            % 片側に広がった幅5の区間（列100〜103）から、y = 45 ± 3 の溝底点を作らない
            % （重心法・局所的最大値法とも。スクリプトは両方に同じ WIDTH_THRESH を使う）
            w = testCase.widthThreshOf(Script.file);
            [pksCnt, ~, pksMax] = testCase.detectPoints(w);

            cols = testCase.WIDE_COLS;
            nearCnt = testCase.pointsNear(pksCnt, cols);
            nearMax = testCase.pointsNear(pksMax, cols);
            testCase.verifyEmpty(nearCnt, testCase.describe(Script.file, w, ...
                "幅5の区間（片側に薄暗い行がつながったもの）を溝底点にしている（重心法）", nearCnt));
            testCase.verifyEmpty(nearMax, testCase.describe(Script.file, w, ...
                "幅5の区間（片側に薄暗い行がつながったもの）を溝底点にしている（局所的最大値法）", nearMax));
        end

        function testWidth4IntervalIsKept(testCase, Script)
            % 上下に1行ずつ広がった幅4の区間（列150〜153）は、y = 45 の溝底点として残す
            w = testCase.widthThreshOf(Script.file);
            pksCnt = testCase.detectPoints(w);

            cols = testCase.WIDTH4_COLS;
            near = testCase.pointsNear(pksCnt, cols);
            hasPoint = arrayfun(@(c) any(near(:,1) == c & abs(near(:,2) - testCase.TARGET_Y) <= 0.01), cols);
            testCase.verifyTrue(all(hasPoint), testCase.describe(Script.file, w, ...
                sprintf("幅4の区間を溝底点にしていない列がある（列 %s。WIDTH_THRESH が小さすぎる）", ...
                mat2str(cols(~hasPoint))), near));
        end
    end

    %% 溝の選択（スクリプトの選び方まで通す）
    methods (Test)

        function testSelectionInterpolatesOverWideInterval(testCase, Script)
            % 列100〜103 では点を採らず（found が false）、前後の列から補間した y が 45 から 0.1 px 以内
            w = testCase.widthThreshOf(Script.file);
            [y, found] = testCase.selectTarget(Script.selection, w);

            cols = testCase.WIDE_COLS;
            sel = [cols(:), y(cols)];
            testCase.verifyFalse(any(found(cols)), testCase.describe(Script.file, w, ...
                sprintf("溝の選択（%s）が、幅5の区間の点を採っている（列 %s）", ...
                Script.selection, mat2str(cols(found(cols)))), sel));
            testCase.verifyLessThanOrEqual(abs(y(cols) - testCase.TARGET_Y), 0.1, ...
                testCase.describe(Script.file, w, ...
                "溝の選択（" + Script.selection + "）の y が溝底の線（y = 45）からずれている", sel));
        end

        function testSelectionKeepsWidth4Interval(testCase, Script)
            % 列150〜153 では点を採り（found が true）、y が 45 から 0.01 px 以内
            w = testCase.widthThreshOf(Script.file);
            [y, found] = testCase.selectTarget(Script.selection, w);

            cols = testCase.WIDTH4_COLS;
            sel = [cols(:), y(cols)];
            testCase.verifyTrue(all(found(cols)), testCase.describe(Script.file, w, ...
                sprintf("溝の選択（%s）が、幅4の区間の点を採っていない（列 %s）", ...
                Script.selection, mat2str(cols(~found(cols)))), sel));
            testCase.verifyEqual(y(cols), testCase.TARGET_Y*ones(numel(cols),1), "AbsTol", 0.01, ...
                testCase.describe(Script.file, w, ...
                "溝の選択（" + Script.selection + "）の y が溝底の線（y = 45）からずれている", sel));
        end

        function testSelectionElsewhereIsOnTheGroove(testCase, Script)
            % 合成データの確認：上の2か所を除く列では、溝底の線（y = 45）の点を採る
            w = testCase.widthThreshOf(Script.file);
            [y, found] = testCase.selectTarget(Script.selection, w);

            other = setdiff(1:testCase.IMG_WIDTH, [testCase.WIDE_COLS testCase.WIDTH4_COLS]);
            testCase.verifyTrue(all(found(other)), testCase.describe(Script.file, w, ...
                sprintf("溝の選択（%s）が点を採らなかった列がある（%d列）", ...
                Script.selection, nnz(~found(other))), zeros(0,2)));
            testCase.verifyEqual(y(other), testCase.TARGET_Y*ones(numel(other),1), "AbsTol", 1e-9);
        end
    end

    %% スクリプトの値の読み取り（評価基準の段階の試行で、別の値に置き換えられるようにしてある）
    methods (Access = protected)

        function w = widthThreshOf(testCase, scriptFile)
            % スクリプトの本文で、行の頭にある「WIDTH_THRESH = <数>;」の代入を読む。
            % cycleConditions(...,WTh=WIDTH_THRESH,...) の行は読まない。
            % パスはこのファイルの場所から作る（CI は Linux で、大文字・小文字を区別する）
            scriptPath = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'scripts', scriptFile);
            testCase.assertTrue(isfile(scriptPath), "スクリプトがありません：" + scriptPath);
            txt = fileread(scriptPath);
            tok = regexp(txt, '^\s*WIDTH_THRESH\s*=\s*([0-9.]+)\s*;', 'tokens', 'lineanchors');
            testCase.assertNumElements(tok, 1, sprintf( ...
                "%s：行の頭にある WIDTH_THRESH の代入が %d 個あります（1個のはず）。", scriptFile, numel(tok)));
            w = str2double(tok{1}{1});
            testCase.assertTrue(isfinite(w) && w > 0, ...
                sprintf("%s：WIDTH_THRESH の値（%s）を数として読めません。", scriptFile, tok{1}{1}));
        end
    end

    %% 合成データと、スクリプトと同じ処理
    methods (Access = protected)

        function img = syntheticImage(testCase)
            % 画素値の画像（double）。暗さ D の画素は 255*(1-D)
            toPixel = @(d) 255*(1 - d);
            img = toPixel(testCase.D_BACKGROUND) * ones(testCase.IMG_HEIGHT, testCase.IMG_WIDTH);
            for c = testCase.GROOVES
                img(c-1:c+1, :) = toPixel(testCase.D_GROOVE);
            end
            t = testCase.TARGET_Y;
            img(t+2:t+4, testCase.WIDE_COLS) = toPixel(testCase.D_SHOULDER);     % 下側だけ（幅5）
            img([t-2 t+2], testCase.WIDTH4_COLS) = toPixel(testCase.D_SHOULDER); % 上下に1行ずつ（幅4）
        end

        function [pksCnt, xQuery, pksMax] = detectPoints(testCase, widthThresh)
            % 3つのスクリプトの検出のループ（grooveHist_Ncycle.m の L128–145 など）と同じ処理で、
            % 重心法と局所的最大値法の溝底点を求め、mergeSegmentPoints で [x y] にする
            origImg = ImageData(testCase.syntheticImage(), [1;1]);
            origD = DarknessMap(origImg);
            origD = origD.setDiffTF(testCase.D_THRESH);

            pts_cnt = GroovePointCloud(origD);
            pts_max = GroovePointCloud(origD);

            extractor = GrooveExtractor(origD);
            for x = 1:origImg.width
                [firstIdx, lastIdx] = extractor.findThresholdIntervals(origD, x);
                [extractor,~,~,numPeaks] = ...
                    extractor.findGrooveBottomIntervals(origD,x,firstIdx,lastIdx,widthThresh);

                centroidY = extractor.extractByCentroid(origD,x);
                maxY = extractor.extractByLocalMax(origD,x);

                pts_cnt.peakCells{x} = [x*ones(numPeaks,1), centroidY];
                pts_max.peakCells{x} = [x*ones(numPeaks,1), maxY];
            end
            [pksCnt, xQuery] = mergeSegmentPoints(pts_cnt);
            pksMax = mergeSegmentPoints(pts_max);
        end

        function [y, found] = selectTarget(testCase, selection, widthThresh)
            % 重心法の点で、スクリプトの選び方により y = 45 の溝を選び、デトレンド前の y と、
            % 点を採れた列を返す。
            %   track：trackGroove（grooveTrack_1cycle.m・grooveTrack_Ncycle.m）。始点は [1 45]
            %   hist ：extractMultiGroove（grooveHist_Ncycle.m）の2本目。1本目は y = 70 の溝で、
            %          そこから y の小さい側の隣が y = 45 の溝（y = 95 の溝は、1本目の山が
            %          ヒストグラムの端のビンにならないように置いている）
            % trackGroove・extractMultiGroove の引数は既定値（スクリプトの値と同じ）
            [pks, xQuery] = testCase.detectPoints(widthThresh);
            if selection == "track"
                [points, found] = trackGroove(pks, [1 testCase.TARGET_Y], xQuery);
                y = points(:,2);
            else
                [~, info] = extractMultiGroove(pks, [1 testCase.GROOVES(3)], xQuery, 2, PolyDegree=1);
                y = info.yAbs(:,2);
                found = info.found(:,2);
            end
        end

        function near = pointsNear(testCase, pks, cols)
            % 列 cols にある、y = 45 ± NEAR_TOL の点 [x y]
            near = pks(ismember(pks(:,1), cols) & abs(pks(:,2) - testCase.TARGET_Y) <= testCase.NEAR_TOL, :);
        end
    end

    methods (Static, Access = protected)

        function msg = describe(scriptFile, w, what, pts)
            % 失敗したときの説明：スクリプト、読み取った値、何がおかしいか、列ごとの y
            msg = sprintf("%s（WIDTH_THRESH = %g）：%s。", scriptFile, w, what);
            if ~isempty(pts)
                msg = msg + " 列と y [px]：" + strjoin(compose("列%d y=%.2f", pts(:,1), pts(:,2)), "、");
            end
        end
    end
end
