AddCSLuaFile()

-- Default gmod function iterates with pairs instead of ipairs or number indexes
local function TableAdd(dest, source)
    for i = 1, #source do
        table.insert( dest, source[i] )
    end
    
    return dest
end

DEFINE_BASECLASS( "base_anim" )

ENT.RenderGroup = RENDERGROUP_OPAQUE

function ENT:SetupDataTables()
	self:NetworkVar("Int", 0, "Sector")
	self:NetworkVar("Int", 1, "Light")
	self:NetworkVar("Bool", 0, "Floor")
end

function ENT:Initialize()
	
end

function ENT:Setup()
	self.Map = DOOM.Map
	local sectorid = self:GetSector()
	local floor = self:GetFloor()
	self.sector = self.Map.Sectors[sectorid]
	if not self.sector then return end
	local bounds = self.sector.bounds
	self.offset = Vector((bounds.lower.x+bounds.upper.x)/2, (bounds.lower.y+bounds.upper.y)/2, floor and self.sector.floorheight or self.sector.ceilingheight)
	if SERVER then 
		local tr = {start = Vector(0, 0, 0), endpos = Vector(0, 0, 0), mins = bounds.lower, maxs = bounds.upper, mask = MASK_SOLID_BRUSHONLY}
		tr = util.TraceHull(tr)
		if tr.Hit then print("doom_sector removed as it might intersect with "..tostring(tr.Entity)) self:Remove() return end
	end
	self.phys = floor and self.Map.FloorPhys[sectorid] or self.Map.CeilPhys[sectorid]
	self:OffsetPhys()
	-- PhysicsFromMesh, PhysicsInitConvex, and PhysicsInitMultiConvex do not behave unless SetModel and PhysicsInit are called first
	self:SetModel("models/hunter/plates/plate1x1.mdl")
	self:PhysicsInit(SOLID_VPHYSICS)
	self:PhysicsInitMultiConvex(self.phys, false)
	self:EnableCustomCollisions()
	self:MakePhysicsObjectAShadow()
	
	if SERVER then
		self:SetMoveType(MOVETYPE_NOCLIP) -- Without this, move speeds get messed up
		self:SetMoveType(MOVETYPE_PUSH)
		self:SetCollisionGroup(COLLISION_GROUP_NONE)
		self:SetPos(self.offset)
		self:SetUseType(SIMPLE_USE)
	end
	if CLIENT then
		self.specialmeshes = self.Map.SpecialMeshes[sectorid]
		self.meshes = floor and self.Map.FloorMeshes[sectorid] or self.Map.CeilMeshes[sectorid]
		self:OffsetMesh()
		local lower = Vector(32767, 32767, 32767)
		local upper = Vector(-32768, -32768, -32768)
		for i = 1, #self.meshes do
			local submesh = self.meshes[i]
			for j = 1, #submesh do
				local pos = submesh[j].pos
				lower.x = math.min(lower.x, pos.x)
				upper.x = math.max(upper.x, pos.x)
				lower.y = math.min(lower.y, pos.y)
				upper.y = math.max(upper.y, pos.y)
				lower.z = math.min(lower.z, pos.z)
				upper.z = math.max(upper.z, pos.z)
			end
		end
		lower.z = math.min(lower.z, (DOOM.FindLowestSurrounding(self.sector, "minfloor") - self.sector.maxfloor), self.sector.minfloor - self.offset.z)
		upper.z = math.max(upper.z, (DOOM.FindHighestSurrounding(self.sector, "maxceiling") - self.sector.minceiling), self.sector.maxceiling - self.offset.z)
		self:SetRenderBounds(lower, upper)
		self.matrix = Matrix()
		--[[
		-- Join triangle tables that can be rendered together
		local j = 1
		while j <= #self.meshes do
			local m1 = self.meshes[j]
			local k = j + 1
			while k <= #self.meshes do
				local m2 = self.meshes[k]
				if m1.material == m2.material and m1.floor == m2.floor and m1.lightsector.id == m2.lightsector.id then
					TableAdd(m1, m2)
					table.remove(self.meshes, k)
					k = k - 1
				end
				k = k + 1
			end
			j = j + 1
		end
		--]]
		for i = 1, #self.meshes do
			local submesh = self.meshes[i]
			local mesh = Mesh()
			mesh:BuildFromTriangles(submesh)
			submesh.mesh = mesh
		end
		-- Positions get messed up slightly, fix them
		timer.Simple(0.2, function() if IsValid(self) then self:SetPos(self.offset) end end)
	end
	if floor then self.sector.floor = self else self.sector.ceiling = self end
	return true
end

function ENT:OffsetPhys()
	if self.phys.offset then return end
	for i = 1, #self.phys do
		local convex = self.phys[i]
		for j = 1, #convex do
			convex[j] = convex[j] - self.offset
		end
	end
	self.phys.offset = true
end

if SERVER then

local shoot_specials = {
	[24] = true,
	[46] = true,
	[47] = true
}

function ENT:OnTakeDamage(dmg)
	if not dmg:IsDamageType(DMG_BULLET) then return end
	for i = 1, #self.sector.lines do
		local line = self.sector.lines[i]
		if not shoot_specials[line.special] then continue end
		local hitpos = dmg:GetDamagePosition()
		local v1 = line.v1
		local v2 = line.v2
		local cross = (hitpos.y - v1.y) * (v2.x - v1.x) - (hitpos.x - v1.x) * (v2.y - v1.y)
		if math.abs(cross) > 8 then continue end
		local dot = (hitpos.x - v1.x) * (v2.x - v1.x) + (hitpos.y - v1.y) * (v2.y - v1.y)
		if dot < 0 then continue end
		local slength = (v2.x - v1.x)^2 + (v2.y - v1.y)^2
		if dot > slength then continue end
		DOOM.P_ShootSpecialLine(dmg:GetAttacker(), line)
	end
end

function ENT:Think()
	self:SetCollisionGroup(COLLISION_GROUP_NONE) -- This guy doesn't want to stay, so I'm FORCING it
	self:NextThink(CurTime()+0.01)
	return true
end

function ENT:Touch(ent)

end

function ENT:Blocked(ent)
	self.block_ent = ent
end

end

if CLIENT then

function ENT:Think()
	local sector = self.sector
	if not sector then
		if self:GetSector() ~= 0 and DOOM.Map and DOOM.Map.loaded then self:Setup() end
		return
	end
	local floor = self:GetFloor()
	if floor then
		sector.floorheight = self:GetPos().z
		sector.lightlevel = self:GetLight()
	else
		sector.ceilingheight = self:GetPos().z
	end
end

function ENT:OffsetMesh()
	if self.meshes.offset then return end
	for i = 1, #self.meshes do
		local submesh = self.meshes[i]
		for j = 1, #submesh do
			submesh[j].pos = submesh[j].pos - self.offset
		end
	end
	self.meshes.offset = true
end

local color = Vector(0, 0, 0)

local function DrawWall(wall)
	if wall.s2 then
		if wall.texid == 0 then
			wall.top = wall.s1.ceilingheight
			wall.bottom = wall.s2.ceilingheight
		elseif wall.texid == 1 then
			wall.top = math.min(wall.s1.ceilingheight, wall.s2.ceilingheight)
			wall.bottom = math.max(wall.s1.floorheight, wall.s2.floorheight)
			local maptexture = DOOM.GetMapTexture(wall.texture)
			if maptexture then
				if wall.top_pegged then
					wall.bottom = math.max(wall.bottom, wall.top - maptexture.height * DOOM.HEIGHTCORRECTION)
				else
					wall.top = math.min(wall.top, wall.bottom + maptexture.height * DOOM.HEIGHTCORRECTION)
				end
			end
		elseif wall.texid == 2 then
			wall.top = wall.s2.floorheight
			wall.bottom = wall.s1.floorheight
		end
	else
		wall.top = wall.s1.ceilingheight
		wall.bottom = wall.s1.floorheight
	end

	local startu, endu, startv, endv
	startu = wall.offsetx / wall.texwidth
	endu = startu + wall.length / wall.texwidth
	if wall.top_pegged then
		startv = 0 + wall.offsety / wall.texheight;
		endv = startv + (wall.top - wall.bottom) / wall.texheight;
	else
		endv = 1 + wall.offsety / wall.texheight;
		startv = endv - (wall.top - wall.bottom) / wall.texheight;
	end
	
	local light = wall.s1.lightlevel
	if DOOM.IsFullbright() then light = 255 end
	
	color.x = 1
	color.y = 1
	color.z = 1
	wall.material:SetVector("$color", color)
	
	render.SetMaterial(wall.material)
	mesh.Begin(MATERIAL_QUADS, 1)
	mesh.Position(Vector(wall.verts[1].x, wall.verts[1].y, wall.top))
	mesh.Normal(wall.normal)
	mesh.Color(light, light, light, 255)
	mesh.TexCoord(0, startu, startv)
	mesh.AdvanceVertex()
	mesh.Position(Vector(wall.verts[2].x, wall.verts[2].y, wall.top))
	mesh.Normal(wall.normal)
	mesh.Color(light, light, light, 255)
	mesh.TexCoord(0, endu, startv)
	mesh.AdvanceVertex()
	mesh.Position(Vector(wall.verts[2].x, wall.verts[2].y, wall.bottom))
	mesh.Normal(wall.normal)
	mesh.Color(light, light, light, 255)
	mesh.TexCoord(0, endu, endv)
	mesh.AdvanceVertex()
	mesh.Position(Vector(wall.verts[1].x, wall.verts[1].y, wall.bottom))
	mesh.Normal(wall.normal)
	mesh.Color(light, light, light, 255)
	mesh.TexCoord(0, startu, endv)
	mesh.AdvanceVertex()
	mesh.End()
end

function ENT:Draw()
	if not self.matrix then return end
	local override = self:GetMaterial()
	local material
	if override ~= "" then material = Material(override) render.SetMaterial(material) end
	self.matrix:SetAngles(self:GetAngles())
	self.matrix:SetTranslation(self:GetPos())
	cam.PushModelMatrix(self.matrix)
	render.SuppressEngineLighting( true )
	for i = 1, #self.meshes do
		local submesh = self.meshes[i]
		if not submesh.visible then continue end
		local lightlevel = ((submesh.lightsector.lightlevel) / 256)
		if DOOM.IsFullbright() then lightlevel = 1 end
		if not submesh.material then continue end
		color.x = lightlevel
		color.y = lightlevel
		color.z = lightlevel
		submesh.material:SetVector("$color", color)
		if not material then render.SetMaterial(submesh.material) end
		submesh.mesh:Draw()
	end
	render.SuppressEngineLighting( false )
	cam.PopModelMatrix()
	local floor = self:GetFloor()
	for i = 1, #self.specialmeshes do
		local wall = self.specialmeshes[i]
		if floor and wall.texid ~= 0 or not floor and wall.texid == 0 then DrawWall(wall) end
	end
end

function ENT:OnRemove()
	if self.meshes then
		for i = 1, #self.meshes do
			self.meshes[i].mesh:Destroy()
			self.meshes[i].mesh = nil
		end
	end
	self.matrix = nil
	self.sector = nil
end

end

