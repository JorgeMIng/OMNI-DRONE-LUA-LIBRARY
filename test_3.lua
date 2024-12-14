
local Object = require "lib.test_2"
local Test = Object:subclass()




function Test:getCases()
    --print("i am test3")
    return {
        ["c"]=function()print("test3")end,
        ["c3"]=function()print("test3")end,

    }
end




return Test