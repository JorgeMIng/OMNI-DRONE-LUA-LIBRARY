matrix = require "lib.matrix"

local ShipReader = require "lib.sensory.ShipReader"
local ShipReaderSPRemote = ShipReader:subclass()

function ShipReaderSPRemote:init(ship_id)
	ShipReaderSPRemote.superClass.init(self)
	self.peripheral = peripheral.find("sp_radar")

	self.shipID = ship_id

	self.ship = self:initShip()
end

function ShipReaderSPRemote:getRotation(is_quaternion)
	local rot = self.ship.rotation
	return {w=rot.w,x=rot.x,y=rot.y,z=rot.z}
end

function ShipReaderSPRemote:getWorldspacePosition()
	return self.ship.pos
end

function ShipReaderSPRemote:getVelocity()
	return self.ship.velocity
end

function ShipReaderSPRemote:getShipID()
	return self.shipID
end

function ShipReaderSPRemote:getMass()
	return self.ship.mass
end

function ShipReaderSPRemote:getShipYardCenterOfMass()
	local com = self.ship.center_of_mass_in_a_ship
	return vector.new(com.x,com.y,com.z)
end

function ShipReaderSPRemote:getInertiaTensors()
	local moi = self.ship.moment_of_inertia_tensor
	local m = matrix(
			{	
				{moi[1.0][1.0],moi[1.0][2.0],moi[1.0][3.0]},
				{moi[2.0][1.0],moi[2.0][2.0],moi[2.0][3.0]},
				{moi[3.0][1.0],moi[3.0][2.0],moi[3.0][3.0]},
			})
	local inv_m = matrix.invert(m)
	local it = {
		x=vector.new(m[1][1],m[1][2],m[1][3]),
		y=vector.new(m[2][1],m[2][2],m[2][3]),
		z=vector.new(m[3][1],m[3][2],m[3][3])
	}
	local inv_it = {
		x=vector.new(inv_m[1][1],inv_m[1][2],inv_m[1][3]),
		y=vector.new(inv_m[2][1],inv_m[2][2],inv_m[2][3]),
		z=vector.new(inv_m[3][1],inv_m[3][2],inv_m[3][3])
	}
	return {it,inv_it}
end

function ShipReaderSPRemote:getInertiaMatrix()
	local moi = self.ship.moment_of_inertia_tensor
	local it = matrix(
			{	
				{moi[1.0][1.0],moi[1.0][2.0],moi[1.0][3.0]},
				{moi[2.0][1.0],moi[2.0][2.0],moi[2.0][3.0]},
				{moi[3.0][1.0],moi[3.0][2.0],moi[3.0][3.0]},
			})
	local inv_it = matrix.invert(it)
	return {it,inv_it}
end


function ShipReaderSPRemote:initShip()
	local ship = {}
	local ships = self.peripheral.scanForShips(500)
	for i,v in ipairs (ships) do
		if (v.id == self.shipID) then
			ship = v
			break
		end
	end
	return ship
end

function ShipReaderSPRemote:updateShipReader()
	if (self.peripheral) then
		local ship = {}
		local ships = self.peripheral.scanForShips(500)
		for i,v in ipairs (ships) do
			if (v.id == self.shipID) then
				ship = v
				break
			end
		end
		self.ship = ship
	end
end

return ShipReaderSPRemote