defense.mobs.register_mob("defense:sarangay", {
	hp_max = 30,
	weight = 19,
	collisionbox = {-1.4,-0.01,-1.4, 1.4,2.5,1.4},
	visual_size = {x=3, y=3},
	mesh = "defense_sarangay.b3d",
	textures = {"defense_sarangay.png"},
	makes_footstep_sound = true,

	animation = {
		idle = {a=0, b=19, rate=10},
		jump = {a=60, b=69, rate=15},
		fall = {a=70, b=89, rate=20},
		attack = {a=40, b=59, rate=15},
		move = {a=20, b=39, rate=20},
		move_attack = {a=40, b=50, rate=15},

		walk = {a=20, b=39, rate=20},
		walk_jump = {a=60, b=69, rate=15},
		walk_fall = {a=70, b=89, rate=20},
		charge = {a=90, b=109, rate=30},
	},

	move_speed = 4,
	jump_height = 1,
	attack_damage = 4,
	attack_range = 2.0,
	attack_interval = 1.0,

	charging = false,
	charge_power = 0,

	on_step = function(self, dtime)
		defense.mobs.default_prototype.on_step(self, dtime)
		if self.charging then
			if self.charge_power > 1 then
				self:hunt()
			end

			-- Break obstacles
			local dir = vector.normalize(vector.add(self.object:getvelocity(), {
				x=math.random(-2,2), y=0, z=math.random(-2,2)
			}))
			dir.y = 0
			local p = self.object:getpos()
			p.y = p.y + self.collisionbox[2] + (self.collisionbox[5] - self.collisionbox[2]) * math.random() + 0.5
			local sx = self.collisionbox[4] - self.collisionbox[1]
			local sz = self.collisionbox[6] - self.collisionbox[3]
			local r = math.sqrt(sx*sx + sz*sz)/2 + 0.5
			local pos = vector.add(p, vector.multiply(dir, r))
			local node = minetest.get_node_or_nil(pos)
			if node and minetest.registered_nodes[node.name].walkable then
				self.charge_power = self.charge_power - 3
				minetest.dig_node(pos)
			end

			if self.charge_power < 0 or self.charge_power > 2 and vector.length(self.object:getvelocity()) < self.move_speed/4 then
				self:set_charging_state(false)
				self.destination = nil
			else
				self.charge_power = self.charge_power + dtime
			end
		else
			local nearest = self:find_nearest_player()
			if nearest then
				if nearest.distance < 6 then
					self:hunt()
				elseif math.random() < 0.05 and nearest.distance > 9 + math.random() * 20 then
					self:set_charging_state(true)
				elseif not self.destination then
					local nearest_pos = nearest.player:getpos()
					local dir = vector.direction(nearest_pos, self.object:getpos())
					self.destination = vector.add(nearest_pos, vector.multiply(dir, 15))
					local  a = (self.id/100000)
					self.destination.x = self.destination.x + math.sin(a) * 8
					self.destination.z = self.destination.z + math.cos(a) * 8
				end
			end
		end
	end,

	set_charging_state = function(self, state)
		self.charging = state
		if state then
			self.charge_power = 0
			self.move_speed = 8
			self.animation.move = self.animation.charge
			self.animation.jump = self.animation.charge
			self.animation.fall = self.animation.charge
		else
			self.move_speed = 4
			self.animation.move = self.animation.walk
			self.animation.jump = self.animation.walk_jump
			self.animation.fall = self.animation.walk_fall
		end
	end,
})