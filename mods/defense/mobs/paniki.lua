defense.mobs.register_mob("defense:paniki", {
	hp_max = 3,
	collisionbox = {-0.3,-0.3,-0.3, 0.3,0.3,0.3},
	mesh = "defense_paniki.b3d",
	textures = {"defense_paniki.png"},
	makes_footstep_sound = false,

	animation = {
		idle = {a=0, b=29, rate=50},
		attack = {a=60, b=89, rate=50},
		move = {a=30, b=59, rate=75},
		move_attack = {a=60, b=89, rate=75},
	},

	mass = 1,
	movement = "air",
	move_speed = 16,
	attack_damage = 1,
	attack_range = 1.1,
	attack_interval = 0.8,

	rank = 0,
	leader = nil,
	last_hp = 3,
	flee_timer = 0,

	on_activate = function(self, staticdata)
		defense.mobs.default_prototype.on_activate(self, staticdata)
		self.rank = math.random()
		local pos = self.object:getpos()
		local radius = 2
		minetest.after(1, function()
			local greatest_paniki = self
			local greatest_rank = self.rank
			for _,o in pairs(minetest.get_objects_inside_radius(pos, radius)) do
				if self.object ~= o then
					local e = o:get_luaentity()
					if e and e.name == self.name then
						if greatest_rank < e.rank then
							greatest_paniki = e
							greatest_rank = e.rank
						end
					end
				end
			end
			self.leader = greatest_paniki
		end)
	end,

	on_step = function(self, dtime)
		defense.mobs.default_prototype.on_step(self, dtime)
		if self.flee_timer > 0  or (self.leader and self.leader.flee_timer > 0) then
			local nearest = self:find_nearest_player()
			local pos = self.object:getpos()
			local delta = vector.subtract(pos, nearest.player:getpos())
			local x = delta.x
			delta.x = delta.x - delta.z * 0.4
			delta.z = delta.z + x * 0.4
			self.destination = vector.add(pos, delta)
			if self.flee_timer > 0 then
				self.flee_timer = self.flee_timer - dtime
			end
		else
			self:hunt()
			if self.object:get_hp() < self.last_hp then
				self.flee_timer = 0.5 + math.random() / (self.object:get_hp() + 1)
			end
			self.last_hp = self.object:get_hp()
		end
	end,

	attack = function(self, obj, dir)
		defense.mobs.default_prototype.attack(self, obj)
		self.flee_timer = math.random() * 0.5
	end,
})