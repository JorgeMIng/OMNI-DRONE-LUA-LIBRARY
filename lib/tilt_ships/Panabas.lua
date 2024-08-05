local quaternion = require "lib.quaternions"
local utilities = require "lib.utilities"
local targeting_utilities = require "lib.targeting_utilities"
local player_spatial_utilities = require "lib.player_spatial_utilities"
local flight_utilities = require "lib.flight_utilities"
local list_manager = require "lib.list_manager"

local DroneBaseClassKontraption = require "lib.tilt_ships.DroneBaseClassKontraption"
local Object = require "lib.object.Object"

local sqrt = math.sqrt
local abs = math.abs
local max = math.max
local min = math.min
local mod = math.fmod
local cos = math.cos
local sin = math.sin
local acos = math.acos
local pi = math.pi
local clamp = utilities.clamp
local sign = utilities.sign

local quadraticSolver = utilities.quadraticSolver
local getTargetAimPos = targeting_utilities.getTargetAimPos
local getQuaternionRotationError = flight_utilities.getQuaternionRotationError
local getLocalPositionError = flight_utilities.getLocalPositionError
local adjustOrbitRadiusPosition = flight_utilities.adjustOrbitRadiusPosition
local getPlayerLookVector = player_spatial_utilities.getPlayerLookVector
local getPlayerHeadOrientation = player_spatial_utilities.getPlayerHeadOrientation
local rotateVectorWithPlayerHead = player_spatial_utilities.rotateVectorWithPlayerHead
local PlayerVelocityCalculator = player_spatial_utilities.PlayerVelocityCalculator
local RadarSystems = targeting_utilities.RadarSystems
local TargetingSystem = targeting_utilities.TargetingSystem
local IntegerScroller = utilities.IntegerScroller
local NonBlockingCooldownTimer = utilities.NonBlockingCooldownTimer
local IndexedListScroller = list_manager.IndexedListScroller


local Panabas = Object:subclass()

--overridable functions--
function Panabas:setShipFrameClass(configs) --override this to set ShipFrame Template
	self.ShipFrame = DroneBaseClassKontraption(configs)
end
--overridable functions--

--custom--
--initialization:
function Panabas:initializeShipFrameClass(instance_configs)
	local configs = instance_configs
	
	configs.ship_constants_config = configs.ship_constants_config or {}
	
	configs.ship_constants_config.DRONE_TYPE = "OMNI"

	configs.ship_constants_config.PID_SETTINGS = configs.ship_constants_config.PID_SETTINGS or
	{
		POS = {
			P = 0.7,
			I = 0.001,
			D = 1
		},
        VEL = {
			P=0.04,
            I=0.001,
            D=0.05,
		}
	}
	
	configs.radar_config = configs.radar_config or {}
	
	configs.radar_config.player_radar_box_size = configs.radar_config.player_radar_box_size or 50
	configs.radar_config.ship_radar_range = configs.radar_config.ship_radar_range or 500
	
	configs.rc_variables = configs.rc_variables or {}
	
	configs.rc_variables.orbit_offset = configs.rc_variables.orbit_offset or vector.new(0,0,0)
	configs.rc_variables.run_mode = false
	self:setShipFrameClass(configs)
	
	
end

function Panabas:initCustom(custom_config)
end


function Panabas:addShipFrameCustomThread()
	for k,thread in pairs(self:CustomThreads()) do
		table.insert(self.ShipFrame.threads,thread)
	end
end

function Panabas:overrideShipFrameGetCustomSettings()
	local panabas = self
	function self.ShipFrame.remoteControlManager:getCustomSettings()
		return {
			blade_mode = panabas.blade_mode,
			axe_mode = panabas.axe_mode,
		}
	end
end

--overridden functions--
function Panabas:overrideShipFrameCustomProtocols()
	local panabas = self
	function self.ShipFrame:customProtocols(msg)
		local command = msg.cmd
		command = command and tonumber(command) or command
		case =
		{
			["blade_mode"]= function (args)
				panabas.blade_mode = not panabas.blade_mode
			end,
			["axe_mode"]= function (args)
				panabas.axe_mode = not panabas.axe_mode
			end,
			default = function ( )
				print(textutils.serialize(command)) 
				print("Panabas: default case executed")
			end,
		}
		if case[command] then
		 case[command](msg.args)
		else
		 case["default"]()
		end
	end
end

Panabas.blade_mode = false --remote; reinitialize PIDs when toggling this
Panabas.axe_mode = true --remote
function Panabas:overrideInitDynamicControllers()
	local panabas = self
	function self.ShipFrame:initDynamicControllers()
		if(panabas.blade_mode) then
			self.lateral_PID = pidcontrollers.PID_Discrete_Vector(	self.ship_constants.PID_SETTINGS.POS.P,
																	self.ship_constants.PID_SETTINGS.POS.I,
																	self.ship_constants.PID_SETTINGS.POS.D,
																	-1,1)
			return
		end

		self.lateral_PID = pidcontrollers.PID_Discrete_Vector(	self.ship_constants.PID_SETTINGS.VEL.P,
																self.ship_constants.PID_SETTINGS.VEL.I,
																self.ship_constants.PID_SETTINGS.VEL.D,
																-1,1)
	end
end

function Panabas:overrideCalculateDynamicControlValueError()
	local panabas = self
	function self.ShipFrame:calculateDynamicControlValueError()
		local target_value = self.target_global_velocity
		local measured_value = self.ship_global_velocity
		if(panabas.blade_mode) then
			target_value = self.target_global_position
			measured_value = self.ship_global_position
		end
		return 	getLocalPositionError(target_value,measured_value,self.ship_rotation)
	end
end

function Panabas:overrideCalculateDynamicControlValues()
	local panabas = self
	function self.ShipFrame:calculateDynamicControlValues(error)
		return 	self.lateral_PID:run(error)
	end
end
Panabas.global_velocity_offset = vector.new(0,0,0)
function Panabas:overrideShipFrameCustomFlightLoopBehavior()
	local panabas = self
	function self.ShipFrame:customFlightLoopBehavior(customFlightVariables)
		--[[
		useful variables to work with:
			self.target_global_position
			self.target_rotation
			self.target_global_velocity
			self.error
		]]--

		if (self.remoteControlManager.rc_variables.run_mode) then
			local target_orbit = self.sensors.orbitTargeting:getTargetSpatials()
			
			local target_orbit_position = target_orbit.position
			local target_orbit_orientation = target_orbit.orientation

			local point = self.axe_mode and 1 or -1

			self.target_rotation = quaternion.fromToRotation(self.target_rotation:localPositiveY()*point,target_orbit_orientation:localPositiveZ())*self.target_rotation

			local formation_position = target_orbit_orientation:rotateVector3(self.remoteControlManager.rc_variables.orbit_offset)
			--self:debugProbe({formation_position=formation_position})
			self.target_global_position = formation_position:add(target_orbit_position)
			
			self.target_global_velocity = vector.new(0,0,0) + panabas.global_velocity_offset
		else
			self.target_global_velocity = vector.new(0,0,0)
			self.target_rotation = quaternion.new(1,0,0,0)
		end
		panabas.global_velocity_offset = vector.new(0,0,0)
		self:debugProbe({ship_global_velocity=self.ship_global_velocity})
	end
end

function Panabas:init(instance_configs)
	self:initializeShipFrameClass(instance_configs)

	self:overrideInitDynamicControllers()
	self:overrideCalculateDynamicControlValueError()
	self:overrideCalculateDynamicControlValues()

	self:overrideShipFrameCustomProtocols()
	self:overrideShipFrameGetCustomSettings()
	self:overrideShipFrameCustomFlightLoopBehavior()

	omniship_custom_config = instance_configs.omniship_custom_config or {}

	self:initCustom(omniship_custom_config)
	Panabas.superClass.init(self)
end

function Panabas:run()
	self.ShipFrame:run()
end
--overridden functions--

return Panabas