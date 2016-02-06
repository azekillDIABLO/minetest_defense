function defense:toggle_debug(on)
	self.debug = on
	if self.debug then
		regeneration.rate = 100
		minetest.set_timeofday(0.3)
		return true, "Debug mode activated"
	else
		regeneration.rate = self.regeneration_rate
		return true, "Debug mode deactivated"
	end
end

minetest.register_chatcommand("debug", {
	description = "Toggle Defense mod debug mode",
	privs = {server=true},
	func = function(name)
		return defense:toggle_debug(not defense.debug)
	end,
})


-- Pathfinder debugger
local pf_player = nil
local pf_class_name = nil
local pf_update_interval = 1.0

minetest.register_chatcommand("debug_pf", {
	description = "Debug the pathfinder",
	params = "<class>",
	privs = {server=true},
	func = function(name, class)
		if class and class ~= "" then
			if defense.pathfinder.classes[class] then
				pf_class_name = class
				pf_player = minetest.get_player_by_name(name)
				return true, "Pathfinder debugger for " .. pf_class_name .. " activated"
			else
				return false, "No pathfinder class of that name"
			end
		else
			pf_class_name = nil
			pf_player = nil
			return true, "Pathfinder debugger deactivated"
		end
	end,
})

minetest.register_node("defense:debug_pf", {
	drawtype = "allfaces",
	tiles = {"defense_debug_path.png"},
	light_source = 14,
	groups = {dig_immediate = 3},
	drop = "",
	walkable = false,
})

minetest.register_abm({
	nodenames = {"defense:debug_pf"},
	interval = 2.0,
	chance = 1,
	action = function(pos)
		minetest.remove_node(pos)
	end,
})

local function pf_update()
	if pf_class_name then
		local pathfinder = defense.pathfinder
		local pos = pf_player:getpos()
		local sector = pathfinder.find_containing_sector(pathfinder.classes[pf_class_name], math.floor(pos.x + 0.5), math.floor(pos.y + 0.5), math.floor(pos.z + 0.5))
		if sector then
			local distance_str = sector.distance
			if sector.distance == nil then
				distance_str = "nil"
			end

			local bounds_str = "(" .. sector.min_x .. "," .. sector.min_y .. "," .. sector.min_z .. ";" .. sector.max_x .. "," .. sector.max_y .. "," .. sector.max_z .. ")"

			local links_str = ""
			for i,l in pairs(sector.links) do
				links_str = links_str .. " " .. i
			end
			links_str = "[" .. links_str .. " ]"

			defense:log("You are in sector " .. sector.id .. " {d=" .. distance_str .. " b=" .. bounds_str .. " l=" .. links_str .. "}")

			for z = sector.min_z,sector.max_z do
				for y = sector.min_y,sector.max_y do
					for x = sector.min_x,sector.max_x do
						if (x == sector.min_x or x == sector.max_x)
						   and (y == sector.min_y or y == sector.max_y)
						   and (z == sector.min_z or z == sector.max_z) then
							local pos = {x=x,y=y,z=z}
							local node = minetest.get_node_or_nil(pos)
							if node and node.name == "air" then
								minetest.set_node(pos, {name="defense:debug_pf"})
							end
						end
					end
				end
			end
		else
			defense:log("You are not in a sector")
		end
	end
end

local pf_last_update_time = 0
minetest.register_globalstep(function(dtime)
	local gt = minetest.get_gametime()
	if pf_last_update_time + pf_update_interval < gt then
 		pf_update()
		pf_last_update_time = gt
	end
end)