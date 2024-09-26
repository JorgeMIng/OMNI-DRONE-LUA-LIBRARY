--Uses VS+Kontraption Gyro Blocks and HexTweaks4.0.0+HexxySkies's Nature's Push Glyph  in MC 1.20.1
local DroneBaseClassHexxySkies = require "lib.tilt_ships.DroneBaseClassHexxySkies"
local HexPatterns = require "lib.hexTweaks.HexPatterns"
local quaternion = require "lib.quaternions"
local flight_utilities = require "lib.flight_utilities"
local utilities = require "lib.utilities"
local clamp = utilities.clamp
local getLocalPositionError = flight_utilities.getLocalPositionError

local DroneBaseClassKontraptionHexxySkiesHybrid = DroneBaseClassHexxySkies:subclass()

function DroneBaseClassKontraptionHexxySkiesHybrid:initMovementPeripherals()
    self.shipControl=peripheral.find("ShipControlInterface") --for 1.20.1
    self.wand = peripheral.find("wand")
    self.IOTAS = HexPatterns.IOTAS
    self.Hex = HexPatterns(self.wand)
end

function DroneBaseClassKontraptionHexxySkiesHybrid:init(instance_configs)

    self:initMovementPeripherals()

	local configs = instance_configs

	configs.ship_constants_config = configs.ship_constants_config or {}

	configs.ship_constants_config.PID_SETTINGS = configs.ship_constants_config.PID_SETTINGS or
	{
        POS = {
			P=7,
            I=1,
            D=8,
		}
	}

    configs.ship_constants_config.MAX_ACCELERATION_LINEAR = configs.ship_constants_config.MAX_ACCELERATION_LINEAR or 50
	DroneBaseClassKontraptionHexxySkiesHybrid.superClass.init(self,configs)
end

function DroneBaseClassKontraptionHexxySkiesHybrid:initFeedbackControllers()
    self.lateral_PID = pidcontrollers.PID_Discrete_Vector(	self.ship_constants.PID_SETTINGS.POS.P,
                                                        self.ship_constants.PID_SETTINGS.POS.I,
                                                        self.ship_constants.PID_SETTINGS.POS.D,
                                                        -self.ship_constants.MAX_ACCELERATION_LINEAR,self.ship_constants.MAX_ACCELERATION_LINEAR)
end

function DroneBaseClassKontraptionHexxySkiesHybrid:calculateFeedbackControlValues(error)
	return 	self.lateral_PID:run(error.pos)
end

function DroneBaseClassKontraptionHexxySkiesHybrid:calculateFeedbackControlValueError()
	return 	{pos=getLocalPositionError(self.target_global_position,self.ship_global_position,self.ship_rotation)}
end

function DroneBaseClassKontraptionHexxySkiesHybrid:applyForceIotaPattern(iotaPattern,net_linear_acceleration)
    local mass_vector = net_linear_acceleration:normalize()*self.ship_mass
    
    local distribution = net_linear_acceleration:length()*2
    distribution = clamp(distribution,0,500)
    local distributed_force = mass_vector*0.5
    for i=0,distribution do
        table.insert(iotaPattern,self.IOTAS.duplicateTopStack)
        table.insert(iotaPattern,self.IOTAS.pushNextPatternToStack)
        table.insert(iotaPattern,distributed_force)
        table.insert(iotaPattern,self.IOTAS.ship_apply_force)
    end
    return iotaPattern
end

function DroneBaseClassKontraptionHexxySkiesHybrid:setGyro(trg_rot)
    local new_rot = trg_rot*self:getOffsetDefaultShipOrientation(quaternion.new(1,0,0,0)):inv()
    self.shipControl.setRotation(new_rot[2],new_rot[3],new_rot[4],new_rot[1])
end

function DroneBaseClassKontraptionHexxySkiesHybrid:calculateMovement()
    self:initFlightConstants()
    self:initFeedbackControllers()
    self:customPreFlightLoopBehavior()
    local customFlightVariables = self:customPreFlightLoopVariables()
    local prev_pos = vector.new(0,0,0)
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
        
        -- self.ship_global_velocity = self.sensors.shipReader:getVelocity()
		-- self.ship_global_velocity = vector.new(self.ship_global_velocity.x,self.ship_global_velocity.y,self.ship_global_velocity.z)
        --[[
        ship.getVelocity() seems to return a negative direction when moving slower than 0.05 m/s
        ]]--
        self.ship_global_velocity = (self.ship_global_position - prev_pos)/self.min_time_step
        prev_pos = self.ship_global_position
        
        --self:debugProbe({ship_global_velocity=self.ship_global_velocity})
        self.error = self:calculateFeedbackControlValueError()
        
        self.pid_output_linear_acceleration = self:calculateFeedbackControlValues(self.error)
        --self:debugProbe({2,pid=pid_output_linear_acceleration,error=self.error,MAX_ACCELERATION_LINEAR=self.ship_constants.MAX_ACCELERATION_LINEAR})
        local local_gravity_acceleration = self.ship_rotation:inv():rotateVector3(self.gravity_acceleration_vector)
        local net_linear_acceleration = self.pid_output_linear_acceleration - local_gravity_acceleration*2 --idk why gravity is doubled when using hex forces
        
        self:setGyro(self.target_rotation)
        self:castHex(net_linear_acceleration)
        sleep(self.min_time_step)
    end

end

return DroneBaseClassKontraptionHexxySkiesHybrid