defense.director = {}
local director = defense.director
director.call_interval = 1.0
director.intensity_decay = 0.9
director.spawn_list = {
	{
		name = "defense:unggoy",
		intensity_min = 0.0,
		intensity_max = 0.8,
		group_min = 1,
		group_max = 1,
		probability = 0.2,
		spawn_timer = 1.0,
	},
	{
		name = "defense:unggoy",
		intensity_min = 0.0,
		intensity_max = 0.4,
		group_min = 3,
		group_max = 7,
		probability = 0.5,
		spawn_timer = 7.0,
	},
}

director.mob_count = 0
director.intensity = 0.0
director.spawn_timer = 0

local last_average_health = 1.0
local last_mob_count = 0

function director:on_interval()
	self:update_intensity()
	minetest.debug("Intensity: " .. self.intensity)
	if self:is_dark() then
		if math.random() < 1 - self.intensity then
			if self:spawn_monsters() then
				self.spawn_timer = 0
			end
		end
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
	local group_size = math.floor(monster.group_max + (monster.group_min - monster.group_max) * intr + 0.5)

	-- Find the spawn location
	local pos = {x=0, y=0, z=0}
	local players = minetest.get_connected_players()
	for _,p in ipairs(players) do
		pos = vector.add(pos, p:getpos())
	end
	pos = vector.multiply(pos, #players)
	local r = 30
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
	for i = pos.y, pos.y + 30 * d, d do
		local top = {x=pos.x, y=pos.y+i, z=pos.z}
		local bottom = {x=pos.x, y=pos.y+i-1, z=pos.z}
		local node_top = minetest.get_node_or_nil(top)
		local node_bottom = minetest.get_node_or_nil(bottom)
		if node_bottom and node_top
			and minetest.registered_nodes[node_bottom.name].walkable ~= minetest.registered_nodes[node_top.name].walkable then
			pos.y = top.y
			break
		end
	end

	-- Spawn
	minetest.debug("Spawn " .. group_size .. " " .. monster.name .. " at " .. minetest.pos_to_string(pos))
	self.mob_count = self.mob_count + group_size
	repeat
		minetest.after(group_size * (math.random() * 0.2), function()
			local obj = minetest.add_entity(pos, monster.name)
		end)
		group_size = group_size - 1
	until group_size <= 0
	return trueD
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
		  -0.2 * (average_health - last_average_health)
		+ 0.2 * (1 / average_health)
		+ 0.001 * (mob_count - last_mob_count)
		+ (self:is_dark() and 0.001 or -0.3)

	last_average_health = average_health
	last_mob_count = mob_count

	self.intensity = math.max(0, math.min(1, self.intensity * self.intensity_decay + delta))
end

function director:is_dark()
	local tod = minetest.get_timeofday()
	return tod < 0.22 or tod > 0.8
end

director.last_call_time = 0
minetest.register_globalstep(function(dtime)
	local gt = minetest.get_gametime()
	if director.last_call_time + director.call_interval < gt then
		director:on_interval()
		director.last_call_time = gt
	end
end)