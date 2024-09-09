--for VS+Kontraption in MC 1.20.1: they changed the shipTerminal name with a capital "S"
local DroneBaseClassKontraption = require "lib.tilt_ships.DroneBaseClassKontraption"

local DroneBaseClassKontraption1201 = DroneBaseClassKontraption:subclass()

function DroneBaseClassKontraption1201:initShipTerminal()
    self.shipControl=peripheral.find("ShipControlInterface") --for 1.20.1
end

return DroneBaseClassKontraption1201