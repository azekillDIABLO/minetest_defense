defense.pathfinder = {}
local pathfinder = defense.pathfinder
pathfinder.path_max_range = 16
pathfinder.fields = {}
pathfinder.classes = {}

local visit_queues = {}
local chunk_size = 16

function pathfinder:register_class(class, properties)
	self.fields[class] = self.fields[class] or {}
	self.classes[class] = properties
	visit_queues[class] = Queue.new()
end

-- Returns a number
-- function pathfinder:get_distance(class, position)
-- 	local field = self:get_field(class, position)
-- 	if not field then
-- 		return nil
-- 	end
-- 	return field.distance
-- end

-- Returns a vector
function pathfinder:get_direction(class, position)
	local field = self:get_field(class, position)
	if not field then
		return nil
	end
	if field.distance == 0 then
		return {x=0, y=0, z=0}
	end
	return ({{x=-1, y=0, z=0},
		{x=1, y=0, z=0},
		{x=0, y=-1, z=0},
		{x=0, y=1, z=0},
		{x=0, y=0, z=-1},
		{x=0, y=0, z=1}})
			[field.direction]
end

-- Returns a table {time, distance}
function pathfinder:get_field(class, position)
	local collisionbox = self.classes[class].collisionbox
	local x = math.floor(position.x + collisionbox[1])
	local y = math.floor(position.y + collisionbox[2])
	local z = math.floor(position.z + collisionbox[3])

	local chunk_key = math.floor(x/chunk_size) ..
		":" .. math.floor(y/chunk_size) ..
		":" .. math.floor(z/chunk_size)
	local chunk = self.fields[class][chunk_key]
	if not chunk then
		return nil
	end

	local cx = x % chunk_size
	local cy = y % chunk_size
	local cz = z % chunk_size
	local index = (cy * chunk_size + cz) * chunk_size + cx
	return chunk[index]
end

function pathfinder:set_field(class, position, distance, direction, time)
	local collisionbox = self.classes[class].collisionbox
	local x = math.floor(position.x + collisionbox[1])
	local y = math.floor(position.y + collisionbox[2])
	local z = math.floor(position.z + collisionbox[3])

	local chunk_key = math.floor(x/chunk_size) ..
		":" .. math.floor(y/chunk_size) ..
		":" .. math.floor(z/chunk_size)
	local chunk = self.fields[class][chunk_key]
	if not chunk then
		chunk = {}
		self.fields[class][chunk_key] = chunk
	end

	local cx = x % chunk_size
	local cy = y % chunk_size
	local cz = z % chunk_size
	local index = (cy * chunk_size + cz) * chunk_size + cx
	chunk[index] = {time=time, direction=direction, distance=distance}
end

function pathfinder:update(dtime)
	if not defense:is_dark() then
		-- reset flow fields
		return
	end

	local neighborhood = {
		{x=1, y=0, z=0},
		{x=-1, y=0, z=0},
		{x=0, y=1, z=0},
		{x=0, y=-1, z=0},
		{x=0, y=0, z=1},
		{x=0, y=0, z=-1},
	}
	-- Update the field
	for c,class in pairs(self.classes) do
		local vq = visit_queues[c]
		local size = Queue.size(vq)
		minetest.debug(size)
		for i=1,math.min(size,1000 * dtime) do
			local current = Queue.pop(vq)
			for di,n in ipairs(neighborhood) do
				local npos = vector.add(current.position, n)
				npos.x = math.floor(npos.x)
				npos.y = math.floor(npos.y)
				npos.z = math.floor(npos.z)
				local cost = class.cost_method(npos, current.position, class.size)
				if cost then
					local next_distance = current.distance + cost
					local neighbor_field = self:get_field(c, npos)
					if not neighbor_field
						or neighbor_field.time < current.time
							and neighbor_field.direction ~= di
						or neighbor_field.time == current.time
							and neighbor_field.distance > next_distance then
						self:set_field(c, npos, next_distance, di, current.time)
						if next_distance < self.path_max_range then
							Queue.push(vq, {
								position = npos,
								distance = next_distance,
								direction = di,
								time = current.time,
							})
						end
					end
				end
			end
		end
	end

	-- Update player positions
	local time = minetest.get_gametime()
	for _,p in ipairs(minetest.get_connected_players()) do
		local pos = p:getpos()
		pos.y = pos.y + 1
		for c,_ in pairs(self.classes) do
			local field = self:get_field(c, pos)
			if not field or field.distance > 0 then
				self:set_field(c, pos, 0, 0, time)
				Queue.push(visit_queues[c], {position=pos, distance=0, direction=0, time=time})
			end
		end
	end
end

pathfinder.cost_method = {}
function pathfinder.cost_method.air(pos, parent, size)
	-- Check if solid
	for y=pos.y,pos.y+size.y-1 do
		for z=pos.z,pos.z+size.z-1 do
			for x=pos.x,pos.x+size.x-1 do
				local node = minetest.get_node_or_nil({x=x, y=y, z=z})
				if not node then return nil end
				if minetest.registered_nodes[node.name].walkable then
					return pathfinder.path_max_range + 1
				end
			end
		end
	end
	return 1
end
function pathfinder.cost_method.ground(pos, parent, size)
	local on_ground = false
	for z=pos.z,pos.z+size.z-1 do
		for x=pos.x,pos.x+size.x-1 do
			-- Check if solid
			for y=pos.y,pos.y+size.y-1 do
				local node = minetest.get_node_or_nil({x=x, y=y, z=z})
				if not node then return nil end
				if minetest.registered_nodes[node.name].walkable then
					return pathfinder.path_max_range + 1
				end
			end

			if not on_ground then
				-- Check if on top of solid
				local node = minetest.get_node_or_nil({x=x, y=pos.y-1, z=z})
				if not node then return nil end
				if minetest.registered_nodes[node.name].walkable then
					on_ground = true
				end
			end
		end
	end
	if not on_ground then
		return pathfinder.path_max_range + 1
	end
	return 1 + math.ceil(math.abs(pos.y - parent.y))
end

minetest.register_globalstep(function(dtime)
	pathfinder:update(dtime)
end)