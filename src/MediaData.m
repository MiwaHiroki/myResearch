% 2026/06/03作成

classdef (Abstract) MediaData < handle
    properties
        Name (1,1) string
    end

    methods
        function data = MediaData(name)
            data.Name = name;
        end
    end

    methods(Abstract)
        save(data,dir)
    end
end