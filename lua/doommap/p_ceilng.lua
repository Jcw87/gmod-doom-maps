local tobool = tobool

local Vector = Vector

local bit = bit

setfenv( 1, DOOM )

SetConstant("CEILSPEED", 1)

local MoveCeiling_Up = {
	[raiseToHighest] = function(ceiling) ceiling.sector.specialdata = nil Map.thinkers[ceiling] = nil end,
	[silentCrushAndRaise] = function(ceiling) S_StartSound(ceiling.sector.ceiling, "sfx_pstop") ceiling.direction = -1 end,
	[fastCrushAndRaise] = function(ceiling) ceiling.direction = -1 end
}

MoveCeiling_Up[crushAndRaise] = MoveCeiling_Up[fastCrushAndRaise]

local MoveCeiling_Down = {
	[silentCrushAndRaise] = function(ceiling) S_StartSound(ceiling.sector.ceiling, "sfx_pstop") ceiling.speed = CEILSPEED ceiling.direction = 1 end,
	[crushAndRaise] = function(ceiling) ceiling.speed = CEILSPEED ceiling.direction = 1 end,
	[fastCrushAndRaise] = function(ceiling) ceiling.direction = 1 end,
	[lowerAndCrush] = function(ceiling) ceiling.sector.specialdata = nil Map.thinkers[ceiling] = nil end
}

MoveCeiling_Down[lowerToFloor] = MoveCeiling_Down[lowerAndCrush]

local MoveCeiling_SlowCrush = {
	[silentCrushAndRaise] = true,
	[crushAndRaise] = true,
	[lowerAndCrush] = true
}

local MoveCeiling_Direction = {
	[0] = function(ceiling) ceiling.sector.ceiling:SetLocalVelocity(Vector(0, 0, 0)) end, -- IN STASIS
	[1] = function(ceiling)
		-- UP
		local res = T_MovePlane(ceiling.sector, ceiling.speed, ceiling.topheight, false, 1, ceiling.direction)
		if tobool(bit.band(LevelTime(), 7)) and ceiling.type ~= silentCrushAndRaise then
			S_StartSound(ceiling.sector.ceiling, "sfx_stnmov")
		end
		if res == pastdest then
			local func = MoveCeiling_Up[ceiling.type]
			if func then func(ceiling) end
		end
	end,
	[-1] = function(ceiling)
		-- DOWN
		local res = T_MovePlane(ceiling.sector, ceiling.speed, ceiling.bottomheight, ceiling.crush, 1, ceiling.direction)
		if tobool(bit.band(LevelTime(), 7)) and ceiling.type ~= silentCrushAndRaise then
			S_StartSound(ceiling.sector.ceiling, "sfx_stnmov")
		end
		if res == pastdest then
			local func = MoveCeiling_Down[ceiling.type]
			if func then func(ceiling) end
		elseif res == crush and MoveCeiling_SlowCrush[ceiling.type] then
			ceiling.speed = CEILSPEED / 8
		end
	end
}

function T_MoveCeiling(ceiling)
	MoveCeiling_Direction[ceiling.direction](ceiling)
end

local DoCeiling_Reactivate = {
	[fastCrushAndRaise] = true,
	[silentCrushAndRaise] = true,
	[crushAndRaise] = true
}

local DoCeiling_Type = {
	[fastCrushAndRaise] = function(ceiling)
		ceiling.crush = true
	    ceiling.topheight = ceiling.sector.ceilingheight
	    ceiling.bottomheight = ceiling.sector.floorheight + 8 * HEIGHTCORRECTION
	    ceiling.speed = CEILSPEED * 2
	end,
	[silentCrushAndRaise] = function(ceiling)
		ceiling.crush = true
	    ceiling.topheight = ceiling.sector.ceilingheight
		ceiling.bottomheight = ceiling.sector.floorheight + 8 * HEIGHTCORRECTION
	end,
	[lowerAndCrush] = function(ceiling)
		ceiling.bottomheight = ceiling.sector.floorheight + 8 * HEIGHTCORRECTION
	end,
	[lowerToFloor] = function(ceiling)
		ceiling.bottomheight = ceiling.sector.floorheight
	end,
	[raiseToHighest] = function(ceiling)
		ceiling.topheight = P_FindHighestCeilingSurrounding(ceiling.sector)
	    ceiling.direction = 1
	end
}

DoCeiling_Type[crushAndRaise] = DoCeiling_Type[silentCrushAndRaise]

function EV_DoCeiling(line, type)
	local sec, ceiling
	local rtn = false
	if DoCeiling_Reactivate[type] then P_ActivateInStasisCeiling(line) end
	for secnum in P_FindSectorFromLineTag(line) do
		sec = Map.Sectors[secnum]
		if sec.specialdata then continue end
		rtn = true
		ceiling = {}
		Map.thinkers[ceiling] = "T_MoveCeiling"
		sec.specialdata = ceiling
		ceiling.Think = T_MoveCeiling
		ceiling.sector = sec
		ceiling.crush = false
		ceiling.direction = -1
		ceiling.speed = CEILSPEED
		DoCeiling_Type[type](ceiling)
		ceiling.tag = sec.tag
		ceiling.type = type
	end
	return rtn
end

function P_ActivateInStasisCeiling(line)
	for secnum in P_FindSectorFromLineTag(line) do
		local ceiling = Map.Sectors[secnum].specialdata
		if not ceiling then continue end
		if ceiling.direction == 0 then
			ceiling.direction = ceiling.olddirection
		end
	end
end

function EV_CeilingCrushStop(line)
	rtn = false
	for secnum in P_FindSectorFromLineTag(line) do
		local ceiling = Map.Sectors[secnum].specialdata
		if not ceiling then continue end
		if ceiling.direction ~= 0 then
			ceiling.olddirection = ceiling.direction
			ceiling.direction = 0
			rtn = true
		end
	end
	return rtn
end