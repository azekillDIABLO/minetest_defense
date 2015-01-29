regeneration = {}
regeneration.rate = 0.2 -- hp per second

local counter = 0
minetest.register_globalstep(function(dtime)
	counter = counter + dtime * regeneration.rate
	while counter >= 1 do
		counter = counter - 1
		for _,p in ipairs(minetest.get_connected_players()) do
			p:set_hp(p:get_hp() + 1)
		end
	end
end)