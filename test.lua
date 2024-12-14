
local Object = require "lib.object.Object"
local Rec = require "lib.utilities_recursive"

local Test = Object:subclass()


function Test:getCases()
    --print("i am base")
    return {
        ["a"]=function()print("base")end,
        ["b"]=function()print("base")end,
        ["c"]=function()print("base")end,
        ["d"]=function()print("base")end,
        ["default"]=function()print("baseDefault")end,
        ["hey"]=function()print("baseDefault")end,
    }
end

function Test:init(t)
	
end


function Test:build(d)


   --return Rec.rec_get_cases_custum("getCases",self,Test,{conservedOld=true,protected_cases={}})
   
   return Rec.rec_switch_custum("ljfljdfkljadslk",{},"getCases",self,Test,{conservedOld=true,protected_cases={},defaultFunc={}})
end


return Test
