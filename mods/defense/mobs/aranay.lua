minetest.register_entity("defense:aranay_proxy", {
	physical = false,
	collisionbox = {0,0,0,0,0,0},
	visual = "mesh",
	mesh = "defense_aranay.b3d",
	textures = {"defense_aranay.png"},

	parent = nil,
	timer = 0.5,

	on_step = function(self, dtime)
		if self.timer > 0 then
			self.timer = self.timer - dtime
		else
			local active_parent = false
			-- The engine does not provide a simple way to check if an entity is still alive
			for _,e in pairs(minetest.luaentities) do
				if e == self.parent then
					active_parent = true
					break
				end
			end
			if not active_parent or not self.parent then
				self.object:remove()
			end
		end
	end
})

local function dot(a, b)
	return a.x*b.x + a.y*b.y + a.z*b.z
end

local function cross(a, b)
	return {
		x=a.y*b.z - a.z*b.y,
		z=a.z*b.x - a.x*b.z,
		y=a.x*b.y - a.y*b.x
	}
end

local function calculate_rotation(dir, up)
	-- http://stackoverflow.com/a/21627251
	local angle_h = math.atan2(dir.z, dir.x)
	local angle_p = math.asin(dir.y)
	local w0 = vector.normalize({x=dir.z, y=0, z=-dir.x})
	local u0 = cross(w0, dir)
	local angle_b = math.atan2(dot(w0,up), dot(u0,up))
	return {x=angle_p, y=angle_h, z=angle_b}
end

defense.mobs.register_mob("defense:aranay", {
	hp_max = 6,
	collisionbox = {-0.4,-0.01,-0.4, 0.4,0.8,0.4},
	mesh = "defense_aranay_core.b3d",
	makes_footstep_sound = true,

	animation = {
		idle = {a=0, b=19, rate=20},
		jump = {a=20, b=39, rate=5},
		fall = {a=20, b=39, rate=5},
		attack = {a=60, b=69, rate=20},
		move = {a=20, b=39, rate=40},
		move_attack = {a=40, b=59, rate=20},
	},

	mass = 3,
	movement = "crawl",
	move_speed = 3,
	armor = 0,
	attack_damage = 1,
	attack_range = 1.5,
	attack_interval = 0.8,

	proxy = nil,
	rotation = {x=0, y=0, z=0},

	on_activate = function(self, staticdata)
		defense.mobs.default_prototype.on_activate(self, staticdata)

		self.proxy = minetest.add_entity(self.object:getpos(), "defense:aranay_proxy")
		self.proxy:get_luaentity().parent = self
		self.proxy:set_attach(self.object, "", {x=0, y=0, z=0}, {x=0, y=0, z=0})
	end,

	on_step = function(self, dtime)
		defense.mobs.default_prototype.on_step(self, dtime)
		self:hunt()

		-- Rotation
		if vector.length(self.object:getvelocity()) > 0.6 then
			local wall = self:calculate_wall_normal()
			if wall then
				local dir = vector.normalize(self.object:getvelocity())
				local abs_dot = math.abs(dot(dir, wall))
				local up = vector.normalize(vector.add(wall, vector.multiply(dir, -abs_dot)))
				local rot = calculate_rotation(dir, up)
				self.rotation = {x=0,y=math.pi/2,z=0}
			end
			self.proxy:set_attach(self.object, "", {x=0, y=0, z=0}, self.rotation)
		end
	end,

	set_animation = function(self, name, inhibit)
		if self.current_animation == name then
			return
		end
		if inhibit then
			for _,p in ipairs(inhibit) do
				if self.current_animation == p and self.timer < self.current_animation_end then
					return
				end
			end
		end

		local anim_prop = self.animation[name]
		if anim_prop then
			self.current_animation = name
			self.current_animation_end = self.timer + (anim_prop.b - anim_prop.a - 1) / anim_prop.rate
			-- This is the diff line
			self.proxy:set_animation({x=anim_prop.a, y=anim_prop.b}, anim_prop.rate, 0)
		end
	end,
})