local quaternion = require "lib.quaternions"
local flight_utilities = require "lib.flight_utilities"


local DroneBaseClassKontraption = require "lib.tilt_ships.DroneBaseClassKontraption"
local Object = require "lib.object.Object"

local getLocalPositionError = flight_utilities.getLocalPositionError

local ImmortalShipBase = Object:subclass()

local ShipReaderSPRemote = require "lib.sensory.ShipReaderSPRemote"
local SensorsSP = require "lib.sensory.SensorsSP"

function SensorsSP:initShipReader(configs)
	return ShipReaderSPRemote(configs.ship_constants_config.DRONE_ID)
end

function ImmortalShipBase:setShipFrameClass(configs) --override this to set ShipFrame Template
	self.ShipFrame = DroneBaseClassKontraption(configs)
end


--custom--
--initialization:
function ImmortalShipBase:initializeShipFrameClass(instance_configs)
	local configs = instance_configs

	configs.ship_constants_config = configs.ship_constants_config or {}
	configs.ship_constants_config.DRONE_ID = configs.ship_constants_config.DRONE_ID or {}
	configs.ship_constants_config.DRONE_TYPE = "OMNI"

	configs.ship_constants_config.PID_SETTINGS = configs.ship_constants_config.PID_SETTINGS or
	{
		POS = {
			P=0.05,
			I=0.001,
			D=0.015,
		},
		VEL = {
			P=0.1,
			I=0.000,
			D=0.000,
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

function ImmortalShipBase:initCustom(custom_config)
end


function ImmortalShipBase:addShipFrameCustomThread()
	for k,thread in pairs(self:CustomThreads()) do
		table.insert(self.ShipFrame.threads,thread)
	end
end

function ImmortalShipBase:overrideShipFrameGetCustomSettings()
	local ImmortalShipBase = self
	function self.ShipFrame.remoteControlManager:getCustomSettings()
		return {
			blade_mode = ImmortalShipBase.blade_mode,
			axe_mode = ImmortalShipBase.axe_mode,
		}
	end
end

--overridden functions--
function ImmortalShipBase:overrideShipFrameCustomProtocols()
	local ImmortalShipBase = self
	function self.ShipFrame:customProtocols(msg)
		local command = msg.cmd
		command = command and tonumber(command) or command
		case =
		{
			["blade_mode"]= function (args)
				ImmortalShipBase.blade_mode = not ImmortalShipBase.blade_mode
				self:InitFeedbackControllers()
			end,
			["axe_mode"]= function (args)
				ImmortalShipBase.axe_mode = not ImmortalShipBase.axe_mode
			end,
			["move"]= function (arg)
				--print("linear moving",textutils.serialise(arg.linear))
				ImmortalShipBase.remote_move_linear = vector.new(arg.linear.x,arg.linear.y,arg.linear.z)

				--print("angular moving",textutils.serialise(arg.angular))
				local angle = vector.new(arg.angular.x,arg.angular.y,arg.angular.z)
				ImmortalShipBase.remote_move_angular = angle
			end,

			default = function ( )
				print(textutils.serialize(command)) 
				print("ImmortalShipBase: default case executed")
			end,
		}
		if case[command] then
		 case[command](msg.args)
		else
		 case["default"]()
		end
	end
end
ImmortalShipBase.remote_move_linear = vector.new(0,0,0)
ImmortalShipBase.remote_move_angular = vector.new(0,0,0)
ImmortalShipBase.axe_mode = true
ImmortalShipBase.blade_mode = false
ImmortalShipBase.defensePose = false
function ImmortalShipBase:overrideInitFeedbackControllers()
	local ImmortalShipBase = self
	function self.ShipFrame:initFeedbackControllers()
		if(ImmortalShipBase.blade_mode) then
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
		print(self.lateral_PID.p,self.lateral_PID.i,self.lateral_PID.d)
	end
end

function ImmortalShipBase:overrideCalculateFeedbackControlValueError()
	local ImmortalShipBase = self
	function self.ShipFrame:calculateFeedbackControlValueError()
		local target_value = self.target_global_velocity
		local measured_value = self.ship_global_velocity
		if(ImmortalShipBase.blade_mode) then
			target_value = self.target_global_position
			measured_value = self.ship_global_position
		end
		return 	getLocalPositionError(target_value,measured_value,self.ship_rotation)
	end
end

function ImmortalShipBase:overrideCalculateFeedbackControlValues()
	local ImmortalShipBase = self
	function self.ShipFrame:calculateFeedbackControlValues(error)
		return 	self.lateral_PID:run(error)
	end
end

function ImmortalShipBase:pointBlade(direction,args)
	local target_rotation = args.target_rotation
	local target_orbit_orientation = args.target_orbit_orientation
	local remote_move_angular = args.remote_move_angular
	local point = args.point
	target_rotation = target_orbit_orientation
	target_rotation = quaternion.fromToRotation(target_rotation:localPositiveY()*point,direction)*target_rotation
	if(remote_move_angular.y>0)then
		self.bladeTwistPose = math.fmod(self.bladeTwistPose+1,4)
	elseif(remote_move_angular.y<0)then
		self.bladeTwistPose = math.fmod(self.bladeTwistPose-1,4)
	end
	target_rotation = quaternion.fromRotation(target_rotation:localPositiveY(),self.bladeTwistPose*90)*target_rotation
	return target_rotation
end

ImmortalShipBase.bladeTwistPose = 0

function ImmortalShipBase:poseBlade(key,args)
	local pose={
		["point"]=function(args)
			local target_orbit_orientation = args.target_orbit_orientation
			return self:pointBlade(target_orbit_orientation:localPositiveZ(),args)
		end,
		["guard"]=function(args)
			local target_orbit_orientation = args.target_orbit_orientation
			return self:pointBlade(target_orbit_orientation:localPositiveX(),args)
		end,
	}
	if pose[key] then
		return pose[key](args)
	end
end


function ImmortalShipBase:safetyOn(active)
	redstone.setOutput("top",active)
end

function ImmortalShipBase:overrideShipFrameCustomFlightLoopBehavior()
	local ImmortalShipBase = self
	function self.ShipFrame:customFlightLoopBehavior(customFlightVariables)
		--[[
		useful variables to work with:
			self.target_global_position
			self.target_rotation
			self.target_global_velocity
			self.error
		]]--
		self.target_global_velocity = vector.new(0,0,0)
		
		if (not self.remoteControlManager.rc_variables.run_mode) then
			ImmortalShipBase:safetyOn(true)
			
			return
		end
		
		local target_orbit = self.sensors.orbitTargeting:getTargetSpatials()
		
		local target_orbit_position = target_orbit.position
		local target_orbit_orientation = target_orbit.orientation
		if(ImmortalShipBase.blade_mode) then
			
			ImmortalShipBase:safetyOn(not ImmortalShipBase.axe_mode)

			local point = ImmortalShipBase.axe_mode and 1 or -1
			local blade_pose_arguments = {	target_rotation=self.target_rotation,
											target_orbit_orientation=target_orbit_orientation,
											point=point,
											remote_move_angular=ImmortalShipBase.remote_move_angular}
			
			if(ImmortalShipBase.remote_move_linear.x<0)then --"keys.w"
				self.defensePose = false
			elseif(ImmortalShipBase.remote_move_linear.x>0)then--"keys.s"
				self.defensePose = true
			end
			if(self.defensePose) then
				self.target_rotation = ImmortalShipBase:poseBlade("guard",blade_pose_arguments)
			else
				self.target_rotation = ImmortalShipBase:poseBlade("point",blade_pose_arguments)
			end

			local formation_position = target_orbit_orientation:rotateVector3(self.remoteControlManager.rc_variables.orbit_offset)
			self.target_global_position = formation_position + target_orbit_position
		else
			ImmortalShipBase:safetyOn(false)
			ImmortalShipBase.remote_move_angular = ImmortalShipBase.remote_move_angular * 10
			self.target_rotation = quaternion.fromRotation(self.target_rotation:localPositiveX(),ImmortalShipBase.remote_move_angular.x)*self.target_rotation
			self.target_rotation = quaternion.fromRotation(self.target_rotation:localPositiveY(),ImmortalShipBase.remote_move_angular.y)*self.target_rotation
			self.target_rotation = quaternion.fromRotation(self.target_rotation:localPositiveZ(),ImmortalShipBase.remote_move_angular.z)*self.target_rotation
			self.target_global_velocity = self.ship_rotation:rotateVector3(ImmortalShipBase.remote_move_linear)*30
		end
	end
end

function ImmortalShipBase:init(instance_configs)
	self:initializeShipFrameClass(instance_configs)

	self:overrideInitFeedbackControllers()
	self:overrideCalculateFeedbackControlValueError()
	self:overrideCalculateFeedbackControlValues()

	self:overrideShipFrameCustomProtocols()
	self:overrideShipFrameGetCustomSettings()
	self:overrideShipFrameCustomFlightLoopBehavior()

	omniship_custom_config = instance_configs.omniship_custom_config or {}

	self:initCustom(omniship_custom_config)
	ImmortalShipBase.superClass.init(self)
end

function ImmortalShipBase:run()
	self.ShipFrame:run()
end
--overridden functions--

return ImmortalShipBase