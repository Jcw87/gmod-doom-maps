local ipairs = ipairs
local pairs = pairs
local tobool = tobool
local tonumber = tonumber

local CreateClientConVar = CreateClientConVar
local ScrW = ScrW

local bit = bit
local cvars = cvars
local hook = hook
local math = math
local table = table

setfenv( 1, DOOM )

-- from r_segs
local function R_StoreWallRange(start, stop)
	local sidedef = curline.side
	local linedef = curline.linedef
	linedef.flags = bit.bor(linedef.flags, ML_MAPPED)
	for _, mesh in pairs(Map.SideMeshes[sidedef.id]) do
		mesh.visible = true
	end
	--[[
	local sectorid = sidedef.sector.id
	for _, mesh in ipairs(Map.FloorMeshes[sectorid]) do
		mesh.visible = true
	end
	for _, mesh in ipairs(Map.CeilMeshes[sectorid]) do
		mesh.visible = true
	end
	--]]
end

local function NormalizeAngle(angle)
	while angle >= 360 do angle = angle - 360 end
	while angle < 0 do angle = angle + 360 end
	return angle
end

-- TODO: make a proper value
local clipangle = 45

function viewangletox(angle)
	-- TODO: handle widescreen FOV
	local centerx = ScrW()/2
	local focallength = centerx / math.tan(math.rad(45))
	local t = math.floor(math.tan(math.rad(angle)) * focallength)
	t = centerx - t + 1
	t = math.max(t, -1)
	t = math.min(t, ScrW()+1)
	return t
end

local solidsegs = {}

function R_ClipSolidWallSegment(first, last)
	local start = 1
	while solidsegs[start].last < first - 1 do start = start + 1 end
	if first < solidsegs[start].first then
		if last < solidsegs[start].first-1 then
			R_StoreWallRange(first, last)
			table.insert(solidsegs, start, {first = first, last = last})
			return
		end
		R_StoreWallRange(first, solidsegs[start].first - 1)
		solidsegs[start].first = first
	end
	if last <= solidsegs[start].last then return end
	local next = start
	local crunch = false
	while last >= solidsegs[next + 1].first - 1 do
		R_StoreWallRange(solidsegs[next].last + 1, solidsegs[next + 1].first - 1)
		next = next + 1
		if last <= solidsegs[next].last then
			solidsegs[start].last = solidsegs[next].last
			crunch = true
			break
		end
	end
	if not crunch then
		R_StoreWallRange(solidsegs[next].last + 1, last)
		solidsegs[start].last = last
	end
	if next == start then return end
	while next > start do
		table.remove(solidsegs, start+1)
		next = next - 1
	end
end

function R_ClipPassWallSegment(first, last)
	local start = 1
	while solidsegs[start].last < first - 1 do start = start + 1 end
	if first < solidsegs[start].first then
		if last < solidsegs[start].first-1 then
			R_StoreWallRange (first, last)
			return
		end
		R_StoreWallRange (first, solidsegs[start].first - 1)
	end
	if last <= solidsegs[start].last then return end
	while last >= solidsegs[start + 1].first - 1 do
		R_StoreWallRange(solidsegs[start].last + 1, solidsegs[start + 1].first - 1)
		start = start + 1
		if last <= solidsegs[start].last then return end
	end
	R_StoreWallRange(solidsegs[start].last + 1, last)
end

function R_ClearClipSegs()
	while #solidsegs < 2 do table.insert(solidsegs, {}) end
	while #solidsegs > 2 do table.remove(solidsegs) end
	solidsegs[1].first = -65535
	solidsegs[1].last = -1
	solidsegs[2].first = ScrW()
	solidsegs[2].last = 65535
end

function R_AddLine(line)
	curline = line
	local angle1 = R_PointToAngle(line.v1.x, line.v1.y)
    local angle2 = R_PointToAngle(line.v2.x, line.v2.y)
	local span = NormalizeAngle(angle1 - angle2)
	if span > 180 then return end
	
	--rw_angle1 = NormalizeAngle(angle1)
	angle1 = NormalizeAngle(angle1 - viewangle)
	angle2 = NormalizeAngle(angle2 - viewangle)

	local tspan = NormalizeAngle(angle1 + clipangle)
	if tspan > 2*clipangle then
		tspan = NormalizeAngle(tspan - 2*clipangle)
		if tspan >= span then return end
		angle1 = clipangle
	end
	tspan = NormalizeAngle(clipangle - angle2)
	if tspan > 2*clipangle then
		tspan = NormalizeAngle(tspan - 2*clipangle)
		if tspan >= span then return end
		angle2 = NormalizeAngle(-clipangle)
	end
	
	local x1 = viewangletox(angle1)
	local x2 = viewangletox(angle2)
	if x1 == x2 then return end
	
	local backsector = line.backsector
	if not backsector or backsector.ceilingheight <= frontsector.floorheight or backsector.floorheight >= frontsector.ceilingheight then
		R_ClipSolidWallSegment(x1, x2-1)
		return
	end
	if backsector.ceilingheight ~= frontsector.ceilingheight or backsector.floorheight ~= frontsector.ceilingheight then
		R_ClipPassWallSegment (x1, x2-1)
		return
	end
	if backsector.ceilingpic == frontsector.ceilingpic
	and backsector.floorpic == frontsector.floorpic
	and backsector.lightlevel == frontsector.lightlevel
	and curline.side.midtexture == "-" then
		return
	end
	R_ClipPassWallSegment (x1, x2-1)
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
	if viewx <= bspcoord.left then boxx = 0 elseif viewx < bspcoord.right then boxx = 1 else boxx = 2 end
	if viewy >= bspcoord.top then boxy = 0 elseif viewy > bspcoord.bottom then boxy = 1 else boxy = 2 end
	
	local boxpos = bit.lshift(boxy, 2) + boxx
	if boxpos == 5 then return true end
	
	local x1 = bspcoord[checkcoord[boxpos+1][1]]
	local y1 = bspcoord[checkcoord[boxpos+1][2]]
	local x2 = bspcoord[checkcoord[boxpos+1][3]]
	local y2 = bspcoord[checkcoord[boxpos+1][4]]
	
	local angle1 = NormalizeAngle(R_PointToAngle(x1, y1) - viewangle)
	local angle2 = NormalizeAngle(R_PointToAngle(x2, y2) - viewangle)
	
	span = NormalizeAngle(angle1 - angle2)
	if span >= 180 then return true end

	local tspan = NormalizeAngle(angle1 + clipangle)
	if tspan > 2*clipangle then
		tspan = NormalizeAngle(tspan - 2*clipangle)
		if tspan >= span then return false end
		angle1 = clipangle
	end
	tspan = NormalizeAngle(clipangle - angle2)
	if tspan > 2*clipangle then
		tspan = NormalizeAngle(tspan - 2*clipangle)
		if tspan >= span then return false end
		angle2 = NormalizeAngle(-clipangle)
	end
	
	local sx1 = viewangletox(angle1)
	local sx2 = viewangletox(angle2)
	if sx1 == sx2 then return false end
	sx2 = sx2 - 1
	for i = 1, #solidsegs do
		local solidseg = solidsegs[i]
		if sx1 >= solidseg.first and sx2 <= solidseg.last then return false end
	end
	return true
end

function R_Subsector(num)
	local sub = Map.Subsectors[num+1]
	frontsector = sub.sector
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
	local side = R_PointOnSide(viewx, viewy, bsp)
	R_RenderBSPNode(bsp.children[side+1])
	local otherside = bit.bxor(side, 1)
	if R_CheckBBox(bsp.bbox[otherside+1]) then R_RenderBSPNode(bsp.children[otherside+1]) end
end

local NewRender = CreateClientConVar("doom_map_cl_newrender", 0, false, false)

cvars.AddChangeCallback("doom_map_cl_newrender", function(name, oldvalue, newvalue)
	if not Map then return end
	if tonumber(newvalue) ~= 0 then return end
	for i = 1, #Map.Sidedefs do 
		for _, mesh in pairs(Map.SideMeshes[i]) do
			mesh.visible = true
		end		
	end
end)

hook.Add("RenderScene", "DOOM.VisibleLines", function(ViewOrigin, ViewAngles)
	if NewRender:GetInt() > 0 then
		if not Map or not Map.loaded then return end
		viewx = ViewOrigin.x
		viewy = ViewOrigin.y
		viewz = ViewOrigin.z
		viewangle = NormalizeAngle(ViewAngles.y)
		for i = 1, #Map.Sidedefs do 
			for _, mesh in pairs(Map.SideMeshes[i]) do
				mesh.visible = false
			end		
		end
		--[[
		for i = 1, #Map.Sectors do
			for _, mesh in ipairs(Map.FloorMeshes[i]) do
				mesh.visible = false
			end
			for _, mesh in ipairs(Map.CeilMeshes[i]) do
				mesh.visible = false
			end
		end
		--]]
		R_ClearClipSegs()
		R_RenderBSPNode(#Map.Nodes-1)
	end
end)
