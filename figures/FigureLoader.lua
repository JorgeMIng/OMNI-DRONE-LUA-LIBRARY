







local Object = require "lib.object.Object"

local expect = require "cc.expect"

local dir_util = require "lib.dir_utilities"


local FigureLoader = {}


function FigureLoader.load_figure(figure_type,figure_name_id,params)
    local files =dir_util.listFiles("lib/figures/figure_types",".lua")
    local found=false
    local idx=1
    local path =nil
    local figure = nil
    local require_path=nil
    
    while (not found and idx<=#files)do
        
        path = files[idx]
       
 
        if fs.exists(path) then
            require_path = path:match("^(.-)" .. ".lua" .. "$")
            require_path=require_path:gsub("/", ".")
            found = FigureLoader.check_figure_class(figure_type,require_path)
        end
        idx=idx+1
    end
    if not found then
        error(("Not found the figure type %s "):format(figure_type), 2)
        return nil
    end
    
    
    local figure_class = require(require_path)
    
    
    return figure_class(figure_name_id,params)
end




function FigureLoader.check_figure_class(figure_type,require_path) 
    local figure_class = nil
    
    if not require_path then
        return false
    else
        figure_class = require(require_path)
        return figure_class and figure_class.figure_type()==figure_type
    end
end




return FigureLoader
