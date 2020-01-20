AddCSLuaFile()

local error = error
local pairs = pairs
local print = print
local setmetatable = setmetatable
local tobool = tobool

local Angle = Angle
local IsValid = IsValid
local Vector = Vector

local bit = bit
local coroutine = coroutine
local ents = ents
local game = game
local hook = hook
local math = math
local net = net
local player = player
local scripted_ents = scripted_ents
local string = string
local table = table
local timer = timer
local util = util
local wad = wad

setfenv( 1, DOOM )

SetConstant("MTF_EASY", 1)
SetConstant("MTF_NORMAL", 2)
SetConstant("MTF_HARD", 4)
SetConstant("MTF_AMBUSH", 8)

SetConstant("ML_BLOCKING", 1)
SetConstant("ML_BLOCKMONSTERS", 2)
SetConstant("ML_TWOSIDED", 4)
SetConstant("ML_DONTPEGTOP", 8)
SetConstant("ML_DONTPEGBOTTOM", 16)
SetConstant("ML_SECRET", 32)
SetConstant("ML_SOUNDBLOCK", 64)
SetConstant("ML_DONTDRAW", 128)
SetConstant("ML_MAPPED", 256)

EnumStart("slopetype_t")
EnumAdd("ST_HORIZONTAL")
EnumAdd("ST_VERTICAL")
EnumAdd("ST_POSITIVE")
EnumAdd("ST_NEGATIVE")

SetConstant("NF_SUBSECTOR", 0x8000)

local function ReadUShort( fstream )
	local short = fstream:ReadShort()
	return short < 0 and bit.band(short, 65535) or short
end

local function ReadThings( fstream, tLumpInfo )
	local self = {}
	local total = tLumpInfo.iSize / 10
	for i = 1, total do
		self[i] = {}
		self[i].x = fstream:ReadShort()
		self[i].y = fstream:ReadShort()
		self[i].angle = fstream:ReadShort()
		self[i].type = ReadUShort( fstream )
		self[i].options = ReadUShort( fstream )
	end
	return self
end

local function ReadLinedefs( fstream, tLumpInfo )
	local self = {}
	local total = tLumpInfo.iSize / 14
	for i = 1, total do
		self[i] = {}
		self[i].v1 = ReadUShort( fstream )
		self[i].v2 = ReadUShort( fstream )
		self[i].flags = ReadUShort( fstream )
		self[i].special = ReadUShort( fstream )
		self[i].tag = ReadUShort( fstream )
		self[i].sidenum = {}
		self[i].sidenum[1] = ReadUShort( fstream )
		self[i].sidenum[2] = ReadUShort( fstream )
	end
	return self
end

local function ReadSidedefs( fstream, tLumpInfo )
	local self = {}
	local total = tLumpInfo.iSize / 30
	for i = 1, total do
		self[i] = {}
		self[i].textureoffset = fstream:ReadShort()
		self[i].rowoffset = fstream:ReadShort() * HEIGHTCORRECTION
		self[i].toptexture = string.upper(string.TrimRight(fstream:Read( 8 ), "\0"))
		self[i].bottomtexture = string.upper(string.TrimRight(fstream:Read( 8 ), "\0"))
		self[i].midtexture = string.upper(string.TrimRight(fstream:Read( 8 ), "\0"))
		self[i].sector = fstream:ReadShort()
	end
	return self
end

local function ReadVertexes( fstream, tLumpInfo )
	local self = {}
	local total = tLumpInfo.iSize / 4
	for i = 1, total do
		self[i] = {}
		self[i].x = fstream:ReadShort()
		self[i].y = fstream:ReadShort()
	end
	return self
end

local function ReadSegs( fstream, tLumpInfo )
	local self = {}
	local total = tLumpInfo.iSize / 12
	for i = 1, total do
		self[i] = {}
		self[i].v1 = ReadUShort( fstream )
		self[i].v2 = ReadUShort( fstream )
		self[i].angle = fstream:ReadShort()
		self[i].linedef = ReadUShort( fstream )
		self[i].side = ReadUShort( fstream )
		self[i].offset = fstream:ReadShort()
	end
	return self
end

local function ReadSubsectors( fstream, tLumpInfo )
	local self = {}
	local total = tLumpInfo.iSize / 4
	for i = 1, total do
		self[i] = {}
		self[i].numsegs = fstream:ReadShort()
		self[i].firstseg = fstream:ReadShort()
	end
	return self
end

local function ReadNodes( fstream, tLumpInfo )
	local self = {}
	local total = tLumpInfo.iSize / 28
	for i = 1, total do
		self[i] = {}
		self[i].x = fstream:ReadShort()
		self[i].y = fstream:ReadShort()
		self[i].dx = fstream:ReadShort()
		self[i].dy = fstream:ReadShort()
		self[i].bbox = {}
		for j = 1, 2 do
			self[i].bbox[j] = {}
			self[i].bbox[j].top = fstream:ReadShort()
			self[i].bbox[j].bottom = fstream:ReadShort()
			self[i].bbox[j].left = fstream:ReadShort()
			self[i].bbox[j].right = fstream:ReadShort()
		end
		self[i].children = {}
		self[i].children[1] = ReadUShort( fstream )
		self[i].children[2] = ReadUShort( fstream )
	end
	return self
end

local function ReadSectors( fstream, tLumpInfo )
	local self = {}
	local total = tLumpInfo.iSize / 26
	for i = 1, total do
		self[i] = {}
		self[i].floorheight = fstream:ReadShort() * HEIGHTCORRECTION
		self[i].ceilingheight = fstream:ReadShort() * HEIGHTCORRECTION
		self[i].floorpic = string.upper(string.TrimRight(fstream:Read( 8 ), "\0"))
		self[i].ceilingpic = string.upper(string.TrimRight(fstream:Read( 8 ), "\0"))
		self[i].lightlevel = fstream:ReadShort()
		self[i].special = ReadUShort( fstream )
		self[i].tag = ReadUShort( fstream )
	end
	return self
end

local function ReadBlockmap( fstream, tLumpInfo )
	local self = {}
	local start = fstream:Tell()
	self.bmaporgx = fstream:ReadShort()
	self.bmaporgy = fstream:ReadShort()
	self.bmapwidth = fstream:ReadShort()
	self.bmapheight = fstream:ReadShort()
	local offsets = {}
	for i = 1, ((self.bmapwidth)*(self.bmapheight)) do
		offsets[i] = ReadUShort(fstream)
	end
	for i = 1, #offsets do
		local lines = {}
		fstream:Seek(start + offsets[i]*2)
		local start0 = fstream:ReadShort() -- discard starting 0
		if start0 != 0 then error("Blockmap invalid!") end
		local lineid = fstream:ReadShort()
		local currentoffset = offsets[i]*2 + 2
		while lineid ~= -1 do
			if currentoffset > tLumpInfo.iSize then error("Blockmap invalid!") end
			table.insert(lines, lineid)
			lineid = fstream:ReadShort()
			currentoffset = currentoffset + 2
		end
		self[i] = lines
	end
	return self
end

MAP = MAP or {}
MAP.__index = MAP

function MAP:SetupSectors()
	for i = 1, #self.Sectors do
		local sector = self.Sectors[i]
		sector.id = i
		sector.lines = {}
		sector.minfloor = sector.floorheight
		sector.maxfloor = sector.floorheight
		sector.minceiling = sector.ceilingheight
		sector.maxceiling = sector.ceilingheight
		sector.validcount = 0
		sector.soundtraversed = 0
	end
end

function MAP:SetupSidedefs()
	for i = 1, #self.Sidedefs do
		local sidedef = self.Sidedefs[i]
		sidedef.id = i
		sidedef.sector = self.Sectors[sidedef.sector+1]
	end
end

function MAP:SetupLinedefs()
	for i = 1, #self.Linedefs do
		local linedef = self.Linedefs[i]
		linedef.id = i
		linedef.v1 = self.Vertexes[linedef.v1+1]
		linedef.v2 = self.Vertexes[linedef.v2+1]
		linedef.dx = linedef.v2.x - linedef.v1.x
		linedef.dy = linedef.v2.y - linedef.v1.y
		if linedef.dx == 0 then
			linedef.slopetype = ST_VERTICAL
		elseif linedef.dy == 0 then
			linedef.slopetype = ST_HORIZONTAL
		else
			if linedef.dx / linedef.dy > 0 then linedef.slopetype = ST_POSITIVE else linedef.slopetype = ST_NEGATIVE end
		end
		linedef.bbox = {}
		linedef.bbox.left = math.min(linedef.v1.x, linedef.v2.x)
		linedef.bbox.right = math.max(linedef.v1.x, linedef.v2.x)
		linedef.bbox.bottom = math.min(linedef.v1.y, linedef.v2.y)
		linedef.bbox.top = math.max(linedef.v1.y, linedef.v2.y)
		local sideindex = linedef.sidenum[1]
		linedef.sidenum[1] = (sideindex ~= 65535) and self.Sidedefs[sideindex+1] or nil
		sideindex = linedef.sidenum[2]
		linedef.sidenum[2] = (sideindex ~= 65535) and self.Sidedefs[sideindex+1] or nil
		if linedef.sidenum[1] then linedef.frontsector = linedef.sidenum[1].sector end
		if linedef.sidenum[2] then linedef.backsector = linedef.sidenum[2].sector end
		if linedef.frontsector then table.insert(linedef.frontsector.lines, linedef) end
		if linedef.backsector then table.insert(linedef.backsector.lines, linedef) end
		linedef.normal = Vector(linedef.v2.y - linedef.v1.y, -(linedef.v2.x - linedef.v1.x), 0):GetNormalized()
		linedef.length = math.sqrt((linedef.v2.x - linedef.v1.x)^2 + (linedef.v2.y - linedef.v1.y)^2)
		linedef.soundpos = Vector(linedef.v1.x + linedef.dx/2, linedef.v1.y + linedef.dy/2, linedef.frontsector.floorheight)
	end
end

local function ProjectPointToLine(line, v)
	local dx2 = line.dx * line.dx
	local dy2 = line.dy * line.dy
	local u = ((v.x - line.v1.x) * line.dx + (v.y - line.v1.y) * line.dy) / (dx2 + dy2)
	v.x = line.v1.x + u * line.dx
	v.y = line.v1.y + u * line.dy
end

function MAP:SetupSegs()
	local hit = {}
	for i = 1, #self.Segs do
		local seg = self.Segs[i]
		seg.id = i
		if type(seg.v1) ~= "number" then print(i) end -- checking the type seems to prevent LuaJIT from screwing up
		if type(seg.v2) ~= "number" then print(i) end
		seg.v1 = self.Vertexes[seg.v1+1]
		seg.v2 = self.Vertexes[seg.v2+1]
		seg.linedef = self.Linedefs[seg.linedef+1]
		local side = seg.side
		seg.side = seg.linedef.sidenum[side+1]
		seg.frontsector = seg.side.sector
		if tobool(bit.band(seg.linedef.flags, ML_TWOSIDED)) then seg.backsector = seg.linedef.sidenum[bit.bxor(side,1)+1].sector end
		
		-- 'slime trails' fix
		local line = seg.linedef
		if line.dx == 0 or line.dy == 0 then continue end
		if not hit[seg.v1] then
			ProjectPointToLine(line, seg.v1)
			hit[seg.v1] = true
		end
		if not hit[seg.v2] then
			ProjectPointToLine(line, seg.v2)
			hit[seg.v2] = true
		end
	end
end

function MAP:SetupSubsectors()
	for i = 1, #self.Subsectors do
		local subsector = self.Subsectors[i]
		subsector.id = i
		subsector.segs = {}
		for j = 1, subsector.numsegs do
			subsector.segs[j] = self.Segs[subsector.firstseg + j]
		end
		subsector.sector = subsector.segs[1].side.sector
	end
end

function MAP:SetupBlockmap()
	for i = 1, #self.Blockmap do
		local lines = self.Blockmap[i]
		for j = 1, #lines do
			lines[j] = self.Linedefs[lines[j]+1]
		end
	end
end

function MAP:SetupThings()
	local gameskill = CvarGet("skill")
	local skillbit = gameskill == sk_baby and 1 or gameskill == sk_nightmare and 4 or bit.lshift(1, gameskill-1)
	for i = 1, #self.Things do
		local thing = self.Things[i]
		local subsector = self:PointInSubsector(thing.x, thing.y)
		local pos = Vector(thing.x, thing.y, subsector.sector.floorheight + 0.5)
		if not util.IsInWorld(pos) then continue end
		local angle = thing.angle < 180 and thing.angle or thing.angle - 360
		if thing.type <= 4 then
			local ent = ents.Create("doom_playerstart")
			ent:SetPos(pos)
			ent:SetAngles(Angle(0, angle, 0))
			ent:SetParent(subsector.sector.floor)
			ent:Spawn()
			ent.player = thing.type
			self.Things[i] = ent
			continue
		end
		if thing.type == 11 then continue end
		if game.SinglePlayer() and tobool(bit.band(thing.options, 16)) then continue end
		if not tobool(bit.band(thing.options, skillbit)) then continue end
		local mobj = P_SpawnMobj(pos, GetMobjInfoIndexByDoomEdNum(thing.type))
		mobj:SetYaw(angle)
		if mobj:HasFlag(MF_SPAWNCEILING) then pos.z = subsector.sector.ceilingheight - 1 - mobj.height*HEIGHTCORRECTION mobj:SetPos(pos) end
		if not game.SinglePlayer() and mobj:HasFlag(MF_SPECIAL) then mobj:SetUsingMPPickupRules(true) end
		if tobool(bit.band(thing.options, MTF_AMBUSH)) then mobj:AddFlag(MF_AMBUSH) end
		P_CheckPosition(ToEntity(mobj), pos.x, pos.y)
		if tmfloorz > pos.z then pos.z = tmfloorz+0.5 mobj:SetPos(pos) end
		mobj:Spawn()
		self.Things[i] = mobj
	end
end

function CreateBounds()
	return {lower = Vector(32767, 32767, 32767), upper = Vector(-32768, -32768, -32768)}
end

function AddBounds(bbox, v)
	if v.x < bbox.lower.x then bbox.lower.x = v.x end
	if v.x > bbox.upper.x then bbox.upper.x = v.x end
	if v.y < bbox.lower.y then bbox.lower.y = v.y end
	if v.y > bbox.upper.y then bbox.upper.y = v.y end
end

function AddBoundsZ(bbox, z)
	if z < bbox.lower.z then bbox.lower.z = z end
	if z > bbox.upper.z then bbox.upper.z = z end
end

function MAP:SetupBounds()
	local mapbbox = CreateBounds()
	for i = 1, #self.Vertexes do
		AddBounds(mapbbox, self.Vertexes[i])
	end
	for i = 1, #self.Sectors do
		local sector = self.Sectors[i]
		AddBoundsZ(mapbbox, sector.floorheight)
		AddBoundsZ(mapbbox, sector.ceilingheight)
		local bbox = CreateBounds()
		for j = 1, #sector.lines do
			AddBounds(bbox, sector.lines[j].v1)
			AddBounds(bbox, sector.lines[j].v2)
		end
		AddBoundsZ(bbox, sector.floorheight)
		AddBoundsZ(bbox, sector.ceilingheight)
		sector.bounds = bbox
	end
	self.Bounds = mapbbox
end

function MAP:Setup()
	self:SetupSectors()
	self:SetupSidedefs()
	self:SetupLinedefs()
	self:SetupSegs()
	self:SetupSubsectors()

	self:LinedefSpecials() -- Sets sector min and max floor and ceiling heights, used for mesh generation

	self:SetupBounds()
	self:CreateMeshes()
	
	if CLIENT then
		for i = 1, #self.Sectors do
			UpdateSectorLight(self.Sectors[i])
		end
	end

	self.thinkers = {}
	validcount = 1
	self.loaded = true
end

function MAP:Spawn()
	for i = 1, #self.Sectors do
		if i % 10 == 0 then coroutine.yield() end
		local sector = self.Sectors[i]
		if #sector.lines == 0 then continue end -- ignore orphaned sectors
		if #self.FloorPhys[i] > 256 or #self.CeilPhys[i] > 256 then print(string.format("Sector %i is too complex for vphysics!", i-1)) continue end
		local ent = ents.Create("doom_sector")
		ent:SetSector(i)
		ent:SetFloor(true)
		ent:SetLight(sector.lightlevel)
		if ent:Setup() then
			ent:Spawn()
		end

		ent = ents.Create("doom_sector")
		ent:SetSector(i)
		ent:SetFloor(false)
		if ent:Setup() then
			ent:Spawn()
		end
	end

	for i = 1, #self.Linedefs do
		local line = self.Linedefs[i]
		if tobool(bit.band(line.flags, ML_TWOSIDED)) and tobool(bit.band(line.flags, ML_BLOCKING)) then
			local ent = ents.Create("doom_linedef")
			ent:SetLinedef(i)
			ent:Setup()
			ent:Spawn()
			self.Linedefs[i].ent = ent
		end
	end

	local trigger666 = ents.Create("doom_bosstrigger")
	trigger666:SetName("666")
	local trigger667 = ents.Create("doom_bosstrigger")
	trigger667:SetName("667")

	P_SpawnSpecials()
	self:SetupThings()
	self.spawned = true
	timer.Destroy("DOOM.LoadMap")
end

function MAP:PointInSubsector(x, y)
	if #self.Nodes == 0 then return self.Subsectors[1] end
	local nodeid = #self.Nodes - 1
	while not tobool(bit.band(nodeid, NF_SUBSECTOR)) do
		local node = self.Nodes[nodeid+1]
		local side
		if SERVER then
			side = P_PointOnDivlineSide(x, y, node)
		else
			side = R_PointOnSide(x, y, node)
		end
		nodeid = node.children[side+1]
	end
	return self.Subsectors[bit.bxor(nodeid, NF_SUBSECTOR)+1]
end

local function MatchNextNamed(tDirectory, pattern)
	tDirectory:ResetReadIndex()
	while true do
		local lump = tDirectory:GetNext()
		if lump == nil then return end
		local name = lump:GetName()
		if name:match(pattern) then return lump end
	end
end

function GetDoomGamemode(tWadFile)
	local tDirectory = tWadFile:GetDirectory()
	-- Some joker WILL try to load a hexen format wad
	tDirectory:ResetReadIndex()
	if tDirectory:FindNextNamed("BEHAVIOR") then return indetermined end
	if MatchNextNamed(tDirectory, "^MAP%d%d$") then return commercial end
	if MatchNextNamed(tDirectory, "^E%dM%d$") then return retail end
	return indetermined
end

local function GetMapNum(mapname)
	local episode, map = mapname:match("^E(%d)M(%d)$")
	if episode then return episode, map end
	map = mapname:match("^MAP(%d%d)$")
	if map then return 1, map end
	return 1, 1
end

local function GetMapName(gamemode, episode, map)
	if gamemode == commercial then
		if map < 10 then return string.format("MAP0%i", map) else return string.format("MAP%i", map) end
	else
		return string.format("E%iM%i", episode, map)
	end
end

function LoadMap(wadname, mapname)
	if Map then return end
	self = setmetatable( {}, MAP )
	self.wadname = wadname
	local tWadFile = wad.Open(wadname)
	if not tWadFile then
		print(string.format("WAD %s not found!", wadname))
		return
	end
	local episode, map = GetMapNum(mapname)
	self.gamemode = GetDoomGamemode(tWadFile)
	if self.gamemode == indetermined then return end
	self.gameepisode = episode
	self.gamemap = map
	self.name = mapname
	local tDirectory = tWadFile:GetDirectory()
	tDirectory:ResetReadIndex()
	local maploc = tDirectory:FindNextNamed(self.name)
	if not maploc then
		print(string.format("MAP %s not found in WAD %s!", self.name, wadname))
		return
	end
	self.Things = tWadFile:ReadLump(tDirectory:GetNext(), ReadThings)
	self.Linedefs = tWadFile:ReadLump(tDirectory:GetNext(), ReadLinedefs)
	self.Sidedefs = tWadFile:ReadLump(tDirectory:GetNext(), ReadSidedefs)
	self.Vertexes = tWadFile:ReadLump(tDirectory:GetNext(), ReadVertexes)
	self.Segs = tWadFile:ReadLump(tDirectory:GetNext(), ReadSegs)
	self.Subsectors = tWadFile:ReadLump(tDirectory:GetNext(), ReadSubsectors)
	self.Nodes = tWadFile:ReadLump(tDirectory:GetNext(), ReadNodes)
	self.Sectors = tWadFile:ReadLump(tDirectory:GetNext(), ReadSectors)
	tDirectory:GetNext() -- REJECT
	self.Blockmap = tWadFile:ReadLump(tDirectory:GetNext(), ReadBlockmap)
	
	self:Setup()
	self:SetupBlockmap()
	self:SetupNet(tWadFile)
	-- WAD should really have a close function
	tWadFile.fstream:Close()
	
	Map = self
	
	if SERVER then
		local co = coroutine.wrap(self.Spawn)
		co(self)
		timer.Create("DOOM.LoadMap", 0.1, 0, co)
	end
	return self
end

local removeclasses = {
	doom_sector = true,
	doom_linedef = true,
	doom_playerstart = true,
	doom_bosstrigger = true
}

function UnloadMap()
	for k, v in pairs(ents.GetAll()) do
		if removeclasses[v:GetClass()] then v:Remove() end
	end
	
	if Map then
		for k, v in pairs(GetAllMobjInstances()) do
			local ent = ToEntity(v)
			if not IsValid(ent) then continue end
			if not ent:GetPos():WithinAABox(Map.Bounds.lower, Map.Bounds.upper) then continue end
			if ent:IsWeapon() and IsValid(ent:GetOwner()) then continue end
			if ent:IsPlayer() then continue end
			ent:Remove()
		end
	end
	
	Map = nil
	timer.Destroy("DOOM.LoadMap")
	timer.Destroy("DOOM.SpawnPlayers")
	net.Start("DOOM.UnloadMap")
	net.Broadcast()
end

function FindPlayerStart()
	local playerstarts = {}
	for k, v in pairs(ents.FindByClass("doom_playerstart")) do
		playerstarts[v.player] = v
	end
	for i = 1, #playerstarts do
		local start = playerstarts[i]
		local pos = start:GetPos()
		local tr = {start = pos, endpos = pos, mins = Vector(-16+0.1, -16+0.1, 0.1), maxs = Vector(16-0.1, 16-0.1, 56*HEIGHTCORRECTION-0.1), mask = MASK_PLAYERSOLID}
		tr = util.TraceHull(tr)
		if not tr.Hit then return start end
	end
end

function SpawnPlayer(ply)
	-- Players might disconnect between maps
	if not ply:IsValid() then return end
	local start = FindPlayerStart()
	if not start then 
		--timer.Simple(1, function() SpawnPlayer(ply) end)
		return
	end
	ply:SetPos(start:GetPos() )
	ply:SetEyeAngles(start:GetAngles())
	local info = GetPlayerInfo(ply)
	info:ResetCards()
	local powers = GetPlayerPowers(ply)
	for i=0, NUMPOWERS-1, 1 do
		powers:Deactivate( i )
	end
	
end

function G_SecretExitLevel()
	G_ExitLevel(true)
end

function G_ExitLevel(secret)
	if Map.exiting then return end
	Map.exiting = true
	local players = {}
	for k, v in pairs(player.GetAll()) do
		if v.subsector then table.insert(players, v) end
	end
	local wadname = Map.wadname
	local oldepisode = Map.gameepisode
	local oldmap = Map.gamemap
	local episode, map
	if Map.gamemode == commercial then
		episode = 0
		if secret then
			if oldmap == 15 then
				map = 31
			elseif oldmap == 31 then
				map = 32
			else
				map = oldmap
			end
		else
			if oldmap == 31 or oldmap == 32 then
				map = 16
			else
				map = oldmap + 1
			end
		end
	else
		episode = oldepisode
		if secret then
			map = 9
		elseif oldmap == 9 then
			if episode == 1 then map = 4
			elseif episode == 2 then map = 6
			elseif episode == 3 then map = 7
			elseif episode == 4 then map = 3
			end
		else
			map = oldmap + 1
		end
	end
	local mapname = GetMapName(Map.gamemode, episode, map)
	timer.Simple(1, UnloadMap)
	timer.Simple(1.2, function()
		LoadMap(wadname, mapname) 
		timer.Create("DOOM.SpawnPlayers", 1, 0, function()
			if not Map or not Map.spawned then return end
			for k, v in pairs(players) do
				SpawnPlayer(v)
			end
			timer.Destroy("DOOM.SpawnPlayers")
		end)
	end)
end

local Restricted = {
	doom_sector = true,
	doom_linedef = true
}

hook.Add("CanTool", "DOOM.MapProtect", function(ply, tr, tool) if Restricted[tr.Entity:GetClass()] then return false end end)
hook.Add("PhysgunPickup", "DOOM.MapProtect", function(ply, ent) if Restricted[ent:GetClass()] then return false end end)

if CLIENT then
hook.Add("DOOM.OnTick", "DOOM.TextureScroll", function()
	if not Map or not Map.loaded then return end
	for _, sectorwalls in pairs(Map.SpecialMeshes) do
		for __, wall in pairs(sectorwalls) do
			if wall.scrollx then
				wall.offsetx = wall.offsetx + 1
			end
		end
	end
end)
end

if SERVER then

local ENT = {Type = "point"}
scripted_ents.Register(ENT, "doom_playerstart")
--scripted_ents.Register(ENT, "doom_deathmatchstart")
ENT = {Type = "point"}
function ENT:AcceptInput(name, activator, caller, data)
	if self:GetName() == "666" and name == "FireUser1" then
		if Map.gamemode ~= commercial and Map.gameepisode == 4 and Map.gamemap == 6 then
			EV_DoDoor({tag = 666}, blazeOpen)
		elseif Map.gamemode == commercial and Map.gamemap == 32 then
			EV_DoDoor({tag = 666}, open)
		else
			EV_DoFloor({tag = 666}, lowerFloorToLowest)
		end
	end
	if self:GetName() == "667" and name == "FireUser1" then
		EV_DoFloor({tag = 667}, raiseToTexture)
	end
end
scripted_ents.Register(ENT, "doom_bosstrigger")
end