function results = runAllTests()
% src 以下の各クラスの単体テストをまとめて実行する。
%
% 使い方（プロジェクトルート または test/ から）:
%   results = runAllTests;
%
% test/unit/ 以下のテストクラス（*Test.m）を検出して実行する。
% 各テストクラスは自身の TestClassSetup で src/ をパスに追加するため、
% 事前に addpath する必要はない。

    thisDir  = fileparts(mfilename('fullpath'));
    unitDir  = fullfile(thisDir, 'unit');

    suite   = matlab.unittest.TestSuite.fromFolder(unitDir);
    results = run(suite);

    disp(table(results));
end
