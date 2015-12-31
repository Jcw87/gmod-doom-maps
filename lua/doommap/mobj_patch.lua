AddCSLuaFile()

setfenv( 1, DOOM )

local Pickups = {
	MT_MISC0,
	MT_MISC1,
	MT_MISC2,
	MT_MISC3,
	MT_MISC4,
	MT_MISC5,
	MT_MISC6,
	MT_MISC7,
	MT_MISC8,
	MT_MISC9,
	MT_MISC10,
	MT_MISC11,
	MT_MISC12,
	MT_MISC13,
	MT_MISC14,
	MT_MISC15,
	MT_MISC16,
	MT_MISC17,
	MT_MISC18,
	MT_MISC19,
	MT_MISC20,
	MT_MISC21,
	MT_MISC22,
	MT_MISC23,
	MT_MISC24,
	MT_MISC25,
	MT_MISC26,
	MT_MISC27,
	MT_MISC28,
	MT_INV,
	MT_INS,
	MT_MEGA,
	MT_CLIP,
	MT_CHAINGUN,
	MT_SHOTGUN,
	MT_SUPERSHOTGUN
}

for i = 1, #Pickups do
	GetMobjInfo(Pickups[i]).radius = 15.9
end

local Decor = {
	MT_MISC31,
	MT_MISC41,
	MT_MISC42,
	MT_MISC43,
	MT_MISC46,
	MT_MISC48
}

for i = 1, #Decor do
	GetMobjInfo(Decor[i]).radius = 15.9
end

local Corpses = {
	MT_MISC61,
	MT_MISC62,
	MT_MISC63,
	MT_MISC64,
	MT_MISC65,
	MT_MISC66,
	MT_MISC67,
	MT_MISC68,
	MT_MISC69,
	MT_MISC71,
	MT_MISC84
}

for i = 1, #Corpses do
	GetMobjInfo(Corpses[i]).radius = 15.9
end

local Shootable = {
	MT_PLAYER,
	MT_POSSESSED,
	MT_SHOTGUY,
	MT_VILE,
	MT_UNDEAD,
	MT_FATSO,
	MT_CHAINGUY,
	MT_TROOP,
	MT_SERGEANT,
	MT_SHADOWS,
	MT_HEAD,
	MT_BRUISER,
	MT_KNIGHT,
	MT_SKULL,
	MT_SPIDER,
	MT_BABY,
	MT_CYBORG,
	MT_PAIN,
	MT_WOLFSS,
	MT_KEEN,
	MT_BOSSBRAIN,
	MT_BARREL,
}

for i = 1, #Shootable do
	local info = GetMobjInfo(Shootable[i])
	info.radius = info.radius - 0.1
end
