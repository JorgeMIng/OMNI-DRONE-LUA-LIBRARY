--This class only works for Command Computers
local DroneBaseClassSP = require "lib.tilt_ships.DroneBaseClassSP"
local flight_utilities = require "lib.flight_utilities"
local pidcontrollers = require "lib.pidcontrollers"
local quaternion = require "lib.quaternions"

local getQuaternionRotationError = flight_utilities.getQuaternionRotationError

local DroneBaseClassCommandComputer = DroneBaseClassSP:subclass()

function DroneBaseClassCommandComputer:init(instance_configs)
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
			P=0.4,
            I=0,
            D=0.4,
		}
	}

    configs.ship_constants_config.MAX_ACCELERATION_LINEAR = configs.ship_constants_config.MAX_ACCELERATION_LINEAR or 10000000

    configs.ship_constants_config.MAX_ACCELERATION_ANGULAR = configs.ship_constants_config.MAX_ACCELERATION_ANGULAR or 10000000

	DroneBaseClassCommandComputer.superClass.init(self,configs)
end

function DroneBaseClassCommandComputer:initFeedbackControllers()
    self.lateral_PID = pidcontrollers.PID_Discrete_Vector(	self.ship_constants.PID_SETTINGS.POS.P,
                                                            self.ship_constants.PID_SETTINGS.POS.I,
                                                            self.ship_constants.PID_SETTINGS.POS.D,
                                                            -self.ship_constants.MAX_ACCELERATION_LINEAR,self.ship_constants.MAX_ACCELERATION_LINEAR)

    self.rotational_PID = pidcontrollers.PID_Discrete_Vector(	self.ship_constants.PID_SETTINGS.ROT.P,
                                                                self.ship_constants.PID_SETTINGS.ROT.I,
                                                                self.ship_constants.PID_SETTINGS.ROT.D,
                                                                -self.ship_constants.MAX_ACCELERATION_ANGULAR,self.ship_constants.MAX_ACCELERATION_ANGULAR)                                                        
end

function DroneBaseClassCommandComputer:calculateFeedbackControlValueError()
	return 	{
        rot=getQuaternionRotationError(self.target_rotation,self.ship_rotation),
        pos=self.target_global_position-self.ship_global_position
    }
end

function DroneBaseClassCommandComputer:calculateFeedbackControlValues(error)
	local rot_output = self.rotational_PID:run(error.rot)
    return
    matrix({rot_output.x,rot_output.y,rot_output.z}),
        self.lateral_PID:run(error.pos)
end



function DroneBaseClassCommandComputer:initFlightConstants()
	local ship_mass = self.sensors.shipReader:getMass()

    --CONFIGURABLES--
    local gravity_acceleration_vector = vector.new(0,-30,0)--VS gravity
    --CONFIGURABLES--

    self.min_time_step = self.ship_constants.min_time_step or 0.05 --how fast the computer should continuously loop (the max is 0.05 for ComputerCraft)
	self.ship_mass = ship_mass
	self.gravity_acceleration_vector = gravity_acceleration_vector
end

function DroneBaseClassCommandComputer:apply(net_torque,net_force)
    ship.applyRotDependentTorque(net_torque.x,net_torque.y,net_torque.z)
    ship.applyInvariantForce(net_force.x,net_force.y,net_force.z)
end

function DroneBaseClassCommandComputer:calculateMovement()
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

        local net_linear_acceleration_invariant = pid_output_linear_acceleration_invariant - self.gravity_acceleration_vector
        local net_force_invariant = net_linear_acceleration_invariant*self.ship_mass

        local net_torque = matrix.mul(self.ship_constants.LOCAL_INERTIA_TENSOR,pid_output_angular_acceleration)
        net_torque=vector.new(net_torque[1][1],net_torque[2][1],net_torque[3][1])


        self:apply(net_torque,net_force_invariant)
        sleep(self.min_time_step)
    end

end

return DroneBaseClassCommandComputer