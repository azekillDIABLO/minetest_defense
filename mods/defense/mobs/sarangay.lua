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
		charge = {a=90, b=109, rate=30},
	},

	move_speed = 4,
	jump_height = 1,
	attack_damage = 4,
	attack_range = 2.0,
	attack_interval = 1.5,

	on_step = function(self, dtime)
		defense.mobs.default_prototype.on_step(self, dtime)
		self:hunt()
	end,
})