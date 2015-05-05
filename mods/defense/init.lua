defense = {}
defense.debug = false

minetest.register_chatcommand("debug", {
	params = "",
	description = "Toggle Defense debug mode",
	privs = {server=true},
	func = function(name, param)
		defense.debug = not defense.debug
		if defense.debug then
			regeneration.rate = 100
			minetest.set_timeofday(0.3)
		else
			regeneration.rate = 0.2
		end
		return true
	end,
})

local modpath = minetest.get_modpath("defense")
local function dofile2(file)
	dofile(modpath .. "/" .. file)
end

function defense:is_dark()
	local tod = minetest.get_timeofday()
	return tod < 0.2 or tod > 0.8 or defense.debug
end

dofile2("util.lua")
dofile2("Queue.lua")

dofile2("initial_stuff.lua")
dofile2("pathfinder.lua")
dofile2("director.lua")
dofile2("music.lua")

dofile2("mob.lua")
dofile2("mobs/unggoy.lua")
dofile2("mobs/aranay.lua")
dofile2("mobs/sarangay.lua")
dofile2("mobs/paniki.lua")
dofile2("mobs/botete.lua")