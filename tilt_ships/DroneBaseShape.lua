

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
	return quaternion.fromRotation(default_ship_orientation:localPositiveY(),angle_offset)*default_ship_orientation -- Rotates the default orientation so that the nose of the ship is aligned with it's local +X axis
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
	local actual_time = os.time(os.date("!*t"))
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

	self.ShipFrame.trilateration_table[info.id]={id=info.id,distance=info.distance,time=info.time,
	lost=info.lost,is_master=info.is_master,relative_pos=info.relative_pos,real_pos=info.real_pos,in_figure=info.in_figure}
	
end

function DroneBaseShape:TrilaterationRequest(radar_targets)
	--filter by need to update on 
	for _,ship_entity in pairs(radar_targets) do
		
		if self:ValidTrilaterationReq(ship_entity.id) then
			local time = os.time(os.date("!*t"))
			local relative_pos = self.ShipFrame.real_pos:round(0.001) - self.ShipFrame.coordinate_center
			relative_pos = self.rotate_coords(relative_pos,self.ShipFrame.angle_offset)
			
			local is_master= ship.getId()==tonumber(self.ShipFrame.master_ship)
			
			local messege ={lost=self.ShipFrame.lost,in_figure=self.ShipFrame.in_figure,is_master=is_master,relative_pos=relative_pos,real_pos=self.ShipFrame.real_pos}
		
			self.ShipFrame:redirectMessege({sender_id=ship_entity.id,channel=self.ShipFrame.com_channels.DRONE_TO_DRONE_CHANNEL},{message=messege,protocol="exchange_lateration_info"})
		end

	end


end


function DroneBaseShape:ShufflePos()
	local bounder = self.ShipFrame.boundaries

	local center_bounder = bounder[1]
	local offset_bonder_max=bounder[2]
	local offset_bounder_min=bounder[3]
	
	local corner = center_bounder + offset_bounder_min
	local height = offset_bonder_max.y-offset_bounder_min.y
	local widthX = offset_bonder_max.x-offset_bounder_min.x
	local widthZ = offset_bonder_max.z-offset_bounder_min.z
	local random_pos = vector.new(math.random(0,widthX),math.random(0,height),math.random(0,widthZ))
	
	local new_pos = corner + random_pos

	return new_pos

end








function DroneBaseShape:getProtocols()
	
	return {

		["stop_drone"] = function (self,mode)
			self.stop_drone=mode
			if mode then
				self.objective_global_position=self.real_pos:round(0.001)
				if not self.pause_report  and self.started_experiment and self.report_on then
					self.report_on=false
					self.pause_time=os.time(os.date("!*t"))
					self.pause_report=true
					if self.report_file then
						self.report_file:close()
						self.report_file=nil
					end
		
					
				end
				
			else
				if self.pause_report then

					self.pause_report=false
					self.continue_time=os.time(os.date("!*t"))
					self.report_on=true
					self.report_file = io.open(self.file_path,"a")
				end
				
			end
		end,
		["random_search_range"] = function (self,range)
			self.random_search_range=range
			end,
		["cooldown_random"] = function (self,cooldown)
			self.cooldown_random=cooldown
			self.timer_random_move.cooldown =cooldown
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

		["offset_needed"]= function (self,offset_needed)
			if not self.offset_needed and offset_needed then
				self.angle_offset=math.random(0,359)
				self.orientation_cache={}
				self.orientation_index=0
			end

			if self.offset_needed and not offset_needed then
				self.angle_offset=0
			end
			self.offset_needed = offset_needed
			
			
		end,

		["always_check_master"]= function (self,always_check_master) 
			self.always_check_master = always_check_master
			
		end,

		["radar_range"]= function (self,radius)
			print("radar_range_changed")
			self.exp_search_range = radius
			
		end,

		["gas_radius"]= function (self,radius)
			print("gas_radius_changed ",radius)
			self.gas_radius = radius
			
		end,

		["experiment_online"] = function (self,mode) 
			print("recived experiment",mode)
			self.experiment_online = mode
			self.shuffling=false
			if ship.getId()==tonumber(self.master_ship)then
				self.lost=false
			else
				self.lost=true
			end
			
			if self.experiment_online then
				self.drone_state="W_SHUFFLE"

			else
				self.drone_state="MV_"..self.movement_mode
				self.report_on=false
				self.angle_offset=0
				if self.report_file then 
					self.report_file:close()
					self.report_file=nil
				end
				
				
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
			print("received params figure",params)
			if self.shape then
				self.shape:set_params(params)
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

		["master_ship"]=function (self,master_ship) 
			
			self.master_ship=master_ship
			
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
			if ship.getId()==tonumber(self.master_ship)then
				self.lost=false
			else
				self.lost=true
			end
			self.started_experiment=false
			local new_pos = self.controller:ShufflePos()
			self.objective_global_position = new_pos
			self.report_on=false
			if self.report_file then 
				self.report_file:close()
				self.report_file=nil
			end
			
			
			self.drone_state="SHUFFLING"
			
			
		end,

		["start_experiment"] = function (self,args) 
			print("start")
			if ship.getId()==tonumber(self.master_ship)then
				self.lost=false
			else
				self.lost=true
			end
			self.shuffling=false
			self.started_experiment=true
			self.coordinate_center=self.real_pos:round(0.001)

			self.start_time_report=os.time(os.date("!*t"))
			if not args then
				self.file_path="reports/report_"..ship.getId()..".csv" 
			else
				self.file_name=args.file_name or "report"
				self.file_name = self.file_name..ship.getId()..".csv" 
				self.file_folder = args.file_folder or "reports"
				self.file_path=self.file_folder.."/"..self.file_name
			end
			if self.report_file then
				self.report_file:close()
				self.report_file=nil
			end

			self.report_file = io.open(self.file_path,"w+")
			print(self.file_path)
			self.report_on=true

			self.report_file:write(self.report_header)
			self.report_file:close()
			self.report_file = io.open(self.file_path,"a")
			
			if self.offset_needed then
				self.angle_offset=math.random(0,359)
			end
			if self.lost then
				self.drone_state="LOST"
			else
				self.drone_state="NOT_LOST"
			end

		end,

		["reply_lateration_request"] = function(self,args)

			local time = os.time(os.date("!*t"))
			
			self.controller:addEntriFromRequest({id=args.sender_id,distance=args.distance,time=time,lost=args.lost,
			is_master=args.is_master,relative_pos=args.relative_pos,real_pos=args.real_pos,in_figure=args.in_figure})
			
		end,


		["exchange_lateration_info"]=function (self,args) 
			
			local time = os.time(os.date("!*t"))
			
			local relative_pos = self.real_pos:round(0.001) - self.coordinate_center
			relative_pos = self.controller.rotate_coords(relative_pos,self.angle_offset)
			
			
			local distance = utilities.vec_distance(args.real_pos,self.real_pos:round(0.001))
			
			
			
			local is_master= ship.getId()==tonumber(self.master_ship)
			self.controller:addEntriFromRequest({id=args.sender_id,distance=distance,time=time,lost=args.lost,
			in_figure=args.in_figure,is_master=args.is_master,relative_pos=args.relative_pos,real_pos=args.real_pos})

			local replay_messege={id=ship.getId(),distance=distance,lost=self.lost,in_figure=self.in_figure,is_master=is_master,
			relative_pos=relative_pos,distance,real_pos=self.real_pos:round(0.001)}
			self:redirectMessege(args,{message=replay_messege,protocol="reply_lateration_request"})
		end,


		["exchange_full_lateration_info"]=function (self,args) 
			
		end,
		}
end

function DroneBaseShape:getFigureData()
	local shape = self.ShipFrame.shape

	return {figure_type=shape.figure_type(),figure_name=shape.figure_name_id,params=shape.params}
end


function DroneBaseShape:getCustomSettings()
	
	print("mi id: ",ship.getId())
	return {
		
		real_pos=function (self) return self.real_pos:round(0.001) end,
		objective_pos = function (self) return self.objective_global_position:round(0.001) end,
		movement_mode = function (self) return self.movement_mode end,
		coordinate_center = function (self) return self.coordinate_center:round(0.01) end,
		angle_offset = function(self) return self.angle_offset end,
		experiment_online = function(self) return self.experiment_online end,
		shape = function(self) if self.shape  then return self.controller:getFigureData() else  return "NONE" end end,
		drone_state = function(self) return self.drone_state end,
		random_search_range = function(self) return self.random_search_range end,
		cooldown_random = function(self) return self.cooldown_random end,
		always_check_master=function(self) return self.always_check_master end,
		offset_needed=function(self) return self.offset_needed end,
		stop_drone=function(self) return self.stop_drone end,
		master_ship=function(self) return self.master_ship end,
	}
		
end


function DroneBaseShape:setCustomSettings()
	return {
		movement_mode = function(self,new_setting,new_settings) self:execute_protocol("movement_mode",new_setting) end,
		experiment_online = function(self,new_setting,new_settings) self.experiment_online = new_setting end,
		shape = function(self,new_setting,new_settings)  self:execute_protocol("shape",new_setting)end,
		drone_state = function(self,new_setting,new_settings) self:execute_protocol("drone_state",new_setting) end,
		random_search_range = function(self,new_setting,new_settings) self:execute_protocol("random_search_range",new_setting) end,
		cooldown_random = function(self,new_setting,new_settings) self:execute_protocol("cooldown_random",new_setting) end,
		always_check_master=function(self,new_setting,new_settings) self:execute_protocol("always_check_master",new_setting) end,
		offset_needed=function(self,new_setting,new_settings) self:execute_protocol("offset_needed",new_setting) end,
		stop_drone=function(self,new_setting,new_settings) self:execute_protocol("stop_drone",new_setting) end,
		master_ship=function(self,new_setting,new_settings) self:execute_protocol("master_ship",new_setting) end
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

function DroneBaseShape:isvalidPos(pos)
	if not pos.x or not pos.y or not pos.z then
		return false
	end
	local pos_x_str=tostring(pos.x)
	local pos_y_str=tostring(pos.y)
	local pos_z_str=tostring(pos.z)
	if  pos_x_str=="nan" or pos_x_str=="inf" 
	or pos_y_str=="nan" or pos_y_str=="inf" 
	or pos_z_str=="nan" or pos_z_str=="inf" then 
		return false 
	end
	return true
end


function DroneBaseShape:TrilaterationFilterData(list)
	
	local count=0
	local master=false
	local time = os.time(os.date("!*t"))
	local list_trilateration={}
	
	if (not list) then
		return {check=false,master=master}
	end
	
	for id,drone in pairs(list)do
		--and drone.lost~=nil and not drone.lost
		
		if (time-drone.time)<=self.ShipFrame.trilateration_time_life and drone.is_master~=nil and drone.is_master then
			master=drone	
		elseif(time-drone.time)<=self.ShipFrame.trilateration_time_life and drone.lost~=nil and not drone.lost   then
			
			if self:isvalidPos(drone.relative_pos) then
				count=count+1
				table.insert(list_trilateration,1,drone)
			end

			
		end

		
	end
	
	table.sort(list_trilateration,function(a,b)return a.distance<b.distance end)

	if master then
		table.insert(list_trilateration,1,master)
		count=count+1
	end

	
	return {len=count ,master=master,list=list_trilateration}
end



function DroneBaseShape:in_figure(pos)
	
	if self.ShipFrame.shape and self.ShipFrame.shape~="NONE" and self.ShipFrame.shape.in_figure then	
		return self.ShipFrame.shape:in_figure(pos)
	else
		print("no FIGURE")
		return false
	end
	
end


function DroneBaseShape:in_border_figure(pos)
	
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
			
			local messege =true
			if drone.is_master ~=nil and not drone.is_master then 
				self.ShipFrame:redirectMessege({sender_id=drone.id,channel=self.ShipFrame.com_channels.DRONE_TO_DRONE_CHANNEL},{message=messege,protocol="set_lost"})
			end
		end
	end
	if info.master then
		-- eliminate the other two problematic ones
		for i=0,2,1 do
			self.ShipFrame.trilateration_table[info.list[2].id].lost=true
			table.remove(info.list,2)
		end
		
		info.len=info.len-3
	else
		-- eliminate the first elements
		for i=0,3,1 do
			self.ShipFrame.trilateration_table[info.list[1].id].lost=true
			table.remove(info.list,1)
		end
		
		info.len=info.len-4
	end
	
	return info


end

function DroneBaseShape:targets_in_figure(list) 

	local count=0
	local time = os.time(os.date("!*t"))
	local list_targets_figure={}
	
	
	
	for id,drone in pairs(list)do
		--and drone.lost~=nil and not drone.lost
		---and drone.in_figure~=nil and drone.in_figure
		if(time-drone.time)<=self.ShipFrame.trilateration_time_life and drone.lost~=nil and not drone.lost   then
			count=count+1
			table.insert(list_targets_figure,1,drone)
		end

		
	end


	
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
	
	if count >3 then
		return total_vec/count
	end

	return nil

end


function DroneBaseShape:average_orientation() 
	local total_angle=0
	local count =0
	for idx,elem in pairs(self.ShipFrame.orientation_cache) do 
		if elem then
			count=count+1
			total_angle = total_angle + elem
		end
	end
	

	return total_angle/count

end
function DroneBaseShape:vec_distance_no_center(pos1,center1,pos2,center2)
	local pos1_r = center1 + pos1
	local pos2_r = center2 + pos2
	return utilities.vec_distance(pos1_r,pos2_r)
end


function DroneBaseShape:fill_tri_history(avg_center,coordinate_center)
	local real_pos= self.ShipFrame.real_pos:round(0.001)
	local rel_pos = real_pos:sub(coordinate_center)
	rel_pos = self.rotate_coords(rel_pos,self.ShipFrame.angle_offset)
	local new_pos = real_pos:sub(avg_center)
	
	if #self.trilateration_history==0 then
		self.trilateration_history[1]={new=avg_center,center=coordinate_center,pos=rel_pos,new_pos=new_pos,real_pos=real_pos}
		return false
	end

	local distance = utilities.vec_distance(self.trilateration_history[1].real_pos,real_pos)
	
	if distance > 4 then
		self.trilateration_history[2]={new=avg_center,center=coordinate_center,pos=rel_pos,new_pos=new_pos,real_pos=real_pos}
		return true
	end
	
	
	

end

function DroneBaseShape:deduce_ori()
	

	if #self.trilateration_history==2 then
		local data1=self.trilateration_history[self.trilateration_history_idx+1]
		local data2=self.trilateration_history[math.fmod((self.trilateration_history_idx+1),2)+1]
		
		
		local vec_rel = data2.pos - data1.pos
		local vec_real = data2.new_pos - data1.new_pos
		
		local angle_vec = math.acos(vec_rel:dot(vec_real) / (vec_rel:length() * vec_real:length()))
		if not angle_vec or tostring(angle_vec) == "nan" then
			angle_vec=0
		end
		
		return math.deg(angle_vec)
		
	else
		return nil
	end


end


function DroneBaseShape:trilateration_check()
	-- try to do trilateration
		
		
		

		if ship.getId()==tonumber(self.ShipFrame.master_ship)then
			-- do no change if you are master
				
			self.ShipFrame.coordinate_center = utilities.table_to_vector(self.ShipFrame.master_coordinate_center)
			self.lost=false
			self.ShipFrame.angle_offset=0
			return {}
		end


		local info = self:TrilaterationFilterData(self.ShipFrame.trilateration_table)
		
		local global_center =nil
		
		if (info.master and not global_center and self.ShipFrame.always_check_master) then
			global_center = utilities.table_to_vector(info.master.real_pos):sub(utilities.table_to_vector(info.master.relative_pos)) 
		end


		while(info.len>=4 and not global_center)do
			local tri_position = utilities.trilateration(info.list)
			
			if tri_position and tostring(tri_position.x)~="nan" and tostring(tri_position.y)~="nan" and tostring(tri_position.z)~="nan" then 
				
				global_center = self.ShipFrame.real_pos:round(0.001) -tri_position
				
				--store global center
			else
				info = self:update_lost_status(info,self.ShipFrame.update_others)
				--send lost messege to the other ships
			end
			
		end
		
		
		if (info.master and not global_center and not self.ShipFrame.always_check_master) then
			global_center = utilities.table_to_vector(info.master.real_pos):sub(utilities.table_to_vector(info.master.relative_pos)) 
		end

		--print(global_center)
		if not global_center then
			
		elseif  global_center.x>10000 or global_center.y>10000 or global_center.z>10000 then
			global_center=nil
		end

		
		self.ShipFrame.trilateration_cache[self.ShipFrame.trilateration_index+1]=global_center
		self.ShipFrame.trilateration_index = math.fmod((self.ShipFrame.trilateration_index+1),self.ShipFrame.trilateration_average_max)

		local avg_center = self:average_global_center()

		if self.no_avg_center then
			avg_center = global_center
		end
		
		if avg_center then
			-- stop global centergenerate average global_center
			local offset_needed = self.ShipFrame.offset_needed
			local angle_deduce=self.ShipFrame.angle_offset
			if offset_needed then
				angle_deduce = nil
				local check = self:fill_tri_history(avg_center,self.ShipFrame.coordinate_center)
				
				if check then
					angle_deduce = self:deduce_ori()
					self.trilateration_history={}
				end
			end
			
			

			if angle_deduce then
				local diff_centers=self.ShipFrame.coordinate_center:sub(avg_center)
				local new_angle = math.abs(self.ShipFrame.angle_offset-angle_deduce)
				new_angle = math.mod(new_angle,360)
				

				self.ShipFrame.orientation_cache[self.ShipFrame.orientation_index+1]=new_angle
				self.ShipFrame.orientation_index = math.fmod((self.ShipFrame.orientation_index+1),self.ShipFrame.orientation_average_max)

				
				if offset_needed then
					self.ShipFrame.angle_offset=self:average_orientation()
				else
					self.ShipFrame.angle_offset=0
				end
				

				
				
				self.ShipFrame.coordinate_center = avg_center
				
				self.ShipFrame.lost=false
			end

		else
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
		
		
		return future_offset
		
end

function DroneBaseShape:gas_move(list,pos,radius)
	local result_vector = vector.new(0,0,0)
	local drone_vector=nil
	local relativeVec=nil
	local future_offset=false
	local timer_right=true
	if not self.ShipFrame.timer_gas_move then
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

	return result_vector
end

function DroneBaseShape.rotate_coords(vec,angle_d)
	
	local angle= math.rad(angle_d)
	local s = math.sin(angle)
	local c = math.cos(angle)
	vec.x= vec.x*c-vec.z*s
	vec.z= vec.x*s+vec.z*c
	return vec:round(0.001)
end


function DroneBaseShape:customFlightLoopBehavior(customFlightVariables)

	-- get default rotation no matter original rot

	self.real_pos = utilities.table_to_vector(ship.getWorldspacePosition())
	
	
	self.target_rotation = quaternion.fromToRotation(self.target_rotation:localPositiveX(),vector.new(1,0,0))*self.target_rotation
	self.target_rotation = quaternion.fromToRotation(self.target_rotation:localPositiveY(),vector.new(0,1,0))*self.target_rotation
	self.target_rotation = (quaternion.fromRotation(self.target_rotation:localPositiveY(),0)*self.target_rotation):normalize()-- uncomment to flip ship upside down
	
	
	local target_pos = self.real_pos:round(0.001) - self.coordinate_center
	self.target_global_position=self.real_pos:round(0.001)
	
	if self.angle_offset~=0 then
	target_pos = self.controller.rotate_coords(target_pos,self.angle_offset):round(0.001)
	end
	

	if self.stop_drone then
		--stop movement
		self.target_global_position=self.objective_global_position
		return {}
	end



	
	if self.experiment_online then
		self.controller:set_range(self.exp_search_range)

		if self.shuffling then
			-- go to shuffling positions
			--print("works")
			self.target_global_position=self.objective_global_position
			return {}

			
		end

		if self.started_experiment then
			self.controller:trilateration_check()
			local info = self.controller:targets_in_figure(self.trilateration_table)
	
			if not self.lost and self.controller:in_figure(target_pos)then
				
			
				
				self.drone_state="IN_FIGURE"
				self.in_figure=true

				local future_offset=self.controller:gas_move(info.list,target_pos,self.gas_radius)

				if future_offset and self.controller:in_figure(target_pos + future_offset) then
					self.objective_global_position = target_pos + future_offset
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
				
				

				self.in_figure=false
				local future_offset=self.controller:random_move()
				if future_offset then
					
					self.objective_global_position = target_pos + future_offset
	
				end
				target_pos=self.objective_global_position
				
				self.drone_state="LOST"
					
				
				
			end
		
			
				
			
		end
	else
		

		if self.movement_mode=="STAY" then
			target_pos= self.objective_global_position


		
		elseif self.movement_mode=="RANDOM" then
			
			local future_offset=self.controller:random_move()
			if future_offset then
				--change for relative_pos
				self.objective_global_position = target_pos + future_offset
			end
			target_pos=self.objective_global_position
			
		elseif self.movement_mode=="HOME" then
			
			self.objective_global_position = self.start_objective_global_position
			target_pos= self.objective_global_position
			
		elseif self.movement_mode=="FOLLOW" then
			
			self.controller:set_range(self.follow_range)
			
			
			local player_info=self.sensors.radars:getRadarTarget("PLAYER",false) or false
			if player_info  then
				
				self.objective_global_position=player_info.position:sub(self.coordinate_center)
				
				target_pos= self.objective_global_position
				
			else
				target_pos= self.objective_global_position
			end
			
			

		else
			target_pos= self.objective_global_position
		end
		


	end



	--print(self.coordinate_center)

	
	
	local target_world_coords=target_pos
	if self.angle_offset~=0 then
		target_world_coords = self.controller.rotate_coords(target_pos,-self.angle_offset)
	end
	
	target_world_coords = target_world_coords + self.coordinate_center
	
	

	target_world_coords = self.controller:clampBoundaries(target_world_coords)

	
	

	self.target_global_position = target_world_coords

	
end

function DroneBaseShape:checkMaxBounder(eje,pos,relative_pos,bounder,center)

	if relative_pos[eje] >= bounder then
		pos[eje]= center[eje]
	end
	return pos
end

function DroneBaseShape:checkMinBounder(eje,pos,relative_pos,bounder,center)
	
	if relative_pos[eje] <= bounder then
		pos[eje]= center[eje]
	end
	return pos
end

function DroneBaseShape:clampBoundaries(pos)
	
	local center_coords_bounder = self.ShipFrame.boundaries[1]
	local offset_bonder_max=self.ShipFrame.boundaries[2]
	local offset_bounder_min=self.ShipFrame.boundaries[3]
	local relative_pos = pos - center_coords_bounder
	
	local new_pos = vector.new(pos.x,pos.y,pos.z)
	local center = vector.new(  (self.ShipFrame.boundaries[2].x-self.ShipFrame.boundaries[1].x)/2,
								(self.ShipFrame.boundaries[2].y-self.ShipFrame.boundaries[1].y)/2,
								(self.ShipFrame.boundaries[2].z-self.ShipFrame.boundaries[1].z)/2)
	
	new_pos = self:checkMaxBounder("x",pos,relative_pos,offset_bonder_max.x,center)
	new_pos = self:checkMinBounder("x",new_pos,relative_pos,offset_bounder_min.x,center)

	new_pos = self:checkMaxBounder("y",new_pos,relative_pos,offset_bonder_max.y,center)
	new_pos = self:checkMinBounder("y",new_pos,relative_pos,offset_bounder_min.y,center)

	new_pos = self:checkMaxBounder("z",new_pos,relative_pos,offset_bonder_max.z,center)
	new_pos = self:checkMinBounder("z",new_pos,relative_pos,offset_bounder_min.z,center)
	
	
	return new_pos + center_coords_bounder
	
end



function DroneBaseShape:customSetConfigFrame(instance_configs)
	instance_configs.ship_constants_config.DRONE_TYPE = "GAS"
	instance_configs.rc_variables={run_mode=true}
	return instance_configs
end




function DroneBaseShape:initCustom(customFlightVariables)

	--math.randomseed(os.time(os.date("!*t")))

	self.ShipFrame.angle_offset=0
	self.trilateration_history_idx=0
	self.ShipFrame.offset_needed=false
	self.ShipFrame.always_check_master=false

	self.ShipFrame.experiment_online=false
	self.ShipFrame.drone_state="MV_STAY"

	self.ShipFrame.shape=nil

	self.ShipFrame.lost=true

	self.ShipFrame.movement_mode="STAY"
	

	self.ShipFrame.trilateration_table={}

	self.ShipFrame.trilateration_time_life =5
	self.ShipFrame.trilateration_cooldown_request =1
	self.ShipFrame.trilateration_cooldown =5

	self.ShipFrame.gas_radius=2
	
	

	self.ShipFrame.real_pos = utilities.table_to_vector(ship.getWorldspacePosition())
	self.real_pos = self.ShipFrame.real_pos
	

	
	self.ShipFrame.master_coordinate_center = customFlightVariables.master_coordinate_center or self.ShipFrame.real_pos:round(0.001)

	self.ShipFrame.coordinate_center = customFlightVariables.coordinate_center or self.ShipFrame.real_pos:round(0.001)
	


	local default_pos=self.ShipFrame.coordinate_center

	if customFlightVariables.relative_starting_pos and not customFlightVariables.starting_pos then
		default_pos =customFlightVariables.relative_starting_pos + self.ShipFrame.coordinate_center
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
	
	
	
	self.ShipFrame.cooldown_report = 1
	self.ShipFrame.report_on=false


	self.ShipFrame.master_ship=140
	

	self.ShipFrame.boundaries ={vector.new(0,0,0),vector.new(60,150,80),vector.new(-60,10,-60)}

	self.ShipFrame.trilateration_index=0
	self.ShipFrame.orientation_index=0
	self.ShipFrame.trilateration_average_max=10
	self.ShipFrame.orientation_average_max=3
	self.ShipFrame.orientation_cache={}
	self.ShipFrame.trilateration_cache={}
	
	self.ShipFrame.manual_move=false
	self.ShipFrame.in_figure=false

	self.ShipFrame.in_figure=nil
	
	self.ShipFrame.pause_report = false

	self.ShipFrame.update_others=false


	self.ShipFrame.exp_search_range=30
	self.ShipFrame.follow_range=1000
	self.stop_drone = false
	self.trilateration_history={}

	self.ShipFrame.no_avg_center=false

	self.ShipFrame.report_header="TimeStamp;Coordinate Center;Angle;Lost;InFigure;Shape\n"

	self.ShipFrame.target_global_position = self.ShipFrame.objective_global_position + self.ShipFrame.coordinate_center
	local new_threads = self:getShapeDroneTreads()
	
	self:addShipThread(new_threads)
end

--threads


function DroneBaseShape:writeCSCLine (params,sep)
	local result =""

	for idx,param in ipairs(params) do

		if not param then
			param ="nan"
		end
		if type(param)=="boolean" or type(param)=="table" then
			param = tostring(param)
		end
		

		if idx<#params then
			result=result..param..sep
		else
			result=result..param.."\n"
		end
	end
	return result
end


function DroneBaseShape:writeLineReport()
	local timestamp = nil
	if self.ShipFrame.pause_time then
		local time_pause = self.ShipFrame.continue_time-self.self.ShipFrame.pause_time
		timestamp = os.time(os.date("!*t")) - time_pause - self.ShipFrame.cumulative_time - self.ShipFrame.start_time_report
		self.ShipFrame.start_time_report = self.ShipFrame.continue_time
		if not  self.ShipFrame.cumulative_time then
			self.ShipFrame.cumulative_time = time_pause
		else
			self.ShipFrame.cumulative_time = self.ShipFrame.cumulative_time + time_pause
		end
	else
	   timestamp = os.time(os.date("!*t")) - self.ShipFrame.start_time_report
	end
	local ship = self.ShipFrame
	local shape_name = "NONE"
	if ship.shape and ship.shape.figure_name_id then
		shape_name=ship.shape.figure_name_id
	end
	local params = {timestamp,
					ship.coordinate_center:tostring(),
					ship.angle_offset,
					ship.lost,
					ship.in_figure,
					shape_name
				}

	local lineCSV = self:writeCSCLine(params, ";")
	print(self.ShipFrame.report_file)
	ship.report_file = io.open(self.ShipFrame.file_path,"a")
	ship.report_file:write(lineCSV)
end


function DroneBaseShape:getShapeDroneTreads()
	
	return {function ()
					
					while self.ShipFrame.run_firmware do
						
						if self.ShipFrame.started_experiment then
							
							local targets = self:radar_ships()
							self:TrilaterationRequest(targets)
							
						end
						os.sleep(self.ShipFrame.trilateration_cooldown_request)
					end
					return
			end,
					
			function ()
				while self.ShipFrame.run_firmware do
					if self.ShipFrame.report_on then
						self:writeLineReport()
						
						os.sleep(self.ShipFrame.cooldown_report)
					else
						
						os.sleep(1)
					end
				end	
					
			end
	}

end







return DroneBaseShape