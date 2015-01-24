local function place_goo(pos, origin)
	if not origin then
		origin = pos
	end

	local node = minetest.get_node_or_nil(pos)
	if not node or node.name ~= "air" and not minetest.registered_nodes[node.name].buildable_to then
		return false
	end

	if node.name == "defense:goo" then
		-- minetest.place_node(pos, {name="defense:goo_block"})
		-- minetest.get_meta(pos):set_string("origin", minetest.pos_to_string(origin))
		return true
	else
		local dirs = {
			{x = 0, y =-1, z = 0},
			{x =-1, y = 0, z = 0},
			{x = 0, y = 0, z = 1},
			{x = 0, y = 0, z =-1},
			{x = 1, y = 0, z = 0},
			{x = 0, y = 1, z = 0},
		}
		local dir = nil
		for _,d in ipairs(dirs) do
			local wall_pos = vector.add(pos, d)
			local wall = minetest.get_node_or_nil(wall_pos)
			if wall and wall.name ~= "air" and minetest.get_item_group(wall.name, "caustic_goo") == 0 then
				dir = d
				break
			end
		end
		if dir then
			local facedir = minetest.dir_to_facedir(dir, true)
			if minetest.registered_nodes[node.name].buildable_to then
				-- minetest.set_node(pos, {name="defense:goo", param2=facedir})
				-- minetest.get_meta(pos):set_string("origin", minetest.pos_to_string(origin))
				return true
			end
		end
	end

	return false
end

local function spread_goo(pos, origin)
	if origin and vector.distance(pos, origin) > 2 then
		return
	end

	local node = minetest.get_node_or_nil(pos)
	if node then
		local dirs = {
			{x = 1, y = 0, z = 0},
			{x =-1, y = 0, z = 0},
			{x = 0, y = 1, z = 0},
			{x = 0, y =-1, z = 0},
			{x = 0, y = 0, z = 1},
			{x = 0, y = 0, z =-1},
		}
		if node.name == "defense:goo" then
			local dir = minetest.facedir_to_dir(node.param2)
			for _,d in ipairs(dirs) do
				local dot_product = d.x * dir.x + d.y * dir.y + d.z * dir.z
				if dot_product == 0 then
					if math.random() < 0.25 then
						local npos = vector.add(pos, d)
						if not place_goo(vector.add(npos, dir), origin) then
							if not place_goo(npos, origin) then
								place_goo(vector.subtract(npos, dir), origin)
							end
						end
					end
				end
			end
		else
			for _,d in ipairs(dirs) do
				if math.random() < 0.17 then
					local npos = vector.add(pos, d)
					minetest.dig_node(npos)
					place_goo(npos, origin)
				end
			end
		end

		if math.random() < 0.1 then
			minetest.dig_node(pos)
		end
	end
end

defense.mobs.register_mob("defense:botete", {
	hp_max = 2,
	collisionbox = {-0.6,-0.7,-0.6, 0.6,0.4,0.6},
	mesh = "defense_botete.b3d",
	textures = {"defense_botete.png"},
	makes_footstep_sound = false,

	animation = {
		idle = {a=0, b=39, rate=20},
		attack = {a=40, b=79, rate=50},
		move = {a=40, b=79, rate=25},
		move_attack = {a=40, b=79, rate=25},
	},

	mass = 1,
	movement = "air",
	move_speed = 4,
	attack_damage = 0,
	attack_range = 8,
	attack_interval = 16,

	on_step = function(self, dtime)
		defense.mobs.default_prototype.on_step(self, dtime)
		if self.last_attack_time + self.attack_interval * 0.5 < self.timer then
			self:hunt()
		elseif not self.destination then
			self.destination = vector.add(self.object:getpos(), {x=math.random(-10,10), y=math.random(-5,6), z=math.random(-10,10)})
		end
	end,

	attack = function(self, obj, dir)
		local pos = self.object:getpos()
		local hdir = vector.normalize({x=dir.x, y=0, z=dir.z})
		pos = vector.add(pos, vector.multiply(hdir, 0.4))
		local s = 9 -- Launch speed
		local g = -defense.mobs.gravity

		-- Calculate launch angle
		local angle
		local delta = vector.subtract(obj:getpos(), pos)
		local x2 = delta.x*delta.x + delta.z*delta.z
		local s2 = s*s
		local r = s2*s2 - g * (g*x2 + 2*delta.y*s2)
		if r >= 0 then
			angle = math.atan((s2 + math.sqrt(r) * (math.random(0,1)*2-1))/(g*math.sqrt(x2)))
		else
			angle = math.pi/4
		end

		-- Calculate initial velocity
		local xs = math.cos(angle) * s * (0.9 + math.random() * 0.2)
		local ys = math.sin(angle) * s * (0.9 + math.random() * 0.2)
		local horiz_angle = math.atan2(delta.z, delta.x) + (math.random() * 0.1 - 0.05)
		local v = {
			x = math.cos(horiz_angle) * xs,
			y = ys,
			z = math.sin(horiz_angle) * xs
		}

		-- Launch projectile
		local projectile = minetest.add_entity(pos, "defense:gooball")
		projectile:setvelocity(v)
		self.object:setvelocity(vector.multiply(v, -0.4))

		if math.random() < 0.1 then
			self.attack_range = 4 + math.random() * 4
		end
	end,
})

-- Goo projectile
minetest.register_entity("defense:gooball", {
	physical = false,
	visual = "sprite",
	visual_size = {x=1, y=1},
	textures = {"defense_gooball.png"},

	on_activate = function(self, staticdata)
		self.object:setacceleration({x=0, y=defense.mobs.gravity, z=0})
	end,

	on_step = function(self, dtime)
		local pos = self.object:getpos()
		local node = minetest.get_node(pos)
		if minetest.get_item_group(node.name, "caustic_goo") > 0 then
			self.object:remove()
		elseif node.name ~= "air" then
			local space = pos
			local nvel = vector.normalize(self.object:getvelocity())
			local back = vector.multiply(nvel, -1)
			local bnode
			repeat
				space = vector.add(space, back)
				bnode = minetest.get_node_or_nil(space)
			until not bnode or bnode.name == "air"
			place_goo(space)
			self.object:remove()
		end
	end,
})

-- Goo node
minetest.register_node("defense:goo", {
	description = "Caustic Goo",
	tiles = {{
		name="defense_goo.png",
		animation={type="vertical_frames", aspect_w=16, aspect_h=16, length=0.7}
	}},
	inventory_image = "defense_gooball.png",
	drawtype = "nodebox",
	node_box = {
		type = "fixed",
		fixed = {-0.5, -0.5, 0.5-2/16, 0.5, 0.5, 0.5},
	},
	paramtype = "light",
	paramtype2 = "facedir",
	liquid_viscosity = 4,
	liquidtype = "source",
	liquid_alternative_flowing = "defense:goo",
	liquid_alternative_source = "defense:goo",
	liquid_renewable = false,
	liquid_range = 0,
	groups = {caustic_goo=1, crumbly=3, dig_immediate=3, liquid=3, disable_jump=1},
	drop = "",
	walkable = false,
	buildable_to = false,
	damage_per_second = 1,

	on_construct = function(pos)
		minetest.get_node_timer(pos):start(1 + math.random() * 9)
		local meta = minetest.get_meta(pos)
		local origin = meta:get_string("origin")
		if not origin then
			meta:set_string("origin", minetest.pos_to_string(pos))
		end
	end,

	on_timer = function(pos, elapsed)
		local meta = minetest.get_meta(pos)
		spread_goo(pos, minetest.string_to_pos(meta:get_string("origin")))
		return true
	end,
})

-- Goo block
minetest.register_node("defense:goo_block", {
	description = "Caustic Goo Block",
	tiles = {{
		name="defense_goo.png",
		animation={type="vertical_frames", aspect_w=16, aspect_h=16, length=0.7}
	}},
	drawtype = "glasslike",
	paramtype = "light",
	liquid_viscosity = 8,
	liquidtype = "source",
	liquid_alternative_flowing = "defense:goo_block",
	liquid_alternative_source = "defense:goo_block",
	liquid_renewable = false,
	liquid_range = 0,
	post_effect_color = {r=100, g=240, b=0, a=240},
	groups = {caustic_goo=1, crumbly=3, dig_immediate=3, liquid=3, disable_jump=1},
	drop = "",
	walkable = false,
	buildable_to = false,
	damage_per_second = 1,

	on_construct = function(pos)
		minetest.get_node_timer(pos):start(1 + math.random() * 15)
		local meta = minetest.get_meta(pos)
		local origin = meta:get_string("origin")
		if not origin then
			meta:set_string("origin", minetest.pos_to_string(pos))
		end
	end,

	on_timer = function(pos, elapsed)
		local meta = minetest.get_meta(pos)
		spread_goo(pos, minetest.string_to_pos(meta:get_string("origin")))
		return true
	end,
})