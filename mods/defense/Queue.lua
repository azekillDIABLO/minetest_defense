Queue = {}
function Queue.new ()
	return {first = 0, last = -1}
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
	return value
end

function Queue.size (queue)
	return queue.last - queue.first + 1
end