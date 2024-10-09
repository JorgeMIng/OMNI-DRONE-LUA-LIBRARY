local DroneBaseClassSP = require "lib.tilt_ships.DroneBaseClassSP"
local flight_utilities = require "lib.flight_utilities"
local pidcontrollers = require "lib.pidcontrollers"
local quaternion = require "lib.quaternions"

local getLocalPositionError = flight_utilities.getLocalPositionError
local clamp_vector3 = utilities.clamp_vector3




local DroneBaseClassKontraption = DroneBaseClassSP:subclass()

function DroneBaseClassKontraption:initMovementPeripherals()
    local shipTerminalPeripheralName = "shipControlInterface" --for 1.18.2
    if(string.find(_HOST,"Minecraft 1.20.1")) then
        shipTerminalPeripheralName = "ShipControlInterface"
    end
    self.shipControl=peripheral.find(shipTerminalPeripheralName)
end

function DroneBaseClassKontraption:init(instance_configs)

    self:initMovementPeripherals()

	local configs = instance_configs

	configs.ship_constants_config = configs.ship_constants_config or {}

	configs.ship_constants_config.PID_SETTINGS = configs.ship_constants_config.PID_SETTINGS or
	{
		POS = {
			P=0.04,
            I=0.001,
            D=0.05,
		},
        VEL = {
			P=0.04,
            I=0.001,
            D=0.05,
		}
	}

    configs.ship_constants_config.ION_THRUSTERS_COUNT = configs.ship_constants_config.ION_THRUSTERS_COUNT or
    { --number of thrusters pointing in each cardinal direction
        pos=vector.new(2,2,2),
        neg=vector.new(2,2,2)
    }

    configs.ship_constants_config.IONTHRUST_CONFIG = configs.ship_constants_config.IONTHRUST_CONFIG or 4

	DroneBaseClassKontraption.superClass.init(self,configs)
end

function DroneBaseClassKontraption:initFeedbackControllers()
    self.lateral_PID = pidcontrollers.PID_Discrete_Vector(	self.ship_constants.PID_SETTINGS.POS.P,
                                                        self.ship_constants.PID_SETTINGS.POS.I,
                                                        self.ship_constants.PID_SETTINGS.POS.D,
                                                        -1,1)
end

function DroneBaseClassKontraption:calculateFeedbackControlValueError()
	return 	{pos=getLocalPositionError(self.target_global_position,self.ship_global_position,self.ship_rotation)}
end

function DroneBaseClassKontraption:calculateFeedbackControlValues(error)
	return 	self.lateral_PID:run(error.pos)
end



function DroneBaseClassKontraption:initFlightConstants()
	local ship_mass = self.sensors.shipReader:getMass()

    --CONFIGURABLES--
    local gravity_acceleration_vector = vector.new(0,-9.8,0)

    local ion_thruster_base_force = self.ship_constants.IONTHRUST_CONFIG*100000
    --CONFIGURABLES--

    local net_base_thrust = {
        pos=vector.new(0,0,0),
        neg=vector.new(0,0,0)
    }
    net_base_thrust.pos = self.ship_constants.ION_THRUSTERS_COUNT.pos*ion_thruster_base_force
    net_base_thrust.neg = self.ship_constants.ION_THRUSTERS_COUNT.neg*ion_thruster_base_force

    --[[ --WIP, waiting for kontraption update
    net_base_thrust.pos = net_base_thrust.pos + self.ship_constants.LIQUID_FUEL_THRUSTER_FORCE.pos
    net_base_thrust.neg = net_base_thrust.neg + self.ship_constants.LIQUID_FUEL_THRUSTER_FORCE.pos
    ]]--

    self.min_time_step = self.ship_constants.min_time_step or 0.05 --how fast the computer should continuously loop (the max is 0.05 for ComputerCraft)
	self.ship_mass = ship_mass
	self.gravity_acceleration_vector = gravity_acceleration_vector
    self.net_base_thrust = net_base_thrust
end

function DroneBaseClassKontraption:powerThrusters(power)
    if(type(power) == "number")then
		self.shipControl.setMovement(power,power,power)
	else
		self.shipControl.setMovement(power.x,power.y,power.z)
	end
end

function DroneBaseClassKontraption:calculateMovement()
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
  
        local new_rot = self.target_rotation*self:getOffsetDefaultShipOrientation(quaternion.new(1,0,0,0)):inv()
        self.shipControl.setRotation(new_rot[2],new_rot[3],new_rot[4],new_rot[1])
		
        self.ship_global_position = self.sensors.shipReader:getWorldspacePosition()
		self.ship_global_position = vector.new(self.ship_global_position.x,self.ship_global_position.y,self.ship_global_position.z)
        
        self.ship_global_velocity = self.sensors.shipReader:getVelocity()
		self.ship_global_velocity = vector.new(self.ship_global_velocity.x,self.ship_global_velocity.y,self.ship_global_velocity.z)
        --self:debugProbe({ship_global_velocity=self.ship_global_velocity})
        self.error = self:calculateFeedbackControlValueError()
        
        local pid_local_linear_power_percentage = self:calculateFeedbackControlValues(self.error)
        
        local local_gravity_acceleration = self.ship_rotation:inv():rotateVector3(self.gravity_acceleration_vector)

        local local_inv_gravity_force = -local_gravity_acceleration*self.ship_mass
        local net_power_percentage = local_inv_gravity_force
        local percentage_coefficients = vector.new(0,0,0)
        
        if(local_inv_gravity_force.x>=0) then
            percentage_coefficients.x = 1/self.net_base_thrust.pos.x
        elseif(local_inv_gravity_force.x<0)then
            percentage_coefficients.x = 1/self.net_base_thrust.neg.x
        end
        
        if(local_inv_gravity_force.y>=0)then
            percentage_coefficients.y = 1/self.net_base_thrust.pos.y
        elseif(local_inv_gravity_force.y<0)then
            percentage_coefficients.y = 1/self.net_base_thrust.neg.y
        end

        if(local_inv_gravity_force.z>=0)then
            percentage_coefficients.z = 1/self.net_base_thrust.pos.z
        elseif(local_inv_gravity_force.z<0)then
            percentage_coefficients.z = 1/self.net_base_thrust.neg.z
        end
        net_power_percentage.x = net_power_percentage.x*percentage_coefficients.x
        net_power_percentage.y = net_power_percentage.y*percentage_coefficients.y
        net_power_percentage.z = net_power_percentage.z*percentage_coefficients.z
        net_power_percentage = net_power_percentage + pid_local_linear_power_percentage

        net_power_percentage = clamp_vector3(net_power_percentage,-1,1)
        
        self:powerThrusters(net_power_percentage)
        sleep(self.min_time_step)
    end

end

return DroneBaseClassKontraption