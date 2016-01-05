local ipairs = ipairs
local pairs = pairs
local tobool = tobool
local tonumber = tonumber

local CreateClientConVar = CreateClientConVar
local ScrW = ScrW
local Vector = Vector

local bit = bit
local cvars = cvars
local hook = hook
local math = math
local table = table

setfenv( 1, DOOM )

local function MapView(origin, angles, fov)
	view = origin
end
hook.Add("RenderScene", "DOOM.MapView", MapView)

local clipranges = {}

local function ClearClipRanges()
	table.Empty(clipranges)
end

local function AddClipRange(startangle, endangle)
	local i = 1
	while i <= #clipranges do
		local range = clipranges[i]
		if range.startangle >= startangle and range.endangle <= endangle then
			table.remove(clipranges, i)
			continue
		end
		if range.startangle <= startangle && range.endangle >= endangle then return end
		i = i + 1
	end
	i = 1
	while i <= #clipranges do
		local range = clipranges[i]
		if range.startangle > endangle then break end
		if range.endangle >= startangle then
			if range.startangle > startangle then range.startangle = startangle end
			if range.endangle < endangle then range.endangle = endangle end
			local range2 = clipranges[i+1]
			while range2 and range2.startangle <= range.endangle do
				table.remove(clipranges, i+1)
				range2 = clipranges[i+1]
			end
			return
		end
		i = i + 1
	end
	i = 1
	while i <= #clipranges do
		local range = clipranges[i]
		if range.startangle > endangle then break end
		i = i + 1
	end
	local range = {}
	range.startangle = startangle
	range.endangle = endangle
	table.insert(clipranges, i, range)
end

local function SafeAddClipRange(startangle, endangle)
	startangle = startangle
	endangle = endangle
	if startangle > endangle then
		AddClipRange(startangle, 360)
		AddClipRange(0, endangle)
	else
		AddClipRange(startangle, endangle)
	end
end

local function IsRangeVisible(startangle, endangle)
	local i = 1
	local range = clipranges[i]
	while range and range.startangle < endangle do
		if startangle >= range.startangle and endangle <= range.endangle then return false end
		i = i + 1
		range = clipranges[i]
	end
	return true
end

local function SafeCheckRange(startangle, endangle)
	startangle = startangle
	endangle = endangle
	if startangle > endangle then
		return IsRangeVisible(startangle, 360) or IsRangeVisible(0, endangle)
	end
	return IsRangeVisible(startangle, endangle)
end

local checkcoord = {
	{"right","top","left","bottom"},
    {"right","top","left","top"},
    {"right","bottom","left","top"},
    {"top"},
    {"left","top","left","bottom"},
    {"top","top","top","top"},
    {"right","bottom","right","top"},
    {"top"},
    {"left","top","right","bottom"},
    {"left","bottom","right","bottom"},
    {"left","bottom","right","top"}
}

function R_CheckBBox(bspcoord)
	local boxx, boxy
	if view.x <= bspcoord.left then boxx = 0 elseif view.x < bspcoord.right then boxx = 1 else boxx = 2 end
	if view.y >= bspcoord.top then boxy = 0 elseif view.y > bspcoord.bottom then boxy = 4 else boxy = 8 end
	
	local boxpos = boxy + boxx
	if boxpos == 5 then return true end
	
	local check = checkcoord[boxpos+1]
	
	local x1 = bspcoord[check[1]]
	local y1 = bspcoord[check[2]]
	local x2 = bspcoord[check[3]]
	local y2 = bspcoord[check[4]]
	
	local angle1 = R_PointToAngle(x1, y1)
	local angle2 = R_PointToAngle(x2, y2)
	
	return SafeCheckRange(angle2, angle1)
end

local function CheckClip(seg, frontsector, backsector)
	if backsector.ceilingheight <= frontsector.floorheight then
		--if seg.side.toptexture == "-" then return false end
		--if backsector.ceilingpic == "F_SKY1" and frontsector.ceilingpic == "F_SKY1" then return false end
		return true
	end
	if frontsector.ceilingheight <= backsector.floorheight then
		--if seg.side.bottomtexture == "-" then return false end
		--if backsector.ceilingpic == "F_SKY1" and frontsector.ceilingpic == "F_SKY1" then return false end
		return true
	end
	if backsector.ceilingheight <= backsector.floorheight then
		--if backsector.ceilingheight < frontsector.floorheight and seg.side.toptexture == "-" then return false end
		--if backsector.floorheight > frontsector.floorheight and seg.side.bottomtexture == "-" then return false end
		--if backsector.ceilingpic == "F_SKY1" and frontsector.ceilingpic == "F_SKY1" then return false end
		--if backsector.floorpic == "F_SKY1" and frontsector.floorpic == "F_SKY1" then return false end
		return true
	end
	return false
end

local renderlists = {}

local function AddWall(seg)
	local sidedef = seg.side
	for _, mesh in pairs(Map.SideMeshes[sidedef.id]) do
		mesh.visible = true
	end
	--TODO: Add wall to render list
end

function R_AddLine(line)
	curline = line
	local angle1 = R_PointToAngle(line.v1.x, line.v1.y)
	local angle2 = R_PointToAngle(line.v2.x, line.v2.y)
	
	if NormalizeAngle(angle2 - angle1) < 180 or not line.linedef then return end
	if not SafeCheckRange(angle2, angle1) then return end
	if not line.backsector then
		SafeAddClipRange(angle2, angle1)
	else
		if line.frontsector == line.backsector and line.side.midtexture == "-" then return end
		if CheckClip(line, line.frontsector, line.backsector) then SafeAddClipRange(angle2, angle1) end
	end
	line.linedef.flags = bit.bor(line.linedef.flags, ML_MAPPED)
	AddWall(line)
end

local function AddSector(sector)
	local sectorid = sector.id
	for _, mesh in ipairs(Map.FloorMeshes[sectorid]) do
		if mesh.floor then mesh.visible = true end
	end
	for _, mesh in ipairs(Map.CeilMeshes[sectorid]) do
		if mesh.ceil then mesh.visible = true end
	end
	--TODO: add floor and ceiling to draw list
end

function R_Subsector(num)
	local sub = Map.Subsectors[num+1]
	if sub.sector.validcount ~= validcount then
		sub.sector.validcount = validcount
		AddSector(sub.sector)
	end
	for i = 1, sub.numsegs do
		R_AddLine(sub.segs[i])
	end
end

function R_RenderBSPNode(bspnum)
	if tobool(bit.band(bspnum, NF_SUBSECTOR)) then
		R_Subsector(bit.bxor(bspnum, NF_SUBSECTOR))
		return
	end
	local bsp = Map.Nodes[bspnum+1]
	local side = R_PointOnSide(view.x, view.y, bsp)
	R_RenderBSPNode(bsp.children[side+1])
	local otherside = bit.bxor(side, 1)
	if R_CheckBBox(bsp.bbox[otherside+1]) then R_RenderBSPNode(bsp.children[otherside+1]) end
end

local draw3dsky = false
hook.Add("PreDrawSkyBox", "DOOM.SkyCheck", function() draw3dsky = true end)
hook.Add("PostDrawSkyBox", "DOOM.SkyCheck", function() draw3dsky = false end)

local NewRender = CreateClientConVar("doom_map_cl_newrender", 0, false, false)

cvars.AddChangeCallback("doom_map_cl_newrender", function(name, oldvalue, newvalue)
	if not Map then return end
	if tonumber(newvalue) ~= 0 then return end
	for i = 1, #Map.Sidedefs do 
		for _, mesh in pairs(Map.SideMeshes[i]) do
			mesh.visible = true
		end		
	end
	for i = 1, #Map.Sectors do
		for _, mesh in ipairs(Map.FloorMeshes[i]) do
			mesh.visible = true
		end
		for _, mesh in ipairs(Map.CeilMeshes[i]) do
			mesh.visible = true
		end
	end
end)

local function DrawMap(isDrawingDepth, isDrawSkybox)
	-- isDrawSkybox only tells you if the 2d skybox is potentially visible.
	-- it fails to act as a filter for 3d skybox passes if the map does not have a 3d skybox.
	if draw3dsky then return end
	if NewRender:GetInt() <= 0 then return end
	if not Map or not Map.loaded then return end
	
	-- TODO: do away with this and build render lists
	for i = 1, #Map.Sidedefs do 
		for _, mesh in pairs(Map.SideMeshes[i]) do
			mesh.visible = false
		end		
	end
	for i = 1, #Map.Sectors do
		for _, mesh in ipairs(Map.FloorMeshes[i]) do
			mesh.visible = false
		end
		for _, mesh in ipairs(Map.CeilMeshes[i]) do
			mesh.visible = false
		end
	end
	
	ClearClipRanges()
	validcount = validcount + 1
	R_RenderBSPNode(#Map.Nodes-1)
end
hook.Add("PreDrawOpaqueRenderables", "DOOM.DrawStaticMap", DrawMap)
