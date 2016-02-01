defense.pathfinder = {}
local pathfinder = defense.pathfinder
pathfinder.update_interval = 2.0
pathfinder.max_sector_size = 16
pathfinder.max_sector_count = 800
pathfinder.max_distance = 100
pathfinder.class_names = {}

local classes = {}
local next_sector_id = 1

local reg_nodes = minetest.registered_nodes
local neighbors = {
	{x =-1, y = 0, z = 0},
	{x = 1, y = 0, z = 0},
	{x = 0, y =-1, z = 0},
	{x = 0, y = 1, z = 0},
	{x = 0, y = 0, z =-1},
	{x = 0, y = 0, z = 1},
}

pathfinder.classes = classes -- For debug

function pathfinder:register_class(class_name, properties)
	table.insert(pathfinder.class_names, class_name)
	classes[class_name] = {
		name = class_name,
		sectors = {},
		sector_seeds = Queue.new(),
		jump_height = properties.jump_height,
		path_check = properties.path_check,
		cost_method = properties.cost_method,
		x_offset = properties.collisionbox[1],
		y_offset = properties.collisionbox[2],
		z_offset = properties.collisionbox[3],
		x_size = math.ceil(properties.collisionbox[4] - properties.collisionbox[1]),
		y_size = math.ceil(properties.collisionbox[5] - properties.collisionbox[2]),
		z_size = math.ceil(properties.collisionbox[6] - properties.collisionbox[3]),
	}
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

pathfinder.find_containing_sector = find_containing_sector -- For debug

local function get_player_pos(player)
	local pos = player:getpos()
	return math.floor(pos.x + 0.5), math.floor(pos.y + 0.5), math.floor(pos.z + 0.5)
end

-- Deletes and queues a sector for regeneration
local function invalidate_sector(sector, class)
	local id = sector.id
	class.sectors[id] = nil

	for i,l in pairs(sector.links) do
		l.links[id] = nil
	end

	Queue.push(class.sector_seeds, {sector.min_x,sector.min_y,sector.min_z, nil,0})
	-- TODO what if replacement seed is blocked?
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
				local cost = cost_method(sector, l)
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

-- Returns array of {x,y,z,parent,parent_dir}
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
	local tmp_vec = vector.new()
	local function path_check_i(x, y, z)
		tmp_vec.x = x
		tmp_vec.y = y
		tmp_vec.z = z
		return path_check(class, tmp_vec, nil)
	end

	local exits = {}

	-- Find passable nodes that are cornered by >=2 different sector or passability nodes
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

					tmp_vec.x = x
					tmp_vec.y = y
					tmp_vec.z = z
					local hash = minetest.hash_node_position(tmp_vec)

					if path_check_i(x, y, z) then

						local val = 0
						local sector = find_containing_sector(class, x, y, z)
						if sector then
							val = sector.id
						end

						local edges = 0
						
						if xs ~= 0 then
							tmp_vec.x = x - xs
							tmp_vec.y = y
							tmp_vec.z = z
							if val ~= map[minetest.hash_node_position(tmp_vec)] then
								edges = edges + 1
							end
						end
						if ys ~= 0 then
							tmp_vec.x = x
							tmp_vec.y = y - ys
							tmp_vec.z = z
							if val ~= map[minetest.hash_node_position(tmp_vec)] then
								edges = edges + 1
							end
						end
						if zs ~= 0 then
							tmp_vec.x = x
							tmp_vec.y = y
							tmp_vec.z = z - zs
							if val ~= map[minetest.hash_node_position(tmp_vec)] then
								edges = edges + 1
							end
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

	local min_x = -math.huge
	local min_y = -math.huge
	local min_z = -math.huge
	local max_x = math.huge
	local max_y = math.huge
	local max_z = math.huge

	local half_mss = math.floor(max_sector_span / 2)
	local half_mss2 = math.ceil(max_sector_span / 2)
	local size_min_x = x - half_mss
	local size_min_y = y - half_mss
	local size_min_z = z - half_mss
	local size_max_x = x + half_mss2
	local size_max_y = y + half_mss2
	local size_max_z = z + half_mss2

	local visited = {}
	local visit = Queue.new()

	Queue.push(visit, {x=x,y=y,z=z})
	visited[minetest.hash_node_position(visit[1])] = true

	while Queue.size(visit) > 0 do
		local pos = Queue.pop(visit)

		for i,n in ipairs(neighbors) do
			local nxt = vector.add(pos, n)
			local nhash = minetest.hash_node_position(nxt)
			local nx = nxt.x
			local ny = nxt.y
			local nz = nxt.z

			if not visited[nhash]
			   and nx <= max_x and nx >= min_x
			   and ny <= max_y and ny >= min_y
			   and nz <= max_z and nz >= min_z then
				visited[nhash] = true

				local passable = path_check(class, nxt, pos)

				if passable == nil then return nil end

				if passable and origin_dir ~= i
				   and not find_containing_sector(class, nx, ny, nz)
				   and nx <= size_max_x and nx >= size_min_x
				   and ny <= size_max_y and ny >= size_min_y
				   and nz <= size_max_z and nz >= size_min_z then
					Queue.push(visit, nxt)
				else
					if i == 1 then
						min_x = pos.x
						size_max_x = min_x + max_sector_span
					elseif i == 2 then
						max_x = pos.x
						size_min_x = max_x - max_sector_span
					elseif i == 3 then
						min_y = pos.y
						size_max_y = min_y + max_sector_span
					elseif i == 4 then
						max_y = pos.y
						size_min_y = max_y - max_sector_span
					elseif i == 5 then
						min_z = pos.z
						size_max_z = min_z + max_sector_span
					elseif i == 6 then
						max_z = pos.z
						size_min_z = max_z - max_sector_span
					end
				end

			end
		end

	end

	local id = next_sector_id
	next_sector_id = next_sector_id + 1
	
	return {
		id = id,
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

	local unready_seeds = {}
	local target_sector_count = math.min(sector_count + math.max(math.ceil(100 / (math.log(sector_count + 10))), 1), max_sector_count)
	while sector_count < target_sector_count and Queue.size(sector_seeds) > 0 do
		local seed = Queue.pop(sector_seeds)
		local x = seed[1]
		local y = seed[2]
		local z = seed[3]

		if not find_containing_sector(class, x, y, z) and path_check(class, {x=x,y=y,z=z}, nil) then
			local new_sector = generate_sector(class, x, y, z, seed[5])
			local parent = seed[4]

			if new_sector and (not parent or parent.distance == nil or parent.distance < max_distance) then
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
				for i,e in ipairs(exits) do
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

				should_refresh_distances = true
			else
				table.insert(unready_seeds, seed)
			end
		end

	end

	-- Update sector distance values
	if should_refresh_distances then
		calculate_distances(class)
	end

	-- Requeue seeds outside of loaded area
	for _,s in ipairs(unready_seeds) do
		Queue.push(sector_seeds, s)
	end

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
function pathfinder.default_cost_method.air(src_sector, dst_sector)
	local dx = ((dst_sector.min_x + dst_sector.max_x) - (src_sector.min_x + src_sector.max_x)) / 2
	local dy = ((dst_sector.min_y + dst_sector.max_y) - (src_sector.min_y + src_sector.max_y)) / 2
	local dz = ((dst_sector.min_z + dst_sector.max_z) - (src_sector.min_z + src_sector.max_z)) / 2
	return math.sqrt(dx*dx + dy*dy + dz*dz)
end
function pathfinder.default_cost_method.ground(src_sector, dst_sector)
	return 1
end
function pathfinder.default_cost_method.crawl(src_sector, dst_sector)
	return 1
end


-- Path checks

pathfinder.default_path_check = {}
function pathfinder.default_path_check.air(class, pos, parent)
	local tmp_vec = vector.new()
	for z = pos.z, pos.z + class.z_size - 1 do
		for y = pos.y, pos.y + class.y_size - 1 do
			for x = pos.x, pos.x + class.x_size - 1 do
				tmp_vec.x = x
				tmp_vec.y = y
				tmp_vec.z = z
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
function pathfinder.default_path_check.ground(class, pos, parent)
	return false
end
function pathfinder.default_path_check.crawl(class, pos, parent)
	return false
end


local last_update_time = 0
minetest.register_globalstep(function(dtime)
	local gt = minetest.get_gametime()
	if last_update_time + pathfinder.update_interval < gt then
 		update()
		last_update_time = gt
	end
end)