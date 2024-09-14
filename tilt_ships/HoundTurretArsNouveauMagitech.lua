local HoundTurretBase = require "lib.tilt_ships.HoundTurretBase"

local HoundTurretArsNouveauMagitech = HoundTurretBase:subclass()

function HoundTurretArsNouveauMagitech:initRepulsorPeripheral()
	self.repulsor = peripheral.find("opencu:repulsor")

	self.repulsor.recalibrateByIdx(1)
	self.repulsor.setRadius(5)
	self.repulsor.setForce(1)
	self.repulsor.setVector(0,140,0)
end



HoundTurretArsNouveauMagitech.laserOn = false
function HoundTurretArsNouveauMagitech:activateLaserAnimation()
	if(not laserOn) then
		redstone.setOutput("right",false)
		redstone.setOutput("left",true)
		os.sleep(0.1)
		redstone.setOutput("left",false)
		self.laserOn = true
	end
end

function HoundTurretArsNouveauMagitech:deactivateLaserAnimation()
	if(laserOn) then
		redstone.setOutput("left",false)
		redstone.setOutput("right",true)
		os.sleep(0.1)
		redstone.setOutput("right",false)
		self.laserOn = false
	end
end

--overridden functions--
function HoundTurretArsNouveauMagitech:onGunsActivation()
	self.repulsor.pulse(0,0,0)
	self:activateLaserAnimation()
end

function HoundTurretArsNouveauMagitech:onGunsDeactivation()
	self:deactivateLaserAnimation()
end

function HoundTurretArsNouveauMagitech:alternateFire(step)
	local seq_1 = step==0
	-- local seq_2 = step==1
	-- local seq_3 = step==2
	--{modem_block, redstoneIntegrator_side}
	
	-- self:activateAllGuns({"front","front"},seq_1)
	-- self:activateAllGuns({"front","right"},seq_1)
	-- self:activateAllGuns({"front","left"},seq_2)
	-- self:activateAllGuns({"front","top"},seq_3)

	self:activateAllGuns({"front","front"},seq_1)
	self:activateAllGuns({"front","right"},seq_1)
	self:activateAllGuns({"front","left"},seq_1)
	self:activateAllGuns({"front","top"},seq_1)
end

function HoundTurretArsNouveauMagitech:getProjectileSpeed()
	return 140
end

function HoundTurretArsNouveauMagitech:init(instance_configs)
	self:initRepulsorPeripheral()
	HoundTurretArsNouveauMagitech.superClass.init(self,instance_configs)
end
--overridden functions--

return HoundTurretArsNouveauMagitech