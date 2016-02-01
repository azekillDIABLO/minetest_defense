defense.mobs = {}
local mobs = defense.mobs
mobs.gravity = -9.81
mobs.default_prototype = {
	-- minetest properties & defaults
	physical = true,
	collide_with_objects = true,
	makes_footstep_sound = true,
	visual = "mesh",
	automatic_face_movement_dir = true,
	stepheight = 0.6,
	-- custom properties
	id = 0,
	smart_path = true,
	mass = 1,
	movement = "ground", -- "ground"/"air"/"crawl"
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

	-- cache
	cache_is_standing = nil,
	cache_find_nearest_player = nil,
}

local reg_nodes = minetest.registered_nodes

local function vec_zero() return {x=0, y=0, z=0} end

function mobs.default_prototype:on_activate(staticdata)
	self.object:set_armor_groups({fleshy = 100 - self.armor})
	if self.movement ~= "air" then
		self.object:setacceleration({x=0, y=mobs.gravity, z=0})
	end
	self.id = math.random(0, 100000)
end

function mobs.default_prototype:on_step(dtime)
	self.cache_is_standing = nil
	self.cache_find_nearest_player = nil

	if self.pause_timer <= 0 then
		if self.destination then
			self:move(dtime, self.destination)
			if vector.distance(self.object:getpos(), self.destination) < 0.5 then
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
	if self.movement == "crawl" then
		if self:is_standing() then
			self.object:setacceleration(vec_zero())
		else
			self.object:setacceleration({x=0, y=mobs.gravity, z=0})
		end
	end

	-- Die when morning comes
	if not defense:is_dark() then
		local damage = self.object:get_hp() * math.random()
		if damage >= 0.5 then
			self:damage(math.ceil(damage))
		end
	end

	-- Remove when far enough and may not reach the player at all
	local nearest = self:find_nearest_player()
	if self.life_timer <= 0 then
		if nearest.distance > 12 then
			self.object:remove()
		end
	else
		self.life_timer = self.life_timer - dtime
	end

	-- Disable collision when far enough
	if self.collide_with_objects then
		if nearest.distance > 6 then
			self.collide_with_objects = false
			self.object:set_properties({collide_with_objects = self.collide_with_objects})
		end
	else
		if nearest.distance < 1.5 then
			self.collide_with_objects = true
			self.object:set_properties({collide_with_objects = self.collide_with_objects})
		end
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
		if nearest.distance <= self.attack_range then
			self:do_attack(nearest.player)
		end
		if nearest.distance > self.attack_range or nearest.distance < self.attack_range/2-1 then
			-- TODO Use pathfinder

			if not self.destination then
				local r = math.max(0, self.attack_range - 2)
				local dir = vector.direction(nearest.position, self.object:getpos())
				self.destination = vector.add(nearest.position, vector.multiply(dir, r))
			end
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
	end
	self.life_timer = math.min(300, self.life_timer + 60)
end

function mobs.default_prototype:jump(direction)
	if self:is_standing() then
		if direction then
			direction.y = 0
			direction = vector.normalize(direction)
		else
			direction = vec_zero()
		end
		local v = self.object:getvelocity()
		v.y = math.sqrt(2 * -mobs.gravity * (self.jump_height + 0.2))
		v.x = direction.x * self.jump_height
		v.z = direction.z * self.jump_height
		self.object:setvelocity(vector.add(self.object:getvelocity(), v))
		self:set_animation("jump")
	end
end

function mobs.default_prototype:die()
	-- self:on_death()
	self.object:remove()
end

function mobs.default_prototype:is_standing()
	if self.cache_is_standing ~= nil then
		return self.cache_is_standing
	end

	if self.movement == "air" then
		self.cache_is_standing = false
		return false
	end

	if self.movement == "crawl" then
		local ret = self:calculate_wall_normal() ~= nil
		self.cache_is_standing = ret
		return ret
	end

	if self.object:getvelocity().y ~= 0 then
		self.cache_is_standing = false
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
		if not node or reg_nodes[node.name].walkable then
			self.cache_is_standing = true
			return true
		end
	end

	self.cache_is_standing = false
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
	if self.cache_find_nearest_player ~= nil then
		return self.cache_find_nearest_player
	end

	local p = self.object:getpos()
	local nearest_player = nil
	local nearest_pos = p
	local nearest_dist = 9999
	for _,obj in ipairs(minetest.get_connected_players()) do
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

	local ret = {player=nearest_player, position=nearest_pos, distance=nearest_dist}
	self.cache_find_nearest_player = ret
	return ret
end

function mobs.default_prototype:calculate_wall_normal()
	local p = self.object:getpos()
	local normals = {1,0,-1}
	local xs = {self.collisionbox[1]-0.5,0,self.collisionbox[4]+0.5}
	local ys = {self.collisionbox[2]-0.5,0,self.collisionbox[5]+0.5}
	local zs = {self.collisionbox[3]-0.5,0,self.collisionbox[6]+0.5}

	local normal = vector.new()
	local count = 0
	for xi=1,3 do
		for yi=1,3 do
			for zi=1,3 do
				if xi ~= 2 and yi ~= 2 and zi ~= 2 then
					local sp = vector.add(p, {x=xs[xi], y=ys[yi], z=zs[zi]})
					local node = minetest.get_node_or_nil(sp)
					if node and reg_nodes[node.name].walkable then
						normal = vector.add(normal, {x=normals[xi], y=normals[yi], z=normals[zi]})
						count = count + 1
					end
				end
			end
		end
	end

	if count > 0 then
		return vector.normalize(normal)
	else
		return nil
	end
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

	local speed = self.move_speed * math.max(0, math.min(1, 1.2 * dist))
	local t
	local v = self.object:getvelocity()
	if vector.length(v) < self.move_speed * 1.5 then
		t = math.pow(0.1, dtime)
	else
		t = math.pow(0.4, dtime)
		speed = speed * 0.9
	end
	self.object:setvelocity(vector.add(
		vector.multiply(self.object:getvelocity(), t),
		vector.multiply(dist > 0 and vector.normalize(delta) or vec_zero(), speed * (1-t))
	))
	
	if speed > self.move_speed * 0.04 then
		self:set_animation("move", {"attack", "move_attack"})
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

	local speed = self.move_speed * math.max(0, math.min(1, 1.2 * dist))
	local t
	local v = self.object:getvelocity()
	if self:is_standing() and vector.length(v) < self.move_speed * 4 then
		t = math.pow(0.001, dtime)
	else
		t = math.pow(0.4, dtime)
		speed = speed * 0.9
	end
	local dir = dist > 0 and vector.normalize(delta) or vec_zero()
	local v2 = vector.add(
		vector.multiply(v, t),
		vector.multiply(dir, speed * (1-t))
	)
	v2.y = v.y
	self.object:setvelocity(v2)

	-- Check for jump
	local jump = nil
	if self.smart_path then
		-- TODO Jump to destination
	else
		if dist > 1 then
			local p = self.object:getpos()
			p.y = p.y + self.collisionbox[2] + 0.5
			local sx = self.collisionbox[4] - self.collisionbox[1]
			local sz = self.collisionbox[6] - self.collisionbox[3]
			local r = math.sqrt(sx*sx + sz*sz)/2 + 0.5
			local fronts = {
				{x = dir.x * self.jump_height, y = 0, z = dir.z * self.jump_height},
				{x = dir.x * r, y = 0, z = dir.z * r},
				{x = dir.x + dir.z * r, y = 0, z = dir.z + dir.x * r},
				{x = dir.x - dir.z * r, y = 0, z = dir.z - dir.x * r},
			}
			for _,f in ipairs(fronts) do
				local node = minetest.get_node_or_nil(vector.add(p, f))
				if not node or reg_nodes[node.name].walkable then
					jump = vector.direction(self.object:getpos(), destination)
					break
				end
			end
		end
	end

	if jump then
		self:jump(jump)
	elseif self:is_standing() then
		if speed > self.move_speed * 0.06 then
			self:set_animation("move", {"move_attack"})
		else
			self:set_animation("idle", {"attack", "move_attack"})
		end
	end
end
function mobs.move_method:crawl(dtime, destination)
	local delta = vector.subtract(destination, self.object:getpos())
	local dist = vector.length(delta)

	local speed = self.move_speed * math.max(0, math.min(1, 1.2 * dist))
	local t
	local v = self.object:getvelocity()
	if self:is_standing() and vector.length(v) < self.move_speed * 4 then
		t = math.pow(0.001, dtime)
	else
		t = math.pow(0.4, dtime)
		speed = speed * 0.9
	end

	local wall = self:calculate_wall_normal()
	if wall and dist > 0 then
		local dot = math.abs(wall.x * delta.x + wall.y * delta.y + wall.z * delta.z)
		delta = vector.add(delta, vector.multiply(wall, -dot))
	end
	local dir = vector.normalize(delta)
	local v2 = vector.add(
		vector.multiply(v, t),
		vector.multiply(dir, speed * (1-t))
	)
	self.object:setvelocity(v2)
	
	if self:is_standing() then
		if speed > self.move_speed * 0.06 then
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

	if defense.pathfinder and prototype.smart_path then
		defense.pathfinder:register_class(name, {
			collisionbox = prototype.collisionbox,
			jump_height = math.floor(prototype.jump_height),
			path_check = def.pathfinder_check or defense.pathfinder.default_path_check[prototype.movement],
			cost_method = def.pathfinder_cost or defense.pathfinder.default_cost_method[prototype.movement],
		})
	end

	minetest.register_entity(name, prototype)
end