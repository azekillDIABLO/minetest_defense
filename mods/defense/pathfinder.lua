defense.pathfinder = {}
local pathfinder = defense.pathfinder
pathfinder.path_max_range = 32
pathfinder.path_max_range_long = 64
pathfinder.classes = {}
local chunk_size = 16

-- State
local fields = {}
local visit_queues = {}
local visit_queue_long = Queue.new()
local player_last_update = {}
local morning_reset = false

-- local cid_data = {}
-- minetest.after(0, function()
-- 	for name, def in pairs(minetest.registered_nodes) do
-- 		cid_data[minetest.get_content_id(name)] = {
-- 			name = name,
-- 			walkable = def.walkable,
-- 		}
-- 	end
-- end)

function pathfinder:register_class(class, properties)
	self.classes[class] = properties
	fields[class] = fields[class] or {}
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
	local directions = {
		{x=0, y=-1, z=0},
		{x=0, y=1, z=0},
		{x=0, y=0, z=-1},
		{x=1, y=0, z=0},
		{x=-1, y=0, z=0},
		{x=0, y=0, z=1},
	}

	local total = vector.new(0, 0, 0)
	local count = 0
	local time = minetest.get_gametime()

	local cells = {
		position,
		{x=position.x + 1, y=position.y, z=position.z},
		{x=position.x - 1, y=position.y, z=position.z},
		{x=position.x, y=position.y + 1, z=position.z},
		{x=position.x, y=position.y - 1, z=position.z},
		{x=position.x, y=position.y, z=position.z + 1},
		{x=position.x, y=position.y, z=position.z - 1},
	}
	for _,p in ipairs(cells) do
		local field = self:get_field(class, p)
		if field then
			local last_time = player_last_update[field.player] or field.time
			if last_time + field.distance * 4 > time then
				local direction = directions[field.direction]
				total = vector.add(total, direction)
			end
		end
	end

	if total.x ~= 0 or total.y ~= 0 or total.z ~= 0 then
		return vector.normalize(total)
	else
		return nil
	end
end

-- Returns a table {time, distance}
function pathfinder:get_field(class, position)
	local collisionbox = self.classes[class].collisionbox
	local x = math.floor(position.x + collisionbox[1] + 0.01)
	local y = math.floor(position.y + collisionbox[2] + 0.01)
	local z = math.floor(position.z + collisionbox[3] + 0.01)

	local chunk_key = math.floor(x/chunk_size) ..
		":" .. math.floor(y/chunk_size) ..
		":" .. math.floor(z/chunk_size)
	local chunk = fields[class][chunk_key]
	if not chunk then
		return nil
	end

	local cx = x % chunk_size
	local cy = y % chunk_size
	local cz = z % chunk_size
	local index = (cy * chunk_size + cz) * chunk_size + cx
	return chunk[index]
end

function pathfinder:set_field(class, position, player, distance, direction, time)
	local collisionbox = self.classes[class].collisionbox
	local x = math.floor(position.x + collisionbox[1] + 0.01)
	local y = math.floor(position.y + collisionbox[2] + 0.01)
	local z = math.floor(position.z + collisionbox[3] + 0.01)

	local chunk_key = math.floor(x/chunk_size) ..
		":" .. math.floor(y/chunk_size) ..
		":" .. math.floor(z/chunk_size)
	local chunk = fields[class][chunk_key]
	if not chunk then
		chunk = {}
		fields[class][chunk_key] = chunk
	end

	local cx = x % chunk_size
	local cy = y % chunk_size
	local cz = z % chunk_size
	local index = (cy * chunk_size + cz) * chunk_size + cx
	chunk[index] = {time=time, direction=direction, distance=distance, player=player}
end

function pathfinder:delete_field(class, position)
	local collisionbox = self.classes[class].collisionbox
	local x = math.floor(position.x + collisionbox[1] + 0.01)
	local y = math.floor(position.y + collisionbox[2] + 0.01)
	local z = math.floor(position.z + collisionbox[3] + 0.01)

	local chunk_key = math.floor(x/chunk_size) ..
		":" .. math.floor(y/chunk_size) ..
		":" .. math.floor(z/chunk_size)
	local chunk = fields[class][chunk_key]
	if not chunk then
		return
	end

	local cx = x % chunk_size
	local cy = y % chunk_size
	local cz = z % chunk_size
	local index = (cy * chunk_size + cz) * chunk_size + cx
	chunk[index] = nil
end

function pathfinder:update(dtime)
	if not defense:is_dark() then
		-- reset flow fields in the morning
		if not morning_reset then
			morning_reset = true
			player_last_update = {}
			for c,_ in pairs(self.classes) do
				fields[c] = {}
				visit_queues[c] = Queue.new()
			end
		end
		return
	end
	morning_reset = false

	local neighborhood = {
		{x=0, y=1, z=0},
		{x=0, y=-1, z=0},
		{x=0, y=0, z=1},
		{x=-1, y=0, z=0},
		{x=1, y=0, z=0},
		{x=0, y=0, z=-1},
	}
	-- Update the field
	local total_queues_size = 0
	for c,class in pairs(self.classes) do
		local vq = visit_queues[c]
		local size = Queue.size(vq)
		local max_iter = 100 - math.floor(defense.director.intensity * 90)
		for i=1,math.min(size,max_iter) do
			local current = Queue.pop(vq)
			for di,n in ipairs(neighborhood) do
				local npos = vector.add(current.position, n)
				npos.x = math.floor(npos.x)
				npos.y = math.floor(npos.y)
				npos.z = math.floor(npos.z)
				local cost = class.cost_method(class, npos, current.position)
				if cost then
					local next_distance = current.distance + cost
					local neighbor_field = self:get_field(c, npos)
					if not neighbor_field
						or neighbor_field.time < current.time
							and neighbor_field.direction ~= di
						or neighbor_field.time == current.time
							and neighbor_field.distance > next_distance then
						if next_distance < self.path_max_range then
							if size < 800 then
								self:set_field(c, npos, current.player, next_distance, di, current.time)
								Queue.push(vq, {
									position = npos,
									player = current.player,
									distance = next_distance,
									direction = di,
									time = current.time,
								})
							end
						elseif next_distance < self.path_max_range_long then
							Queue.push(visit_queue_long, {
								class = c,
								position = npos,
								player = current.player,
								distance = next_distance,
								direction = di,
								time = current.time,
							})
						else
							self:delete_field(c, npos)
						end
					end
				end
			end
		end
		total_queues_size = total_queues_size + math.max(0, size - max_iter)
	end

	-- Update far fields
	if total_queues_size == 0 then
		if Queue.size(visit_queue_long) > 0 then
			local current = Queue.pop(visit_queue_long)
			Queue.push(visit_queues[current.class], current)
		end
	end

	-- Update player positions
	local time = minetest.get_gametime()
	for _,p in ipairs(minetest.get_connected_players()) do
		local pos = p:getpos()
		for c,_ in pairs(self.classes) do
			for y=pos.y-0.5,pos.y+0.5 do
				local tp = {x=pos.x, y=y, z=pos.z}
				local field = self:get_field(c, tp)
				if not field or field.distance > 0 then
					local name = p:get_player_name()
					self:set_field(c, tp, name, 0, 4, time)
					Queue.push(visit_queues[c], {position=tp, player=name, distance=0, direction=0, time=time})
					player_last_update[name] = time
				end
			end
		end
	end
end

pathfinder.cost_method = {}
function pathfinder.cost_method.air(class, pos, parent)
	-- Check if solid
	for y=pos.y,pos.y+class.size.y-1 do
		for z=pos.z,pos.z+class.size.z-1 do
			for x=pos.x,pos.x+class.size.x-1 do
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
function pathfinder.cost_method.ground(class, pos, parent)
	-- Check if in solid
	for z=pos.z,pos.z+class.size.z-1 do
		for x=pos.x,pos.x+class.size.x-1 do
			for y=pos.y,pos.y+class.size.y-1 do
				local node = minetest.get_node_or_nil({x=x, y=y, z=z})
				if not node then return nil end
				if minetest.registered_nodes[node.name].walkable then
					return pathfinder.path_max_range + 1
				end
			end
		end
	end

	-- Check if on top of solid
	local ground_distance = 9999
	for z=pos.z,pos.z+class.size.z-1 do
		for x=pos.x,pos.x+class.size.x-1 do
			for y=pos.y-1,pos.y-class.jump_height-1,-1 do
				local node = minetest.get_node_or_nil({x=x, y=y, z=z})
				if not node then return nil end
				if minetest.registered_nodes[node.name].walkable then
					ground_distance = math.min(ground_distance, pos.y - y)
					if ground_distance == 1 then
						return 1
					end
					break
				end
			end
		end
	end

	if ground_distance > 1 then
		if ground_distance <= class.jump_height + 1 then
			local ledges = {
				{x=pos.x + class.size.x, y=pos.y - 1, z=pos.z},
				{x=pos.x - 1, y=pos.y - 1, z=pos.z},
				{x=pos.x, y=pos.y - 1, z=pos.z + class.size.z},
				{x=pos.x, y=pos.y - 1, z=pos.z - 1},
			}
			for _,l in ipairs(ledges) do
				local node = minetest.get_node_or_nil(l)
				if not node then return nil end
				if minetest.registered_nodes[node.name].walkable then
					return ground_distance
				end
			end
		end

		-- Check if this is a fall
		if parent.y < pos.y then
			return 2
		end

		return pathfinder.path_max_range + 1
	end

	return 1
end

minetest.register_globalstep(function(dtime)
	pathfinder:update(dtime)
end)