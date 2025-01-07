local quaternion = require "lib.quaternions"
local utilities = require "lib.utilities"
local targeting_utilities = require "lib.targeting_utilities"
local player_spatial_utilities = require "lib.player_spatial_utilities"
local flight_utilities = require "lib.flight_utilities"
local list_manager = require "lib.list_manager"

local DroneBaseClass = require "lib.tilt_ships.DroneBaseClass"
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


local ShipFrameController = Object:subclass()

local htb = self




function ShipFrameController:setShipFrameClass(frame_class) --override this to set ShipFrame Template
	ShipFrameController.newFrame = frame_class:subclass()
end




--overridable functions--
function ShipFrameController:CustomThreads()
	local htb = self
	local threads = {
		function()--synchronize guns
			sync_step = 0
			while self.ShipFrame.run_firmware do
				
				if (htb.activate_weapons) then
					htb:alternateFire(sync_step)
					
					sync_step = math.fmod(sync_step+1,htb.ALTERNATING_FIRE_SEQUENCE_COUNT)
				else
					htb:reset_guns()
				end
				os.sleep(htb.GUNS_COOLDOWN_DELAY)
			end
			htb:reset_guns()
		end,
	}
	return threads
end





--overridable functions--

--custom--
--initialization:

function ShipFrameController:modifyConfigs(configs)

	--[[
	configs.radar_config = configs.radar_config or {}
	
	configs.radar_config.player_radar_box_size = configs.radar_config.player_radar_box_size or 50
	configs.radar_config.ship_radar_range = configs.radar_config.ship_radar_range or 500
	
	configs.rc_variables = configs.rc_variables or {}
	
	configs.rc_variables.orbit_offset = configs.rc_variables.orbit_offset or vector.new(0,0,0)
	configs.rc_variables.run_mode = false
	configs.rc_variables.dynamic_positioning_mode = false
	configs.rc_variables.player_mounting_ship = false
	configs.rc_variables.weapons_free = false--activate to fire cannons
	configs.rc_variables.hunt_mode = false--activate for the drone to follow what it's aiming at, force-activates auto_aim if set to true
	configs.rc_variables.range_finding_mode = 3
	return configs
	]]
	return configs
end





function ShipFrameController:initializeShipFrameClass(frame_ship,instance_configs)
	local configs = instance_configs
	
	self:setShipFrameClass(frame_ship)
	self.overrideFunctions(self)
	configs = self:customSetConfigFrame(configs)
	configs = self:modifyConfigs(configs)

	return configs

end

function ShipFrameController:initCustom(custom_config)
	
end

function ShipFrameController:customSetConfigFrame(instance_configs)
	return instance_configs
end





function ShipFrameController:run()
	ShipFrameController.ShipFrame:run()
end


--setters and getters:





--custom--

--overridden functions--
-- Example of getProtocols
function ShipFrameController:getProtocols()
	return {["test"]=function () print("FUCK STUPID")end}
	--[[
	return 
	{
	["set_range_finding_mode"] = function (arguments)--1:manual ; 2:auto ; 3:auto-external
		ShipFrameController:setRangeFindingMode(arguments.mode)
	end,
	["override_bullet_range"] = function (arguments)
		ShipFrameController:overrideBulletRange(arguments.args)
	end,
	["scroll_bullet_range"] = function (arguments)
		ShipFrameController:changeBulletRange(arguments.args)
	end,
	["hunt_mode"] = function (args)
		ShipFrameController:setHuntMode(args)
	end,
	["burst_fire"] = function (arguments)
		ShipFrameController:setWeaponsFree(arguments.mode)
	end,
	["weapons_free"] = function (arguments)
		ShipFrameController:setWeaponsFree(arguments.args)
	end,
	["hush"] = function (args) --kill command
		self:resetRedstone()
		print("reseting redstone")
		self.run_firmware = false
	end,
	["set_target_mode"] =function (args)
		--print("set_target_mode:", args.is_aim,args.mode)
		ShipFrameController.ShipFrame:setTargetMode(args.is_aim,args.mode)
		--print("getTargetMode:", self:getTargetMode(false))
	end
	}
	]]
end



-- Example of getCustomSettings
function ShipFrameController:getCustomSettings()
	local dbc = self
	return {}
	--[[
	return {
		
		hunt_mode = function (self) print("PEP",self.checking) return self.controller:getHuntMode() end,
		bullet_range = function (self) return self.controller:getBulletRange() end,
		range_finding_mode = function (self) return self.controller:getRangeFindingMode() end,
	}
		]]
end




-- Example of setCustomSettings
function ShipFrameController:setCustomSettings()

	local dbc = self
	print("override ",self)
	return {}
	--[[ Example of setCustomSettings
	return {
		auto_aim = function(new_setting,new_settings) dbc:setAutoAim(new_setting) end,
		orbit_offset = function(new_setting,new_settings) return dbc.remoteControlManager.rc_variables.orbit_offset end,
		dynamic_positioning_mode = function(new_setting,new_settings) return dbc.remoteControlManager.rc_variables.dynamic_positioning_mode end,
		player_mounting_ship = function(new_setting,new_settings) return dbc.remoteControlManager.rc_variables.player_mounting_ship end,
		run_mode = function(new_setting,new_settings) return dbc.remoteControlManager:getRunMode()end,
		use_external_aim = function(new_setting,new_settings)  dbc:useExternalRadar(true,new_setting)end,
		use_external_orbit = function(new_setting,new_settings)  dbc:useExternalRadar(false,new_setting)end,
		aim_target_mode = function(new_setting,new_settings) dbc:setTargetMode(true,new_settings.aim_target_mode)end,
		orbit_target_mode = function(new_setting,new_settings) dbc:setTargetMode(false,new_settings.orbit_target_mode)end,
		master_player = function(new_setting,new_settings) dbc:setDesignatedMaster(true,new_settings.master_player)end,
		master_ship = function(new_setting,new_settings) dbc:setDesignatedMaster(false,new_settings.master_ship)end,
	}
		]]

end




function ShipFrameController:customPreFlightLoopBehavior()	
end



function ShipFrameController:customFlightLoopBehavior()
	

end


function ShipFrameController:get_override_frame_funcs()
	return {"customFlightLoopBehavior",
	"getOffsetDefaultShipOrientation",
	"getProtocols",
	"composeComponentMessage",
	"customPreFlightLoopVariables",
	"onResetRedstone",
	"communicateWithComponent",
	"getCustomSettings",
	"setCustomSettings"}
end


function ShipFrameController:overrideFunctions()
	for _,fun in pairs(self:get_override_frame_funcs()) do
		if self[fun] then
			self.newFrame[fun]=self[fun]
		end
	end
	
end

function ShipFrameController:init(frame_ship,instance_configs)
	
	ShipFrameController.superClass.init(self)
	local frameConfigs = self:initializeShipFrameClass(frame_ship,instance_configs)
	ShipFrameController.ShipFrame = self.newFrame(frameConfigs)
	ShipFrameController.ShipFrame.controller = self
	
	local custom_config = instance_configs.custom_config or {}

	self:initCustom(custom_config)
	
	
end
--overridden functions--




return ShipFrameController