local quaternion = require "lib.quaternions"
local utilities = require "lib.utilities"
local pidcontrollers = require "lib.pidcontrollers"
local targeting_utilities = require "lib.targeting_utilities"
local player_spatial_utilities = require "lib.player_spatial_utilities"
local flight_utilities = require "lib.flight_utilities"
local RemoteControlManager = require "lib.remote.RemoteControlManager"
local Rec = require "lib.utilities_recursive"


local Sensors = require "lib.sensory.Sensors"

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


local DroneBaseClass = Object:subclass()

--OVERRIDABLE FUNCTIONS--
function DroneBaseClass:getOffsetDefaultShipOrientation(default_ship_orientation)	--based on dynamic ship orientation (rotated from how it is oriented right now)
	local offset_orientation = quaternion.fromRotation(default_ship_orientation:localPositiveZ(), 0)*default_ship_orientation
	return offset_orientation
end

function DroneBaseClass:composeComponentMessage(linear,angular)
	return {cmd="move", 
			drone_designation=self.ship_constants.DRONE_ID, 
			"custom_message_here",}
end

function DroneBaseClass:getProtocols()
	
	return {
		["scroll_aim_target"] = function (self,arguments)
			if (self:getAutoAim()) then
				if (arguments.args>0) then
					self:scrollUpShipTargets()
					self:scrollUpPlayerTargets()
				else
					self:scrollDownShipTargets()
					self:scrollDownPlayerTargets()
				end
			end
		end,
		["run_mode"] = function (self,mode)
			self.remoteControlManager.rc_variables.run_mode = mode
		end,
		
		["auto_aim"] = function (self,mode)
			self:setAutoAim(mode)
		end,
		["use_external_radar"] = function (self,args)
			self:useExternalRadar(args.is_aim,args.mode)
		end,
		["set_target_mode"] = function (self,args)
			print("set_target_mode:", args.is_aim,args.mode)
			self:setTargetMode(args.is_aim,args.mode)
			--print("getTargetMode:", self:getTargetMode(false))
		end,
		["designate_to_player"] = function (self,designation)
			self:setDesignatedMaster(true,designation)
		end,
		["designate_to_ship"] = function (self,designation)
			self:setDesignatedMaster(false,designation)
		end,
		["add_to_whitelist"] = function (self,args)
			self:addToWhitelist(args.is_player,args.designation)
		end,
		["remove_from_whitelist"] = function (self,args)
			self:removeFromWhitelist(args.is_player,args.designation)
		end,
		["realign"] = function (self,args)
			self.target_rotation = quaternion.fromRotation(vector.new(0,1,0), 0)
		end,
		["hush"] = function (self,args) --kill command
			print("FJUCCCCCCCCCCCCCCC")
			self:resetRedstone()
			self.run_firmware = false
		end,
		["restart"] = function (self,args) --kill command
			self:resetRedstone()
			os.reboot()
		end,
		["dynamic_positioning_mode"] = function (self,mode)
			self.remoteControlManager.rc_variables.dynamic_positioning_mode = mode
		end,
		["player_mounting_ship"] = function (self,mode)
			self.remoteControlManager.rc_variables.player_mounting_ship = mode
		end,
		["orbit_offset"] = function (self,pos_vec)
			self.remoteControlManager.rc_variables.orbit_offset = pos_vec
		end,
		["default"] = function (self)
			print("default was executed")
		end
		}
end

function DroneBaseClass:redirectMessege(args,reply_info)
	local senderChannel=self.com_channels.REPLY_DUMP_CHANNEL

	local reply_message={sender_id=args.sender_id,id=ship.getId(),msg={cmd=reply_info.protocol,args=reply_info.message}}
	if args.channel ==self.com_channels.REMOTE_TO_DRONE_CHANNEL then
		senderChannel= self.com_channels.DRONE_TO_REMOTE_CHANNEL
		--print("secret",args.sender_id)
		reply_message={reply_id=args.sender_id,drone_ID=ship.getId(),protocol=reply_info.protocol,args=reply_info.message}
	end

	if args.channel ==self.com_channels.DEBUG_TO_DRONE_CHANNEL then
		senderChannel= self.com_channels.DRONE_TO_DEBUG_CHANNEL
	end

	if args.channel ==self.com_channels.DRONE_TO_DRONE_CHANNEL then
		senderChannel= self.com_channels.DRONE_TO_DRONE_CHANNEL
		reply_message={drone_id=args.sender_id,id=ship.getId(),msg={cmd=reply_info.protocol,args=reply_info.message}}
	end
	
	self.modem.transmit(senderChannel,self.com_channels.REPLY_DUMP_CHANNEL,reply_message)
end




function DroneBaseClass:getBroadcastProtocols()
	
	return {
		["ping"] = function (self,args)
			
			self:redirectMessege(args,{protocol="reply_ping",message={id=ship.getId(),drone_type=self.remoteControlManager.DRONE_TYPE}})
			
		end,
		
		
		["default"] = function (self)
			print("default was executed")
		end
		}
end

function DroneBaseClass:customPreFlightLoopBehavior(customFlightVariables) end

function DroneBaseClass:customPreFlightLoopVariables()
	return {}
end

function DroneBaseClass:customFlightLoopBehavior()
	--[[
	useful variables to work with:
		self.target_global_position :read/write
		self.target_rotation :read/write
		self.rotation_error :read only
		self.position_error :read only
		self.ship_rotation :read only
		self.ship_global_position :read only
	]]--
end

function DroneBaseClass:onResetRedstone() end

function DroneBaseClass:communicateWithComponent(component_control_msg)
	self.modem.transmit(self.com_channels.DRONE_TO_COMPONENT_BROADCAST_CHANNEL, self.com_channels.COMPONENT_TO_DRONE_CHANNEL,component_control_msg)
end
--OVERRIDABLE FUNCTIONS--



--INITIALIZATION FUNCTIONS--
function DroneBaseClass:init(configs)
	DroneBaseClass.superClass.init(self)
	self:initPeripherals(configs)
	self:initVariables()
	self:initConstants(configs.ship_constants_config)
	self:initModemChannels(configs.channels_config)
	self:initRadar(configs.radar_config)
	
	self:initRemoteControl(configs)
	
	
	
	self.threads = {
		function()
			self:receiveCommand()
		end,
		function()
			self:calculateMovement()
		end,
		function()
			self:checkInterupt()
		end,
	}
	
	self:addTargetingSystemThreads()
end


function DroneBaseClass:getCustomSettings()

	return {
		
		orbit_offset = function (self) return self.remoteControlManager.rc_variables.orbit_offset end,
		dynamic_positioning_mode = function (self) return self.remoteControlManager.rc_variables.dynamic_positioning_mode end,
		player_mounting_ship = function (self) return self.remoteControlManager.rc_variables.player_mounting_ship end,
		run_mode = function (self) return self.remoteControlManager:getRunMode()end,
		auto_aim = function (self) return self:getAutoAim() end,
		use_external_aim = function (self) return self:isUsingExternalRadar(true)end,
		use_external_orbit = function (self) return self:isUsingExternalRadar(false)end,
		aim_target_mode = function (self) return self:getTargetMode(true)end,
		orbit_target_mode = function (self) return self:getTargetMode(false)end,
		master_player = function (self) return self.sensors:getDesignatedMaster(true)end,
		master_ship= function (self)  return  self.sensors:getDesignatedMaster(false) end,
	}
end

function DroneBaseClass:setCustomSettings()
	return {
		auto_aim = function(self,new_setting,new_settings) self:setAutoAim(new_setting) end,
		use_external_aim = function(self,new_setting,new_settings)  self:useExternalRadar(true,new_setting)end,
		use_external_orbit = function(self,new_setting,new_settings)  self:useExternalRadar(false,new_setting)end,
		aim_target_mode = function(self,new_setting,new_settings) self:setTargetMode(true,new_settings.aim_target_mode)end,
		orbit_target_mode = function(self,new_setting,new_settings) self:setTargetMode(false,new_settings.orbit_target_mode)end,
		master_player = function(self,new_setting,new_settings) self:setDesignatedMaster(true,new_settings.master_player)end,
		master_ship = function(self,new_setting,new_settings) self:setDesignatedMaster(false,new_settings.master_ship)end,
	}

end

function DroneBaseClass:execute_protocol(protocol,args)
	
	
	Rec.rec_switch_custum(protocol,args,"getProtocols",self,{conservedOld=true,protected_cases=self.remoteControlManager:getProtocols(),defaultFunc={}})
end


function DroneBaseClass:getSettingsDrone()
	
	local custom_cases = Rec.rec_get_cases_custum("getCustomSettings",self,{conservedOld=true,protected_cases={}})
	
	for key,_ in pairs(custom_cases) do
		custom_cases[key]=custom_cases[key](self)
	end

	return custom_cases
end


function DroneBaseClass:setSettingsDrone(new_settings)

	local setter_funcs = Rec.rec_get_cases_custum("setCustomSettings",self,{conservedOld=true,protected_cases={}})

	--setting the variables by executing the funcs || now we can re-implemente more easily the functs
	for var_name,new_setting in pairs(new_settings) do
		
		if setter_funcs[var_name] and new_setting~=nil then
			--print(var_name,new_setting,"|")
			setter_funcs[var_name](self,new_setting,new_settings)
		end
		-- change to a function of remotecontroler manager TODO
		if (self.remoteControlManager.rc_variables[var_name] ~= nil) then
			self.remoteControlManager.rc_variables[var_name] = new_setting
		end
	end
end



function DroneBaseClass:initRemoteControl(config)
	local dbc = self
	
	config.DRONE_TO_REMOTE_CHANNEL = config.channels_config.DRONE_TO_REMOTE_CHANNEL or 0
	config.REPLY_DUMP_CHANNEL = config.channels_config.REPLY_DUMP_CHANNEL or 0
	config.DRONE_ID = self.ship_constants.DRONE_ID
	config.DRONE_TYPE = self.ship_constants.DRONE_TYPE

	config.rc_variables = config.rc_variables or {}
	config.rc_variables.run_mode = config.rc_variables.run_mode or false
	config.modem = self.modem
	
	
	
	local dbc=self
	

	function RemoteControlManager:getSettings()
		--local dbc=self
		--print("TESTING",dbc.getSettingsDrone)
		return dbc:getSettingsDrone()
	end

	function RemoteControlManager:setSettings(new_settings)
		--print("TESTING_2",dbc.setSettingsDrone)

		
		return dbc:setSettingsDrone(new_settings)
	end

	--function RemoteControlManager:setLocalInstance(dbc,new)
	--	self.dbc=dbc
	--	print("TESTING INSTANCE",self.checking)
	--end


	function RemoteControlManager:setRunMode(mode)
		self.rc_variables.run_mode = mode
	end

	function RemoteControlManager:getRunMode()
		if(dbc:targetedPlayersAreUndetected()) then
			return false
		end
		return self.rc_variables.run_mode
	end

	self.remoteControlManager = RemoteControlManager(config)
	
	--self.remoteControlManager.setLocalInstance(self)
end






function DroneBaseClass:initSensors(configs)
	self.sensors = Sensors(configs)
end

function DroneBaseClass:initPeripherals(configs)
	configs = configs or {}
	self:initSensors(configs)
	self.modem = peripheral.find("modem", function(name, object) return object.isWireless() end)
end

function DroneBaseClass:initVariables()
	self.ship_global_velocity = vector.new(0,0,0)
	self.run_firmware = true

	self.ship_rotation = self.sensors.shipReader:getRotation(true)
	
	self.ship_rotation = quaternion.new(self.ship_rotation.w,self.ship_rotation.x,self.ship_rotation.y,self.ship_rotation.z)
	
	self.ship_rotation = self:getOffsetDefaultShipOrientation(self.ship_rotation)
	
	self.target_rotation = self.ship_rotation

	self.ship_global_position = self.sensors.shipReader:getWorldspacePosition()
	self.ship_global_position = vector.new(self.ship_global_position.x,self.ship_global_position.y,self.ship_global_position.z)
	self.target_global_position = self.ship_global_position

	self.ship_global_velocity = self.sensors.shipReader:getVelocity()
	self.ship_global_velocity = vector.new(self.ship_global_velocity.x,self.ship_global_velocity.y,self.ship_global_velocity.z)
	self.target_global_velocity = vector.new(0,0,0)

	--useful for modifying flight behavior
	self.rotation_error = vector.new(0,0,0)
	self.position_error = vector.new(0,0,0)
end

function DroneBaseClass:getInertiaTensors()
	return self.sensors.shipReader:getInertiaTensors()
end

function DroneBaseClass:rotateInertiaTensors()
	--[[
	"tensor" = {
	x = vector.new(x,y,z),
	y = vector.new(x,y,z),
	z = vector.new(x,y,z),
	}
	--NOTE: this isn't what "TENSOR" actually look like I just found it convenient to call these 3xvector3 arrays like this
	]]--
	self.ship_constants.LOCAL_INERTIA_TENSOR = quaternion.rotateTensor(
												self.ship_constants.LOCAL_INERTIA_TENSOR,
												self.ship_constants.DEFAULT_NEW_LOCAL_SHIP_ORIENTATION)

	self.ship_constants.LOCAL_INV_INERTIA_TENSOR = quaternion.rotateTensor(
													self.ship_constants.LOCAL_INV_INERTIA_TENSOR,
													self.ship_constants.DEFAULT_NEW_LOCAL_SHIP_ORIENTATION)

end

function DroneBaseClass:initConstants(ship_constants_config)
	ship_constants_config = ship_constants_config or {}
	local inertia_tensors = self:getInertiaTensors()

	self.ship_constants = {
	
		--DO NOT OVERRIDE THESE UNLESS YOU KNOW WHAT YOU ARE DOING--
		
		WORLD_UP_VECTOR = vector.new(0,1,0),
		MY_SHIP_ID = self.sensors.shipReader:getShipID(),
		
		LOCAL_INERTIA_TENSOR = inertia_tensors[1],
		LOCAL_INV_INERTIA_TENSOR = inertia_tensors[2],

		DRONE_ID = self.sensors.shipReader:getShipID(),
		DRONE_TYPE = "DEFAULT",
		DEFAULT_NEW_LOCAL_SHIP_ORIENTATION = self:getOffsetDefaultShipOrientation(quaternion.new(1,0,0,0)), --based on static ship world orientation (rotated from how it was built in the world grid)
		
		--make sure to check the VS2-Tournament mod config
		MOD_CONFIGURED_THRUSTER_SPEED = 10000,
		
		--make sure ALL the tournament thrusters are upgraded to the same level
		THRUSTER_TIER = 1,
		
		PID_SETTINGS = {
			POS = {
				P = 0,
				I = 0,
				D = 0
			},
			ROT = {
				X = {
					P = 0,
					I = 0,
					D = 0
				},
				Y = {
					P = 0,
					I = 0,
					D = 0
				},
				Z = {
					P = 0,
					I = 0,
					D = 0
				}
			}
		}
	}
	
	for constant_name,new_value in pairs(ship_constants_config) do
		self.ship_constants[constant_name] = new_value
	end
	
	self:rotateInertiaTensors()
	
end

function DroneBaseClass:initModemChannels(channels_config)
	channels_config = channels_config or {}
	self.com_channels = {
		DEBUG_TO_DRONE_CHANNEL = 0,
		DRONE_TO_DEBUG_CHANNEL = 0,
		DRONE_TO_DRONE_CHANNEL = 0,
		REMOTE_TO_DRONE_CHANNEL = 0,
		DRONE_TO_REMOTE_CHANNEL = 0,
		DRONE_TO_COMPONENT_BROADCAST_CHANNEL = 0,
		COMPONENT_TO_DRONE_CHANNEL = 0,
		REPLY_DUMP_CHANNEL = 0,
		EXTERNAL_AIM_TARGETING_CHANNEL = 0,--transmit targeting information from external radar system
		EXTERNAL_ORBIT_TARGETING_CHANNEL = 0,
	}
	local modem = self.modem
	
	for channel_name,new_channel in pairs(channels_config) do
		self.com_channels[channel_name] = new_channel
		modem.open(new_channel)
	end
end

function DroneBaseClass:initSensorRadar(radar_config)
	self.sensors:initRadar(radar_config)
end

function DroneBaseClass:initRadar(radar_config)
	
	radar_config = radar_config or {}
	radar_config.EXTERNAL_AIM_TARGETING_CHANNEL = self.com_channels.EXTERNAL_AIM_TARGETING_CHANNEL
	radar_config.EXTERNAL_ORBIT_TARGETING_CHANNEL = self.com_channels.EXTERNAL_ORBIT_TARGETING_CHANNEL
	radar_config.DRONE_ID = self.ship_constants.DRONE_ID
	radar_config.DRONE_TYPE = self.ship_constants.DRONE_TYPE
	
	self:initSensorRadar(radar_config)
	
	function DroneBaseClass:scrollUpShipTargets()
		self.sensors:scrollUpShipTargets()
	end
	function DroneBaseClass:scrollDownShipTargets()
		self.sensors:scrollDownShipTargets()
	end
	function DroneBaseClass:scrollUpPlayerTargets()
		self.sensors:scrollUpPlayerTargets()
	end
	function DroneBaseClass:scrollDownPlayerTargets()
		self.sensors:scrollDownPlayerTargets()
	end
end
--INITIALIZATION FUNCTIONS--



--RADAR SYSTEM FUNCTIONS--
function DroneBaseClass:useExternalRadar(is_aim,mode)
	self.sensors:useExternalRadar(is_aim,mode)
end

function DroneBaseClass:isUsingExternalRadar(is_aim)
	return self.sensors:isUsingExternalRadar(is_aim)
end

function DroneBaseClass:setTargetMode(is_aim,target_mode)
	self.sensors:setTargetMode(is_aim,target_mode)
end

function DroneBaseClass:getTargetMode(is_aim)
	return self.sensors:getTargetMode(is_aim)
end

function DroneBaseClass:setDesignatedMaster(is_player,designation)
	self.sensors:setDesignatedMaster(is_player,designation)
end




function DroneBaseClass:addToWhitelist(is_player,designation)
	self.sensors:addToWhitelist(is_player,designation)
end

function DroneBaseClass:removeFromWhitelist(is_player,designation)
	-- set new designated player/ship before removing it from whitelist
	self.sensors:removeFromWhitelist(is_player,designation)
end

function DroneBaseClass:getAutoAim()
	return self.sensors:getAutoAim()
end

function DroneBaseClass:setAutoAim(mode)
	--deactivate for manual aiming (by designated player/ship),
	--deactivate self.hunt_mode first before deactivating auto_aim
	self.sensors:setAutoAim(self.hunt_mode,mode)
end

function DroneBaseClass:targetedPlayersAreUndetected()
	return self.sensors:targetedPlayersAreUndetected()
end
--RADAR SYSTEM FUNCTIONS--



--REDSTONE FUNCTIONS--
function DroneBaseClass:resetRedstone()
	self.modem.transmit(self.com_channels.DRONE_TO_COMPONENT_BROADCAST_CHANNEL, self.com_channels.COMPONENT_TO_DRONE_CHANNEL, {cmd="reset",drone_designation=self.ship_constants.DRONE_ID})
	self:onResetRedstone()
end

function DroneBaseClass:applyRedStonePower(lin_mv,rot_mv)
	--Redstone signal for linear movement p==positive, n==negative--
	local linear = {
		lin_x_p = max(0,lin_mv.x),
		lin_x_n = abs(min(0,lin_mv.x)),
		lin_y_p = max(0,lin_mv.y),
		lin_y_n = abs(min(0,lin_mv.y)),
		lin_z_p = max(0,lin_mv.z),
		lin_z_n = abs(min(0,lin_mv.z))
	}
	--Redstone signal for angular movement p==positive, n==negative--
	local angular = {
		rot_x_p = max(0,rot_mv.x),
		rot_x_n = abs(min(0,rot_mv.x)),
		rot_y_p = max(0,rot_mv.y),
		rot_y_n = abs(min(0,rot_mv.y)),
		rot_z_p = max(0,rot_mv.z),
		rot_z_n = abs(min(0,rot_mv.z))
	}
	local component_control_msg = self:composeComponentMessage(linear,angular)
	
	--self:communicateWithComponent(component_control_msg)
end
--REDSTONE FUNCTIONS--



--COMMUNICATION FUNCTIONS--
function DroneBaseClass:debugProbe(msg)--transmits to debug channel
	self.modem.transmit(self.com_channels.DRONE_TO_DEBUG_CHANNEL, self.com_channels.REPLY_DUMP_CHANNEL, msg)
end

function DroneBaseClass:protocols(messege,channel)
	--[[
		--SAMPLE: Transmit from controller to this drone
		modem.transmit(
			self.com_channels.REMOTE_TO_DRONE_CHANNEL, 
			self.com_channels.DRONE_TO_REMOTE_CHANNEL,
			{drone_id=drone,msg={cmd=cmd,args=args}}
			)
	]]--
	
	
	
	if messege.msg.args == nil then
		messege.msg.args={}
	end
	if type(messege.msg.args)=="table"then
		if messege.id then
			messege.msg.args.sender_id=messege.id
		end
		messege.msg.args.channel=channel
	end
	
	if messege.msg.drone_type and self.remoteControlManager.DRONE_TYPE == messege.msg.drone_type then
		return self:execute_protocol(messege.msg.cmd,messege.msg.args)
	elseif not messege.msg.drone_type then
		return self:execute_protocol(messege.msg.cmd,messege.msg.args)
	end
		
end

function DroneBaseClass:broadcast(messege,channel)
	--[[
		--SAMPLE: Transmit from controller to this drone
		modem.transmit(
			self.com_channels.REMOTE_TO_DRONE_CHANNEL, 
			self.com_channels.DRONE_TO_REMOTE_CHANNEL,
			{drone_id=drone,msg={cmd=cmd,args=args}}
			)
	]]--
	if messege.id then
		messege.msg.args.sender_id=messege.id
	end
	
	messege.msg.args.channel=channel
	
	return Rec.rec_switch_custum(messege.msg.cmd,messege.msg.args,"getBroadcastProtocols",self,{conservedOld=true,defaultFunc={}})
end
	
--COMMUNICATION FUNCTIONS--



--THREAD FUNCTIONS--
function DroneBaseClass:receiveCommand()
	--[[
	--SAMPLE-- 
	--Transmit from controller to this drone
	modem.transmit(
		self.com_channels.REMOTE_TO_DRONE_CHANNEL, 
		self.com_channels.DRONE_TO_REMOTE_CHANNEL,
		{drone_id=drone,msg={cmd=cmd,args=args}}
		)
	]]--
	while self.run_firmware do
		local event, modemSide, senderChannel, replyChannel, message, senderDistance = os.pullEvent("modem_message")
		if (senderChannel==self.com_channels.REMOTE_TO_DRONE_CHANNEL or senderChannel==self.com_channels.DEBUG_TO_DRONE_CHANNEL or senderChannel==self.com_channels.DRONE_TO_DRONE_CHANNEL) then
			if (message) then
				if (tostring(message.drone_id) == tostring(self.ship_constants.DRONE_ID)) then
					--self:debugProbe({message.msg})
					
					self:protocols(message,senderChannel)	
					
				end

				
				if (message.broadcast == 1)then
					self:broadcast(message,senderChannel)
				end
				
			end
		end
	end
	self:resetRedstone()
end

function DroneBaseClass:initPID(max_lin_acc,max_ang_acc)
	self.pos_PID = pidcontrollers.PID_Continuous_Vector(self.ship_constants.PID_SETTINGS.POS.P,
											self.ship_constants.PID_SETTINGS.POS.I,
											self.ship_constants.PID_SETTINGS.POS.D,
											-max_lin_acc,max_lin_acc)
	
	self.rot_x_PID = pidcontrollers.PID_Continuous_Scalar(self.ship_constants.PID_SETTINGS.ROT.X.P,
													self.ship_constants.PID_SETTINGS.ROT.X.I,
													self.ship_constants.PID_SETTINGS.ROT.X.D,
													-max_ang_acc[1][1],max_ang_acc[1][1])
	self.rot_y_PID = pidcontrollers.PID_Continuous_Scalar(self.ship_constants.PID_SETTINGS.ROT.Y.P,
													self.ship_constants.PID_SETTINGS.ROT.Y.I,
													self.ship_constants.PID_SETTINGS.ROT.Y.D,
													-max_ang_acc[2][1],max_ang_acc[2][1])
	self.rot_z_PID = pidcontrollers.PID_Continuous_Scalar(self.ship_constants.PID_SETTINGS.ROT.Z.P,
													self.ship_constants.PID_SETTINGS.ROT.Z.I,
													self.ship_constants.PID_SETTINGS.ROT.Z.D,
													-max_ang_acc[3][1],max_ang_acc[3][1])
end

function DroneBaseClass:calculateMovement()


	
	local min_time_step = 0.05 --how fast the computer should continuously loop (the max is 0.05 for ComputerCraft)
	local ship_mass = self.sensors.shipReader:getMass()
	local max_redstone = 15
	
	
	local gravity_acceleration_vector = vector.new(0,-9.8,0)
	
	local inv_active_thrusters_per_linear_movement = self.ship_constants.INV_ACTIVE_THRUSTERS_PER_LINEAR_MOVEMENT
	local inv_active_thrusters_per_angular_movement = self.ship_constants.INV_ACTIVE_THRUSTERS_PER_ANGULAR_MOVEMENT
	
	local base_thruster_force = self.ship_constants.MOD_CONFIGURED_THRUSTER_SPEED*self.ship_constants.THRUSTER_TIER --thruster force when powered with a redstone power of 1(from VS2-Tournament code)
	
	local inv_base_thruster_force = 1/base_thruster_force --the base thruster force... but it's inverted
	--it's easier for the computer to use the multiplication operator instead of dividing them over and over again (I'm not really sure if this applies to Lua, I just know that this is what (should) generally go on in your CPU hardware)
	
	--for linear movement--
	local angled_thrust_coefficient = self.ship_constants.ANGLED_THRUST_COEFFICIENT
	
	local linear_acceleration_to_redstone_coefficient = angled_thrust_coefficient:mul(inv_base_thruster_force)
	linear_acceleration_to_redstone_coefficient = linear_acceleration_to_redstone_coefficient:mul(ship_mass)
	linear_acceleration_to_redstone_coefficient.x = linear_acceleration_to_redstone_coefficient.x*inv_active_thrusters_per_linear_movement.x
	linear_acceleration_to_redstone_coefficient.y = linear_acceleration_to_redstone_coefficient.y*inv_active_thrusters_per_linear_movement.y
	linear_acceleration_to_redstone_coefficient.z = linear_acceleration_to_redstone_coefficient.z*inv_active_thrusters_per_linear_movement.z
---------------------------------------------------------------------------------------------------------------------------
	--[[
	these values are specific for the 10-thruster template.
	The thrusters should be symetrical around their own axis enough to represent the other thrusters that also rotate the same axis.
	The axes that they're based on are the world axes. I rotate them to the ships new default orientation next.
	]]--
	local X_thruster_position = self.ship_constants.THRUSTER_SPATIALS.THRUSTER_POSITIONS.X_AXIS--represents thrusters that rotate x-axis
	local Y_thruster_position = self.ship_constants.THRUSTER_SPATIALS.THRUSTER_POSITIONS.Y_AXIS--represents thrusters that rotate y-axis
	local Z_thruster_position = self.ship_constants.THRUSTER_SPATIALS.THRUSTER_POSITIONS.Z_AXIS--represents thrusters that rotate z-axis

	local X_thruster_direction = self.ship_constants.THRUSTER_SPATIALS.THRUSTER_DIRECTION.X_AXIS--in world space
	local Y_thruster_direction = self.ship_constants.THRUSTER_SPATIALS.THRUSTER_DIRECTION.Y_AXIS
	local Z_thruster_direction = self.ship_constants.THRUSTER_SPATIALS.THRUSTER_DIRECTION.Z_AXIS
	
	--I have to get the thruster position relative to the new ship default orientation--
	local new_local_X_thruster_position = self.ship_constants.DEFAULT_NEW_LOCAL_SHIP_ORIENTATION:inv():rotateVector3(X_thruster_position)
	local new_local_Y_thruster_position = self.ship_constants.DEFAULT_NEW_LOCAL_SHIP_ORIENTATION:inv():rotateVector3(Y_thruster_position)
	local new_local_Z_thruster_position = self.ship_constants.DEFAULT_NEW_LOCAL_SHIP_ORIENTATION:inv():rotateVector3(Z_thruster_position)
	
	local new_local_X_thruster_direction = self.ship_constants.DEFAULT_NEW_LOCAL_SHIP_ORIENTATION:inv():rotateVector3(X_thruster_direction)
	local new_local_Y_thruster_direction = self.ship_constants.DEFAULT_NEW_LOCAL_SHIP_ORIENTATION:inv():rotateVector3(Y_thruster_direction)
	local new_local_Z_thruster_direction = self.ship_constants.DEFAULT_NEW_LOCAL_SHIP_ORIENTATION:inv():rotateVector3(Z_thruster_direction)
	
	local new_local_thruster_position_from_X_axis = vector.new(0,new_local_X_thruster_position.y,new_local_X_thruster_position.z)
	local new_local_thruster_position_from_Y_axis = vector.new(new_local_Y_thruster_position.x,0,new_local_Y_thruster_position.z)
	local new_local_thruster_position_from_Z_axis = vector.new(new_local_Z_thruster_position.x,new_local_Z_thruster_position.y,0)
---------------------------------------------------------------------------------------------------------------------------
	--[[
	instead of using trigonometric functions I use quaternions because they're easier to read:
	
	perpendicular_force = base_thruster_force*cos((pi/2) - acos(new_local_Y_thruster_direction:normalize():dot(new_local_thruster_position_from_Y_axis:normalize())))
	
	local perpendicular_force.z = new_local_Z_thruster_direction:mul(base_thruster_force):dot(quaternion.fromRotation(vector.new(0,0,1), -90):rotateVector3(new_local_thruster_position_from_Z_axis):normalize())
	]]--
	
	local perpendicular_force = vector.new(0,0,0)
	perpendicular_force.x = new_local_X_thruster_direction:mul(base_thruster_force):dot(quaternion.fromRotation(vector.new(1,0,0), 90):rotateVector3(new_local_thruster_position_from_X_axis):normalize())
	perpendicular_force.y = new_local_Y_thruster_direction:mul(base_thruster_force):dot(quaternion.fromRotation(vector.new(0,1,0), 90):rotateVector3(new_local_thruster_position_from_Y_axis):normalize())
	
	--note that this should be -90 degrees for this particular thruster arangement, but it doesn't matter anymore...
	perpendicular_force.z = new_local_Z_thruster_direction:mul(base_thruster_force):dot(quaternion.fromRotation(vector.new(0,0,1), 90):rotateVector3(new_local_thruster_position_from_Z_axis):normalize()) 
	
	--self:debugProbe({new_local_thruster_position_from_Y_axis=new_local_thruster_position_from_Y_axis})
	
	--[[
	for future drones, thrusters might be facing the opposite direction to the perpendicular vector.
	Since these only affect the magnitude of the values they're suppose to change, I get rid of the signs
	]]--
	perpendicular_force.x = perpendicular_force.x*sign(perpendicular_force.x)
	perpendicular_force.y = perpendicular_force.y*sign(perpendicular_force.y)
	perpendicular_force.z = perpendicular_force.z*sign(perpendicular_force.z)
	
	local thruster_distances_from_axes = vector.new(0,0,0)
	thruster_distances_from_axes.x = new_local_thruster_position_from_X_axis:length()
	thruster_distances_from_axes.y = new_local_thruster_position_from_Y_axis:length()
	thruster_distances_from_axes.z = new_local_thruster_position_from_Z_axis:length()
	
	local torque_to_redstone_coefficient = inv_active_thrusters_per_angular_movement
	
	torque_to_redstone_coefficient.x = torque_to_redstone_coefficient.x/(thruster_distances_from_axes.x*perpendicular_force.x)
	torque_to_redstone_coefficient.y = torque_to_redstone_coefficient.y/(thruster_distances_from_axes.y*perpendicular_force.y)
	torque_to_redstone_coefficient.z = torque_to_redstone_coefficient.z/(thruster_distances_from_axes.z*perpendicular_force.z)
	
	
	--for PID output (and Integral) clamping--
	local max_thruster_force = max_redstone*base_thruster_force
	local max_linear_acceleration = max_thruster_force/ship_mass --for PID Integral clamping
	
	local max_perpendicular_force = vector.new(0,0,0)
	
	max_perpendicular_force.x = new_local_X_thruster_direction:mul(max_thruster_force):dot(quaternion.fromRotation(vector.new(1,0,0), 90):rotateVector3(new_local_thruster_position_from_X_axis):normalize())
	max_perpendicular_force.y = new_local_Y_thruster_direction:mul(max_thruster_force):dot(quaternion.fromRotation(vector.new(0,1,0), 90):rotateVector3(new_local_thruster_position_from_Y_axis):normalize())
	max_perpendicular_force.z = new_local_Z_thruster_direction:mul(max_thruster_force):dot(quaternion.fromRotation(vector.new(0,0,1), 90):rotateVector3(new_local_thruster_position_from_Z_axis):normalize())

	-- USE WHEN VS2-COMPUTERS UPDATE RELEASES --
	--[[
	self.ship_constants.LOCAL_INERTIA_TENSOR = quaternion.rotateTensor(self.sensors.shipReader.getInertiaTensor(),self.ship_constants.DEFAULT_NEW_LOCAL_SHIP_ORIENTATION)
	self.ship_constants.LOCAL_INV_INERTIA_TENSOR = quaternion.rotateTensor(self.sensors.shipReader.getInverseInertiaTensor(),self.ship_constants.DEFAULT_NEW_LOCAL_SHIP_ORIENTATION)
	]]--
	-- USE WHEN VS2-COMPUTERS UPDATE RELEASES --
	--[[
	self.ship_constants.LOCAL_INERTIA_TENSOR = quaternion.rotateTensor(self.ship_constants.LOCAL_INERTIA_TENSOR,self.ship_constants.DEFAULT_NEW_LOCAL_SHIP_ORIENTATION)
	self.ship_constants.LOCAL_INV_INERTIA_TENSOR = quaternion.rotateTensor(self.ship_constants.LOCAL_INV_INERTIA_TENSOR,self.ship_constants.DEFAULT_NEW_LOCAL_SHIP_ORIENTATION)
	]]--

	--[[
	for future drones, thrusters might be facing the opposite direction to the perpendicular vector, 
	so I have to get rid of the signs
	]]--
	max_perpendicular_force.x = max_perpendicular_force.x*sign(max_perpendicular_force.x)
	max_perpendicular_force.y = max_perpendicular_force.y*sign(max_perpendicular_force.y)
	max_perpendicular_force.z = max_perpendicular_force.z*sign(max_perpendicular_force.z)
	
	local torque_saturation = vector.new(0,0,0)
	torque_saturation.x = thruster_distances_from_axes.x * (max_perpendicular_force.x)
	torque_saturation.y = thruster_distances_from_axes.y * (max_perpendicular_force.y)
	torque_saturation.z = thruster_distances_from_axes.z * (max_perpendicular_force.z)
	
	--self:debugProbe({thruster_distances_from_axes=thruster_distances_from_axes})
	
	local max_angular_acceleration = vector.new(0,0,0)
	max_angular_acceleration.x = torque_saturation:dot(self.ship_constants.LOCAL_INV_INERTIA_TENSOR.x)
	max_angular_acceleration.y = torque_saturation:dot(self.ship_constants.LOCAL_INV_INERTIA_TENSOR.y)
	max_angular_acceleration.z = torque_saturation:dot(self.ship_constants.LOCAL_INV_INERTIA_TENSOR.z)
	
	
	--PID Controllers--
	self:initPID(max_linear_acceleration,max_angular_acceleration)
	
	--Error Based Distributed PWM Algorithm by NikZapp for finer control over redstone thrusters--
	local linear_pwm = utilities.pwm()
	local angular_pwm = utilities.pwm()
	
	self:customPreFlightLoopBehavior()
	
	local customFlightVariables = self:customPreFlightLoopVariables()
	
	while self.run_firmware do
		--self:debugProbe({rcvv=self.rc_variables})
		self:customFlightLoopBehavior(customFlightVariables)

		self.ship_rotation = self.sensors.shipReader:getRotation(true)
		self.ship_rotation = quaternion.new(self.ship_rotation.w,self.ship_rotation.x,self.ship_rotation.y,self.ship_rotation.z)
		self.ship_rotation = self:getOffsetDefaultShipOrientation(self.ship_rotation)

		self.ship_global_position = self.sensors.shipReader:getWorldspacePosition()
		self.ship_global_position = vector.new(self.ship_global_position.x,self.ship_global_position.y,self.ship_global_position.z)

		self.ship_global_velocity = self.sensors.shipReader:getVelocity()
		self.ship_global_velocity = vector.new(self.ship_global_velocity.x,self.ship_global_velocity.y,self.ship_global_velocity.z)

		--FOR ANGULAR MOVEMENT--
		self.rotation_error = getQuaternionRotationError(self.target_rotation,self.ship_rotation)
		--self:debugProbe({LEGACY_rotation_error=self.rotation_error})
		local pid_output_angular_acceleration = vector.new(0,0,0)
		pid_output_angular_acceleration.x = self.rot_x_PID:run(self.rotation_error.x)
		pid_output_angular_acceleration.y = self.rot_y_PID:run(self.rotation_error.y)
		pid_output_angular_acceleration.z = self.rot_z_PID:run(self.rotation_error.z)
		--self:debugProbe({LEGACY_ang_acc_pid=pid_output_angular_acceleration})
		local net_torque = vector.new(0,0,0)
		net_torque.x = pid_output_angular_acceleration:dot(self.ship_constants.LOCAL_INERTIA_TENSOR.x)
		net_torque.y = pid_output_angular_acceleration:dot(self.ship_constants.LOCAL_INERTIA_TENSOR.y)
		net_torque.z = pid_output_angular_acceleration:dot(self.ship_constants.LOCAL_INERTIA_TENSOR.z)
		
		--self:debugProbe({LEGACY_IT=self.ship_constants.LOCAL_INERTIA_TENSOR})
		--self:debugProbe({net_torque=net_torque})
		
		local calculated_angular_RS_PID = net_torque
		
		calculated_angular_RS_PID.x = calculated_angular_RS_PID.x*torque_to_redstone_coefficient.x
		calculated_angular_RS_PID.y = calculated_angular_RS_PID.y*torque_to_redstone_coefficient.y
		calculated_angular_RS_PID.z = calculated_angular_RS_PID.z*torque_to_redstone_coefficient.z
		
		calculated_angular_RS_PID = angular_pwm:run(calculated_angular_RS_PID)
		
		--FOR LINEAR MOVEMENT--
		self.position_error = getLocalPositionError(self.target_global_position,self.ship_global_position,self.ship_rotation)
		
		local pid_output_linear_acceleration = self.pos_PID:run(self.position_error)

		local local_gravity_acceleration = self.ship_rotation:inv():rotateVector3(gravity_acceleration_vector)
		local net_linear_acceleration = pid_output_linear_acceleration:sub(local_gravity_acceleration)
	
		local calculated_linear_RS_PID = net_linear_acceleration
		
		calculated_linear_RS_PID.x = calculated_linear_RS_PID.x*linear_acceleration_to_redstone_coefficient.x
		calculated_linear_RS_PID.y = calculated_linear_RS_PID.y*linear_acceleration_to_redstone_coefficient.y
		calculated_linear_RS_PID.z = calculated_linear_RS_PID.z*linear_acceleration_to_redstone_coefficient.z
		
		calculated_linear_RS_PID = linear_pwm:run(calculated_linear_RS_PID)
		
		--self:debugProbe({calculated_angular_RS_PID=calculated_angular_RS_PID})
		self:applyRedStonePower(calculated_linear_RS_PID,calculated_angular_RS_PID)
		sleep(min_time_step)
	end
end

function DroneBaseClass:addTargetingSystemThreads()
	
	local functions = self.sensors:getTargetingSystemThreads()
	
	for i,v in ipairs(functions) do
		local thread = function()
			while self.run_firmware do
					v()
				os.sleep(0)
			end
		end
		table.insert(self.threads,thread)
	end
	
	
	
end




function DroneBaseClass:checkInterupt()
	while self.run_firmware do
		local event, key, isHeld = os.pullEvent("key")
		if (key == keys.q) then
			self:resetRedstone()
			return
		end
	end
	
end



function DroneBaseClass:run()
	
	
	parallel.waitForAny(unpack(self.threads))
	
end
--THREAD FUNCTIONS--

return DroneBaseClass