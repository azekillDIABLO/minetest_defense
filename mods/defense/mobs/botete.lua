defense.mobs.register_mob("defense:botete", {
	hp_max = 2,
	collisionbox = {-0.4,-0.4,-0.4, 0.4,0.4,0.4},
	mesh = "defense_botete.b3d",
	textures = {"defense_botete.png"},
	makes_footstep_sound = false,

	animation = {
		-- idle = {a=0, b=29, rate=50},
		-- attack = {a=60, b=89, rate=50},
		-- move = {a=30, b=59, rate=75},
		-- move_attack = {a=60, b=89, rate=75},
	},

	mass = 1,
	movement = "air",
	move_speed = 6,
	attack_damage = 0,
	attack_range = 8,
	attack_interval = 2.2,

	on_step = function(self, dtime)
		
	end,
})