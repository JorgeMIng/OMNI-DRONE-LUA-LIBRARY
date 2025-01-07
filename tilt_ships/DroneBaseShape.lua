

local ShipFrameController = require "lib.tilt_ships.ShipFrameController"

local quaternion = require "lib.quaternions"
local utilities = require "lib.utilities"
local targeting_utilities = require "lib.targeting_utilities"
local player_spatial_utilities = require "lib.player_spatial_utilities"
local flight_utilities = require "lib.flight_utilities"
local list_manager = require "lib.list_manager"

local ShipFrameController = require "lib.tilt_ships.ShipFrameController"

local FigureLoader = require("lib.figures.FigureLoader")

local sqrt = math.sqrt
local abs = math.abs
local max = math.max
local min = math.min
local mod = math.fmod
local cos = math.cos
local sin = math.sin
local acos = math.acos
local pi = math.pi
local clamp = utilities.clamp
local sign = utilities.sign

local quadraticSolver = utilities.quadraticSolver
local getTargetAimPos = targeting_utilities.getTargetAimPos
local getQuaternionRotationError = flight_utilities.getQuaternionRotationError
local getLocalPositionError = flight_utilities.getLocalPositionError
local adjustOrbitRadiusPosition = flight_utilities.adjustOrbitRadiusPosition
local getPlayerLookVector = player_spatial_utilities.getPlayerLookVector
local getPlayerHeadOrientation = player_spatial_utilities.getPlayerHeadOrientation
local rotateVectorWithPlayerHead = player_spatial_utilities.rotateVectorWithPlayerHead
local PlayerVelocityCalculator = player_spatial_utilities.PlayerVelocityCalculator
local RadarSystems = targeting_utilities.RadarSystems
local TargetingSystem = targeting_utilities.TargetingSystem
local IntegerScroller = utilities.IntegerScroller
local IndexedListScroller = list_manager.IndexedListScroller
local Object = require "lib.object.Object"

local DroneBaseShape = ShipFrameController:subclass()






function DroneBaseShape:getOffsetDefaultShipOrientation(default_ship_orientation)
	local angle_offset = self.angle_offset or 0
	angle_offset = -90 + angle_offset
	return quaternion.fromRotation(default_ship_orientation:localPositiveY(), angle_offset)*default_ship_orientation -- Rotates the default orientation so that the nose of the ship is aligned with it's local +X axis
end


--function DroneBaseShape:getOffsetDefaultShipOrientation(default_ship_orientation)
--	return quaternion.fromRotation(default_ship_orientation:localPositiveY(), 0)*default_ship_orientation -- Rotates the default orientation so that the nose of the ship is aligned with it's local +X axis
--end


function DroneBaseShape:radar_ships()
	return self.ShipFrame.sensors.radars.targeting.ship_targets
end

function DroneBaseShape:set_range(range)
	self.ShipFrame.sensors.radars.targeting.range=range
end

function DroneBaseShape:ValidTrilaterationReq(ship_id)
	local actual_time = os.clock()
	if ship_id==ship.getId() then
		return false
	end
	if not self.ShipFrame.trilateration_table[ship_id] then
		return true
	end
	if (actual_time-self.ShipFrame.trilateration_table[ship_id].time)>self.ShipFrame.trilateration_time_life then
		return true
	end

	return false

end


--my_pos=self.ShipFrame.ship_global_position


function DroneBaseShape:addEntriFromRequest(info)
	--print("new distances",info.id,info.distance)
	self.ShipFrame.trilateration_table[info.id]={id=info.id,distance=info.distance,time=info.time,
	lost=info.lost,is_master=info.is_master,relative_pos=info.relative_pos,real_pos=info.real_pos,in_figure=info.in_figure}
	
end

function DroneBaseShape:TrilaterationRequest(radar_targets)
	--filter by need to update on 
	for _,ship_entity in pairs(radar_targets) do
		
		if self:ValidTrilaterationReq(ship_entity.id) then
			local time = os.clock()
			local relative_pos = self.ShipFrame.ship_global_position:sub(self.ShipFrame.coordinate_center)
			
			local is_master= ship.getId()==tonumber(self.ShipFrame.sensors:getDesignatedMaster(false))
			
			local messege ={lost=self.ShipFrame.lost,in_figure=self.ShipFrame.in_figure,is_master=is_master,relative_pos=relative_pos,real_pos=self.ShipFrame.ship_global_position}
			--print("sending request to ",ship_entity.id)
			self.ShipFrame:redirectMessege({sender_id=ship_entity.id,channel=self.ShipFrame.com_channels.DRONE_TO_DRONE_CHANNEL},{message=messege,protocol="exchange_lateration_info"})
		end

	end


end


--for _,ship in pairs(ship_list) do
	--if ship.id~= ship.getId() and filter_func()
	--print(ship.id)
	--do
--	print(ship.id)
--end






function DroneBaseShape:getProtocols()
	
	return {

		["stop_drone"] = function (self,mode)
			self.stop_drone=mode
		end,
		
		["objective_pos"] = function (self,pos) 
			self.objective_global_position = pos
			
		end,
		["movement_mode"] = function (self,mode) 
			self.movement_mode = mode
			if not self.experiment_online then
				self.drone_state="MV_"..self.movement_mode
			end
			
		end,
		["coordinate_center"] = function (self,coordinate_center)
			
			self.coordinate_center = utilities.table_to_vector(coordinate_center)
			
		end,

		["angle_offset"] = function (self,X_angle_offset) 
			self.angle_offset = X_angle_offset
			
		end,

		["experiment_online"] = function (self,mode) 
			print("recived experiment",mode)
			self.experiment_online = mode
			self.shuffling=false
			if ship.getId()==tonumber(self.sensors:getDesignatedMaster(false))then
				self.lost=false
			else
				self.lost=true
			end
			
			if self.experiment_online then
				self.drone_state="W_SHUFFLE"
			else
				self.drone_state="MV_"..self.movement_mode
				
			end
			self.started_experiment=false
			
		end,

		["shape"] = function (self,figure_data)
			if figure_data and figure_data ~="NONE" and figure_data.figure_name ~="NONE" then
	
				print("recived figure",figure_data)
				
				--local figure_instance = Object.deserialize(shape.figure)
				local figure_instance = FigureLoader.load_figure(figure_data.figure_type,figure_data.figure_name,figure_data.params)
				self.shape=figure_instance
			end
			
		end,
		["set_shape_params"] = function (self,params) 
			if self.shape then
				self.shape.setParams(params)
			end
		end,

		["set_boundaries"] = function (self,boundaries)
			local boundaries_vec = {}
			for bound in pairs(boundaries) do
				table.insert(boundaries_vec,utilities.table_to_vector(bound))
			end
			self.boundaries=boundaries_vec
		end,
		["set_lost"]=function (self,lost) 
			print("set i am lost ",lost)
			self.lost = lost
			
		end,

		["drone_state"] = function (self,state) 
			print("state",state)
			if state then
			self.drone_state = state
			end
		end,

		["shuffle"] = function (self,args) 
			print("shuffle")
			self.shuffling=true
			if ship.getId()==tonumber(self.sensors:getDesignatedMaster(false))then
				self.lost=false
			else
				self.lost=true
			end
			self.started_experiment=false
			self.drone_state="SHUFFLING"
			
			
		end,

		["start_experiment"] = function (self,args) 
			print("start")
			if ship.getId()==tonumber(self.sensors:getDesignatedMaster(false))then
				self.lost=false
			else
				self.lost=true
			end
			self.shuffling=false
			self.started_experiment=true
			if self.lost then
				self.drone_state="LOST"
			else
				self.drone_state="NOT_LOST"
			end

		end,

		["reply_lateration_request"] = function(self,args)

			local time = os.clock()
			
			self.controller:addEntriFromRequest({id=args.sender_id,distance=args.distance,time=time,lost=args.lost,
			is_master=args.is_master,relative_pos=args.relative_pos,real_pos=args.real_pos,in_figure=args.in_figure})
			--print("NICE_WW",args.id,args.distance)
		end,


		["exchange_lateration_info"]=function (self,args) 
			
			local time = os.clock()
			--print("starting exchange from",args.sender_id)
			local relative_pos = self.ship_global_position:sub(self.coordinate_center)
			
			
			local distance = utilities.vec_distance(args.real_pos,self.ship_global_position)
			--print("real",self.ship_global_position)
			
			
			local is_master= ship.getId()==tonumber(self.sensors:getDesignatedMaster(false))
			self.controller:addEntriFromRequest({id=args.sender_id,distance=distance,time=time,lost=args.lost,
			in_figure=args.in_figure,is_master=args.is_master,relative_pos=args.relative_pos,real_pos=args.real_pos})

			local replay_messege={id=ship.getId(),distance=distance,lost=self.lost,in_figure=self.in_figure,is_master=is_master,
			relative_pos=relative_pos,distance,real_pos=self.ship_global_position}
			self:redirectMessege(args,{message=replay_messege,protocol="reply_lateration_request"})
		end,


		["exchange_full_lateration_info"]=function (self,args) 
			
		end,
		}
end




function DroneBaseShape:getCustomSettings()
	
	print("mi id: ",ship.getId())
	return {
		
		objective_pos = function (self) return self.objective_global_position end,
		movement_mode = function (self) return self.movement_mode end,
		coordinate_center = function (self) return self.coordinate_center end,
		angle_offset = function(self) return self.angle_offset end,
		experiment_online = function(self) return self.experiment_online end,
		shape = function(self) if self.shape  then return self.shape.figure_name else  return "NONE" end end,
		drone_state = function(self) return self.drone_state end,
	}
		
end


function DroneBaseShape:setCustomSettings()
	return {
		objective_pos = function(self,new_setting,new_settings) self:execute_protocol("objective_pos",new_setting) end,
		movement_mode = function(self,new_setting,new_settings) self:execute_protocol("movement_mode",new_setting) end,
		coordinate_center = function(self,new_setting,new_settings) self:execute_protocol("coordinate_center",new_setting) end,
		angle_offset = function(self,new_setting,new_settings) self:execute_protocol("angle_offset",new_setting) end,
		experiment_online = function(self,new_setting,new_settings) self:execute_protocol("experiment_online",new_setting)end,
		shape = function(self,new_setting,new_settings)  self:execute_protocol("shape",new_setting)end,
		drone_state = function(self,new_setting,new_settings) self:execute_protocol("drone_state",new_setting) end,
	}

	
end

function DroneBaseShape:new_pos_angles(angle_ejeY,angle_ejeZ)
	local ship_rotation = self.ShipFrame.target_rotation --* self:getOffsetDefaultShipOrientation(quaternion.new(1,0,0,0))

	local ejeX = ship_rotation:localPositiveX()
	ship_rotation = (quaternion.fromRotation(ship_rotation:localPositiveY(),angle_ejeY)*ship_rotation)
	ship_rotation = (quaternion.fromRotation(ship_rotation:localPositiveZ(),angle_ejeZ)*ship_rotation)

	return ship_rotation:rotateVector3(ejeX)
end

function DroneBaseShape:random_dir(sphere_range)
	
	local angle_ejeY = math.random(0, 360)
	local angle_ejeX = math.random(0, 360)
	


	local direction = self:new_pos_angles(angle_ejeY,angle_ejeX)
	local new_pos_offset = direction * sphere_range
	return new_pos_offset
end


function DroneBaseShape:TrilaterationFilterData(list)
	
	local count=0
	local master=false
	local time = os.clock()
	local list_trilateration={}
	
	if (not list) then
		return {check=false,master=master}
	end
	
	for id,drone in pairs(list)do
		--and drone.lost~=nil and not drone.lost
		
		if (time-drone.time)<=self.ShipFrame.trilateration_time_life and drone.is_master~=nil and drone.is_master then
			master=drone	
		elseif(time-drone.time)<=self.ShipFrame.trilateration_time_life and drone.lost~=nil and not drone.lost   then
			count=count+1
			table.insert(list_trilateration,1,drone)
		end

		
	end

	if master then
		table.insert(list_trilateration,1,master)
		count=count+1
	end

	--print("the count is ",count)
	return {len=count ,master=master,list=list_trilateration}
end



function DroneBaseShape:in_figure(pos)
	--print("hello")
	if self.ShipFrame.shape and self.ShipFrame.shape~="NONE" and self.ShipFrame.shape.in_figure then	
		return self.ShipFrame.shape:in_figure(pos)
	else
		print("no FIGURE")
		return false
	end
	
end


function DroneBaseShape:in_border_figure(pos)
	--print("hello")
	if self.ShipFrame.shape and self.ShipFrame.shape~="NONE" and self.ShipFrame.shape.in_figure then	
		return self.ShipFrame.shape:in_border_figure(pos)
	else
		print("no FIGURE")
		return false
	end
	
end

function DroneBaseShape:update_lost_status(info,update_other)
	local list = info.list
	local drones = {list[1],list[2],list[3]}
	local id_master=false
	if update_other then
		for idx,drone in pairs(drones)do 
			--print(drone.id)
			local messege =true
			if drone.is_master ~=nil and not drone.is_master then 
				self.ShipFrame:redirectMessege({sender_id=drone.id,channel=self.ShipFrame.com_channels.DRONE_TO_DRONE_CHANNEL},{message=messege,protocol="set_lost"})
			end
		end
	end
	if info.master then
		-- eliminate the other two problematic ones
		self.ShipFrame.trilateration_table[info.list[2].id].lost=true
		table.remove(info.list,2)
		self.ShipFrame.trilateration_table[info.list[2].id].lost=true
		table.remove(info.list,2)
		info.len=info.len-2
	else
		-- eliminate the first elements
		self.ShipFrame.trilateration_table[info.list[1].id].lost=true
		table.remove(info.list,1)
		self.ShipFrame.trilateration_table[info.list[1].id].lost=true
		table.remove(info.list,1)
		self.ShipFrame.trilateration_table[info.list[1].id].lost=true
		table.remove(info.list,1)
		info.len=info.len-3
	end
	
	return info


end

function DroneBaseShape:targets_in_figure(list) 

	local count=0
	local time = os.clock()
	local list_targets_figure={}
	
	
	
	for id,drone in pairs(list)do
		--and drone.lost~=nil and not drone.lost
		if(time-drone.time)<=self.ShipFrame.trilateration_time_life and drone.lost~=nil and not drone.lost and drone.in_figure~=nil and drone.in_figure  then
			count=count+1
			table.insert(list_targets_figure,1,drone)
		end

		
	end


	--print("the count is ",count)
	return {len=count,list=list_targets_figure}
	
end

function DroneBaseShape:average_global_center() 
	local total_vec=vector.new(0,0,0)
	local count =0
	for idx,elem in pairs(self.ShipFrame.trilateration_cache) do 
		if elem then
			count=count+1
			total_vec = total_vec + elem
		end
	end
	--print(count)
	if count >3 then
		return total_vec/count
	end

	return nil

end
function DroneBaseShape:vec_distance_no_center(pos1,center1,pos2,center2)
	local pos1_r = center1:add(pos1)
	local pos2_r = center2:add(pos2)
	return utilities.vec_distance(pos1_r,pos2_r)
end


function DroneBaseShape:fill_tri_history(avg_center,old_coordinate_center)
	local rel_pos = self.ShipFrame.ship_global_position:sub(old_coordinate_center)
	if #self.trilateration_history==0 then
		self.trilateration_history[1]={new=avg_center,center=old_coordinate_center,pos=rel_pos}
		self.trilateration_history_idx=1
		return nil
	end
	local distance = self:vec_distance_no_center(self.trilateration_history[1].rel_pos,self.trilateration_history[1].center)
	if distance > 2 then
		self.trilateration_history[self.trilateration_history_idx]={new=avg_center,center=old_coordinate_center,pos=rel_pos}
		self.trilateration_history_idx= math.fmod((self.trilateration_history_idx+1),2)
	end

end


function DroneBaseShape:trilateration_check()
	-- try to do trilateration
		
		if ship.getId()==tonumber(self.ShipFrame.sensors:getDesignatedMaster(false))then
			-- do no change if you are master
			self.ShipFrame.coordinate_center = utilities.table_to_vector(self.ShipFrame.master_coordinate_center)
			self.lost=false
			self.angle_offset=0
			return {}
		end
		
		local repeat_trilat=  self.ShipFrame.timer_trilateration:check() 
		if repeat_trilat then
			self.ShipFrame.timer_trilateration:reset()	
		end
		local info = self:TrilaterationFilterData(self.ShipFrame.trilateration_table)
		
		local global_center =nil
		
		if (info.master and repeat_trilat and not global_center and self.ShipFrame.always_check_master) then
			global_center = utilities.table_to_vector(info.master.real_pos):sub(utilities.table_to_vector(info.master.relative_pos)) 
		end


		while(info.len>=3 and repeat_trilat and not global_center)do
			local tri_position = utilities.trilateration(info.list)
			
			if tri_position and tostring(tri_position.x)~="nan" and tostring(tri_position.y)~="nan" and tostring(tri_position.z)~="nan" then 
				
				global_center = self.ShipFrame.ship_global_position:sub(tri_position)
				--store global center
			else
				info = self:update_lost_status(info,self.ShipFrame.update_others)
				--send lost messege to the other ships
			end
		end
		
		
		if (info.master and repeat_trilat and not global_center and not self.ShipFrame.always_check_master) then
			global_center = utilities.table_to_vector(info.master.real_pos):sub(utilities.table_to_vector(info.master.relative_pos)) 
		end

		if repeat_trilat then
			--store global center
			self.ShipFrame.trilateration_cache[self.ShipFrame.trilateration_index+1]=global_center
			self.ShipFrame.trilateration_index = math.fmod((self.ShipFrame.trilateration_index+1),self.ShipFrame.trilateration_average_max)
		end

		local avg_center = self:average_global_center()

		if avg_center and repeat_trilat then
			-- stop global centergenerate average global_center
			--self:fill_tri_history(avg_center,self.ShipFrame.coordinate_center)


			
			local diff_centers=self.ShipFrame.coordinate_center:sub(avg_center)
			self.ShipFrame.start_objective_global_position=self.ShipFrame.start_objective_global_position:add(diff_centers)
			self.ShipFrame.objective_global_position=self.ShipFrame.objective_global_position:add(diff_centers)
			self.ShipFrame.coordinate_center = avg_center
			self.ShipFrame.lost=false

		elseif repeat_trilat then
			self.ShipFrame.lost=true
			self.trilateration_history={}
			self.trilateration_history_idx=0
		end
		
		return info
end

function DroneBaseShape:random_move()
	-- try to do trilateration
		local future_offset=false
		if not self.ShipFrame.timer_random_move then
			self.ShipFrame.timer_random_move=utilities.NonBlockingCooldownTimer(self.ShipFrame.cooldown_random)
			self.ShipFrame.timer_random_move:start()
			future_offset = self:random_dir(self.ShipFrame.random_search_range)
		end

		if self.ShipFrame.timer_random_move:check() then
			future_offset = self:random_dir(self.ShipFrame.random_search_range)
			self.ShipFrame.timer_random_move:reset()	
			
		end
		if (future_offset) then
			
			
		end
		
		
		return future_offset
		
end

function DroneBaseShape:gas_move(list,pos,radius)
	local result_vector = vector.new(0,0,0)
	local drone_vector=nil
	local relativeVec=nil
	local future_offset=false
	local timer_right=true
	if not self.ShipFrame.timer_gas_move then
		--print("hello")
		self.ShipFrame.timer_gas_move=utilities.NonBlockingCooldownTimer(self.ShipFrame.cooldown_gas)
		self.ShipFrame.timer_gas_move:start()
		timer_right = true
	end
	timer_right = timer_right or self.ShipFrame.timer_gas_move:check()
	if not timer_right then return nil end

	for _,drone in ipairs(list) do
		relativeVec = utilities.table_to_vector(drone.relative_pos)
		drone_vector = ((pos - relativeVec ) / drone.distance ) * (radius-drone.distance)
		result_vector = result_vector + drone_vector
	end
	--print("result",result_vector)
	return result_vector
end


function DroneBaseShape:customFlightLoopBehavior(customFlightVariables)

	-- get default rotation no matter original rot

	self.target_rotation = quaternion.fromToRotation(self.target_rotation:localPositiveX(),vector.new(1,0,0))*self.target_rotation
	self.target_rotation = quaternion.fromToRotation(self.target_rotation:localPositiveY(),vector.new(0,1,0))*self.target_rotation
	self.target_rotation = (quaternion.fromRotation(self.target_rotation:localPositiveY(),0)*self.target_rotation):normalize()-- uncomment to flip ship upside down
	
	--print("fuck",self.coordinate_center)
	local target_pos = self.ship_global_position:sub(self.coordinate_center)
	
	--print("hfjdsfjds",target_pos)
	

	if self.timer_trilateration_request:check() then
		
		local targets = self.controller:radar_ships()
		
		self.controller:TrilaterationRequest(targets)
		self.timer_trilateration_request:reset()	
	end

	if self.stop_drone then
		--stop movement
		
		return {}
	end


	
	if self.experiment_online then
		self.controller:set_range(self.exp_search_range)

		if self.shuffling then
			-- go to shuffling positions
			target_pos=self.objective_global_position
			
		end

		if self.started_experiment then
			self.controller:trilateration_check()
			local info = self.controller:targets_in_figure(self.trilateration_table)
	
			if not self.lost and self.controller:in_figure(target_pos)then
				
				--print("in figure")
				-- what to do in figure
				
				self.drone_state="IN_FIGURE"
				self.in_figure=true

				



				local future_offset=self.controller:gas_move(info.list,target_pos,self.gas_radius)

				if future_offset and self.controller:in_figure(target_pos:add(future_offset)) then
					self.objective_global_position = target_pos:add(future_offset)
				end
				if self.controller:in_border_figure(target_pos) then
					
					self.objective_global_position= utilities.table_to_vector(self.shape.center_figure)
					
				else
					self.objective_global_position= target_pos
				end
				
				target_pos=self.objective_global_position
				


			elseif not self.lost then
				self.drone_state="OUT_FIGURE"
				
				if self.shape then
					
					target_pos = utilities.table_to_vector(self.shape.center_figure)
				end
			else
				
				
				--print("out figure")
				self.in_figure=false
				local future_offset=self.controller:random_move()
				if future_offset then
					self.objective_global_position = target_pos:add(future_offset)				
					--print(future_offset)
					
				end
				target_pos=self.objective_global_position
				--print(target_pos)
				
				self.drone_state="LOST"
					
				
				
			end
		
			
				
			
		end
	else
		
		--print("i am stupid",self.movement_mode.."|",self.movement_mode=="FOLLOW ")
		if self.movement_mode=="STAY" then
			target_pos= self.objective_global_position


		
		elseif self.movement_mode=="RANDOM" then
			
			local future_offset=self.controller:random_move()
			if future_offset then
				--change for relative_pos
				self.objective_global_position = target_pos:add(future_offset)
			end
			target_pos=self.objective_global_position
			
		elseif self.movement_mode=="HOME" then
			
			self.objective_global_position = self.start_objective_global_position
			target_pos= self.objective_global_position
			
		elseif self.movement_mode=="FOLLOW" then
			self.controller:set_range(self.follow_range)
			--print("hey",self.remoteControlManager:getRunMode())
			
			local player_info=self.sensors.radars:getRadarTarget("PLAYER",false) or false
			if player_info  then
				
				self.objective_global_position=player_info.position:sub(self.coordinate_center)
				target_pos= self.objective_global_position
				--print("i shoud be moving",target_pos)
			else
				target_pos= self.objective_global_position
			end
			
			

		else
			target_pos= self.objective_global_position
		end
		


	end





	

	
	
	
	local target_world_coords = target_pos:add(self.coordinate_center)
	
	--print("error",target_world_coords)
	-- clamp to bounaries

	self.controller:clampBoundaries(target_world_coords)

	self.target_global_position = target_world_coords

	
end

function DroneBaseShape:checkMaxBounder(eje,pos,relative_pos,bounder)
	--print("max",eje,relative_pos[eje] >= bounder )
	if relative_pos[eje] >= bounder then
		pos[eje]= bounder
	end
	return pos
end

function DroneBaseShape:checkMinBounder(eje,pos,relative_pos,bounder)
	--print("min",eje,relative_pos[eje] <= bounder )
	if relative_pos[eje] <= bounder then
		pos[eje]= bounder
	end
	return pos
end

function DroneBaseShape:clampBoundaries(pos)
	local center_bounder = self.ShipFrame.boundaries[1]
	local offset_bonder_max=self.ShipFrame.boundaries[2]
	local offset_bounder_min=self.ShipFrame.boundaries[3]
	local relative_pos = pos - center_bounder
	
	self:checkMaxBounder("x",pos,relative_pos,offset_bonder_max.x)
	self:checkMinBounder("x",pos,relative_pos,offset_bounder_min.x)

	self:checkMaxBounder("y",pos,relative_pos,offset_bonder_max.y)
	self:checkMinBounder("y",pos,relative_pos,offset_bounder_min.y)

	self:checkMaxBounder("z",pos,relative_pos,offset_bonder_max.z)
	self:checkMinBounder("z",pos,relative_pos,offset_bounder_min.z)
	
end



function DroneBaseShape:customSetConfigFrame(instance_configs)
	instance_configs.ship_constants_config.DRONE_TYPE = "GAS"
	instance_configs.rc_variables={run_mode=true}
	return instance_configs
end




function DroneBaseShape:initCustom(customFlightVariables)

	--math.randomseed(os.time())

	self.ShipFrame.angle_offset=0
	self.trilateration_history_idx=0

	self.ShipFrame.experiment_online=false
	self.ShipFrame.drone_state="MV_STAY"

	self.ShipFrame.shape=nil

	self.ShipFrame.lost=true

	self.ShipFrame.movement_mode="STAY"
	

	self.ShipFrame.trilateration_table={}

	self.ShipFrame.trilateration_time_life =3
	self.ShipFrame.trilateration_cooldown_request =1
	self.ShipFrame.trilateration_cooldown =1

	self.ShipFrame.gas_radius=5
	
	self.ShipFrame.master_coordinate_center = customFlightVariables.master_coordinate_center or self.ShipFrame.ship_global_position

	self.ShipFrame.coordinate_center = customFlightVariables.coordinate_center or self.ShipFrame.ship_global_position
	


	local default_pos=self.ShipFrame.coordinate_center

	if customFlightVariables.relative_starting_pos and not customFlightVariables.starting_pos then
		default_pos =customFlightVariables.relative_starting_pos:add(self.ShipFrame.coordinate_center)
	elseif customFlightVariables.starting_pos then
		default_pos=customFlightVariables.starting_pos
	end

	
	self.ShipFrame.start_objective_global_position = default_pos:sub(self.ShipFrame.coordinate_center)
	self.ShipFrame.objective_global_position = self.ShipFrame.start_objective_global_position

	self.ShipFrame.random_search_range = customFlightVariables.random_search_range or 5
	
	self.ShipFrame.cooldown_random = customFlightVariables.cooldown_random_move or 5
	self.ShipFrame.cooldown_gas = customFlightVariables.cooldown_gas_move or 5
	
	
	self.ShipFrame.timer_random_move = utilities.NonBlockingCooldownTimer(self.ShipFrame.cooldown_random)
	self.ShipFrame.timer_random_move:start()
	
	self.ShipFrame.timer_gas_move = utilities.NonBlockingCooldownTimer(self.ShipFrame.cooldown_gas)
	self.ShipFrame.timer_gas_move:start()
	
	
	
	
	self.ShipFrame.timer_trilateration_request = utilities.NonBlockingCooldownTimer(self.ShipFrame.trilateration_cooldown_request)
	self.ShipFrame.timer_trilateration_request:start()

	
	self.ShipFrame.timer_trilateration = utilities.NonBlockingCooldownTimer(self.ShipFrame.trilateration_cooldown)
	self.ShipFrame.timer_trilateration:start()
	

	self.ShipFrame.boundaries ={vector.new(0,0,0),vector.new(100,160,100),vector.new(-100,10,-100)}

	self.ShipFrame.trilateration_index=0
	self.ShipFrame.trilateration_average_max=10
	
	self.ShipFrame.manual_move=false
	self.ShipFrame.in_figure=false
	self.ShipFrame.always_check_master=true
	self.ShipFrame.trilateration_cache={}

	self.ShipFrame.update_others=false

	self.ShipFrame.exp_search_range=20
	self.ShipFrame.follow_range=100
	self.stop_drone = false
	self.trilateration_history={}

	
	
	self.ShipFrame.target_global_position = self.ShipFrame.objective_global_position:add(self.ShipFrame.coordinate_center)
	
end
return DroneBaseShape