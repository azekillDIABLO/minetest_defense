defense.pathfinder = {}
local pathfinder = defense.pathfinder
pathfinder.update_interval = 2.0
pathfinder.max_sector_size = 16
pathfinder.max_sector_count = 800
pathfinder.max_distance = 100
pathfinder.class_names = {}

local classes = {}
local sector_id_counter = 0
local tmp_vec = vector.new()

local reg_nodes = minetest.registered_nodes
local neighbors = {
	{x =-1, y = 0, z = 0},
	{x = 1, y = 0, z = 0},
	{x = 0, y =-1, z = 0},
	{x = 0, y = 1, z = 0},
	{x = 0, y = 0, z =-1},
	{x = 0, y = 0, z = 1},
}

local function pos_key(x, y, z)
	tmp_vec.x = x
	tmp_vec.y = y
	tmp_vec.z = z
	return minetest.hash_node_position(tmp_vec)
end

-- Returns object {surface=[min_x,min_y,min_z,max_x,max_y,max_z], normal={x,y,z}}
local function compute_sector_interface(sector1, sector2)
	local min_x = math.max(sector1.min_x, sector2.min_x)
	local min_y = math.max(sector1.min_y, sector2.min_y)
	local min_z = math.max(sector1.min_z, sector2.min_z)

	local max_x = math.min(sector1.max_x, sector2.max_x)
	local max_y = math.min(sector1.max_y, sector2.max_y)
	local max_z = math.min(sector1.max_z, sector2.max_z)

	local normal = vector.new()

	if min_x > max_x then
		min_x = (min_x + max_x) / 2
		max_x = min_x
		normal.x = sector1.min_x < sector2.min_x and 1 or -1
		normal.y = 0
		normal.z = 0
	elseif min_y > max_y then
		min_y = (min_y + max_y) / 2
		max_y = min_y
		normal.x = 0
		normal.y = sector1.min_y < sector2.min_y and 1 or -1
		normal.z = 0
	elseif min_z > max_z then
		min_z = (min_z + max_z) / 2
		max_z = min_z
		normal.x = 0
		normal.y = 0
		normal.z = sector1.min_z < sector2.min_z and 1 or -1
	end

	return {
		surface = {
			min_x,min_y,min_z,
			max_x,max_y,max_z
		},
		normal = normal,
	}
end

local function to_world_pos(class, vec)
	return {
		x = vec.x + (class.x_size - 1 - class.collisionbox[1] - class.collisionbox[4]) / 2,
		y = vec.y + (class.y_size - 1 - class.collisionbox[2] - class.collisionbox[5]) / 2,
		z = vec.z + (class.z_size - 1 - class.collisionbox[3] - class.collisionbox[6]) / 2,
	}
end

local function to_grid_pos(class, vec)
	return {
		x = math.floor(vec.x + class.x_offset + 0.5),
		y = math.floor(vec.y + class.y_offset + 0.5),
		z = math.floor(vec.z + class.z_offset + 0.5)
	}
end

local function get_player_pos(player)
	local pos = player:getpos()
	return math.floor(pos.x + 0.5), math.floor(pos.y + 0.5), math.floor(pos.z + 0.5)
end

local function sector_contains(sector, x, y, z)
	return x <= sector.max_x and x >= sector.min_x
		and y <= sector.max_y and y >= sector.min_y
		and z <= sector.max_z and z >= sector.min_z
end

local function find_containing_sector(class, x, y, z)
	for i,s in pairs(class.sectors) do
		if (sector_contains(s, x, y, z)) then
			return s
		end
	end
	return nil
end

-- Deletes and queues a sector for regeneration
local function invalidate_sector(sector, class)
	local id = sector.id
	class.sectors[id] = nil

	for i,l in pairs(sector.links) do
		l.links[id] = nil
	end

	if sector.distance ~= nil and sector.distance <= pathfinder.max_distance then
		Queue.push(class.sector_seeds, {sector.min_x,sector.min_y,sector.min_z, nil,0})
		-- TODO what if replacement seed is blocked?
	end

end

local function invalidate_containing_sector(class, x, y, z)
	local sector = find_containing_sector(class, x, y, z)
	if sector then
		invalidate_sector(sector, class)
	end
end

-- Calculates the distances for each sector
local function calculate_distances(class)
	local cost_method = class.cost_method

	local sectors = class.sectors
	for i,s in pairs(sectors) do
		s.distance = nil
	end

	local visited_ids = {}
	local visit = Queue.new()

	local players = minetest.get_connected_players()
	if #players then
		for _,p in ipairs(players) do
			local x, y, z = get_player_pos(p)

			local sector = find_containing_sector(class, x, y, z)
			if sector then
				sector.distance = 0
				Queue.push(visit, sector)
			end
		end
	end

	while Queue.size(visit) > 0 do
		local sector = Queue.pop(visit)
		visited_ids[sector.id] = true

		local distance = sector.distance
		for i,l in pairs(sector.links) do
			if not visited_ids[i] then
				local cost = cost_method(class, sector, l)
				local new_ldist = distance + cost
				local ldist = l.distance
				if ldist == nil or ldist > new_ldist then
					l.distance = new_ldist
					Queue.push(visit, l)
				end
			end
		end
	end
end

-- Returns array [x,y,z, parent,parent_dir]
local function find_sector_exits(sector, class)
	local sides = {
		{0,1,1,
		sector.max_x + 1, sector.min_y, sector.min_z,
		sector.max_x + 1, sector.max_y, sector.max_z},
		{0,1,1,
		sector.min_x - 1, sector.min_y, sector.min_z,
		sector.min_x - 1, sector.max_y, sector.max_z},
		{1,0,1,
		sector.min_x, sector.max_y + 1, sector.min_z,
		sector.max_x, sector.max_y + 1, sector.max_z},
		{1,0,1,
		sector.min_x, sector.min_y - 1, sector.min_z,
		sector.max_x, sector.min_y - 1, sector.max_z},
		{1,1,0,
		sector.min_x, sector.min_y, sector.max_z + 1,
		sector.max_x, sector.max_y, sector.max_z + 1},
		{1,1,0,
		sector.min_x, sector.min_y, sector.min_z - 1,
		sector.max_x, sector.max_y, sector.min_z - 1},
	}

	local path_check = class.path_check

	local exits = {}

	-- Find passable nodes that are cornered by >=2 different sectors or passability
	for i,s in ipairs(sides) do
		local xs = s[1]
		local ys = s[2]
		local zs = s[3]
		local min_x = s[4]
		local min_y = s[5]
		local min_z = s[6]
		local max_x = s[7]
		local max_y = s[8]
		local max_z = s[9]

		local map = {}

		for z = min_z,max_z,zs do
			for y = min_y,max_y,ys do
				for x = min_x,max_x,xs do

					local hash = pos_key(x, y, z)

					-- TODO Supply parent pos to path_check
					if path_check(class, vector.new(x, y, z), nil) then

						local val = 0
						local esec = find_containing_sector(class, x, y, z)
						if esec then
							val = esec.id
						end

						local edges = 0
						
						if xs ~= 0 and val ~= map[pos_key(x-xs, y, z)] then
							edges = edges + 1
						end
						if ys ~= 0 and val ~= map[pos_key(x, y-ys, z)] then
							edges = edges + 1
						end
						if zs ~= 0 and val ~= map[pos_key(x, y, z-zs)] then
							edges = edges + 1
						end

						if edges >= 2 then
							table.insert(exits, {x,y,z, sector,i})
						end

						map[hash] = val
					else
						map[hash] = -1
					end

					if xs == 0 then break end
				end
				if ys == 0 then break end
			end
			if zs == 0 then break end
		end
	end

	return exits
end

-- Returns a sector object {id, distance, links, min_x,min_y,min_z, max_x,max_y,max_z}
local function generate_sector(class, x, y, z, origin_dir)
	local max_sector_span = pathfinder.max_sector_size - 1
	local path_check = class.path_check

	local hmss = math.floor(max_sector_span / 2)
	local hmss2 = math.ceil(max_sector_span / 2)
	local span_min_x = x - hmss
	local span_min_y = y - hmss
	local span_min_z = z - hmss
	local span_max_x = x + hmss2
	local span_max_y = y + hmss2
	local span_max_z = z + hmss2

	local min_x = x
	local min_y = y
	local min_z = z
	local max_x = x
	local max_y = y
	local max_z = z


	local passed = {}
	local visit = Queue.new()

	Queue.push(visit, {x=x,y=y,z=z})
	passed[pos_key(x, y, z)] = true

	-- Flood fill all passable positions
	while Queue.size(visit) > 0 do
		local pos = Queue.pop(visit)
		local px = pos.x
		local py = pos.y
		local pz = pos.z

		for i,n in ipairs(neighbors) do
			if i ~= origin_dir then
				local npos = vector.add(pos, n)
				local nx = npos.x
				local ny = npos.y
				local nz = npos.z

				local nhash = pos_key(nx, ny, nz)
				if not passed[nhash]
				   and (n.x == math.sign(nx - x) -- Only spread outward
				        or n.y == math.sign(ny - y) 
				        or n.z == math.sign(nz - z))
				   and nx >= span_min_x and nx <= span_max_x -- Limit to max_sector_span
				   and ny >= span_min_y and ny <= span_max_y
				   and nz >= span_min_z and nz <= span_max_z then

					local pass = path_check(class, npos, pos)
					if pass == nil then return nil end
					if pass and not find_containing_sector(class, nx, ny, nz) then
						Queue.push(visit, npos)
						passed[nhash] = true
						min_x = math.min(min_x, nx)
						min_y = math.min(min_y, ny)
						min_z = math.min(min_z, nz)
						max_x = math.max(max_x, nx)
						max_y = math.max(max_y, ny)
						max_z = math.max(max_z, nz)
					end

				end
			end
		end
	end


	-- Find the largest passable box
	--[[ Using dynamic programming:
		
		S(x,y,z) = { 1 + min S(x-a,y-b,z-c) for 1 <= a+b+c <= 3 and max(x,y,z) == 1,  if passable(x,y)
		
		The largest cube is the maximum S, with the top-right-far corner at (x,y,z) in which the maximum S value is found.
		Using the largest cube as the starting point, the largest box can be found by finding equal and adjacent S values.
	]]
	local x_stride = 1
	local y_stride = max_x - min_x + 2
	local z_stride = (max_y - min_y + 2) * y_stride

	-- Compute S
	local s_matrix = {}
	local s_max = 0

	local index = z_stride
	for iz = min_z,max_z do
		index = index + y_stride
		for iy = min_y,max_y do
			index = index + x_stride
			for ix = min_x,max_x do

				if passed[pos_key(ix, iy, iz)] then
					local s = 1 + math.min(
						s_matrix[index - x_stride] or 0,
						s_matrix[index - y_stride] or 0,
						s_matrix[index - z_stride] or 0,
						s_matrix[index - x_stride - y_stride] or 0,
						s_matrix[index - x_stride - z_stride] or 0,
						s_matrix[index - y_stride - z_stride] or 0,
						s_matrix[index - x_stride - y_stride - z_stride] or 0)
					s_matrix[index] = s
					s_max = math.max(s_max, s)
				else
					s_matrix[index] = 0
				end

				index = index + 1
			end
		end
	end

	-- Starting at (x,y,z), go up the S gradient until a corner is found
	local edge_x, edge_y, edge_z = false, false, false
	max_x, max_y, max_z = x, y, z
	index = (max_z - min_z + 1) * z_stride + (max_y - min_y + 1) * y_stride + (max_x - min_x + 1) * x_stride
	while true do
		local s = s_matrix[index] or 0
		if (s_matrix[index + x_stride + y_stride + z_stride] or -1) > s and not (edge_x or edge_y or edge_z) then
			index = index + x_stride + y_stride + z_stride
			max_x = max_x + 1
			max_y = max_y + 1
			max_z = max_z + 1
		elseif (s_matrix[index + x_stride + y_stride] or -1) > s and not (edge_x or edge_y) then
			index = index + x_stride + y_stride
			max_x = max_x + 1
			max_y = max_y + 1
			edge_z = true
		elseif (s_matrix[index + x_stride + z_stride] or -1) > s and not (edge_x or edge_z) then
			index = index + x_stride + z_stride
			max_x = max_x + 1
			max_z = max_z + 1
			edge_y = true
		elseif (s_matrix[index + y_stride + z_stride] or -1) > s and not (edge_y or edge_z) then
			index = index + y_stride + z_stride
			max_y = max_y + 1
			max_z = max_z + 1
			edge_x = true
		elseif (s_matrix[index + x_stride] or -1) >= s and not edge_x then
			index = index + x_stride
			max_x = max_x + 1
			edge_y = true
			edge_z = true
		elseif (s_matrix[index + y_stride] or -1) >= s and not edge_y then
			index = index + y_stride
			max_y = max_y + 1
			edge_x = true
			edge_z = true
		elseif (s_matrix[index + z_stride] or -1) >= s and not edge_z then
			index = index + z_stride
			max_z = max_z + 1
			edge_x = true
			edge_y = true
		else
			break
		end
	end

	-- (max_x,max_y,max_z) or [index] is now a corner of a cube
	local base_size = s_matrix[index]

	-- Compute extended dimensions
	local w, h, l = 0, 0, 0
	for iw = 1,max_sector_span do
		if s_matrix[index - iw * x_stride] ~= base_size then break end
		w = iw
	end
	for ih = 1,max_sector_span do
		if s_matrix[index - ih * y_stride] ~= base_size then break end
		h = ih
	end
	for il = 1,max_sector_span do
		if s_matrix[index - il * z_stride] ~= base_size then break end
		l = il
	end

	-- Compute final bounds (cube base size + extended dimensions)
	min_x = max_x - base_size + 1
	min_y = max_y - base_size + 1
	min_z = max_z - base_size + 1
	local max_dim = math.max(w,h,l)
	if max_dim == w then
		min_x = min_x - w
		if s_matrix[index - x_stride - y_stride] == base_size then
			min_y = min_y - h
		elseif s_matrix[index - x_stride - z_stride] == base_size then
			min_z = min_z - l
		end
	elseif max_dim == h then
		min_y = min_y - h
		if s_matrix[index - y_stride - x_stride] == base_size then
			min_x = min_x - w
		elseif s_matrix[index - y_stride - z_stride] == base_size then
			min_z = min_z - l
		end
	elseif max_dim == l then
		min_z = min_z - l
		if s_matrix[index - z_stride - x_stride] == base_size then
			min_x = min_x - w
		elseif s_matrix[index - z_stride - y_stride] == base_size then
			min_y = min_y - h
		end
	end


	sector_id_counter = sector_id_counter + 1
	return {
		id = sector_id_counter,
		distance = nil,
		links = {},
		min_x = min_x,
		min_y = min_y,
		min_z = min_z,
		max_x = max_x,
		max_y = max_y,
		max_z = max_z,
	}
end

-- Removes sectors and seeds too far away from players
local function prune_sectors(class)
	defense:log("Pruning sectors...")
	local max_distance = pathfinder.max_distance
	local sectors = class.sectors
	local sector_seeds = class.sector_seeds

	local players = minetest.get_connected_players()

	-- Remove sectors
	local to_remove = {}

	for i,s in pairs(sectors) do
		if s.distance == nil or s.distance > max_distance then
			to_remove[i] = true
		end
	end

	for i,_ in pairs(to_remove) do
		local s = sectors[i]
		sectors[i] = nil

		for __,l in pairs(s.links) do
			if not to_remove[l.id] then
				invalidate_sector(l, class)
			end
		end
	end

	-- Remove seeds
	for i = sector_seeds.last,sector_seeds.first,-1 do
		local seed = sector_seeds[i]
		local seed_pos = {x=seed[1], y=seed[2], z=seed[3]}

		local far = true
		for _,p in ipairs(players) do
			local x, y, z = get_player_pos(p)
			if vector.distance({x=x,y=y,z=z}, seed_pos) <= max_distance then
				far = false
			end
		end

		if far then
			Queue.remove(sector_seeds, i)
		end
	end
end


local function update_class(class)
	local max_sector_count = pathfinder.max_sector_count
	local max_distance = pathfinder.max_distance
	local sectors = class.sectors
	local sector_seeds = class.sector_seeds
	local path_check = class.path_check

	local force_generate = 0
	local should_refresh_distances = false

	-- Generate new seeds from player positions
	local players = minetest.get_connected_players()
	if #players then
		for _,p in ipairs(players) do
			local x, y, z = get_player_pos(p)

			local sector = find_containing_sector(class, x, y, z)
			if not sector then
				Queue.push_back(sector_seeds, {x,y,z, nil,0})
				should_refresh_distances = true
				force_generate = force_generate + 1
			else
				local distance = sector.distance
				if distance == nil or distance > 0 then
					should_refresh_distances = true
				end
			end
		end
	end

	-- Grow sector seeds into sectors
	local sector_count = 0
	for _,__ in pairs(sectors) do
		sector_count = sector_count + 1
	end

	local sectors_to_generate = math.max(math.ceil(10 / math.log(sector_count + 10)), 1)
	local target_sector_count = math.min(sector_count + sectors_to_generate, max_sector_count) + force_generate
	while sector_count < target_sector_count and Queue.size(sector_seeds) > 0 do
		local seed = Queue.pop(sector_seeds)
		local x = seed[1]
		local y = seed[2]
		local z = seed[3]

		-- TODO Supply parent pos to path_check
		if not find_containing_sector(class, x, y, z) and path_check(class, {x=x,y=y,z=z}, nil) then
			local new_sector = generate_sector(class, x, y, z, seed[5])
			local parent = seed[4]

			if new_sector then
				should_refresh_distances = true

				if not parent or parent.distance == nil or parent.distance < max_distance then
					local id = new_sector.id
					sectors[id] = new_sector
					sector_count = sector_count + 1

					-- Link parent
					if parent then
						new_sector.links[parent.id] = parent
						parent.links[id] = new_sector
					end

					-- Generate new seeds and link adjacent sectors
					local exits = find_sector_exits(new_sector, class)
					for _,e in ipairs(exits) do
						local exited_sector = find_containing_sector(class, e[1], e[2], e[3])
						if exited_sector then
							if not exited_sector.links[new_sector.id] then
								exited_sector.links[new_sector.id] = new_sector
								new_sector.links[exited_sector.id] = exited_sector
							end
						else
							Queue.push(sector_seeds, e)
						end
					end
				end
			end
		end

	end

	-- Update sector distance values
	if should_refresh_distances then
		calculate_distances(class)
	end

	-- TODO Reseed far exits

	defense:log(class.name .. ": There are " .. sector_count .. " sectors, " .. Queue.size(sector_seeds) .. " seeds.")

	-- Prune excess sectors
	if sector_count + Queue.size(sector_seeds) >= max_sector_count then
		prune_sectors(class)
	end
end

local function update()
	for n,c in pairs(classes) do
		update_class(c)
	end
end


-- Cost methods

pathfinder.default_cost_method = {}
function pathfinder.default_cost_method.air(class, src_sector, dst_sector)
	local dx = ((dst_sector.min_x + dst_sector.max_x) - (src_sector.min_x + src_sector.max_x)) / 2
	local dy = ((dst_sector.min_y + dst_sector.max_y) - (src_sector.min_y + src_sector.max_y)) / 2
	local dz = ((dst_sector.min_z + dst_sector.max_z) - (src_sector.min_z + src_sector.max_z)) / 2
	return math.sqrt(dx*dx + dy*dy + dz*dz)
end
function pathfinder.default_cost_method.ground(class, src_sector, dst_sector)
	local dy = dst_sector.min_y - src_sector.min_y
	if dy > class.jump_height then
		return math.huge
	end
	local dx = ((dst_sector.min_x + dst_sector.max_x) - (src_sector.min_x + src_sector.max_x)) / 2
	local dz = ((dst_sector.min_z + dst_sector.max_z) - (src_sector.min_z + src_sector.max_z)) / 2
	if dy >= 0 then
		dy = dy * 1.5
	else
		dy = 1
	end
	return math.sqrt(dx*dx + dz*dz) + dy
end
function pathfinder.default_cost_method.crawl(class, src_sector, dst_sector)
	local dx = ((dst_sector.min_x + dst_sector.max_x) - (src_sector.min_x + src_sector.max_x)) / 2
	local dy = ((dst_sector.min_y + dst_sector.max_y) - (src_sector.min_y + src_sector.max_y)) / 2
	local dz = ((dst_sector.min_z + dst_sector.max_z) - (src_sector.min_z + src_sector.max_z)) / 2
	return math.abs(dx) + math.abs(dy) + math.abs(dz)
end


-- Path checks

local function path_check_common(class, pos)
	for z = pos.z, pos.z + class.z_size - 1 do
		tmp_vec.z = z
		for y = pos.y, pos.y + class.y_size - 1 do
			tmp_vec.y = y
			for x = pos.x, pos.x + class.x_size - 1 do
				tmp_vec.x = x
				local node = minetest.get_node_or_nil(tmp_vec)
				if not node then return nil end
				if reg_nodes[node.name].walkable then
					return false
				end
			end
		end
	end
	return true
end

pathfinder.default_path_check = {}
function pathfinder.default_path_check.air(class, pos, parent)
	return path_check_common(class, pos)
end
function pathfinder.default_path_check.ground(class, pos, parent)
	if not path_check_common(class, pos) then
		return false
	end

	-- Find ground
	local vertical = parent == nil or (pos.x == parent.x and pos.z == parent.z)
	for z = pos.z, pos.z + class.z_size - 1 do
		tmp_vec.z = z
		for x = pos.x, pos.x + class.x_size - 1 do
			tmp_vec.x = x

			local last_walkable = false
			for y = pos.y, pos.y - class.jump_height - 1, -1 do
				tmp_vec.y = y
				local node = minetest.get_node_or_nil(tmp_vec)
				if not node then return nil end

				local walkable = reg_nodes[node.name].walkable
				if y < pos.y and walkable and not last_walkable then
					local ground_dist = pos.y - y
					if ground_dist == 1 or (ground_dist > 1 and vertical) then
						return true
					end
				end
				last_walkable = walkable
			end

		end
	end

	-- TODO How to allow falls?

	return false
end
function pathfinder.default_path_check.crawl(class, pos, parent)
	if not path_check_common(class, pos) then
		return false
	end

	-- Find wall
	local x, y, z = pos.x, pos.y, pos.z
	local xs, ys, zs = class.x_size, class.y_size, class.z_size
	local xm, ym, zm = math.floor(xs/2), math.floor(ys/2), math.floor(zs/2)

	-- TODO Cache this table per crawl class
	-- If >=1 hooks are attached to wall, pathable
	local crawl_hooks = {
		{x = x - 1, y = y - 1, z = z + zm},
		{x = x - 1, y = y + ym, z = z - 1},
		{x = x - 1, y = y + ym, z = z + zm},
		{x = x - 1, y = y + ym, z = z + zs},
		{x = x - 1, y = y + ys, z = z + zm},
		{x = x + xm, y = y - 1, z = z - 1},
		{x = x + xm, y = y - 1, z = z + zm},
		{x = x + xm, y = y - 1, z = z + zs},
		{x = x + xm, y = y + ym, z = z - 1},
		{x = x + xm, y = y + ym, z = z + zs},
		{x = x + xm, y = y + ys, z = z - 1},
		{x = x + xm, y = y + ys, z = z + zm},
		{x = x + xm, y = y + ys, z = z + zs},
		{x = x + xs, y = y - 1, z = z + zm},
		{x = x + xs, y = y + ym, z = z - 1},
		{x = x + xs, y = y + ym, z = z + zm},
		{x = x + xs, y = y + ym, z = z + zs},
		{x = x + xs, y = y + ys, z = z + zm},
	}

	for _,h in ipairs(crawl_hooks) do
		local node = minetest.get_node_or_nil(h)
		if not node then return nil end
		
		if reg_nodes[node.name].walkable then
			return true
		end
	end

	return false
end



----------------
-- PUBLIC API --
----------------

pathfinder.classes = classes -- For debug
pathfinder.find_containing_sector = find_containing_sector -- For debug

-- Registers a pathfinder class
function pathfinder:register_class(class_name, properties)
	table.insert(pathfinder.class_names, class_name)
	local class = {
		name = class_name,
		sectors = {},
		sector_seeds = Queue.new(),
		jump_height = properties.jump_height,
		path_check = properties.path_check,
		cost_method = properties.cost_method,
		collisionbox = properties.collisionbox,
		x_offset = properties.collisionbox[1] + 0.01,
		y_offset = properties.collisionbox[2] + 0.01,
		z_offset = properties.collisionbox[3] + 0.01,
		x_size = math.ceil(properties.collisionbox[4] - properties.collisionbox[1]),
		y_size = math.ceil(properties.collisionbox[5] - properties.collisionbox[2]),
		z_size = math.ceil(properties.collisionbox[6] - properties.collisionbox[3]),
	}
	classes[class_name] = class
end

-- Returns the destination for an entity of class class_name at position (x,y,z) to get to the nearest player
function pathfinder:get_waypoint(class_name, x, y, z)
	local class = classes[class_name]

	local grid_pos = to_grid_pos(class, {x=x, y=y, z=z})
	local gx = grid_pos.x
	local gy = grid_pos.y
	local gz = grid_pos.z

	local sector = find_containing_sector(class, gx, gy, gz)
	if not sector or sector.distance == nil then return nil end

	if sector.distance == 0 then
		local players = minetest.get_connected_players()
		if #players then
			local nearest_player = nil
			local nearest_dist_sq = math.huge
			for _,p in ipairs(players) do
				local px, py, pz = get_player_pos(p)
				if sector_contains(sector, px, py, pz) then
					local dx = px - gx;
					local dy = py - gy;
					local dz = pz - gz;
					local dist_sq = dx*dx + dy*dy + dz*dz;
					if dist_sq < nearest_dist_sq then
						nearest_dist_sq = dist_sq
						nearest_player = p
					end
				end
			end
			if nearest_player then
				return nearest_player:getpos()
			else
				return nil
			end
		end
		return nil
	end

	local nearest_link = nil
	for i,l in pairs(sector.links) do
		if l.distance ~= nil
		   and (not nearest_link or l.distance < nearest_link.distance) then
			nearest_link = l
		end
	end
	if not nearest_link then return nil end

	local interface = compute_sector_interface(sector, nearest_link)
	if not interface then
		defense:log("Error! No interface found between sectors " .. sector.id .. " and " .. nearest_link.id .. " in " .. class_name)
		return nil
	end

	local surface = interface.surface
	local normal = interface.normal

	local waypoint = {
		x = math.max(surface[1], math.min(surface[4], gx)),
		y = math.max(surface[2], math.min(surface[5], gy)),
		z = math.max(surface[3], math.min(surface[6], gz))
	}

	local delta = vector.subtract({x=x,y=y,z=z}, waypoint)
	local directed_distance = vector.dot(normal, delta) / vector.length(normal)
	local waypoint_offset = vector.multiply(normal, math.max(-1, math.min(1, directed_distance + 1)))

	return to_world_pos(class, vector.add(waypoint, waypoint_offset))
end



local last_update_time = 0
minetest.register_globalstep(function(dtime)
	local gt = minetest.get_gametime()
	if last_update_time + pathfinder.update_interval < gt then
 		update()
		last_update_time = gt
	end
end)

minetest.register_on_placenode(function(pos, newnode, placer, oldnode, itemstack, pointed_thing)
	for n,c in pairs(classes) do
		invalidate_containing_sector(c, pos.x, pos.y, pos.z)
	end
end)
minetest.register_on_dignode(function(pos, oldnode, digger)
	for n,c in pairs(classes) do
		invalidate_containing_sector(c, pos.x, pos.y, pos.z)
	end
end)