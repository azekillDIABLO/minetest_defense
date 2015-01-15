defense_mobs = {}
defense_mobs.gravity = -9.81

local function dofile2(file)
	dofile(minetest.get_modpath("defense_mobs") .. "/" .. file)
end

dofile2("mob.lua")
dofile2("unggoy.lua")