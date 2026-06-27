--	Filename:	SharedConstants.lua
--	Project:	Sirus Game Interface
--	Author:		Nyll
--	E-mail:		nyll@sirus.su
--	Web:		https://sirus.su/

S_GLOBAL = S_GLOBAL or {}

enum:E_DEFAULT_CLIENT_EVENTS {
	[240] = "LANGUAGE_LIST_CHANGED"
}

enum:E_CLIEN_CUSTOM_EVENTS {
	"AUCTION_CANCELED",
	"AUCTION_HOUSE_AUCTION_CREATED",
	"AUCTION_HOUSE_BROWSE_FAILURE",
	"AUCTION_HOUSE_BROWSE_RESULTS_ADDED",
	"AUCTION_HOUSE_BROWSE_RESULTS_UPDATED",
	"AUCTION_HOUSE_FAVORITES_UPDATED",
	"AUCTION_HOUSE_NEW_BID_RECEIVED",
	"AUCTION_HOUSE_NEW_RESULTS_RECEIVED",
	"AUCTION_HOUSE_THROTTLED_MESSAGE_DROPPED",
	"AUCTION_HOUSE_THROTTLED_MESSAGE_QUEUED",
	"AUCTION_HOUSE_THROTTLED_MESSAGE_RESPONSE_RECEIVED",
	"AUCTION_HOUSE_THROTTLED_MESSAGE_SENT",
	"AUCTION_HOUSE_THROTTLED_SYSTEM_READY",
	"AUCTION_MULTISELL_FAILURE",
	"AUCTION_MULTISELL_START",
	"AUCTION_MULTISELL_UPDATE",
	"BID_ADDED",
	"BIDS_UPDATED",
	"COMMODITY_PRICE_UNAVAILABLE",
	"COMMODITY_PRICE_UPDATED",
	"COMMODITY_PURCHASE_FAILED",
	"COMMODITY_PURCHASE_SUCCEEDED",
	"COMMODITY_PURCHASED",
	"COMMODITY_SEARCH_RESULTS_ADDED",
	"COMMODITY_SEARCH_RESULTS_UPDATED",
	"EXTRA_BROWSE_INFO_RECEIVED",
	"ITEM_KEY_ITEM_INFO_RECEIVED",
	"ITEM_PURCHASED",
	"ITEM_SEARCH_RESULTS_ADDED",
	"ITEM_SEARCH_RESULTS_UPDATED",
	"OWNED_AUCTION_BIDDER_INFO_RECEIVED",
	"OWNED_AUCTIONS_UPDATED",
	"REPLICATE_ITEM_LIST_UPDATE",

	"AUCTION_HOUSE_CLOSED",
	"AUCTION_HOUSE_DISABLED",
	"AUCTION_HOUSE_SHOW",

	"TRANSMOG_COLLECTION_UPDATED",
	"TRANSMOG_COLLECTION_ITEM_UPDATE",
	"TRANSMOG_SOURCE_COLLECTABILITY_UPDATE",
	"TRANSMOG_SEARCH_UPDATED",
	"TRANSMOG_OUTFITS_CHANGED",
	"TRANSMOGRIFY_CLOSE",
	"TRANSMOGRIFY_OPEN",
	"TRANSMOGRIFY_SUCCESS",
	"TRANSMOGRIFY_UPDATE",

	"UPDATE_MINI_GAMES_STATUS",
	"UPDATE_MINI_GAME",
	"UPDATE_MINI_GAME_SCORE",
	"UPDATE_AVAILABLE_MINI_GAMES",
	"MINI_GAME_LOST",
	"MINI_GAME_WON",
	"MINI_GAME_INVITE",
	"MINI_GAME_INVITE_STATUS",
	"MINI_GAME_INVITE_ACCEPT",
	"MINI_GAME_INVITE_ABADDON",
}

enum:E_REALM_ID {
	[5] = "SIRUS",
	[9] = "SCOURGE",
	[16] = "FROSTMOURNE",
	[21] = "NELTHARION",
	[33] = "ALGALON",
}

SHARED_SIRUS_REALM_NAME = "Dark Chaos 3.3.5a"
SHARED_SCOURGE_REALM_NAME = "Scourge x2 - 3.3.5a+"
SHARED_FROSTMOURNE_REALM_NAME = "Frostmourne x1 - 3.3.5a+"
SHARED_NELTHARION_REALM_NAME = "Neltharion x3 - 3.3.5a+"
SHARED_ALGALON_REALM_NAME = "Algalon x4 - 3.3.5a"

SHARED_SCOURGE_PROXY_REALM_NAME = "Proxy Scourge x2 - 3.3.5a+"
SHARED_ALGALON_PROXY_REALM_NAME = "Proxy Algalon x4 - 3.3.5a"

SIRUS_ROLE_FLAG_DAMAGER = 1
SIRUS_ROLE_FLAG_HEAL = 2
SIRUS_ROLE_FLAG_TANK = 4

REALM_ID_SIRUS = 5

MIN_CHARACTER_SEARCH = 3

BATTLEGROUND_ARATHI_BASIN = 462
BATTLEGROUND_WARSONG_GULCH = 444
BATTLEGROUND_ISLE_OF_CONQUEST = 541
BATTLEGROUND_ALTERAC_VALLEY = 402
BATTLEGROUND_SILVERSHARD_MINES = 861
BATTLEGROUND_EYE_OF_THE_STORM = 483
BATTLEGROUND_SLAVERY_VALLEY = 611
BATTLEGROUND_TEMPLE_OF_KOTMGU = 917

LE_EXPANSION_LEVEL_CURRENT = 2

LE_EXPANSION_CLASSIC = 0
LE_EXPANSION_BURNING_CRUSADE = 1
LE_EXPANSION_WRATH_OF_THE_LICH_KING = 2
LE_EXPANSION_CATACLYSM = 3
LE_EXPANSION_MISTS_OF_PANDARIA = 4
LE_EXPANSION_WARLORDS_OF_DRAENOR = 5
LE_EXPANSION_LEGION = 6
LE_EXPANSION_BATTLE_FOR_AZEROTH = 7
LE_EXPANSION_SHADOWLANDS = 8

LE_ITEM_QUALITY_COMMON = 1
LE_ITEM_QUALITY_EPIC = 4
LE_ITEM_QUALITY_HEIRLOOM = 7
LE_ITEM_QUALITY_LEGENDARY = 5
LE_ITEM_QUALITY_POOR = 0
LE_ITEM_QUALITY_RARE = 3
LE_ITEM_QUALITY_UNCOMMON = 2
LE_ITEM_QUALITY_WOW_TOKEN = 8
LE_ITEM_QUALITY_ARTIFACT = 6

LE_ITEM_FILTER_TYPE_HEAD = 1
LE_ITEM_FILTER_TYPE_NECK = 2
LE_ITEM_FILTER_TYPE_SHOULDER = 3
LE_ITEM_FILTER_TYPE_CLOAK = 16
LE_ITEM_FILTER_TYPE_CHEST = 5
LE_ITEM_FILTER_TYPE_WRIST = 9
LE_ITEM_FILTER_TYPE_HAND = 10
LE_ITEM_FILTER_TYPE_WAIST = 6
LE_ITEM_FILTER_TYPE_LEGS = 7
LE_ITEM_FILTER_TYPE_FEET = 8
LE_ITEM_FILTER_TYPE_MAIN_HAND = 21
LE_ITEM_FILTER_TYPE_OFF_HAND = 22
LE_ITEM_FILTER_TYPE_2HWEAPON = 32
LE_ITEM_FILTER_TYPE_HWEAPON = 33
LE_ITEM_FILTER_TYPE_FINGER = 11
LE_ITEM_FILTER_TYPE_TRINKET = 12
LE_ITEM_FILTER_TYPE_ARTIFACT_RELIC = 30
LE_ITEM_FILTER_TYPE_RANGED = 31

S_RESET_FRAME_STATE_TIME = 30

S_GENDER_FILESTRING = {[0] = "MALE", [1] = "FEMALE", [2] = "NONE"}
S_GENDER_FILESTRING_INVERT = tInvert(S_GENDER_FILESTRING)

NORMAL_FONT_COLOR			= CreateColor(1.0, 0.82, 0.0)
HIGHLIGHT_FONT_COLOR		= CreateColor(1.0, 1.0, 1.0)
RED_FONT_COLOR				= CreateColor(1.0, 0.1, 0.1)
DIM_RED_FONT_COLOR			= CreateColor(0.8, 0.1, 0.1)
GREEN_FONT_COLOR			= CreateColor(0.1, 1.0, 0.1)
GRAY_FONT_COLOR				= CreateColor(0.5, 0.5, 0.5)
YELLOW_FONT_COLOR			= CreateColor(1.0, 1.0, 0.0)
BLUE_FONT_COLOR				= CreateColor(0, 0.749, 0.953)
LIGHTYELLOW_FONT_COLOR		= CreateColor(1.0, 1.0, 0.6)
ORANGE_FONT_COLOR			= CreateColor(1.0, 0.5, 0.25)
PASSIVE_SPELL_FONT_COLOR	= CreateColor(0.77, 0.64, 0.0)
BATTLENET_FONT_COLOR 		= CreateColor(0.510, 0.773, 1.0)
TRANSMOGRIFY_FONT_COLOR		= CreateColor(1, 0.5, 1)
DISABLED_FONT_COLOR			= CreateColor(0.498, 0.498, 0.498)
LIGHTBLUE_FONT_COLOR		= CreateColor(0.53, 0.67, 1.0)
BLUEHELP_FONT_COLOR			= CreateColor(0, 0.8, 1)
WHITE_FONT_COLOR			= CreateColor(1, 1, 1)

LOOT_FONT_COLOR 	= CreateColor(0, 0.666, 0)
SYSTEM_FONT_COLOR 	= CreateColor(1, 1, 0)

-- faction
PLAYER_FACTION_GROUP = { [0] = "Horde", [1] = "Alliance", [2] = "Renegade", [3] = "Neutral", Horde = 0, Alliance = 1, Renegade = 2, Neutral = 3 };
SERVER_PLAYER_FACTION_GROUP = { [0] = "Alliance", [1] = "Horde", [2] = "Renegade", [3] = "Neutral", Alliance = 0, Horde = 1, Renegade = 2, Neutral = 3 }
SERVER_PLAYER_TEAM = { [469] = "Alliance", [67] = "Horde", [1187] = "Renegade", [0] = "Neutral", Alliance = 469, Horde = 67, Renegade = 1187, Neutral = 0 }
PLAYER_FACTION_COLORS = { [0] = CreateColor(0.90, 0.05, 0.07), [1] = CreateColor(0.29, 0.33, 0.91) }

SERVER_FACTION_TO_GAME_FACTION = {
	[SERVER_PLAYER_FACTION_GROUP.Horde] = PLAYER_FACTION_GROUP.Horde,
	[SERVER_PLAYER_FACTION_GROUP.Alliance] = PLAYER_FACTION_GROUP.Alliance,
	[SERVER_PLAYER_FACTION_GROUP.Renegade] = PLAYER_FACTION_GROUP.Renegade,
}

GAME_FACTION_TO_SERVER_FACTION = {
	[PLAYER_FACTION_GROUP.Horde] = SERVER_PLAYER_FACTION_GROUP.Horde,
	[PLAYER_FACTION_GROUP.Alliance] = SERVER_PLAYER_FACTION_GROUP.Alliance,
	[PLAYER_FACTION_GROUP.Renegade] = SERVER_PLAYER_FACTION_GROUP.Renegade,
}

SERVER_PLAYER_TEAM_TO_GAME_FACTION = {
	[SERVER_PLAYER_TEAM.Horde] = PLAYER_FACTION_GROUP.Horde,
	[SERVER_PLAYER_TEAM.Alliance] = PLAYER_FACTION_GROUP.Alliance,
	[SERVER_PLAYER_TEAM.Renegade] = PLAYER_FACTION_GROUP.Renegade,
}

PLAYER_FACTION_LANGUAGE = {
	[PLAYER_FACTION_GROUP.Horde] = LANGUAGE_HORDE,
	[PLAYER_FACTION_GROUP.Alliance] = LANGUAGE_ALLIANCE,
	[PLAYER_FACTION_GROUP.Renegade] = LANGUAGE_RENEGADE,
}

BAG_ITEM_QUALITY_COLORS = {
	[LE_ITEM_QUALITY_COMMON] = CreateColor(0.65882, 0.65882, 0.65882),
	[LE_ITEM_QUALITY_UNCOMMON] = CreateColor(0.08235, 0.70196, 0),
	[LE_ITEM_QUALITY_RARE] = CreateColor(0, 0.56863, 0.94902),
	[LE_ITEM_QUALITY_EPIC] = CreateColor(0.78431, 0.27059, 0.98039),
	[LE_ITEM_QUALITY_LEGENDARY] = CreateColor(1, 0.50196, 0),
	[LE_ITEM_QUALITY_ARTIFACT] = CreateColor(0.90196, 0.8, 0.50196),
	[LE_ITEM_QUALITY_HEIRLOOM] = CreateColor(0.90196, 0.8, 0.50196),
	[LE_ITEM_QUALITY_WOW_TOKEN] = CreateColor(0, 0.8, 1),
}

NEW_ITEM_ATLAS_BY_QUALITY = {
	[LE_ITEM_QUALITY_POOR] = {0.00390625, 0.15625, 0.699219, 0.821562},
	[LE_ITEM_QUALITY_COMMON] = {0.00390625, 0.15625, 0.699219, 0.821562},
	[LE_ITEM_QUALITY_UNCOMMON] = {0.542969, 0.695312, 0.164062, 0.316406},
	[LE_ITEM_QUALITY_RARE] = {0.703125, 0.855469, 0.00390625, 0.15625},
	[LE_ITEM_QUALITY_EPIC] = {0, 0.16015625, 0.359375, 0.51953125},
	[LE_ITEM_QUALITY_LEGENDARY] = {0.69921875, 0.859375, 0.16015625, 0.3203125},
	[LE_ITEM_QUALITY_ARTIFACT] = {0.363281, 0.527344, 0.183594, 0.347656},
	[LE_ITEM_QUALITY_HEIRLOOM] = {0.363281, 0.527344, 0.183594, 0.347656},
}

LOOT_BORDER_BY_QUALITY = {
	[LE_ITEM_QUALITY_UNCOMMON] = {0.614258, 0.670898, 0.707031, 0.933594},
	[LE_ITEM_QUALITY_RARE] = {0.555664, 0.612305, 0.707031, 0.933594},
	[LE_ITEM_QUALITY_EPIC] = {0.790039, 0.84668, 0.707031, 0.933594},
	[LE_ITEM_QUALITY_LEGENDARY] = {0.731445, 0.788086, 0.707031, 0.933594},
	[LE_ITEM_QUALITY_HEIRLOOM] = {0.672852, 0.729492, 0.707031, 0.933594},
	[LE_ITEM_QUALITY_ARTIFACT] = {0.895508, 0.952148, 0.386719, 0.613281},
}

MAX_PLAYER_LEVEL_TABLE = {}
MAX_PLAYER_LEVEL_TABLE[LE_EXPANSION_CLASSIC] = 60
MAX_PLAYER_LEVEL_TABLE[LE_EXPANSION_BURNING_CRUSADE] = 70
MAX_PLAYER_LEVEL_TABLE[LE_EXPANSION_WRATH_OF_THE_LICH_KING] = 80
MAX_PLAYER_LEVEL_TABLE[LE_EXPANSION_CATACLYSM] = 85
MAX_PLAYER_LEVEL_TABLE[LE_EXPANSION_MISTS_OF_PANDARIA] = 90
MAX_PLAYER_LEVEL_TABLE[LE_EXPANSION_WARLORDS_OF_DRAENOR] = 100
MAX_PLAYER_LEVEL_TABLE[LE_EXPANSION_LEGION] = 110


DRESSUPMODEL_CAMERA_POSITION = {
	["Human2"] = {0.691001, 1.018000, 0.999001},
	["Human3"] = {0.487000, 0.985001, 0.999001},
	["Dwarf2"] = {1.767001, 0.993001, 0.845001},
	["Dwarf3"] = {0.794001, 0.960001, 1.050001},
	["NightElf2"] = {0.341001, 0.996001, 0.999001},
	["NightElf3"] = {1.255001, 0.981001, 1.000000},
	["Gnome2"] = {0.948000, 1.000000, 0.896001},
	["Gnome3"] = {0.794001, 0.997001, 0.894001},
	["Draenei2"] = {1.348001, 1.000000, 1.049001},
	["Draenei3"] = {0.743001, 0.971000, 0.999001},
	["Worgen2"] = {1.101001, 0.911000, 0.845001},
	["Worgen3"] = {1.972001, 1.156000, 1.000000},
	["Queldo2"] = {1.101001, 1.013000, 1.000000},
	["Queldo3"] = {0.640001, 1.101001, 0.971000},
	["Orc2"] = {0.743001, 1.044001, 1.000000},
	["Orc3"] = {0.743001, 0.988001, 1.000000},
	["Scourge2"] = {0.896001, 1.024001, 1.000000},
	["Scourge3"] = {1.767001, 1.019001, 1.050001},
	["Tauren2"] = {1.665001, 0.996001, 0.948000},
	["Tauren3"] = {0.691001, 1.031000, 0.896001},
	["Goblin2"] = {0.691001, 1.003000, 0.794001},
	["Goblin3"] = {0.896001, 1.000000, 0.896001},
	["Troll2"] = {1.050001, 0.958001, 1.000000},
	["Troll3"] = {0.794001, 0.930001, 0.999001},
	["Naga2"] = {1.357001, 1.063001, 1.101001},
	["Naga3"] = {1.562001, 1.057001, 1.050001},
	["BloodElf2"] = {1.101001, 1.013000, 1.000000},
	["BloodElf3"] = {0.640001, 1.101001, 0.971000},
	["Nightborne2"] = {1.000000, 1.000000, 1.000000},
	["Nightborne3"] = {1.000000, 1.000000, 1.000000},
	["VoidElf2"] = {1.000000, 1.000000, 1.000000},
	["VoidElf3"] = {1.000000, 1.000000, 1.000000},
	["Eredar2"] = {1.000000, 1.000000, 1.000000},
	["Eredar3"] = {1.000000, 1.000000, 1.000000},
	["DarkIronDwarf2"] = {1.000000, 1.000000, 1.000000},
	["DarkIronDwarf3"] = {1.000000, 1.000000, 1.000000},
}

SHARED_CONSTANTS_SPECIALIZATION = {
	["HUNTER"] = {
		{
			name = "Beast Mastery",
			icon = "Interface\\Icons\\ABILITY_HUNTER_BESTIALDISCIPLINE",
			role = "DAMAGER",
			description = "A master of the wild who can tame a wide variety of beasts to fight alongside them in combat."
		},
		{
			name = "Marksmanship",
			icon = "Interface\\Icons\\Ability_Marksmanship",
			role = "DAMAGER",
			description = "A master sharpshooter who has no equal at bringing down enemies from great range."
		},
		{
			name = "Survival",
			icon = "Interface\\Icons\\Ability_Hunter_SwiftStrike",
			role = "DAMAGER",
			description = "A tracker who prefers to use poisons, explosives, and traps."
		},
	},
	["WARRIOR"] = {
		{
			name = "Arms",
			icon = "Interface\\Icons\\ability_warrior_savageblow",
			role = "DAMAGER",
			description = "A battle-hardened master of two-handed weapons who relies on mobility and powerful strikes in combat."
		},
		{
			name = "Fury",
			icon = "Interface\\Icons\\ability_warrior_innerrage",
			role = "DAMAGER",
			description = "A furious berserker wielding a weapon in each hand, unleashing a flurry of blows able to hack enemies to pieces."
		},
		{
			name = "Protection",
			icon = "Interface\\Icons\\ability_warrior_defensivestance",
			role = "TANK",
			description = "A hardy defender who uses a shield to protect themselves and their allies from enemy attacks."
		},
	},
	["PALADIN"] = {
		{
			name = "Holy",
			icon = "Interface\\Icons\\spell_holy_holybolt",
			role = "HEALER",
			description = "A skilled knight who calls upon the powers of the Light to protect and heal."
		},
		{
			name = "Protection",
			icon = "Interface\\Icons\\ability_paladin_shieldofthetemplar",
			role = "TANK",
			description = "A fearless guardian who uses the magic of the Light to shield themselves and their allies from enemy attacks."
		},
		{
			name = "Retribution",
			icon = "Interface\\Icons\\spell_holy_auraoflight",
			role = "DAMAGER",
			description = "A champion of justice who metes out punishment to enemies using weapons and the magic of the Light."
		},
	},
	["ROGUE"] = {
		{
			name = "Assassination",
			icon = "Interface\\Icons\\ability_rogue_eviscerate",
			role = "DAMAGER",
			description = "A deadly master of poisons who dispatches enemies with strikes from envenomed daggers."
		},
		{
			name = "Combat",
			icon = "Interface\\Icons\\ability_backstab",
			role = "DAMAGER",
			description = "A nimble and cunning cutthroat, a master of close-quarters combat."
		},
		{
			name = "Subtlety",
			icon = "Interface\\Icons\\ability_stealth",
			role = "DAMAGER",
			description = "A master of stealth, perfectly skilled in the arts of unseen movement and sudden, lethal attacks."
		},
	},
	["PRIEST"] = {
		{
			name = "Discipline",
			icon = "Interface\\Icons\\spell_holy_powerwordshield",
			role = "HEALER",
			description = "Uses magic to protect allies and heal their wounds."
		},
		{
			name = "Holy",
			icon = "Interface\\Icons\\spell_holy_guardianspirit",
			role = "HEALER",
			description = "A versatile healer who can mend single targets and groups, and can even heal from beyond death."
		},
		{
			name = "Shadow",
			icon = "Interface\\Icons\\spell_shadow_shadowwordpain",
			role = "DAMAGER",
			description = "Uses Shadow magic to destroy enemies, favoring spells that deal damage over time."
		},
	},
	["DEATHKNIGHT"] = {
		{
			name = "Blood",
			icon = "Interface\\Icons\\spell_deathknight_bloodpresence",
			role = "DAMAGER",
			description = "A dark conqueror who holds back the enemy onslaught, absorbing their life force and using it to empower their attacks."
		},
		{
			name = "Frost",
			icon = "Interface\\Icons\\spell_deathknight_frostpresence",
			role = "DAMAGER",
			description = "A merciless harbinger of doom who wields the power of runes and delivers lightning-fast weapon strikes."
		},
		{
			name = "Unholy",
			icon = "Interface\\Icons\\spell_deathknight_unholypresence",
			role = "DAMAGER",
			description = "A master of death and decay who spreads disease and commands undead minions."
		},
	},
	["SHAMAN"] = {
		{
			name = "Elemental",
			icon = "Interface\\Icons\\spell_nature_lightning",
			role = "DAMAGER",
			description = "A spellcaster who bends the destructive forces of the elements to their will."
		},
		{
			name = "Enhancement",
			icon = "Interface\\Icons\\spell_nature_lightningshield",
			role = "DAMAGER",
			description = "A fighter who uses totems and strikes enemies with weapons empowered by elemental spirits."
		},
		{
			name = "Restoration",
			icon = "Interface\\Icons\\spell_nature_magicimmunity",
			role = "HEALER",
			description = "A healer who calls upon ancestral spirits and the cleansing power of water to mend allies' wounds."
		},
	},
	["MAGE"] = {
		{
			name = "Arcane",
			icon = "Interface\\Icons\\spell_holy_magicalsentry",
			role = "DAMAGER",
			description = "Wields the energy of arcane magic, commanding time and space."
		},
		{
			name = "Fire",
			icon = "Interface\\Icons\\spell_fire_firebolt02",
			role = "DAMAGER",
			description = "Incinerates enemies with fireballs and dragon's breath."
		},
		{
			name = "Frost",
			icon = "Interface\\Icons\\spell_frost_frostbolt02",
			role = "DAMAGER",
			description = "Uses frost magic to freeze enemies and shatter them to pieces."
		},
	},
	["WARLOCK"] = {
		{
			name = "Affliction",
			icon = "Interface\\Icons\\spell_shadow_deathcoil",
			role = "DAMAGER",
			description = "A master of dark magic who terrifies enemies, drains their strength, and deals damage over time."
		},
		{
			name = "Demonology",
			icon = "Interface\\Icons\\spell_shadow_metamorphosis",
			role = "DAMAGER",
			description = "Equally skilled in fire and Shadow magic, supported by powerful demons."
		},
		{
			name = "Destruction",
			icon = "Interface\\Icons\\spell_shadow_rainoffire",
			role = "DAMAGER",
			description = "Calls down demonic fire that scorches and destroys enemies."
		},
	},
	["DRUID"] = {
		{
			name = "Balance",
			icon = "Interface\\Icons\\spell_nature_starfall",
			role = "DAMAGER",
			description = "Takes the form of a wise moonkin and, balancing the powers of arcane and nature magic, destroys enemies from afar."
		},
		{
			name = "Feral",
			icon = "Interface\\Icons\\ability_racial_bearform",
			role = "DAMAGER",
			description = "Takes the form of a cat to claw and bite enemies and make them bleed, or a mighty bear to protect allies."
		},
		{
			name = "Restoration",
			icon = "Interface\\Icons\\spell_nature_healingtouch",
			role = "HEALER",
			description = "Uses healing-over-time spells to sustain allies. \nCan take the form of a tree to heal even more effectively."
		},
	},
}

SHARED_BARTENDER4_MICROMENU_BUTTONS = {
	"CharacterMicroButton",
	"SpellbookMicroButton",
	"TalentMicroButton",
	"AchievementMicroButton",
	"QuestLogMicroButton",
	"SocialsMicroButton",
	"GuildMicroButton",
	"LFDMicroButton",
	"CollectionsMicroButton",
	"EncounterJournalMicroButton",
	"StoreMicroButton",
	"MainMenuMicroButton",
}

SHARED_MICROMENU_BUTTONS = SHARED_BARTENDER4_MICROMENU_BUTTONS

SHARED_SIRUS_LOGO_COORD = {
	{0, 0.759765625, 0, 0.205078125}, -- Sirus
	{0, 0.759765625, 0.2158203125, 0.4208984375}, -- Scourge
	{0, 0.759765625, 0.431640625, 0.63671875}, -- Frostmourne
	{0, 0.759765625, 0.6474609375, 0.8525390625} -- Neltharion
}

GUILD_TABARD_EMBLEM_COLOR = {
	[0] = CreateColor(0.40392156862745, 0, 0.12941176470588),
	[1] = CreateColor(0.40392156862745, 0.13725490196078, 0),
	[2] = CreateColor(0.38823529411765, 0.40392156862745, 0),
	[3] = CreateColor(0.31764705882353, 0.40392156862745, 0),
	[4] = CreateColor(0.55686274509804, 0.5921568627451, 0),
	[5] = CreateColor(0.55686274509804, 0.5921568627451, 0),
	[6] = CreateColor(0.2156862745098, 0.40392156862745, 0),
	[7] = CreateColor(0, 0.40392156862745, 0.12156862745098),
	[8] = CreateColor(0, 0.40392156862745, 0.34117647058824),
	[9] = CreateColor(0, 0.28235294117647, 0.40392156862745),
	[10] = CreateColor(0.035294117647059, 0.16470588235294, 0.36470588235294),
	[11] = CreateColor(0.42745098039216, 0, 0.46666666666667),
	[12] = CreateColor(0.36470588235294, 0.035294117647059, 0.30980392156863),
	[13] = CreateColor(0.32941176470588, 0.2156862745098, 0.03921568627451),
	[14] = CreateColor(1, 1, 1),
	[15] = CreateColor(0.062745098039216, 0.082352941176471, 0.090196078431373),
	[16] = CreateColor(0.87450980392157, 0.64705882352941, 0.35294117647059),
}

GUILD_TABARD_BORDER_COLOR = {
	["ALL"] = GUILD_TABARD_EMBLEM_COLOR,
	[1] = {
		[0] = CreateColor(0.40392156862745, 0, 0.12941176470588),
		[1] = CreateColor(0.40392156862745, 0.13725490196078, 0),
		[2] = CreateColor(0.38823529411765, 0.40392156862745, 0),
		[3] = CreateColor(0.76078431372549, 0.63137254901961, 0.3921568627451),
		[4] = CreateColor(0.76470588235294, 0.76470588235294, 0.76470588235294),
		[5] = CreateColor(0, 0.40392156862745, 0.34117647058824),
		[6] = CreateColor(0.082352941176471, 0.72549019607843, 1),
		[7] = CreateColor(0.2, 0.67450980392157, 0.95686274509804),
		[8] = CreateColor(0.50196078431373, 0.50196078431373, 1),
		[9] = CreateColor(0.1843137254902, 0.22352941176471, 0.34901960784314),
		[10] = CreateColor(0.37647058823529, 0.24705882352941, 0.41176470588235),
		[11] = CreateColor(0.42745098039216, 0.13725490196078, 0.32941176470588),
		[12] = CreateColor(0.37254901960784, 0.12156862745098, 0.29019607843137),
		[13] = CreateColor(0.77647058823529, 0.4156862745098, 0.14901960784314),
		[14] = CreateColor(0.64313725490196, 0.57647058823529, 0.45882352941176),
		[15] = CreateColor(0.27843137254902, 0.41176470588235, 0.43921568627451),
		[16] = CreateColor(0.83921568627451, 0.81960784313725, 0.094117647058824),
	}
}

GUILD_TABARD_BACKGROUND_COLOR = {
	[0] = CreateColor(1, 0.21960784313725, 0.98039215686275),
	[1] = CreateColor(1, 0.12549019607843, 0.53333333333333),
	[2] = CreateColor(0.40392156862745, 0, 0.12941176470588),
	[3] = CreateColor(1, 0.53725490196078, 0.10588235294118),
	[4] = CreateColor(0.88235294117647, 0.27058823529412, 0),
	[5] = CreateColor(0.69411764705882, 0, 0.18039215686275),
	[6] = CreateColor(0.76862745098039, 0.6078431372549, 0),
	[7] = CreateColor(1, 0.53725490196078, 0.10588235294118),
	[8] = CreateColor(0.68235294117647, 0.29411764705882, 0),
	[9] = CreateColor(0.95294117647059, 0.7921568627451, 0),
	[10] = CreateColor(0.76862745098039, 0.6078431372549, 0),
	[11] = CreateColor(0.5843137254902, 0.42352941176471, 0),
	[12] = CreateColor(1, 1, 0.07843137254902),
	[13] = CreateColor(0.8156862745098, 0.8156862745098, 0.07843137254902),
	[14] = CreateColor(0.63137254901961, 0.63137254901961, 0.07843137254902),
	[15] = CreateColor(0.73725490196078, 0.96470588235294, 0.10588235294118),
	[16] = CreateColor(0.55686274509804, 0.5921568627451, 0),
	[17] = CreateColor(0.34509803921569, 0.50196078431373, 0),
	[18] = CreateColor(0.53333333333333, 0.72941176470588, 0.011764705882353),
	[19] = CreateColor(0.38823529411765, 0.63921568627451, 0),
	[20] = CreateColor(0, 0.50980392156863, 0.058823529411765),
	[21] = CreateColor(0.11764705882353, 1, 0.4078431372549),
	[22] = CreateColor(0.015686274509804, 0.76470588235294, 0.27843137254902),
	[23] = CreateColor(0, 0.40392156862745, 0.12156862745098),
	[24] = CreateColor(0.11764705882353, 0.96862745098039, 0.75686274509804),
	[25] = CreateColor(0.015686274509804, 0.71764705882353, 0.56078431372549),
	[26] = CreateColor(0, 0.56470588235294, 0.38039215686275),
	[27] = CreateColor(0.12941176470588, 0.86274509803922, 1),
	[28] = CreateColor(0, 0.6156862745098, 0.77254901960784),
	[29] = CreateColor(0, 0.38823529411765, 0.56862745098039),
	[30] = CreateColor(0.30196078431373, 0.55686274509804, 0.85490196078431),
	[31] = CreateColor(0.17254901960784, 0.4156862745098, 0.68235294117647),
	[32] = CreateColor(0, 0.2078431372549, 0.50980392156863),
	[33] = CreateColor(0.82745098039216, 0.29019607843137, 0.7843137254902),
	[34] = CreateColor(0.67843137254902, 0.16078431372549, 0.67450980392157),
	[35] = CreateColor(0.52549019607843, 0.058823529411765, 0.60392156862745),
	[36] = CreateColor(0.9921568627451, 0, 0.65098039215686),
	[37] = CreateColor(0.82745098039216, 0, 0.52941176470588),
	[38] = CreateColor(0.63921568627451, 0, 0.4078431372549),
	[39] = CreateColor(1, 0.12549019607843, 0.53333333333333),
	[40] = CreateColor(0.61960784313725, 0, 0.21176470588235),
	[41] = CreateColor(0.40392156862745, 0, 0.12941176470588),
	[42] = CreateColor(0.52941176470588, 0.33333333333333, 0.074509803921569),
	[43] = CreateColor(0.32941176470588, 0.2156862745098, 0.03921568627451),
	[44] = CreateColor(0.30980392156863, 0.13725490196078, 0),
	[45] = CreateColor(0.13725490196078, 0.13725490196078, 0.13725490196078),
	[46] = CreateColor(0.50196078431373, 0.50196078431373, 0.50196078431373),
	[47] = CreateColor(0.70588235294118, 0.73333333333333, 0.65882352941176),
	[48] = CreateColor(0.84313725490196, 0.86666666666667, 0.79607843137255),
	[49] = CreateColor(1, 1, 1),
	[50] = CreateColor(0.98823529411765, 0.4078431372549, 0.56862745098039),
}

SHARED_TABARD_EMBLEM_COLOR = {
	[0] = {103, 0, 33},
	[1] = {103, 35, 0},
	[2] = {99, 103, 0},
	[3] = {81, 103, 0},
	[4] = {142, 151, 0},
	[5] = {142, 151, 0},
	[6] = {55, 103, 0},
	[7] = {0, 103, 31},
	[8] = {0, 103, 87},
	[9] = {0, 72, 103},
	[10] = {9, 42, 93},
	[11] = {109, 0, 119},
	[12] = {93, 9, 79},
	[13] = {84, 55, 10},
	[14] = {255, 255, 255},
	[15] = {16, 21, 23},
	[16] = {223, 165, 90}
}

SHARED_TABARD_BORDER_COLOR = {
	["ALL"] = {
		[0] = {103, 0, 33},
		[1] = {103, 35, 0},
		[2] = {99, 103, 0},
		[3] = {81, 103, 0},
		[4] = {142, 151, 0},
		[5] = {142, 151, 0},
		[6] = {55, 103, 0},
		[7] = {0, 103, 31},
		[8] = {0, 103, 87},
		[9] = {0, 72, 103},
		[10] = {9, 42, 93},
		[11] = {109, 0, 119},
		[12] = {93, 9, 79},
		[13] = {84, 55, 10},
		[14] = {255, 255, 255},
		[15] = {16, 21, 23},
		[16] = {223, 165, 90}
	},
	[1] = {
		[0] = {103, 0, 33},
		[1] = {103, 35, 0},
		[2] = {99, 103, 0},
		[3] = {194, 161, 100},
		[4] = {195, 195, 195},
		[5] = {0, 103, 87},
		[6] = {21, 185, 255},
		[7] = {51, 172, 244},
		[8] = {128, 128, 255},
		[9] = {47, 57, 89},
		[10] = {96, 63, 105},
		[11] = {109, 35, 84},
		[12] = {95, 31, 74},
		[13] = {198, 106, 38},
		[14] = {164, 147, 117},
		[15] = {71, 105, 112},
		[16] = {214, 209, 24},
	}
}

SHARED_TABARD_BACKGROUND_COLOR = {
	[50] = {252, 104, 145},
	[49] = {255, 255, 255},
	[48] = {215, 221, 203},
	[47] = {180, 187, 168},
	[46] = {128, 128, 128},
	[45] = {35, 35, 35},
	[44] = {79, 35, 0},
	[43] = {84, 55, 10},
	[42] = {135, 85, 19},
	[41] = {103, 0, 33},
	[40] = {158, 0, 54},
	[39] = {255, 32, 136},
	[38] = {163, 0, 104},
	[37] = {211, 0, 135},
	[36] = {253, 0, 166},
	[35] = {134, 15, 154},
	[34] = {173, 41, 172},
	[33] = {211, 74, 200},
	[32] = {0, 53, 130},
	[31] = {44, 106, 174},
	[30] = {77, 142, 218},
	[29] = {0, 99, 145},
	[28] = {0, 157, 197},
	[27] = {33, 220, 255},
	[26] = {0, 144, 97},
	[25] = {4, 183, 143},
	[24] = {30, 247, 193},
	[23] = {0, 103, 31},
	[22] = {4, 195, 71},
	[21] = {30, 255, 104},
	[20] = {0, 130, 15},
	[19] = {99, 163, 0},
	[18] = {136, 186, 3},
	[17] = {88, 128, 0},
	[16] = {142, 151, 0},
	[15] = {188, 246, 27},
	[14] = {161, 161, 20},
	[13] = {208, 208, 20},
	[12] = {255, 255, 20},
	[11] = {149, 108, 0},
	[10] = {196, 155, 0},
	[9] = {243, 202, 0},
	[8] = {174, 75, 0},
	[7] = {255, 137, 27},
	[6] = {196, 155, 0},
	[5] = {177, 0, 46},
	[4] = {225, 69, 0},
	[3] = {255, 137, 27},
	[2] = {103, 0, 33},
	[1] = {255, 32, 136},
	[0] = {255, 56, 250}
}

SHARED_INVTYPE_BY_ID = {
	[0] = "",
	[1] = "INVTYPE_HEAD",
	[2] = "INVTYPE_NECK",
	[3] = "INVTYPE_SHOULDER",
	[4] = "INVTYPE_BODY",
	[5] = "INVTYPE_CHEST",
	[6] = "INVTYPE_WAIST",
	[7] = "INVTYPE_LEGS",
	[8] = "INVTYPE_FEET",
	[9] = "INVTYPE_WRIST",
	[10] = "INVTYPE_HAND",
	[11] = "INVTYPE_FINGER",
	[12] = "INVTYPE_TRINKET",
	[13] = "INVTYPE_WEAPON",
	[14] = "INVTYPE_SHIELD",
	[15] = "INVTYPE_RANGED",
	[16] = "INVTYPE_CLOAK",
	[17] = "INVTYPE_2HWEAPON",
	[18] = "INVTYPE_BAG",
	[19] = "INVTYPE_TABARD",
	[20] = "INVTYPE_ROBE",
	[21] = "INVTYPE_WEAPONMAINHAND",
	[22] = "INVTYPE_WEAPONOFFHAND",
	[23] = "INVTYPE_HOLDABLE",
	[24] = "INVTYPE_AMMO",
	[25] = "INVTYPE_THROWN",
	[26] = "INVTYPE_RANGEDRIGHT",
	[27] = "INVTYPE_QUIVER",
	[28] = "INVTYPE_RELIC",
}

SIRUS_TALENT_INFO = {
	["default"] = {
		[1] = {
			color = {r=1.0, g=0.72, b=0.1},
		},
		[2] = {
			color = {r=1.0, g=0.0, b=0.0},
		},
		[3] = {
			color = {r=0.3, g=0.5, b=1.0},
		}
	},
	["PET_409"] = {
		-- Tenacity
		[1] = {
			color = {r=1.0, g=0.1, b=1.0},
		}
	},

	["PET_410"] = {
		-- Ferocity
		[1] = {
			color = {r=1.0, g=0.0, b=0.0},
		}
	},

	["PET_411"] = {
		-- Cunning
		[1] = {
			color = {r=0.0, g=0.6, b=1.0},
		}
	},
	["DEATHKNIGHT"] = {
		[1] = {
			-- Blood
			ActiveBonus = {55262},
			PassiveBonus = {50029, 49395, 53138},
			Description = "A dark protector who holds back the enemy onslaught, or smites them with frenzied attacks, sustaining themselves on their life force.",
			color = {r=1.0, g=0.0, b=0.0},
			role = 5 -- Damager + Tank
		},
		[2] = {
			-- Frost
			ActiveBonus = {55268},
			PassiveBonus = {54637, 66192, 51130},
			Description = "A merciless harbinger of doom who wields the power of runes and delivers lightning-fast weapon strikes.",
			color = {r=0.3, g=0.5, b=1.0},
			role = 5 -- Damager + Tank
		},
		[3] = {
			-- Unholy
			ActiveBonus = {55271},
			PassiveBonus = {51161, 56835, 49655},
			Description = "A master of death and decay who spreads disease and commands undead minions.",
			color = {r=0.2, g=0.8, b=0.2},
			role = 1 -- Damager
		}
	},

	["DRUID"] = {
		[1] = {
			-- Balance
			ActiveBonus = {53201},
			PassiveBonus = {48525, 33607, 48393},
			Description = "Takes the form of a wise moonkin and, balancing the powers of arcane and nature magic, destroys enemies from afar.",
			color = {r=0.8, g=0.3, b=0.8},
			role = 1 -- Damager
		},
		[2] = {
			-- Feral
			ActiveBonus = {50334},
			PassiveBonus = {51269, 33856, 24894},
			Description = "Takes the form of a cat to claw and bite enemies and make them bleed, or a mighty bear to protect allies.",
			color = {r=1.0, g=0.0, b=0.0},
			role = 5 -- Damager+Tank
		},
		[3] = {
			-- Restoration
			ActiveBonus = {18562},
			PassiveBonus = {48537, 51183, 34153},
			Description = "Uses healing-over-time spells to sustain allies. Can take the form of a tree to heal even more effectively.",
			color = {r=0.4, g=0.8, b=0.2},
			role = 2 -- Heal
		}
	},

	["HUNTER"] = {
		[1] = {
			-- Beast Mastery
			ActiveBonus = {19574},
			PassiveBonus = {19556, 19620, 34470},
			Description = "A master of the wild who can tame a wide variety of beasts to fight alongside them in combat.",
			color = {r=1.0, g=0.0, b=0.3},
			role = 1 -- Damager
		},
		[2] = {
			-- Marksmanship
			ActiveBonus = {49050},
			PassiveBonus = {53217, 53224, 53238},
			Description = "A master sharpshooter who has no equal at bringing down enemies from great range.",
			color = {r=0.3, g=0.6, b=1.0},
			role = 1 -- Damager
		},
		[3] = {
			-- Survival
			ActiveBonus = {60053},
			PassiveBonus = {56341, 56344, 53304},
			Description = "A tracker who prefers to use poisons, explosives, and traps.",
			color = {r=1.0, g=0.6, b=0.0},
			role = 1 -- Damager
		}
	},

	["MAGE"] = {
		[1] = {
			-- Arcane
			ActiveBonus = {12042},
			PassiveBonus = {31588, 54490, 31583},
			Description = "Wields the energy of arcane magic, commanding time and space.",
			color = {r=0.7, g=0.2, b=1.0},
			role = 1 -- Damager
		},
		[2] = {
			-- Fire
			ActiveBonus = {42891},
			PassiveBonus = {44448, 34296, 31658},
			Description = "Incinerates enemies with fireballs and dragon's breath.",
			color = {r=1.0, g=0.5, b=0.0},
			role = 1 -- Damager
		},
		[3] = {
			-- Frost
			ActiveBonus = {44572},
			PassiveBonus = {44549, 44545, 28593},
			Description = "Uses frost magic to freeze enemies and shatter them to pieces.",
			color = {r=0.3, g=0.6, b=1.0},
			role = 1 -- Damager
		}
	},

	["PALADIN"] = {
		[1] = {
			-- Holy
			ActiveBonus = {48825},
			PassiveBonus = {53576, 31841, 31836},
			Description = "Calls upon the powers of the Light to protect and heal.",
			color = {r=1.0, g=0.5, b=0.0},
			role = 2 -- Heal
		},
		[2] = {
			-- Protection
			ActiveBonus = {48827},
			PassiveBonus = {53592, 53585, 33776},
			Description = "Uses the magic of the Light to protect themselves and their allies from enemy attacks.",
			color = {r=0.3, g=0.5, b=1.0},
			role = 4 -- Tank
		},
		[3] = {
			-- Retribution
			ActiveBonus = {53385},
			PassiveBonus = {53503, 53488, 31878},
			Description = "A champion of justice who metes out punishment to enemies using weapons and the magic of the Light.",
			color = {r=1.0, g=0.0, b=0.0},
			role = 1 -- Damager
		}
	},

	["PRIEST"] = {
		[1] = {
			-- Discipline
			ActiveBonus = {53007},
			PassiveBonus = {33202, 47515, 14777},
			Description = "Uses magic to protect allies and heal their wounds.",
			color = {r=1.0, g=0.5, b=0.0},
			role = 2 -- Heal
		},
		[2] = {
			-- Holy
			ActiveBonus = {48089},
			PassiveBonus = {47560, 63543, 15031},
			Description = "A versatile healer who can mend single targets and groups, and can even heal from beyond death.",
			color = {r=0.6, g=0.6, b=1.0},
			role = 2 -- Heal
		},
		[3] = {
			-- Shadow
			ActiveBonus = {48156},
			PassiveBonus = {15332, 33371, 27840},
			Description = "Uses Shadow magic to destroy enemies, favoring spells that deal damage over time.",
			color = {r=0.7, g=0.4, b=0.8},
			role = 1 -- Damager
		}
	},

	["ROGUE"] = {
		[1] = {
			-- Assassination
			ActiveBonus = {48666},
			PassiveBonus = {51636, 51669, 58410},
			Description = "A deadly master of poisons who dispatches enemies with strikes from envenomed daggers.",
			color = {r=0.5, g=0.8, b=0.5},
			role = 1 -- Damager
		},
		[2] = {
			-- Combat
			ActiveBonus = {13877},
			PassiveBonus = {61329, 35553, 32601},
			Description = "A nimble and cunning cutthroat, a master of close-quarters combat.",
			color = {r=1.0, g=0.5, b=0.0},
			role = 1 -- Damager
		},
		[3] = {
			-- Subtlety
			ActiveBonus = {36554},
			PassiveBonus = {31223, 31220},
			Description = "A master of stealth, perfectly skilled in the arts of unseen movement and sudden, lethal attacks.",
			color = {r=0.3, g=0.5, b=1.0},
			role = 1 -- Damager
		}
	},

	["SHAMAN"] = {
		[1] = {
			-- Elemental
			ActiveBonus = {59159},
			PassiveBonus = {60188, 62101, 51486},
			Description = "A spellcaster who bends the destructive forces of the elements to their will.",
			color = {r=0.8, g=0.2, b=0.8},
			role = 1 -- Damager
		},
		[2] = {
			-- Enhancement
			ActiveBonus = {60103},
			PassiveBonus = {30798, 30814, 30809},
			Description = "A fighter who uses totems and strikes enemies with weapons empowered by elemental spirits.",
			color = {r=0.3, g=0.5, b=1.0},
			role = 1 -- Damager
		},
		[3] = {
			-- Restoration
			ActiveBonus = {49284},
			PassiveBonus = {16213, 51558, 51566},
			Description = "A healer who calls upon ancestral spirits and the cleansing power of water to mend allies' wounds.",
			color = {r=0.2, g=0.8, b=0.4},
			role = 2 -- Heal
		}
	},

	["WARLOCK"] = {
		[1] = {
			-- Affliction
			ActiveBonus = {47843},
			PassiveBonus = {17814, 18829, 63108},
			Description = "A master of dark magic who terrifies enemies, drains their strength, and deals damage over time.",
			color = {r=0.0, g=1.0, b=0.6},
			role = 1 -- Damager
		},
		[2] = {
			-- Demonology
			ActiveBonus = {30146},
			PassiveBonus = {23825, 18768},
			Description = "Equally skilled in fire and Shadow magic, supported by powerful demons.",
			color = {r=1.0, g=0.0, b=0.0},
			role = 1 -- Damager
		},
		[3] = {
			-- Destruction
			ActiveBonus = {17962},
			PassiveBonus = {63245, 17834},
			Description = "Calls down demonic fire that scorches and destroys enemies.",
			color = {r=1.0, g=0.5, b=0.0},
			role = 1 -- Damager
		}
	},

	["WARRIOR"] = {
		[1] = {
			-- Arms
			ActiveBonus = {47486},
			PassiveBonus = {12712, 46855},
			Description = "A battle-hardened master of two-handed weapons who relies on mobility and powerful strikes in combat.",
			color = {r=1.0, g=0.72, b=0.1},
			role = 1 -- Damager
		},
		[2] = {
			-- Fury
			ActiveBonus = {23881},
			PassiveBonus = {23588, 46917},
			Description = "A furious berserker wielding a weapon in each hand, unleashing a flurry of blows able to hack enemies to pieces.",
			color = {r=1.0, g=0.0, b=0.0},
			role = 1 -- Damager
		},
		[3] = {
			-- Protection
			ActiveBonus = {23922},
			PassiveBonus = {29144, 12727, 47296},
			Description = "Uses a shield to protect themselves and their allies from enemy attacks.",
			color = {r=0.3, g=0.5, b=1.0},
			role = 4 -- Tank
		}
	},
	["DEMONHUNTER"] = {
		[1] = {
			-- Devastation
			ActiveBonus = {302405},
			PassiveBonus = {302452, 302455, 302468},
			Description = "PH_DemonHunter_description_1.",
			color = {r=50 / 255, g=205 / 255, b=50/255},
			role = 1 -- Damager
		},
		[2] = {
			-- Vengeance
			ActiveBonus = {302620},
			PassiveBonus = {302618, 302612, 302631},
			Description = "PH_DemonHunter_description_2.",
			color = {r=105 / 255, g=105 / 255, b=105 / 255},
			role = 4 -- Tank
		},
		[3] = {
			-- Possession
			ActiveBonus = {302585},
			PassiveBonus = {302511, 302551, 302581},
			Description = "A fanatical demon hunter, skilled with both blades and dark magic. Striking the soul and body of their foe, they summon powerful servants.",
			color = {r=147 / 255, g=112 / 255, b=219 / 255},
			role = 1 -- Damager
		}
	},
}

CLASS_ID_WARRIOR = 1
CLASS_ID_PALADIN = 2
CLASS_ID_HUNTER = 3
CLASS_ID_ROGUE = 4
CLASS_ID_PRIEST = 5
CLASS_ID_DEATHKNIGHT = 6
CLASS_ID_SHAMAN = 7
CLASS_ID_MAGE = 8
CLASS_ID_WARLOCK = 9
CLASS_ID_DEMONHUNTER = 10
CLASS_ID_DRUID = 11

S_SPECIALIZATION_ROLE_DAMAGER_FLAG = 0x1
S_SPECIALIZATION_ROLE_TANK_FLAG = 0x2
S_SPECIALIZATION_ROLE_HEAL_FLAG = 0x4

S_SPECIALIZATION_FLAG_SPEC1 = 0x1
S_SPECIALIZATION_FLAG_SPEC2 = 0x2
S_SPECIALIZATION_FLAG_SPEC3 = 0x4

S_CLASS_SORT_ORDER = {
	[1] = {1, "WARRIOR"},
	[2] = {2, "PALADIN"},
	[3] = {4, "HUNTER"},
	[4] = {8, "ROGUE"},
	[5] = {16, "PRIEST"},
	[6] = {32, "DEATHKNIGHT"},
	[7] = {64, "SHAMAN"},
	[8] = {128, "MAGE"},
	[9] = {256, "WARLOCK"},
	[10] = {512, "DEMONHUNTER"},
	[11] = {1024, "DRUID"},
}

S_CLASS_DATA_LOCALIZATION_ASSOC = {}

do
	for index, classData in pairs(S_CLASS_SORT_ORDER) do
		local keyMale = _G["SHARED_"..classData[2].."_MALE"]
		local keyFemale = _G["SHARED_"..classData[2].."_FEMALE"]

		classData[3] = index
		classData[4] = keyMale
		classData[5] = keyFemale

		S_CLASS_DATA_LOCALIZATION_ASSOC[keyMale] = classData
		S_CLASS_DATA_LOCALIZATION_ASSOC[keyFemale] = classData
	end
end

table.lockTable(S_CLASS_SORT_ORDER)
S_MAX_CLASSES = #S_CLASS_SORT_ORDER

S_CALSS_SPECIALIZATION_DATA = {
	[CLASS_ID_WARRIOR] = { -- WARRIOR
		{161, WARRIOR_SPEC_ARMS_TITLE, WARRIOR_SPEC_ARMS_DESC, "Interface\\Icons\\Ability_Rogue_Eviscerate", S_SPECIALIZATION_ROLE_DAMAGER_FLAG, false},
		{164, WARRIOR_SPEC_FURY_TITLE, WARRIOR_SPEC_FURY_DESC, "Interface\\Icons\\Ability_Warrior_InnerRage", S_SPECIALIZATION_ROLE_DAMAGER_FLAG, true},
		{163, WARRIOR_SPEC_PROTECTION_TITLE, WARRIOR_SPEC_PROTECTION_DESC, "Interface\\Icons\\INV_Shield_06", S_SPECIALIZATION_ROLE_TANK_FLAG, false},
	},
	[CLASS_ID_PALADIN] = { -- PALADIN
		{382, PALADIN_SPEC_HOLY_TITLE, PALADIN_SPEC_HOLY_DESC, "Interface\\Icons\\Spell_Holy_HolyBolt", S_SPECIALIZATION_ROLE_HEAL_FLAG, false},
		{383, PALADIN_SPEC_PROTECTION_TITLE, PALADIN_SPEC_PROTECTION_DESC, "Interface\\Icons\\Spell_Holy_DevotionAura", S_SPECIALIZATION_ROLE_TANK_FLAG, false},
		{381, PALADIN_SPEC_RETRIBUTION_TITLE, PALADIN_SPEC_RETRIBUTION_DESC, "Interface\\Icons\\Spell_Holy_AuraOfLight", S_SPECIALIZATION_ROLE_DAMAGER_FLAG, true},
	},
	[CLASS_ID_HUNTER] = { -- HUNTER
		{361, HUNTER_SPEC_BEASTMASTERY_TITLE, HUNTER_SPEC_BEASTMASTERY_DESC, "Interface\\Icons\\Ability_Hunter_BeastTaming", S_SPECIALIZATION_ROLE_DAMAGER_FLAG, true},
		{363, HUNTER_SPEC_MARKSMANSHIP_TITLE, HUNTER_SPEC_MARKSMANSHIP_DESC, "Interface\\Icons\\Ability_Marksmanship", S_SPECIALIZATION_ROLE_DAMAGER_FLAG, false},
		{362, HUNTER_SPEC_SURVIVAL_TITLE, HUNTER_SPEC_SURVIVAL_DESC, "Interface\\Icons\\Ability_Hunter_SwiftStrike", S_SPECIALIZATION_ROLE_DAMAGER_FLAG, false},
	},
	[CLASS_ID_ROGUE] = { -- ROGUE
		{182, ROGUE_SPEC_ASSASSINATION_TITLE, ROGUE_SPEC_ASSASSINATION_DESC, "Interface\\Icons\\Ability_Rogue_Eviscerate", S_SPECIALIZATION_ROLE_DAMAGER_FLAG, true},
		{181, ROGUE_SPEC_COMBAT_TITLE, ROGUE_SPEC_COMBAT_DESC, "Interface\\Icons\\Ability_BackStab", S_SPECIALIZATION_ROLE_DAMAGER_FLAG, false},
		{183, ROGUE_SPEC_SUBTLETY_TITLE, ROGUE_SPEC_SUBTLETY_DESC, "Interface\\Icons\\Ability_Stealth", S_SPECIALIZATION_ROLE_DAMAGER_FLAG, false},
	},
	[CLASS_ID_PRIEST] = { -- PRIEST
		{201, PRIEST_SPEC_DISCIPLINE_TITLE, PRIEST_SPEC_DISCIPLINE_DESC, "Interface\\Icons\\Spell_Holy_WordFortitude", S_SPECIALIZATION_ROLE_HEAL_FLAG, false},
		{202, PRIEST_SPEC_HOLY_TITLE, PRIEST_SPEC_HOLY_DESC, "Interface\\Icons\\Spell_Holy_HolyBolt", S_SPECIALIZATION_ROLE_HEAL_FLAG, false},
		{203, PRIEST_SPEC_SHADOW_TITLE, PRIEST_SPEC_SHADOW_DESC, "Interface\\Icons\\Spell_Shadow_ShadowWordPain", S_SPECIALIZATION_ROLE_DAMAGER_FLAG, true},
	},
	[CLASS_ID_DEATHKNIGHT] = { -- DEATHKNIGHT
		{398, DEATHKNIGHT_SPEC_BLOOD_TITLE,  DEATHKNIGHT_SPEC_BLOOD_DESC, "Interface\\Icons\\Spell_Deathknight_BloodPresence", bit.bor(S_SPECIALIZATION_ROLE_DAMAGER_FLAG, S_SPECIALIZATION_ROLE_TANK_FLAG), true},
		{399, DEATHKNIGHT_SPEC_FROST_TITLE,  DEATHKNIGHT_SPEC_FROST_DESC, "Interface\\Icons\\Spell_Deathknight_FrostPresence", bit.bor(S_SPECIALIZATION_ROLE_DAMAGER_FLAG, S_SPECIALIZATION_ROLE_TANK_FLAG), false},
		{400, DEATHKNIGHT_SPEC_UNHOLY_TITLE, DEATHKNIGHT_SPEC_UNHOLY_DESC, "Interface\\Icons\\Spell_Deathknight_UnholyPresence", bit.bor(S_SPECIALIZATION_ROLE_DAMAGER_FLAG, S_SPECIALIZATION_ROLE_TANK_FLAG), false},
	},
	[CLASS_ID_SHAMAN] = { -- SHAMAN
		{261, SHAMAN_SPEC_ELEMENTAL_TITLE,  SHAMAN_SPEC_ELEMENTAL_DESC, "Interface\\Icons\\Spell_Nature_Lightning", S_SPECIALIZATION_ROLE_DAMAGER_FLAG, true},
		{263, SHAMAN_SPEC_ENHANCEMENT_TITLE,  SHAMAN_SPEC_ENHANCEMENT_DESC, "Interface\\Icons\\Spell_Nature_LightningShield", S_SPECIALIZATION_ROLE_DAMAGER_FLAG, false},
		{262, SHAMAN_SPEC_RESTORATION_TITLE, SHAMAN_SPEC_RESTORATION_DESC, "Interface\\Icons\\Spell_Nature_MagicImmunity", S_SPECIALIZATION_ROLE_HEAL_FLAG, false},
	},
	[CLASS_ID_MAGE] = { -- MAGE
		{81, MAGE_SPEC_ARCANE_TITLE,  MAGE_SPEC_ARCANE_DESC, "Interface\\Icons\\Spell_Holy_MagicalSentry", S_SPECIALIZATION_ROLE_DAMAGER_FLAG, false},
		{41, MAGE_SPEC_FIRE_TITLE,  MAGE_SPEC_FIRE_DESC, "Interface\\Icons\\Spell_Fire_FireBolt02", S_SPECIALIZATION_ROLE_DAMAGER_FLAG, false},
		{61, MAGE_SPEC_FROST_TITLE, MAGE_SPEC_FROST_DESC, "Interface\\Icons\\Spell_Frost_FrostBolt02", S_SPECIALIZATION_ROLE_DAMAGER_FLAG, true},
	},
	[CLASS_ID_WARLOCK] = { -- WARLOCK
		{302, WARLOCK_AFFLICTION_TITLE,  WARLOCK_AFFLICTION_DESC, "Interface\\Icons\\Spell_Shadow_DeathCoil", S_SPECIALIZATION_ROLE_DAMAGER_FLAG, false},
		{303, WARLOCK_DEMONOLOGY_TITLE,  WARLOCK_DEMONOLOGY_DESC, "Interface\\Icons\\Spell_Shadow_Metamorphosis", S_SPECIALIZATION_ROLE_DAMAGER_FLAG, false},
		{301, WARLOCK_DESTRUCTION_TITLE, WARLOCK_DESTRUCTION_DESC, "Interface\\Icons\\Spell_Shadow_RainOfFire", S_SPECIALIZATION_ROLE_DAMAGER_FLAG, true},
	},
	[CLASS_ID_DEMONHUNTER] = { -- DEMONHUNTER
		{504, DEMONHUNTER_HAVOC_TITLE,  DEMONHUNTER_HAVOC_DESC, "Interface\\icons\\Ability_DemonHunter_SpecDPS_1", S_SPECIALIZATION_ROLE_DAMAGER_FLAG, true},
		{505, DEMONHUNTER_REVENGE_TITLE,  DEMONHUNTER_REVENGE_DESC, "Interface\\icons\\Ability_DemonHunter_SpecTank", S_SPECIALIZATION_ROLE_TANK_FLAG, false},
		{506, DEMONHUNTER_POSESSION_TITLE, DEMONHUNTER_POSESSION_DESC, "Interface\\icons\\Ability_DemonHunter_SpecDPS_2", S_SPECIALIZATION_ROLE_DAMAGER_FLAG, false},
	},
	[CLASS_ID_DRUID] = { -- DRUID
		{283, DRUID_BALANCE_TITLE,  DRUID_BALANCE_DESC, "Interface\\Icons\\Spell_Nature_StarFall", S_SPECIALIZATION_ROLE_DAMAGER_FLAG, false},
		{281, DRUID_FERAL_TITLE,  DRUID_FERAL_DESC, "Interface\\Icons\\Ability_Racial_BearForm", bit.bor(S_SPECIALIZATION_ROLE_DAMAGER_FLAG, S_SPECIALIZATION_ROLE_TANK_FLAG), true},
		{282, DRUID_RESTORATION_TITLE, DRUID_RESTORATION_DESC, "Interface\\Icons\\Spell_Nature_HealingTouch", S_SPECIALIZATION_ROLE_HEAL_FLAG, false},
	},
}

S_EXPANSION_DATA = {
	[LE_EXPANSION_CLASSIC] = "Classic",
	[LE_EXPANSION_BURNING_CRUSADE] = "The Burning Crusade",
	[LE_EXPANSION_WRATH_OF_THE_LICH_KING] = "Wrath of Lich King",
	[LE_EXPANSION_CATACLYSM] = "Cataclysm",
	[LE_EXPANSION_MISTS_OF_PANDARIA] = "Mists of Pandaria",
	[LE_EXPANSION_WARLORDS_OF_DRAENOR] = "Warlords of Draenor",
	[LE_EXPANSION_LEGION] = "Legion",
	[LE_EXPANSION_BATTLE_FOR_AZEROTH] = "Battle For Azeroth",
	[LE_EXPANSION_SHADOWLANDS] = "Shadowlands",
}

-- ##################################################################################

enum:E_CHARACTER_RACES {
	"RACE_HUMAN",
	"RACE_DWARF",
	"RACE_NIGHTELF",
	"RACE_GNOME",
	"RACE_DRAENEI",
	"RACE_WORGEN",
	"RACE_PANDAREN_ALLIANCE",
	"RACE_QUELDO",
	"RACE_VOIDELF",
	"RACE_VULPERA_ALLIANCE",
	"RACE_VULPERA_NEUTRAL",
	"RACE_PANDAREN_NEUTRAL",
	"RACE_LIGHTFORGED_DRAENEI",
	"RACE_DARKIRONDWARF",
	"RACE_ORC",
	"RACE_SCOURGE",
	"RACE_TAUREN",
	"RACE_TROLL",
	"RACE_GOBLIN",
	"RACE_BLOODELF",
	"RACE_NAGA",
	"RACE_PANDAREN_HORDE",
	"RACE_NIGHTBORNE",
	"RACE_VULPERA_HORDE",
	"RACE_ZANDALARITROLL",
	"RACE_EREDAR",
	"RACE_NIGHTELF_DH",
	"RACE_BLOODELF_DH",
	"RACE_GOBLIN_CREATURE",
	"RACE_FELORC",
	"RACE_NAGA_",
	"RACE_BROKEN",
	"RACE_SKELETON",
	"RACE_VRYKUL",
	"RACE_TUSKARR",
	"RACE_FORESTTROLL",
	"RACE_HUMAN_CREATURE",
	"RACE_ORC_CREATURE",
	"RACE_DWARF_CREATURE",
	"RACE_NIGHTELF_CREATURE",
	"RACE_SCOURGE_CREATURE",
	"RACE_TAUREN_CREATURE",
	"RACE_GNOME_CREATURE",
	"RACE_TROLL_CREATURE",
	"RACE_BLOODELF_CREATURE",
	"RACE_DRAENEI_CREATURE",
	"RACE_TAUNKA",
	"RACE_NORTHRENDSKELETON",
	"RACE_ICETROLL",
}

S_CHARACTER_RACES_INFO = {
	[E_CHARACTER_RACES.RACE_HUMAN] 				= {raceID = E_CHARACTER_RACES.RACE_HUMAN, 				clientFileString = "Human", 			raceName = "RACE_HUMAN", 				raceNameFemale = nil, 									overrideRaceName = nil, overrideRaceNameFemale = nil, factionID = PLAYER_FACTION_GROUP.Alliance},
	[E_CHARACTER_RACES.RACE_ORC] 				= {raceID = E_CHARACTER_RACES.RACE_ORC, 				clientFileString = "Orc", 				raceName = "RACE_ORC", 					raceNameFemale = nil, 									overrideRaceName = nil, overrideRaceNameFemale = nil, factionID = PLAYER_FACTION_GROUP.Horde},
	[E_CHARACTER_RACES.RACE_DWARF] 				= {raceID = E_CHARACTER_RACES.RACE_DWARF, 				clientFileString = "Dwarf", 			raceName = "RACE_DWARF", 				raceNameFemale = nil, 									overrideRaceName = nil, overrideRaceNameFemale = nil, factionID = PLAYER_FACTION_GROUP.Alliance},
	[E_CHARACTER_RACES.RACE_NIGHTELF] 			= {raceID = E_CHARACTER_RACES.RACE_NIGHTELF, 			clientFileString = "NightElf", 			raceName = "RACE_NIGHTELF", 			raceNameFemale = "RACE_NIGHTELF_FEMALE", 				overrideRaceName = nil, overrideRaceNameFemale = nil, factionID = PLAYER_FACTION_GROUP.Alliance},
	[E_CHARACTER_RACES.RACE_SCOURGE] 			= {raceID = E_CHARACTER_RACES.RACE_SCOURGE, 			clientFileString = "Scourge", 			raceName = "RACE_SCOURGE", 				raceNameFemale = "RACE_SCOURGE_FEMALE", 				overrideRaceName = nil, overrideRaceNameFemale = nil, factionID = PLAYER_FACTION_GROUP.Horde},
	[E_CHARACTER_RACES.RACE_TAUREN] 			= {raceID = E_CHARACTER_RACES.RACE_TAUREN, 				clientFileString = "Tauren", 			raceName = "RACE_TAUREN", 				raceNameFemale = nil, 									overrideRaceName = nil, overrideRaceNameFemale = nil, factionID = PLAYER_FACTION_GROUP.Horde},
	[E_CHARACTER_RACES.RACE_GNOME] 				= {raceID = E_CHARACTER_RACES.RACE_GNOME, 				clientFileString = "Gnome", 			raceName = "RACE_GNOME", 				raceNameFemale = nil, 									overrideRaceName = nil, overrideRaceNameFemale = nil, factionID = PLAYER_FACTION_GROUP.Alliance},
	[E_CHARACTER_RACES.RACE_TROLL] 				= {raceID = E_CHARACTER_RACES.RACE_TROLL, 				clientFileString = "Troll", 			raceName = "RACE_TROLL", 				raceNameFemale = nil, 									overrideRaceName = nil, overrideRaceNameFemale = nil, factionID = PLAYER_FACTION_GROUP.Horde},
	[E_CHARACTER_RACES.RACE_GOBLIN] 			= {raceID = E_CHARACTER_RACES.RACE_GOBLIN, 				clientFileString = "Goblin", 			raceName = "RACE_GOBLIN", 				raceNameFemale = nil, 									overrideRaceName = nil, overrideRaceNameFemale = nil, factionID = PLAYER_FACTION_GROUP.Horde},
	[E_CHARACTER_RACES.RACE_BLOODELF] 			= {raceID = E_CHARACTER_RACES.RACE_BLOODELF, 			clientFileString = "BloodElf", 			raceName = "RACE_BLOODELF", 			raceNameFemale = "RACE_BLOODELF_FEMALE", 				overrideRaceName = nil, overrideRaceNameFemale = nil, factionID = PLAYER_FACTION_GROUP.Horde},
	[E_CHARACTER_RACES.RACE_DRAENEI] 			= {raceID = E_CHARACTER_RACES.RACE_DRAENEI, 			clientFileString = "Draenei", 			raceName = "RACE_DRAENEI", 				raceNameFemale = nil, 									overrideRaceName = nil, overrideRaceNameFemale = nil, factionID = PLAYER_FACTION_GROUP.Alliance},
	[E_CHARACTER_RACES.RACE_WORGEN] 			= {raceID = E_CHARACTER_RACES.RACE_WORGEN, 				clientFileString = "Worgen", 			raceName = "RACE_WORGEN", 				raceNameFemale = "RACE_WORGEN_FEMALE", 					overrideRaceName = nil, overrideRaceNameFemale = nil, factionID = PLAYER_FACTION_GROUP.Alliance},
	[E_CHARACTER_RACES.RACE_NAGA] 				= {raceID = E_CHARACTER_RACES.RACE_NAGA, 				clientFileString = "Naga", 				raceName = "RACE_NAGA", 				raceNameFemale = "RACE_NAGA_FEMALE", 					overrideRaceName = nil, overrideRaceNameFemale = nil, factionID = PLAYER_FACTION_GROUP.Horde},
	[E_CHARACTER_RACES.RACE_PANDAREN_ALLIANCE] 	= {raceID = E_CHARACTER_RACES.RACE_PANDAREN_ALLIANCE, 	clientFileString = "Pandaren", 			raceName = "RACE_PANDAREN_ALLIANCE", 	raceNameFemale = "RACE_PANDAREN_ALLIANCE_FEMALE", 		overrideRaceName = nil, overrideRaceNameFemale = nil, factionID = PLAYER_FACTION_GROUP.Alliance},
	[E_CHARACTER_RACES.RACE_QUELDO] 			= {raceID = E_CHARACTER_RACES.RACE_QUELDO, 				clientFileString = "Queldo", 			raceName = "RACE_QUELDO", 				raceNameFemale = "RACE_QUELDO_FEMALE", 					overrideRaceName = nil, overrideRaceNameFemale = nil, factionID = PLAYER_FACTION_GROUP.Alliance},
	[E_CHARACTER_RACES.RACE_PANDAREN_HORDE] 	= {raceID = E_CHARACTER_RACES.RACE_PANDAREN_HORDE, 		clientFileString = "Pandaren", 			raceName = "RACE_PANDAREN_HORDE", 		raceNameFemale = "RACE_PANDAREN_HORDE_HORDE_FEMALE", 	overrideRaceName = nil, overrideRaceNameFemale = nil, factionID = PLAYER_FACTION_GROUP.Horde},
	[E_CHARACTER_RACES.RACE_NIGHTELF_DH] 		= {raceID = E_CHARACTER_RACES.RACE_NIGHTELF_DH, 		clientFileString = "NightElf", 			raceName = "RACE_NIGHTELF_DH", 			raceNameFemale = "RACE_NIGHTELF_DH_FEMALE", 			overrideRaceName = nil, overrideRaceNameFemale = nil, factionID = PLAYER_FACTION_GROUP.Alliance},
	[E_CHARACTER_RACES.RACE_BLOODELF_DH] 		= {raceID = E_CHARACTER_RACES.RACE_BLOODELF_DH, 		clientFileString = "BloodElf", 			raceName = "RACE_BLOODELF_DH", 			raceNameFemale = "RACE_BLOODELF_DH_FEMALE", 			overrideRaceName = nil, overrideRaceNameFemale = nil, factionID = PLAYER_FACTION_GROUP.Horde},
	[E_CHARACTER_RACES.RACE_VULPERA_ALLIANCE] 	= {raceID = E_CHARACTER_RACES.RACE_VULPERA_ALLIANCE, 	clientFileString = "Vulpera", 			raceName = "RACE_VULPERA_ALLIANCE",		raceNameFemale = "RACE_VULPERA_ALLIANCE_FEMALE", 		overrideRaceName = nil, overrideRaceNameFemale = nil, factionID = PLAYER_FACTION_GROUP.Alliance},
	[E_CHARACTER_RACES.RACE_VULPERA_HORDE] 		= {raceID = E_CHARACTER_RACES.RACE_VULPERA_HORDE, 		clientFileString = "Vulpera", 			raceName = "RACE_VULPERA_HORDE", 		raceNameFemale = "RACE_VULPERA_HORDE_FEMALE", 			overrideRaceName = nil, overrideRaceNameFemale = nil, factionID = PLAYER_FACTION_GROUP.Horde},
	[E_CHARACTER_RACES.RACE_VULPERA_NEUTRAL] 	= {raceID = E_CHARACTER_RACES.RACE_VULPERA_NEUTRAL, 	clientFileString = "Vulpera", 			raceName = "RACE_VULPERA_NEUTRAL",		raceNameFemale = "RACE_VULPERA_NEUTRAL_FEMALE", 		overrideRaceName = nil, overrideRaceNameFemale = nil, factionID = PLAYER_FACTION_GROUP.Neutral},
	[E_CHARACTER_RACES.RACE_PANDAREN_NEUTRAL] 	= {raceID = E_CHARACTER_RACES.RACE_PANDAREN_NEUTRAL, 	clientFileString = "Pandaren", 			raceName = "RACE_PANDAREN_NEUTRAL", 	raceNameFemale = nil, 									overrideRaceName = nil, overrideRaceNameFemale = nil, factionID = PLAYER_FACTION_GROUP.Neutral},
	[E_CHARACTER_RACES.RACE_FELORC] 			= {raceID = E_CHARACTER_RACES.RACE_FELORC, 				clientFileString = "FelOrc", 			raceName = "RACE_FELORC", 				raceNameFemale = nil, 									overrideRaceName = nil, overrideRaceNameFemale = nil, factionID = PLAYER_FACTION_GROUP.Neutral},
	[E_CHARACTER_RACES.RACE_NAGA_] 				= {raceID = E_CHARACTER_RACES.RACE_NAGA_, 				clientFileString = "Naga_", 			raceName = "RACE_NAGA_", 				raceNameFemale = "RACE_NAGA_FEMALE_", 					overrideRaceName = nil, overrideRaceNameFemale = nil, factionID = PLAYER_FACTION_GROUP.Neutral},
	[E_CHARACTER_RACES.RACE_BROKEN] 			= {raceID = E_CHARACTER_RACES.RACE_BROKEN, 				clientFileString = "Broken", 			raceName = "RACE_BROKEN", 				raceNameFemale = "RACE_BROKEN_FEMALE", 					overrideRaceName = nil, overrideRaceNameFemale = nil, factionID = PLAYER_FACTION_GROUP.Neutral},
	[E_CHARACTER_RACES.RACE_SKELETON] 			= {raceID = E_CHARACTER_RACES.RACE_SKELETON, 			clientFileString = "Skeleton", 			raceName = "RACE_SKELETON", 			raceNameFemale = nil, 									overrideRaceName = nil, overrideRaceNameFemale = nil, factionID = PLAYER_FACTION_GROUP.Neutral},
	[E_CHARACTER_RACES.RACE_VRYKUL] 			= {raceID = E_CHARACTER_RACES.RACE_VRYKUL, 				clientFileString = "Vrykul", 			raceName = "RACE_VRYKUL", 				raceNameFemale = nil, 									overrideRaceName = nil, overrideRaceNameFemale = nil, factionID = PLAYER_FACTION_GROUP.Neutral},
	[E_CHARACTER_RACES.RACE_TUSKARR] 			= {raceID = E_CHARACTER_RACES.RACE_TUSKARR, 			clientFileString = "Tuskarr", 			raceName = "RACE_TUSKARR", 				raceNameFemale = nil, 									overrideRaceName = nil, overrideRaceNameFemale = nil, factionID = PLAYER_FACTION_GROUP.Neutral},
	[E_CHARACTER_RACES.RACE_FORESTTROLL] 		= {raceID = E_CHARACTER_RACES.RACE_FORESTTROLL, 		clientFileString = "ForestTroll", 		raceName = "RACE_FORESTTROLL", 			raceNameFemale = nil, 									overrideRaceName = nil, overrideRaceNameFemale = nil, factionID = PLAYER_FACTION_GROUP.Neutral},
	[E_CHARACTER_RACES.RACE_HUMAN_CREATURE] 	= {raceID = E_CHARACTER_RACES.RACE_HUMAN_CREATURE, 		clientFileString = "Human", 			raceName = "RACE_HUMAN_CREATURE", 		raceNameFemale = nil, 									overrideRaceName = nil, overrideRaceNameFemale = nil, factionID = PLAYER_FACTION_GROUP.Alliance},
	[E_CHARACTER_RACES.RACE_ORC_CREATURE] 		= {raceID = E_CHARACTER_RACES.RACE_ORC_CREATURE, 		clientFileString = "Orc", 				raceName = "RACE_ORC_CREATURE", 		raceNameFemale = nil, 									overrideRaceName = nil, overrideRaceNameFemale = nil, factionID = PLAYER_FACTION_GROUP.Horde},
	[E_CHARACTER_RACES.RACE_DWARF_CREATURE] 	= {raceID = E_CHARACTER_RACES.RACE_DWARF_CREATURE, 		clientFileString = "Dwarf", 			raceName = "RACE_DWARF_CREATURE", 		raceNameFemale = nil, 									overrideRaceName = nil, overrideRaceNameFemale = nil, factionID = PLAYER_FACTION_GROUP.Alliance},
	[E_CHARACTER_RACES.RACE_NIGHTELF_CREATURE] 	= {raceID = E_CHARACTER_RACES.RACE_NIGHTELF_CREATURE, 	clientFileString = "NightElf", 			raceName = "RACE_NIGHTELF_CREATURE", 	raceNameFemale = "RACE_NIGHTELF_CREATURE_FEMALE", 		overrideRaceName = nil, overrideRaceNameFemale = nil, factionID = PLAYER_FACTION_GROUP.Alliance},
	[E_CHARACTER_RACES.RACE_SCOURGE_CREATURE] 	= {raceID = E_CHARACTER_RACES.RACE_SCOURGE_CREATURE, 	clientFileString = "Scourge", 			raceName = "RACE_SCOURGE_CREATURE", 	raceNameFemale = "RACE_SCOURGE_CREATURE_FEMALE", 		overrideRaceName = nil, overrideRaceNameFemale = nil, factionID = PLAYER_FACTION_GROUP.Horde},
	[E_CHARACTER_RACES.RACE_TAUREN_CREATURE] 	= {raceID = E_CHARACTER_RACES.RACE_TAUREN_CREATURE, 	clientFileString = "Tauren", 			raceName = "RACE_TAUREN_CREATURE", 		raceNameFemale = nil, 									overrideRaceName = nil, overrideRaceNameFemale = nil, factionID = PLAYER_FACTION_GROUP.Horde},
	[E_CHARACTER_RACES.RACE_GNOME_CREATURE] 	= {raceID = E_CHARACTER_RACES.RACE_GNOME_CREATURE, 		clientFileString = "Gnome", 			raceName = "RACE_GNOME_CREATURE", 		raceNameFemale = nil, 									overrideRaceName = nil, overrideRaceNameFemale = nil, factionID = PLAYER_FACTION_GROUP.Alliance},
	[E_CHARACTER_RACES.RACE_TROLL_CREATURE] 	= {raceID = E_CHARACTER_RACES.RACE_TROLL_CREATURE, 		clientFileString = "Troll", 			raceName = "RACE_TROLL_CREATURE", 		raceNameFemale = nil, 									overrideRaceName = nil, overrideRaceNameFemale = nil, factionID = PLAYER_FACTION_GROUP.Horde},
	[E_CHARACTER_RACES.RACE_BLOODELF_CREATURE] 	= {raceID = E_CHARACTER_RACES.RACE_BLOODELF_CREATURE, 	clientFileString = "BloodElf", 			raceName = "RACE_BLOODELF_CREATURE", 	raceNameFemale = "RACE_BLOODELF_CREATURE_FEMALE", 		overrideRaceName = nil, overrideRaceNameFemale = nil, factionID = PLAYER_FACTION_GROUP.Horde},
	[E_CHARACTER_RACES.RACE_DRAENEI_CREATURE] 	= {raceID = E_CHARACTER_RACES.RACE_DRAENEI_CREATURE, 	clientFileString = "Draenei", 			raceName = "RACE_DRAENEI_CREATURE", 	raceNameFemale = nil, 									overrideRaceName = nil, overrideRaceNameFemale = nil, factionID = PLAYER_FACTION_GROUP.Alliance},
	[E_CHARACTER_RACES.RACE_TAUNKA] 			= {raceID = E_CHARACTER_RACES.RACE_TAUNKA, 				clientFileString = "Taunka", 			raceName = "RACE_TAUNKA", 				raceNameFemale = "RACE_TAUNKA_FEMALE", 					overrideRaceName = nil, overrideRaceNameFemale = nil, factionID = PLAYER_FACTION_GROUP.Neutral},
	[E_CHARACTER_RACES.RACE_NORTHRENDSKELETON] 	= {raceID = E_CHARACTER_RACES.RACE_NORTHRENDSKELETON, 	clientFileString = "NorthrendSkeleton", raceName = "RACE_NORTHRENDSKELETON", 	raceNameFemale = nil, 									overrideRaceName = nil, overrideRaceNameFemale = nil, factionID = PLAYER_FACTION_GROUP.Neutral},
	[E_CHARACTER_RACES.RACE_ICETROLL] 			= {raceID = E_CHARACTER_RACES.RACE_ICETROLL, 			clientFileString = "IceTroll", 			raceName = "RACE_ICETROLL", 			raceNameFemale = nil, 									overrideRaceName = nil, overrideRaceNameFemale = nil, factionID = PLAYER_FACTION_GROUP.Neutral},
	[E_CHARACTER_RACES.RACE_NIGHTBORNE] 		= {raceID = E_CHARACTER_RACES.RACE_NIGHTBORNE, 			clientFileString = "Nightborne", 		raceName = "RACE_NIGHTBORNE", 			raceNameFemale = "RACE_NIGHTBORNE_FEMALE", 				overrideRaceName = nil, overrideRaceNameFemale = nil, factionID = PLAYER_FACTION_GROUP.Horde},
	[E_CHARACTER_RACES.RACE_VOIDELF] 			= {raceID = E_CHARACTER_RACES.RACE_VOIDELF, 			clientFileString = "VoidElf", 			raceName = "RACE_VOIDELF", 				raceNameFemale = "RACE_VOIDELF_FEMALE", 				overrideRaceName = nil, overrideRaceNameFemale = nil, factionID = PLAYER_FACTION_GROUP.Alliance},
	[E_CHARACTER_RACES.RACE_DARKIRONDWARF] 		= {raceID = E_CHARACTER_RACES.RACE_DARKIRONDWARF, 		clientFileString = "DarkIronDwarf", 	raceName = "RACE_DARKIRONDWARF", 		raceNameFemale = "RACE_DARKIRONDWARF_FEMALE", 			overrideRaceName = nil, overrideRaceNameFemale = nil, factionID = PLAYER_FACTION_GROUP.Alliance},
	[E_CHARACTER_RACES.RACE_EREDAR] 			= {raceID = E_CHARACTER_RACES.RACE_EREDAR, 				clientFileString = "Eredar", 			raceName = "RACE_EREDAR", 				raceNameFemale = "RACE_EREDAR_FEMALE", 					overrideRaceName = nil, overrideRaceNameFemale = nil, factionID = PLAYER_FACTION_GROUP.Horde},
}

S_CHARACTER_RACES_INFO_LOCALIZATION_ASSOC = {}
for _, data in pairs(S_CHARACTER_RACES_INFO) do
	if data.raceName and not string.find(data.raceName, "_CREATURE") then
		S_CHARACTER_RACES_INFO_LOCALIZATION_ASSOC[_G[data.raceName]] = data
	end
	if data.raceNameFemale then
		S_CHARACTER_RACES_INFO_LOCALIZATION_ASSOC[_G[data.raceNameFemale]] = data
	end
end

--CHARACTER_CREATE_RACES_ORDER = {
--	-- Alliance
--	E_CHARACTER_RACES.RACE_HUMAN,
--	E_CHARACTER_RACES.RACE_DWARF,
--	E_CHARACTER_RACES.RACE_NIGHTELF,
--	E_CHARACTER_RACES.RACE_GNOME,
--	E_CHARACTER_RACES.RACE_DRAENEI,
--	E_CHARACTER_RACES.RACE_WORGEN,
--	E_CHARACTER_RACES.RACE_QUELDO,
--
--	-- Horde
--	E_CHARACTER_RACES.RACE_ORC,
--	E_CHARACTER_RACES.RACE_SCOURGE,
--	E_CHARACTER_RACES.RACE_TAUREN,
--	E_CHARACTER_RACES.RACE_GOBLIN,
--	E_CHARACTER_RACES.RACE_TROLL,
--	E_CHARACTER_RACES.RACE_NAGA,
--	E_CHARACTER_RACES.RACE_BLOODELF,
--
--	-- Neutral
--	E_CHARACTER_RACES.RACE_PANDAREN_ALLIANCE,
--	E_CHARACTER_RACES.RACE_VULPERA_NEUTRAL,
--
--	-- Hidden
--	E_CHARACTER_RACES.RACE_VULPERA_ALLIANCE,
--	E_CHARACTER_RACES.RACE_VULPERA_HORDE,
--	E_CHARACTER_RACES.RACE_BLOODELF_DH,
--	E_CHARACTER_RACES.RACE_NIGHTELF_DH,
--	E_CHARACTER_RACES.RACE_PANDAREN_HORDE,
--}

CHARACTER_CREATE_RACES_ORDER = {
	-- Alliance
	E_CHARACTER_RACES.RACE_HUMAN,
	E_CHARACTER_RACES.RACE_DWARF,
	E_CHARACTER_RACES.RACE_NIGHTELF,
	E_CHARACTER_RACES.RACE_GNOME,
	E_CHARACTER_RACES.RACE_DRAENEI,
	E_CHARACTER_RACES.RACE_WORGEN,
	E_CHARACTER_RACES.RACE_QUELDO,

	-- Horde
	E_CHARACTER_RACES.RACE_ORC,
	E_CHARACTER_RACES.RACE_SCOURGE,
	E_CHARACTER_RACES.RACE_TAUREN,
	E_CHARACTER_RACES.RACE_GOBLIN,
	E_CHARACTER_RACES.RACE_TROLL,
	E_CHARACTER_RACES.RACE_NAGA,
	E_CHARACTER_RACES.RACE_BLOODELF,

	-- Neutral
	E_CHARACTER_RACES.RACE_PANDAREN_ALLIANCE,
	E_CHARACTER_RACES.RACE_VULPERA_NEUTRAL,

	-- Hidden
	E_CHARACTER_RACES.RACE_VULPERA_ALLIANCE,
	E_CHARACTER_RACES.RACE_VULPERA_HORDE,
	E_CHARACTER_RACES.RACE_BLOODELF_DH,
	E_CHARACTER_RACES.RACE_NIGHTELF_DH,
	E_CHARACTER_RACES.RACE_PANDAREN_HORDE,

	E_CHARACTER_RACES.RACE_VOIDELF,
	E_CHARACTER_RACES.RACE_NIGHTBORNE,


	E_CHARACTER_RACES.RACE_DARKIRONDWARF,
	E_CHARACTER_RACES.RACE_EREDAR,
}

CHARACTER_CREATE_CAMERA_SETTINGS = {
	["Alliance"] = {-0.751000, 0.727001, 0.186000},
	["Horde"] = {-0.899000, 0.612001, 0.414000},
	["DeathKnight"] = {0.186000, 0.028000, 0.186000},
	["Vulpera"] = {1.235000, -0.726000, -0.316000},
	["Pandaren"] = {-0.453000, 0.502001, 0.323000}
}

CHARACTER_SELECT_CAMERA_SETTINGS = {
	["Alliance"] = {-0.751000, 0.727001, 0.186000},
	["Horde"] = {-0.899000, 0.612001, 0.414000},
	["DeathKnight"] = {-0.635000, 0.642000, 0.186000},
	["Vulpera"] = {1.235000, -0.726000, -0.316000},
	["Pandaren"] = {-0.453000, 0.502001, 0.323000}
}

CHARACTER_CREATE_MODEL_LIGHT = {
	["Alliance"] = {2.199000, -4.000000, -3.444000, 0.405020, 1.000000, 1.000000, 1.000000, 1.000000, 1.000000, 1.000000, 1.000000},
	["Horde"] = {10.000000, -9.240000, -10.000000, 0.749100, 1.000000, 0.579930, 0.568460, 0.505380, 1.000000, 0.278850, 0.273120},
	["DeathKnight"] = {2.287001, -4.996000, -2.301000, 0.333330, 0.565590, 0.855200, 1.000000, 1.000000, 0.419360, 0.769180, 1.000000},
	["Vulpera"] = {0.796001, 2.459001, -5.455000, 0.301790, 1.000000, 1.000000, 1.000000, 1.000000, 1.000000, 0.405020, 0.109680},
	["Pandaren"] = {10.000000, -4.251000, -8.380000, 0.192830, 1.000000, 1.000000, 1.000000, 1.000000, 0.763440, 0.846590, 0.918280}
}

enum:E_CHARACTER_GENDER {
	"NONE",
	"MALE",
	"FEMALE"
}

CHARACTER_CREATE_FACE_ZOOM_CAMERA_SETTINGS = {
	[E_CHARACTER_GENDER.MALE] = {
		[E_CHARACTER_RACES.RACE_HUMAN] 				= {-4.602000, 3.582001, -0.379000},
		[E_CHARACTER_RACES.RACE_DWARF] 				= {-4.601996, 3.581998, 0.003000},
		[E_CHARACTER_RACES.RACE_NIGHTELF] 			= {-4.601986, 3.581991, -0.726000},
		[E_CHARACTER_RACES.RACE_GNOME] 				= {-4.601996, 3.581998, 0.551000},
		[E_CHARACTER_RACES.RACE_DRAENEI] 			= {-4.601996, 3.581998, -0.863000},
		[E_CHARACTER_RACES.RACE_WORGEN] 			= {-4.601996, 3.581998, -0.589000},
		[E_CHARACTER_RACES.RACE_QUELDO] 			= {-4.830000, 3.622001, -0.498000},
		[E_CHARACTER_RACES.RACE_VOIDELF] 			= {-4.830000, 3.622001, -0.498000},
		[E_CHARACTER_RACES.RACE_VULPERA_ALLIANCE] 	= {-4.601986, 3.591001, -0.786000},
		[E_CHARACTER_RACES.RACE_DARKIRONDWARF] 		= {-4.601996, 3.581998, 0.003000},

		[E_CHARACTER_RACES.RACE_ORC] 				= {-4.671000, 3.420001, -0.364000},
		[E_CHARACTER_RACES.RACE_SCOURGE] 			= {-4.964000, 3.514001, -0.133000},
		[E_CHARACTER_RACES.RACE_TAUREN] 			= {-4.647997, 3.414001, -0.291000},
		[E_CHARACTER_RACES.RACE_GOBLIN] 			= {-5.058000, 3.724001, 0.348000},
		[E_CHARACTER_RACES.RACE_TROLL] 				= {-4.830000, 3.653001, -0.598000},
		[E_CHARACTER_RACES.RACE_NAGA] 				= {-4.784000, 3.551001, -0.492000},
		[E_CHARACTER_RACES.RACE_BLOODELF] 			= {-4.967000, 3.581001, -0.357000},
		[E_CHARACTER_RACES.RACE_VULPERA_HORDE] 		= {-4.601986, 3.591001, -0.786000},
		[E_CHARACTER_RACES.RACE_EREDAR] 			= {-4.830000, 3.653001, -0.598000},

		[E_CHARACTER_RACES.RACE_PANDAREN_ALLIANCE] 	= {-3.516000, 2.764001, -0.130000},
		[E_CHARACTER_RACES.RACE_PANDAREN_HORDE] 	= {-3.516000, 2.764001, -0.130000},

		[E_CHARACTER_RACES.RACE_VULPERA_NEUTRAL] 	= {-4.601986, 3.591001, -0.786000},

		[E_CHARACTER_RACES.RACE_VOIDELF]			= {-4.858000, 3.646001, -0.673000},
		[E_CHARACTER_RACES.RACE_NIGHTBORNE]			= {-4.768000, 3.556001, -0.939000},
	},
	[E_CHARACTER_GENDER.FEMALE] = {
		[E_CHARACTER_RACES.RACE_HUMAN] 				= {-4.921000, 3.792001, -0.368000},
		[E_CHARACTER_RACES.RACE_DWARF] 				= {-5.195000, 4.016001, 0.003000},
		[E_CHARACTER_RACES.RACE_NIGHTELF] 			= {-4.693000, 3.661001, -0.677000},
		[E_CHARACTER_RACES.RACE_GNOME] 				= {-4.601982, 3.617001, 0.587000},
		[E_CHARACTER_RACES.RACE_DRAENEI] 			= {-4.601982, 3.665001, -0.681000},
		[E_CHARACTER_RACES.RACE_WORGEN] 			= {-4.601993, 3.552001, -0.641000},
		[E_CHARACTER_RACES.RACE_QUELDO] 			= {-4.601993, 3.631001, -0.270000},
		[E_CHARACTER_RACES.RACE_VOIDELF] 			= {-4.601993, 3.631001, -0.270000},
		[E_CHARACTER_RACES.RACE_VULPERA_ALLIANCE] 	= {-4.601991, 3.629001, -0.772000},
		[E_CHARACTER_RACES.RACE_DARKIRONDWARF] 		= {-5.195000, 4.016001, 0.003000},

		[E_CHARACTER_RACES.RACE_ORC] 				= {-4.647997, 3.504001, -0.257000},
		[E_CHARACTER_RACES.RACE_SCOURGE] 			= {-4.647987, 3.475001, -0.032000},
		[E_CHARACTER_RACES.RACE_TAUREN] 			= {-4.647997, 3.477001, -0.338000},
		[E_CHARACTER_RACES.RACE_GOBLIN] 			= {-4.647994, 3.508001, 0.433001},
		[E_CHARACTER_RACES.RACE_TROLL] 				= {-4.647994, 3.423001, -0.545000},
		[E_CHARACTER_RACES.RACE_NAGA] 				= {-4.647987, 3.484001, -0.453000},
		[E_CHARACTER_RACES.RACE_BLOODELF] 			= {-4.647984, 3.522001, -0.152000},
		[E_CHARACTER_RACES.RACE_VULPERA_HORDE] 		= {-4.601991, 3.629001, -0.772000},
		[E_CHARACTER_RACES.RACE_EREDAR] 			= {-4.647994, 3.423001, -0.545000},

		[E_CHARACTER_RACES.RACE_PANDAREN_ALLIANCE] 	= {-3.461997, 2.771001, -0.023000},
		[E_CHARACTER_RACES.RACE_PANDAREN_HORDE] 	= {-3.461997, 2.771001, -0.023000},

		[E_CHARACTER_RACES.RACE_VULPERA_NEUTRAL] 	= {-4.601991, 3.629001, -0.772000},

		[E_CHARACTER_RACES.RACE_VOIDELF]			= {-4.678000, 3.647001, -0.516000},
		[E_CHARACTER_RACES.RACE_NIGHTBORNE]			= {-3.864000, 2.787001, -0.697000},
	},
	["DEATHKNIGHT"] = {
		[E_CHARACTER_GENDER.MALE] = {
			[E_CHARACTER_RACES.RACE_HUMAN] 				= {-2.915000, 2.313001, -0.151000},
			[E_CHARACTER_RACES.RACE_DWARF] 				= {-2.914997, 2.323001, 0.095000},
			[E_CHARACTER_RACES.RACE_NIGHTELF] 			= {-2.914994, 2.324001, -0.407000},
			[E_CHARACTER_RACES.RACE_GNOME] 				= {-2.914994, 2.308001, 0.323000},
			[E_CHARACTER_RACES.RACE_DRAENEI] 			= {-2.914994, 2.303001, -0.453000},
			[E_CHARACTER_RACES.RACE_WORGEN] 			= {-2.914994, 2.298001, -0.261000},
			[E_CHARACTER_RACES.RACE_QUELDO] 			= {-2.914994, 2.233001, -0.196000},
			[E_CHARACTER_RACES.RACE_VOIDELF] 			= {-2.914994, 2.233001, -0.196000},
			[E_CHARACTER_RACES.RACE_VULPERA_ALLIANCE] 	= {-3.234000, 2.535001, 0.191000},
			[E_CHARACTER_RACES.RACE_DARKIRONDWARF] 		= {-2.914997, 2.323001, 0.095000},

			[E_CHARACTER_RACES.RACE_ORC] 				= {-2.831000, 2.215001, -0.192000},
			[E_CHARACTER_RACES.RACE_SCOURGE] 			= {-3.325000, 2.510001, -0.112000},
			[E_CHARACTER_RACES.RACE_TAUREN] 			= {-2.550000, 2.021001, -0.104000},
			[E_CHARACTER_RACES.RACE_GOBLIN] 			= {-3.234000, 2.528001, 0.161000},
			[E_CHARACTER_RACES.RACE_TROLL] 				= {-2.732997, 2.210001, -0.269000},
			[E_CHARACTER_RACES.RACE_NAGA] 				= {-2.367998, 1.908001, -0.175000},
			[E_CHARACTER_RACES.RACE_BLOODELF] 			= {-2.914997, 2.233001, -0.153000},
			[E_CHARACTER_RACES.RACE_VULPERA_HORDE] 		= {-3.051997, 2.401000, 0.231000},
			[E_CHARACTER_RACES.RACE_EREDAR] 			= {-2.732997, 2.210001, -0.269000},

			[E_CHARACTER_RACES.RACE_PANDAREN_ALLIANCE] 	= {-2.596000, 2.071001, -0.285000},
			[E_CHARACTER_RACES.RACE_PANDAREN_HORDE] 	= {-2.596000, 2.071001, -0.285000},

			[E_CHARACTER_RACES.RACE_VULPERA_NEUTRAL] 	= {-3.051997, 2.401000, 0.231000},

			[E_CHARACTER_RACES.RACE_VOIDELF]			= {-2.914000, 2.232001, -0.318000},
			[E_CHARACTER_RACES.RACE_NIGHTBORNE]			= {-2.755000, 2.207000, -0.495000},
		},
		[E_CHARACTER_GENDER.FEMALE] = {
			[E_CHARACTER_RACES.RACE_HUMAN] 				= {-3.052000, 2.405001, -0.133000},
			[E_CHARACTER_RACES.RACE_DWARF] 				= {-2.915000, 2.307001, 0.095000},
			[E_CHARACTER_RACES.RACE_NIGHTELF] 			= {-2.869000, 2.289001, -0.300000},
			[E_CHARACTER_RACES.RACE_GNOME] 				= {-3.279997, 2.573001, 0.345001},
			[E_CHARACTER_RACES.RACE_DRAENEI] 			= {-2.778000, 2.238001, -0.316000},
			[E_CHARACTER_RACES.RACE_WORGEN] 			= {-2.733000, 2.146001, -0.361000},
			[E_CHARACTER_RACES.RACE_QUELDO] 			= {-3.097000, 2.456001, -0.145000},
			[E_CHARACTER_RACES.RACE_VOIDELF] 			= {-3.097000, 2.456001, -0.145000},
			[E_CHARACTER_RACES.RACE_VULPERA_ALLIANCE] 	= {-3.143000, 2.468001, 0.218000},
			[E_CHARACTER_RACES.RACE_DARKIRONDWARF] 		= {-2.915000, 2.307001, 0.095000},

			[E_CHARACTER_RACES.RACE_ORC] 				= {-3.006000, 2.378000, -0.199000},
			[E_CHARACTER_RACES.RACE_SCOURGE] 			= {-3.325000, 2.598001, -0.131000},
			[E_CHARACTER_RACES.RACE_TAUREN] 			= {-2.837000, 2.238001, -0.239000},
			[E_CHARACTER_RACES.RACE_GOBLIN] 			= {-3.188000, 2.514001, 0.170000},
			[E_CHARACTER_RACES.RACE_TROLL] 				= {-2.960000, 2.295001, -0.390000},
			[E_CHARACTER_RACES.RACE_NAGA] 				= {-2.505000, 2.012001, -0.182000},
			[E_CHARACTER_RACES.RACE_BLOODELF] 			= {-3.143000, 2.490000, -0.150000},
			[E_CHARACTER_RACES.RACE_VULPERA_HORDE] 		= {-3.143000, 2.468001, 0.218000},
			[E_CHARACTER_RACES.RACE_EREDAR] 			= {-2.960000, 2.295001, -0.390000},

			[E_CHARACTER_RACES.RACE_PANDAREN_ALLIANCE] 	= {-2.824000, 2.240000, -0.222000},
			[E_CHARACTER_RACES.RACE_PANDAREN_HORDE] 	= {-2.824000, 2.240000, -0.222000},

			[E_CHARACTER_RACES.RACE_VULPERA_NEUTRAL] 	= {-3.143000, 2.468001, 0.218000},

			[E_CHARACTER_RACES.RACE_VOIDELF]			= {-2.687000, 2.154001, -0.199000},
			[E_CHARACTER_RACES.RACE_NIGHTBORNE]			= {-2.280000, 1.792001, -0.380000},
		}
	}
}

-- ##################################################################################

FLYOUT_STORAGE = {}
FLYOUT_STORAGE[308230] = {308228, 308221, 308222, 308223, 308224, 308225, 308226, 308227}
FLYOUT_STORAGE[316451] = {316452, 316453}

S_CATEGORY_SPELL_ID = {
	90036, 302100, 302101, 302102, 302103, 302104, 302105, 302106, 302107, 90028, 90029, 90030,
	90031, 90032, 90033, 90034, 90035, 90021, 90022, 90023, 90024, 90025, 90026, 90027, 90015, 90016, 90017, 90018,
	90019, 90020, 90001, 90002, 90003, 90004, 90005, 90006, 90007, 90008, 90009, 90010, 90011, 90012, 90013, 90014
}

S_VIP_STATUS_DATA = {
	[308221] = {
		spellID 	= 308221,
		category 	= 1,
		color 		= CreateColor(0.80, 0.49, 0.19),
	},
	[308222] = {
		spellID 	= 308222,
		category 	= 1,
		color 		= CreateColor(1, 1, 1),
	},
	[308223] = {
		spellID 	= 308223,
		category 	= 1,
		color 		= CreateColor(1, 0.84, 0),
	},
	[308224] = {
		spellID 	= 308224,
		category 	= 2,
		color 		= CreateColor(0.80, 0.49, 0.19),
	},
	[308225] = {
		spellID 	= 308225,
		category 	= 2,
		color 		= CreateColor(1, 1, 1),
	},
	[308226] = {
		spellID 	= 308226,
		category 	= 2,
		color 		= CreateColor(1, 0.84, 0),
	},
	[308227] = {
		spellID 	= 308227,
		category 	= 3,
		color 		= CreateColor(0.47, 1, 0.47),
	},
--[[
	[] = {
		spellID 	= ,
		category 	= 3,
		color 		= CreateColor(0.38, 0.56, 1),
	},
	[] = {
		spellID 	= ,
		category 	= 3,
		color 		= CreateColor(1, 0.3, 0.34),
	},
]]
}

enum:E_SEX {
	"NONE",
	"MALE",
	"FEMALE"
}

FACTION_OVERRIDE_BY_DEBUFFS = {
	[309327] = PLAYER_FACTION_GROUP.Alliance,
	[302906] = PLAYER_FACTION_GROUP.Alliance,
	[308184] = PLAYER_FACTION_GROUP.Alliance,
	[302904] = PLAYER_FACTION_GROUP.Alliance,
	[310063] = PLAYER_FACTION_GROUP.Alliance,
	[310065] = PLAYER_FACTION_GROUP.Alliance,

	[309328] = PLAYER_FACTION_GROUP.Horde,
	[302907] = PLAYER_FACTION_GROUP.Horde,
	[308185] = PLAYER_FACTION_GROUP.Horde,
	[302905] = PLAYER_FACTION_GROUP.Horde,
	[310064] = PLAYER_FACTION_GROUP.Horde,
	[310066] = PLAYER_FACTION_GROUP.Horde,

	[309329] = PLAYER_FACTION_GROUP.Renegade
}

TOAST_TYPE_ICONS = {
	[1] = "WoW_Token01",
	[2] = "Wow_Token02",
	[3] = "warrior_skullbanner",
	[4] = "warrior_skullbanner",
	[5] = "warrior_skullbanner",
	[6] = "warrior_skullbanner",
	[7] = "warrior_skullbanner",
	[8] = "warrior_skullbanner",
	[9] = "warrior_skullbanner",
	[10] = "warrior_skullbanner",
	[11] = "warrior_skullbanner",
	[12] = "warrior_skullbanner",
	[13] = "warrior_skullbanner",
	[14] = "Battlepas_64x64",
	[15] = "Battlepas_64x64",
	[16] = "Battlepas_64x64",
	[17] = "Battlepas_64x64",
	[18] = "Spell_Deathknight_ClassIcon",
	[21] = "Inv_misc_coin_01",
	[22] = "Inv_misc_coin_01",
	[23] = "Inv_misc_coin_01",
	[24] = "inv_belt_mail_vrykuldragonrider_b_01",
	[25] = "inv_belt_mail_vrykuldragonrider_b_01",
	[26] = "ability_rogue_disguise",
}

C_SERVICE_FLAG_RENEGATE             = 0x00000001
C_SERVICE_FLAG_XP                   = 0x00000002
C_SERVICE_FLAG_STORE                = 0x00000004
C_SERVICE_FLAG_WAR_MOD              = 0x00000008
C_SERVICE_FLAG_STRENGTHEN_STATS     = 0x00000010
C_SERVICE_FLAG_IS_SWITCH_WAR_MODE   = 0x00000020