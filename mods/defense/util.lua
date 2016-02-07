minetest.wallmounted_to_dir = minetest.wallmounted_to_dir or function(wallmounted)
	return ({[0]={x=0, y=1, z=0},
		     {x=0, y=-1, z=0},
		     {x=1, y=0, z=0},
		     {x=-1, y=0, z=0},
		     {x=0, y=0, z=1},
		     {x=0, y=0, z=-1}})
			[wallmounted]
end

math.sign = math.sign or function(x)
	if x < 0 then
		return -1
	elseif x > 0 then
		return 1
	else
		return 0
	end
end

vector.aim = function(a, b)
	return vector.normalize(vector.subtract(b, a))
end

vector.dot = function(a, b)
	return a.x * b.x + a.y * b.y + a.z * b.z
end