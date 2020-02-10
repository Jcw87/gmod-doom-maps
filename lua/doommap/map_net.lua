AddCSLuaFile()

local error = error
local pairs = pairs
local print = print
local setmetatable = setmetatable
local tostring = tostring

local coroutine = coroutine
local hook = hook
local math = math
local net = net
local string = string
local util = util
local table = table
local timer = timer
local wad = wad

setfenv( 1, DOOM )

if SERVER then
util.AddNetworkString("DOOM.Map")
util.AddNetworkString("DOOM.ReqMapChunk")
util.AddNetworkString("DOOM.MapChunk")
util.AddNetworkString("DOOM.UnloadMap")
util.AddNetworkString("DOOM.ChangeFloorTexture")
util.AddNetworkString("DOOM.ChangeWallTexture")
end

local function PrepareLumpSend(data)
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
	lump.hash = md5.sum(data)
	lump.numchunks = numchunks
	return lump
end

local lumpsendtypes = {
	ML_LINEDEFS,
	ML_SIDEDEFS,
	ML_VERTEXES,
	ML_SEGS,
	ML_SSECTORS,
	ML_NODES,
	ML_SECTORS,
}
lumpsendtypes.n = #lumpsendtypes

local function SendMapInfo(map, ply)
	local lumps = map.lumps
	net.Start("DOOM.Map")
	net.WriteString(map.wadname)
	net.WriteString(map.name)
	for i = 1, lumpsendtypes.n do
		local type = lumpsendtypes[i]
		net.WriteInt(lumps[type].numchunks, 8)
		net.WriteData(lumps[type].hash, 16)
	end
	if ply then net.Send(ply) else net.Broadcast() end
end

function MAP:SetupNet(wad)
	local lumpnum = wad:GetLumpNum(self.name)
	
	local lumps = {}
	lumps[ML_LINEDEFS] = PrepareLumpSend(wad:GetLumpByNum(lumpnum + ML_LINEDEFS):ReadString())
	lumps[ML_SIDEDEFS] = PrepareLumpSend(wad:GetLumpByNum(lumpnum + ML_SIDEDEFS):ReadString())
	lumps[ML_VERTEXES] = PrepareLumpSend(wad:GetLumpByNum(lumpnum + ML_VERTEXES):ReadString())
	lumps[ML_SEGS] = PrepareLumpSend(wad:GetLumpByNum(lumpnum + ML_SEGS):ReadString())
	lumps[ML_SSECTORS] = PrepareLumpSend(wad:GetLumpByNum(lumpnum + ML_SSECTORS):ReadString())
	lumps[ML_NODES] = PrepareLumpSend(wad:GetLumpByNum(lumpnum + ML_NODES):ReadString())
	lumps[ML_SECTORS] = PrepareLumpSend(wad:GetLumpByNum(lumpnum + ML_SECTORS):ReadString())
	self.lumps = lumps
	
	SendMapInfo(self)
end

hook.Add("DOOM.PlayerInitialSpawn", "DOOM.LoadMap", function(ply)
	if not Map then return end
	SendMapInfo(Map, ply)
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
	for i = 1, Map.Sectors.n do
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
	for i = 1, Map.Sidedefs.n do
		local sidedef = Map.Sidedefs[i]
		if sidedef.picchanged then
			SendChangeWall(sidedef.id, top, sidedef.toptexture, ply)
			SendChangeWall(sidedef.id, middle, sidedef.midtexture, ply)
			SendChangeWall(sidedef.id, bottom, sidedef.bottomtexture, ply)
		end
	end
end)

if CLIENT then

local readers = {
	[ML_LINEDEFS] = ReadLinedefs,
	[ML_SIDEDEFS] = ReadSidedefs,
	[ML_VERTEXES] = ReadVertexes,
	[ML_SEGS] = ReadSegs,
	[ML_SSECTORS] = ReadSubsectors,
	[ML_NODES] = ReadNodes,
	[ML_SECTORS] = ReadSectors
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

local function NextMissingChunk()
	local lumps = Map.lumps

	local nextlump
	local nextchunk
	local receivedchunks = 0
	local totalchunks = 0
	for i = 1, lumpsendtypes.n do
		local type = lumpsendtypes[i]
		local lump = lumps[type]
		totalchunks = totalchunks + lump.numchunks
		for j = 1, lump.numchunks do
			if lump[j] then receivedchunks = receivedchunks + 1 end
			if not nextchunk and not lump[j] then
				nextlump = type
				nextchunk = j
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

local function ReceiveMap(bits)
	local wadname = net.ReadString()
	local name = net.ReadString()
	print(string.format("Receiving info for %s/%s", wadname, name))
	if name == "" then return end
	
	Map = setmetatable( {}, MAP )
	Map.wadname = wadname
	Map.name = name
	
	local lumps = {}
	for i = 1, lumpsendtypes.n do
		local type = lumpsendtypes[i]
		lumps[type] = {
			numchunks = net.ReadInt(8),
			hash = net.ReadData(16),
		}
	end
	Map.lumps = lumps
	
	local wad = OpenWad(wadname)
	if wad then
		local lumpnum = wad:GetLumpNum(name)
		if lumpnum then
			for i = 1, lumpsendtypes.n do
				local type = lumpsendtypes[i]
				local lump = lumps[type]
				local data = wad:GetLumpByNum(lumpnum + type):ReadString()
				local hash = md5.sum(data)
				if hash == lump.hash then
					Map[typetoname[type]] = readers[type](stream.wrap(data))
					for j = 1, lump.numchunks do lump[j] = true end
				end
			end
		end
	end
	wad:Close()
	
	NextMissingChunk()
end

net.Receive("DOOM.Map", ReceiveMap)

local function ReceiveMapChunk(bits)
	if not Map then return end
	local type = net.ReadInt(8)
	local numchunk = net.ReadInt(8)
	local size = bits / 8 - 2
	local data = net.ReadData(size)
	local lumps = Map.lumps
	local lump = lumps[type]
	if not lump then error(string.format("received unknown lump type %i", type)) end
	lump[numchunk] = data
	print(string.format("Received chunk %i of %i, lump type %i, data size %i", numchunk, lump.numchunks, type, size))
	local allchunks = true
	for i = 1, lump.numchunks do
		if not lump[i] then allchunks = false end
	end
	if allchunks then
		local cdata = table.concat(lump)
		local data = util.Decompress(cdata)
		local s = stream.wrap(data)
		Map[typetoname[type]] = readers[type](s)
		lump.loaded = true
	end
	
	NextMissingChunk()
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
