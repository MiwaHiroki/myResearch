% trackingSeeds の単体テスト
% （受け入れテスト GrooveTrackingAcceptanceTest で見ていない細部を確かめる）
classdef TrackingSeedsTest < matlab.unittest.TestCase

    methods (TestClassSetup)
        function addToPath(testCase)
            import matlab.unittest.fixtures.PathFixture
            thisDir = fileparts(mfilename('fullpath'));
            srcDir  = fullfile(thisDir, '..', '..', 'src');
            testCase.applyFixture(PathFixture(srcDir));
        end
    end

    methods (Test)

        function testSeedsTakePriorityOverP1(testCase)
            % seeds と p1 の両方があれば seeds を返す
            seeds = [5 50; 6 60; 7 70];
            p1 = [(1:30)', (1:30)'];
            gs = struct('p1', p1, 'p2', p1, 'seeds', seeds);

            testCase.verifyEqual(trackingSeeds(gs, 10), seeds);
        end

        function testOldFormatWith80Rows(testCase)
            % 実データと同じ 80x2（8枚 x 10セグメント）→ 8x2
            p1 = [(1:80)', 200 + (1:80)'];
            gs = struct('p1', p1, 'p2', p1);

            seeds = trackingSeeds(gs, 10);

            testCase.verifySize(seeds, [8 2]);
            testCase.verifyEqual(seeds, p1(1:10:end, :));
        end

        function testP1RowsNotMultipleOfSegmentsErrors(testCase)
            gs = struct('p1', zeros(15,2), 'p2', zeros(15,2));
            testCase.verifyError(@() trackingSeeds(gs, 10), "trackingSeeds:noSelection");
        end

        function testStructWithoutFieldsErrors(testCase)
            testCase.verifyError(@() trackingSeeds(struct(), 10), "trackingSeeds:noSelection");
        end
    end
end
