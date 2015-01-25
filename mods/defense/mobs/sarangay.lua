local c_air = minetest.get_content_id("air")
defense.mobs.register_mob("defense:sarangay", {
	hp_max = 30,
	collisionbox = {-0.9,-0.01,-0.9, 0.9,2.5,0.9},
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
	armor = 0,
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
			if self.charge_power > 0.5 then
				self:hunt()
			end

			-- Break obstacles
			local pos = self.object:getpos()
			pos.y = pos.y + 2.5
			local v = self.object:getvelocity()
			v.y = 0
			pos = vector.add(pos, vector.multiply(vector.normalize(v), 1.5))
			self.charge_power = self:crash_blocks(pos, 4, self.charge_power/2) * 2
			self.charge_power = self:crash_entities(pos, 3, self.charge_power/3) * 3

			if self.charge_power < 0 or (self.charge_power > 1 and vector.length(self.object:getvelocity()) < self.move_speed/4) then
				self:set_charging_state(false)
				self.destination = nil
			else
				self.charge_power = self.charge_power + dtime
			end
		else
			local nearest = self:find_nearest_player()
			if nearest then
				if math.abs(self.object:getpos().y - nearest.player:getpos().y) < 4 then
					if math.random() < 0.1 then
						self:set_charging_state(true)
						self.destination = nil
					elseif nearest.distance < 4 then
						self:hunt()
					elseif not self.destination then
						local nearest_pos = nearest.player:getpos()
						local dir = vector.direction(nearest_pos, self.object:getpos())
						self.destination = vector.add(nearest_pos, vector.multiply(dir, math.random() * 16))
					end
				else
					self:hunt()
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

	crash_blocks = function(self, pos, radius, maxwear)
		local p = {x=0, y=0, z=pos.z - radius}
		for z = -radius, radius do
			p.y = pos.y - radius
			for y = -radius, radius do
				p.x = pos.x - radius
				for x = -radius, radius do
					if x*x + y*y + z*z <= radius then
						local wear = self:get_node_wear(p)
						if wear > 0 then
							minetest.dig_node(p)
							maxwear = maxwear - wear
							if maxwear <= 0 then
								return 0
							end
						end
					end
					p.x = p.x + 1
				end
				p.y = p.y + 1
			end
			p.z = p.z + 1
		end

		return maxwear
	end,

	crash_entities = function(self, pos, radius, maxweight)
		local myv = self.object:getvelocity()
		for _,o in ipairs(minetest.get_objects_inside_radius(pos, radius)) do
			if o ~= self.object then
				-- o:punch(self.object, 1.0,  {
				-- 	full_punch_interval=1.0,
				-- 	damage_groups = {fleshy=1}
				-- }, nil)

				local e = o:get_luaentity()
				if e then
					local m = e.mass or 1
					local v = vector.add(o:getvelocity(), vector.multiply(myv, 1/m))
					if v then
						local dir = vector.direction(self.object:getpos(), o:getpos())
						dir.y = dir.y + 1
						o:setvelocity(vector.add(v, vector.multiply(dir, 3/m)))
					end

					maxweight = maxweight - m
					if maxweight <= 0 then
						return 0
					end
				end
			end
		end

		return maxweight
	end,

	get_node_wear = function(self, pos)
		local node = minetest.get_node_or_nil(pos)
		local groupwear = {
			crumbly = {[1]=0.5, [2]=0.1, [3]=0.1},
			fleshy  = {[1]=1,   [2]=0.5, [3]=0.1},
			snappy  = {[1]=1.5, [2]=1,   [3]=0.5},
			choppy  = {[1]=2,   [2]=1,   [3]=0.5},
			cracky  = {[1]=4,   [2]=2,   [3]=1},
		}
		if node then
			local wear = 0
			for k,v in pairs(groupwear) do
				local rating = minetest.get_item_group(node.name, k)
				if v[rating] and v[rating] > wear then
					wear = v[rating]
				end
			end
			return wear
		else
			return 0
		end
	end,
})