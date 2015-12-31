local tobool = tobool

local Vector = Vector

local bit = bit
local math = math

setfenv( 1, DOOM )

SetConstant("PLATWAIT", 3)
SetConstant("PLATSPEED", 1)

local PlatRaise_Remove = {
	[blazeDWUS] = true,
	[downWaitUpStay] = true,
	[raiseAndChange] = true,
	[raiseToNearestAndChange] = true
}

local PlatRaise_Status = {
	[up] = function(plat)
		local res = T_MovePlane(plat.sector, plat.speed, plat.high, plat.crush, 0, 1)
		if plat.type == raiseAndChange or plat.type == raiseToNearestAndChange then
			if not tobool(bit.band(LevelTime(), 7)) then S_StartSound(plat.sector.floor, "sfx_stnmov") end
		end
		if res == crushed and not plat.crush then
			plat.count = plat.wait
			plat.status = down
			S_StartSound(plat.sector.floor,"sfx_pstart")
		else
			if res == pastdest then
				plat.count = plat.wait
				plat.status = waiting
				S_StartSound(plat.sector.floor, "sfx_pstop")
				if PlatRaise_Remove[plat.type] then plat.sector.specialdata = nil Map.thinkers[plat] = nil end
			end
		end
	end,
	[down] = function(plat)
		local res = T_MovePlane(plat.sector, plat.speed, plat.low, false, 0, -1)
		if res == pastdest then
			plat.count = plat.wait
			plat.status = waiting
			S_StartSound(plat.sector.floor, "sfx_pstop")
		end
	end,
	[waiting] = function(plat)
		plat.count = plat.count - 1
		if plat.count == 0 then
			if math.abs(plat.sector.floor:GetPos().z - plat.low) < 0.1 then plat.status = up else plat.status = down end
			S_StartSound(plat.sector.floor,"sfx_pstart")
		end
	end,
	[in_stasis] = function(plat) plat.sector.floor:SetLocalVelocity(Vector(0, 0, 0)) end
}

function T_PlatRaise(plat)
	PlatRaise_Status[plat.status](plat)
end

local DoPlat_Type = {
	[raiseToNearestAndChange] = function(plat, line, amount)
		plat.speed = PLATSPEED/2
		Map:ChangeFloorTexture(plat.sector, line.frontsector.floorpic)
		plat.high = P_FindNextHighestFloor(plat.sector, plat.sector.floorheight)
		plat.wait = 0
		plat.status = up
		plat.sector.special = 0
		S_StartSound(plat.sector.floor, "sfx_stnmov")
	end,
	[raiseAndChange] = function(plat, line, amount)
		plat.speed = PLATSPEED/2
		Map:ChangeFloorTexture(plat.sector, line.frontsector.floorpic)
		plat.high = plat.sector.floorheight + amount
		plat.wait = 0
		plat.status = up
		S_StartSound(plat.sector.floor, "sfx_stnmov")
	end,
	[downWaitUpStay] = function(plat, line, amount)
		plat.speed = PLATSPEED * 4
		plat.low = P_FindLowestFloorSurrounding(plat.sector)
		if plat.low > plat.sector.floorheight then plat.low = plat.sector.floorheight end
		plat.high = plat.sector.floorheight
		plat.wait = 35*PLATWAIT
		plat.status = down
		S_StartSound(plat.sector.floor, "sfx_pstart")
	end,
	[blazeDWUS] = function(plat, line, amount)
		plat.speed = PLATSPEED * 8
		plat.low = P_FindLowestFloorSurrounding(plat.sector)
		if plat.low > plat.sector.floorheight then plat.low = plat.sector.floorheight end
		plat.high = plat.sector.floorheight
		plat.wait = 35*PLATWAIT
		plat.status = down
		S_StartSound(plat.sector.floor, "sfx_pstart")
	end,
	[perpetualRaise] = function(plat, line, amount)
		plat.speed = PLATSPEED
		plat.low = P_FindLowestFloorSurrounding(plat.sector)
		if plat.low > plat.sector.floorheight then plat.low = plat.sector.floorheight end
		plat.high = P_FindHighestFloorSurrounding(plat.sector)
		if plat.high < plat.sector.floorheight then plat.high = plat.sector.floorheight end
		plat.wait = 35*PLATWAIT;
		plat.status = bit.band(P_Random(), 1)
		S_StartSound(plat.sector.floor, "sfx_pstart")
	end
}

function EV_DoPlat(line, type, amount)
	local plat, sec
	local rtn = false
	if type == perpetualRaise then P_ActivateInStasis(line) end
	for secnum in P_FindSectorFromLineTag(line) do
		sec = Map.Sectors[secnum]
		if not sec.floor then continue end
		if sec.specialdata then continue end
		rtn = true
		plat = {}
		Map.thinkers[plat] = true
		plat.type = type
		plat.sector = sec
		sec.specialdata = plat
		plat.Think = T_PlatRaise
		plat.crush = false
		plat.tag = line.tag
		DoPlat_Type[type](plat, line, amount)
	end
	return rtn
end

-- Changed this a bit to avoid maintaining a list of active platforms
function P_ActivateInStasis(line)
	for secnum in P_FindSectorFromLineTag(line) do
		local plat = Map.Sectors[secnum].specialdata
		if not plat then continue end
		if plat.status == in_stasis then
			plat.status = plat.oldstatus
		end
	end
end

function EV_StopPlat(line)
	for secnum in P_FindSectorFromLineTag(line) do
		local plat = Map.Sectors[secnum].specialdata
		if not plat then continue end
		if plat.status ~= in_stasis then
			plat.oldstatus = plat.status
			plat.status = in_stasis
		end
	end
end

