defense = {}

local function dofile2(file)
	dofile(minetest.get_modpath("defense") .. "/" .. file)
end

dofile2("mob.lua")
dofile2("mobs/unggoy.lua")
dofile2("mobs/sarangay.lua")

dofile2("director.lua")