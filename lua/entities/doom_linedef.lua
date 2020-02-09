AddCSLuaFile()

DEFINE_BASECLASS( "base_anim" )

ENT.RenderGroup = RENDERGROUP_OPAQUE

function ENT:SetupDataTables()
	self:NetworkVar("Int", 0, "Linedef")
end

function ENT:Initialize()

end

function ENT:Setup()
	self.Map = DOOM.Map
	local lineid = self:GetLinedef()
	self.linedef = self.Map.Linedefs[lineid]
	if not self.linedef then return end
	self.leftside = self.linedef.sidenum[1]
	local v1, v2 = self.linedef.v1, self.linedef.v2
	self.offset = Vector((v1.x + v2.x)/2, (v1.y + v2.y)/2, self.leftside.sector.floorheight)
	
	if tobool(bit.band(self.linedef.flags, DOOM.ML_TWOSIDED)) and tobool(bit.band(self.linedef.flags, DOOM.ML_BLOCKING)) then
		self.phys = self.Map.LinePhys[lineid]
		self:OffsetPhys()
	
		self:SetModel("models/props_c17/fence01a.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:PhysicsInitConvex(self.phys, false)
		self:EnableCustomCollisions()
		self:MakePhysicsObjectAShadow()
		-- It's less game breaking to have this non-solid for now
		self:SetNotSolid(true)
		-- This allows bullets to pass through and not players, however it does not react well with projectile weapons.
		--self:SetSolidFlags(FSOLID_CUSTOMBOXTEST)
	else
		self:SetNotSolid(true)
	end
	
	self:SetMoveType(MOVETYPE_NOCLIP)
	if SERVER then
		self:SetPos(self.offset)
		self:SetTrigger(true) 
		self:SetNoDraw(true)
	end
end

function ENT:OffsetPhys()
	if self.phys.offset then return end
	local convex = self.phys
	for i = 1, #convex do
		convex[i] = convex[i] - self.offset
	end
	self.phys.offset = true
end

if CLIENT then

function ENT:Think()
	if not self.linedef then
		if self:GetLinedef() ~= 0 and DOOM.Map and DOOM.Map.loaded then self:Setup() end
		return
	end
end

end
