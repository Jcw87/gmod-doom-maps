
local Angle = Angle
local Vector = Vector

local sound = sound

setfenv( 1, DOOM )

function EV_Teleport(line, side, thing)
	if side == 2 then return false end
	for i = 1, Map.Things.n do
		local mobj = Map.Things[i]
		if mobj.type ~= MT_TELEPORTMAN then continue end
		if not mobj:IsValid() then continue end
		local pos = mobj:GetPos()
		local ss = Map:PointInSubsector(pos.x, pos.y)
		if ss.sector.tag == line.tag then
			local oldpos = thing:GetPos()
			local oldang = thing:GetAngles()
			if not P_TeleportMove(thing, pos.x, pos.y) then return false end
			local yaw = mobj:GetYaw()
			local angle = Angle(0, yaw, 0)

			CreateClientsideMobj(oldpos, oldang, MT_TFOG)
			sound.Play("doom.sfx_telept", oldpos)
			CreateClientsideMobj(pos + angle:Forward()*20, angle, MT_TFOG)
			sound.Play("doom.sfx_telept", pos)
			
			if thing:IsPlayer() then thing:SetEyeAngles(angle) else thing:SetAngles(angle) end
			thing:SetLocalVelocity(Vector(0, 0, 0))
			return true
		end
	end
	return false
end