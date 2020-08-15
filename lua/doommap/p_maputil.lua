local ipairs = ipairs
local tobool = tobool

local bit = bit
local math = math

setfenv( 1, DOOM )

SetConstant("PT_ADDLINES", 1)
SetConstant("PT_ADDTHINGS", 2)
SetConstant("PT_EARLYOUT", 4)

function P_PointOnLineSide(x, y, line)
	local dx = line.v2.x - line.v1.x
	local dy = line.v2.y - line.v1.y
	return (line.v1.y - y) * dx - (line.v1.x - x) * dy >= 0 and 0 or 1
end

local BoxOnLineSide_Type = {
	[ST_HORIZONTAL] = function(tmbox, ld)
		local p1 = tmbox.top > ld.v1.y and 1 or 0
		local p2 = tmbox.bottom > ld.v1.y and 1 or 0
		if ld.dx < 0 then
			p1 = bit.bxor(p1, 1)
			p2 = bit.bxor(p2, 1)
		end
		return p1, p2
	end,
	[ST_VERTICAL] = function(tmbox, ld)
		local p1 = tmbox.right < ld.v1.x and 1 or 0
		local p2 = tmbox.left < ld.v1.x and 1 or 0
		if ld.dy < 0 then
			p1 = bit.bxor(p1, 1)
			p2 = bit.bxor(p2, 1)
		end
		return p1, p2
	end,
	[ST_POSITIVE] = function(tmbox, ld)
		local p1 = P_PointOnLineSide(tmbox.left, tmbox.top, ld)
		local p2 = P_PointOnLineSide(tmbox.right, tmbox.bottom, ld)
		return p1, p2
	end,
	[ST_NEGATIVE] = function(tmbox, ld)
		local p1 = P_PointOnLineSide(tmbox.right, tmbox.top, ld)
		local p2 = P_PointOnLineSide(tmbox.left, tmbox.bottom, ld)
		return p1, p2
	end
}

function P_BoxOnLineSide(tmbox, ld)
	local p1, p2 = BoxOnLineSide_Type[ld.slopetype](tmbox, ld)
	if p1 == p2 then return p1 end
	return -1
end

function P_PointOnDivlineSide(x, y, line)
	return (line.y - y) * line.dx - (line.x - x) * line.dy >= 0 and 0 or 1
end

function P_MakeDivline(li)
	local dl = {
		x = li.v1.x,
		y = li.v1.y,
		dx = li.dx,
		dy = li.dy
	}
	return dl
end

function P_InterceptVector(v2, v1)
	local den = v1.dy * v2.dx - v1.dx * v2.dy
	if den == 0 then return 0 end
	local num = (v1.x - v2.x) * v1.dy + (v2.y - v1.y) * v1.dx
	return num / den
end

function P_LineOpening(linedef)
	if not linedef.side[2] then openrange = 0 return end
	local front = linedef.frontsector
	local back = linedef.backsector
	opentop = front.ceilingheight < back.ceilingheight and front.ceilingheight or back.ceilingheight
	if front.floorheight > back.floorheight then
		openbottom = front.floorheight
		lowfloor = back.floorheight
	else
		openbottom = back.floorheight
		lowfloor = front.floorheight
	end
	openrange = opentop - openbottom
end

function P_BlockLinesIterator(x, y, func)
	local Blockmap = Map.Blockmap
	if x < 0 or y < 0 or x >= Blockmap.bmapwidth or y >= Blockmap.bmapheight then return true end
	local list = Blockmap[y * Blockmap.bmapwidth + x + 1]
	for i, ld in ipairs(list) do -- LuaJIT was doing some weird stuff with 'for i = 1, #list do'
		--local ld = list[i]
		if ld.validcount == validcount then continue end
		ld.validcount = validcount
		if not func(ld) then return false end
	end
	return true
end

local intercepts = {}
local intercept_p
local earlyout
trace = {}

function PIT_AddLineIntercepts(ld)
	local s1, s2
	if trace.dx > 16 or trace.dy > 16 or trace.dx < -16 or trace.dy < -16 then
		s1 = P_PointOnDivlineSide(ld.v1.x, ld.v1.y, trace)
		s2 = P_PointOnDivlineSide(ld.v2.x, ld.v2.y, trace)
	else
		s1 = P_PointOnLineSide(trace.x, trace.y, ld)
		s2 = P_PointOnLineSide(trace.x + trace.dx, trace.y + trace.dy, ld)
	end
	if s1 == s2 then return true end
	local dl = P_MakeDivline(ld)
	local frac = P_InterceptVector(trace, dl)
	if frac < 0 then return true end
	if earlyout and frac < 1 and not ld.backsector then return false end
	intercepts[intercept_p] = {}
	intercepts[intercept_p].frac = frac
	intercepts[intercept_p].isaline = true
	intercepts[intercept_p].d = ld
	intercept_p = intercept_p + 1
	return true

end

function P_TraverseIntercepts(func, maxfrac)
	local intercept
	local count = intercept_p - 1
	while count ~= 0 do
		local dist = 32767
		for scan = 1, intercept_p - 1 do
			if intercepts[scan].frac < dist then
				dist = intercepts[scan].frac
				intercept = intercepts[scan]
			end
		end
		if dist > maxfrac then return true end
		if not func(intercept) then return false end
		intercept.frac = 32767
		count = count - 1
	end
	return true
end

function P_PathTraverse(x1, y1, x2, y2, flags, trav)
	local Blockmap = Map.Blockmap
	earlyout = tobool(bit.band(flags, PT_EARLYOUT))
	validcount = validcount + 1
	intercept_p = 1
	if bit.band(x1-Blockmap.bmaporgx, 128-1) == 0 then x1 = x1 + 1 end
	if bit.band(y1-Blockmap.bmaporgy, 128-1) == 0 then y1 = y1 + 1 end

	trace.x = x1
	trace.y = y1
	trace.dx = x2 - x1
	trace.dy = y2 - y1

	x1 = x1 - Blockmap.bmaporgx
	y1 = y1 - Blockmap.bmaporgy
	local xt1 = bit.arshift(x1, 7)
	local yt1 = bit.arshift(y1, 7)

	x2 = x2 - Blockmap.bmaporgx
	y2 = y2 - Blockmap.bmaporgy
	local xt2 = bit.arshift(x2, 7)
	local yt2 = bit.arshift(y2, 7)

	local mapxstep, partial, ystep
	if xt2 > xt1 then
		mapxstep = 1
		partial = 1 - (x1 / 128 - math.floor(x1 / 128))
		ystep = (y2 - y1) / math.abs(x2 - x1)
	elseif xt2 < xt1 then
		mapxstep = -1
		partial = x1 / 128 - math.floor(x1 / 128)
		ystep = (y2 - y1) / math.abs(x2 - x1)
	else
		mapxstep = 0
		partial = 1
		ystep = 256
	end

	local yintercept = y1 / 128 + partial * ystep

	local mapystep, xstep
	if yt2 > yt1 then
		mapystep = 1
		partial = 1 - (y1 / 128 - math.floor(y1 / 128))
		xstep = (x2 - x1) / math.abs(y2 - y1)
	elseif yt2 < yt1 then
		mapystep = -1
		partial = y1 / 128 - math.floor(y1 / 128)
		xstep = (x2-x1) / math.abs(y2-y1)
	else
		mapystep = 0
		partial = 1
		xstep = 256
	end

	local xintercept = x1 / 128 + partial * xstep

	local mapx = xt1
	local mapy = yt1

	debug_blocks = {}

	for count = 1, 64 do
		debug_blocks[count] = {x = mapx, y = mapy}
		if tobool(bit.band(flags, PT_ADDLINES)) then
			if not P_BlockLinesIterator(mapx, mapy, PIT_AddLineIntercepts) then return false end
		end
		if tobool(bit.band(flags, PT_ADDTHINGS)) then
			--if not P_BlockThingsInterator(mapx, mapy, PIT_AddThingIntercepts) then return false end
		end
		if mapx == xt2 and mapy == yt2 then break end
		if math.floor(yintercept) == mapy then
			yintercept = yintercept + ystep
			mapx = mapx + mapxstep
		elseif math.floor(xintercept) == mapx then
			xintercept = xintercept + xstep
			mapy = mapy + mapystep
		end
	end
	return P_TraverseIntercepts(trav, 1)
end
