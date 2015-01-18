defense = {}
defense.debug = false

local function dofile2(file)
	dofile(minetest.get_modpath("defense") .. "/" .. file)
end

function defense:is_dark()
	local tod = minetest.get_timeofday()
	return tod < 0.22 or tod > 0.8 or defense.debug
end

dofile2("mob.lua")
dofile2("mobs/unggoy.lua")
dofile2("mobs/sarangay.lua")

dofile2("director.lua")