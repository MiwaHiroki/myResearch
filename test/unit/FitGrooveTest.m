% fitGroove の単体テスト
% P1/P2 を両方指定すると ginput を呼ばずに済むため、この経路のみ自動テストできる
classdef FitGrooveTest < matlab.unittest.TestCase

    properties
        fig
        % 傾き10/9、切片5の直線上の点（10列分）
        pksA
        % 傾き10/9、切片2の直線上の点（pksAと平行に3だけ下にずらした）
        pksB
    end

    methods (TestClassSetup)
        function addToPath(testCase)
            import matlab.unittest.fixtures.PathFixture
            thisDir = fileparts(mfilename('fullpath'));
            srcDir  = fullfile(thisDir, '..', '..', 'src');
            testCase.applyFixture(PathFixture(srcDir));
        end
    end

    methods (TestMethodSetup)
        function buildPeakData(testCase)
            x = (1:10)';
            testCase.pksA = [x, 5 + (10/9)*(x-1)];
            testCase.pksB = [x, 2 + (10/9)*(x-1)];
        end

        function openHiddenFigure(testCase)
            testCase.fig = figure('Visible', 'off');
            testCase.addTeardown(@() closeIfValid(testCase.fig));
        end
    end

    methods (Test)
        function testAutoSelectSingleDatasetRemovesSlope(testCase)
            % P1,P2を両方渡すとginputを呼ばず、直線に沿って傾きを除去する
            [p1,p2,pksCorCell] = fitGroove(1,testCase.fig,[0,0],10,10, ...
                {testCase.pksA}, P1=[1,5], P2=[10,15]);

            testCase.verifyEqual(p1, [1,5]);
            testCase.verifyEqual(p2, [10,15]);
            testCase.verifyNumElements(pksCorCell, 1);

            pksCor = pksCorCell{1};
            testCase.verifyEqual(pksCor(:,1), testCase.pksA(:,1));
            % 直線上の点はすべてpolyfitのx=0における切片(5-10/9)に揃うはず
            testCase.verifyEqual(pksCor(:,2), (5-10/9)*ones(10,1), 'AbsTol', 1e-9);
        end

        function testAutoSelectFitsEachDatasetIndependently(testCase)
            % 同じ平行四辺形で選んだ点を使いつつ、各データセットは別々に近似する
            [~,~,pksCorCell] = fitGroove(1,testCase.fig,[0,0],10,10, ...
                {testCase.pksA, testCase.pksB}, P1=[1,5], P2=[10,15]);

            testCase.verifyNumElements(pksCorCell, 2);
            testCase.verifyEqual(pksCorCell{1}(:,2), (5-10/9)*ones(10,1), 'AbsTol', 1e-9);
            testCase.verifyEqual(pksCorCell{2}(:,2), (2-10/9)*ones(10,1), 'AbsTol', 1e-9);
        end

        function testP1OverrideSkipsGinputEvenOnFirstSegment(testCase)
            % jSegment==1でも、P1が渡されていればginputを呼ばずP1を使う
            [p1,~,~] = fitGroove(1,testCase.fig,[0,0],10,10, ...
                {testCase.pksA}, P1=[1,5], P2=[10,15]);
            testCase.verifyEqual(p1, [1,5]);
        end

        function testP1CarriesOverFromPreviousP2WhenNotOverridden(testCase)
            % P1を渡さずjSegment>1なら、引数のp2をp1として使う（従来の挙動）
            prevP2 = [1,5];
            [p1,p2,pksCorCell] = fitGroove(2,testCase.fig,prevP2,10,10, ...
                {testCase.pksA}, P2=[10,15]);

            testCase.verifyEqual(p1, prevP2);
            testCase.verifyEqual(p2, [10,15]);
            testCase.verifyEqual(pksCorCell{1}(:,2), (5-10/9)*ones(10,1), 'AbsTol', 1e-9);
        end

        function testAcceptsColumnVectorP2(testCase)
            % p2は縦ベクトル([x;y])で渡す既存の呼び出し方も許容する
            [p1,p2,pksCorCell] = fitGroove(1,testCase.fig,[0;0],10,10, ...
                {testCase.pksA}, P1=[1,5], P2=[10,15]);

            testCase.verifyEqual(p1, [1,5]);
            testCase.verifyEqual(p2, [10,15]);
            testCase.verifyEqual(pksCorCell{1}(:,2), (5-10/9)*ones(10,1), 'AbsTol', 1e-9);
        end

        function testAutoSelectAcceptsEmptyFig(testCase)
            % P1,P2両方指定ならfigが[]でもエラーにならない
            [p1,p2,pksCorCell] = fitGroove(1,[],[0,0],10,10, ...
                {testCase.pksA}, P1=[1,5], P2=[10,15]);

            testCase.verifyEqual(p1, [1,5]);
            testCase.verifyEqual(p2, [10,15]);
            testCase.verifyEqual(pksCorCell{1}(:,2), (5-10/9)*ones(10,1), 'AbsTol', 1e-9);
        end

        function testAutoSelectDoesNotCreateFigure(testCase)
            % P1,P2両方指定のときは新しいfigureを作らない
            figCountBefore = numel(findall(0,'Type','figure'));

            fitGroove(1,[],[0,0],10,10,{testCase.pksA}, P1=[1,5], P2=[10,15]);

            figCountAfter = numel(findall(0,'Type','figure'));
            testCase.verifyEqual(figCountAfter, figCountBefore);
        end

        function testErrorsWhenNoPointsInsideParallelogram(testCase)
            farAwayPks = [(1:10)', 1000*ones(10,1)];
            testCase.verifyError(@() fitGroove(1,testCase.fig,[0,0],10,10, ...
                {farAwayPks}, P1=[1,5], P2=[10,15]), ...
                "fitGroove:emptySelection");
        end
    end
end

% --- ローカル関数 -------------------------------------------------------
function closeIfValid(fig)
    if isvalid(fig)
        close(fig);
    end
end
