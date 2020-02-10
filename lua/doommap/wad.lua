AddCSLuaFile()

local error = error
local getmetatable = getmetatable
local setmetatable = setmetatable

local string = string
local table = table

local bit = bit
local file = file

setfenv( 1, DOOM )

local function errorf(...) error(string.format(...)) end

LUMPDESCRIPTOR = {}
LUMPDESCRIPTOR.__index = LUMPDESCRIPTOR

function LUMPDESCRIPTOR:GetName() return self.name end
function LUMPDESCRIPTOR:GetSize() return self.size end
function LUMPDESCRIPTOR:GetWad() return self.wad end
function LUMPDESCRIPTOR:ReadString()
	local s = self.wad.s
	s:Seek(self.offset)
	return s:Read(self.size)
end
function LUMPDESCRIPTOR:ReadStream() return stream.wrap(self:ReadString()) end

WAD = {}
WAD.__index = WAD

function WAD:GetName() return self.filename end
function WAD:GetSize() return self.s:Size() end
function WAD:GetNumLumps() return #self.directory end
function WAD:GetLumpNum(name) return self.lookup[name] end
function WAD:GetLumpByNum(num) return self.directory[num] end
function WAD:GetLumpByName(name)
	local num = self:GetLumpNum(name)
	if num then return self.directory[num] end
end
function WAD:Close() self.s:Close() end

function OpenWad(filename)
	local fstream = file.Open(filename, "rb", "GAME")
	if not fstream then return end
	local s = stream.wrap(fstream)
	local size = s:Size()
	
	local ident = s:Read(4)
	if ident ~= "IWAD" and ident ~= "PWAD" then errorf("'%s' is not a valid WAD file", filename) end
	local numlumps = s:ReadUInt32LE()
	local diroffset = s:ReadUInt32LE()
	if diroffset < 0 or diroffset + numlumps * 16 > size then errorf("'%s' is not a valid WAD file", filename) end
	
	s:Seek(diroffset)
	local wad = setmetatable({}, WAD)
	wad.s = s
	wad.filename = filename
	local lookup = {}
	local directory = {}
	for i = 1, numlumps do
		local lump = setmetatable({}, LUMPDESCRIPTOR)
		lump.offset = s:ReadUInt32LE()
		lump.size = s:ReadUInt32LE()
		if bit.band(s:ReadUInt8(), 0x80) > 0 then error("WADs with compressed lumps are not supported") end
		s:Skip(-1)
		lump.name = s:Read(8):TrimRight("\0"):upper()
		lump.wad = wad
		if (lump.offset < 0) or (lump.offset + lump.size > size) then errorf("'%s' is not a valid WAD file", filename) end
		table.insert(directory, lump)
		lookup[lump.name] = i
	end
	wad.directory = directory
	wad.lookup = lookup
	return wad
end

local WAD_COLLECTION = {}
WAD_COLLECTION.__index = WAD_COLLECTION
WAD_COLLECTION.GetNumLumps = WAD.GetNumLumps
WAD_COLLECTION.GetLumpNum = WAD.GetLumpNum
WAD_COLLECTION.GetLumpByNum = WAD.GetLumpByNum
WAD_COLLECTION.GetLumpByName = WAD.GetLumpByName
function WAD_COLLECTION:Close()
	for i = 1, #self.wads do
		self.wads[i]:Close()
	end
end

function CreateWadCollection(...)
	args = {...}
	local lookup = {}
	local directory = {}
	local wads = {}
	local insert = 1
	for iwad = 1, #args do
		local wad = args[iwad]
		if getmetatable(wad) ~= WAD then errorf("arg %i is not a WAD", iwad) end
		table.insert(wads, wad)
		for ilump = 1, #wad.directory do
			local lump = wad.directory[ilump]
			table.insert(directory, lump)
			lookup[lump.name] = insert
			insert = insert + 1
		end
	end
	local collection = setmetatable({}, WAD_COLLECTION)
	collection.wads = wads
	collection.directory = directory
	collection.lookup = lookup
	return collection
end
