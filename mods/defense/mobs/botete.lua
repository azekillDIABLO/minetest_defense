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
		if self.last_attack_time + self.attack_interval * 0.8 < self.timer then
			self:hunt()
		elseif not self.destination then
			self.destination = vector.add(self.object:getpos(), {x=math.random(-10,10), y=math.random(-5,5), z=math.random(-10,10)})
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
		delta.y = delta.y + 1
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
		if node.name ~= "air" and node.name ~= "defense:goo" then
			local space = pos
			local nvel = vector.normalize(self.object:getvelocity())
			local back = vector.multiply(nvel, -1)
			local bnode
			repeat
				space = vector.add(space, back)
				bnode = minetest.get_node_or_nil(space)
			until not bnode or bnode.name == "air"
			self:hit(space, nvel)
			self.object:remove()
		end
	end,

	hit = function(self, pos, dir)
		local xmag = math.abs(dir.x)
		local ymag = math.abs(dir.y)
		local zmag = math.abs(dir.z)
		if xmag > ymag then
			if xmag > zmag then
				dir.x = dir.x/xmag
				dir.y = 0
				dir.z = 0
			else
				dir.x = 0
				dir.y = 0
				dir.z = dir.z/zmag
			end
		else
			if ymag > zmag then
				dir.x = 0
				dir.y = dir.y/ymag
				dir.z = 0
			else
				dir.x = 0
				dir.y = 0
				dir.z = dir.z/zmag
			end
		end
		local facedir = minetest.dir_to_facedir(dir, true)
		minetest.set_node(pos, {name="defense:goo", param2=facedir})
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
	groups = {crumbly=3, dig_immediate=3, liquid=3, disable_jump=1},
	drop = "",
	walkable = false,
	buildable_to = false,
	damage_per_second = 1,

	on_construct = function(pos)
		minetest.get_node_timer(pos):start(1 + math.random() * 5)
	end,

	on_timer = function(pos, elapsed)
		local dir = minetest.facedir_to_dir(minetest.get_node(pos).param2)
		local under = vector.add(pos, dir)
		local node = minetest.get_node_or_nil(under)
		if node and node.name ~= "air" then
			minetest.remove_node(under)
			minetest.place_node(under, {name="defense:goo_block"})
		end
		minetest.dig_node(pos)
		return false
	end,
})

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
	groups = {crumbly=3, dig_immediate=3, falling_node=1, liquid=3, disable_jump=1},
	drop = "",
	walkable = false,
	buildable_to = false,
	damage_per_second = 1,
})

minetest.register_abm({
	nodenames = {"defense:goo_block"},
	interval = 1.5,
	chance = 2,
	action = function(pos, _, _, _)
		if math.random() < 0.5 then
			minetest.dig_node(pos)
		else
			local neighbor = vector.new(pos)
			if math.random() < 1.0/3.0 then
				neighbor.y = pos.y - 1
			elseif math.random() < 0.5 then
				neighbor.x = pos.x + math.random(0,1) * 2 - 1
			else
				neighbor.z = pos.z + math.random(0,1) * 2 - 1
			end
			local node = minetest.get_node_or_nil(neighbor)
			if node and node.name ~= "air" then
				minetest.remove_node(neighbor)
				minetest.place_node(neighbor, {name="defense:goo_block"})
			end
			minetest.dig_node(pos)
		end
	end,
})
