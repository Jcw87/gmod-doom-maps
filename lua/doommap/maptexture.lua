AddCSLuaFile()

local concommand = concommand
local error = error
local pairs = pairs
local pcall = pcall
local setmetatable = setmetatable
local tobool = tobool

local CreateMaterial = CreateMaterial
local GetRenderTargetEx = GetRenderTargetEx
local Material = Material
local ScrH = ScrH
local ScrW = ScrW
local SysTime = SysTime

local bit = bit
local cam = cam
local engine = engine
local hook = hook
local math = math
local render = render
local string = string
local surface = surface
local table = table
local wad = wad

local MATERIAL_RT_DEPTH_NONE = MATERIAL_RT_DEPTH_NONE
local MATERIAL_RT_DEPTH_SEPARATE = MATERIAL_RT_DEPTH_SEPARATE
local MATERIAL_RT_DEPTH_SHARED = MATERIAL_RT_DEPTH_SHARED
local RT_SIZE_DEFAULT = RT_SIZE_DEFAULT
local RT_SIZE_NO_CHANGE = RT_SIZE_NO_CHANGE
local RT_SIZE_OFFSCREEN = RT_SIZE_OFFSCREEN
local STENCIL_ALWAYS = STENCIL_ALWAYS
local STENCIL_EQUAL = STENCIL_EQUAL
local STENCIL_KEEP = STENCIL_KEEP
local STENCIL_REPLACE = STENCIL_REPLACE

local IMAGE_FORMAT_RGB888 = IMAGE_FORMAT_RGB888
local IMAGE_FORMAT_RGBA8888 = IMAGE_FORMAT_RGBA8888

local bWindows = system.IsWindows()

setfenv( 1, DOOM )

local iTexFlags = bit.bor(
	TEXTUREFLAGS_POINTSAMPLE,
	TEXTUREFLAGS_SINGLECOPY,
	TEXTUREFLAGS_RENDERTARGET,
	--TEXTUREFLAGS_NODEPTHBUFFER,
	TEXTUREFLAGS_PROCEDURAL
)

local function ReadPnames( fstream )
	local self = {}
	local nummappatches = fstream:ReadLong()
	for i = 1, nummappatches do
		self[i] = string.upper( string.TrimRight( fstream:Read( 8 ), "\0" ) )
	end
	return self
end

MAPTEXTURE = MAPTEXTURE or {}
MAPTEXTURE.__index = MAPTEXTURE

local function ReadMapTexture( fstream )
	local self = setmetatable( {}, MAPTEXTURE )

	self.name = string.TrimRight( fstream:Read( 8 ), "\0" )
	self.masked = tobool( fstream:ReadLong() )
	self.width = fstream:ReadShort()
	self.height = fstream:ReadShort()
	self.columndirectory = fstream:ReadLong() // OBSOLETE
	self.patchcount = fstream:ReadShort()
	self.patches = {}
	for i = 1, self.patchcount do
		local patch = {}
		patch.originx = fstream:ReadShort()
		patch.originy = fstream:ReadShort()
		patch.patch = fstream:ReadShort()
		patch.stepdir = fstream:ReadShort()
		patch.colormap = fstream:ReadShort()
		self.patches[i] = patch
	end
	return self
end

local function ReadTextureLump( fstream )
	local self = {}
	local start = fstream:Tell()
	local numtextures = fstream:ReadLong()
	local offsets = {}
	for i = 1, numtextures do
		offsets[i] = fstream:ReadLong()
	end
	for i = 1, numtextures do
		fstream:Seek( start+offsets[i] )
		self[i] = ReadMapTexture( fstream )
	end
	return self
end

local function SetupTextures(pnames, textures)
	for i = 1, #textures do
		local maptexture = textures[i]
		for j = 1, #maptexture.patches do
			local patch = maptexture.patches[j]
			patch.patch = pnames[patch.patch+1]
		end
		if CLIENT then maptexture:AllocateTexture() end
	end
end

local tTextures = {}
local tUninitializedTextures = {}

function LoadTextureLumps(tWadFile)
	if not tWadFile then return end
	local tDirectory = tWadFile:GetDirectory()

	-- PNAMES
	tDirectory:ResetReadIndex()
	local tLumpInfo = tDirectory:FindNextNamed( "PNAMES" )
	if not tLumpInfo then return end
	local pnames = tWadFile:ReadLump( tLumpInfo, ReadPnames )
	
	-- TEXTURES
	local textures = {}
	tDirectory:ResetReadIndex()
	tLumpInfo = tDirectory:FindNextNamed( "TEXTURE1" )
	table.Add( textures, tWadFile:ReadLump( tLumpInfo, ReadTextureLump ) )
	tLumpInfo = tDirectory:FindNextNamed("TEXTURE2")
	if tLumpInfo then table.Add( textures, tWadFile:ReadLump( tLumpInfo, ReadTextureLump ) ) end

	-- put them together
	SetupTextures(pnames, textures)
	for i = 1, #textures do
		local maptexture = textures[i]
		local name = maptexture.name
		table.insert(tTextures, maptexture)
	end
end

local matNULL
if CLIENT then matNULL = Material("Debug/debugempty") end

function GetMapTexture(name)
	for i = 1, #tTextures do
		if tTextures[i].name == name then
			local texture = tTextures[i]
			if not texture.loaded then tUninitializedTextures[texture] = true end
			return texture
		end
	end
	local maptexture = {width = 64, height = 64}
	if CLIENT then maptexture.texture = matNULL:GetTexture("$basetexture") end
	return maptexture
end

function LoadTextures()
	--[[
	local tWadFile = wad.Open("DOOM.WAD")
	if tWadFile then
		LoadTextureLumps(tWadFile)
		tWadFile.fstream:Close()
	end
	tWadFile = wad.Open("DOOM2.WAD")
	if tWadFile then
		LoadTextureLumps(tWadFile)
		tWadFile.fstream:Close()
	end
	]]
	LoadTextureLumps(GetWad())
end

if CLIENT then

local function InDirectX80() -- I have no idea what render.GetDXLevel() returns on OSX.
	return ( bWindows and ( render.GetDXLevel() < 90 ) )
end

local function NextPowerOfTwo( i )
	local val = 1
	while val < i do
		val = val * 2
	end
	return val
end
--[[
local function Patch_WriteToTexture(self, tex, tPalette)
	local oldRT = render.GetRenderTarget()
	local oldW, oldH = ScrW(), ScrH()
	render.Clear( 0, 0, 0, 0, true, true )
	if ( not InDirectX80() ) then
		render.CopyRenderTargetToTexture( tex )
	end
	render.SetRenderTarget( tex )
	render.Clear( 0, 0, 0, 0, true, true )
	render.SetViewPort( 0, 0, self.w, self.h )
	cam.Start2D()
	
	render.PushFilterMin(1)
	--render.OverrideDepthEnable( true, true )
	render.SetBlend( 1 )
	render.SetColorModulation( 1, 1, 1 )
	self:Draw( tPalette )
	--render.OverrideDepthEnable( false, false )
	render.PopFilterMin()
	render.SetRenderTarget( oldRT )
	cam.End2D()
	render.SetViewPort( 0, 0, oldW, oldH )
end

local function Patch_AllocateTexture(self, name)
	local pow2width = NextPowerOfTwo(self.w)
	local pow2height = NextPowerOfTwo(self.h)
	local bAlpha = self.bAlpha
	if pow2width ~= self.w or pow2height ~= self.h then bAlpha = true end
	local iFormat = bAlpha and IMAGE_FORMAT_RGBA8888 or IMAGE_FORMAT_RGB888
	local iDepthType = InDirectX80() and MATERIAL_RT_DEPTH_SHARED or MATERIAL_RT_DEPTH_NONE
	return GetRenderTargetEx( "doom/patches/"..name, pow2width, pow2height, RT_SIZE_NO_CHANGE, iDepthType, iTexFlags, 0, iFormat )
end

local tPatches = {}
local tUninitializedPatches = {}

function GetPatchTexture(name)
	if tPatches[name] then return tPatches[name] end
	local tWadFile = GetWad()
	if not tWadFile then
		local patch = {width = 64, height = 64, texture = matNULL:GetTexture("$basetexture")}
		tPatches[name] = patch
		return patch
	end
	local tPic = LoadNamedPicture(tWadFile, name)
	if not tPic then
		local patch = {width = 64, height = 64, texture = matNULL:GetTexture("$basetexture")}
		tPatches[name] = patch
		return patch
	end
	local tPalette = GetDefaultPalette()
	local tex = Patch_AllocateTexture(tPic, name)
	local patch = {width = tPic.w, height = tPic.h, texture = tex, name = name}
	tPatches[name] = patch
	tUninitializedPatches[patch] = tPic
	return patch
end

function ReloadPatch( patch )
	local tWadFile = GetWad()
	if not tWadFile then return end
	tUninitializedPatches[patch] = LoadNamedPicture(tWadFile, patch.name)
end

local bFirstFrame = true

hook.Add("PreRender", "DOOM.WritePatches", function()
	if bFirstFrame then bFirstFrame = false return end
	local tPalette = GetDefaultPalette()
	local timeMaxWriteTime = CvarGet( "cl_texwrite_timeout" )
	local timeStart = SysTime()
	for patch, tPic in pairs(tUninitializedPatches) do
		Patch_WriteToTexture(tPic, patch.texture, tPalette)
		tUninitializedPatches[patch] = nil
		print(patch.name)
		if timeMaxWriteTime ~= 0 and SysTime() - timeStart > timeMaxWriteTime and not engine.IsPlayingDemo() then break end
	end
end)

local tPatchMaterials = {}

function GetPatchMaterial(name)
	if tPatchMaterials[name] then return tPatchMaterials[name] end
	local material = CreateMaterial("doom/patches/"..name, "UnlitGeneric", {["$alphatest"] = "1", ["$vertexcolor"] = "1"})
	material:SetTexture("$basetexture", GetPatchTexture(name).texture)
	tPatchMaterials[name] = material
	return material
end
]]
local tFlatMaterials = {F_SKY1 = Material("doom/floors/f_sky1")}
--local tFlatMaterials = {}

function GetFlatMaterial(name)
	if tFlatMaterials[name] then return tFlatMaterials[name] end
	local material = CreateMaterial("doom/flats/"..name, "UnlitGeneric", {["$vertexcolor"] = "1"})
	material:SetTexture("$basetexture", GetFlatTexture(name))
	tFlatMaterials[name] = material
	return material
end

local tTextureMaterials = {}

function GetTextureMaterial(name)
	if tTextureMaterials[name] then return tTextureMaterials[name] end
	local material = CreateMaterial("doom/textures/"..name, "UnlitGeneric", {["$alphatest"] = "1", ["$vertexcolor"] = "1"})
	material:SetTexture("$basetexture", GetMapTexture(name).texture)
	tTextureMaterials[name] = material
	return material
end

local PatchMaterial = CreateMaterial("doompatch", "UnlitGeneric", {["$alphatest"] = "1", ["$vertexcolor"] = "1"})

function MAPTEXTURE:Draw()
	for i = 1, #self.patches do
		local mappatch = self.patches[i]
		local patch = GetTexRect(mappatch.patch)
		surface.SetDrawColor(255, 255, 255, 255)
		PatchMaterial:SetTexture("$basetexture", patch.texture)
		surface.SetMaterial(PatchMaterial)
		local x = math.Round(mappatch.originx*self.ScaleX)
		local y = math.Round(mappatch.originy*self.ScaleY)
		local w = math.Round((patch.realwidth or patch.width)*self.ScaleX)
		local h = math.Round((patch.realheight or patch.height)*self.ScaleY)
		DrawTexturedRect(x, y, w, h)
	end
end

function MAPTEXTURE:AllocateTexture()
	local pow2width, pow2height
	pow2width = NextPowerOfTwo(self.width)
	pow2height = NextPowerOfTwo(self.height)
	
	local texname = "doom/textures/"..string.lower(self.name)
	local iFormat = IMAGE_FORMAT_RGBA8888
	local iDepthType = MATERIAL_RT_DEPTH_SEPARATE
	self.texture = GetRenderTargetEx( texname, pow2width, pow2height, RT_SIZE_NO_CHANGE, iDepthType, iTexFlags, 0, iFormat )
end

function MAPTEXTURE:WriteToTexture()
	local oldRT = render.GetRenderTarget()
	local oldW, oldH = ScrW(), ScrH()
	self.ScaleX = self.texture:Width()/self.width
	self.ScaleY = self.texture:Height()/self.height
	render.SetRenderTarget(self.texture )
	render.SetViewPort( 0, 0, self.texture:Width(), self.texture:Height() )
	render.Clear( 0, 0, 0, 255, true, true )

	render.SetStencilEnable( true )
	render.SetStencilTestMask( 1 )
	render.SetStencilWriteMask( 1 )
	render.SetStencilReferenceValue( 1 )
	render.SetStencilCompareFunction( STENCIL_ALWAYS )
	render.SetStencilPassOperation( STENCIL_REPLACE )

	render.PushFilterMin(1)
	render.SetBlend( 1 )
	render.SetColorModulation( 1, 1, 1 )
	cam.Start2D()
	local status, msg = pcall( self.Draw, self )
	cam.End2D()
	render.PopFilterMin()

	render.SetStencilReferenceValue( 0 )
	render.SetStencilCompareFunction( STENCIL_EQUAL )
	render.ClearBuffersObeyStencil( 0, 0, 0, 0, true )
	render.SetStencilEnable( false )
	
	render.SetRenderTarget( oldRT )
	render.SetViewPort( 0, 0, oldW, oldH )
	if not status then error(msg) end
end
hook.Add( "PreRender", "DOOM.DrawTextures", function()
	for texture, _ in pairs(tUninitializedTextures) do
		local ready = true
		for __, patch in pairs(texture.patches) do
			if not GetTexRect(patch.patch).loaded then ready = false break end
		end
		if ready then
			texture:WriteToTexture()
			texture.loaded = true
			tUninitializedTextures[texture] = nil
		end
	end
end )

local function ReloadAllTextures()
	for _, texture in pairs(tTextures) do
		if texture.loaded then texture.loaded = false tUninitializedTextures[texture] = true end
	end
	for k, v in pairs(tTextureMaterials) do v:SetTexture("$basetexture", GetMapTexture(k).texture)  end
	for k, v in pairs(tFlatMaterials) do v:SetTexture("$basetexture", GetFlatTexture(k)) end
	tFlatMaterials["F_SKY1"] = Material("doom/floors/f_sky1")
end

hook.Add( "DOOM.OnMatSysReloaded", "DOOM.ReloadTextures", function()
		ReloadAllTextures()
end)

local animdefs = {
	{istexture = false, endname = "NUKAGE3", startname = "NUKAGE1", speed = 8},
	{istexture = false, endname = "FWATER4", startname = "FWATER1", speed = 8},
	{istexture = false, endname = "SWATER4", startname = "SWATER1", speed = 8},
	{istexture = false, endname = "LAVA4", startname = "LAVA1", speed = 8},
	{istexture = false, endname = "BLOOD3", startname = "BLOOD1", speed = 8},

	-- DOOM II flat animations.
	{istexture = false, endname = "RROCK08", startname = "RROCK05", speed = 8},		
	{istexture = false, endname = "SLIME04", startname = "SLIME01", speed = 8},
	{istexture = false, endname = "SLIME08", startname = "SLIME05", speed = 8},
	{istexture = false, endname = "SLIME12", startname = "SLIME09", speed = 8},

	{istexture = true, endname = "BLODGR4", startname = "BLODGR1", speed = 8},
	{istexture = true, endname = "SLADRIP3", startname = "SLADRIP1", speed = 8},

	{istexture = true, endname = "BLODRIP4", startname = "BLODRIP1", speed = 8},
	{istexture = true, endname = "FIREWALL", startname = "FIREWALA", speed = 8},
	{istexture = true, endname = "GSTFONT3", startname = "GSTFONT1", speed = 8},
	{istexture = true, endname = "FIRELAVA", startname = "FIRELAV3", speed = 8},
	{istexture = true, endname = "FIREMAG3", startname = "FIREMAG1", speed = 8},
	{istexture = true, endname = "FIREBLU2", startname = "FIREBLU1", speed = 8},
	{istexture = true, endname = "ROCKRED3", startname = "ROCKRED1", speed = 8},

	{istexture = true, endname = "BFALL4", startname = "BFALL1", speed = 8},
	{istexture = true, endname = "SFALL4", startname = "SFALL1", speed = 8},
	{istexture = true, endname = "WFALL4", startname = "WFALL1", speed = 8},
	{istexture = true, endname = "DBRAIN4", startname = "DBRAIN1", speed = 8},
}

local anims = {}

local function InitTextureAnim(animdef)
	local names = {}
	if GetMapTexture(animdef.startname).texture:GetName() == "debug/debugempty" then return end
	local started = false
	for i = 1, #tTextures do
		local name = tTextures[i].name
		if name == animdef.startname then started = true end
		if started then
			table.insert(names, name)
			if name == animdef.endname then break end
		end
	end
	for i = 1, #names do
		j = i + 1
		if j > #names then j = 1 end
		anims[names[i]] = {texture = GetMapTexture(names[j]).texture}
	end
end

local function InitFlatAnim(animdef)
	-- Find all of the names
	local names = {}
	local tWadFile = GetWad()
	if not tWadFile then return end
	local directory = tWadFile:GetDirectory()
	directory:ResetReadIndex()
	local tLumpInfo = directory:FindNextNamed(animdef.startname)
	if not tLumpInfo then return end
	while tLumpInfo:GetName() ~= animdef.endname do
		table.insert(names, tLumpInfo:GetName())
		tLumpInfo = directory:GetNext()
	end
	table.insert(names, animdef.endname)
	for i = 1, #names do
		j = i + 1
		if j > #names then j = 1 end
		anims[names[i]] = {texture = GetFlatTexture(names[j]), flat = true}
	end
end

function InitPicAnims()
	for i = 1, #animdefs do
		local animdef = animdefs[i]
		if animdef.istexture then
			InitTextureAnim(animdef)
		else
			InitFlatAnim(animdef)
		end
	end
end

local count = 8

hook.Add("DOOM.OnTick", "DOOM.PicAnims", function()
	count = count - 1
	if count ~= 0 then return end
	for k, v in pairs(anims) do
		local material
		if v.flat then material = GetFlatMaterial(k) else material = GetTextureMaterial(k) end
		local texture = material:GetTexture("$basetexture")
		local name = string.upper(string.GetFileFromFilename(texture:GetName()))
		if not anims[name] then continue end
		material:SetTexture("$basetexture", anims[name].texture)
	end
	count = 8
end)

end

LoadTextures()
if CLIENT then InitPicAnims() end
