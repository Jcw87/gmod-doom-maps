
local IN_ATTACK = IN_ATTACK
local IN_ATTACK2 = IN_ATTACK2
local IN_USE = IN_USE

local ipairs = ipairs
local pairs = pairs
local tobool = tobool

local IsValid = IsValid

local bit = bit
local ents = ents
local hook = hook
local player = player

setfenv( 1, DOOM )

if SERVER then

local soundtarget

local function P_RecursiveSound(sec, soundblocks)
	if sec.validcount == validcount and sec.soundtraversed <= soundblocks+1 then return end
	sec.validcount = validcount
	sec.soundtraversed = soundblocks+1
	sec.soundtarget = soundtarget
	local check
	for i = 1, #sec.lines do
		check = sec.lines[i]
		if not tobool(bit.band(check.flags, ML_TWOSIDED)) then continue end
		P_LineOpening(check)
		if openrange <= 0 then continue end
		local other
		if check.side[1].sector.id == sec.id then
			other = check.side[2].sector
		else
			other = check.side[1].sector
		end
		if tobool(bit.band(check.flags, ML_SOUNDBLOCK)) then
			if soundblocks == 0 then
				P_RecursiveSound(other, 1)
			end
		else
			P_RecursiveSound(other, soundblocks)
		end
	end
end

local function P_NoiseAlert(target, emmiter)
	soundtarget = target
	validcount = validcount + 1
	P_RecursiveSound(emmiter.subsector.sector, 0)
end

hook.Add("Think", "DOOM.MonsterHearingMap", function()
	for _, ply in pairs(player.GetAll()) do
		if not ply.subsector then continue end
		local weapon = ply:GetActiveWeapon()
		if not IsValid(weapon) then continue end
		if ply:KeyDown(IN_ATTACK) or ply:KeyDown(IN_ATTACK2) then
			P_NoiseAlert(ply, ply)
			for mobj, __ in pairs(GetListeningMonsterTable()) do
				local ent = ToEntity(mobj)
				if not ent:IsNPC() or not ent.subsector then continue end
				mobj.entHeard = ent.subsector.sector.soundtarget
			end
		end
	end
end)

hook.Add("DOOM.CanMonsterHearSound", "DOOM.MapSoundOverride", function(mobjListener, entEmitter, entTarget)
	if ToEntity(mobjListener).subsector or entEmitter.subsector then return false end
end)

hook.Add("DOOM.OnTick", "DOOM.Subsector", function()
	for k, v in pairs(ents.GetAll()) do
		if not IsValid(v) then continue end
		if not v:IsPlayer() and not v:IsNPC() then continue end
		if not Map then v.subsector = nil continue end
		local pos = v:GetPos()
		if not pos:WithinAABox(Map.Bounds.lower, Map.Bounds.upper) then v.subsector = nil continue end
		v.subsector = Map:PointInSubsector(pos.x, pos.y)
		if SERVER and v:IsPlayer() and v.subsector.sector.special ~= 0 then P_PlayerInSpecialSector(v) end
	end
end)

hook.Add("DOOM.OnTick", "DOOM.MapThinkers", function()
	if not Map or not Map.spawned then return end
	for k, v in pairs(Map.thinkers) do
		k:Think()
	end
end)

hook.Add("Think", "DOOM.Use", function()
	if not Map or not Map.spawned then return end
	for k, v in pairs(player.GetAll()) do
		if not v:GetPos():WithinAABox(Map.Bounds.lower, Map.Bounds.upper) then continue end
		local use = v:KeyDown(IN_USE)
		if use and not v.lastuse then
			v.lastuse = use
			P_UseLines(v)
		end
		v.lastuse = use
	end
end)

hook.Add("DOOM.OnTick", "DOOM.CrossLine", function()
	if not Map or not Map.spawned then return end
	for _, ent in pairs(ents.GetAll()) do
		if ent:IsPlayer() or ent:IsNPC() then
			if ent.subsector then
				local pos = ent:GetPos()
				if ent.oldpos and (ent.oldpos.x ~= pos.x or ent.oldpos.y ~= pos.y) then
					P_CheckPosition(ent, ent.oldpos.x, ent.oldpos.y)
					for i, ld in ipairs(spechit) do -- LuaJIT was doing some weird shit with 'for i = 1, #spechit do'
						pos = ent:GetPos()
						local side = P_PointOnLineSide(pos.x, pos.y, ld)
						local oldside = P_PointOnLineSide(ent.oldpos.x, ent.oldpos.y, ld)
						if side ~= oldside then P_CrossSpecialLine(ld.id, oldside+1, ent) end
					end
				end
				ent.oldpos = ent:GetPos()
			else
				ent.oldpos = nil
			end
		end
	end
end)

end

hook.Add("ShouldCollide", "DOOM.MapCollide", function(ent1, ent2)
	local class1 = ent1:GetClass()
	local class2 = ent2:GetClass()
	if class1 == "doom_sector" and class2 == "doom_sector" then return false end
end)
