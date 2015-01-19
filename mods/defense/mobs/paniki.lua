defense.mobs.register_mob("defense:paniki", {
	hp_max = 3,
	collisionbox = {-0.4,-0.01,-0.4, 0.4,0.8,0.4},
	visual_size = {x=1.0, y=1.0},
	-- mesh = "defense_paniki.b3d",
	visual = "sprite",
	textures = {"defense_paniki.png"},
	makes_footstep_sound = false,

	animation = {
		-- idle = {a=0, b=39, rate=30},
		-- jump = {a=40, b=49, rate=15},
		-- fall = {a=50, b=64, rate=20},
		-- attack = {a=65, b=72, rate=15},
		-- move = {a=75, b=99, rate=40},
		-- move_attack = {a=100, b=113, rate=20},
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
				self.flee_timer = math.random()
				self.last_hp = self.object:get_hp()
			end
		end
	end
})