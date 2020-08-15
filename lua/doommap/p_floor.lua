local tobool = tobool

local Vector = Vector

local bit = bit
local math = math

setfenv( 1, DOOM )

SetConstant("FLOORSPEED", 1)

function T_MovePlane(sector, speed, dest, crush, floorOrCeiling, direction)
	speed = speed * HEIGHTCORRECTION
	local ent = tobool(floorOrCeiling) and sector.ceiling or sector.floor
	if not ent then return end
	local pos = ent:GetPos()
	local save = ent:GetSaveTable()
	if not ent.moving then
		ent:SetSaveValue("m_flMoveDoneTime", save.ltime + math.abs(dest - pos.z) / speed)
		ent:SetMoveType(MOVETYPE_PUSH)
		ent.moving = true
	end
	ent:SetLocalVelocity(Vector(0, 0, (speed * TICRATE) * direction))
	if direction == -1 and pos.z - speed <= dest or direction == 1 and pos.z >= dest then
		ent.moving = false
		pos.z = dest
		ent:SetSaveValue("m_flMoveDoneTime", -1)
		ent:SetLocalVelocity(Vector(0, 0, 0))
		ent:SetPos(pos)
		if floorOrCeiling == 0 then sector.floorheight = dest else sector.ceilingheight = dest end
		return pastdest
	end
	if ent.block_ent then
		local blocker = ent.block_ent
		ent.block_ent = nil
		local mobj = ToMobj(blocker)
		--hack to stop crushers from getting stuck on items
		if crush and mobj and mobj:HasFlag(MF_SPECIAL) then
			return pastdest
		end
		if mobj then
			if blocker:Health() <= 0 then
				mobj:SetState(S_GIBS)
				mobj:RemoveFlag(MF_SOLID)
				mobj.height = 0
				mobj.radius = 0
				return ok
			end
			if mobj:HasFlag(MF_DROPPED) then
				mobj:Remove()
				return ok
			end
			if not mobj:HasFlag(MF_SHOOTABLE) then
				return ok
			end
		end
		if crush and not tobool(bit.band(LevelTime(), 3)) then
			P_DamageEnt(blocker, ent, ent, 10)
			if blocker:IsPlayer() or blocker:IsNPC() then
				local pos = blocker:GetPos()
				pos.z = pos.z + blocker:OBBCenter().z
				SpawnBlood(pos, 10)
			end
		end

		return crushed
	end
	return ok
end

function T_MoveFloor(floor)
	local res = T_MovePlane(floor.sector, floor.speed, floor.floordestheight, floor.crush, 0, floor.direction)
	if not floor.sector.floor then return end
	if not tobool(bit.band(LevelTime(), 7)) then S_StartSound(floor.sector.floor, "sfx_stnmov") end
	if res == pastdest then
		floor.sector.specialdata = nil
		if floor.direction == 1 and floor.type == donutRaise then
			floor.sector.special = floor.newspecial
			Map:ChangeFloorTexture(floor.sector, floor.texture)
		end
		if floor.direction == -1 and floor.type == lowerAndChange then
			floor.sector.special = floor.newspecial
			Map:ChangeFloorTexture(floor.sector, floor.texture)
		end
		Map.thinkers[floor] = nil
		S_StartSound(floor.sector.floor, "sfx_pstop")
	end
end

local DoFloor_Type = {
	[lowerFloor] = function(floor)
		floor.direction = -1
		floor.speed = FLOORSPEED
		floor.floordestheight = P_FindHighestFloorSurrounding(floor.sector)
	end,
	[lowerFloorToLowest] = function(floor)
		floor.direction = -1
		floor.speed = FLOORSPEED
		floor.floordestheight = P_FindLowestFloorSurrounding(floor.sector)
	end,
	[turboLower] = function(floor)
		floor.direction = -1
		floor.speed = FLOORSPEED * 4
		local height = P_FindHighestFloorSurrounding(floor.sector)
		if height ~= floor.sector.floorheight then height = height + 8 end
		floor.floordestheight = height
	end,
	[raiseFloorCrush] = function(floor)
		floor.crush = true
		floor.direction = 1
		floor.speed = FLOORSPEED
		local height = P_FindLowestCeilingSurrounding(floor.sector)
		if height > floor.sector.ceilingheight then height = floor.sector.ceilingheight end
		floor.floordestheight = height - 8
	end,
	[raiseFloor] = function(floor)
		floor.direction = 1
		floor.speed = FLOORSPEED
		local height = P_FindLowestCeilingSurrounding(floor.sector)
		if height > floor.sector.ceilingheight then height = floor.sector.ceilingheight end
		floor.floordestheight = height
	end,
	[raiseFloorTurbo] = function(floor)
		floor.direction = 1
		floor.speed = FLOORSPEED * 4
		floor.floordestheight = P_FindNextHighestFloor(floor.sector, floor.sector.floorheight)
	end,
	[raiseFloorToNearest] = function(floor)
		floor.direction = 1
		floor.speed = FLOORSPEED
		floor.floordestheight = P_FindNextHighestFloor(floor.sector, floor.sector.floorheight)
	end,
	[raiseFloor24] = function(floor)
		floor.direction = 1
		floor.speed = FLOORSPEED
		floor.floordestheight = floor.sector.floorheight + 24 * HEIGHTCORRECTION
	end,
	[raiseFloor512] = function(floor)
		floor.direction = 1
		floor.speed = FLOORSPEED
		floor.floordestheight = floor.sector.floorheight + 512 * HEIGHTCORRECTION
	end,
	[raiseFloor24AndChange] = function(floor, line)
		floor.direction = 1
		floor.speed = FLOORSPEED
		floor.floordestheight = floor.sector.floorheight + 24 * HEIGHTCORRECTION
		Map:ChangeFloorTexture(floor.sector, line.frontsector.floorpic)
		floor.sector.special = line.frontsector.special
	end,
	[raiseToTexture] = function(floor)
		floor.direction = 1
		floor.speed = FLOORSPEED
		local minsize = 32767
		for i = 1, #floor.sector.lines do
			local line = floor.sector.lines[i]
			if tobool(bit.band(line.flags, ML_TWOSIDED)) then
				local texture = GetMapTexture(line.side[1].bottomtexture)
				if texture and texture.height < minsize then minsize = texture.height end
				texture = GetMapTexture(line.side[2].bottomtexture)
				if texture and texture.height < minsize then minsize = texture.height end
			end
		end
		floor.floordestheight = floor.sector.floorheight + minsize * HEIGHTCORRECTION
	end,
	[lowerAndChange] = function(floor, line)
		floor.direction = -1
	    floor.speed = FLOORSPEED
	    floor.floordestheight = P_FindLowestFloorSurrounding(floor.sector)
	    floor.texture = floor.sector.floorpic;
		for i = 1, #floor.sector.lines do
			local line = floor.sector.lines[i]
			if tobool(bit.band(line.flags, ML_TWOSIDED)) then
				local sec = line.side[1].sector
				if sec.id == floor.sector.id then sec = line.side[2].sector end
				if sec.floorheight == floor.floordestheight then
					floor.texture = sec.floorpic;
					floor.newspecial = sec.special;
				end
			end
		end
	end
}

function EV_DoFloor(line, floortype)
	local sec, floor
	local rtn = false
	for secnum in P_FindSectorFromLineTag(line) do
		sec = Map.Sectors[secnum]
		if sec.specialdata then continue end
		rtn = true
		floor = {}
		Map.thinkers[floor] = "T_MoveFloor"
		sec.specialdata = floor
		floor.Think = T_MoveFloor
		floor.type = floortype
		floor.crush = false
		floor.sector = sec
		local func = DoFloor_Type[floortype]
		if func then func(floor, line) end
	end
	return rtn
end

function EV_BuildStairs(line, type)
	local sec, tsec, floor
	rtn = false
	for secnum in P_FindSectorFromLineTag(line) do
		sec = Map.Sectors[secnum]
		if sec.specialdata then continue end
		rtn = true
		floor = {}
		Map.thinkers[floor] = "T_MoveFloor"
		sec.specialdata = floor
		floor.Think = T_MoveFloor
		floor.direction = 1
		floor.sector = sec
		local speed, stairsize, height
		if type == build8 then
			speed = FLOORSPEED / 4
			stairsize = 8 * HEIGHTCORRECTION
		end
		if type == turbo16 then
			speed = FLOORSPEED * 4
			stairsize = 16 * HEIGHTCORRECTION
		end
		floor.speed = speed
		height = sec.floorheight + stairsize
		floor.floordestheight = height

		local ok = true
		while ok do
			ok = false
			for i = 1, #sec.lines do
				ok = false
				local tline = sec.lines[i]
				if not tobool(bit.band(tline.flags, ML_TWOSIDED)) then continue end
				tsec = tline.frontsector
				if sec.id ~= tsec.id then continue end
				tsec = tline.backsector
				if tsec.floorpic ~= sec.floorpic then continue end
				height = height + stairsize
				if tsec.specialdata then continue end
				sec = tsec
				floor = {}
				Map.thinkers[floor] = "T_MoveFloor"
				sec.specialdata = floor
				floor.Think = T_MoveFloor
				floor.direction = 1
				floor.sector = sec
				floor.speed = speed
				floor.floordestheight = height
				ok = true
				break
			end
		end
	end
	return rtn
end
