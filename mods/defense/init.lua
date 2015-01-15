defense = {}

local function dofile2(file)
	dofile(minetest.get_modpath("defense") .. "/" .. file)
end

dofile2("director.lua")