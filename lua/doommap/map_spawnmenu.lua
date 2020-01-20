AddCSLuaFile()

-- WARNING! This file does not play nice with auto-refresh!

if SERVER then

util.AddNetworkString("DOOM.RequestWadList")
util.AddNetworkString("DOOM.WadList")
util.AddNetworkString("DOOM.RequestWadGamemode")
util.AddNetworkString("DOOM.WadMaps")

concommand.Add("doom_map_wadlist", function(ply, cmd, args)
	if not ply:IsAdmin() then return end
	local wads = file.Find("*.wad", "GAME")
	local count = #wads
	if count > 255 then ply:ChatPrint("Too many wad files in the server's garrysmod folder!") return end
	net.Start("DOOM.WadList")
	for i = 1, count do
		net.WriteString(wads[i])
	end
	net.Send(ply)
end)

concommand.Add("doom_map_wadmaps", function(ply, cmd, args)
	if not ply:IsAdmin() then return end
	local wadname = args[1]
	if not wadname then return end
	local tWadFile = wad.Open(wadname)
	if not tWadFile then ply:ChatPrint(string.format("Wad '%s' could not be read!", wadname)) return end
	-- TODO: use zDoom data to determine what maps exist
	local maps = {}
	local tDirectory = tWadFile:GetDirectory()
	while true do
		local lump = tDirectory:GetNext()
		if lump == nil then break end
		local name = lump:GetName()
		if name:match("^E%dM%d$") or name:match("^MAP%d%d$") then table.insert(maps, name) end
	end
	tWadFile.fstream:Close()
	net.Start("DOOM.WadMaps")
	for i = 1, #maps do
		net.WriteString(maps[i])
	end
	net.Send(ply)
end)

concommand.Add("doom_map_load", function(ply, cmd, args)
	if not ply:IsAdmin() then return end
	local wadname = ply:GetInfo("doom_map_wad", "")
	local mapname = ply:GetInfo("doom_map_mapname", "")
	local skill = ply:GetInfoNum("doom_map_skill", 0)
	RunConsoleCommand("doom_skill", tostring(skill))
	if DOOM.Map then DOOM.UnloadMap() end
	timer.Simple(2, function()
		local map = DOOM.LoadMap(wadname, mapname)
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
CreateClientConVar("doom_map_mapname", "", false, true)
CreateClientConVar("doom_map_skill", 0, true, true)

local WadList
local EpisodeList
local MapList

local function LoadMapCPanel(CPanel)
	CPanel:Help("Warning! Loading a DOOM map is NOT recommended on confined maps! You should only do so on large, open maps (like gm_flatgrass).")
	WadList = CPanel:ComboBox("Wad File", "doom_map_wad")
	function WadList:OnSelect(index, value, data)
		self:ConVarChanged(value)
		RunConsoleCommand("doom_map_wadmaps", value)
	end
	function WadList:Think()
		self:ConVarStringThink()
	end
	MapList = CPanel:ComboBox("Map", "doom_map_mapname")
	function MapList:OnSelect(index, value, data)
		self:ConVarChanged(value)
	end
	MapList:SetDisabled(true)
	local SkillList = CPanel:ComboBox("Skill Level", "doom_map_skill")
	function SkillList:OnSelect(index, value, data)
		self:ConVarChanged(index-1)
	end
	function SkillList:SetValue(val)
		self:ChooseOptionID(val+1)
	end
	SkillList:SetSortItems(false)
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
	while true do
		local name = net.ReadString()
		if #name == 0 then break end
		WadList:AddChoice(name)
	end
	WadList:SetValue(value)
end)

net.Receive("DOOM.WadMaps", function(bits)
	if not MapList then return end
	MapList:Clear()
	while true do
		local name = net.ReadString()
		if #name == 0 then break end
		MapList:AddChoice(name)
	end
	MapList:SetDisabled(false)
	MapList:ChooseOptionID(1)
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
