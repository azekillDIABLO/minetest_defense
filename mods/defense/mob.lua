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
	armor = 0,
	attack_range = 1,
	attack_damage = 1,
	attack_interval = 1,

	current_animation = nil,
	current_animation_end = 0,
	destination = nil, -- position
	last_attack_time = 0,
	life_timer = 75,
	pause_timer = 0,
	timer = 0,
}

function mobs.default_prototype:on_activate(staticdata)
	self.object:set_armor_groups({fleshy = 100 - self.armor})
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
		self:damage(self.object:get_hp() * math.random() + 1)
	end

	if self.life_timer <= 0 then
		if destination_distance > 6 then
			self.object:remove()
		end
	else
		self.life_timer = self.life_timer - dtime
	end

	self.timer = self.timer + dtime
end

function mobs.default_prototype:on_punch(puncher, time_from_last_punch, tool_capabilities, dir)
	-- Weapon wear code adapted from TenPlus1's mobs redo (https://github.com/tenplus1/mobs)
	if puncher then
		local weapon = puncher:get_wielded_item()
		if tool_capabilities then
			local wear = (0.01) * (self.armor / 100) * 65534 + 1
			weapon:add_wear(wear)
			puncher:set_wielded_item(weapon)
		end
	end

	dir.y = dir.y + 1
	local m = self.mass or 1
	local knockback = vector.multiply(vector.normalize(dir), 10 / (1 + m))
	self.object:setvelocity(vector.add(self.object:getvelocity(), knockback))
	self.pause_timer = 0.3

	if self.object:get_hp() <= 0 then
		self:die()
	end
end

function mobs.default_prototype:damage(amount)
	if self.object:get_hp() <= amount then
		self:die()
	else
		self.object:set_hp(self.object:get_hp() - amount)
	end
end

function mobs.default_prototype:attack(obj, dir)
	obj:punch(self.object, self.timer - self.last_attack_time,  {
		full_punch_interval=self.attack_interval,
		damage_groups = {fleshy=self.attack_damage}
	}, dir)
end

function mobs.default_prototype:move(dtime, destination)
	mobs.move_method[self.movement](self, dtime, destination)
end

function mobs.default_prototype:hunt()
	local nearest = self:find_nearest_player()
	if nearest.player then
		local dir = vector.direction(nearest.position, self.object:getpos())
		if nearest.distance <= self.attack_range then
			self:do_attack(nearest.player)
		end
		if nearest.distance > self.attack_range or nearest.distance < self.attack_range/2-1 then
			local r = math.max(0, self.attack_range - 2)
			self.destination = vector.add(nearest.position, vector.multiply(dir, r))
		end
	end
end

function mobs.default_prototype:do_attack(obj)
	if self.last_attack_time + self.attack_interval < self.timer then
		local dir = vector.direction(self.object:getpos(), obj:getpos())
		self:attack(obj, dir)
		self.last_attack_time = self.timer
		if self.current_animation == "move" then
			self:set_animation("move_attack")
		else
			self:set_animation("attack")
		end
		self.object:setyaw(math.atan2(dir.z, dir.x))
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

function mobs.default_prototype:die()
	-- self:on_death()
	self.object:remove()
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
	local nearest_pos = p
	local nearest_dist = 9999
	for _,obj in ipairs(minetest.get_connected_players()) do
		if obj:is_player() then
			if not nearest_player then
				nearest_player = obj
				nearest_pos = obj:getpos()
				nearest_pos.y = nearest_pos.y + 1
				nearest_dist = vector.distance(nearest_pos, p)
			else
				local pos = obj:getpos()
				pos.y = pos.y + 1
				local d = vector.distance(pos, p)
				if d < nearest_dist then
					nearest_player = obj
					nearest_pos = pos
					nearest_dist = d
				end
			end
		end
	end
	return {player=nearest_player, position=nearest_pos, distance=nearest_dist}
end

mobs.move_method = {}
function mobs.move_method:air(dtime, destination)
	local delta = vector.subtract(destination, self.object:getpos())
	local dist = vector.length(delta)

	local r_angle = (self.id/100000) * 2 * math.pi
	local r_radius = (self.id/100000) * dist/3
	delta = vector.add(delta, {
		x=math.cos(r_angle)*r_radius,
		y=r_radius,
		z=math.sin(r_angle)*r_radius
	})

	local speed = self.move_speed * math.max(0, math.min(1, 0.8 * dist))
	local t
	local v = self.object:getvelocity()
	if vector.length(v) < self.move_speed * 1.5 then
		t = math.pow(0.1, dtime)
	else
		t = math.pow(0.9, dtime)
		speed = speed * 0.9
	end
	self.object:setvelocity(vector.add(
		vector.multiply(self.object:getvelocity(), t),
		vector.multiply(vector.normalize(delta), speed * (1-t))
	))
	
	if speed > self.move_speed * 0.04 then
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
		self:set_animation("idle", {"attack", "move_attack"})
	end
end
function mobs.move_method:ground(dtime, destination)
	local delta = vector.subtract(destination, self.object:getpos())
	delta.y = 0
	local dist = vector.length(delta)

	local r_angle = (self.id/100000) * 2 * math.pi
	local r_radius = dist/4
	delta = vector.add(delta, {
		x=math.cos(r_angle)*r_radius,
		y=0,
		z=math.sin(r_angle)*r_radius
	})

	local speed = self.move_speed * math.max(0, math.min(1, 0.8 * dist))
	local t
	local v = self.object:getvelocity()
	if self:is_standing() and vector.length(v) < self.move_speed * 3 then
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

	-- Check for obstacle to jump
	local jump = false
	if dist > 1 then
		local p = self.object:getpos()
		p.y = p.y + self.collisionbox[2] + 0.5
		local sx = self.collisionbox[4] - self.collisionbox[1]
		local sz = self.collisionbox[6] - self.collisionbox[3]
		local r = math.sqrt(sx*sx + sz*sz)/2 + 0.5
		local fronts = {
			{x = dir.x * r, y = 0, z = dir.z * r},
			{x = dir.x + dir.z * r, y = 0, z = dir.z + dir.x * r},
			{x = dir.x - dir.z * r, y = 0, z = dir.z - dir.x * r},
		}
		for _,f in ipairs(fronts) do
			local node = minetest.get_node_or_nil(vector.add(p, f))
			if not node or minetest.registered_nodes[node.name].walkable then
				jump = true
				break
			end
		end
	end

	if jump then
		self:jump(dir)
	elseif self:is_standing() then
		if speed > self.move_speed * 0.06 then
			local yaw = self.object:getyaw()
			local yaw_delta = math.atan2(dir.z, dir.x) - yaw
			if yaw_delta < -math.pi then
				yaw_delta = yaw_delta + math.pi * 2
			elseif yaw_delta > math.pi then
				yaw_delta = yaw_delta - math.pi * 2
			end
			self.object:setyaw(yaw + yaw_delta * (1-t))
			self:set_animation("move", {"move_attack"})
		else
			self:set_animation("idle", {"attack", "move_attack"})
		end
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