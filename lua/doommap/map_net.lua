AddCSLuaFile()

local pairs = pairs
local setmetatable = setmetatable
local tostring = tostring

local coroutine = coroutine
local hook = hook
local net = net
local math = math
local string = string
local util = util
local timer = timer
local wad = wad

setfenv( 1, DOOM )

EnumStart()
EnumAdd("ML_LABEL")
EnumAdd("ML_THINGS")
EnumAdd("ML_LINEDEFS")
EnumAdd("ML_SIDEDEFS")
EnumAdd("ML_VERTEXES")
EnumAdd("ML_SEGS")
EnumAdd("ML_SSECTORS")
EnumAdd("ML_NODES")
EnumAdd("ML_SECTORS")
EnumAdd("ML_REJECT")
EnumAdd("ML_BLOCKMAP")

if SERVER then
util.AddNetworkString("DOOM.Map")
util.AddNetworkString("DOOM.UnloadMap")
util.AddNetworkString("DOOM.ChangeFloorTexture")
util.AddNetworkString("DOOM.ChangeWallTexture")
end

local targetplayer

local datasize = {
	[ML_LINEDEFS] = 14,
	[ML_SIDEDEFS] = 30,
	[ML_VERTEXES] = 4,
	[ML_SEGS] = 12,
	[ML_SSECTORS] = 4,
	[ML_NODES] = 28,
	[ML_SECTORS] = 26
}

local nametotype = {
	LINEDEFS = ML_LINEDEFS,
	SIDEDEFS = ML_SIDEDEFS,
	VERTEXES = ML_VERTEXES,
	SEGS = ML_SEGS,
	SSECTORS = ML_SSECTORS,
	NODES = ML_NODES,
	SECTORS = ML_SECTORS
}

local function SendLump( fstream, tLumpInfo )
	local name = tLumpInfo:GetName()
	local type = nametotype[name]
	-- shave a few bytes off, just in case
	local maxsize = math.floor(65530 / datasize[type]) * datasize[type]
	local numpackets = math.ceil(tLumpInfo.iSize/maxsize)
	for i = 1, numpackets do
		local size = i < numpackets and maxsize or tLumpInfo.iSize - maxsize*(i-1)
		print(string.format("Sending packet %i of %i, lump type %i, data size %i", i, numpackets, type, size))
		net.Start("DOOM.Map")
		net.WriteInt(type, 8)
		net.WriteInt(numpackets, 8)
		net.WriteInt(i-1, 8)
		net.WriteData(fstream:Read(size), size)
		if targetplayer then net.Send(targetplayer) else net.Broadcast() end
	end
end

function MAP:SendToClients(tWadFile, ply)
	local tDirectory = tWadFile:GetDirectory()
	targetplayer = ply
	local index
	if ply then index = ply:EntIndex() end
	tDirectory:ResetReadIndex()
	tDirectory:FindNextNamed(self.name)
	tDirectory:GetNext() -- THINGS
	local linedefs = tDirectory:GetNext() -- LINEDEFS
	local sidedefs = tDirectory:GetNext() -- SIDEDEFS
	local vertexes = tDirectory:GetNext() -- VERTEXES
	local segs = tDirectory:GetNext() -- SEGS
	local ssectors = tDirectory:GetNext() -- SSECTORS
	local nodes = tDirectory:GetNext() -- NODES
	local sectors = tDirectory:GetNext() -- SECTORS
	tWadFile:ReadLump(linedefs, SendLump)
	coroutine.yield()
	tWadFile:ReadLump(sidedefs, SendLump)
	coroutine.yield()
	tWadFile:ReadLump(vertexes, SendLump)
	coroutine.yield()
	tWadFile:ReadLump(segs, SendLump)
	coroutine.yield()
	tWadFile:ReadLump(ssectors, SendLump)
	coroutine.yield()
	tWadFile:ReadLump(nodes, SendLump)
	coroutine.yield()
	tWadFile:ReadLump(sectors, SendLump)
	-- WAD should really have a close function
	tWadFile.fstream:Close()
	coroutine.yield()
	if index then timer.Destroy("DOOM.LoadMap"..tostring(index)) end
end

hook.Add("DOOM.PlayerInitialSpawn", "DOOM.LoadMap", function(ply)
	if not Map then return end
	local tWadFile = wad.Open(Map.wadname)
	local co = coroutine.wrap(Map.SendToClients)
	co(Map, tWadFile, ply)
	timer.Create("DOOM.LoadMap"..tostring(ply:EntIndex()), 0.5, 0, co)
end)

local function SendChangeFloor(sectorid, newpic, ply)
	net.Start("DOOM.ChangeFloorTexture")
	net.WriteInt(sectorid, 16)
	net.WriteString(newpic)
	if ply then net.Send(ply) else net.Broadcast() end
end

function MAP:ChangeFloorTexture(sector, newpic)
	sector.floorpic = newpic
	sector.floorpicchanged = true
	SendChangeFloor(sector.id, newpic)
end

hook.Add("DOOM.PlayerInitialSpawn", "DOOM.ChangeFloorTexture", function(ply)
	if not Map then return end
	for i = 1, #Map.Sectors do
		local sector = Map.Sectors[i]
		if sector.floorpicchanged then SendChangeFloor(sector.id, sector.floorpic, ply) end
	end
end)

local function SendChangeWall(sideid, where, newpic, ply)
	net.Start("DOOM.ChangeWallTexture")
	net.WriteInt(sideid, 16)
	net.WriteInt(where, 8)
	net.WriteString(newpic)
	if ply then net.Send(ply) else net.Broadcast() end
end

function MAP:ChangeWallTexture(sidedef, where, newpic)
	if where == 0 then
		sidedef.toptexture = newpic
	elseif where == 1 then
		sidedef.midtexture = newpic
	elseif where == 2 then
		sidedef.bottomtexture = newpic
	end
	sidedef.picchanged = true
	SendChangeWall(sidedef.id, where, newpic)
end

hook.Add("DOOM.PlayerInitialSpawn", "DOOM.ChangeWallTexture", function(ply)
	if not Map then return end
	for i = 1, #Map.Sidedefs do
		local sidedef = Map.Sidedefs[i]
		if sidedef.picchanged then
			SendChangeWall(sidedef.id, top, sidedef.toptexture)
			SendChangeWall(sidedef.id, middle, sidedef.midtexture)
			SendChangeWall(sidedef.id, bottom, sidedef.bottomtexture)
		end
	end
end)

if CLIENT then

local function ReceiveLinedefs(bits)
	local self = {}
	local total = bits / 8 / 14
	for i = 1, total do
		self[i] = {}
		self[i].v1 = net.ReadInt(16)
		self[i].v2 = net.ReadInt(16)
		self[i].flags = net.ReadInt(16)
		self[i].special = net.ReadInt(16)
		self[i].tag = net.ReadInt(16)
		self[i].sidenum = {}
		self[i].sidenum[1] = net.ReadInt(16)
		self[i].sidenum[2] = net.ReadInt(16)
	end
	return self
end

local function ReceiveSidedefs(bits)
	local self = {}
	local total = bits / 8 / 30
	for i = 1, total do
		self[i] = {}
		self[i].textureoffset = net.ReadInt(16)
		self[i].rowoffset = net.ReadInt(16) * HEIGHTCORRECTION
		self[i].toptexture = string.upper(string.TrimRight(net.ReadData(8), "\0"))
		self[i].bottomtexture = string.upper(string.TrimRight(net.ReadData(8), "\0"))
		self[i].midtexture = string.upper(string.TrimRight(net.ReadData(8), "\0"))
		self[i].sector = net.ReadInt(16)
	end
	return self
end

local function ReceiveVertexes(bits)
	local self = {}
	local total = bits / 8 / 4
	for i = 1, total do
		self[i] = {}
		self[i].x = net.ReadInt(16)
		self[i].y = net.ReadInt(16)
	end
	return self
end

local function ReceiveSegs(bits)
	local self = {}
	local total = bits / 8 / 12
	for i = 1, total do
		self[i] = {}
		self[i].v1 = net.ReadInt(16)
		self[i].v2 = net.ReadInt(16)
		self[i].angle = net.ReadInt(16)
		self[i].linedef = net.ReadInt(16)
		self[i].side = net.ReadInt(16)
		self[i].offset = net.ReadInt(16)
	end
	return self
end

local function ReceiveSubsectors(bits)
	local self = {}
	local total = bits / 8 / 4
	for i = 1, total do
		self[i] = {}
		self[i].numsegs = net.ReadInt(16)
		self[i].firstseg = net.ReadInt(16)
	end
	return self
end

local function ReceiveNodes(bits)
	local self = {}
	local total = bits / 8 / 28
	for i = 1, total do
		self[i] = {}
		self[i].x = net.ReadInt(16)
		self[i].y = net.ReadInt(16)
		self[i].dx = net.ReadInt(16)
		self[i].dy = net.ReadInt(16)
		self[i].bbox = {}
		for j = 1, 2 do
			self[i].bbox[j] = {}
			self[i].bbox[j].top = net.ReadInt(16)
			self[i].bbox[j].bottom = net.ReadInt(16)
			self[i].bbox[j].left = net.ReadInt(16)
			self[i].bbox[j].right = net.ReadInt(16)
		end
		self[i].children = {}
		self[i].children[1] = net.ReadUInt(16)
		self[i].children[2] = net.ReadUInt(16)
	end
	return self
end

local function ReceiveSectors(bits)
	local self = {}
	local total = bits / 8 / 26
	for i = 1, total do
		self[i] = {}
		self[i].floorheight = net.ReadInt(16) * HEIGHTCORRECTION
		self[i].ceilingheight = net.ReadInt(16) * HEIGHTCORRECTION
		self[i].floorpic = string.upper(string.TrimRight(net.ReadData(8), "\0"))
		self[i].ceilingpic = string.upper(string.TrimRight(net.ReadData(8), "\0"))
		self[i].lightlevel = net.ReadInt(16)
		self[i].special = net.ReadInt(16)
		self[i].tag = net.ReadInt(16)
	end
	return self
end

local readers = {
	[ML_LINEDEFS] = ReceiveLinedefs,
	[ML_SIDEDEFS] = ReceiveSidedefs,
	[ML_VERTEXES] = ReceiveVertexes,
	[ML_SEGS] = ReceiveSegs,
	[ML_SSECTORS] = ReceiveSubsectors,
	[ML_NODES] = ReceiveNodes,
	[ML_SECTORS] = ReceiveSectors
}

local typetoname = {
	[ML_LINEDEFS] = "Linedefs",
	[ML_SIDEDEFS] = "Sidedefs",
	[ML_VERTEXES] = "Vertexes",
	[ML_SEGS] = "Segs",
	[ML_SSECTORS] = "Subsectors",
	[ML_NODES] = "Nodes",
	[ML_SECTORS] = "Sectors"
}

local function ReceiveMap(bits)
	if Map and Map.loaded then Map = nil end
	if not Map then
		Map = setmetatable( {}, MAP )
		for k, v in pairs(typetoname) do
			Map[v] = {packetcount = 0}
		end
	end
	local type = net.ReadInt(8)
	local numpackets = net.ReadInt(8)
	local packet = net.ReadInt(8)
	local numentries = (bits-24) / 8 / datasize[type]
	local maxentries = math.floor(65530 / datasize[type])
	local name = typetoname[type]
	print(string.format("Receiving packet %i of %i, lump type %i, data size %i", packet+1, numpackets, type, (bits-24) / 8))
	AddMessage(string.format("%s map lump '%s'", (packet+1 == numpackets and "Received" or "Receiving"), name), 4)
	local data = readers[type](bits-24)
	local dest = Map[name]
	for i = 1, numentries do
		dest[maxentries*packet+i] = data[i]
	end
	dest.packetcount = dest.packetcount + 1
	if dest.packetcount == numpackets then dest.loaded = true end
	for k, v in pairs(typetoname) do
		if not Map[v].loaded then return end
	end
	Map:Setup()
	AddMessage("Map Spawning...", 4)
end

net.Receive("DOOM.Map", ReceiveMap)
net.Receive("DOOM.UnloadMap", function() Map = nil end)

local function ChangeFloorTexture(sector, newpic)
	sector.floorpic = newpic
	local meshes = Map.FloorMeshes[sector.id]
	for i = 1, #meshes do
		local submesh = meshes[i]
		if submesh.floor then submesh.material = GetFlatMaterial(newpic) end
	end
end

local PendingFloorChanges = {}

local function ApplyPendingFloorChanges()
	if Map and Map.loaded then
		for sectorid, newpic in pairs(PendingFloorChanges) do
			ChangeFloorTexture(Map.Sectors[sectorid], newpic)
			PendingFloorChanges[sectorid] = nil
		end
	else
		timer.Start("DOOM.ChangeFloorTexture")
	end
end

net.Receive("DOOM.ChangeFloorTexture", function()
	local sectorid = net.ReadInt(16)
	local newpic = net.ReadString()
	if Map and Map.loaded then
		local sector = Map.Sectors[sectorid]
		ChangeFloorTexture(sector, newpic)
	else
		PendingFloorChanges[sectorid] = newpic
		timer.Create("DOOM.ChangeFloorTexture", 1, 1, ApplyPendingFloorChanges)
	end
end)

local function ChangeWallTexture(sidedef, where, newpic)
	if where == 0 then
		sidedef.toptexture = newpic
	elseif where == 1 then
		sidedef.midtexture = newpic
	elseif where == 2 then
		sidedef.bottomtexture = newpic
	end
	local mesh = Map.SideMeshes[sidedef.id][where]
	if mesh then 
		mesh.material = mesh.flat and GetFlatMaterial(newpic) or GetTextureMaterial(newpic)
	end
end

local PendingWallChanges = {}

local function ApplyPendingWallChanges()
	if Map and Map.loaded then
		for sideid, walls in pairs(PendingWallChanges) do
			for where, newpic in pairs(walls) do
				ChangeWallTexture(Map.Sidedefs[sideid], where, newpic)
			end
			PendingWallChanges[sideid] = nil
		end
	else
		timer.Start("DOOM.ChangeWallTexture")
	end
end

net.Receive("DOOM.ChangeWallTexture", function()
	local sideid = net.ReadInt(16)
	local where = net.ReadInt(8)
	local newpic = net.ReadString()
	if Map and Map.loaded then
		local sidedef = Map.Sidedefs[sideid]
		ChangeWallTexture(sidedef, where, newpic)
	else
		PendingWallChanges[sideid] = PendingWallChanges[sideid] or {}
		PendingWallChanges[sideid][where] = newpic
		timer.Create("DOOM.ChangeWallTexture", 1, 1, ApplyPendingWallChanges)
	end
end)

end
