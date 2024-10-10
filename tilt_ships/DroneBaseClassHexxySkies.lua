--This class only works for if you have hexxyskies and hextweaks 4.0.0
local DroneBaseClassSP = require "lib.tilt_ships.DroneBaseClassSP"
local flight_utilities = require "lib.flight_utilities"
local utilities = require "lib.utilities"
local pidcontrollers = require "lib.pidcontrollers"
local quaternion = require "lib.quaternions"
local HexPatterns = require "lib.hexTweaks.HexPatterns"
local JSON = require "lib.JSON"
local getQuaternionRotationError = flight_utilities.getQuaternionRotationError
local clamp = utilities.clamp


local DroneBaseClassHexxySkies = DroneBaseClassSP:subclass()

function DroneBaseClassHexxySkies:initMovementPeripherals()
    self.wand = peripheral.find("wand")
    self.IOTAS = HexPatterns.IOTAS
    self.Hex = HexPatterns(self.wand)
end

function DroneBaseClassHexxySkies:init(instance_configs)
    self:initMovementPeripherals()
    
	local configs = instance_configs

	configs.ship_constants_config = configs.ship_constants_config or {}

	configs.ship_constants_config.PID_SETTINGS = configs.ship_constants_config.PID_SETTINGS or
	{
		POS = {
			P=7,
            I=0,
            D=8,
		},
        ROT = {
			P=0.3,
            I=0,
            D=0.5,
		}
	}

    configs.ship_constants_config.MAX_ACCELERATION_LINEAR = configs.ship_constants_config.MAX_ACCELERATION_LINEAR or 500

    configs.ship_constants_config.MAX_ACCELERATION_ANGULAR = configs.ship_constants_config.MAX_ACCELERATION_ANGULAR or 500

	DroneBaseClassHexxySkies.superClass.init(self,configs)
end

function DroneBaseClassHexxySkies:initFeedbackControllers()
    self.lateral_PID = pidcontrollers.PID_Discrete_Vector(	self.ship_constants.PID_SETTINGS.POS.P,
                                                            self.ship_constants.PID_SETTINGS.POS.I,
                                                            self.ship_constants.PID_SETTINGS.POS.D,
                                                            -self.ship_constants.MAX_ACCELERATION_LINEAR,self.ship_constants.MAX_ACCELERATION_LINEAR)

    self.rotational_PID = pidcontrollers.PID_Discrete_Vector(	self.ship_constants.PID_SETTINGS.ROT.P,
                                                                self.ship_constants.PID_SETTINGS.ROT.I,
                                                                self.ship_constants.PID_SETTINGS.ROT.D,
                                                                -self.ship_constants.MAX_ACCELERATION_ANGULAR,self.ship_constants.MAX_ACCELERATION_ANGULAR)                                                        
end

function DroneBaseClassHexxySkies:calculateFeedbackControlValueError()
	return 	{
        rot=getQuaternionRotationError(self.target_rotation,self.ship_rotation),
        pos=self.target_global_position-self.ship_global_position
    }
end

function DroneBaseClassHexxySkies:calculateFeedbackControlValues(error)
    return
        self.rotational_PID:run(error.rot),
        self.lateral_PID:run(error.pos)
end



function DroneBaseClassHexxySkies:initFlightConstants()
	local ship_mass = self.sensors.shipReader:getMass()

    --CONFIGURABLES--
    local gravity_acceleration_vector = vector.new(0,-30,0)--VS gravity
    --CONFIGURABLES--

    self.min_time_step = self.ship_constants.min_time_step or 0.05 --how fast the computer should continuously loop (the max is 0.05 for ComputerCraft)
	self.ship_mass = ship_mass
	self.gravity_acceleration_vector = gravity_acceleration_vector
end

function DroneBaseClassHexxySkies:applyForceIotaPattern(iotaPattern,net_linear_acceleration)
    local mass_vector = net_linear_acceleration:normalize()*self.ship_mass
    
    local distribution = net_linear_acceleration:length()*2
    distribution = clamp(distribution,0,500)
    local distributed_force = mass_vector*0.5
    --print(textutils.serialise(distributed_force))
    for i=0, distribution do
        table.insert(iotaPattern,self.IOTAS.duplicateTopStack)
        table.insert(iotaPattern,self.IOTAS.pushNextPatternToStack)
        table.insert(iotaPattern,distributed_force)
        table.insert(iotaPattern,self.IOTAS.ship_apply_force_invariant)
    end
    return iotaPattern
end

function DroneBaseClassHexxySkies:applyTorqueIotaPattern(iotaPattern,net_angular_acceleration)
    local normalized_ang_acc = net_angular_acceleration:normalize()
    
    local distribution = net_angular_acceleration:length()*4
    distribution = clamp(distribution,0,500)
    local distributed_torque = matrix.mul(self.ship_constants.LOCAL_INERTIA_TENSOR,matrix({
                                            normalized_ang_acc.x,
                                            normalized_ang_acc.y,
                                            normalized_ang_acc.z}))
    distributed_torque = vector.new(distributed_torque[1][1],distributed_torque[2][1],distributed_torque[3][1])
    distributed_torque = distributed_torque*0.25
    --print(textutils.serialise(distributed_torque:length()/self.ship_mass))
    for i=0,distribution do
        table.insert(iotaPattern,self.IOTAS.duplicateTopStack)
        table.insert(iotaPattern,self.IOTAS.pushNextPatternToStack)
        table.insert(iotaPattern,distributed_torque)
        table.insert(iotaPattern,self.IOTAS.ship_apply_torque)
    end
    return iotaPattern
end

function DroneBaseClassHexxySkies:castHex(net_linear_acceleration,net_angular_acceleration)
    self.wand.clearStack()
    local position = ship.getWorldspacePosition()
    local center_of_mass = ship.getShipyardPosition()
    local iotaPattern = {
        self.IOTAS.pushNextPatternToStack,
        vector.new(center_of_mass.x,center_of_mass.y,center_of_mass.z),
        self.IOTAS.getShipByShipyardPosition,
    }
    iotaPattern=self:applyForceIotaPattern(iotaPattern,net_linear_acceleration)
    if(net_angular_acceleration ~= nil) then
        iotaPattern=self:applyTorqueIotaPattern(iotaPattern,net_angular_acceleration)
    end
    self.wand.pushStack(iotaPattern)
    self.Hex:executePattern()
end

function DroneBaseClassHexxySkies:calculateMovement()
    self:initFlightConstants()
    self:initFeedbackControllers()
    self:customPreFlightLoopBehavior()
    local customFlightVariables = self:customPreFlightLoopVariables()
    
    while self.run_firmware do
        if(self.ship_mass ~= self.sensors.shipReader:getMass()) then
			self:initFlightConstants()
		end
        
        self:customFlightLoopBehavior(customFlightVariables)
        self.ship_rotation = self.sensors.shipReader:getRotation(true)
		self.ship_rotation = quaternion.new(self.ship_rotation.w,self.ship_rotation.x,self.ship_rotation.y,self.ship_rotation.z)
        self.ship_rotation = self:getOffsetDefaultShipOrientation(self.ship_rotation)
  
        self.ship_global_position = self.sensors.shipReader:getWorldspacePosition()
		self.ship_global_position = vector.new(self.ship_global_position.x,self.ship_global_position.y,self.ship_global_position.z)
        
        self.ship_global_velocity = self.sensors.shipReader:getVelocity()
		self.ship_global_velocity = vector.new(self.ship_global_velocity.x,self.ship_global_velocity.y,self.ship_global_velocity.z)
        --self:debugProbe({ship_global_velocity=self.ship_global_velocity})
        self.error = self:calculateFeedbackControlValueError()
        
        local pid_output_angular_acceleration,pid_output_linear_acceleration_invariant = self:calculateFeedbackControlValues(self.error)

        local net_linear_acceleration_invariant = pid_output_linear_acceleration_invariant - self.gravity_acceleration_vector*2 --idk why gravity is doubled when using hex forces
        local net_angular_acceleration = pid_output_angular_acceleration

        self:castHex(net_linear_acceleration_invariant,net_angular_acceleration)
        sleep(self.min_time_step)
    end

end

return DroneBaseClassHexxySkies