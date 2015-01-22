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

		local xs = math.cos(angle) * s * (0.9 + math.random() * 0.2)
		local ys = math.sin(angle) * s * (0.9 + math.random() * 0.2)
		local horiz_angle = math.atan2(delta.z, delta.x) + (math.random() * 0.1 - 0.05)
		local v = {
			x = math.cos(horiz_angle) * xs,
			y = ys,
			z = math.sin(horiz_angle) * xs
		}

		local projectile = minetest.add_entity(pos, "defense:gooball")
		projectile:setvelocity(v)
		self.object:setvelocity(vector.multiply(v, -0.5))
	end,
})

-- Botete's projectile
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
			-- self:on_hit()
			self.object:remove()
		end
	end,
})