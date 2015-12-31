AddCSLuaFile()

local ipairs = ipairs
local tobool = tobool

local bit = bit
local math = math

setfenv( 1, DOOM )

local LinedefSpecials = {
	[1] = {door = true, type = normal, man = true},
	[2] = {door = true, type = open},
	[3] = {door = true, type = close},
	[4] = {door = true, type = normal},
	[5] = {floor = true, type = raiseFloor},
	[6] = {ceil = true, type = fastCrushAndRaise},
	[7] = {stair = true, type = build8},
	[8] = {stair = true, type = build8},
	[10] = {plat = true, type = downWaitUpStay},
	[14] = {plat = true, type = raiseAndChange},
	[15] = {plat = true, type = raiseAndChange},
	[16] = {door = true, type = close30ThenOpen},
	[18] = {floor = true, type = raiseFloorToNearest},
	[19] = {floor = true, type = lowerFloor},
	[20] = {plat = true, type = raiseToNearestAndChange},
	[21] = {plat = true, type = downWaitUpStay},
	[22] = {plat = true, type = raiseToNearestAndChange},
	[23] = {floor = true, type = lowerFloorToLowest},
	[24] = {floor = true, type = raiseFloor},
	[26] = {door = true, type = normal, man = true},
	[27] = {door = true, type = normal, man = true},
	[28] = {door = true, type = normal, man = true},
	[29] = {door = true, type = normal},
	[30] = {floor = true, type = raiseToTexture},
	[31] = {door = true, type = open, man = true},
	[32] = {door = true, type = open, man = true},
	[33] = {door = true, type = open, man = true},
	[34] = {door = true, type = open, man = true},
	[36] = {floor = true, type = turboLower},
	[37] = {floor = true, type = lowerAndChange},
	[38] = {floor = true, type = lowerFloorToLowest},
	[40] = {ceil = true, type = raiseToHighest},
	[41] = {ceil = true, type = lowerToFloor},
	[42] = {door = true, type = close},
	[43] = {ceil = true, type = lowerToFloor},
	[44] = {ceil = true, type = lowerAndCrush},
	[45] = {floor = true, type = lowerFloor},
	[46] = {door = true, type = open},
	[47] = {plat = true, type = raiseToNearestAndChange},
	[49] = {ceil = true, type = crushAndRaise},
	[50] = {door = true, type = close},
	[53] = {plat = true, type = perpetualRaise},
	[55] = {floor = true, type = raiseFloorCrush},
	[56] = {floor = true, type = raiseFloorCrush},
	[58] = {floor = true, type = raiseFloor24},
	[59] = {floor = true, type = raiseFloor24AndChange},
	[60] = {floor = true, type = lowerFloorToLowest},
	[61] = {door = true, type = open},
	[62] = {plat = true, type = downWaitUpStay},
	[63] = {door = true, type = normal},
	[64] = {floor = true, type = raiseFloor},
	[65] = {floor = true, type = raiseFloorCrush},
	[66] = {plat = true, type = raiseAndChange},
	[67] = {plat = true, type = raiseAndChange},
	[68] = {plat = true, type = raiseToNearestAndChange},
	[69] = {floor = true, type = raiseFloorToNearest},
	[70] = {floor = true, type = turboLower},
	[71] = {floor = true, type = turboLower},
	[72] = {ceil = true, type = lowerAndCrush},
	[73] = {ceil = true, type = lowerAndCrush},
	[75] = {door = true, type = close},
	[76] = {door = true, type = close30ThenOpen},
	[77] = {ceil = true, type = fastCrushAndRaise},
	[82] = {floor = true, type = lowerFloorToLowest},
	[83] = {floor = true, type = lowerFloor},
	[84] = {floor = true, type = lowerAndChange},
	[86] = {door = true, type = open},
	[87] = {plat = true, type = perpetualRaise},
	[88] = {plat = true, type = downWaitUpStay},
	[90] = {door = true, type = normal},
	[91] = {floor = true, type = raiseFloor},
	[92] = {floor = true, type = raiseFloor24},
	[93] = {floor = true, type = raiseFloor24AndChange},
	[94] = {floor = true, type = raiseFloorCrush},
	[95] = {plat = true, type = raiseToNearestAndChange},
	[96] = {floor = true, type = raiseToTexture},
	[98] = {floor = true, type = turboLower},
	[99] = {door = true, type = blazeOpen},
	[100] = {stair = true, type = turbo16},
	[101] = {floor = true, type = raiseFloor},
	[102] = {floor = true, type = lowerFloor},
	[103] = {door = true, type = open},
	[105] = {door = true, type = blazeRaise},
	[106] = {door = true, type = blazeOpen},
	[107] = {door = true, type = blazeClose},
	[108] = {door = true, type = blazeRaise},
	[109] = {door = true, type = blazeOpen},
	[110] = {door = true, type = blazeClose},
	[111] = {door = true, type = blazeRaise},
	[112] = {door = true, type = blazeOpen},
	[113] = {door = true, type = blazeClose},
	[114] = {door = true, type = blazeRaise},
	[115] = {door = true, type = blazeOpen},
	[116] = {door = true, type = blazeClose},
	[117] = {door = true, type = blazeRaise, man = true},
	[118] = {door = true, type = blazeOpen, man = true},
	[119] = {floor = true, type = raiseFloorToNearest},
	[120] = {plat = true, type = blazeDWUS},
	[121] = {plat = true, type = blazeDWUS},
	[122] = {plat = true, type = blazeDWUS},
	[123] = {plat = true, type = blazeDWUS},
	[127] = {stair = true, type = turbo16},
	[128] = {floor = true, type = raiseFloorToNearest},
	[129] = {floor = true, type = raiseFloorTurbo},
	[130] = {floor = true, type = raiseFloorTurbo},
	[131] = {floor = true, type = raiseFloorTurbo},
	[132] = {floor = true, type = raiseFloorTurbo},
	[133] = {door = true, type = blazeOpen},
	[134] = {door = true, type = blazeOpen},
	[135] = {door = true, type = blazeOpen},
	[136] = {door = true, type = blazeOpen},
	[137] = {door = true, type = blazeOpen},
	[140] = {floor = true, type = raiseFloor512},
	[141] = {ceil = true, type = silentCrushAndRaise}
}

local function getNextSector(line, sec)
	if not bit.band(line.flags, ML_TWOSIDED) then return end
	if line.frontsector.id == sec.id then return line.backsector end
	return line.frontsector
end

function FindHighestSurrounding(sector, name, height)
	local line, other
	height = height or -32768
	
	for i = 1, #sector.lines do
		line = sector.lines[i]
		other = getNextSector(line, sector)
		
		if not other then continue end
		height = math.max(height, other[name])
	end
	return height
end

function FindLowestSurrounding(sector, name, height)
	local line, other
	height = height or 32767
	
	for i = 1, #sector.lines do
		line = sector.lines[i]
		other = getNextSector(line, sector)
		
		if not other then continue end
		height = math.min(height, other[name])
	end
	return height
end

local sectorschanged

local Specials_Floor = {
	[lowerFloor] = function(s) return FindHighestSurrounding(s, "minfloor") end,
	[lowerFloorToLowest] = function(s) return FindLowestSurrounding(s, "minfloor") end,
	[raiseFloor] = function(s) return FindLowestSurrounding(s, "maxceiling") end,
	[raiseFloorToNearest] = function(s) return FindHighestSurrounding(s, "maxfloor") end,
	[raiseToTexture] = function(s) return s.maxceiling end
}

Specials_Floor[turboLower] = Specials_Floor[lowerFloor]
Specials_Floor[lowerAndChange] = Specials_Floor[lowerFloorToLowest]
Specials_Floor[raiseFloor24] = Specials_Floor[raiseToTexture]
Specials_Floor[raiseFloor24AndChange] = Specials_Floor[raiseToTexture]
Specials_Floor[raiseFloorCrush] = Specials_Floor[raiseFloor]
Specials_Floor[raiseFloorTurbo] = Specials_Floor[raiseFloorToNearest]
Specials_Floor[raiseFloor512] = Specials_Floor[raiseToTexture]

local function UpdateSectorFloor(sector, type)
	local height = Specials_Floor[type](sector)
	if sector.maxfloor < height then
		sector.maxfloor = height
		sector.floormoves = true
		sectorschanged = true
	end
	if sector.minfloor > height then
		sector.minfloor = height
		sector.floormoves = true
		sectorschanged = true
	end
end

local function UpdateSectorStair(sector)
	if sector.maxfloor < sector.ceilingheight then
		sector.maxfloor = sector.ceilingheight
		sector.floormoves = true
		sector.donestairs = true
		sectorschanged = true
	end
	for _, line in ipairs(sector.lines) do
		if not tobool(bit.band(line.flags, ML_TWOSIDED)) then continue end
		local tsec = line.frontsector
		if sector.id ~= tsec.id then continue end
		tsec = line.backsector
		if tsec.floorpic ~= sector.floorpic then continue end
		if tsec.donestairs then continue end
		UpdateSectorStair(tsec)
		break
	end
end

local function UpdateSectorCeil(sector, type)
	local height
	if type == raiseToHighest then
		height = FindHighestSurrounding(sector, "maxceiling")
		if sector.maxceiling < height then
			sector.maxceiling = height
			sector.ceilingmoves = true
			sectorschanged = true
		end
	else
		height = sector.minfloor
		if sector.minceiling > height then
			sector.minceiling = height
			sector.ceilingmoves = true
			sectorschanged = true
		end
	end
end

local function UpdateSectorDoor(sector, type)
	local maxceiling = FindLowestSurrounding(sector, "maxceiling")
	if sector.maxceiling < maxceiling then
		sector.maxceiling = maxceiling
		sector.ceilingmoves = true
		sectorschanged = true
	end
	if sector.minceiling > sector.minfloor then
		sector.minceiling = sector.minfloor
		sector.ceilingmoves = true
		sectorschanged = true
	end
end

local Specials_Plat = {
	[perpetualRaise] = function(s) return FindLowestSurrounding(s, "minfloor"), FindHighestSurrounding(s, "maxfloor") end,
	[downWaitUpStay] = function(s) return FindLowestSurrounding(s, "minfloor") end,
	[raiseAndChange] = function(s) return s.maxceiling end,
	[raiseToNearestAndChange] = function(s) return FindHighestSurrounding(s, "maxfloor") end,
}

Specials_Plat[blazeDWUS] = Specials_Plat[downWaitUpStay]

local function UpdateSectorPlat(sector, type)
	local height1, height2 = Specials_Plat[type](sector)
	height2 = height2 or height1
	if sector.maxfloor < math.max(height1, height2)then
		sector.maxfloor = math.max(height1, height2)
		sector.floormoves = true
		sectorschanged = true
	end
	if sector.minfloor > math.min(height1, height2) then
		sector.minfloor = math.min(height1, height2)
		sector.floormoves = true
		sectorschanged = true
	end
end

function MAP:FindSectorFromLineTag(line)
	start = 0
	return function()
		for i = start+1, #self.Sectors do
			start = i
			if self.Sectors[i].tag == line.tag then return i end
		end
	end
end

function MAP:LinedefSpecials()
	sectorschanged = false
	for i = 1, #self.Linedefs do
		local line = self.Linedefs[i]
		local special = LinedefSpecials[line.special]
		if not special then continue end
		if special.floor then
			for secnum in self:FindSectorFromLineTag(line) do
				UpdateSectorFloor(self.Sectors[secnum], special.type)
			end
		elseif special.stair then
			for secnum in self:FindSectorFromLineTag(line) do
				UpdateSectorStair(self.Sectors[secnum])
			end
		elseif special.ceil then
			for secnum in self:FindSectorFromLineTag(line) do
				UpdateSectorCeil(self.Sectors[secnum], special.type)
			end
		elseif special.door then
			if special.man then
				if not line.backsector then continue end -- Don't error on MAP06: The Crusher
				UpdateSectorDoor(line.backsector, special.type)
			else
				for secnum in self:FindSectorFromLineTag(line) do
					UpdateSectorDoor(self.Sectors[secnum], special.type)
				end
			end
		elseif special.plat then
			for secnum in self:FindSectorFromLineTag(line) do 
				UpdateSectorPlat(self.Sectors[secnum], special.type)
			end
		end
	end
	-- hacky special case shit
	for i = 1, #self.Sectors do
		local sector = self.Sectors[i]
		if sector.tag == 666 then 
			if self.gamemode ~= commercial and self.gameepisode == 4 and self.gamemap == 6 then
				UpdateSectorDoor(sector, blazeOpen)
			else
				UpdateSectorFloor(sector, lowerFloorToLowest)
			end
		end
		if sector.tag == 667 then UpdateSectorFloor(sector, raiseToTexture) end
	end
	if sectorschanged then self:LinedefSpecials() end
end
