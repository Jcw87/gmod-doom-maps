local bit = bit
local file = file
local io = io
local string = string

local error = error
local setmetatable = setmetatable
local type = type

local AddCSLuaFile = AddCSLuaFile

local BASE = {}
BASE.__index = BASE

function BASE:Size()
	error("not implemented")
end
function BASE:Seek()
	error("not implemented")
end
function BASE:Skip()
	error("not implemented")
end
function BASE:Tell()
	error("not implemented")
end
function BASE:Read()
	error("not implemented")
end
function BASE:Close()
	error("not implemented")
end

function BASE:ReadUInt8()
	local str = self:Read(1)
	local b1 = string.byte(str)
	return b1
end

function BASE:ReadSInt8()
	local str = self:Read(1)
	local b1 = string.byte(str)
	if b1 > 127 then b1 = b1 - 256 end
	return b1
end

function BASE:ReadUInt16LE()
	local str = self:Read(2)
	local b1, b2 = string.byte(str, 1, 2)
	return b1 + b2 * 256
end

function BASE:ReadSInt16LE()
	local str = self:Read(2)
	local b1, b2 = string.byte(str, 1, 2)
	if b2 > 127 then b2 = b2 - 256 end
	return b1 + b2 * 256
end

function BASE:ReadUInt24LE()
	local str = self:Read(3)
	local b1, b2, b3 = string.byte(str, 1, 3)
	return b1 + b2 * 256 + b3 * 65536
end

function BASE:ReadSInt24LE()
	local str = self:Read(3)
	local b1, b2, b3 = string.byte(str, 1, 3)
	if b3 > 127 then b3 = b3 - 256 end
	return b1 + b2 * 256 + b3 * 65536
end

function BASE:ReadUInt32LE()
	local str = self:Read(4)
	local b1, b2, b3, b4 = string.byte(str, 1, 4)
	return b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
end

function BASE:ReadSInt32LE()
	local str = self:Read(4)
	local b1, b2, b3, b4 = string.byte(str, 1, 4)
	if b4 > 127 then b4 = b4 - 256 end
	return b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
end

function BASE:ReadUInt16BE()
	local str = self:Read(2)
	local b1, b2 = string.byte(str, 1, 2)
	return b1 * 256 + b2
end

function BASE:ReadSInt16BE()
	local str = self:Read(2)
	local b1, b2 = string.byte(str, 1, 2)
	if b1 > 127 then b1 = b1 - 256 end
	return b1 * 256 + b2
end

function BASE:ReadUInt24BE()
	local str = self:Read(3)
	local b1, b2, b3 = string.byte(str, 1, 3)
	return b1 * 65536 + b2 * 256 + b3
end

function BASE:ReadSInt24BE()
	local str = self:Read(3)
	local b1, b2, b3 = string.byte(str, 1, 3)
	if b1 > 127 then b1 = b1 - 256 end
	return b1 * 65536 + b2 * 256 + b3
end

function BASE:ReadUInt32BE()
	local str = self:Read(4)
	local b1, b2, b3, b4 = string.byte(str, 1, 4)
	return b1 * 16777216 + b2 * 65536 + b3 * 256 + b4
end

function BASE:ReadSInt32BE()
	local str = self:Read(4)
	local b1, b2, b3, b4 = string.byte(str, 1, 4)
	if b1 > 127 then b1 = b1 - 256 end
	return b1 * 16777216 + b2 * 65536 + b3 * 256 + b4
end

local function ReadFloat32(x)
	-- code found on the interwebs
	local sign = 1
	local mantissa = string.byte(x, 3) % 128

	for i = 2, 1, -1 do mantissa = mantissa * 256 + string.byte(x, i) end

	if string.byte(x, 4) > 127 then sign = -1 end
	local exponent = (string.byte(x, 4) % 128) * 2 +
	math.floor(string.byte(x, 3) / 128)
	if exponent == 0 then return 0 end
	mantissa = (math.ldexp(mantissa, -23) + 1) * sign
	return math.ldexp(mantissa, exponent - 127)
end

function BASE:ReadFloat32LE()
	return ReadFloat32(self:Read(4))
end

function BASE:ReadFloat32BE()
	return ReadFloat32(string.reverse(self:Read(4)))
end

function BASE:Write(str)
	error("not implemented")
end

function BASE:WriteUInt8(n)
	local b1 = bit.band(n, 0xFF)
	self:Write(string.char(b1))
end

BASE.WriteSInt8 = BASE.WriteUInt8

function BASE:WriteUInt16LE(n)
	local b1 = bit.band(n, 0x00FF)
	local b2 = bit.rshift(bit.band(n, 0xFF00), 8)
	self:Write(string.char(b1, b2))
end

function BASE:WriteSInt16LE(n)
	self:WriteUInt16LE(bit.band(n, 0xFFFF))
end

function BASE:WriteUInt24LE(n)
	local b1 = bit.band(n, 0x0000FF)
	local b2 = bit.rshift(bit.band(n, 0x00FF00), 8)
	local b3 = bit.rshift(bit.band(n, 0xFF0000), 16)
	self:Write(string.char(b1, b2, b3))
end

function BASE:WriteSInt24LE(n)
	self:WriteUInt24LE(bit.band(n, 0xFFFFFF))
end

function BASE:WriteUInt32LE(n)
	local b1 = bit.band(n, 0x000000FF)
	local b2 = bit.rshift(bit.band(n, 0x0000FF00), 8)
	local b3 = bit.rshift(bit.band(n, 0x00FF0000), 16)
	local b4 = bit.rshift(bit.band(n, 0xFF000000), 24)
	self:Write(string.char(b1, b2, b3, b4))
end

function BASE:WriteSInt32LE(n)
	self:WriteUInt32LE(bit.band(n, 0xFFFFFFFF))
end

function BASE:WriteUInt16BE(n)
	local b2 = bit.band(n, 0x00FF)
	local b1 = bit.rshift(bit.band(n, 0xFF00), 8)
	self:Write(string.char(b1, b2))
end

function BASE:WriteSInt16BE(n)
	self:WriteUInt16BE(bit.band(n, 0xFFFF))
end

function BASE:WriteUInt24BE(n)
	local b3 = bit.band(n, 0x0000FF)
	local b2 = bit.rshift(bit.band(n, 0x00FF00), 8)
	local b1 = bit.rshift(bit.band(n, 0xFF0000), 16)
	self:Write(string.char(b1, b2, b3))
end

function BASE:WriteSInt24BE(n)
	self:WriteUInt24BE(bit.band(n, 0xFFFFFF))
end

function BASE:WriteUInt32BE(n)
	local b4 = bit.band(n, 0x000000FF)
	local b3 = bit.rshift(bit.band(n, 0x0000FF00), 8)
	local b2 = bit.rshift(bit.band(n, 0x00FF0000), 16)
	local b1 = bit.rshift(bit.band(n, 0xFF000000), 24)
	self:Write(string.char(b1, b2, b3, b4))
end

function BASE:WriteSInt32BE(n)
	self:WriteUInt32BE(bit.band(n, 0xFFFFFFFF))
end


function BASE:Writef(...)
	self:Write(string.format(...))
end

local STRING = {}
STRING.__index = STRING
setmetatable(STRING, BASE)

function STRING:Size()
	return #self.o
end

function STRING:Seek(offset)
	self.npos = offset
end

function STRING:Skip(offset)
	self.npos = self.npos + offset
end

function STRING:Tell()
	return self.npos
end

function STRING:Read(size)
	local str = string.sub(self.o, self.npos + 1, self.npos + size)
	self.npos = self.npos + size
	return str
end

function STRING:Close()
	self.o = nil
end

local LUA_IO = {}
LUA_IO.__index = LUA_IO
setmetatable(LUA_IO, BASE)

function LUA_IO:Size()
	local old = self.o:seek()
	local len = self.o:seek("end")
	self.o:seek("set", old)
	return len
end

function LUA_IO:Seek(offset)
	self.o:seek("set", offset)
end

function LUA_IO:Skip(offset)
	self.o:seek("cur", offset)
end

function LUA_IO:Tell()
	return self.o:seek()
end

function LUA_IO:Read(size)
	return self.o:read(size)
end

function LUA_IO:Write(str)
	self.o:write(str)
end

function LUA_IO:Close()
	self.o:close()
	self.o = nil
end

local GMOD_FILE = {}
GMOD_FILE.__index = GMOD_FILE
setmetatable(GMOD_FILE, BASE)

function GMOD_FILE:Size()
	return self.o:Size()
end

function GMOD_FILE:Seek(offset)
	self.o:Seek(offset)
end

function GMOD_FILE:Skip(offset)
	self.o:Skip(offset)
end

function GMOD_FILE:Tell()
	return self.o:Tell()
end

function GMOD_FILE:Read(size)
	return self.o:Read(size)
end

function GMOD_FILE:ReadUInt8()
	local n = self.o:ReadByte()
	return n
end

function GMOD_FILE:ReadSInt8()
	local n = self.o:ReadByte()
	if n > 127 then n = n - 256 end
	return n
end

function GMOD_FILE:ReadUInt16LE()
	local n = self.o:ReadShort()
	return bit.band(n, 65535)
end

function GMOD_FILE:ReadSInt16LE()
	local n = self.o:ReadShort()
	return n
end

function GMOD_FILE:ReadUInt32LE()
	local n = self.o:ReadLong()
	return bit.band(n, 4294967295)
end

function GMOD_FILE:ReadSInt32LE()
	local n = self.o:ReadLong()
	return n
end

function GMOD_FILE:ReadFloat32LE()
	local n = self.o:ReadFloat()
	return n
end

function GMOD_FILE:Write(str)
	self.o:Write(str)
end

function GMOD_FILE:WriteUInt8(n)
	self.o:WriteByte(n)
end

function GMOD_FILE:WriteSInt16LE(n)
	self.o:WriteShort(n)
end

function GMOD_FILE:WriteSInt32LE(n)
	self.o:WriteLong(n)
end

function GMOD_FILE:Close()
	self.o:Close()
	self.o = nil
end

module("DOOM.stream")

if type(io) == "table" and type(io.open) == "function" then
	-- Standard Lua
	function open(fname, mode)
		return wrap(io.open(fname, mode))
	end
elseif type(file) == "table" and type(file.Open) == "function" and AddCSLuaFile then
	-- Garry's Mod
	AddCSLuaFile()
	function open(fname, mode)
		local f = file.Open(fname, mode, "DATA")
		if not f then f = file.Open(fname, mode, "GAME") end
		return wrap(f)
	end
end

function wrap(object)
	local t = {}
	t.o = object

	local type1 = type(object)

	if type1 == "string" then
		setmetatable(t, STRING)
		t.npos = 0
	elseif type1 == "userdata" and io and io.type and io.type(object) and io.type(object) == "file" then
		setmetatable(t, LUA_IO)
	elseif type1 == "File" and AddCSLuaFile then
		setmetatable(t, GMOD_FILE)
	else
		error(string.format("Unknown object type '%s' for stream!", type1))
	end

	return t
end
