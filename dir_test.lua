
local Object = require "lib.object.Object"


local dir_ut = require "lib.dir_utilities"

local Test = Object:subclass()



function Test:init(t)
	
end


function Test:build(d)

    local list = dir_ut.listFolders("lib/tilt_ships")
    print("THE LIST",list)
   
end


return Test
