
local tobool = tobool

local bit = bit
local table = table

setfenv( 1, DOOM )

SetConstant("GLOWSPEED", 8)
SetConstant("STROBEBRIGHT", 5)
SetConstant("FASTDARK", 15)
SetConstant("SLOWDARK", 35)

function T_FireFlicker(flick)
	flick.count = flick.count - 1
	if flick.count ~= 0 then return end
	
	local sector = flick.sector
	local amount = bit.band(P_Random(), 3)*16
	if sector.lightlevel - amount < flick.minlight then
		sector.lightlevel = flick.minlight
	else
		sector.lightlevel = flick.maxlight - amount;
	end
	flick.count = 4
	if sector.floor then sector.floor:SetLight(sector.lightlevel) end
end

function P_SpawnFireFlicker(sector)
	sector.special = 0
	local flick = {}
	Map.thinkers[flick] = "T_FireFlicker"
	flick.Think = T_FireFlicker
	flick.sector = sector
	flick.maxlight = sector.lightlevel
	flick.minlight = P_FindMinSurroundingLight(sector, sector.lightlevel)+16
	flick.count = 4
end

function T_LightFlash(flash)
	flash.count = flash.count - 1
	if flash.count ~= 0 then return end
	local sector = flash.sector
	if sector.lightlevel == flash.maxlight then
		sector.lightlevel = flash.minlight
		flash.count = bit.band(P_Random(), flash.mintime)+1
	else
		sector.lightlevel = flash.maxlight
		flash.count = bit.band(P_Random(), flash.maxtime)+1
	end
	if sector.floor then sector.floor:SetLight(sector.lightlevel) end
end

function P_SpawnLightFlash(sector)
	sector.special = 0
	local flash = {}
	Map.thinkers[flash] = "T_LightFlash"
	flash.Think = T_LightFlash
	flash.sector = sector
	flash.maxlight = sector.lightlevel
	flash.minlight = P_FindMinSurroundingLight(sector,sector.lightlevel)
	flash.maxtime = 64
	flash.mintime = 7
	flash.count = bit.band(P_Random(), flash.maxtime)+1
end

function T_StrobeFlash(flash)
	flash.count = flash.count - 1
	if flash.count ~= 0 then return end
	local sector = flash.sector
	if sector.lightlevel == flash.minlight then
		sector.lightlevel = flash.maxlight
		flash.count = flash.brighttime
	else
		sector.lightlevel = flash.minlight
		flash.count = flash.darktime
	end
	if sector.floor then sector.floor:SetLight(sector.lightlevel) end
end

function P_SpawnStrobeFlash(sector, fastOrSlow, inSync)
	local flash = {}
	Map.thinkers[flash] = "T_StrobeFlash"
	flash.sector = sector
	flash.darktime = fastOrSlow
	flash.brighttime = STROBEBRIGHT
	flash.Think = T_StrobeFlash
	flash.maxlight = sector.lightlevel
	flash.minlight = P_FindMinSurroundingLight(sector, sector.lightlevel)
	
	if flash.minlight == flash.maxlight then flash.minlight = 0 end
	sector.special = 0
	if not tobool(inSync) then flash.count = bit.band(P_Random(), 7)+1 else flash.count = 1 end
end

function EV_StartLightStrobing(line)
	local sec
	for secnum in P_FindSectorFromLineTag(line) do
		sec = Map.Sectors[secnum]
		if sec.specialdata then continue end
		P_SpawnStrobeFlash(sec, SLOWDARK, 0)
	end
end

function EV_TurnTagLightsOff(line)
	local sector
	for secnum in P_FindSectorFromLineTag(line) do
		sector = Map.Sectors[secnum]
		sector.lightlevel = P_FindMinSurroundingLight(sector, sector.lightlevel)
		if sector.floor then sector.floor:SetLight(sector.lightlevel) end
	end
end

function EV_LightTurnOn(line, bright)
	local sector, temp, templine
	for secnum in P_FindSectorFromLineTag(line) do
		sector = Map.Sectors[secnum]
		if bright == 0 then
			for i = 1, #sector.lines do
				templine = sector.lines[i]
				temp = getNextSector(templine, sector)
				if not temp then continue end
				if temp.lightlevel > bright then bright = temp.lightlevel end
			end
		end
		sector.lightlevel = bright
		if sector.floor then sector.floor:SetLight(sector.lightlevel) end
	end
end

function T_Glow(g)
	local sector = g.sector
	sector.lightlevel = sector.lightlevel + GLOWSPEED * g.direction
	if g.direction == -1 and sector.lightlevel <= g.minlight or g.direction == 1 and sector.lightlevel >= g.maxlight then
		sector.lightlevel = sector.lightlevel - GLOWSPEED * g.direction
		g.direction = g.direction * -1
	end
	if sector.floor then sector.floor:SetLight(sector.lightlevel) end
end

function P_SpawnGlowingLight(sector)
	local g = {}
	Map.thinkers[g] = "T_Glow"
	g.sector = sector
	g.minlight = P_FindMinSurroundingLight(sector,sector.lightlevel)
	g.maxlight = sector.lightlevel
	g.Think = T_Glow
	g.direction = -1
	
	sector.special = 0
end
