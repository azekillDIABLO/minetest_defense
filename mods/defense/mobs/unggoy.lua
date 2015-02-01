defense.mobs.register_mob("defense:unggoy", {
	hp_max = 11,
	collisionbox = {-0.4,-0.01,-0.4, 0.4,1.5,0.4},
	mesh = "defense_unggoy.b3d",
	textures = {"defense_unggoy.png"},
	makes_footstep_sound = true,

	animation = {
		idle = {a=0, b=39, rate=30},
		jump = {a=40, b=49, rate=15},
		fall = {a=50, b=64, rate=20},
		attack = {a=65, b=72, rate=15},
		move = {a=75, b=99, rate=40},
		move_attack = {a=100, b=113, rate=20},
	},

	mass = 4,
	move_speed = 5,
	jump_height = 2,
	armor = 0,
	attack_damage = 1,
	attack_range = 1.5,
	attack_interval = 0.6,

	wander = false,

	on_activate = function(self, staticdata)
		defense.mobs.default_prototype.on_activate(self, staticdata)
		-- Some monkeys can jump higher
		if math.random() < 0.1 then
			self.jump_height = self.jump_height + math.random() * 2
		end
	end,

	on_step = function(self, dtime)
		defense.mobs.default_prototype.on_step(self, dtime)
		if self.wander then
			if math.random() < 0.1 then
				self.destination = vector.add(
					self.object:getpos(),
					{x=math.random(-4,4),y=0,z=math.random(-4,4)}
				)
			elseif math.random() < 0.1 then
				self.wander = false
			end
		else
			if math.random() < 0.006 then
				self.wander = true
			else
				self:hunt()
			end
		end
		if math.random() < 0.05 then
			self:jump()
		end
	end,

	is_standing = function(self)
		-- Able to stand on top of others
		if defense.mobs.default_prototype.is_standing(self) then
			return true
		else
			local vel = self.object:getvelocity()
			if math.abs(vel.y) > 0.05 then
				return false
			end

			local pos = self.object:getpos()
			pos.y = pos.y - 1
			for _,o in ipairs(minetest.get_objects_inside_radius(pos, 1)) do
				if o ~= self.object then
					local e = o:get_luaentity()
					if e and e.name == self.name then
						return true
					end
				end
			end
			return false
		end
	end,
})