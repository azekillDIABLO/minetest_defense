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
	attack_interval = 2.2,

	on_step = function(self, dtime)
		defense.mobs.default_prototype.on_step(self, dtime)
		self:hunt()
	end,
})