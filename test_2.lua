

local Object = require "lib.test_1"

local Test = Object:subclass()

function Test:my_local()
    print("my_local_isworking_test_2")
end


function Test:getCases()
    print("i am test2")
    return {
        ["b"]=function()self:my_local() end,
        ["b2"]=function()print("test2")end,
        ["default"]=function()print("test2")end,
    }
end
return Test