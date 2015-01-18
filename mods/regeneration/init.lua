local rate = 0.1 -- hp per second

local timer = 0
minetest.register_globalstep(function(dtime)
	timer = timer + dtime
	if timer * rate > 1 then
		for _,p in ipairs(minetest.get_connected_players()) do
			while timer * rate > 1 do
				timer = timer - rate
				p:set_hp(p:get_hp() + 1)
			end
		end
	end
end)