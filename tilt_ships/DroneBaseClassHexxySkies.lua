--This class only works for if you have hexxyskies and hextweaks 4.0.0
local DroneBaseClassSP = require "lib.tilt_ships.DroneBaseClassSP"
local flight_utilities = require "lib.flight_utilities"
local pidcontrollers = require "lib.pidcontrollers"
local quaternion = require "lib.quaternions"

local getQuaternionRotationError = flight_utilities.getQuaternionRotationError
local getLocalPositionError = flight_utilities.getLocalPositionError
local clamp_vector3 = utilities.clamp_vector3

local wand = peripheral.find("wand")

local DroneBaseClassHexxySkies = DroneBaseClassSP:subclass()

function DroneBaseClassHexxySkies:init(instance_configs)
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
    local min_time_step = 0.05 --how fast the computer should continuously loop (the max is 0.05 for ComputerCraft)
	local ship_mass = self.sensors.shipReader:getMass()

    --CONFIGURABLES--
    local gravity_acceleration_vector = vector.new(0,-30,0)--VS gravity
    --CONFIGURABLES--

    self.min_time_step = min_time_step
	self.ship_mass = ship_mass
	self.gravity_acceleration_vector = gravity_acceleration_vector*2 --idk why gravity is doubled when using hex forces
end

local IOTAS = {
    chat={
            startDir = "NORTH_EAST",
            angles = "de",
    },
    eraseTopOfStack={
        startDir = "SOUTH_EAST",
        angles = "a",
    },
    pushNextPatternToStack={
        startDir = "WEST",
        angles = "qqqaw",
    },
    getEntityLookVector={--Alidade's Purification (entity → vector)
            startDir = "EAST",
            angles = "wa",
    },

    duplicateTopStack={--Gemini Decomposition (any → any, any)
            startDir = "EAST",
            angles = "aadaa",
    },

    getEntityPosition={--Compass' Purification (entity → vector)
            startDir = "NORTH_EAST",
            angles = "aa",
    },

    getEntitiesInZone={
            animals={--Zone Dstl.: Animal (vector, number → list)
                        startDir = "SOUTH_EAST",
                        angles = "qqqqqwdeddwa",
                    },
            non_player={--Zone Dstl.: Non-Player (vector, number → list)
                        startDir = "NORTH_EAST",
                        angles = "eeeeewaqaawe",
                    },
            non_living={
                startDir = "NORTH_EAST",
                angles = "eeeeewaqaawd",
              },
            non_item={
                startDir = "NORTH_EAST",
                angles = "eeeeewaqaaww",
              }
    },
    multiply={--Multiplicative Dstl. (num/vec, num/vec → num/vec)
            startDir = "SOUTH_EAST",
            angles = "waqaw",
    },
    divide={
        startDir = "NORTH_EAST",
        angles = "wdedw",
    },
    add={
        startDir = "NORTH_EAST",
        angles = "waaw",
    },
    subtract={
            startDir = "NORTH_WEST",
            angles = "wddw",
    },
    getLength={
        startDir = "NORTH_EAST",
        angles = "wqaqw",
    },
    getAbsValue={
        startDir = "NORTH_EAST",
        angles = "wqaqw",
    },
    impulse={--Impulse (entity, vector →)
        startDir = "SOUTH_WEST",
        angles = "awqqqwaqw",
    },
    
    thothsGambit={--Thoth's Gambit (list of patterns, list → list)
            startDir = "NORTH_EAST",
            angles = "dadad",
        },
    
    hermesGambit={--Hermes' Gambit ([pattern] | pattern → many)
            startDir = "SOUTH_EAST",
            angles = "deaqq",
        },
    pushListContentToStack={
            startDir = "NORTH_WEST",
            angles = "qwaeawq",
        },
    FIVE={
            startDir = "SOUTH_EAST",
            angles = "aqaaq",
        },
    TEN={
            startDir = "SOUTH_EAST",
            angles = "aqaae",
        },
    summonWisp={
            startDir = "NORTH_WEST",
            angles = "aqaweewaqawee",
    },
    --Ignite Block (vector →)
    igniteBlock={
        startDir = "SOUTH_EAST",
        angles = "aaqawawa",
    },
    fireBall={
        startDir = "EAST",
        angles = "ddwddwdd",
    },

    scan_ships={
        startDir = "EAST",
        angles = "wawwwaqaweeee",
    },
    ship_apply_force={
        startDir = "EAST",
        angles = "wawwwawawwqqqwwaq",
    },
    ship_apply_force_invariant={
        startDir = "EAST",
        angles = "wawwwawawwqqqwwaqw",
    },
    ship_apply_torque={
        startDir = "EAST",
        angles = "wawwwawawwqqqwwawa",
    },
    ship_apply_torque_invariant={
        startDir = "EAST",
        angles = "wawwwawawwqqqwwaqqd",
    },
    ship_get_name={
        startDir = "EAST",
        angles = "wawwwaqwa",
    },
    getTableLength={
        startDir = "NORTH_EAST",
        angles = "wqaqw",
    },
    getStackSize={
        startDir = "NORTH_WEST",
        angles = "qwaeawqaeaqa",
    }
}

function DroneBaseClassHexxySkies:executePatternOnTable()
    wand.runPattern(IOTAS.thothsGambit)
end

function DroneBaseClassHexxySkies:executePattern()
    wand.runPattern(IOTAS.hermesGambit)
end

function DroneBaseClassHexxySkies:applyInvariantForceIotaPattern(iotaPattern,net_linear_acceleration_invariant)
    local mass_vector = net_linear_acceleration_invariant:normalize()*self.ship_mass
    for i=0,net_linear_acceleration_invariant:length() do
        table.insert(iotaPattern,IOTAS.duplicateTopStack)
        table.insert(iotaPattern,IOTAS.pushNextPatternToStack)
        table.insert(iotaPattern,mass_vector)
        table.insert(iotaPattern,IOTAS.ship_apply_force_invariant)
    end
    return iotaPattern
end

function DroneBaseClassHexxySkies:applyTorqueIotaPattern(iotaPattern,net_angular_acceleration)
    local normalized_ang_acc = net_angular_acceleration:normalize()
    local distributed_torque = matrix.mul(self.ship_constants.LOCAL_INERTIA_TENSOR,matrix({
                                            normalized_ang_acc.x,
                                            normalized_ang_acc.y,
                                            normalized_ang_acc.z}))
    distributed_torque = vector.new(distributed_torque[1][1],distributed_torque[2][1],distributed_torque[3][1])
    for i=0,net_angular_acceleration:length() do
        table.insert(iotaPattern,IOTAS.duplicateTopStack)
        table.insert(iotaPattern,IOTAS.pushNextPatternToStack)
        table.insert(iotaPattern,distributed_torque)
        table.insert(iotaPattern,IOTAS.ship_apply_torque)
    end
    return iotaPattern
end

function DroneBaseClassHexxySkies:castHex(net_angular_acceleration,net_linear_acceleration_invariant)
    local position = ship.getWorldspacePosition()
    local iotaPattern = {
        IOTAS.pushNextPatternToStack,
        vector.new(position.x,position.y,position.z),
        IOTAS.pushNextPatternToStack,
        1,
        IOTAS.scan_ships,
    }
    iotaPattern=self:applyInvariantForceIotaPattern(iotaPattern,net_linear_acceleration_invariant)
    iotaPattern=self:applyTorqueIotaPattern(iotaPattern,net_angular_acceleration)
    wand.pushStack(iotaPattern)
    self:executePattern()
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

        local net_linear_acceleration_invariant = pid_output_linear_acceleration_invariant - self.gravity_acceleration_vector
        local net_angular_acceleration = pid_output_angular_acceleration

        self:castHex(net_angular_acceleration,net_linear_acceleration_invariant)
        sleep(self.min_time_step)
    end

end

return DroneBaseClassHexxySkies