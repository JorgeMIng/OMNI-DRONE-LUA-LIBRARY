



local Object = require "lib.object.Object"

local expect = require "cc.expect"


local DefaultFigure = Object:subclass()



--OVERRIDABLE--
function DefaultFigure:in_figure(pos)
    return false
end

function DefaultFigure:in_border_figure(pos)
    return false
end

-- static--
function DefaultFigure.figure_type()
    return "default"
end
-- static--
function DefaultFigure.params_to_check()
    return {{name="center_figure",gui_type="vector",type="table"}}

end





---------------------------- NOT OVERRIDE --------------------
function DefaultFigure:init(figure_name_id,params)
	self.figure_name_id = figure_name_id
    local params_metadata=self.params_to_check()
    self.params_metadata=self.params_to_check()
    self:checkParams(params,params_metadata)
	self:load_params(params)
    self.params=params
    
    DefaultFigure.superClass.init(self)


end

---------------------------- NOT OVERRIDE --------------------
function DefaultFigure:load_params(params)
    for key,value in pairs(params) do
        self[key]=value
    end
end

function DefaultFigure:set_params(params)

    self:checkParams(params,self.params_metadata)
	self:load_params(params)
    self.params=params
    
end

---------------------------- NOT OVERRIDE --------------------
function DefaultFigure:checkParams(params,params_metadata)

    expect(1, params, "table")
    expect(2, keys, "table")
    for _,param_metadata in ipairs(keys) do 
        
        local value = expect.field(param_metadata.name, key,param_metadata.type) 
    end
end






return DefaultFigure