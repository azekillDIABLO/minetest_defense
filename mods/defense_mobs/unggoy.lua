defense_mobs.register_mob("defense_mobs:unggoy", {
	hp_max = 1,
	weight = 6,
	collisionbox = {-0.4,-0.01,-0.4, 0.4,1.5,0.4},
	visual_size = {x=2.5, y=2.5},
	mesh = "defense_mobs_unggoy.b3d",
	textures = {"defense_mobs_unggoy.png"},
	makes_footstep_sound = true,

	animation = {
		idle = {a=0, b=39, rate=30},
		jump = {a=40, b=49, rate=15},
		fall = {a=50, b=64, rate=20},
		attack = {a=65, b=72, rate=15},
		move = {a=75, b=99, rate=40},
		move_attack = {a=100, b=113, rate=20},
	},

	move_speed = 5,
	jump_height = 2,
	attack_damage = 1,
	attack_interval = 0.5,

	on_activate = function(self, staticdata)
		self:hunt(70)
	end,

	on_step = function(self, dtime)
		self:hunt(20)
	end,
})