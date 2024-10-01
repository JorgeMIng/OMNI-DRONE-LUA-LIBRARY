local quaternion = require "lib.quaternions"
local flight_utilities = require "lib.flight_utilities"


local DroneBaseClassKontraptionHexxySkiesHybrid = require "lib.tilt_ships.DroneBaseClassKontraptionHexxySkiesHybrid"
local Object = require "lib.object.Object"

local getLocalPositionError = flight_utilities.getLocalPositionError

local Panabas = Object:subclass()

--overridable functions--
function Panabas:setShipFrameClass(configs) --override this to set ShipFrame Template
	self.ShipFrame = DroneBaseClassKontraptionHexxySkiesHybrid(configs)
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
			P=7,
            I=0,
            D=8,
		},
        VEL = {
			P = 1,
			I = 0,
			D = 0
		},
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
				self:initFeedbackControllers()
			end,
			["axe_mode"]= function (args)
				panabas.axe_mode = not panabas.axe_mode
			end,
			["move"]= function (arg)
				panabas.remote_move_linear = vector.new(arg.linear.x,arg.linear.y,arg.linear.z)
				local angle = vector.new(arg.angular.x,arg.angular.y,arg.angular.z)
				panabas.remote_move_angular = angle
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
Panabas.remote_move_linear = vector.new(0,0,0)
Panabas.remote_move_angular = vector.new(0,0,0)
Panabas.axe_mode = true
Panabas.blade_mode = false
Panabas.defensePose = false
function Panabas:overrideInitFeedbackControllers()
	local panabas = self
	function self.ShipFrame:initFeedbackControllers()
		if(panabas.blade_mode) then
			self.lateral_PID = pidcontrollers.PID_Discrete_Vector(	self.ship_constants.PID_SETTINGS.POS.P,
																	self.ship_constants.PID_SETTINGS.POS.I,
																	self.ship_constants.PID_SETTINGS.POS.D,
																	-self.ship_constants.MAX_ACCELERATION_LINEAR,self.ship_constants.MAX_ACCELERATION_LINEAR)
			return
		end
		self.lateral_PID = pidcontrollers.PID_Discrete_Vector(	self.ship_constants.PID_SETTINGS.VEL.P,
																self.ship_constants.PID_SETTINGS.VEL.I,
																self.ship_constants.PID_SETTINGS.VEL.D,
																-self.ship_constants.MAX_ACCELERATION_LINEAR,self.ship_constants.MAX_ACCELERATION_LINEAR)
	end
end

function Panabas:overrideCalculateFeedbackControlValueError()
	local panabas = self
	function self.ShipFrame:calculateFeedbackControlValueError()
		local target_value = self.target_global_velocity
		local measured_value = self.ship_global_velocity
		if(panabas.blade_mode) then
			target_value = self.target_global_position
			measured_value = self.ship_global_position
		end
		return 	getLocalPositionError(target_value,measured_value,self.ship_rotation)
	end
end

function Panabas:overrideCalculateFeedbackControlValues()
	local panabas = self
	function self.ShipFrame:calculateFeedbackControlValues(error)
		if(not panabas.blade_mode) then
			return 	self.lateral_PID:run(error)/self.min_time_step
		end
		return 	self.lateral_PID:run(error)
	end
end

function Panabas:pointBlade(direction,args)
	local target_rotation = args.target_rotation
	local target_orbit_orientation = args.target_orbit_orientation
	local remote_move_angular = args.remote_move_angular
	local point = args.point
	target_rotation = target_orbit_orientation
	target_rotation = quaternion.fromToRotation(target_rotation:localPositiveZ(),target_orbit_orientation:localPositiveY())*target_rotation
	target_rotation = quaternion.fromToRotation(target_rotation:localPositiveY()*point,direction)*target_rotation
	target_rotation = quaternion.fromToRotation(target_rotation:localPositiveZ(),target_orbit_orientation:localPositiveY())*target_rotation
	if(remote_move_angular.y>0)then
		self.bladeTwistPose = math.fmod(self.bladeTwistPose+1,4)
	elseif(remote_move_angular.y<0)then
		self.bladeTwistPose = math.fmod(self.bladeTwistPose-1,4)
	end
	target_rotation = quaternion.fromRotation(target_rotation:localPositiveY(),self.bladeTwistPose*90)*target_rotation
	return target_rotation
end

Panabas.bladeTwistPose = 0

function Panabas:poseBlade(key,args)
	local pose={
		["point"]=function(args)
			local target_orbit_orientation = args.target_orbit_orientation
			local position_offset = target_orbit_orientation:localPositiveX()*-25
			
			local target_orbit_position = args.target_orbit_position + position_offset
			local blade_direction = self.ShipFrame.target_global_position - target_orbit_position
			self.ShipFrame:debugProbe({blade_direction=blade_direction})
			return self:pointBlade(blade_direction:normalize(),args)
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


function Panabas:safetyOn(active)
	redstone.setOutput("right",active)
end

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
		self.target_global_velocity = vector.new(0,0,0)
		--self:debugProbe({target_global_velocity=self.target_global_velocity,error=self.error})
		if (not self.remoteControlManager.rc_variables.run_mode) then
			
			panabas:safetyOn(true)
			
			return
		end

		local target_orbit = self.sensors.orbitTargeting:getTargetSpatials()
		
		local target_orbit_position = target_orbit.position
		local target_orbit_orientation = target_orbit.orientation
		if(panabas.blade_mode) then
			
			panabas:safetyOn(not panabas.axe_mode)
			
			local formation_position = target_orbit_orientation:rotateVector3(self.remoteControlManager.rc_variables.orbit_offset)
			self.target_global_position = formation_position + target_orbit_position

			local point = panabas.axe_mode and 1 or -1
			local blade_pose_arguments = {	target_rotation=self.target_rotation,
											target_orbit_orientation=target_orbit_orientation,
											target_orbit_position = target_orbit_position,
											point=point,
											remote_move_angular=panabas.remote_move_angular}
			
			if(panabas.remote_move_linear.x<0)then --"keys.w"
				self.defensePose = false
			elseif(panabas.remote_move_linear.x>0)then--"keys.s"
				self.defensePose = true
			end
			if(self.defensePose) then
				self.target_rotation = panabas:poseBlade("guard",blade_pose_arguments)
			else
				self.target_rotation = panabas:poseBlade("point",blade_pose_arguments)
			end

			
			
		else
			panabas:safetyOn(false)
			panabas.remote_move_angular = panabas.remote_move_angular * 10
			self.target_rotation = quaternion.fromRotation(self.target_rotation:localPositiveX(),panabas.remote_move_angular.x)*self.target_rotation
			self.target_rotation = quaternion.fromRotation(self.target_rotation:localPositiveY(),panabas.remote_move_angular.y)*self.target_rotation
			self.target_rotation = quaternion.fromRotation(self.target_rotation:localPositiveZ(),panabas.remote_move_angular.z)*self.target_rotation
			self.target_global_velocity = self.ship_rotation:rotateVector3(panabas.remote_move_linear)*100
			
		end
		
	end
end

function Panabas:init(instance_configs)
	self:initializeShipFrameClass(instance_configs)

	self:overrideInitFeedbackControllers()
	self:overrideCalculateFeedbackControlValueError()
	self:overrideCalculateFeedbackControlValues()

	self:overrideShipFrameCustomProtocols()
	self:overrideShipFrameGetCustomSettings()
	self:overrideShipFrameCustomFlightLoopBehavior()
	--self:overridecalculateMovement()

	omniship_custom_config = instance_configs.omniship_custom_config or {}

	self:initCustom(omniship_custom_config)
	Panabas.superClass.init(self)
end

function Panabas:run()
	self.ShipFrame:run()
end
--overridden functions--

return Panabas