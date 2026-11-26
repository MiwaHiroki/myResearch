% migrateResults（scripts/migration/。対応表で古い形の results/・experiments/ を移す）の単体テスト
%
% 一時フォルダをプロジェクトのルートに見立てて、合成した古い形のフォルダだけを移す。
% 外側から見た仕様（試し、移し終えたものを飛ばす、上書きしない）は ResultLayoutAcceptanceTest が
% 確かめるので、ここではパターンの解き方、対応表の読み方、数え方などの細部を確かめる。
classdef MigrateResultsTest < matlab.unittest.TestCase

    properties (Constant)
        HEADER = "phase,kind,source,destination,note"
    end

    properties
        root   % 一時フォルダ（プロジェクトのルートに見立てる）
    end

    methods (TestClassSetup)
        function addToPath(testCase)
            import matlab.unittest.fixtures.PathFixture
            thisDir = fileparts(mfilename('fullpath'));
            testCase.applyFixture(PathFixture(fullfile(thisDir, '..', '..', 'scripts', 'migration')));
        end
    end

    methods (TestMethodSetup)
        function makeRoot(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture = testCase.applyFixture(TemporaryFolderFixture);
            testCase.root = string(fixture.Folder);
        end
    end

    methods (Test)

        function testPatternIsCaseInsensitiveAndParenthesesAreLiteral(testCase)
            testCase.makeFiles(["results/1014/EVALTRACK_rmse.png", "results/1014/audio_x.wav", ...
                "results/1014/audio_(cnt)(original).wav"]);
            csv = testCase.writeCsv([
                "results,files,results/1014/evalTrack_*,results/grooveTracking/2026-1014_evaluation,"
                "results,files,results/1014/audio_(*)(original).wav,results/grooveTracking/2026-1014_manual,"
                "results,files,results/1014/audio_x.wav,results/grooveTracking/2026-1014_other,"]);
            actions = migrateResults(testCase.root, csv, Phase="results", DryRun=false);
            testCase.verifyEqual(actions.count', [1 1 1]);
            testCase.verifyTrue(isfile(testCase.absPath("results/grooveTracking/2026-1014_evaluation/EVALTRACK_rmse.png")));
            testCase.verifyTrue(isfile(testCase.absPath("results/grooveTracking/2026-1014_manual/audio_(cnt)(original).wav")));
            testCase.verifyTrue(isfile(testCase.absPath("results/grooveTracking/2026-1014_other/audio_x.wav")), ...
                "( ) をパターンの記号として扱い、audio_x.wav を前の行で移した");
        end

        function testOverlappingPatternsMoveEachFileOnce(testCase)
            % 前の行で移すことに決めたファイルは、後の行で数えない
            testCase.makeFiles(["results/1028/grooveTrackN_img1.png", "results/1028/grooveTrack_img1.png"]);
            csv = testCase.writeCsv([
                "results,files,results/1028/grooveTrackN_*,results/multiGroove/2026-1028_track5,"
                "results,files,results/1028/grooveTrack*,results/multiGroove/2026-1028_track,"
                "results,deleteEmpty,results/1028,,"]);
            actions = migrateResults(testCase.root, csv, Phase="results");
            testCase.verifyEqual(actions.count', [1 1 0]);
            testCase.verifyEqual(actions.status', ["move","move","delete"]);
        end

        function testDirCountIncludesSubfolders(testCase)
            testCase.makeFiles(["results/0820/bilateral/ori/a.png", "results/0820/bilateral/ori/sub/b.png"]);
            csv = testCase.writeCsv([
                "results,dir,results/0820/bilateral/ori,results/bilateralFilter/2026-0820_ori,"
                "results,deleteEmpty,results/0820,,入れ子の空のフォルダもまとめて消す"]);
            actions = migrateResults(testCase.root, csv, Phase="results", DryRun=false);
            testCase.verifyEqual(actions.count(1), 2);
            testCase.verifyTrue(isfile(testCase.absPath("results/bilateralFilter/2026-0820_ori/sub/b.png")));
            testCase.verifyFalse(isfolder(testCase.absPath("results/0820")), "空になった入れ子のフォルダが残っている");
        end

        function testFilesRowWithNothingAnywhereIsMissing(testCase)
            mkdir(testCase.absPath("results/1118"));
            csv = testCase.writeCsv("results,files,results/1118/waveform_*,results/grooveBottomDetection/2026-1118_evaluation,");
            actions = testCase.verifyWarning(@() migrateResults(testCase.root, csv, Phase="results"), ...
                "migrateResults:sourceMissing");
            testCase.verifyEqual(actions.status, "missing");
        end

        function testSameSourceOrDestinationTwice(testCase)
            % 同じ元を2行に書いたら、2行目では元が無いものとして扱う（2回移そうとしない）
            testCase.makeFiles("experiments/0731/b.mat");
            csv = testCase.writeCsv([
                "experiments,file,experiments/0731/b.mat,experiments/2026-0731/b.mat,"
                "experiments,file,experiments/0731/b.mat,experiments/2026-0731/c.mat,"]);
            actions = testCase.verifyWarning(@() migrateResults(testCase.root, csv, Phase="experiments"), ...
                "migrateResults:sourceMissing");
            testCase.verifyEqual(actions.status', ["move","missing"]);

            % 同じ行き先を2行に書いたら、上書きになるので止める
            testCase.makeFiles("experiments/0731/d.mat");
            csv2 = testCase.writeCsv([
                "experiments,file,experiments/0731/b.mat,experiments/2026-0731/x.mat,"
                "experiments,file,experiments/0731/d.mat,experiments/2026-0731/x.mat,"], "same.csv");
            testCase.verifyError(@() migrateResults(testCase.root, csv2, Phase="experiments", DryRun=false), ...
                "migrateResults:destinationExists");
            testCase.verifyTrue(isfile(testCase.absPath("experiments/0731/b.mat")), "エラーなのに動かした");
        end

        function testCsvWithBomQuotesAndOtherPhase(testCase)
            % BOM 付きの CSV、" で囲んだ列の中のカンマを読める。別の phase の行は扱わない
            testCase.makeFiles(["results/0721/PkDots(orig,rsmpl).fig", "experiments/0731/a.mat"]);
            lines = [testCase.HEADER
                "results,files,""results/0721/PkDots(orig,rsmpl).fig"",results/upsampling/2026-0721,""メモ, カンマ入り"""
                "experiments,file,experiments/0731/a.mat,experiments/2026-0731/a.mat,"];
            csv = fullfile(testCase.root, "bom.csv");
            fid = fopen(csv, "w", "n", "UTF-8");
            fwrite(fid, [239 187 191], "uint8");   % UTF-8 の BOM
            fwrite(fid, unicode2native(char(strjoin(lines, newline)), "UTF-8"), "uint8");
            fclose(fid);
            actions = migrateResults(testCase.root, csv, Phase="results", DryRun=false);
            testCase.verifyEqual(height(actions), 1);
            testCase.verifyEqual(actions.source, "results/0721/PkDots(orig,rsmpl).fig");
            testCase.verifyTrue(isfile(testCase.absPath("results/upsampling/2026-0721/PkDots(orig,rsmpl).fig")));
            testCase.verifyTrue(isfile(testCase.absPath("experiments/0731/a.mat")), "phase の違う行を動かした");
        end

        function testInvalidMappings(testCase)
            testCase.makeFiles("results/0721/a.png");
            bad = [
                "results,dir,../outside,results/upsampling/2026-0721,"            % ルートの外
                "results,dir,results/0721,experiments/2026-0721,"                 % phase と違う置き場所
                "results,dir,results/0721,,"                                      % 行き先が無い
                "results,dir,results/0721,results/upsampling/2026-0721"           % 列が足りない
                "photos,dir,results/0721,results/upsampling/2026-0721,"           % 知らない phase
                "results,dir,/results/0721,results/upsampling/2026-0721,"];       % 絶対パス
            for k = 1:numel(bad)
                csv = testCase.writeCsv(bad(k), "bad" + k + ".csv");
                testCase.verifyError(@() migrateResults(testCase.root, csv, Phase="results", DryRun=false), ...
                    "migrateResults:invalidMapping", "対応表の行：" + bad(k));
            end
            testCase.verifyError(@() migrateResults(testCase.root, fullfile(testCase.root, "none.csv"), ...
                Phase="results"), "migrateResults:invalidMapping");
            testCase.verifyTrue(isfile(testCase.absPath("results/0721/a.png")));
        end

        function testEmptyPhaseReturnsEmptyTable(testCase)
            csv = testCase.writeCsv("results,deleteEmpty,results/0710,,");
            actions = migrateResults(testCase.root, csv, Phase="experiments");
            testCase.verifyEqual(height(actions), 0);
            testCase.verifyEqual(string(actions.Properties.VariableNames), ...
                ["phase","kind","source","destination","status","count"]);
        end
    end

    methods (Access = private)
        function p = absPath(testCase, rel)
            p = testCase.root + filesep + replace(rel, "/", filesep);
        end

        function makeFiles(testCase, rels)
            for rel = rels
                p = testCase.absPath(rel);
                if ~isfolder(fileparts(p))
                    mkdir(fileparts(p));
                end
                writelines(rel, p, Encoding="UTF-8");
            end
        end

        function csv = writeCsv(testCase, rows, name)
            arguments
                testCase
                rows string
                name (1,1) string = "mapping.csv"
            end
            csv = fullfile(testCase.root, name);
            writelines([testCase.HEADER; rows(:)], csv, Encoding="UTF-8");
        end
    end
end
