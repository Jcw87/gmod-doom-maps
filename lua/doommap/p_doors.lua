
local math = math

setfenv( 1, DOOM )

SetConstant("VDOORSPEED", 2)
SetConstant("VDOORWAIT", 150)

local VerticalDoor_Waiting = {
	[blazeRaise] = function(door) door.direction = -1 S_StartSound(door.sector.ceiling, "sfx_bdcls") end,
	[normal] = function(door) door.direction = -1 S_StartSound(door.sector.ceiling, "sfx_dorcls") end,
	[close30ThenOpen] = function(door) door.direction = 1 S_StartSound(door.sector.ceiling, "sfx_doropn") end
}

local VerticalDoor_Down1 = {
	[blazeRaise] = function(door) door.sector.specialdata = nil Map.thinkers[door] = nil S_StartSound(door.sector.ceiling, "sfx_bdcls") end,
	[normal] = function(door) door.sector.specialdata = nil Map.thinkers[door] = nil end,
	[close30ThenOpen] = function(door) door.direction = 0 door.topcountdown = 35*30 end
}

VerticalDoor_Down1[blazeClose] = VerticalDoor_Down1[blazeRaise]
VerticalDoor_Down1[close] = VerticalDoor_Down1[normal]

local VerticalDoor_Down2 = {
	[blazeClose] = true,
	[close] = true
}

local VerticalDoor_Up = {
	[blazeRaise] = function(door) door.direction = 0 door.topcountdown = door.topwait end,
	[close30ThenOpen] = function(door) door.sector.specialdata = nil Map.thinkers[door] = nil end,
}

VerticalDoor_Up[normal] = VerticalDoor_Up[blazeRaise]
VerticalDoor_Up[blazeOpen] = VerticalDoor_Up[close30ThenOpen]
VerticalDoor_Up[open] = VerticalDoor_Up[close30ThenOpen]

local VerticalDoor_Direction = {
	[0] = function(door)
		--WAITING
		door.topcountdown = door.topcountdown - 1
		if door.topcountdown == 0 then
			local func = VerticalDoor_Waiting[door.type]
			if func then func(door) end
		end
	end,
	[2] = function(door)
		-- INITIAL WAIT
		door.topcountdown = door.topcountdown - 1
		if door.topcountdown == 0 then
			if door.type == raiseIn5Mins then
				door.direction = 1
				door.type = normal
				S_StartSound(door.sector.ceiling, "sfx_doropn")
			end
		end
	end,
	[-1] = function(door)
		-- DOWN
		local res = T_MovePlane(door.sector, door.speed, door.sector.floorheight, false, 1, door.direction)
		
		if res == pastdest then
			local func = VerticalDoor_Down1[door.type]
			if func then func(door) end
		elseif res == crushed then
			if not VerticalDoor_Down2[door.type] then
				door.direction = 1
				S_StartSound(door.sector.ceiling, "sfx_doropn")
			end
		end
	end,
	[1] = function(door)
		-- UP
		local res = T_MovePlane(door.sector, door.speed, door.topheight, false, 1, door.direction)
		if res == pastdest then
			local func = VerticalDoor_Up[door.type]
			if func then func(door) end
		end
	end
}

function T_VerticalDoor(door)
	local func = VerticalDoor_Direction[door.direction]
	if func then func(door) end
end

local Keys = {
	[26] = {card = it_bluecard, message = "PD_BLUEK"},
	[27] = {card = it_yellowcard, message = "PD_YELLOWK"},
	[28] = {card = it_redcard, message = "PD_REDK"},
	[99] = {card = it_bluecard, message = "PD_BLUEO"},
	[134] = {card = it_redcard, message = "PD_REDO"},
	[136] = {card = it_yellowcard, message = "PD_YELLOWO"},
}

Keys[32] = Keys[26]
Keys[33] = Keys[28]
Keys[34] = Keys[27]
Keys[133] = Keys[99]
Keys[135] = Keys[134]
Keys[137] = Keys[136]

function EV_DoLockedDoor(line, type, thing)
	local ent = ToEntity(thing)
	if not ent or not ent:IsPlayer() then return 0 end
	local p = GetPlayerInfo(ent)
	local key = Keys[line.special]
	if not p:HasCard(key.card, true) then
		p:SendMessage(key.message)
		S_StartSound(thing, "sfx_oof")
		return false
	end
	
	return EV_DoDoor(line, type)
end

local DoDoor_Type = {
	[blazeClose] = function(door)
		door.topheight = P_FindLowestCeilingSurrounding(door.sector) - 4 * HEIGHTCORRECTION
		door.direction = -1
		door.speed = VDOORSPEED * 4
		S_StartSound(door.sector.ceiling, "sfx_bdcls")
	end,
	[close] = function(door)
		door.topheight = P_FindLowestCeilingSurrounding(door.sector) - 4 * HEIGHTCORRECTION
		door.direction = -1
		S_StartSound(door.sector.ceiling, "sfx_dorcls")
	end,
	[close30ThenOpen] = function(door)
		door.topheight = door.sector.ceilingheight
		door.direction = -1
		S_StartSound(door.sector.ceiling, "sfx_dorcls")
	end,
	[blazeRaise] = function(door)
		door.topheight = P_FindLowestCeilingSurrounding(door.sector) - 4 * HEIGHTCORRECTION
		door.direction = 1
		door.speed = VDOORSPEED * 4
		if math.abs(door.topheight - door.sector.ceilingheight) > 0.1 then S_StartSound(door.sector.ceiling, "sfx_bdopn") end
	end,
	[normal] = function(door)
		door.topheight = P_FindLowestCeilingSurrounding(door.sector) - 4 * HEIGHTCORRECTION
		door.direction = 1
		if math.abs(door.topheight - door.sector.ceilingheight) > 0.1 then S_StartSound(door.sector.ceiling, "sfx_doropn") end
	end
}

DoDoor_Type[blazeOpen] = DoDoor_Type[blazeRaise]
DoDoor_Type[open] = DoDoor_Type[normal]

function EV_DoDoor(line, type)
	local sec, door
	local rtn = false
	for secnum in P_FindSectorFromLineTag(line) do
		sec = Map.Sectors[secnum]
		if not sec.ceiling then continue end
		if sec.specialdata then continue end
		rtn = true
		door = {}
		Map.thinkers[door] = true
		sec.specialdata = door
		door.Think = T_VerticalDoor
		door.sector = sec
		door.type = type
		door.topwait = VDOORWAIT
		door.speed = VDOORSPEED
		local func = DoDoor_Type[type]
		if func then func(door) end
	end
	return rtn
end

local VerticalDoor_Raise = {
	[1] = true,
	[26] = true,
	[27] = true,
	[28] = true,
	[117] = true
}

local VerticalDoor_Blaze = {
	[117] = true,
	[118] = true
}

local VerticalDoor_Type = {
	[1] = normal,
	[26] = normal,
	[27] = normal,
	[28] = normal,
	[31] = open,
	[32] = open,
	[33] = open,
	[34] = open,
	[117] = blazeRaise,
	[118] = blazeOpen
}

function EV_VerticalDoor(line, thing)
	local player, sec, door
	local ent = ToEntity(thing)
	if ent:IsPlayer() then player = GetPlayerInfo(ent) end
	local key = Keys[line.special]
	if key then 
		if not player then return end
		if not player:HasCard(key.card, true) then
			player:SendMessage(key.message)
			S_StartSound(thing, "sfx_oof")
			return false
		end
	end
	
	-- If a VerticalDoor was activated on a single sided linedef, the game crashed.
	-- This can be illustrated in MAP06: The Crusher
	if not line.sidenum[2] then
		if player then ent:ChatPrint("Fun fact: That wall you just used would have crashed Doom.") end
		return
	end
	sec = line.sidenum[2].sector
	if not sec.ceiling then return end
	if sec.specialdata then
		door = sec.specialdata
		if VerticalDoor_Raise[line.special] then
			if door.direction == -1 then
				door.direction = 1
			else
				if not player then return end
				door.direction = -1
			end
			return
		end
	end
	
	if VerticalDoor_Blaze[line.special] then
		S_StartSound(sec.ceiling, "sfx_bdopn")
	else
		S_StartSound(sec.ceiling, "sfx_doropn")
	end
	
	door = {}
	Map.thinkers[door] = true
	sec.specialdata = door
	door.Think = T_VerticalDoor
	door.sector = sec
	door.direction = 1
	door.speed = VDOORSPEED
	door.topwait = VDOORWAIT
	door.type = VerticalDoor_Type[line.special]
	if door.type == open then line.special = 0 end
	if door.type == blazeRaise then door.speed = VDOORSPEED*4 end
	if door.type == blazeOpen then door.speed = VDOORSPEED*4 line.special = 0 end
	door.topheight = P_FindLowestCeilingSurrounding(sec) - 4 * HEIGHTCORRECTION
end

function P_SpawnDoorCloseIn30(sec)
	local door = {}
	Map.thinkers[door] = true
	sec.specialdata = door
	sec.special = 0
	door.Think = T_VerticalDoor
	door.sector = sec
	door.direction = 0
	door.type = normal
	door.speed = VDOORSPEED
	door.topcountdown = 30 * 35
end

function P_SpawnDoorRaiseIn5Mins(sec, secnum)
	local door = {}
	Map.thinkers[door] = true
	sec.specialdata = door
	sec.special = 0
	door.Think = T_VerticalDoor
	door.sector = sec
	door.direction = 2
	door.type = raiseIn5Mins
	door.speed = VDOORSPEED
	door.topheight = P_FindLowestCeilingSurrounding(sec) - 4 * HEIGHTCORRECTION
	door.topwait = VDOORWAIT
	door.topcountdown = 5 * 60 * 35
end
