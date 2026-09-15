% ImageData -> omitMask -> DarknessMap -> dResample -> GrooveExtractor
% -> GroovePointCloud -> fitGroove -> extractGrooveWaveform を、合成データで
% 一気通貫に確認する統合テスト。各クラス単体のテストでは検出できない
% 「クラス間の繋ぎ目」の破壊（引数の順序変更・返り値の形の変更など）を狙う。
% 実データは使わないため高速・移植可能で、他の単体テストと同様runAllTestsで拾われる。
classdef GroovePipelineTest < matlab.unittest.TestCase

    properties (Constant)
        Width = 60
        Height = 61
        Base = 30      % 溝底の基準の高さ(行)
        Amp = 4        % 波打ち(=音の波形)の振幅(px)。実際の音溝の揺れと同程度の大きさにする
        Period = 20    % 波打ちの周期(列)
        BandHalfWidth = 2
        PRsmpl = 4
        QRsmpl = 1
        DThresh = 0.6
        WidthThresh = 8
        BinWidth = 2
        MinPeakHeight = 3
        Tolerance = 6
        PolyDegree = 3
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
        function testWavyGrooveBottomIsRecovered(testCase)
            % 溝底が波打っている(=音の波形そのもの)場合でも、
            % パイプライン全体を通して元の形を復元できることを確認する
            [centerRow, img] = testCase.buildSyntheticGrooveImage();
            [pointsFit, ~] = testCase.runPipeline(img, centerRow);
            expected = detrendGrooveShape([(1:testCase.Width)', centerRow], PolyDegree=testCase.PolyDegree);

            testCase.verifyEqual(size(pointsFit,1), testCase.Width);
            testCase.verifyFalse(any(isnan(pointsFit(:,2))));
            testCase.verifyEqual(pointsFit(:,2), expected(:,2), 'AbsTol', 2, ...
                "波打つ溝底の形状が復元できていない");
        end

        function testDustGapIsInterpolated(testCase)
            % 溝底にホコリ(10x10px程度の非常に明るい部分)があり、
            % その区間で溝候補点が全く取れない場合でも、
            % fillmissingによって欠損区間が正しく補間されることを確認する
            dustCols = 26:35; % 10列分（波打ちの単調な区間に配置）
            [centerRow, img] = testCase.buildSyntheticGrooveImage();
            img(:, dustCols) = 255; % ホコリ: 音溝ごと明るく塗りつぶし候補点を消す

            [pointsFit, numPeaks] = testCase.runPipeline(img, centerRow);
            expected = detrendGrooveShape([(1:testCase.Width)', centerRow], PolyDegree=testCase.PolyDegree);

            testCase.verifyEqual(numPeaks(dustCols), zeros(1,numel(dustCols)), ...
                "ホコリの列では候補点が0件になるはず");
            testCase.verifyEqual(size(pointsFit,1), testCase.Width);
            testCase.verifyFalse(any(isnan(pointsFit(:,2))), ...
                "ホコリ区間がfillmissingで補間されずNaNのまま残っている");

            nonDustCols = setdiff(1:testCase.Width, dustCols);
            testCase.verifyEqual(pointsFit(nonDustCols,2), expected(nonDustCols,2), 'AbsTol', 2, ...
                "ホコリの影響が無い列まで乱れている");
            testCase.verifyEqual(pointsFit(dustCols,2), expected(dustCols,2), 'AbsTol', 3, ...
                "ホコリ区間の補間値が元の溝形状から大きく外れている");
        end
    end

    methods (Access = private)
        function [centerRow, img] = buildSyntheticGrooveImage(testCase)
            x = (1:testCase.Width)';
            centerRow = round(testCase.Base + testCase.Amp*sin(2*pi*x/testCase.Period));
            img = uint8(255*ones(testCase.Height, testCase.Width));
            for xi = 1:testCase.Width
                r0 = max(1, centerRow(xi)-testCase.BandHalfWidth);
                r1 = min(testCase.Height, centerRow(xi)+testCase.BandHalfWidth);
                img(r0:r1, xi) = 50; % 溝底(暗い)
            end
        end

        function [pointsFit, numPeaks] = runPipeline(testCase, img, centerRow)
            [imgMasked, ~] = omitMask(img, 20);
            origImg = ImageData(imgMasked, [1;1]);

            origD = DarknessMap(origImg);
            origD = origD.setDiffTF(testCase.DThresh);
            rsmplD = dResample(origD, testCase.PRsmpl, testCase.QRsmpl);
            rsmplD = rsmplD.setDiffTF(testCase.DThresh);

            extractor = GrooveExtractor(rsmplD);
            pts = GroovePointCloud(rsmplD);
            numPeaks = zeros(1, testCase.Width);
            for xi = 1:testCase.Width
                [firstIdx,lastIdx] = extractor.findThresholdIntervals(rsmplD,xi);
                [extractor,~,~,n] = extractor.findGrooveBottomIntervals( ...
                    rsmplD,xi,firstIdx,lastIdx,testCase.WidthThresh);
                numPeaks(xi) = n;
                centroidY = extractor.extractByCentroid(rsmplD,xi);
                pts.peakCells{xi} = [xi*ones(n,1), centroidY];
            end
            pks = vertcat(pts.peakCells{:});

            x = (1:testCase.Width)';
            P1 = [1, centerRow(1)];
            P2 = [testCase.Width, centerRow(end)];
            [p1,~,pksCorCell] = fitGroove(1,[],[0,0],testCase.Width,20,{pks}, P1=P1, P2=P2);

            pointsFit = extractGrooveWaveform(pksCorCell{1}, p1(2), x, ...
                BinWidth=testCase.BinWidth, MinPeakHeight=testCase.MinPeakHeight, ...
                Tolerance=testCase.Tolerance, PolyDegree=testCase.PolyDegree);
        end
    end
end
