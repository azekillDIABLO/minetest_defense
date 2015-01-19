defense.mobs.register_mob("defense:paniki", {
	hp_max = 3,
	collisionbox = {-0.4,-0.4,-0.4, 0.4,0.4,0.4},
	visual_size = {x=5.0, y=5.0},
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
	attack_range = 1.5,
	attack_interval = 0.8,

	last_hp = 3,
	flee_timer = 0,

	on_step = function(self, dtime)
		defense.mobs.default_prototype.on_step(self, dtime)
		if self.flee_timer > 0 then
			local nearest = self:find_nearest_player()
			local pos = self.object:getpos()
			local delta = vector.subtract(pos, nearest.player:getpos())
			self.destination = vector.add(pos, delta)
			if vector.length(delta) <= self.attack_range then
				self:hunt()
			end
			self.flee_timer = self.flee_timer - dtime
		else
			self:hunt()
			if self.object:get_hp() < self.last_hp then
				self.flee_timer = math.random() * 2 / (self.object:get_hp() + 1)
				self.last_hp = self.object:get_hp()
			end
		end
	end,

	attack = function(self, obj)
		defense.mobs.default_prototype.attack(self, obj)
		self.object:set_hp(self.object:get_hp() + 1)
		self.flee_timer = 0.1
	end,
})