AddCSLuaFile()

-- WARNING! This file does not play nice with auto-refresh!

if SERVER then

util.AddNetworkString("DOOM.RequestWadList")
util.AddNetworkString("DOOM.WadList")
util.AddNetworkString("DOOM.RequestWadGamemode")
util.AddNetworkString("DOOM.WadGamemode")

concommand.Add("doom_map_wadlist", function(ply, cmd, args)
	if not ply:IsAdmin() then return end
	local wads = file.Find("*.wad", "GAME")
	local count = #wads
	if count > 255 then ply:ChatPrint("Too many wad files in the server's garrysmod folder!") return end
	net.Start("DOOM.WadList")
	net.WriteUInt(count, 8)
	for i = 1, count do
		net.WriteString(wads[i])
	end
	net.Send(ply)
end)

concommand.Add("doom_map_wadgamemode", function(ply, cmd, args)
	if not ply:IsAdmin() then return end
	local wadname = args[1]
	if not wadname then return end
	local tWadFile = wad.Open(wadname)
	if not tWadFile then ply:ChatPrint(string.format("Wad '%s' could not be read!", wadname)) return end
	local gamemode = DOOM.GetDoomGamemode(tWadFile)
	tWadFile.fstream:Close()
	net.Start("DOOM.WadGamemode")
	net.WriteUInt(gamemode, 8)
	net.Send(ply)
end)

concommand.Add("doom_map_load", function(ply, cmd, args)
	if not ply:IsAdmin() then return end
	local wadname = ply:GetInfo("doom_map_wad", "")
	local episode = ply:GetInfoNum("doom_map_episode", 0)
	local map = ply:GetInfoNum("doom_map_map", 0)
	local skill = ply:GetInfoNum("doom_map_skill", 0)
	RunConsoleCommand("doom_skill", tostring(skill))
	if DOOM.Map then DOOM.UnloadMap() end
	timer.Simple(2, function()
		local map = DOOM.LoadMap(wadname, episode, map)
		if not map and IsValid(ply) then ply:ChatPrint("Failed to load map.") end
	end)
end)

concommand.Add("doom_map_unload", function(ply, cmd, args)
	if not ply:IsAdmin() then return end
	DOOM.UnloadMap()
end)

concommand.Add("doom_map_removenpcs", function(ply, cmd, args)
	if not ply:IsAdmin() then return end
	for k, v in pairs(DOOM.GetAllMobjInstances()) do
		if DOOM.ToEntity(v):IsNPC() then v:Remove() end
	end
end)

concommand.Add("doom_map_removecorpses", function(ply, cmd, args)
	if not ply:IsAdmin() then return end
	for k, v in pairs(DOOM.GetAllMobjInstances()) do
		if v:HasFlag(DOOM.MF_CORPSE) then v:Remove() end
	end
end)

concommand.Add("doom_map_removeentities", function(ply, cmd, args)
	if not ply:IsAdmin() then return end
	for k, v in pairs(DOOM.GetAllMobjInstances()) do
		local ent = DOOM.ToEntity(v)
		if ent:IsWeapon() and IsValid(ent:GetOwner()) then continue end
		if v.type == DOOM.MT_TELEPORTMAN then continue end
		v:Remove()
	end
end)

end

if CLIENT then

CreateClientConVar("doom_map_wad", "", false, true)
CreateClientConVar("doom_map_episode", 0, false, true)
CreateClientConVar("doom_map_map", 0, false, true)
CreateClientConVar("doom_map_skill", 0, true, true)

local WadList
local EpisodeList
local MapList

local function LoadMapCPanel(CPanel)
	CPanel:Help("Warning! Loading a DOOM map is NOT recommended on confined maps! You should only do so on large, open maps (like gm_flatgrass).")
	WadList = CPanel:ComboBox("Wad File", "doom_map_wad")
	function WadList:OnSelect(index, value, data)
		self:ConVarChanged(value)
		RunConsoleCommand("doom_map_wadgamemode", value)
	end
	function WadList:Think()
		self:ConVarStringThink()
	end
	EpisodeList = CPanel:ComboBox("Episode", "doom_map_episode")
	function EpisodeList:OnSelect(index, value, data)
		self:ConVarChanged(value)
	end
	EpisodeList:SetDisabled(true)
	EpisodeList:SetValue(0)
	MapList = CPanel:ComboBox("Map", "doom_map_map")
	function MapList:OnSelect(index, value, data)
		self:ConVarChanged(value)
	end
	MapList:SetDisabled(true)
	MapList:SetValue(0)
	local SkillList = CPanel:ComboBox("Skill Level", "doom_map_skill")
	function SkillList:OnSelect(index, value, data)
		self:ConVarChanged(index-1)
	end
	function SkillList:SetValue(val)
		self:ChooseOptionID(val+1)
	end
	SkillList:AddChoice("I'm too young to die", nil, true)
	SkillList:AddChoice("Hey, not too rough")
	SkillList:AddChoice("Hurt me plenty")
	SkillList:AddChoice("Ultra-Violence")
	SkillList:AddChoice("Nightmare!")
	local LoadButton = CPanel:Button("Load", "doom_map_load")
end

net.Receive("DOOM.WadList", function(bits)
	if not WadList then return end
	local value = WadList:GetValue()
	WadList:Clear()
	local count = net.ReadUInt(8)
	for i = 1, count do
		WadList:AddChoice(net.ReadString())
	end
	WadList:SetValue(value)
end)

net.Receive("DOOM.WadGamemode", function(bits)
	if not EpisodeList or not MapList then return end
	local gamemode = net.ReadUInt(8)
	local episodes = 0
	local maps = 0
	EpisodeList:Clear()
	MapList:Clear()
	if gamemode == DOOM.commercial then
		maps = 32
	elseif gamemode == DOOM.retail then
		episodes = 4 maps = 9
	elseif gamemode == DOOM.registered then
		episodes = 3 maps = 9
	elseif gamemode == DOOM.shareware then
		episodes = 1 maps = 9
	end
	if episodes > 0 then
		EpisodeList:SetDisabled(false)
		for i = 1, episodes do EpisodeList:AddChoice(tostring(i)) end
		EpisodeList:SetValue(1)
		EpisodeList:ConVarChanged(1)
	else
		EpisodeList:SetDisabled(true)
		EpisodeList:SetValue(0)
		EpisodeList:ConVarChanged(0)
	end
	if maps > 0 then
		MapList:SetDisabled(false)
		for i = 1, maps do MapList:AddChoice(string.format("%2i", i)) end
		MapList:SetValue(1)
		MapList:ConVarChanged(1)
	else
		MapList:SetDisabled(true)
		MapList:SetValue(0)
		MapList:ConVarChanged(0)
	end
end)

local function CleanupCPanel(CPanel)
	CPanel:Button("Unload Map", "doom_map_unload")
	CPanel:Button("Remove All DOOM NPCs", "doom_map_removenpcs")
	CPanel:Button("Remove All DOOM Corpses", "doom_map_removecorpses")
	CPanel:Button("Remove All DOOM Entities", "doom_map_removeentities")
end

hook.Add("AddToolMenuTabs", "DOOM.MapMenu", function()
	spawnmenu.AddToolTab("DOOM.Maps", "Doom Maps", "doom/icon16_head.png")
	spawnmenu.AddToolCategory("DOOM.Maps", "Maps1", "Map Management")
	spawnmenu.AddToolMenuOption("DOOM.Maps", "Maps1", "LoadMap", "Load Map (Admin Only)", "doom_map_wadlist", "", LoadMapCPanel)
	spawnmenu.AddToolMenuOption("DOOM.Maps", "Maps1", "Cleanup", "Cleanup (Admin Only)", "", "", CleanupCPanel)
end)

end
