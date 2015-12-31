AddCSLuaFile()

local getmetatable = getmetatable
local pairs = pairs
local setmetatable = setmetatable
local tobool = tobool

local Material = Material
local Vector = Vector

local bit = bit
local math = math
local string = string
local table = table

setfenv( 1, DOOM )

-- Default gmod function doesn't copy vectors
local function TableCopy(t, lookup_table)
	if (t == nil) then return nil end
	
	local copy = {}
	setmetatable(copy, getmetatable(t))
	for k,v in pairs(t) do
		if type(v) == "table" then
			lookup_table = lookup_table or {}
			lookup_table[t] = copy
			if lookup_table[v] then
				copy[k] = lookup_table[v] -- we already copied this table. reuse the copy.
			else
				copy[k] = TableCopy(v,lookup_table) -- not yet copied. copy it.
			end
		elseif type(v) == "Vector" then
			copy[k] = Vector(v.x, v.y, v.z)
		else
			copy[k] = v
		end
	end
	return copy
end

-- Witchcraft!
local function intercept_vertex(startv, endv, fdiv)
	local ax = startv.x
	local ay = startv.y
	local bx = endv.x
	local by = endv.y
	local cx = fdiv.x
	local cy = fdiv.y
	local dx = cx + fdiv.dx
	local dy = cy + fdiv.dy

	local num = (ay - cy) * (dx - cx) - (ax - cx) * (dy - cy);
	local den = (bx - ax) * (dy - cy) - (by - ay) * (dx - cx);

	if (den == 0) then return false end;
	
	local r = num / den;
	
	local inter = {}
	inter.x = ax + r * (bx - ax);
	inter.y = ay + r * (by - ay);
	return inter;
end

function MAP:BuildWalls(line, side)
	local walls = {}
	local v1, v2, thisside, otherside
	if side == 1 then
		v1 = line.v1
		v2 = line.v2
		thisside = line.sidenum[1]
		otherside = line.sidenum[2]
	elseif side == 2 then
		v1 = line.v2
		v2 = line.v1
		thisside = line.sidenum[2]
		otherside = line.sidenum[1]
	else
		error("Invalid Side: "..tostring(side))
	end
	local thissector = thisside.sector
	local othersector = otherside and otherside.sector
	local wall = {}
	wall.verts = {}
	wall.verts[1] = v1
	wall.verts[2] = v2
	wall.offsetx = thisside.textureoffset
	wall.offsety = thisside.rowoffset
	wall.normal = side == 1 and line.normal or line.normal * -1
	wall.length = line.length
	wall.s1id = thissector.id
	wall.id = thisside.id
	if otherside then
		if thissector.maxceiling > othersector.minceiling then
			wall.texid = 0
			wall.top_pegged = tobool(bit.band(line.flags, ML_DONTPEGTOP))
			wall.top = othersector.ceilingheight + (thissector.maxceiling - othersector.minceiling)
			wall.bottom = othersector.ceilingheight
			wall.flat = false
			if thisside.toptexture ~= "-" then
				wall.texture = thisside.toptexture
			else
				wall.texture = othersector.ceilingpic
				wall.flat = true
			end
			wall.s2id = othersector.id
			if othersector.ceilingpic == "F_SKY1" then wall.sky = true end
			table.insert(walls, TableCopy(wall))
		end
		if thisside.midtexture ~= "-" then
			wall.texid = 1
			wall.top_pegged = not tobool(bit.band(line.flags, ML_DONTPEGBOTTOM))
			wall.top = math.min(thissector.ceilingheight, othersector.ceilingheight)
			wall.bottom = math.max(thissector.floorheight, othersector.floorheight)
			wall.flat = false
			wall.texture = thisside.midtexture
			local maptexture = GetMapTexture(wall.texture)
			if maptexture then
				if wall.top_pegged then
					wall.bottom = math.max(wall.bottom, wall.top - maptexture.height * HEIGHTCORRECTION)
				else
					wall.top = math.min(wall.top, wall.bottom + maptexture.height * HEIGHTCORRECTION)
				end
			end
			wall.sky = false
			table.insert(walls, TableCopy(wall))
		end
		if thissector.minfloor < othersector.maxfloor then
			wall.texid = 2
			wall.top_pegged = true
			wall.top = othersector.floorheight
			wall.bottom = othersector.floorheight - (othersector.maxfloor - thissector.minfloor)
			wall.flat = false
			if thisside.bottomtexture ~= "-" then
				wall.texture = thisside.bottomtexture
			else
				wall.texture = othersector.floorpic
				wall.flat = true
			end
			wall.s2id = othersector.id
			wall.sky = false
			if tobool(bit.band(line.flags, ML_DONTPEGBOTTOM)) then wall.offsety = wall.offsety + (thissector.ceilingheight - othersector.floorheight) end
			table.insert(walls, TableCopy(wall))
		end
	else
		wall.texid = 1
		wall.top_pegged = not tobool(bit.band(line.flags, ML_DONTPEGBOTTOM))
		wall.top = wall.top_pegged and thissector.ceilingheight or thissector.floorheight + (thissector.maxceiling - thissector.minfloor)
		wall.bottom = wall.top_pegged and thissector.ceilingheight - (thissector.maxceiling - thissector.minfloor) or thissector.floorheight
		wall.texture = thisside.midtexture
		wall.sky = false
		if wall.top == wall.bottom then return end
		table.insert(walls, TableCopy(wall))
		local convex = {}
		convex[1] = Vector(v1.x, v1.y, wall.top)
		convex[2] = Vector(v1.x, v1.y, wall.bottom)
		convex[3] = Vector(v2.x, v2.y, wall.top)
		convex[4] = Vector(v2.x, v2.y, wall.bottom)
		convex[5] = Vector((v1.x + v2.x)/2, (v1.y + v2.y)/2, wall.top) - wall.normal*4
		convex[6] = Vector(convex[5].x, convex[5].y, wall.bottom)
		local target = wall.top_pegged and self.CeilPhys or self.FloorPhys
		table.insert(target[thissector.id], convex)
	end
	return walls
end

function MAP:CreateWallTriangles(wall)
	local triangles = {}
	triangles.lightsector = self.Sectors[wall.s1id]
	for i = 1, 6 do
		triangles[i] = {}
		triangles[i].normal = wall.normal
	end

	local startu, endu, startv, endv

	if CLIENT and wall.texture ~= "-" then
		local width, height
		if not wall.flat then
			local maptexture = GetMapTexture(wall.texture)
			if maptexture then
				width = maptexture.width
				height = maptexture.height*HEIGHTCORRECTION
				triangles.material = GetTextureMaterial(wall.texture)
			else
				width = 256
				height = 256*HEIGHTCORRECTION
			end
		else
			width = 64
			height = 64*HEIGHTCORRECTION
			triangles.material = GetFlatMaterial(wall.texture)
		end
		if wall.sky then triangles.material = GetFlatMaterial("F_SKY1") end
		startu = wall.offsetx / width
		endu = startu + wall.length / width
		if wall.top_pegged then
			startv = 0 + wall.offsety / height;
			endv = startv + (wall.top - wall.bottom) / height;
		else
			endv = 1 + wall.offsety / height;
			startv = endv - (wall.top - wall.bottom) / height;
		end
		
	end
	
	triangles[1].pos = Vector(wall.verts[1].x, wall.verts[1].y, wall.top)
	triangles[1].u = startu
	triangles[1].v = startv

	triangles[2].pos = Vector(wall.verts[2].x, wall.verts[2].y, wall.top)
	triangles[2].u = endu
	triangles[2].v = startv

	triangles[3].pos = Vector(wall.verts[2].x, wall.verts[2].y, wall.bottom)
	triangles[3].u = endu
	triangles[3].v = endv

	triangles[4].pos = Vector(wall.verts[1].x, wall.verts[1].y, wall.top)
	triangles[4].u = startu
	triangles[4].v = startv
	
	triangles[5].pos = Vector(wall.verts[2].x, wall.verts[2].y, wall.bottom)
	triangles[5].u = endu
	triangles[5].v = endv
	
	triangles[6].pos = Vector(wall.verts[1].x, wall.verts[1].y, wall.bottom)
	triangles[6].u = startu
	triangles[6].v = endv

	return triangles
end

function MAP:PolygonClip(input, clipper)
	local out = {}
	local workpoly = TableCopy(input);
	local vert
	for i = 1, #workpoly do
		local side = (clipper.y - workpoly[i].y) * clipper.dx - (clipper.x - workpoly[i].x) * clipper.dy
		if side > 0 then workpoly[i].side = 1 end
		if side < 0 then workpoly[i].side = 0 end
		if math.abs(side) < 1 then workpoly[i].side = 2 end
	end
	local i = 1
	while i <= #workpoly do
		local startpos = i
		local endpos = i + 1
		if endpos == #workpoly + 1 then endpos = 1 end
		local startv = workpoly[startpos]
		local endv = workpoly[endpos]
		if startv.side ~= 2 and endv.side ~= 2 and startv.side ~= endv.side then
			local newvert = intercept_vertex(startv, endv, clipper)
			if not newvert then
				-- Abort clipping
				out[1] = TableCopy(input)
				out[2] = TableCopy(input)
				return out
			end
			newvert.side = 2
			table.insert(workpoly, endpos, newvert)
			i = i + 1
		end
		i = i + 1
	end
	out[1] = TableCopy(workpoly)
	out[2] = TableCopy(workpoly)
	for i = 1, 2 do
		poly = out[i];
		local j = 1
		while j <= #poly do
			if poly[j].side == i-1 then
				table.remove(poly, j)
				j = j - 1
			end
			j = j + 1
		end
	end
	return out
end

function MAP:TriangulateSubsector(subsector)
	local polygon = TableCopy(subsector.polygon)
	local sector = subsector.sector
	local triangles = {}
	while #polygon >= 3 do
		for i = 1, 3 do
			local vertex = {}
			vertex.pos = Vector(polygon[i].x, polygon[i].y, 0)
			vertex.norm = fnormal
			vertex.u = polygon[i].x / 64.0
			vertex.v = -polygon[i].y / 64.0
			table.insert(triangles, vertex)
		end
		table.remove(polygon, 2)
	end
	-- Check for degenerate triangles
	for i = 1, #triangles / 3 do
		local firstvert = (i-1)*3+1
		local A = triangles[firstvert].pos
		local B = triangles[firstvert+1].pos
		local C = triangles[firstvert+2].pos
		if ((B - A):Cross(C - A)):Length() <= 0.01 then print(string.format("degenerate triangle %i in subsector %i", i, subsector.id)) end
	end
	return triangles
end

function MAP:ProcessNode(node, polygon)
	local clipped = self:PolygonClip(polygon, node)
	for i = 1, 2 do
		local nextnode = node.children[i]
		if tobool(bit.band(nextnode, NF_SUBSECTOR)) then
			-- if we clip with segs, the floors will stay within their sectors, but we get more holes
			local subsector = self.Subsectors[bit.bxor(nextnode, NF_SUBSECTOR)+1]
			local polygon = clipped[i]
			for i = 1, #subsector.segs do
				local seg = subsector.segs[i]
				local v1 = seg.v1
				local v2 = seg.v2
				local clipper = {x = v1.x, y = v1.y, dx = v2.x - v1.x, dy = v2.y - v1.y}
				clipped2 = self:PolygonClip(polygon, clipper)
				polygon = clipped2[1];
			end
			subsector.polygon = polygon;
		else
			self:ProcessNode(self.Nodes[nextnode+1], clipped[i]);
		end
	end
end

function MAP:CreateMeshes()
	self.FloorMeshes = {}
	self.CeilMeshes = {}
	self.SideMeshes = {}
	self.SpecialMeshes = {}
	self.FloorPhys = {}
	self.CeilPhys = {}
	self.LinePhys = {}
	for i = 1, #self.Sectors do
		self.FloorMeshes[i] = {}
		self.CeilMeshes[i] = {}
		self.SpecialMeshes[i] = {}
		self.FloorPhys[i] = {}
		self.CeilPhys[i] = {}
	end
	for i = 1, #self.Sidedefs do
		self.SideMeshes[i] = {}
	end
	
	-- Generate wall data for linedefs
	for i = 1, #self.Linedefs do
		local linedef = self.Linedefs[i]
		local leftside = linedef.sidenum[1]
		local rightside = linedef.sidenum[2]
		if leftside then linedef.leftwalls = self:BuildWalls(linedef, 1) end
		if rightside then linedef.rightwalls = self:BuildWalls(linedef, 2) end
		if tobool(bit.band(linedef.flags, ML_TWOSIDED)) and tobool(bit.band(linedef.flags, ML_BLOCKING)) then
			local v1 = linedef.v1
			local v2 = linedef.v2
			local convex = {}
			local high = math.max(leftside.sector.maxceiling, rightside and rightside.sector.maxceiling or -32768)
			local low = math.min(leftside.sector.minfloor, rightside and rightside.sector.minfloor or 32767)
			convex[1] = Vector(v1.x, v1.y, high)
			convex[2] = Vector(v1.x, v1.y, low)
			convex[3] = Vector(v2.x, v2.y, high)
			convex[4] = Vector(v2.x, v2.y, low)
			convex[5] = Vector((v1.x + v2.x)/2, (v1.y + v2.y)/2, high) + linedef.normal*2
			convex[6] = Vector(convex[5].x, convex[5].y, low)
			self.LinePhys[i] = convex
		end
	end
	
	local polygon = {}
	polygon[1] = {x = self.Bounds.lower.x, y = self.Bounds.upper.y}
	polygon[2] = {x = self.Bounds.upper.x, y = self.Bounds.upper.y}
	polygon[3] = {x = self.Bounds.upper.x, y = self.Bounds.lower.y}
	polygon[4] = {x = self.Bounds.lower.x, y = self.Bounds.lower.y}
	
	-- Traverse node tree and generate polygons for subsectors
	self:ProcessNode(self.Nodes[#self.Nodes], polygon)
	
	if CLIENT then
		for i =1, #self.Linedefs do
			local linedef = self.Linedefs[i]
			local leftwalls = linedef.leftwalls
			local rightwalls = linedef.rightwalls
			local leftsector = linedef.sidenum[1] and linedef.sidenum[1].sector
			local rightsector = linedef.sidenum[2] and linedef.sidenum[2].sector
			if leftwalls then
				for j = 1, #leftwalls do
					local wall = leftwalls[j]
					local id, target
					if wall.s2id then
						id = wall.s2id
						target = wall.texid == 2 and self.FloorMeshes or self.CeilMeshes
					else
						id = leftsector.id
						target = wall.top_pegged and self.CeilMeshes or self.FloorMeshes
					end
					if wall.texid == 0 and rightsector.ceilingmoves and wall.top_pegged then wall.special = true end
					if wall.texid == 1 and rightsector and (leftsector.floormoves or leftsector.ceilingmoves or rightsector.floormoves or rightsector.ceilingmoves) then wall.special = true end
					if wall.texid == 2 and rightsector.floormoves and not wall.top_pegged then wall.special = true end
					if linedef.special == 48 then wall.scrollx = true wall.special = true end
					if not wall.sky and wall.special then
						local w, h = 64, 64
						if not wall.flat then
							local texture = GetMapTexture(wall.texture)
							if texture then w = texture.width h = texture.height end
						end
						wall.s1 = leftsector
						wall.s2 = linedef.sidenum[2] and linedef.sidenum[2].sector
						wall.texwidth = w
						wall.texheight = h*HEIGHTCORRECTION
						wall.material = wall.flat and GetFlatMaterial(wall.texture) or GetTextureMaterial(wall.texture)
						table.insert(self.SpecialMeshes[id], wall)
						self.SideMeshes[linedef.sidenum[1].id][wall.texid] = wall
					else
						local triangles = self:CreateWallTriangles(wall)
						table.insert(target[id], triangles)
						triangles.flat = wall.flat
						triangles.visible = true
						self.SideMeshes[linedef.sidenum[1].id][wall.texid] = triangles
					end
				end
			end
			if rightwalls then
				for j = 1, #rightwalls do
					local wall = rightwalls[j]
					local id, target
					if wall.s2id then
						id = wall.s2id
						target = wall.texid == 2 and self.FloorMeshes or self.CeilMeshes
					else
						id = rightsector.id
						target = wall.top_pegged and self.CeilMeshes or self.FloorMeshes
					end
					if wall.texid == 0 and leftsector.ceilingmoves and wall.top_pegged then wall.special = true end
					if wall.texid == 1 and leftsector and (rightsector.floormoves or rightsector.ceilingmoves or leftsector.floormoves or leftsector.ceilingmoves) then wall.special = true end
					if wall.texid == 2 and leftsector.floormoves and not wall.top_pegged then wall.special = true end
					if not wall.sky and wall.special then
						local w, h = 64, 64
						if not wall.flat then
							local texture = GetMapTexture(wall.texture)
							if texture then w = texture.width h = texture.height end
						end
						wall.s1 = rightsector
						wall.s2 = linedef.sidenum[1] and linedef.sidenum[1].sector
						wall.texwidth = w
						wall.texheight = h*HEIGHTCORRECTION
						wall.material = wall.flat and GetFlatMaterial(wall.texture) or GetTextureMaterial(wall.texture)
						table.insert(self.SpecialMeshes[id], wall)
					else
						local triangles = self:CreateWallTriangles(wall)
						triangles.visible = true
						table.insert(target[id], triangles)
					end
				end
			end
		end
	end
	
	-- Create triangles for floor and ceiling from polygon
	local fnormal = Vector(0, 0, 1)
	local cnormal = Vector(0, 0, -1)
	for i = 1, #self.Subsectors do
		local subsector = self.Subsectors[i]
		local sector = subsector.sector
		local ftriangles = self:TriangulateSubsector(subsector)
		local ctriangles = {}
		for j = 1, #ftriangles do
			ftriangles[j].pos.z = sector.floorheight
			ftriangles[j].norm = fnormal
			local cond = (j - 1) % 3
			if cond == 0 then
				ctriangles[j] = TableCopy(ftriangles[j])
			elseif cond == 1 then
				ctriangles[j] = TableCopy(ftriangles[j+1])
			elseif cond == 2 then
				ctriangles[j] = TableCopy(ftriangles[j-1])
			end
			ctriangles[j].pos.z = sector.ceilingheight
			ctriangles[j].norm = cnormal
		end
		ftriangles.lightsector = sector
		ctriangles.lightsector = sector
		ftriangles.floor = true
		ctriangles.ceil = true
		ftriangles.visible = true
		ctriangles.visible = true
		if CLIENT then
			ftriangles.material = GetFlatMaterial(sector.floorpic)
			ctriangles.material = GetFlatMaterial(sector.ceilingpic)
			table.insert(self.FloorMeshes[sector.id], ftriangles)
			table.insert(self.CeilMeshes[sector.id], ctriangles)
		end

		phys = {}
		local poly = subsector.polygon
		local bottom = sector.floorheight - (sector.maxfloor - FindLowestSurrounding(sector, "minfloor", sector.floorheight))
		local top = sector.ceilingheight + (FindHighestSurrounding(sector, "maxceiling", sector.ceilingheight) - sector.minceiling)
		if bottom == sector.floorheight then bottom = bottom - 8 end
		if top == sector.ceilingheight then top = top + 8 end
		local convex = {}
		for j = 1, #poly do
			table.insert(convex, Vector(poly[j].x, poly[j].y, sector.floorheight))
			table.insert(convex, Vector(poly[j].x, poly[j].y, bottom))
		end
		table.insert(self.FloorPhys[sector.id], convex)
		convex = {}
		for j = 1, #poly do
			table.insert(convex, Vector(poly[j].x, poly[j].y, sector.ceilingheight))
			table.insert(convex, Vector(poly[j].x, poly[j].y, top))
		end
		table.insert(self.CeilPhys[sector.id], convex)
	end
end
