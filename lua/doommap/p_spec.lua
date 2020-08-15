
include("p_ceilng.lua")
include("p_doors.lua")
include("p_floor.lua")
include("p_lights.lua")
include("p_plats.lua")
include("p_switch.lua")
include("p_telept.lua")

local tobool = tobool

local bit = bit
local math = math

setfenv( 1, DOOM )

function S_StartSound( ent, name )
	local sound = "DOOM." .. name
	if ( ent.LastSound ) then
		ent:StopSound( ent.LastSound )
	end
	ent.LastSound = sound
	ent:EmitSound( sound )
end

function getNextSector(line, sec)
	if not bit.band(line.flags, ML_TWOSIDED) then return end
	if line.frontsector.id == sec.id then return line.backsector end
	return line.frontsector
end

function P_FindLowestFloorSurrounding(sec)
	local check, other
	local floor = sec.floorheight

	for i = 1, #sec.lines do
		check = sec.lines[i]
		other = getNextSector(check, sec)

		if not other then continue end
		if other.floorheight < floor then floor = other.floorheight end
	end
	return floor
end

function P_FindHighestFloorSurrounding(sec)
	local check, other
	local floor = -500

	for i = 1, #sec.lines do
		check = sec.lines[i]
		other = getNextSector(check, sec)

		if not other then continue end
		if other.floorheight > floor then floor = other.floorheight end
	end
	return floor
end

function P_FindNextHighestFloor(sec, currentheight)
	local check, other
	local height = currentheight
	local heightlist = {}

	local h = 1
	for i = 1, #sec.lines do
		check = sec.lines[i]
		other = getNextSector(check, sec)

		if not other then continue end
		if other.floorheight > height then
			heightlist[h] = other.floorheight
			h = h + 1
		end
	end
	if h == 1 then return currentheight end

	local min = heightlist[1]
	for i = 2, #heightlist do
		if heightlist[i] < min then min = heightlist[i] end
	end
	return min
end

function P_FindLowestCeilingSurrounding(sec)
	local check, other
	local height = 32767

	for i = 1, #sec.lines do
		check = sec.lines[i]
		other = getNextSector(check, sec)

		if not other then continue end
		if other.ceilingheight < height then height = other.ceilingheight end
	end
	return height;
end

function P_FindHighestCeilingSurrounding(sec)
	local check, other
	local height = 0

	for i = 1, #sec.lines do
		check = sec.lines[i]
		other = getNextSector(check, sec)

		if not other then continue end
		if other.ceilingheight > height then height = other.ceilingheight end
	end
	return height;
end

-- changed this function so that it can be used in a generic for loop
function P_FindSectorFromLineTag(line)
	local start = 0
	return function()
		for i = start + 1, Map.Sectors.n do
			start = i
			if Map.Sectors[i].tag == line.tag then return i end
		end
	end
end

function P_FindMinSurroundingLight(sec, max)
	local line, check
	local min = max
	for i = 1, #sec.lines do
		line = sec.lines[i]
		check = getNextSector(line, sec)
		if not check then continue end
		if check.lightlevel < min then min = check.lightlevel end
	end
	return min
end

local CrossSpecialLine_Excludes = {
	[MT_ROCKET] = true,
	[MT_PLASMA] = true,
	[MT_BFG] = true,
	[MT_TROOPSHOT] = true,
	[MT_HEADSHOT] = true,
	[MT_BRUISERSHOT] = true
}

local CrossSpecialLine_MonsterActivated = {
	[39] = true,
	[97] = true,
	[125] = true,
	[126] = true,
	[4] = true,
	[10] = true,
	[88] = true
}

local CrossSpecialLine_Action = {
	[2] = function(line,side,thing) EV_DoDoor(line,open) line.special = 0 end,
	[3] = function(line,side,thing) EV_DoDoor(line,close) line.special = 0 end,
	[4] = function(line,side,thing) EV_DoDoor(line,normal) line.special = 0 end,
	[5] = function(line,side,thing) EV_DoFloor(line,raiseFloor) line.special = 0 end,
	[6] = function(line,side,thing) EV_DoCeiling(line,fastCrushAndRaise) line.special = 0 end,
	[8] = function(line,side,thing) EV_BuildStairs(line,build8) line.special = 0 end,
	[10] = function(line,side,thing) EV_DoPlat(line,downWaitUpStay,0) line.special = 0 end,
	[12] = function(line,side,thing) EV_LightTurnOn(line,0) line.special = 0 end,
	[13] = function(line,side,thing) EV_LightTurnOn(line,255) line.special = 0 end,
	[16] = function(line,side,thing) EV_DoDoor(line,close30ThenOpen) line.special = 0 end,
	[17] = function(line,side,thing) EV_StartLightStrobing(line) line.special = 0 end,
	[19] = function(line,side,thing) EV_DoFloor(line,lowerFloor) line.special = 0 end,
	[22] = function(line,side,thing) EV_DoPlat(line,raiseToNearestAndChange,0) line.special = 0 end,
	[25] = function(line,side,thing) EV_DoCeiling(line,crushAndRaise) line.special = 0 end,
	[30] = function(line,side,thing) EV_DoFloor(line,raiseToTexture) line.special = 0 end,
	[35] = function(line,side,thing) EV_LightTurnOn(line,35) line.special = 0 end,
	[36] = function(line,side,thing) EV_DoFloor(line,turboLower) line.special = 0 end,
	[37] = function(line,side,thing) EV_DoFloor(line,lowerAndChange) line.special = 0 end,
	[38] = function(line,side,thing) EV_DoFloor(line,lowerFloorToLowest) line.special = 0 end,
	[39] = function(line,side,thing) EV_Teleport(line,side,thing) line.special = 0 end,
	[40] = function(line,side,thing) EV_DoCeiling(line,raiseToHighest) EV_DoFloor( line, lowerFloorToLowest ) line.special = 0 end,
	[44] = function(line,side,thing) EV_DoCeiling(line,lowerAndCrush) line.special = 0 end,
	[52] = function(line,side,thing) G_ExitLevel() end,
	[53] = function(line,side,thing) EV_DoPlat(line,perpetualRaise,0) line.special = 0 end,
	[54] = function(line,side,thing) EV_StopPlat(line) line.special = 0 end,
	[56] = function(line,side,thing) EV_DoFloor(line,raiseFloorCrush) line.special = 0 end,
	[57] = function(line,side,thing) EV_CeilingCrushStop(line) line.special = 0 end,
	[58] = function(line,side,thing) EV_DoFloor(line,raiseFloor24) line.special = 0 end,
	[59] = function(line,side,thing) EV_DoFloor(line,raiseFloor24AndChange) line.special = 0 end,
	[104] = function(line,side,thing) EV_TurnTagLightsOff(line) line.special = 0 end,
	[108] = function(line,side,thing) EV_DoDoor (line,blazeRaise) line.special = 0 end,
	[109] = function(line,side,thing) EV_DoDoor (line,blazeOpen) line.special = 0 end,
	[100] = function(line,side,thing) EV_BuildStairs(line,turbo16) line.special = 0 end,
	[110] = function(line,side,thing) EV_DoDoor (line,blazeClose) line.special = 0 end,
	[119] = function(line,side,thing) EV_DoFloor(line,raiseFloorToNearest) line.special = 0 end,
	[121] = function(line,side,thing) EV_DoPlat(line,blazeDWUS,0) line.special = 0 end,
	[124] = function(line,side,thing) G_SecretExitLevel() end,
	[125] = function(line,side,thing) if not thing:IsPlayer() then EV_Teleport(line,side,thing) line.special = 0 end end,
	[130] = function(line,side,thing) EV_DoFloor(line,raiseFloorTurbo) line.special = 0 end,
	[141] = function(line,side,thing) EV_DoCeiling(line,silentCrushAndRaise) line.special = 0 end,
	[72] = function(line,side,thing) EV_DoCeiling(line,lowerAndCrush) end,
	[73] = function(line,side,thing) EV_DoCeiling(line,crushAndRaise) end,
	[74] = function(line,side,thing) EV_CeilingCrushStop(line) end,
	[75] = function(line,side,thing) EV_DoDoor(line,close) end,
	[76] = function(line,side,thing) EV_DoDoor(line,close30ThenOpen) end,
	[77] = function(line,side,thing) EV_DoCeiling(line,fastCrushAndRaise) end,
	[79] = function(line,side,thing) EV_LightTurnOn(line,35) end,
	[80] = function(line,side,thing) EV_LightTurnOn(line,0) end,
	[81] = function(line,side,thing) EV_LightTurnOn(line,255) end,
	[82] = function(line,side,thing) EV_DoFloor(line,lowerFloorToLowest) end,
	[83] = function(line,side,thing) EV_DoFloor(line,lowerFloor) end,
	[84] = function(line,side,thing) EV_DoFloor(line,lowerAndChange) end,
	[86] = function(line,side,thing) EV_DoDoor(line,open) end,
	[87] = function(line,side,thing) EV_DoPlat(line,perpetualRaise,0) end,
	[88] = function(line,side,thing) EV_DoPlat(line,downWaitUpStay,0) end,
	[89] = function(line,side,thing) EV_StopPlat(line) end,
	[90] = function(line,side,thing) EV_DoDoor(line,normal) end,
	[91] = function(line,side,thing) EV_DoFloor(line,raiseFloor) end,
	[92] = function(line,side,thing) EV_DoFloor(line,raiseFloor24) end,
	[93] = function(line,side,thing) EV_DoFloor(line,raiseFloor24AndChange) end,
	[94] = function(line,side,thing) EV_DoFloor(line,raiseFloorCrush) end,
	[95] = function(line,side,thing) EV_DoPlat(line,raiseToNearestAndChange,0) end,
	[96] = function(line,side,thing) EV_DoFloor(line,raiseToTexture) end,
	[97] = function(line,side,thing) EV_Teleport(line,side,thing) end,
	[98] = function(line,side,thing) EV_DoFloor(line,turboLower) end,
	[105] = function(line,side,thing) EV_DoDoor (line,blazeRaise) end,
	[106] = function(line,side,thing) EV_DoDoor (line,blazeOpen) end,
	[107] = function(line,side,thing) EV_DoDoor (line,blazeClose) end,
	[120] = function(line,side,thing) EV_DoPlat(line,blazeDWUS,0) end,
	[126] = function(line,side,thing) if not thing:IsPlayer() then EV_Teleport(line,side,thing) end end,
	[128] = function(line,side,thing) EV_DoFloor(line,raiseFloorToNearest) end,
	[129] = function(line,side,thing) EV_DoFloor(line,raiseFloorTurbo) end
}

function P_CrossSpecialLine(linenum, side, thing)
	local line = Map.Linedefs[linenum]
	if not thing:IsPlayer() then
		if CrossSpecialLine_Excludes[thing.type] then return end
		if not CrossSpecialLine_MonsterActivated[line.special] then return end
	end
	local func = CrossSpecialLine_Action[line.special]
	if func then func(line, side, thing) end
end

local ShootSpecialLine_Action = {
	[24] = function(line) EV_DoFloor(line,raiseFloor) P_ChangeSwitchTexture(line,0) end,
	[46] = function(line) EV_DoDoor(line,open) P_ChangeSwitchTexture(line,1) end,
	[47] = function(line) EV_DoPlat(line,raiseToNearestAndChange,0) P_ChangeSwitchTexture(line,0) end
}

function P_ShootSpecialLine(thing, line)
	if not thing:IsPlayer() and line.special ~= 46 then return end
	local func = ShootSpecialLine_Action[line.special]
	if func then func(line) end
end

local PlayerInSpecialSector_Type = {
	[5] = function(player, sector)
		if not player:HasPower(pw_ironfeet) and not tobool(bit.band(LevelTime(), 31)) then
			P_DamageEnt(player, sector.floor, sector.floor, 10)
		end
	end,
	[7] = function(player, sector)
		if not player:HasPower(pw_ironfeet) and not tobool(bit.band(LevelTime(), 31)) then
			P_DamageEnt(player, sector.floor, sector.floor, 5)
		end
	end,
	[16] = function(player, sector)
		if (not player:HasPower(pw_ironfeet) or P_Random() < 5) and not tobool(bit.band(LevelTime(), 31)) then
			P_DamageEnt(player, sector.floor, sector.floor, 20)
		end
	end,
	[9] = function(player, sector)
		-- TODO: use secret sectors
	end,
	[11] = function(player, sector)
		player:ToEntity():GodDisable()
		if not tobool(bit.band(LevelTime(), 31)) then
			P_DamageEnt(player, sector.floor, sector.floor, 20)
		end
		if player:Health() < 10 then --[[G_ExitLevel()]] end
	end
}

PlayerInSpecialSector_Type[4] = PlayerInSpecialSector_Type[16]

function P_PlayerInSpecialSector(player)
	local xplayer = GetPlayerInfo(player)
	local pos = player:GetPos()
	local sector = player.subsector.sector
	if math.abs(pos.z - sector.floorheight) > 0.2 then return end
	PlayerInSpecialSector_Type[sector.special](xplayer, sector)
end

function EV_DoDonut(line)
	local s1, s2, s3
	local rtn = false
	for secnum in P_FindSectorFromLineTag(line) do
		s1 = Map.Sectors[secnum]
		-- ALREADY MOVING?  IF SO, KEEP GOING...
		if s1.specialdata then continue end
		rtn = true
		s2 = getNextSector(s1.lines[1], s1)
		for i = 1, #s2.lines do
			if not tobool(bit.band(s2.lines[i].flags, ML_TWOSIDED)) or s2.lines[i].backsector.id == s1.id then continue end
			s3 = s2.lines[i].backsector

			-- Spawn rising slime
			local floor = {}
			Map.thinkers[floor] = "T_MoveFloor"
			s2.specialdata = floor
			floor.Think = T_MoveFloor
			floor.type = donutRaise
			floor.crush = false
			floor.direction = 1
			floor.sector = s2
			floor.speed = FLOORSPEED / 2
			floor.texture = s3.floorpic
			floor.newspecial = 0
			floor.floordestheight = s3.floorheight

			-- Spawn lowering donut-hole
			floor = {}
			Map.thinkers[floor] = "T_MoveFloor"
			s1.specialdata = floor
			floor.Think = T_MoveFloor
			floor.type = lowerFloor
			floor.crush = false
			floor.direction = -1
			floor.sector = s1
			floor.speed = FLOORSPEED / 2
			floor.floordestheight = s3.floorheight
		end
	end
	return rtn
end

local SpawnSpecials_Action = {
	[1] = function(sector) P_SpawnLightFlash(sector) end,
	[2] = function(sector) P_SpawnStrobeFlash(sector,FASTDARK,0) end,
	[3] = function(sector) P_SpawnStrobeFlash(sector,SLOWDARK,0) end,
	[4] = function(sector) P_SpawnStrobeFlash(sector,FASTDARK,0) sector.special = 4 end,
	[8] = function(sector) P_SpawnGlowingLight(sector) end,
	--[9] = function(sector) Map.totalsecret = Map.totalsecret + 1 end,
	[10] = function(sector) P_SpawnDoorCloseIn30(sector) end,
	[12] = function(sector) P_SpawnStrobeFlash(sector,SLOWDARK,1) end,
	[13] = function(sector) P_SpawnStrobeFlash(sector,FASTDARK,1) end,
	[14] = function(sector) P_SpawnDoorRaiseIn5Mins(sector,sector.id) end,
	[17] = function(sector) P_SpawnFireFlicker(sector) end
}

function P_SpawnSpecials()
	for i = 1, Map.Sectors.n do
		local sector = Map.Sectors[i]
		if sector.special == 0 then continue end
		local func = SpawnSpecials_Action[sector.special]
		if func then func(sector) end
	end
end
