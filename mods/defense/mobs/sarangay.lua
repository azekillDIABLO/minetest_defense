local c_air = minetest.get_content_id("air")
defense.mobs.register_mob("defense:sarangay", {
	hp_max = 30,
	collisionbox = {-1.4,-0.01,-1.4, 1.4,2.5,1.4},
	visual_size = {x=3, y=3},
	mesh = "defense_sarangay.b3d",
	textures = {"defense_sarangay.png"},
	makes_footstep_sound = true,

	animation = nil,

	normal_animation = {
		idle = {a=0, b=19, rate=10},
		jump = {a=60, b=69, rate=15},
		fall = {a=70, b=89, rate=20},
		attack = {a=40, b=59, rate=15},
		move = {a=20, b=39, rate=20},
		move_attack = {a=40, b=50, rate=15},
	},

	charging_animation = {
		idle = {a=120, b=129, rate=10},
		jump = {a=90, b=109, rate=10},
		fall = {a=90, b=109, rate=10},
		attack = {a=40, b=59, rate=15},
		move = {a=90, b=109, rate=30},
		move_attack = {a=40, b=50, rate=15},
		start = {a=110, b=119, rate=15},
	},

	mass = 12,
	move_speed = 4,
	jump_height = 1,
	attack_damage = 4,
	attack_range = 2.0,
	attack_interval = 1.0,

	charging = false,
	charge_power = 0,

	on_activate = function(self, staticdata)
		self:set_charging_state(self.charging)
		defense.mobs.default_prototype.on_activate(self, staticdata)
	end,

	on_step = function(self, dtime)
		defense.mobs.default_prototype.on_step(self, dtime)
		if self.charging then
			self:hunt()

			-- Break obstacles
			local pos = self.object:getpos()
			pos.y = pos.y + 2
			self.charge_power = self.charge_power - self:crash_blocks(pos, 1.5) * 0.2
			self.charge_power = self.charge_power - self:crash_entities(pos, 4) * 0.06

			if self.charge_power < 0 or (self.charge_power > 1 and vector.length(self.object:getvelocity()) < 1) then
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
				elseif math.random() < 0.05 and nearest.distance > 9 + math.random() * 21 then
					self:set_charging_state(true)
					self.destination = nil
				elseif not self.destination then
					local nearest_pos = nearest.player:getpos()
					local dir = vector.direction(nearest_pos, self.object:getpos())
					self.destination = vector.add(nearest_pos, vector.multiply(dir, math.random() * 30))
				end
			end
		end
	end,

	set_charging_state = function(self, state)
		self.charging = state
		if state then
			self.charge_power = 0
			self.move_speed = 8
			self.animation = self.charging_animation
			self:set_animation("charge")
		else
			self.move_speed = 4
			self.animation = self.normal_animation
			self:set_animation("attack")
		end
	end,

	crash_blocks = function(self, pos, radius)
		local hit_count = 0
		local p = {x=0, y=0, z=pos.z - radius}
		for z = -radius, radius do
			p.y = pos.y - radius
			for y = -radius, radius do
				p.x = pos.x - radius
				for x = -radius, radius do
					if self:can_destroy_node(p) then
						minetest.dig_node(p)
						hit_count = hit_count + 1
					end
					p.x = p.x + 1
				end
				p.y = p.y + 1
			end
			p.z = p.z + 1
		end

		return hit_count
	end,

	crash_entities = function(self, pos, radius)
		local weight_count = 0
		for _,o in pairs(minetest.get_objects_inside_radius(pos, radius)) do
			if o ~= self.object then
				local dir = vector.direction(self.object:getpos(), o:getpos())
				o:set_hp(o:get_hp() - 3)

				local e = o:get_luaentity()
				if e then
					local v = o:getvelocity()
					local m = e.mass or 0.1
					if v then
						dir.y = dir.y + 1
						o:setvelocity(vector.add(v, vector.multiply(dir, 15/m)))
					end

					weight_count = weight_count + m
				end
			end
		end
		return weight_count
	end,

	can_destroy_node = function(self, pos)
		local node = minetest.get_node_or_nil(pos)
		if not node or minetest.registered_nodes[node.name].walkable then
			return true
		else
			return false
		end
	end,
})