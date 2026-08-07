% テスト専用の具象サブクラス
% 抽象クラス MediaData を単体テストするために用いる最小の実装
classdef ConcreteMediaData < MediaData
    properties
        SaveWasCalled (1,1) logical = false
        SaveDir (1,1) string = ""
    end

    methods
        function data = ConcreteMediaData(name)
            data@MediaData(name);
        end

        function save(data, dir)
            % 抽象メソッド save の最小実装（呼び出しを記録するだけ）
            data.SaveWasCalled = true;
            data.SaveDir = dir;
        end
    end
end
