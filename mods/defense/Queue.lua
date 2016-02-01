Queue = {}
function Queue.new ()
	return {first = 1, last = 0}
end

function Queue.push (queue, value)
	local last = queue.last + 1
	queue.last = last
	queue[last] = value
end

function Queue.pop (queue)
	local first = queue.first
	if first > queue.last then error("queue is empty") end
	local value = queue[first]
	queue[first] = nil
	queue.first = first + 1

	-- resize internal array
	first = queue.first
	local last = queue.last
	if first * 2 > last then
		for i = first,last do
			queue[i - first + 1] = queue[i]
			queue[i] = nil
		end
		queue.first = 1
		queue.last = last - first + 1
	end

	return value
end

function Queue.push_back (queue, value)
	local first = queue.first
	if first > 1 then
		first = first - 1
		queue.first = first
		queue[first] = value
	else 
		-- shift elements to right
		local last = queue.last
		for i = last,first,-1 do
			queue[i + 1] = queue[i]
		end
		
		queue[1] = value
		queue.first = 1
		queue.last = last + 1
	end
end

function Queue.remove (queue, index)
	local last = queue.last - 1
	queue.last = last

	for i = index,last-1 do
		queue[i] = queue[i + 1]
	end

	queue[last + 1] = nil
end

function Queue.size (queue)
	return queue.last - queue.first + 1
end