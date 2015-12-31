local math = math

setfenv( 1, DOOM )

function R_PointOnSide(x, y, node)
	local dx = (x - node.x)
	local dy = (y - node.y)
	
	local left = node.dy * dx
	local right = dy * node.dx
	
	return right < left and 0 or 1
end

function R_PointToAngle(x, y)
	return math.deg(math.atan2(y - viewy, x - viewx))
end
