



local DefaultFigure = require "lib.figures.DefaultFigure"

local expect = require "cc.expect"


local GeometricFigure = DefaultFigure:subclass()

function GeometricFigure:init(figure_name_id,params)
    self.funcs_in=GeometricFigure.name_to_function("_funct_in")
    self.funcs_border=GeometricFigure.name_to_function("_funct_border")
    GeometricFigure.superClass.init(self,figure_name_id,params)
end


--OVERRIDABLE--
function GeometricFigure:in_figure(pos)
    if not self.funcs_in then
        self.funcs_in=GeometricFigure.name_to_function("_funct_in")
    end
    
    local result=false
    local geo_func = self.funcs_in[self.figure_name_id]
    if geo_func then
        result = geo_func(pos,self.center_figure,self.insc_length)
    else
        error(("Invalid Figure ID Name %s "):format(self.figure_name_id), 2)
    end
    return result
end

function GeometricFigure:in_border_figure(pos)
    if not self.funcs_border then
        self.funcs_border=GeometricFigure.name_to_function("_funct_border")
    end
    
    local result=false
    local geo_func = self.funcs_border[self.figure_name_id]
    if geo_func then
        result = geo_func(pos,self.center_figure,self.insc_length)
    else
        error(("Invalid Figure ID Name %s "):format(self.figure_name_id), 2)
    end
    return result
end



function GeometricFigure.name_to_function(funct_subname)
    local functions = GeometricFigure.geometric_func()
    local result={}
    for _,func_name in ipairs(functions) do
        local full_name=func_name..funct_subname
        result[func_name]=GeometricFigure[full_name]
    end
    return result

end
function GeometricFigure.geometric_func()
    return {"CUBE","PYRAMID","SPHERE"}
end

-- 0,0,0 will be the coordinate center 
-- center_figure the center of the figure
-- insc_length the maximum length of the inscribed cube -- aplies for sphere and pyramid
function GeometricFigure.CUBE_funct_in(pos,center_figure,insc_length)
    
    local mitad_arista = insc_length / 2
    
    -- Comprobamos si el punto está dentro de los límites del cubo en cada eje
    return pos.x >= center_figure.x - mitad_arista and pos.x <= center_figure.x + mitad_arista and
    pos.y >= center_figure.y - mitad_arista and pos.y <= center_figure.y + mitad_arista and
    pos.z >= center_figure.z - mitad_arista and pos.z <= center_figure.z + mitad_arista
end

function GeometricFigure.PYRAMID_funct_in(pos,center_figure,insc_length)
    return false

end

function GeometricFigure.SPHERE_funct_in(pos,center_figure,insc_length)

    local radius = insc_length/2
    local distancia_cuadrada = (pos.x - center_figure.x)^2 + (pos.y - center_figure.y)^2 + (pos.z - center_figure.z)^2
    
    -- Comparamos si la distancia al cuadrado es menor o igual al radio al cuadrado
    return distancia_cuadrada <= (radius)^2

end

--- border---

function GeometricFigure.CUBE_funct_border(pos,center_figure,insc_length)
    
    local mitad_arista = insc_length / 2
    
    -- Comprobamos si el punto está dentro de los límites del cubo en cada eje
    return pos.x >= center_figure.x - mitad_arista and pos.x <= center_figure.x + mitad_arista and
    pos.y >= center_figure.y - mitad_arista and pos.y <= center_figure.y + mitad_arista and
    pos.z >= center_figure.z - mitad_arista and pos.z <= center_figure.z + mitad_arista
end

function GeometricFigure.PYRAMID_funct_border(pos,center_figure,insc_length)
    return false

end

function GeometricFigure.SPHERE_funct_border(pos,center_figure,insc_length)

    local radius = insc_length/2
    local distancia_cuadrada = (pos.x - center_figure.x)^2 + (pos.y - center_figure.y)^2 + (pos.z - center_figure.z)^2
    
    -- Comparamos si la distancia al cuadrado es menor o igual al radio al cuadrado
    return distancia_cuadrada <= (radius)^2 and distancia_cuadrada > (radius-radius*0.2)^2

end














--static--
function GeometricFigure.params_to_check()
    return {
        {name="center_figure",gui_type="vector",type="table"},
        {name="insc_length",gui_type="number",type="number"}}

end

--static--
function GeometricFigure.figure_type()
    return "geometric"
end





return GeometricFigure