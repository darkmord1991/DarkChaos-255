--[[
	DC-Talents - where WotLK talents sit on the retail canvas, and which retail spec each tree is.

	Retail draws a class tree and a spec tree on a 1612 x 774 canvas. A WotLK class has three trees of
	4 columns and up to 11 tiers, and at level 255 all three fill up, so they are laid out side by side,
	each centred on a third of the canvas. Node positions use retail's units (1/10 px):
	button centre = posX / 10 - basePanOffsetX, -posY / 10 + basePanOffsetY (ClassTalentsFrame uses 49 / -30).

	Each WotLK tree maps to the retail spec with the same name (Combat -> Outlaw, Feral Combat -> Feral),
	which gives every tree retail's spec background, thumbnail and role.
]]

local _, ns = ...
setfenv(1, ns.env)

local G = ns.realG

local Layout = {}
ns.Layout = Layout

local CANVAS_WIDTH = 1612
local BASE_PAN_OFFSET_X = 49
local BASE_PAN_OFFSET_Y = -30
local COLUMN_SPACING = 64
local ROW_SPACING = 55
local FIRST_ROW_Y = 132
local PET_FIRST_ROW_Y = 170
local PET_ROW_SPACING = 80
local PET_COLUMN_SPACING = 80

Layout.CANVAS_WIDTH = CANVAS_WIDTH
Layout.COLUMN_SPACING = COLUMN_SPACING
Layout.ROW_SPACING = ROW_SPACING
Layout.FIRST_ROW_Y = FIRST_ROW_Y

-- TalentTab.dbc id -> retail specialization id.
Layout.RetailSpecByTalentTab = {
	[161] = 71, [164] = 72, [163] = 73,          -- Warrior: Arms, Fury, Protection
	[382] = 65, [383] = 66, [381] = 70,          -- Paladin: Holy, Protection, Retribution
	[361] = 253, [363] = 254, [362] = 255,       -- Hunter: Beast Mastery, Marksmanship, Survival
	[182] = 259, [181] = 260, [183] = 261,       -- Rogue: Assassination, Combat (Outlaw), Subtlety
	[201] = 256, [202] = 257, [203] = 258,       -- Priest: Discipline, Holy, Shadow
	[398] = 250, [399] = 251, [400] = 252,       -- Death Knight: Blood, Frost, Unholy
	[261] = 262, [263] = 263, [262] = 264,       -- Shaman: Elemental, Enhancement, Restoration
	[81] = 62, [41] = 63, [61] = 64,             -- Mage: Arcane, Fire, Frost
	[302] = 265, [303] = 266, [301] = 267,       -- Warlock: Affliction, Demonology, Destruction
	[283] = 102, [281] = 103, [282] = 105,       -- Druid: Balance, Feral Combat (Feral), Restoration
}

Layout.RoleByRetailSpec = {
	[71] = "DAMAGER", [72] = "DAMAGER", [73] = "TANK",
	[65] = "HEALER", [66] = "TANK", [70] = "DAMAGER",
	[253] = "DAMAGER", [254] = "DAMAGER", [255] = "DAMAGER",
	[259] = "DAMAGER", [260] = "DAMAGER", [261] = "DAMAGER",
	[256] = "HEALER", [257] = "HEALER", [258] = "DAMAGER",
	[250] = "TANK", [251] = "DAMAGER", [252] = "DAMAGER",
	[262] = "DAMAGER", [263] = "DAMAGER", [264] = "HEALER",
	[62] = "DAMAGER", [63] = "DAMAGER", [64] = "DAMAGER",
	[265] = "DAMAGER", [266] = "DAMAGER", [267] = "DAMAGER",
	[102] = "DAMAGER", [103] = "DAMAGER", [105] = "HEALER",
}

-- Retail primary stat per spec (LE_UNIT_STAT_*: 1 Strength, 2 Agility, 4 Intellect). The spec cards
-- only print their description when a primary stat is known.
Layout.PrimaryStatByRetailSpec = {
	[71] = 1, [72] = 1, [73] = 1,
	[65] = 4, [66] = 1, [70] = 1,
	[253] = 2, [254] = 2, [255] = 2,
	[259] = 2, [260] = 2, [261] = 2,
	[256] = 4, [257] = 4, [258] = 4,
	[250] = 1, [251] = 1, [252] = 1,
	[262] = 4, [263] = 2, [264] = 4,
	[62] = 4, [63] = 4, [64] = 4,
	[265] = 4, [266] = 4, [267] = 4,
	[102] = 4, [103] = 2, [105] = 4,
}

-- Retail spec id -> class file and tree position, for inspect and loadout strings.
Layout.ClassByRetailSpec = {}
for talentTabID, specID in pairs(Layout.RetailSpecByTalentTab) do
	local tabData = ns.TalentTabData and ns.TalentTabData[talentTabID]
	if tabData then
		for classID, classFile in pairs(ns.ClassFileByID) do
			if bit.band(tabData[1], bit.lshift(1, classID - 1)) ~= 0 then
				Layout.ClassByRetailSpec[specID] = classFile
			end
		end
	end
end

-- Centre (px from the canvas left edge) of each tree for 1, 2 or 3 trees.
local function TreeCenterX(numTabs, tab)
	if numTabs <= 1 then
		return CANVAS_WIDTH / 2
	end
	return CANVAS_WIDTH * (2 * tab - 1) / (2 * numTabs)
end
Layout.TreeCenterX = TreeCenterX

function Layout.NodePosition(tree, node)
	local x, y
	if tree.isPet then
		x = TreeCenterX(1, 1) + (node.column - 2.5) * PET_COLUMN_SPACING
		y = PET_FIRST_ROW_Y + (node.tier - 1) * PET_ROW_SPACING
	else
		x = TreeCenterX(#tree.tabs, node.tab) + (node.column - 2.5) * COLUMN_SPACING
		y = FIRST_ROW_Y + (node.tier - 1) * ROW_SPACING
	end
	return (x + BASE_PAN_OFFSET_X) * 10, (y + BASE_PAN_OFFSET_Y) * 10
end

-- Top-left (px, canvas space) of a tree's header block.
function Layout.TreeHeaderPosition(numTabs, tab)
	return TreeCenterX(numTabs, tab), 58
end

function Layout.RetailSpecForTab(tab, inspect)
	local treeID = inspect and nil or ns.Traits.GetPlayerTreeID()
	local tree = treeID and ns.Traits.GetTree(treeID)
	local tabInfo = tree and tree.tabs[tab]
	local talentTabID = tabInfo and tabInfo.talentTabID
	return talentTabID and Layout.RetailSpecByTalentTab[talentTabID] or nil
end

function Layout.RoleForTab(tab)
	local specID = Layout.RetailSpecForTab(tab)
	return specID and Layout.RoleByRetailSpec[specID] or "DAMAGER"
end

-- "Arms 51 / Fury 5 / Protection 15"
function Layout.DescribeGroup(group, inspect)
	local parts = {}
	for tab = 1, (G.GetNumTalentTabs(inspect or false, false) or 0) do
		local name, _, points = G.GetTalentTabInfo(tab, inspect or false, false, group)
		parts[#parts + 1] = ("%s %d"):format(name or "?", points or 0)
	end
	return table.concat(parts, " / ")
end
