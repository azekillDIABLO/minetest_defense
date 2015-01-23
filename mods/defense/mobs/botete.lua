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
	attack_interval = 3.4,

	on_step = function(self, dtime)
		defense.mobs.default_prototype.on_step(self, dtime)
		self:hunt()
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
		self.object:setvelocity(vector.multiply(v, -0.5))

		if math.random() < 0.1 then
			if self.attack_range < 4 then
				self.attack_range = 8
			else
				self.attack_range = self.attack_range - 1
			end
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
		if minetest.get_node(pos).name ~= "air" then
			local space = pos
			local back = vector.multiply(vector.normalize(self.object:getvelocity()), -1)
			local node
			repeat
				space = vector.add(space, back)
				node = minetest.get_node_or_nil(space)
			until not node or node.name == "air" or node.name == "defense:goo"
			self:hit(space)
			self.object:remove()
		end
	end,

	hit = function(self, pos)
		minetest.set_node(pos, {name="defense:goo"})
	end,
})

-- Goo node
minetest.register_node("defense:goo", {
	description = "Caustic Goo",
	tiles = {"defense_goo.png"},
	inventory_image = "defense_gooball.png",
	drop = "",
	groups = {crumbly=3},
	walkable = false,
	buildable_to = false,
	damage_per_second = 1,
	paramtype = "light",
	paramtype2 = "facedir",
	drawtype = "nodebox",
	node_box = {
		type = "fixed",
		fixed = {-0.5, -0.5, -0.5, 0.5, -0.5+2/16, 0.5},
	},
})

minetest.register_node("defense:goo_block", {
	description = "Caustic Goo Block",
	tiles = {"defense_goo.png"},
	-- inventory_image = "defense_goo.png",
	drop = "",
	groups = {crumbly=3},
	walkable = false,
	buildable_to = false,
	damage_per_second = 1,
})

minetest.register_abm({
	nodenames = {"defense:goo", "defense:goo_block"},
	interval = 1,
	chance = 30,
	action = function(pos, node)
		minetest.remove_node(pos)
	end,
})