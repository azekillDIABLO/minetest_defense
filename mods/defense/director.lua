defense.director = {}
local director = defense.director
director.call_interval = 1.0
director.intensity_decay = 0.9
director.spawn_list = {
	{
		name = "defense:unggoy",
		intensity_min = 0.0,
		intensity_max = 0.9,
		group_min = 1,
		group_max = 1,
		probability = 0.1,
		spawn_timer = 1.0,
	},
	{
		name = "defense:unggoy",
		intensity_min = 0.0,
		intensity_max = 0.5,
		group_min = 4,
		group_max = 14,
		probability = 0.5,
		spawn_timer = 9.0,
	},
	{
		name = "defense:unggoy",
		intensity_min = 0.0,
		intensity_max = 0.0,
		group_min = 16,
		group_max = 16,
		probability = 0.8,
		spawn_timer = 9.0,
	},
	{
		name = "defense:sarangay",
		intensity_min = 0.1,
		intensity_max = 0.5,
		group_min = 1,
		group_max = 1,
		probability = 0.4,
		spawn_timer = 8.0,
	},
}

director.mob_count = 0
director.spawn_timer = 600

director.intensity = 0.5
director.cooldown_timer = 3

local last_average_health = 1.0
local last_mob_count = 0

function director:on_interval()
	self:update_intensity()
	minetest.chat_send_all("Intensity: " .. self.intensity)

	if self.cooldown_timer <= 0 then
		if defense:is_dark() then
			if math.random() < 1 - self.intensity then
				if self:spawn_monsters() then
					self.spawn_timer = 0
				end
			end
		end

		if self.intensity > 0.85 then
			if self.intensity == 1 then
				self.cooldown_timer = math.random(20, 45)
			else
				self.cooldown_timer = math.random(5, 10)
			end
		end
	else
		self.cooldown_timer = self.cooldown_timer - self.call_interval
		minetest.chat_send_all("Cooldown: " .. self.cooldown_timer)
	end

	self.spawn_timer = self.spawn_timer + self.call_interval
end

function director:spawn_monsters()
	-- Filter eligible monsters
	local filtered = {}
	for _,m in ipairs(self.spawn_list) do
		if self.spawn_timer >= m.spawn_timer
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
	local pos = self:find_spawn_position()
	if not pos then
		minetest.chat_send_all("No spawn point found!")
		return false
	end

	-- Spawn
	minetest.chat_send_all("Spawn " .. group_size .. " " .. monster.name .. " at " .. minetest.pos_to_string(pos))
	self.mob_count = self.mob_count + group_size
	repeat
		minetest.after(group_size * (math.random() * 0.2), function()
			local obj = minetest.add_entity(pos, monster.name)
		end)
		group_size = group_size - 1
	until group_size <= 0
	return true
end

function director:find_spawn_position()
	local players = minetest.get_connected_players()
	if #players == 0 then
		return nil
	end
	
	local center = {x=0, y=0, z=0}
	for _,p in ipairs(players) do
		center = vector.add(center, p:getpos())
	end
	center = vector.multiply(center, #players)

	local radii = {}
	local points = {}
	for _,p in ipairs(players) do
		local pos = p:getpos()
		local r = 10 + 20/(vector.distance(pos, center) + 1)
		radii[p:get_player_name()] = r - 0.5
		for j = 0, 6, 1 do
			local a = math.random() * 2 * math.pi
			pos.x = pos.x + math.cos(a) * r
			pos.z = pos.z + math.sin(a) * r
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
			end
	end

	if #points == 0 then
		return nil
	end

	local filtered = {}
	for _,p in ipairs(players) do
		local pos = p:getpos()
		for _,o in ipairs(points) do
			if vector.distance(pos, o) >= radii[p:get_player_name()] then
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

	local mob_count = self.mob_count

	local delta =
		  -0.1 * math.min(0.3, average_health - last_average_health)
		+ 0.3 * (1 / average_health - 0.1)
		+ 0.01 * (mob_count - last_mob_count)

	last_average_health = average_health
	last_mob_count = mob_count

	self.intensity = math.max(0, math.min(1, self.intensity * self.intensity_decay + delta))
end

director.last_call_time = 0
minetest.register_globalstep(function(dtime)
	local gt = minetest.get_gametime()
	if director.last_call_time + director.call_interval < gt then
		director:on_interval()
		director.last_call_time = gt
	end
end)