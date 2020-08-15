
local bit = bit
local sound = sound
local timer = timer

setfenv( 1, DOOM )

SetConstant("BUTTONTIME", 35)

EnumStart("bwhere_e")
EnumAdd("top")
EnumAdd("middle")
EnumAdd("bottom")

local alphSwitchList = {
	-- Doom shareware episode 1 switches
	{"SW1BRCOM",	"SW2BRCOM"},
	{"SW1BRN1",		"SW2BRN1"},
	{"SW1BRN2",		"SW2BRN2"},
	{"SW1BRNGN",	"SW2BRNGN"},
	{"SW1BROWN",	"SW2BROWN"},
	{"SW1COMM",		"SW2COMM"},
	{"SW1COMP",		"SW2COMP"},
	{"SW1DIRT",		"SW2DIRT"},
	{"SW1EXIT",		"SW2EXIT"},
	{"SW1GRAY",		"SW2GRAY"},
	{"SW1GRAY1",	"SW2GRAY1"},
	{"SW1METAL",	"SW2METAL"},
	{"SW1PIPE",		"SW2PIPE"},
	{"SW1SLAD",		"SW2SLAD"},
	{"SW1STARG",	"SW2STARG"},
	{"SW1STON1",	"SW2STON1"},
	{"SW1STON2",	"SW2STON2"},
	{"SW1STONE",	"SW2STONE"},
	{"SW1STRTN",	"SW2STRTN"},

	-- Doom registered episodes 2&3 switches
	{"SW1BLUE",		"SW2BLUE"},
	{"SW1CMT",		"SW2CMT"},
	{"SW1GARG",		"SW2GARG"},
	{"SW1GSTON",	"SW2GSTON"},
	{"SW1HOT",		"SW2HOT"},
	{"SW1LION",		"SW2LION"},
	{"SW1SATYR",	"SW2SATYR"},
	{"SW1SKIN",		"SW2SKIN"},
	{"SW1VINE",		"SW2VINE"},
	{"SW1WOOD",		"SW2WOOD"},

	-- Doom II switches
	{"SW1PANEL",	"SW2PANEL"},
	{"SW1ROCK",		"SW2ROCK"},
	{"SW1MET2",		"SW2MET2"},
	{"SW1WDMET",	"SW2WDMET"},
	{"SW1BRIK",		"SW2BRIK"},
	{"SW1MOD1",		"SW2MOD1"},
	{"SW1ZIM",		"SW2ZIM"},
	{"SW1STON6",	"SW2STON6"},
	{"SW1TEK",		"SW2TEK"},
	{"SW1MARB",		"SW2MARB"},
	{"SW1SKULL",	"SW2SKULL"}
}

local switchlist = {}

for i = 1, #alphSwitchList do
	switchlist[(i - 1) * 2] = alphSwitchList[i][1]
	switchlist[(i - 1) * 2 + 1] = alphSwitchList[i][2]
end

function P_StartButton(line, w, texture, time)
	timer.Simple(time / TICRATE, function()
		local leftside = line.side[1]
		Map:ChangeWallTexture(leftside, w, texture)
	end)
end

function P_ChangeSwitchTexture(line, useAgain)
	if useAgain == 0 then line.special = 0 end
	local leftside = line.side[1]
	local texTop = leftside.toptexture
	local texMid = leftside.midtexture
	local texBot = leftside.bottomtexture
	local soundname = "doom.sfx_swtchn"
	if line.special == 11 then soundname = "doom.sfx_swtchx" end
	for i = 0, #alphSwitchList * 2 do
		if switchlist[i] == texTop then
			sound.Play(soundname, line.soundpos)
			Map:ChangeWallTexture(leftside, top, switchlist[bit.bxor(i, 1)])
			if useAgain == 1 then P_StartButton(line,top,switchlist[i],BUTTONTIME) end
		elseif switchlist[i] == texMid then
			sound.Play(soundname, line.soundpos)
			Map:ChangeWallTexture(leftside, middle, switchlist[bit.bxor(i, 1)])
			if useAgain == 1 then P_StartButton(line,middle,switchlist[i],BUTTONTIME) end
		elseif switchlist[i] == texBot then
			sound.Play(soundname, line.soundpos)
			Map:ChangeWallTexture(leftside, bottom, switchlist[bit.bxor(i, 1)])
			if useAgain == 1 then P_StartButton(line,bottom,switchlist[i],BUTTONTIME) end
		end
	end

	-- TODO: This
end

local UseSpecialLine_Monsters = {
	[1] = true,
	[32] = true,
	[33] = true,
	[34] = true
}

local UseSpecialLine_Type = {
	[1] = function(line,thing) EV_VerticalDoor(line, thing) end,
	[7] = function(line) if EV_BuildStairs(line,build8) then P_ChangeSwitchTexture(line,0) end end,
	[9] = function(line) if EV_DoDonut(line) then P_ChangeSwitchTexture(line,0) end end,
	[11] = function(line) P_ChangeSwitchTexture(line,0) G_ExitLevel() end,
	[14] = function(line) if EV_DoPlat(line,raiseAndChange,32 * HEIGHTCORRECTION) then P_ChangeSwitchTexture(line,0) end end,
	[15] = function(line) if EV_DoPlat(line,raiseAndChange,24 * HEIGHTCORRECTION) then P_ChangeSwitchTexture(line,0) end end,
	[18] = function(line) if EV_DoFloor(line,raiseFloorToNearest) then P_ChangeSwitchTexture(line,0) end end,
	[20] = function(line) if EV_DoPlat(line,raiseToNearestAndChange,0) then P_ChangeSwitchTexture(line,0) end end,
	[21] = function(line) if EV_DoPlat(line,downWaitUpStay,0) then P_ChangeSwitchTexture(line,0) end end,
	[23] = function(line) if EV_DoFloor(line,lowerFloorToLowest) then P_ChangeSwitchTexture(line,0) end end,
	[29] = function(line) if EV_DoDoor(line,normal) then P_ChangeSwitchTexture(line,0) end end,
	[41] = function(line) if EV_DoCeiling(line,lowerToFloor) then P_ChangeSwitchTexture(line,0) end end,
	[71] = function(line) if EV_DoFloor(line,turboLower) then P_ChangeSwitchTexture(line,0) end end,
	[49] = function(line) if EV_DoCeiling(line,crushAndRaise) then P_ChangeSwitchTexture(line,0) end end,
	[50] = function(line) if EV_DoDoor(line,close) then P_ChangeSwitchTexture(line,0) end end,
	[51] = function(line) P_ChangeSwitchTexture(line,0) G_SecretExitLevel() end,
	[55] = function(line) if EV_DoFloor(line,raiseFloorCrush) then P_ChangeSwitchTexture(line,0) end end,
	[101] = function(line) if EV_DoFloor(line,raiseFloor) then P_ChangeSwitchTexture(line,0) end end,
	[102] = function(line) if EV_DoFloor(line,lowerFloor) then P_ChangeSwitchTexture(line,0) end end,
	[103] = function(line) if EV_DoDoor(line,open) then P_ChangeSwitchTexture(line,0) end end,
	[111] = function(line) if EV_DoDoor(line,blazeRaise) then P_ChangeSwitchTexture(line,0) end end,
	[112] = function(line) if EV_DoDoor(line,blazeOpen) then P_ChangeSwitchTexture(line,0) end end,
	[113] = function(line) if EV_DoDoor(line,blazeClose) then P_ChangeSwitchTexture(line,0) end end,
	[122] = function(line) if EV_DoPlat(line,blazeDWUS,0) then P_ChangeSwitchTexture(line,0) end end,
	[127] = function(line) if EV_BuildStairs(line,turbo16) then P_ChangeSwitchTexture(line,0) end end,
	[131] = function(line) if EV_DoFloor(line,raiseFloorTurbo) then P_ChangeSwitchTexture(line,0) end end,
	[133] = function(line,thing) if EV_DoLockedDoor(line,blazeOpen,thing) then P_ChangeSwitchTexture(line,0) end end,
	[140] = function(line) if EV_DoFloor(line,raiseFloor512) then P_ChangeSwitchTexture(line,0) end end,
	[42] = function(line) if EV_DoDoor(line,close) then P_ChangeSwitchTexture(line,1) end end,
	[43] = function(line) if EV_DoCeiling(line,lowerToFloor) then P_ChangeSwitchTexture(line,1) end end,
	[45] = function(line) if EV_DoFloor(line,lowerFloor) then P_ChangeSwitchTexture(line,1) end end,
	[60] = function(line) if EV_DoFloor(line,lowerFloorToLowest) then P_ChangeSwitchTexture(line,1) end end,
	[61] = function(line) if EV_DoDoor(line,open) then P_ChangeSwitchTexture(line,1) end end,
	[62] = function(line) if EV_DoPlat(line,downWaitUpStay,1) then P_ChangeSwitchTexture(line,1) end end,
	[63] = function(line) if EV_DoDoor(line,normal) then P_ChangeSwitchTexture(line,1) end end,
	[64] = function(line) if EV_DoFloor(line,raiseFloor) then P_ChangeSwitchTexture(line,1) end end,
	[66] = function(line) if EV_DoPlat(line,raiseAndChange,24 * HEIGHTCORRECTION) then P_ChangeSwitchTexture(line,1) end end,
	[67] = function(line) if EV_DoPlat(line,raiseAndChange,32 * HEIGHTCORRECTION) then P_ChangeSwitchTexture(line,1) end end,
	[65] = function(line) if EV_DoFloor(line,raiseFloorCrush) then P_ChangeSwitchTexture(line,1) end end,
	[68] = function(line) if EV_DoPlat(line,raiseToNearestAndChange,0) then P_ChangeSwitchTexture(line,1) end end,
	[69] = function(line) if EV_DoFloor(line,raiseFloorToNearest) then P_ChangeSwitchTexture(line,1) end end,
	[70] = function(line) if EV_DoFloor(line,turboLower) then P_ChangeSwitchTexture(line,1) end end,
	[114] = function(line) if EV_DoDoor(line,blazeRaise) then P_ChangeSwitchTexture(line,1) end end,
	[115] = function(line) if EV_DoDoor(line,blazeOpen) then P_ChangeSwitchTexture(line,1) end end,
	[116] = function(line) if EV_DoDoor(line,blazeClose) then P_ChangeSwitchTexture(line,1) end end,
	[123] = function(line) if EV_DoPlat(line,blazeDWUS,0) then P_ChangeSwitchTexture(line,1) end end,
	[132] = function(line) if EV_DoFloor(line,raiseFloorTurbo) then P_ChangeSwitchTexture(line,1) end end,
	[99] = function(line,thing) if EV_DoLockedDoor(line,blazeOpen,thing) then P_ChangeSwitchTexture(line,1) end end,
	[138] = function(line) EV_LightTurnOn(line,255) P_ChangeSwitchTexture(line,1) end,
	[139] = function(line) EV_LightTurnOn(line,35) P_ChangeSwitchTexture(line,1) end,
}

UseSpecialLine_Type[26] = UseSpecialLine_Type[1]
UseSpecialLine_Type[27] = UseSpecialLine_Type[1]
UseSpecialLine_Type[28] = UseSpecialLine_Type[1]
UseSpecialLine_Type[31] = UseSpecialLine_Type[1]
UseSpecialLine_Type[32] = UseSpecialLine_Type[1]
UseSpecialLine_Type[33] = UseSpecialLine_Type[1]
UseSpecialLine_Type[34] = UseSpecialLine_Type[1]
UseSpecialLine_Type[117] = UseSpecialLine_Type[1]
UseSpecialLine_Type[118] = UseSpecialLine_Type[1]
UseSpecialLine_Type[135] = UseSpecialLine_Type[133]
UseSpecialLine_Type[137] = UseSpecialLine_Type[133]
UseSpecialLine_Type[134] = UseSpecialLine_Type[99]
UseSpecialLine_Type[136] = UseSpecialLine_Type[99]

function P_UseSpecialLine(thing, line, side)
	if side == 1 then return false end
	local ent = ToEntity(thing)
	if not ent:IsPlayer() then
		if tobool(bit.band(line.flags, ML_SECRET)) then return false end
		if not UseSpecialLine_Monsters[line.special] then return false end
	end
	local func = UseSpecialLine_Type[line.special]
	if func then func(line, thing) end
	return true
end
