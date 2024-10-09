--OpenCU is not available in 1.20.1 yet. Install a MindSplice Staff From Hexcasting as a side peripheral (make sure to have HexTweaks installed)
local HoundTurretBase = require "lib.tilt_ships.HoundTurretBase"
local HoundTurretArsNouveauMagitech = require "lib.tilt_ships.HoundTurretArsNouveauMagitech"
local DroneBaseClassKontraption = require "lib.tilt_ships.DroneBaseClassKontraption"
local HexPatterns = require "lib.hexTweaks.HexPatterns"
local utilities = require"lib.utilities"
local quaternion = require "lib.quaternions"

local IOTAS = HexPatterns.IOTAS
local ArrayExtract = utilities.ArrayExtract

local MAX_SPELL_RANGE = 5
local PULSE_STRENGTH = 10

local FILTER_PUSH_ONLY = {-- true to keep in scan; false to remove from scan.
    ["Seat"]=false,
    ["entity.vs_clockwork.sequenced_seat"]=false,
    ["entity.valkyrienskies.ship_mounting_entity"]=false,
    ["entity.kontraption.kontraption_ship_mounting_entity"]=false,
    ["Pitch Contraption"]=false,
    ["Cannon Carriage"]=false,
    ["Spell Projectile"]=true,
    ["PHO"]=false
}

function filterScanPush(scan, i,j) -- Return true to keep the value, or false to discard it. if it's not in the list the value is kept
    local key = scan[i].name
    return FILTER_PUSH_ONLY[key] == nil and true or FILTER_PUSH_ONLY[key]
end

local HoundTurretArsNouveauMagitech1201 = HoundTurretArsNouveauMagitech:subclass()

--overridden functions--
function HoundTurretArsNouveauMagitech1201:setShipFrameClass(configs)
	self.ShipFrame = DroneBaseClassKontraption(configs)
end

function HoundTurretArsNouveauMagitech1201:onGunsActivation()
	self:hexBoostBullets()
	self:activateLaserAnimation()
end

function HoundTurretArsNouveauMagitech1201:getProjectileSpeed()
	return 140
end

function HoundTurretArsNouveauMagitech1201:alternateFire(step)
	local seq_1 = step==0
	-- local seq_2 = step==1
	-- local seq_3 = step==2
	--{modem_block, redstoneIntegrator_side}
	
	-- self:activateAllGuns({"front","front"},seq_1)
	-- self:activateAllGuns({"front","right"},seq_1)
	-- self:activateAllGuns({"front","left"},seq_2)
	-- self:activateAllGuns({"front","top"},seq_3)

	self:activateAllGuns({"top","front"},seq_1)
	self:activateAllGuns({"top","right"},seq_1)
	self:activateAllGuns({"top","left"},seq_1)
	self:activateAllGuns({"top","top"},seq_1)
end

function HoundTurretArsNouveauMagitech1201:initRepulsorPeripheral()
	self.wand = peripheral.find("wand")
	self.Hex = HexPatterns(self.wand)
end
--overridden functions--

function HoundTurretArsNouveauMagitech1201:hexBoostBullets()
	local position = self.ShipFrame.ship_global_position
	self.Hex:scanEntitiesInZone(position,MAX_SPELL_RANGE,IOTAS.getEntitiesInZone.non_item)
	local scan = self.wand.getStack()[1]
	if(#scan>0) then
		local scan_push_only = ArrayExtract(scan, filterScanPush)
		if(#scan_push_only>0) then
			local ship_rotation = self.ShipFrame.ship_rotation--ship.getQuaternion()
            --ship_rotation = quaternion.new(ship_rotation.w,ship_rotation.x,ship_rotation.y,ship_rotation.z)
			local pulse_direction = ship_rotation:localPositiveY()
			
			self.wand.clearStack()
            self.wand.pushStack(self.Hex:pulseEntityIota(pulse_direction,PULSE_STRENGTH))
            self.wand.pushStack(scan_push_only)
            self.Hex:executePatternOnTable()
		end
	end
	self.wand.clearStack()
end



return HoundTurretArsNouveauMagitech1201