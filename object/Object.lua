--[[
I have to thank Knector01 for this Object class. It was from their GUI API. 
It was so well documented, simple to understand and easy to use that I decided to use it to tidy up my drone code into its own neat instantiable class.
https://github.com/knector01/gui.lua/blob/master/docs.md#object
]]--

local expect = require "cc.expect"

-- Creates an instance of a class, and then calls the class's init() method
-- with the provided arguments.
local function new(class, ...)
    local instance = setmetatable({}, class.instanceMeta)
    ret, msg = pcall(instance.init, instance, ...)
    if not ret then
        error(msg, 2) -- propagate error up to caller
    end
    return instance
end

-- Converts a table into a class.
local function makeClass(class, superClass)
    class.class = class
    class.superClass = superClass
    class.instanceMeta = {__index=class}
    return setmetatable(class, {__index=superClass, __call=new})
end

-- Implements basic inheritance features.
local Object = {}

makeClass(Object)

-- Object constructor.
--
-- To create an instance of an Object, call Object(args), which will instantiate
-- the class and then call the Object's constructor to set up the instance.
-- The process works the same way for subclasses: just replace Object with the
-- name of the class you are instantiating.
--
-- Internally, the constructor is named Object:init(...). Override this init
-- method to specify initialization behavior for an Object subclass. An object's
-- init() method may call its super class's init() if desired
-- (use ClassName.superClass.init(self,...))
function Object:init(...) end

-- Creates a subclass of an existing class.
function Object:subclass()
    return makeClass({}, self)
end

-- Returns true if the Object is an instance of the provided class or a subclass.
function Object:instanceof(class)
    expect(1, class, "table")
    local c = self.class
    while c ~= nil do
        if c == class then
            return true
        end
        c = c.superClass
    end
    return false
end

function Object:serialize()
    local data = {
        class = self.class,      -- Guardamos la referencia a la clase
        variables = {}           -- Aquí guardamos las variables de la instancia
    }

    -- Copiar las variables de la instancia (no las funciones)
    for key, value in pairs(self) do
        if type(value) ~= "function" then
            data.variables[key] = value
        end
    end

    return textutils.serialize(data)
end

-- Función para deserializar una instancia
function Object.deserialize(serializedData)
    local data = textutils.unserialize(serializedData)

    -- Crear la nueva instancia usando la clase guardada
    local instance = new(data.class)

    -- Restaurar las variables
    for key, value in pairs(data.variables) do
        instance[key] = value
    end

    return instance
end

return Object
