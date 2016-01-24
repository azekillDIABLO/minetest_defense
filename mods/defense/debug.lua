minetest.register_chatcommand("debug", {
	description = "Toggle Defense mod debug mode",
	privs = {server=true},
	func = function(name)
		defense.debug = not defense.debug
		if defense.debug then
			regeneration.rate = 100
			minetest.set_timeofday(0.3)
			return true, "Debug mode activated"
		else
			regeneration.rate = defense.regeneration_rate
			return true, "Debug mode deactivated"
		end
	end,
})

-- Pathfinder debugger
local path_interval = 3
local path_class = nil
local path_visit = nil
local path_visited = nil
local path_waiting = {}
local path_active = {}
local path_timer = 0
local path_count = 0
local path_directions = {
	{x=0, y=0, z=0},
	{x=0, y=-1, z=0},
	{x=0, y=1, z=0},
	{x=0, y=0, z=-1},
	{x=1, y=0, z=0},
	{x=-1, y=0, z=0},
	{x=0, y=0, z=1},
}

minetest.register_chatcommand("debug_path", {
	params = "[<class>]",
	description = "Debug the pathfinder flow field",
	privs = {server=true},
	func = function(name, class)
		if not defense.debug then
			return false, "Debug mode required!"
		end

		if not class or class == "" then
			path_class = nil
			return true, "Pathfinder debug off"
		else
			if defense.pathfinder.classes[class] then
				local pos = minetest.get_player_by_name(name):getpos()
				pos = {
					x = math.floor(pos.x + 0.5),
					y = math.floor(pos.y + 0.5),
					z = math.floor(pos.z + 0.5)
				}
				path_visited = {}
				path_visit = Queue.new() Queue.push(path_visit, pos)
				path_timer = path_interval
				path_class = class
				return true
			else
				return false, "Invalid class!"
			end
		end
	end,
})

minetest.register_node("defense:debug_path", {
	drawtype = "allfaces",
	visual_scale = 1.0,
	tiles = {"defense_debug_path.png"},
	use_texture_alpha = true,
	paramtype = "light",
	sunlight_propagates = true,
	walkable = false,
	groups = {dig_immediate=3},
})

local function path_update()
	for _=1,Queue.size(path_visit) do
		local pos = Queue.pop(path_visit)
		table.insert(path_waiting, pos)
		path_visited[pos.x .. ":" .. pos.y .. ":" .. pos.z] = true
		for _,dir in ipairs(path_directions) do
			local nxt = vector.add(pos, dir)
			if not path_visited[nxt.x .. ":" .. nxt.y .. ":" .. nxt.z] then
				Queue.push(path_visit, nxt)
			end
		end
	end

	for _,pos in ipairs(path_active) do
		minetest.remove_node(pos)
	end
	path_active = {}

	for i=#path_waiting,1,-1 do
		local pos = path_waiting[i]
		local field = defense.pathfinder:get_field(path_class, pos)
		if field and field.distance == path_count then
			minetest.place_node(pos, {name="defense:debug_path"})
			table.remove(path_waiting, i)
			table.insert(path_active, pos)
		end
	end

	path_count = path_count + 1

	if path_count > 20 then
		path_class = nil
	end
end

minetest.register_globalstep(function(dtime)
	if path_class then
		path_timer = path_timer - dtime
		if path_timer <= 0 then
			path_timer = path_interval
			path_update()
		end
	end
end)