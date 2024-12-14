

local Object = require "lib.test_1"

local Test = Object:subclass()




function Test:getCases()
   -- print("i am test2")
    return {
        ["b"]=function()print("test2")end,
        ["b2"]=function()print("test2")end,
        ["default"]=function()print("test2")end,
    }
end
return Test