
local Object = require "lib.test"

local Test = Object:subclass()




function Test:getCases()
   -- print("i am test1")
    return {
        ["a"]=function()print("test1")end,
        ["a1"]=function()print("test1")end,
    }
end
return Test


