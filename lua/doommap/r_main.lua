local math = math

setfenv( 1, DOOM )

function NormalizeAngle(angle)
	while angle >= 360 do angle = angle - 360 end
	while angle < 0 do angle = angle + 360 end
	return angle
end

function R_PointOnSide(x, y, node)
	local dx = (x - node.x)
	local dy = (y - node.y)

	local left = node.dy * dx
	local right = dy * node.dx

	return right < left and 0 or 1
end

function R_PointToAngle(x, y)
	return NormalizeAngle(math.deg(math.atan2(y - view.y, x - view.x)))
end
