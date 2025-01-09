--PHOBOSS--
--[[ 
function clampB(x, min, max) --benchmark speed: 0.076612 seconds
    return math.max(math.min(x, max), min)
end

function clampC(x, min, max) --benchmark speed: 0.030656 seconds
    return x < min and min or x > max and max or x
end

local n = 1e6
local function benchmarkingTimer(f, n)
  local clock = os.clock
  local before = clock()
  minn = -5
  maxx = 5
  for i=1,n do
    f(i,minn,maxx)
  end
  local after = clock()
  return after-before
end

print(string.format("clamp A took %f seconds", benchmarkingTimer(clampA, n)))
print(string.format("clamp B Took %f seconds", benchmarkingTimer(clampB, n)))
print(string.format("clamp C Took %f seconds", benchmarkingTimer(clampC, n)))
]]--

utilities = {}

function utilities.clamp(x, min, max)--benchmark speed: 0.027751 seconds
    if x < min then return min end
    if x > max then return max end
    return x
end



--[[ 
function len(table) return len of table
]]--

function utilities.lenTable(table)
	local count=0
	
	if (not table) then
		return 0
	end
	for _ in pairs(table)do 
		count=count+1
	end
	return count
end












function utilities.table_to_vector(vector_input)

	return vector.new(utilities.round(vector_input.x),utilities.round(vector_input.y),utilities.round(vector_input.z))
end

local function trilaterate(A, B, C)
    local a2b = B.vPosition - A.vPosition
    local a2c = C.vPosition - A.vPosition


	


    if math.abs(a2b:normalize():dot(a2c:normalize())) > 0.999 then
        return nil
		
    end

    local d = a2b:length()
    local ex = a2b:normalize( )
    local i = ex:dot(a2c)
    local ey = (a2c - ex * i):normalize()
    local j = ey:dot(a2c)
    local ez = ex:cross(ey)

    local r1 = A.nDistance
    local r2 = B.nDistance
    local r3 = C.nDistance

	if math.abs(d)<0.1 then
		
		return nil
	end

	if math.abs(j)<0.1 then
		return nil
	end

    local x = (r1 * r1 - r2 * r2 + d * d) / (2 * d)
    local y = (r1 * r1 - r3 * r3 - x * x + (x - i) * (x - i) + j * j) / (2 * j)
	

    local result = A.vPosition + ex * x + ey * y

    local zSquared = r1 * r1 - x * x - y * y
    if zSquared > 0 then
        local z = math.sqrt(zSquared)
        local result1 = result + ez * z
        local result2 = result - ez * z

        local rounded1, rounded2 = result1:round(0.01), result2:round(0.01)
        if rounded1.x ~= rounded2.x or rounded1.y ~= rounded2.y or rounded1.z ~= rounded2.z then
            return rounded1, rounded2
        else
            return rounded1
        end
    end
    return result:round(0.01)
end


function utilities.trilateration(drone_list)

	local p1=utilities.table_to_vector(drone_list[1].relative_pos)
    local p2=utilities.table_to_vector(drone_list[2].relative_pos) 
    local p3=utilities.table_to_vector(drone_list[3].relative_pos)  

	--print("fuck me ||p1||",p1,"||p2||",p2,"||p3||",p3)

    local r1=drone_list[1].distance
    local r2=drone_list[2].distance
    local r3=drone_list[3].distance

	--print("fuck me",r1,r2,r3)

	local A ={vPosition=p1,nDistance=r1}
	local B ={vPosition=p2,nDistance=r2}
	local C ={vPosition=p3,nDistance=r3}

	--print("fuck",p1.x,p2.x,p3.x)

	--implementation of computercraft trilaterate
	
	local result = trilaterate(A,B,C)


	--print("fuck me",result)
	
	return result
	end

	


function utilities.add_scalar(vec,scalar)
	vec.x=vec.x+scalar
	vec.y=vec.y+scalar
	vec.z=vec.z+scalar
	return vector.new(vec.x,vec.y,vec.z)
end


function utilities.sub_scalar(vec,scalar)
	vec.x=vec.x+scalar
	vec.y=vec.y+scalar
	vec.z=vec.z+scalar
	return vector.new(vec.x,vec.y,vec.z)
end


--Thanks to rv55 from: https://stackoverflow.com/questions/1318220/lua-decimal-sign
function utilities.sign(x) --faster, caution: doesn't return 0
  return x<0 and -1 or 1
end

function utilities.vec_distance(vec1,vec2)
	return math.sqrt((vec2.x - vec1.x)^2 +(vec2.y - vec1.y)^2+(vec2.z - vec1.z)^2)

end

function utilities.clamp_vector3(vec,minn,maxx)
	if(type(minn) == "number" and type(maxx) == "number") then
		return vector.new(utilities.clamp(vec.x,minn,maxx),utilities.clamp(vec.y,minn,maxx),utilities.clamp(vec.z,minn,maxx))
	end
	return vector.new(utilities.clamp(vec.x,minn.x,maxx.x),utilities.clamp(vec.y,minn.y,maxx.y),utilities.clamp(vec.z,minn.z,maxx.z))
end

function utilities.sign_vector3(vec)
	return vector.new(utilities.sign(vec.x),utilities.sign(vec.y),utilities.sign(vec.z))
end

function utilities.abs_vector3(vec)
	return vector.new(math.abs(vec.x),math.abs(vec.y),math.abs(vec.z))
end

function utilities.roundTo(value,place)
	return math.floor(value * place)/place
end

function utilities.roundTo_vector3(value,place)
	return vector.new(math.floor(value.x * place)/place,math.floor(value.y * place)/place,math.floor(value.z * place)/place)
end

function utilities.round(value)
	return math.floor(value + 0.5)
end

function utilities.round_vector3(value)
	return vector.new(math.floor(value.x + 0.5),math.floor(value.y + 0.5),math.floor(value.z + 0.5))
end


--thanks to FrancisPostsHere: https://www.youtube.com/watch?v=ZfRaYTPUHCU
--https://pastebin.pl/view/e157c3e2
function utilities.quadraticSolver(a,b,c)--at^2 + bt + c = 0
	local sol_1=nil
	local sol_2=nil
	
	local discriminator = (b*b) - (4*a*c)
	local discriminator_squareroot = math.sqrt(math.abs(discriminator))
	local denominator = 2*a
	
	if (discriminator==0) then
		sol_1 = -b/denominator
		return discriminator,sol_1,sol_1
	elseif (discriminator>0) then
		sol_1 = ((-b)+discriminator_squareroot)/denominator
		sol_2 = ((-b)-discriminator_squareroot)/denominator
		return discriminator,sol_1,sol_2
	end
	
	return discriminator,sol_1,sol_2--I would use complex imaginary numbers but... meh
end


--distributed PWM redstone algorithm
--[[Thanks to NikZapp: https://www.youtube.com/channel/UCzlyClqJtuPS3IgHOtdP_Jw]]--
function utilities.pwm()
	return{
	last_output_float_error=vector.new(0,0,0),
	run=function(self,rs)
		local pid_out_w_error = rs:add(self.last_output_float_error)
		output = utilities.round_vector3(pid_out_w_error)
		self.last_output_float_error = pid_out_w_error:sub(output)
		return output
	end
	}
end

function utilities.PwmScalar()
	return{
	last_output_float_error=0,
	run=function(self,rs)
		local pid_out_w_error = rs+self.last_output_float_error
		output = utilities.round(pid_out_w_error)
		self.last_output_float_error = pid_out_w_error-output
		return output
	end
	}
end
function utilities.PwmMatrix(init_row,init_column)
	return{
	last_output_float_error=matrix(init_row,init_column,0),
	run=function(self,rs_matrix)
		local pid_out_w_error = matrix.add(rs_matrix,self.last_output_float_error)
		local output = matrix.roundClone(pid_out_w_error,0)
		self.last_output_float_error = matrix.sub(pid_out_w_error,output)
		return output
	end
	}
end



function utilities.PwmMatrixList(list_size)
	local l = {}
	for i=1,list_size do
		l[i]=0
	end
	return{
	last_output_float_error=l,
	run=function(self,rs_matrix)--expects 1 column matrix
		local pid_out_w_error={}
		local output = {}
		for i=1,#rs_matrix do
			pid_out_w_error[i] = rs_matrix[i][1]+self.last_output_float_error[i]
			output[i] = utilities.round(pid_out_w_error[i])
			self.last_output_float_error[i] = pid_out_w_error[i]-output[i]
		end
		return output
	end
	}
end


function utilities.IntegerScroller(value,minimum,maximum)
	return{
		value=value,
		maximum = maximum,
		minimum = minimum,
		override=function(self,new_value)
			value = utilities.clamp(new_value, minimum, maximum)
		end,
		set=function(self,delta)
			value = utilities.clamp(value+delta, minimum, maximum)
		end,
		get=function(self)
			return value
		end
	}
end


function utilities.NonBlockingCooldownCounter(cooldown)
	return{
		count = 0,
		prev_time=os.clock(),
		cooldown=cooldown,
		start=function(self)
			self.prev_time=os.clock()
			self.count = 0
		end,
		increment=function(self)
			local curr_time = os.clock()
			self.count = math.fmod(self.count + (curr_time - self.prev_time),self.cooldown)
			self.prev_time = curr_time
		end,
	}
end

function utilities.NonBlockingCooldownTimer(cooldown)
	return{
		prev_time=os.clock(),
		cooldown=cooldown,
		start=function(self)
			self.prev_time=os.clock()
		end,
		check=function(self)
			local curr_time = os.clock()
			return curr_time-self.prev_time>=self.cooldown
		end,
		reset=function(self)
			local curr_time = os.clock()
			self.prev_time=curr_time
		end
	}
end

function utilities.ArrayExtract(t, fnKeep)
    local j, n = 1, #t;
    local new_t={}
    for i=1,n do
        if (fnKeep(t, i, j)) then
            table.insert(new_t,t[i])
        end
    end
    return new_t;
end

--https://stackoverflow.com/questions/12394841/safely-remove-items-from-an-array-table-while-iterating
--by Mitch McMabers
function utilities.ArrayRemove(t, fnKeep)
    local j, n = 1, #t;

    for i=1,n do
        if (fnKeep(t, i, j)) then
            -- Move i's kept value to j's position, if it's not already there.
            if (i ~= j) then
                t[j] = t[i];
                t[i] = nil;
            end
            j = j + 1; -- Increment position of where we'll place the next kept value.
        else
            t[i] = nil;
        end
    end

    return t;
end

return utilities