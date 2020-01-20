AddCSLuaFile()

local error = error
local pairs = pairs
local print = print
local setmetatable = setmetatable
local tostring = tostring

local coroutine = coroutine
local hook = hook
local net = net
local math = math
local string = string
local util = util
local table = table
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
util.AddNetworkString("DOOM.ReqMapChunk")
util.AddNetworkString("DOOM.MapChunk")
util.AddNetworkString("DOOM.UnloadMap")
util.AddNetworkString("DOOM.ChangeFloorTexture")
util.AddNetworkString("DOOM.ChangeWallTexture")
end

local function PrepareLumpSend(fstream, tLumpInfo)
	local data = fstream:Read(tLumpInfo.iSize)
	local cdata = util.Compress(data)
	local csize = #cdata
	local maxsize = 65530
	local numchunks = math.ceil(csize / maxsize)
	local lump = {}
	for i = 1, numchunks do
		local start = (i - 1) * maxsize
		local size = i < numchunks and maxsize or csize - start
		lump[i] = string.sub(cdata, start + 1, start + size)
	end
	lump.numchunks = numchunks
	return lump
end

-- TODO: add lump hashes/checksums so that maps can be loaded locally if available
function MAP:SetupNet(tWadFile)
	local tDirectory = tWadFile:GetDirectory()
	tDirectory:ResetReadIndex()
	tDirectory:FindNextNamed(self.name)
	
	local lumps = {}
	tDirectory:GetNext() -- THINGS
	lumps[ML_LINEDEFS] = tWadFile:ReadLump(tDirectory:GetNext(), PrepareLumpSend)
	lumps[ML_SIDEDEFS] = tWadFile:ReadLump(tDirectory:GetNext(), PrepareLumpSend)
	lumps[ML_VERTEXES] = tWadFile:ReadLump(tDirectory:GetNext(), PrepareLumpSend)
	lumps[ML_SEGS] = tWadFile:ReadLump(tDirectory:GetNext(), PrepareLumpSend)
	lumps[ML_SSECTORS] = tWadFile:ReadLump(tDirectory:GetNext(), PrepareLumpSend)
	lumps[ML_NODES] = tWadFile:ReadLump(tDirectory:GetNext(), PrepareLumpSend)
	lumps[ML_SECTORS] = tWadFile:ReadLump(tDirectory:GetNext(), PrepareLumpSend)
	self.lumps = lumps
	
	net.Start("DOOM.Map")
	net.WriteString(self.name)
	net.WriteInt(lumps[ML_LINEDEFS].numchunks, 8)
	net.WriteInt(lumps[ML_SIDEDEFS].numchunks, 8)
	net.WriteInt(lumps[ML_VERTEXES].numchunks, 8)
	net.WriteInt(lumps[ML_SEGS].numchunks, 8)
	net.WriteInt(lumps[ML_SSECTORS].numchunks, 8)
	net.WriteInt(lumps[ML_NODES].numchunks, 8)
	net.WriteInt(lumps[ML_SECTORS].numchunks, 8)
	net.Broadcast()
end

hook.Add("DOOM.PlayerInitialSpawn", "DOOM.LoadMap", function(ply)
	if not Map then return end
	local lumps = Map.lumps
	net.Start("DOOM.Map")
	net.WriteString(Map.name)
	net.WriteInt(#lumps[ML_LINEDEFS], 8)
	net.WriteInt(#lumps[ML_SIDEDEFS], 8)
	net.WriteInt(#lumps[ML_VERTEXES], 8)
	net.WriteInt(#lumps[ML_SEGS], 8)
	net.WriteInt(#lumps[ML_SSECTORS], 8)
	net.WriteInt(#lumps[ML_NODES], 8)
	net.WriteInt(#lumps[ML_SECTORS], 8)
	net.Send(ply)
end)

net.Receive("DOOM.ReqMapChunk", function(bits, ply)
	if not Map then return end
	local type = net.ReadInt(8)
	local numchunk = net.ReadInt(8)
	local lump = Map.lumps[type]
	if not lump then print(string.format("Player '%s' requested invalid lump type %i", ply:GetName(), type)) return end
	local data = lump[numchunk]
	if not data then print(string.format("Player '%s' requested invalid chunk %i from lump %i", ply:GetName(), numchunk, type)) return end
	local size = #data
	print(string.format("Sending chunk %i of %i, lump type %i, data size %i to player %s", numchunk, lump.numchunks, type, size, ply:GetName()))
	net.Start("DOOM.MapChunk")
	net.WriteInt(type, 8)
	net.WriteInt(numchunk, 8)
	net.WriteData(data, size)
	net.Send(ply)
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

local function ReceiveMap(bits)
	local name = net.ReadString()
	print(string.format("Receiving info for map '%s'", name))
	if name == "" then return end
	
	Map = setmetatable( {}, MAP )
	Map.name = name
	Map.lumps = {
		[ML_LINEDEFS] = { numchunks = net.ReadInt(8) },
		[ML_SIDEDEFS] = { numchunks = net.ReadInt(8) },
		[ML_VERTEXES] = { numchunks = net.ReadInt(8) },
		[ML_SEGS] = { numchunks = net.ReadInt(8) },
		[ML_SSECTORS] = { numchunks = net.ReadInt(8) },
		[ML_NODES] = { numchunks = net.ReadInt(8) },
		[ML_SECTORS] = { numchunks = net.ReadInt(8) }
	}
	
	net.Start("DOOM.ReqMapChunk")
	net.WriteInt(ML_LINEDEFS, 8)
	net.WriteInt(1, 8)
	net.SendToServer()
end

net.Receive("DOOM.Map", ReceiveMap)

local function ReceiveLinedefs(s, size)
	local self = {}
	local total = size / 14
	for i = 1, total do
		self[i] = {}
		self[i].v1 = s:ReadUInt16LE()
		self[i].v2 = s:ReadUInt16LE()
		self[i].flags = s:ReadUInt16LE()
		self[i].special = s:ReadUInt16LE()
		self[i].tag = s:ReadUInt16LE()
		self[i].sidenum = {}
		self[i].sidenum[1] = s:ReadUInt16LE()
		self[i].sidenum[2] = s:ReadUInt16LE()
	end
	return self
end

local function ReceiveSidedefs(s, size)
	local self = {}
	local total = size / 30
	for i = 1, total do
		self[i] = {}
		self[i].textureoffset = s:ReadSInt16LE()
		self[i].rowoffset = s:ReadSInt16LE() * HEIGHTCORRECTION
		self[i].toptexture = string.upper(string.TrimRight(s:Read(8), "\0"))
		self[i].bottomtexture = string.upper(string.TrimRight(s:Read(8), "\0"))
		self[i].midtexture = string.upper(string.TrimRight(s:Read(8), "\0"))
		self[i].sector = s:ReadSInt16LE()
	end
	return self
end

local function ReceiveVertexes(s, size)
	local self = {}
	local total = size / 4
	for i = 1, total do
		self[i] = {}
		self[i].x = s:ReadSInt16LE()
		self[i].y = s:ReadSInt16LE()
	end
	return self
end

local function ReceiveSegs(s, size)
	local self = {}
	local total = size / 12
	for i = 1, total do
		self[i] = {}
		self[i].v1 = s:ReadUInt16LE()
		self[i].v2 = s:ReadUInt16LE()
		self[i].angle = s:ReadSInt16LE()
		self[i].linedef = s:ReadUInt16LE()
		self[i].side = s:ReadUInt16LE()
		self[i].offset = s:ReadSInt16LE()
	end
	return self
end

local function ReceiveSubsectors(s, size)
	local self = {}
	local total = size / 4
	for i = 1, total do
		self[i] = {}
		self[i].numsegs = s:ReadSInt16LE()
		self[i].firstseg = s:ReadSInt16LE()
	end
	return self
end

local function ReceiveNodes(s, size)
	local self = {}
	local total = size / 28
	for i = 1, total do
		self[i] = {}
		self[i].x = s:ReadSInt16LE()
		self[i].y = s:ReadSInt16LE()
		self[i].dx = s:ReadSInt16LE()
		self[i].dy = s:ReadSInt16LE()
		self[i].bbox = {}
		for j = 1, 2 do
			self[i].bbox[j] = {}
			self[i].bbox[j].top = s:ReadSInt16LE()
			self[i].bbox[j].bottom = s:ReadSInt16LE()
			self[i].bbox[j].left = s:ReadSInt16LE()
			self[i].bbox[j].right = s:ReadSInt16LE()
		end
		self[i].children = {}
		self[i].children[1] = s:ReadUInt16LE()
		self[i].children[2] = s:ReadUInt16LE()
	end
	return self
end

local function ReceiveSectors(s, size)
	local self = {}
	local total = size / 26
	for i = 1, total do
		self[i] = {}
		self[i].floorheight = s:ReadSInt16LE() * HEIGHTCORRECTION
		self[i].ceilingheight = s:ReadSInt16LE() * HEIGHTCORRECTION
		self[i].floorpic = string.upper(string.TrimRight(s:Read(8), "\0"))
		self[i].ceilingpic = string.upper(string.TrimRight(s:Read(8), "\0"))
		self[i].lightlevel = s:ReadSInt16LE()
		self[i].special = s:ReadUInt16LE()
		self[i].tag = s:ReadUInt16LE()
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

local function ReceiveMapChunk(bits)
	if not Map then return end
	local type = net.ReadInt(8)
	local numchunk = net.ReadInt(8)
	local size = bits / 8 - 2
	local data = net.ReadData(size)
	local lump = Map.lumps[type]
	if not lump then error(string.format("received unknown lump type %i", type)) end
	lump[numchunk] = data
	local name = typetoname[type]
	print(string.format("Received chunk %i of %i, lump type %i, data size %i", numchunk, lump.numchunks, type, size))
	local allchunks = true
	for i = 1, lump.numchunks do
		if not lump[i] then allchunks = false end
	end
	if allchunks then
		local cdata = table.concat(lump)
		local data = util.Decompress(cdata)
		local s = stream.wrap(data)
		Map[name] = readers[type](s, #data)
		lump.loaded = true
	end
	
	local receivedchunks = 0
	local totalchunks = 0
	local nextlump
	local nextchunk
	for k, v in pairs(typetoname) do
		local lump = Map.lumps[k]
		totalchunks = totalchunks + lump.numchunks
		for i = 1, lump.numchunks do
			if lump[i] then receivedchunks = receivedchunks + 1 end
			if not nextlump and not lump[i] then
				nextlump = k
				nextchunk = i
			end
		end
	end
	
	AddMessage(string.format("Receiving map %s: %i/%i", Map.name, receivedchunks, totalchunks), 4)
	
	if nextlump then
		net.Start("DOOM.ReqMapChunk")
		net.WriteInt(nextlump, 8)
		net.WriteInt(nextchunk, 8)
		net.SendToServer()
	else
		Map:Setup()
		AddMessage("Map Spawning...", 4)
	end
end

net.Receive("DOOM.MapChunk", ReceiveMapChunk)
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
