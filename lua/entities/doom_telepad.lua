AddCSLuaFile()

DEFINE_BASECLASS( "base_anim" )

ENT.Category = "DOOM"
ENT.PrintName = "Map Entry Teleporter"
ENT.Spawnable            = true
ENT.AdminOnly            = false
ENT.RenderGroup = RENDERGROUP_OPAQUE

function ENT:SpawnFunction( ply, tr, ClassName )
    if not tr.Hit then return end
	if not DOOM then
		ply:ChatPrint("gmDoom is required!")
		return
	end
	if not DOOM.FindPlayerStart then
		ply:ChatPrint("gmDoom Maps did not load correctly. Make sure you have gmDoom installed and enabled.")
		return
	end
    
    local SpawnPos = tr.HitPos
    
    local ent = ents.Create( ClassName )
        ent:SetPos( SpawnPos )
    ent:Spawn()
    
    return ent
end

if SERVER then
function ENT:Initialize()
	self:SetModel("models/doom/telepad_002.mdl")
	self:PhysicsInit(SOLID_VPHYSICS)
	local phys = self:GetPhysicsObject()
	phys:SetMass(50)
end

function ENT:StartTouch(ent)
	if not ent:IsPlayer() then return end
	local spawn = DOOM.FindPlayerStart()
	if not spawn then return end
	local pos = spawn:GetPos()
		
	local oldpos = ent:GetPos()
	local oldang = ent:GetAngles()
	if not DOOM.P_TeleportMove(ent, pos.x, pos.y) then return false end
	local angle = spawn:GetAngles()
	ent:SetEyeAngles(angle)
	ent:SetLocalVelocity(Vector(0, 0, 0))

	DOOM.CreateClientsideMobj(oldpos, oldang, DOOM.MT_TFOG)
	sound.Play("doom.sfx_telept", oldpos)
	DOOM.CreateClientsideMobj(pos + angle:Forward()*20, angle, DOOM.MT_TFOG)
	sound.Play("doom.sfx_telept", pos)

	ent:SetHull( Vector(-16, -16, 0), Vector(16, 16, 56 * DOOM.HEIGHTCORRECTION - 0.1))
	ent:SetStepSize(24 * DOOM.HEIGHTCORRECTION)
	ent:SetWalkSpeed(8.333*DOOM.TICRATE)
	ent:SetRunSpeed(16.666*DOOM.TICRATE)
	ent:SendLua("LocalPlayer():SetHull(Vector(-16,-16,0),Vector(16,16,56*DOOM.HEIGHTCORRECTION-0.1)) LocalPlayer():SetStepSize(24*DOOM.HEIGHTCORRECTION)")
	if not ent:HasWeapon("doom_weapon_pistol") then
		ent:Give("doom_weapon_fist")
		ent:GiveAmmo(50, "Pistol", true)
		ent:Give("doom_weapon_pistol")
	end
end
end