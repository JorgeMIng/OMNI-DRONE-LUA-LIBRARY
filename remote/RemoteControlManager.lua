local Object = require "lib.object.Object"

local Rec = require "lib.utilities_recursive"

local RemoteControlManager = Object:subclass()

--OVERRIDABLE FUNCTIONS--
function RemoteControlManager:getProtocols()
	return {
	
	["set_settings"] = function (class,args)
			self:setSettings(args)
	end,
	["get_settings_info"] = function (args)
		self:transmitCurrentSettingsToController()
	end,
	 ["default"] = function (self)
	end
	}
end

function RemoteControlManager:getCustomSettingsTemp()
	return {}
end

function RemoteControlManager:getSettings()
	local rcd_settings = {
		orbit_offset = self.rc_variables.orbit_offset,
		dynamic_positioning_mode = self.rc_variables.dynamic_positioning_mode,
		player_mounting_ship = self.rc_variables.player_mounting_ship,
	}

	
	local custom_settings = self:getCustomSettingsTemp()

	Rec.combined_params(custom_settings,rcd_settings,false)
	
	for key,value in pairs(custom_settings) do
		--print(key,value)
		rcd_settings[key] = value
	end
	
	return rcd_settings
end

function RemoteControlManager:setSettings(new_settings)
	for var_name,new_setting in pairs(new_settings) do
		if (self.rc_variables[var_name] ~= nil) then
			self.rc_variables[var_name] = new_setting
		end
	end
end
--OVERRIDABLE FUNCTIONS--



function RemoteControlManager:protocols(msg)
	return Rec.rec_switch_custum(msg.cmd,msg.args,"getProtocols",self,{conservedOld=true,protected_cases={},defaultFunc={}})
end

function RemoteControlManager:init(configs)--
	
	self.DRONE_ID = configs.DRONE_ID
	self.DRONE_TYPE = configs.DRONE_TYPE
	self.DRONE_TO_REMOTE_CHANNEL = configs.DRONE_TO_REMOTE_CHANNEL
	self.REPLY_DUMP_CHANNEL = configs.REPLY_DUMP_CHANNEL
	self.modem = configs.modem
	self.rc_variables = {
		dynamic_positioning_mode = false,--deactivate to have drone act like stationary turret
		player_mounting_ship = false,--activate for aiming while "sitting" on a ship
		orbit_offset = vector.new(0,0,0),--flight formation around orbit_target
	}
	
	if (configs.rc_variables) then
		for key,value in pairs(configs.rc_variables) do
			self.rc_variables[key] = value
		end
	end
	RemoteControlManager.superClass.init(self,configs)
end

function RemoteControlManager:transmitCurrentSettingsToController()
	print("transmitCurrentSettingsToController")
	
	local settings=self:getSettings()
	local msg = {drone_ID=self.DRONE_ID,protocol="drone_settings_update",partial_profile={settings=settings,drone_type=self.DRONE_TYPE}}

	self:transmitToController(msg)
end

function RemoteControlManager:transmitToController(msg)
	self.modem.transmit(self.DRONE_TO_REMOTE_CHANNEL, self.REPLY_DUMP_CHANNEL, msg)
end

return RemoteControlManager