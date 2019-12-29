AddCSLuaFile()

if SERVER then util.AddNetworkString("DOOM.LoadErrorNotify") end

local function MessageBox(msg)
	local frame = vgui.Create("DFrame")
	frame:SetSize(400, 100)
	frame:Center()
	frame:SetTitle("gmDoom Maps")
	local label = vgui.Create("DLabel", frame)
	label:SetText(msg)
	label:SizeToContents()
	label:Dock(TOP)
	local button = vgui.Create("DButton", frame)
	button:SetText("Ok")
	function button:DoClick()
		frame:Close()
	end
	button:Dock(BOTTOM)
	frame:MakePopup()
end

local function LoadError(msg)
	if SERVER then 
		MsgC(Color(255, 0, 0), msg, "\n")
		hook.Add("PlayerInitialSpawn", "DOOM.LoadErrorNotify", function(ply)
			net.Start("DOOM.LoadErrorNotify")
			net.WriteString(msg)
			net.Send(ply)
		end)
	end
end

net.Receive("DOOM.LoadErrorNotify", function()
	local msg = net.ReadString()
	MessageBox(msg)
end)

if type(ipairs) ~= "function" then LoadError("Another addon is not playing nice! ipairs was overwritten with "..tostring(ipairs)) return end

-- Bypassing these checks isn't going to make the addon work. gmDoom is REQUIRED!
pcall(require, "doom")
if not DOOM or not DOOM.EnumStart or not DOOM.EnumAdd or not DOOM.SetConstant then LoadError("gmDoom not found! gmDoom Maps cannot function!") return end

-- Even with the introduction of the workshop and its automatic updates, people STILL manage to never update their addons.

if SERVER then
hook.Add("InitPostEntity", "DOOM.VersionCheck", function()
	if not DOOM.GetListeningMonsterTable then
		hook.Remove("Think", "DOOM.MonsterHearingMap")
		hook.Remove("DOOM.CanMonsterHearSound", "DOOM.MapSoundOverride")
		LoadError("Your copy of gmDoom appears to be out of date! Monster hearing will be wrong!")
	end
end)
end

if CLIENT then
hook.Add("InitPostEntity", "DOOM.VersionCheck", function()
	if not DOOM.IsFullbright then
		scripted_ents.GetStored("doom_sector").t.Draw = function() end
		MessageBox("Your copy of gmDoom appears to be out of date! Map rendering will not work!")
	end
end)
end

local function ClientInclude( sScriptName )
	if ( SERVER ) then
		AddCSLuaFile( sScriptName )
	else
		include( sScriptName )
	end
end

include("doommap/stream.lua")
include("doommap/enum.lua")
include("doommap/maptexture.lua")
include("doommap/map.lua")
include("doommap/map_mesh.lua")
include("doommap/map_net.lua")
include("doommap/map_specials.lua")
include("doommap/map_spawnmenu.lua")
include("doommap/mobj_patch.lua")
if SERVER then
	include("doommap/hooks.lua")
	include("doommap/p_map.lua")
	include("doommap/p_maputil.lua")
	include("doommap/p_spec.lua")
end
ClientInclude("doommap/r_main.lua")
ClientInclude("doommap/r_bsp.lua")
