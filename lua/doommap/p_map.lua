
local pairs = pairs
local tobool = tobool

local Vector = Vector

local bit = bit
local math = math
local table = table

setfenv( 1, DOOM )

SetConstant("USERANGE", 64)

local function GetBBox(ent, x, y)
	local thing = ToMobj(ent)
	if thing then
		return {top = y + thing.radius, bottom = y - thing.radius, right = x + thing.radius, left = x - thing.radius}
	else
		local lower, upper = ent:OBBMins(), ent:OBBMaxs()
		return {top = y + upper.y, bottom = y + lower.y, right = x + upper.x, left = x + lower.x}
	end
end

local tmbbox = {}
local tment
local tmthing

spechit = {}

function PIT_StompThing(ent)
	local thing = ToMobj(ent)
	if thing and thing:HasFlag(MF_CORPSE) then return true end -- Should probably go in P_BlockThingsIterator
	if not (ent:IsPlayer() or ent:IsNPC() or thing and tobool(bit.band(thing.flags, MF_SHOOTABLE))) then return true end
	local blockdist = (thing and thing.radius or ent:OBBMaxs().x) + (tmthing and tmthing.radius or tment:OBBMaxs().x)
	local pos = ent:GetPos()
	if math.abs(pos.x - tmx) >= blockdist or math.abs(pos.y - tmy) >= blockdist then return true end
	if ent:EntIndex() == tment:EntIndex() then return true end
	if not tment:IsPlayer() and Map.gamemap ~= 30 then return false end
	P_DamageEnt(ent, tment, tment, 10000)
	return true
end

function P_TeleportMove(ent, x, y)
	tment = ent
	tmthing = ToMobj(ent)
	tmflags = tmthing and tmthing.flags or 0

	tmx = x
	tmy = y

	tmbbox = GetBBox(ent, x, y)

	local newsubsec = Map:PointInSubsector(x, y)
	ceilingline = nil
	
	tmdropoffz = newsubsec.sector.floorheight
	tmfloorz = tmdropoffz
	tmceilingz = newsubsec.sector.ceilingheight
	
	validcount = validcount + 1
	for k, v in pairs(spechit) do spechit[k] = nil end
	--[[
	local Blockmap = Map.Blockmap
	local x1 = bit.arshift(tmbbox.left - Blockmap.bmaporgx - MAXRADIUS, 7)
	local xh = bit.arshift(tmbbox.right - Blockmap.bmaporgx + MAXRADIUS, 7)
	local y1 = bit.arshift(tmbbox.bottom - Blockmap.bmaporgy - MAXRADIUS, 7)
	local yh = bit.arshift(tmbbox.top - Blockmap.bmaporgy + MAXRADIUS, 7)
	for bx = x1, xh do
		for by = y1, yh do
			P_BlockThingsIterator(bx, by, PIT_StompThing)
		end
	end
	]]
	local dest = Vector(x, y, tmfloorz+0.5)
	local mins = ent:OBBMins()
	if not tActions.P_BlockThingsIterator(dest + mins, PIT_StompThing) then return false end
	
	--P_UnsetThingPosition(thing)

	--thing.floorz = tmfloorz
	--thing.ceilingz = tmceilingz
	if tmthing then tmthing:SetPos(dest) else ent:SetPos(dest) end
	
	--P_SetThingPosition(thing)
	
	return true
end

function PIT_CheckLine(ld)
	if tmbbox.right <= ld.bbox.left
	or tmbbox.left >= ld.bbox.right
	or tmbbox.top <= ld.bbox.bottom
	or tmbbox.bottom >= ld.bbox.top then
		return true
	end
	
	if P_BoxOnLineSide(tmbbox, ld) ~= -1 then return true end
	if not ld.backsector then return false end
	--[[
	if not tobool(bit.band(tmthing.flags, MF_MISSLE)) then
		if tobool(bit.band(ld.flags, ML_BLOCKING)) then return false end
		if not tmthing:IsPlayer() and tobool(bit.band(ld.flags, ML_BLOCKMONSTERS)) then return false end
	end
	--]]
	P_LineOpening(ld)
	if opentop < tmceilingz then tmceilingz = opentop ceilingline = ld end
	if openbottom > tmfloorz then tmfloorz = openbottom end
	if lowfloor < tmdropoffz then tmdropoffz = lowfloor end
	if ld.special ~= 0 then table.insert(spechit, ld) end
	return true
end

-- Debugging
tCheckPosition = {}

function P_CheckPosition(ent, x, y)
	do
		local pos = ent:GetPos()
		table.insert(tCheckPosition, {x1 = x, y1 = y, x2 = pos.x, y2 = pos.y})
		if #tCheckPosition > 128 then table.remove(tCheckPosition, 1) end
	end
	local thing = ToMobj(ent)
	tmthing = thing or ent
	if thing then tmflags = thing.flags end

	tmx = x
	tmy = y
	
	tmbbox = GetBBox(ent, x, y)

	local newsubsec = Map:PointInSubsector(x, y)
	ceilingline = nil
	
	tmdropoffz = newsubsec.sector.floorheight
	tmfloorz = tmdropoffz
	tmceilingz = newsubsec.sector.ceilingheight
	
	validcount = validcount + 1
	for k, v in pairs(spechit) do spechit[k] = nil end
	
	if thing and tobool(bit.band(tmflags, MF_NOCLIP)) then return true end
	
	local Blockmap = Map.Blockmap
	local x1 = bit.arshift(tmbbox.left - Blockmap.bmaporgx - MAXRADIUS, 7)
	local xh = bit.arshift(tmbbox.right - Blockmap.bmaporgx + MAXRADIUS, 7)
	local y1 = bit.arshift(tmbbox.bottom - Blockmap.bmaporgy - MAXRADIUS, 7)
	local yh = bit.arshift(tmbbox.top - Blockmap.bmaporgy + MAXRADIUS, 7)
	for bx = x1, xh do
		for by = y1, yh do
			--if not P_BlockThingsIterator(bx, by, PIT_CheckThing) then return false end
		end
	end
	
	x1 = bit.arshift(tmbbox.left - Blockmap.bmaporgx, 7)
	xh = bit.arshift(tmbbox.right - Blockmap.bmaporgx, 7)
	y1 = bit.arshift(tmbbox.bottom - Blockmap.bmaporgy, 7)
	yh = bit.arshift(tmbbox.top - Blockmap.bmaporgy, 7)
	for bx = x1, xh do
		for by = y1, yh do
			if not P_BlockLinesIterator(bx, by, PIT_CheckLine) then return false end
		end
	end
	return true
end

local usething

function PTR_UseTraverse(intercept)
	local line = intercept.d
	if line.special == 0 then
		P_LineOpening(line)
		if openrange <= 0 then
			S_StartSound(usething, "sfx_oof")
			return false
		end
		return true
	end
	
	local pos = usething:GetPos()
	local side = P_PointOnLineSide(pos.x, pos.y, line)
	P_UseSpecialLine(usething, line, side)
	return false
end

function P_UseLines(player)
	usething = player
	local dir = player:EyeAngles():Forward()
	dir.z = 0
	dir:Normalize()
	dir = dir * USERANGE
	local pos = player:GetPos()
	P_PathTraverse(pos.x, pos.y, pos.x + dir.x, pos.y + dir.y, PT_ADDLINES, PTR_UseTraverse )
	
end
