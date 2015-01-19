defense = {}
defense.debug = true

local modpath = minetest.get_modpath("defense")
local function dofile2(file)
	dofile(modpath .. "/" .. file)
end

function defense:is_dark()
	local tod = minetest.get_timeofday()
	return tod < 0.22 or tod > 0.8 or defense.debug
end

dofile2("mob.lua")
dofile2("mobs/unggoy.lua")
dofile2("mobs/sarangay.lua")
dofile2("mobs/paniki.lua")

dofile2("director.lua")
dofile2("initial_stuff.lua")