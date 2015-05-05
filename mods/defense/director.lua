defense.director = {}
local director = defense.director
director.call_interval = 1.0
director.intensity_decay = 0.93
director.max_entities = 50
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
		spawn_location = "ground",
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
		spawn_location = "ground",
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
		spawn_location = "ground",
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
		spawn_location = "air",
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
		spawn_location = "ground",
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
		spawn_location = "air",
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

function director:on_interval()
	self:update_intensity()
	if defense.debug then
		-- minetest.chat_send_all("Intensity: " .. self.intensity)
	end

	if self.cooldown_timer <= 0 then
		if defense:is_dark() and #minetest.luaentities < self.max_entities and not defense.debug then
			self:spawn_monsters()
		end

		if self.intensity > 0.5 then
			self.cooldown_timer = math.random(5, 5 + 80 * (self.intensity - 0.5))
		end
	else
		self.cooldown_timer = self.cooldown_timer - self.call_interval
		if defense.debug then
			minetest.chat_send_all("Cooldown: " .. self.cooldown_timer)
		end
	end

	for k,v in pairs(spawn_timers) do
		if v > 0 then 
			spawn_timers[k] = v - self.call_interval
		end
	end
end

function director:spawn_monsters()
	-- Filter eligible monsters
	local filtered = {}
	for _,m in ipairs(self.spawn_list) do
		if spawn_timers[m.description] <= 0
			and self:get_day_count() >= m.day_start
			and math.random() < m.probability
			and self.intensity >= m.intensity_min
			and self.intensity <= m.intensity_max then
			table.insert(filtered, m)
		end
	end
	if #filtered == 0 then
		return false
	end
	local monster = filtered[math.random(#filtered)]

	-- Determine group size
	local intr = math.max(0, math.min(1, self.intensity + math.random() * 2 - 1))
	local group_size = math.floor(0.5 + monster.group_max + (monster.group_min - monster.group_max) * intr)

	-- Find the spawn position
	local pos = self:find_spawn_position(monster.spawn_location)
	if not pos then
		if defense.debug then
			minetest.chat_send_all("No spawn point found for " .. monster.description .. "!")
		end
		return false
	end

	-- Spawn
	if defense.debug then
		minetest.chat_send_all("Spawn " .. monster.description .. " (" .. group_size .. " " .. 
			monster.name .. ") at " .. minetest.pos_to_string(pos))
	end
	repeat
		minetest.after(group_size * (math.random() * 0.2), function()
			local obj = minetest.add_entity(pos, monster.name)
		end)
		group_size = group_size - 1
	until group_size <= 0
	spawn_timers[monster.description] = monster.spawn_time
	return true
end

function director:find_spawn_position(spawn_location)
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
			if spawn_location == "ground" then
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
			elseif spawn_location == "air" then
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

function director:update_intensity()
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

	self.intensity = math.max(0, math.min(1, self.intensity * self.intensity_decay + delta))
end

function director:get_day_count()
	local time_speed = minetest.setting_get("time_speed")
	return math.floor(minetest.get_gametime() * time_speed / 86400)
end

function director:save()
	local file = assert(io.open(minetest.get_worldpath() .. "/defense.txt", "w"))
	local data = {
		intensity = self.intensity,
		cooldown_timer = self.cooldown_timer,
		spawn_timers = spawn_timers,
		last_average_health = last_average_health,
		last_mob_count = last_mob_count,
	}
	file:write(minetest.serialize(data))
	assert(file:close())
end

function director:load()
	local file = io.open(minetest.get_worldpath() .. "/defense.txt", "r")
	if file then
		local data = minetest.deserialize(file:read("*all"))
		if data then
			self.intensity = data.intensity
			self.cooldown_timer = data.cooldown_timer
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
	director:save()
end)
director:load()

local last_call_time = 0
minetest.register_globalstep(function(dtime)
	local gt = minetest.get_gametime()
	if last_call_time + director.call_interval < gt then
		director:on_interval()
		last_call_time = gt
	end
end)