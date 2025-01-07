
local Object = require "lib.object.Object"
local Rec = require "lib.utilities_recursive"
local Test = require "lib.test_3"

local Pepe = Object:subclass()



function Pepe:init()
	
end


function Pepe:build(d)
    local a = Test()

   --return Rec.rec_get_cases_custum("getCases",self,Test,{conservedOld=true,protected_cases={}})
   
   return Rec.rec_switch_custum("b",{},"getCases",a,{conservedOld=true,protected_cases={},defaultFunc={}})
end


return Pepe
