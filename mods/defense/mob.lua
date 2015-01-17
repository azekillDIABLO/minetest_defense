defense.mobs = {}
local mobs = defense.mobs
mobs.gravity = -9.81
mobs.default_prototype = {
	-- minetest properties & defaults
	physical = true,
	collide_with_objects = true,
	makes_footstep_sound = true,
	visual = "mesh",
	automatic_face_movement_dir = false,
	stepheight = 0.6,
	-- custom properties
	id = 0,
	movement = "ground", -- "ground"/"air"
	move_speed = 1,
	jump_height = 1,
	armor = 100,
	attack_range = 1,
	attack_damage = 1,
	attack_interval = 1,

	current_animation = nil,
	current_animation_end = 0,
	destination = nil, -- position
	last_attack_time = 0,
	life_timer = 90,
	pause_timer = 0,
	timer = 0,
}

function mobs.default_prototype:on_activate(staticdata)
	self.object:set_armor_groups({fleshy=self.armor})
	if self.movement == "ground" then
		self.object:setacceleration({x=0, y=mobs.gravity, z=0})
	end
	self.id = math.random(0, 100000)
end

function mobs.default_prototype:on_step(dtime)
	local destination_distance = 0
	if self.destination then
		destination_distance = vector.distance(self.object:getpos(), self.destination)
	end

	if self.pause_timer <= 0 then
		if self.destination then
			self:move(dtime, self.destination)
			if destination_distance < 1 then
				self.destination = nil
			end
		else
			self:move(dtime, self.object:getpos())
		end
	else
		self.pause_timer = self.pause_timer - dtime
	end

	if self.movement ~= "air" and not self:is_standing() then
		self:set_animation("fall", {"jump", "attack", "move_attack"})
	end

	if not defense:is_dark() then
		-- self:damage(self.object:get_hp() * math.random() * 0.2 + 1)
	end

	if self.life_timer <= 0 then
		if destination_distance > 12 then
			self.object:remove()
		end
	else
		self.life_timer = self.life_timer - dtime
	end

	self.timer = self.timer + dtime
end

function mobs.default_prototype:on_punch(puncher, time_from_last_punch, tool_capabilities, dir)
	dir.y = dir.y + 1
	local knockback = vector.multiply(vector.normalize(dir), 10 / (1 + self.mass))
	self.object:setvelocity(vector.add(self.object:getvelocity(), knockback))
	self.pause_timer = 0.3
end

function mobs.default_prototype:damage(amount)
	if self.object:get_hp() <= amount then
		self.object:remove()
	else
		self.object:set_hp(self.object:get_hp() - amount)
	end
end

function mobs.default_prototype:attack(obj)
	local dir = vector.direction(self.object:getpos(), obj:getpos())
	obj:punch(self.object, self.timer - self.last_attack_time,  {
		full_punch_interval=self.attack_interval,
		damage_groups = {fleshy=self.attack_damage}
	}, dir)
	self.object:setyaw(math.atan2(dir.z, dir.x))
end

function mobs.default_prototype:move(dtime, destination)
	mobs.move_method[self.movement](self, dtime, destination)
end

function mobs.default_prototype:hunt()
	local nearest = self:find_nearest_player()
	if nearest.player then
		local nearest_pos = nearest.player:getpos()
		local dir = vector.direction(nearest_pos, self.object:getpos())
		self.destination = vector.add(nearest_pos, vector.multiply(dir, self.attack_range/2))
		if nearest.distance < self.attack_range then
			self:do_attack(nearest.player)
		end
	end
end

function mobs.default_prototype:do_attack(obj)
	if self.last_attack_time + self.attack_interval < self.timer then
		self:attack(obj)
		self.last_attack_time = self.timer
		if self.current_animation == "move" then
			self:set_animation("move_attack")
		else
			self:set_animation("attack")
		end
	end
	self.life_timer = math.min(300, self.life_timer + 60)
end

function mobs.default_prototype:jump(direction)
	if self:is_standing() then
		direction = vector.normalize(direction)
		local v = self.object:getvelocity()
		v.y = math.sqrt(2 * -mobs.gravity * (self.jump_height + 0.2))
		v.x = direction.x * v.y
		v.z = direction.z * v.y
		self.object:setvelocity(v)
		self:set_animation("jump")
	end
end

function mobs.default_prototype:is_standing()
	if self.movement == "air" then
		return false
	end
	local p = self.object:getpos()
	p.y = p.y + self.collisionbox[2] - 0.5
	local corners = {
		vector.add(p, {x=self.collisionbox[1], y=0, z=self.collisionbox[3]}),
		vector.add(p, {x=self.collisionbox[1], y=0, z=self.collisionbox[6]}),
		vector.add(p, {x=self.collisionbox[4], y=0, z=self.collisionbox[3]}),
		vector.add(p, {x=self.collisionbox[4], y=0, z=self.collisionbox[6]}),
	}
	for _,c in ipairs(corners) do
		local node = minetest.get_node_or_nil(c)
		if not node or minetest.registered_nodes[node.name].walkable and self.object:getvelocity().y == 0 then
			return true
		end
	end
	return false
end

function mobs.default_prototype:set_animation(name, inhibit)
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
		self.object:set_animation({x=anim_prop.a, y=anim_prop.b}, anim_prop.rate, 0)
	end
end

function mobs.default_prototype:find_nearest_player()
	local p = self.object:getpos()
	local nearest_player = nil
	local nearest_dist = 999
	for _,obj in ipairs(minetest.get_connected_players()) do
		if obj:is_player() then
			if nearest_player then 
				local d = vector.distance(nearest_player:getpos(), p)
				if d < nearest_dist then
					nearest_player = obj
					nearest_dist = d
				end
			else
					nearest_player = obj
					nearest_dist = vector.distance(obj:getpos(), p)
			end
		end
	end
	return {player=nearest_player, distance=nearest_dist}
end

mobs.move_method = {}
function mobs.move_method:air(dtime, destination)
	local delta = vector.subtract(destination, self.object:getpos())
	local dist = vector.length(delta)

	local r_angle = (self.id/100000) * 2 * math.pi
	local r_radius = dist/2
	delta = vector.add(delta, {
		x=math.cos(r_angle)*r_radius,
		y=0,
		z=math.sin(r_angle)*r_radius
	})

	local speed = self.move_speed * math.max(0, math.min(1, 2 * dist - 0.5))
	if speed > 0.01 then
		local t
		local v = self.object:getvelocity()
		if vector.length(v) < self.move_speed * 1.1 then
			t = math.pow(0.1, dtime)
		else
			t = math.pow(0.9, dtime)
			speed = speed * 0.9
		end
		self.object:setvelocity(vector.add(
			vector.multiply(self.object:getvelocity(), t),
			vector.multiply(vector.normalize(delta), speed * (1-t))
		))
		
		local yaw = self.object:getyaw()
		local yaw_delta = math.atan2(delta.z, delta.x) - yaw
		if yaw_delta < -math.pi then
			yaw_delta = yaw_delta + math.pi * 2
		elseif yaw_delta > math.pi then
			yaw_delta = yaw_delta - math.pi * 2
		end
		self.object:setyaw(yaw + yaw_delta * (1-t))

		self:set_animation("move", {"move_attack"})
	else
		self.object:setvelocity({x=0, y=0, z=0})
		self:set_animation("idle", {"attack", "move_attack"})
	end
end
function mobs.move_method:ground(dtime, destination)
	local delta = vector.subtract(destination, self.object:getpos())
	delta.y = 0
	local dist = vector.length(delta)

	local r_angle = (self.id/100000) * 2 * math.pi
	local r_radius = dist/3
	delta = vector.add(delta, {
		x=math.cos(r_angle)*r_radius,
		y=0,
		z=math.sin(r_angle)*r_radius
	})

	local speed = self.move_speed * math.max(0, math.min(1, 3 * dist - 0.5))
	if speed > 0.01 then
		local t
		local v = self.object:getvelocity()
		if self:is_standing() and vector.length(v) < self.move_speed * 2 then
			t = math.pow(0.001, dtime)
		else
			t = math.pow(0.9, dtime)
			speed = speed * 0.9
		end
		local dir = vector.normalize(delta)
		local v2 = vector.add(
			vector.multiply(v, t),
			vector.multiply(dir, speed * (1-t))
		)
		v2.y = v.y
		self.object:setvelocity(v2)

		local yaw = self.object:getyaw()
		local yaw_delta = math.atan2(dir.z, dir.x) - yaw
		if yaw_delta < -math.pi then
			yaw_delta = yaw_delta + math.pi * 2
		elseif yaw_delta > math.pi then
			yaw_delta = yaw_delta - math.pi * 2
		end
		self.object:setyaw(yaw + yaw_delta * (1-t))

		-- Check for obstacle to jump
		local jump = false
		if dist > 1 then
			local p = self.object:getpos()
			p.y = p.y + self.collisionbox[2] + 0.5
			local sx = self.collisionbox[4] - self.collisionbox[1]
			local sz = self.collisionbox[6] - self.collisionbox[3]
			local r = math.sqrt(sx*sx + sz*sz)/2 + self.move_speed/3 + 0.5
			local node = minetest.get_node_or_nil(vector.add(p, vector.multiply(dir, r)))
			if not node or minetest.registered_nodes[node.name].walkable then
				jump = true
			end
		end

		if jump then
			self:jump(dir)
		elseif self:is_standing() then
			self:set_animation("move", {"move_attack"})
		end
	else
		local v = self.object:getvelocity()
		v.x = 0
		v.z = 0
		self.object:setvelocity(v)
		self:set_animation("idle", {"attack", "move_attack"})
	end
end

function mobs.register_mob(name, def)
	local prototype = {}
	for k,v in pairs(mobs.default_prototype) do
		prototype[k] = v
	end
	for k,v in pairs(def) do
		prototype[k] = v
	end

	prototype.move = def.move or mobs.move_method[prototype.movement]

	minetest.register_entity(name, prototype)
end