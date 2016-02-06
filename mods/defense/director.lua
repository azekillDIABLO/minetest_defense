defense.director = {}
local director = defense.director
director.update_interval = 1.0
director.intensity_decay = 0.93
director.max_entities = 50

--[[
spawn_list: List of spawn events that may happen
	description: Description for this spawn event (mostly for debugging)
	name: Name of the entity to spawn
	intensity_min: Minimum intensity requirement for the event to fire
	intensity_max: Maximum intensity requirement for the event to fire
	group_min: Minimum number of entities to spawn when event fires
	group_max: Maximum number of entities to spawn when event fires
	probability: Probability of spawning per update (excluding cooldown times)
	day_start: Number of game days before this event can start happening
	spawn_time: Spawn cooldown
	spawn_location_type: ["ground"/"air"] Where entities will appear
]]
director.spawn_list = {
	{
		description = "Unggoy group",
		name = "defense:unggoy",
		intensity_min = 0.0,
		intensity_max = 0.6,
		group_min = 1,
		group_max = 4,
		probability = 0.4,
		day_start = 0,
		spawn_time = 14.0,
		spawn_location_type = "ground",
	},
	{
		description = "Unggoy horde",
		name = "defense:unggoy",
		intensity_min = 0.0,
		intensity_max = 0.1,
		group_min = 21,
		group_max = 24,
		probability = 0.8,
		day_start = 1,
		spawn_time = 31.0,
		spawn_location_type = "ground",
	},
	{
		description = "Aranay group",
		name = "defense:aranay",
		intensity_min = 0.0,
		intensity_max = 0.5,
		group_min = 1,
		group_max = 2,
		probability = 0.3,
		day_start = 0,
		spawn_time = 18.0,
		spawn_location_type = "ground",
	},
	{
		description = "Paniki group",
		name = "defense:paniki",
		intensity_min = 0.0,
		intensity_max = 0.3,
		group_min = 1,
		group_max = 6,
		probability = 0.6,
		day_start = 0,
		spawn_time = 9.0,
		spawn_location_type = "air",
	},
	{
		description = "Sarangay",
		name = "defense:sarangay",
		intensity_min = 0.0,
		intensity_max = 0.2,
		group_min = 1,
		group_max = 1,
		probability = 0.4,
		day_start = 2,
		spawn_time = 90.0,
		spawn_location_type = "ground",
	},
	{
		description = "Botete",
		name = "defense:botete",
		intensity_min = 0.0,
		intensity_max = 0.3,
		group_min = 1,
		group_max = 1,
		probability = 0.4,
		day_start = 1,
		spawn_time = 90.0,
		spawn_location_type = "air",
	},
}

-- State tracking stuff
director.intensity = 0.5
director.cooldown_timer = 3

local spawn_timers = {}
local last_average_health = 1.0
local last_mob_count = 0

for _,m in ipairs(director.spawn_list) do
	spawn_timers[m.description] = m.spawn_time/2
end

local function find_spawn_position(spawn_location_type)
	local players = minetest.get_connected_players()
	if #players == 0 then
		return nil
	end
	
	local center = {x=0, y=0, z=0}
	for _,p in ipairs(players) do
		center = vector.add(center, p:getpos())
	end
	center = vector.multiply(center, #players)

	local radius = {}
	local points = {}
	for _,p in ipairs(players) do
		local r = 20 + 10/(vector.distance(p:getpos(), center) + 1)
		radius[p:get_player_name()] = r - 0.5
		for j = 0, 3, 1 do
			local pos = p:getpos()
			local a = math.random() * 2 * math.pi
			pos.x = pos.x + math.cos(a) * r
			pos.z = pos.z + math.sin(a) * r
			if spawn_location_type == "ground" then
				-- Move pos to on ground
				pos.y = pos.y + 10
				local d = -1
				local node = minetest.get_node_or_nil(pos)
				if node and minetest.registered_nodes[node.name].walkable then
					d = 1
					pos.y = pos.y + 1
				end
				for i = pos.y, pos.y + 40 * d, d do
					local top = {x=pos.x, y=i, z=pos.z}
					local bottom = {x=pos.x, y=i-1, z=pos.z}
					local node_top = minetest.get_node_or_nil(top)
					local node_bottom = minetest.get_node_or_nil(bottom)
					if node_bottom and node_top
						and minetest.registered_nodes[node_bottom.name].walkable ~= minetest.registered_nodes[node_top.name].walkable then
						table.insert(points, top)
						break
					end
				end
			elseif spawn_location_type == "air" then
				-- Move pos up
				pos.y = pos.y + 12 + math.random() * 12
				local node = minetest.get_node_or_nil(pos)
				if node and not minetest.registered_nodes[node.name].walkable then
					table.insert(points, pos)
				end
			end
		end
	end

	if #points == 0 then
		return nil
	end

	local filtered = {}
	for _,p in ipairs(players) do
		local pos = p:getpos()
		for _,o in ipairs(points) do
			if vector.distance(pos, o) >= radius[p:get_player_name()] then
				table.insert(filtered, o)
			end
		end
	end

	if #filtered > 0 then
		return filtered[math.random(#filtered)]
	end
	return nil
end

local function spawn_monsters()
	-- Filter eligible monsters
	local filtered = {}
	for _,m in ipairs(director.spawn_list) do
		if spawn_timers[m.description] <= 0
			and defense.get_day_count() >= m.day_start
			and math.random() < m.probability
			and director.intensity >= m.intensity_min
			and director.intensity <= m.intensity_max then
			table.insert(filtered, m)
		end
	end
	if #filtered == 0 then
		return false
	end
	local monster = filtered[math.random(#filtered)]

	-- Determine group size
	local intr = math.max(0, math.min(1, director.intensity + math.random() * 2 - 1))
	local group_size = math.floor(0.5 + monster.group_max + (monster.group_min - monster.group_max) * intr)

	-- Find the spawn position
	local pos = find_spawn_position(monster.spawn_location_type)
	if not pos then
		defense:log("No spawn point found for " .. monster.description .. "!")
		return false
	end

	-- Spawn
	defense:log("Spawn " .. monster.description .. " (" .. group_size .. " " ..  monster.name .. ") at " .. minetest.pos_to_string(pos))
	repeat
		minetest.after(group_size * (math.random() * 0.2), function()
			local obj = minetest.add_entity(pos, monster.name)
		end)
		group_size = group_size - 1
	until group_size <= 0
	spawn_timers[monster.description] = monster.spawn_time
	return true
end

local function update_intensity()
	local players = minetest.get_connected_players()
	if #players == 0 then
		return
	end

	local average_health = 0
	for _,p in ipairs(players) do
		average_health = average_health + p:get_hp()
	end
	average_health = average_health / #players

	local mob_count = #minetest.luaentities

	local delta =
		  -0.2 * (average_health - last_average_health)
		+ 4.0 * math.max(0, 1 / average_health - 0.1)
		+ 0.006 * (mob_count - last_mob_count)

	last_average_health = average_health
	last_mob_count = mob_count

	director.intensity = math.max(0, math.min(1, director.intensity * director.intensity_decay + delta))
end

local function update()
	update_intensity()

	if director.cooldown_timer <= 0 then
		if defense:is_dark() and #minetest.luaentities < director.max_entities and not defense.debug then
			spawn_monsters()
		end

		if director.intensity > 0.5 then
			director.cooldown_timer = math.random(5, 5 + 80 * (director.intensity - 0.5))
		end
	else
		director.cooldown_timer = director.cooldown_timer - director.update_interval
	end

	for k,v in pairs(spawn_timers) do
		if v > 0 then 
			spawn_timers[k] = v - director.update_interval
		end
	end
end

local function save()
	local file = assert(io.open(minetest.get_worldpath() .. "/defense_director_state.txt", "w"))
	local data = {
		intensity = director.intensity,
		cooldown_timer = director.cooldown_timer,
		spawn_timers = spawn_timers,
		last_average_health = last_average_health,
		last_mob_count = last_mob_count,
	}
	file:write(minetest.serialize(data))
	assert(file:close())
end

local function load()
	local file = io.open(minetest.get_worldpath() .. "/defense_director_state.txt", "r")
	if file then
		local data = minetest.deserialize(file:read("*all"))
		if data then
			director.intensity = data.intensity
			director.cooldown_timer = data.cooldown_timer
			last_average_health = data.last_average_health
			last_mob_count = data.last_mob_count
			for k,v in pairs(data.spawn_timers) do
				spawn_timers[k] = v
			end
		end
		assert(file:close())
	end
end

minetest.register_on_shutdown(function()
	save()
end)
load()

local last_update_time = 0
minetest.register_globalstep(function(dtime)
	local gt = minetest.get_gametime()
	if last_update_time + director.update_interval < gt then
		update()
		last_update_time = gt
	end
end)