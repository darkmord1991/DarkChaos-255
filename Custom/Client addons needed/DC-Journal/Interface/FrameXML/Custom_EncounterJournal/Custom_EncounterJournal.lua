local EJ_TIER_DATA =
{
	[1] = { backgroundTexture = "Interface\\EncounterJournal\\UI-EJ-Classic", r = 1.0, g = 0.8, b = 0.0 },
	[2] = { backgroundTexture = "Interface\\EncounterJournal\\UI-EJ-BurningCrusade", r = 0.6, g = 0.8, b = 0.0 },
	[3] = { backgroundTexture = "Interface\\EncounterJournal\\UI-EJ-WrathoftheLichKing", r = 0.2, g = 0.8, b = 1.0 },
	[4] = { backgroundTexture = "Interface\\EncounterJournal\\UI-EJ-Cataclysm", r = 1.0, g = 0.4, b = 0.0 },
	[5] = { backgroundTexture = "Interface\\EncounterJournal\\UI-EJ-MistsofPandaria", r = 0.0, g = 0.6, b = 0.2 },
	[6] = { backgroundTexture = "Interface\\ENCOUNTERJOURNAL\\UI-EJ-WarlordsofDraenor", r = 0.82, g = 0.55, b = 0.1 },
	[7] = { backgroundTexture = "Interface\\EncounterJournal\\UI-EJ-Legion", r = 1.0, g = 0.8, b = 0.0 },
}

JOURNALENCOUNTER_BY_ENCOUNTER = {}
JOURNALENCOUNTERITEM_BY_ENTRY = {}

ExpansionEnumToEJTierDataTableId = {
	[LE_EXPANSION_CLASSIC] = 1,
	[LE_EXPANSION_BURNING_CRUSADE] = 2,
	[LE_EXPANSION_WRATH_OF_THE_LICH_KING] = 3,
	[LE_EXPANSION_CATACLYSM] = 4,
	[LE_EXPANSION_MISTS_OF_PANDARIA] = 5,
	[LE_EXPANSION_WARLORDS_OF_DRAENOR] = 6,
	[LE_EXPANSION_LEGION] = 7,
}

local EJ_Tabs = {}
local EJ_section_openTable = {}
local EJ_SearchData = {}
local EJ_SearchBuffer = {}
local EJ_slotFilter = 0
local NO_INV_TYPE_FILTER = 0
local NO_CLASS_FILTER = 0

local EJ_NUM_SEARCH_PREVIEWS = 5
local EJ_SHOW_ALL_SEARCH_RESULTS_INDEX = EJ_NUM_SEARCH_PREVIEWS + 1

EJ_Tabs[1] = {frame="overviewScroll", button="overviewTab"}
EJ_Tabs[2] = {frame="lootScroll", button="lootTab"}
EJ_Tabs[3] = {frame="detailsScroll", button="bossTab"}
EJ_Tabs[4] = {frame="model", button="modelTab"}

local overviewPriorities = {
	[1] = "DAMAGER",
	[2] = "HEALER",
	[3] = "TANK",
}

local flagsByRole = {
	["DAMAGER"] = 1,
	["HEALER"] = 2,
	["TANK"] = 0,
}

local rolesByFlag = {
	[0] = "TANK",
	[1] = "DAMAGER",
	[2] = "HEALER"
}

local EJ_STYPE_ITEM = 0
local EJ_STYPE_ENCOUNTER = 1
local EJ_STYPE_CREATURE = 2
local EJ_STYPE_SECTION = 3
local EJ_STYPE_INSTANCE = 4

local EJ_FLAG_INSTANCE_ISRAID = 16
local EJ_FLAG_INSTANCE_HIDE_DIFFICULTY = 64

local EJ_FLAG_RAID_DIFFICULTY_NORMAL_10 = 1
local EJ_FLAG_RAID_DIFFICULTY_NORMAL_25 = 2
local EJ_FLAG_RAID_DIFFICULTY_HEROIC_10 = 4
local EJ_FLAG_RAID_DIFFICULTY_HEROIC_25 = 8

local EJ_FLAG_INSTANCE_DIFFICULTY_NORMAL = 1
local EJ_FLAG_INSTANCE_DIFFICULTY_HEROIC = 2

local EJ_FLAG_CLASSMASK_WARRIOR = 1
local EJ_FLAG_CLASSMASK_PALADIN = 2
local EJ_FLAG_CLASSMASK_HUNTER = 4
local EJ_FLAG_CLASSMASK_ROGUE = 8
local EJ_FLAG_CLASSMASK_PRIEST = 16
local EJ_FLAG_CLASSMASK_DEATHKINGHT = 32
local EJ_FLAG_CLASSMASK_SHAMAN = 64
local EJ_FLAG_CLASSMASK_MAGE = 128
local EJ_FLAG_CLASSMASK_WARLOCK = 256
local EJ_FLAG_CLASSMASK_MONK = 512
local EJ_FLAG_CLASSMASK_DRUID = 1024
local EJ_FLAG_CLASSMASK_DEMONHUNTER = 2048

local EJ_FLAG_ARMOR_CLOTH = 1
local EJ_FLAG_ARMOR_LEATHER = 2
local EJ_FLAG_ARMOR_MAIL = 4
local EJ_FLAG_ARMOR_PLATE = 8

local armorClassFilterMask = {
	[ITEM_SUB_CLASS_4_1] = EJ_FLAG_ARMOR_CLOTH,
	[ITEM_SUB_CLASS_4_2] = EJ_FLAG_ARMOR_LEATHER,
	[ITEM_SUB_CLASS_4_3] = EJ_FLAG_ARMOR_MAIL,
	[ITEM_SUB_CLASS_4_4] = EJ_FLAG_ARMOR_PLATE
}

local weaponClassFilterMask = {
	[ITEM_SUB_CLASS_2_0] = 111,
	[ITEM_SUB_CLASS_2_10] = 1424,
	[ITEM_SUB_CLASS_2_3] = 13,
	[ITEM_SUB_CLASS_2_2] = 13,
	[ITEM_SUB_CLASS_2_18] = 13,
	[ITEM_SUB_CLASS_2_7] = 431,
	[ITEM_SUB_CLASS_2_13] = 72,
	[ITEM_SUB_CLASS_2_15] = 1501,
	[ITEM_SUB_CLASS_2_19] = 400,
	[ITEM_SUB_CLASS_2_4] = 1147,
	[ITEM_SUB_CLASS_2_6] = 1028,
	[ITEM_SUB_CLASS_2_1] = 39,
	[ITEM_SUB_CLASS_2_8] = 39,
	[ITEM_SUB_CLASS_2_5] = 1059,
	[ITEM_SUB_CLASS_4_6] = 67,
	[ITEM_SUB_CLASS_4_7] = 2,
	[ITEM_SUB_CLASS_4_8] = 1024,
	[ITEM_SUB_CLASS_4_9] = 64,
	[ITEM_SUB_CLASS_4_10] = 32
}

local classLootData = {
	["WARRIOR"] = {fileName = "WARRIOR", flag = EJ_FLAG_CLASSMASK_WARRIOR, armorMask = EJ_FLAG_ARMOR_PLATE, subArmorMask = EJ_FLAG_ARMOR_MAIL},
	["PALADIN"] = {fileName = "PALADIN", flag = EJ_FLAG_CLASSMASK_PALADIN, armorMask = EJ_FLAG_ARMOR_PLATE, subArmorMask = EJ_FLAG_ARMOR_MAIL},
	["HUNTER"] = {fileName = "HUNTER", flag = EJ_FLAG_CLASSMASK_HUNTER, armorMask = EJ_FLAG_ARMOR_MAIL, subArmorMask = EJ_FLAG_ARMOR_LEATHER},
	["ROGUE"] = {fileName = "ROGUE", flag = EJ_FLAG_CLASSMASK_ROGUE, armorMask = EJ_FLAG_ARMOR_LEATHER},
	["PRIEST"] = {fileName = "PRIEST", flag = EJ_FLAG_CLASSMASK_PRIEST, armorMask = EJ_FLAG_ARMOR_CLOTH},
	["DEATHKNIGHT"] = {fileName = "DEATHKNIGHT", flag = EJ_FLAG_CLASSMASK_DEATHKINGHT, armorMask = EJ_FLAG_ARMOR_PLATE},
	["SHAMAN"] = {fileName = "SHAMAN", flag = EJ_FLAG_CLASSMASK_SHAMAN, armorMask = EJ_FLAG_ARMOR_MAIL, subArmorMask = EJ_FLAG_ARMOR_LEATHER},
	["MAGE"] = {fileName = "MAGE", flag = EJ_FLAG_CLASSMASK_MAGE, armorMask = EJ_FLAG_ARMOR_CLOTH},
	["WARLOCK"] = {fileName = "WARLOCK", flag = EJ_FLAG_CLASSMASK_WARLOCK, armorMask = EJ_FLAG_ARMOR_CLOTH},
	["MONK"] = {fileName = "MONK", flag = EJ_FLAG_CLASSMASK_MONK, armorMask = EJ_FLAG_ARMOR_LEATHER},
	["DRUID"] = {fileName = "DRUID", flag = EJ_FLAG_CLASSMASK_DRUID, armorMask = EJ_FLAG_ARMOR_LEATHER},
	["DEMONHUNTER"] = {fileName = "DEMONHUNTER", flag = EJ_FLAG_CLASSMASK_DEMONHUNTER, armorMask = EJ_FLAG_ARMOR_LEATHER}
}

local EJ_FLAG_SECTION_STARTS_OPEN = 1
local EJ_FLAG_SECTION_HEROIC = 2

local EJ_LINK_TYPE_INSTANCE	= 0
local EJ_LINK_TYPE_ENCOUNTER = 1
local EJ_LINK_TYPE_SECTION = 2

local MAX_CREATURES_PER_ENCOUNTER = 9
local EJ_NUM_INSTANCE_PER_ROW = 4
local EJ_LORE_MAX_HEIGHT = 97
local EJ_TIER_SELECTED
local EJ_INSTANCE_SELECTED
local EJ_HTYPE_OVERVIEW = 3

local HEADER_INDENT = 15
local SECTION_BUTTON_OFFSET = 6
local SECTION_DESCRIPTION_OFFSET = 27
local EJ_MAX_SECTION_MOVE = 320

local EJ_CONST_TIER_ID = 1
local EJ_CONST_TIER_NAME = 2

local BOSS_LOOT_BUTTON_HEIGHT = 45
local INSTANCE_LOOT_BUTTON_HEIGHT = 64

local EJ_CONST_INSTANCE_NAME = 1
local EJ_CONST_INSTANCE_DESCRIPTION = 2
local EJ_CONST_INSTANCE_BUTTONICON = 3
local EJ_CONST_INSTANCE_SMALLBUTTONICON = 4
local EJ_CONST_INSTANCE_BACKGROUND = 5
local EJ_CONST_INSTANCE_LOREBACKGROUND = 6
local EJ_CONST_INSTANCE_MAPID = 7
local EJ_CONST_INSTANCE_AREAID = 8
local EJ_CONST_INSTANCE_ORDERINDEX = 9
local EJ_CONST_INSTANCE_FLAGS = 10
local EJ_CONST_INSTANCE_ID = 11
local EJ_CONST_INSTANCE_WORLDMAPAREAID = 12

local EJ_CONST_ENCOUNTER_ID = 1
local EJ_CONST_ENCOUNTER_NAME = 2
local EJ_CONST_ENCOUNTER_DESCRIPTION = 3
local EJ_CONST_ENCOUNTER_MAPPOS1 = 4
local EJ_CONST_ENCOUNTER_MAPPOS2 = 5
local EJ_CONST_ENCOUNTER_FLOORINDEX = 6
local EJ_CONST_ENCOUNTER_WORLDMAPAREAID = 7
local EJ_CONST_ENCOUNTER_FIRSTSECTIONID = 8
local EJ_CONST_ENCOUNTER_INSTANCEID = 9
local EJ_CONST_ENCOUNTER_DIFFICULTYMASK = 10
local EJ_CONST_ENCOUNTER_FLAGS = 11
local EJ_CONST_ENCOUNTER_ORDERINDEX = 12

local EJ_CONST_ENCOUNTERCREATURE_NAME = 1
local EJ_CONST_ENCOUNTERCREATURE_DESCRIPTION = 2
local EJ_CONST_ENCOUNTERCREATURE_CREATUREDISPLAYID = 3
local EJ_CONST_ENCOUNTERCREATURE_ICON = 4
local EJ_CONST_ENCOUNTERCREATURE_ENCOUNTERID = 5
local EJ_CONST_ENCOUNTERCREATURE_ORDERINDEX = 6
local EJ_CONST_ENCOUNTERCREATURE_ID = 7
local EJ_CONST_ENCOUNTERCREATURE_CREATUREENTRY = 8

local EJ_CONST_ENCOUNTERSECTION_ID = 1
local EJ_CONST_ENCOUNTERSECTION_NAME = 2
local EJ_CONST_ENCOUNTERSECTION_DESCRIPTION = 3
local EJ_CONST_ENCOUNTERSECTION_CREATUREDISPLAYID = 4
local EJ_CONST_ENCOUNTERSECTION_DESCRIPTIONSPELLID = 5
local EJ_CONST_ENCOUNTERSECTION_ICONSPELLID = 6
local EJ_CONST_ENCOUNTERSECTION_ENCOUNTERID = 7
local EJ_CONST_ENCOUNTERSECTION_NEXTSECTIONID = 8
local EJ_CONST_ENCOUNTERSECTION_SUBSECTIONID = 9
local EJ_CONST_ENCOUNTERSECTION_PARENTSECTIONID = 10
local EJ_CONST_ENCOUNTERSECTION_FLAGS = 11
local EJ_CONST_ENCOUNTERSECTION_ICONFLAGS = 12
local EJ_CONST_ENCOUNTERSECTION_ORDERINDEX = 13
local EJ_CONST_ENCOUNTERSECTION_TYPE = 14
local EJ_CONST_ENCOUNTERSECTION_DIFFCULTYMASK = 15
local EJ_CONST_ENCOUNTERSECTION_CREATUREENTRY = 16

local EJ_CONST_ENCOUNTERITEM_ITEMENTRY = 1
local EJ_CONST_ENCOUNTERITEM_ENCOUNTERID = 2
local EJ_CONST_ENCOUNTERITEM_DIFFIULTYMASK = 3
local EJ_CONST_ENCOUNTERITEM_FACTIONMASK = 4
local EJ_CONST_ENCOUNTERITEM_FLAGS = 5
local EJ_CONST_ENCOUNTERITEM_ID = 6
local EJ_CONST_ENCOUNTERITEM_CLASSMASK = 7

local EJ_DIFFICULTIES = {
    { size = "5",  prefix = PLAYER_DIFFICULTY1, difficultyID = 1, difficultyMask = 1 },
    { size = "5",  prefix = PLAYER_DIFFICULTY2, difficultyID = 2, difficultyMask = 2 },
    { size = "10", prefix = PLAYER_DIFFICULTY1, difficultyID = 1, difficultyMask = 1 },
    { size = "25", prefix = PLAYER_DIFFICULTY1, difficultyID = 2, difficultyMask = 2 },
    { size = "10", prefix = PLAYER_DIFFICULTY2, difficultyID = 3, difficultyMask = 4 },
    { size = "25", prefix = PLAYER_DIFFICULTY2, difficultyID = 4, difficultyMask = 8 },
}

EncounterJournalSlotFilters = {
	{ invType = LE_ITEM_FILTER_TYPE_HEAD, invTypeName = INVTYPE_HEAD },
	{ invType = LE_ITEM_FILTER_TYPE_NECK, invTypeName = INVTYPE_NECK },
	{ invType = LE_ITEM_FILTER_TYPE_SHOULDER, invTypeName = INVTYPE_SHOULDER },
	{ invType = LE_ITEM_FILTER_TYPE_CLOAK, invTypeName = INVTYPE_CLOAK },
	{ invType = LE_ITEM_FILTER_TYPE_CHEST, invTypeName = INVTYPE_CHEST },
	{ invType = LE_ITEM_FILTER_TYPE_WRIST, invTypeName = INVTYPE_WRIST },
	{ invType = LE_ITEM_FILTER_TYPE_HAND, invTypeName = INVTYPE_HAND },
	{ invType = LE_ITEM_FILTER_TYPE_WAIST, invTypeName = INVTYPE_WAIST },
	{ invType = LE_ITEM_FILTER_TYPE_LEGS, invTypeName = INVTYPE_LEGS },
	{ invType = LE_ITEM_FILTER_TYPE_FEET, invTypeName = INVTYPE_FEET },
	{ invType = LE_ITEM_FILTER_TYPE_MAIN_HAND, invTypeName = INVTYPE_WEAPONMAINHAND },
	{ invType = LE_ITEM_FILTER_TYPE_OFF_HAND, invTypeName = INVTYPE_WEAPONOFFHAND },
	{ invType = LE_ITEM_FILTER_TYPE_2HWEAPON, invTypeName = INVTYPE_2HWEAPON },
	{ invType = LE_ITEM_FILTER_TYPE_HWEAPON, invTypeName = INVTYPE_WEAPON },
	{ invType = LE_ITEM_FILTER_TYPE_RANGED, invTypeName = INVTYPE_RANGEDRIGHT },
	{ invType = LE_ITEM_FILTER_TYPE_FINGER, invTypeName = INVTYPE_FINGER },
	{ invType = LE_ITEM_FILTER_TYPE_TRINKET, invTypeName = INVTYPE_TRINKET },
}

local SelectedDifficulty = 1
local SelectedLootFilter

local LJ_ITEMSET_X_OFFSET = 10
local LJ_ITEMSET_Y_OFFSET = 10
local LJ_ITEMSET_BUTTON_SPACING = 13
local LJ_ITEMSET_BOTTOM_BUFFER = 4

local CLASS_DROPDOWN = 1
local NO_SPEC_FILTER = 0
local NO_CLASS_FILTER = 0
local NO_INV_TYPE_FILTER = 0
local LOOTJOURNAL_CLASSFILTER
local LOOTJOURNAL_SPECFILTER

UIPanelWindows["EncounterJournal"] = { area = "left", pushable = 0, whileDead = 1, width = 830, xOffset = "15", yOffset = "-10"}

function EJ_GetDifficulty()
	return SelectedDifficulty
end

function EJ_GetDifficultyMask( difficulty )
	local value = EJ_GetDifficultyInfo(difficulty or SelectedDifficulty, EJ_IsRaid(EncounterJournal.instanceID))

    if value then
        return value.difficultyMask
    end

    return 1
end

function EJ_GetDifficultyInfo( difficultyID, isRaid )
	for i = 1, #EJ_DIFFICULTIES do
        local _isRaid = (EJ_DIFFICULTIES[i].size ~= "5")
        if EJ_DIFFICULTIES[i].difficultyID == difficultyID and isRaid == _isRaid then
            return EJ_DIFFICULTIES[i]
        end
    end

    return nil
end

function EJ_IsValidInstanceDifficulty( difficulty, instanceID )
 	local bossData = JOURNALENCOUNTER[instanceID or EncounterJournal.instanceID]
    local mask = 0
    local isRaid = EJ_IsRaid(instanceID or EncounterJournal.instanceID)
    local info = EJ_GetDifficultyInfo(difficulty, isRaid)

    if not info or not bossData then
        return false
    end

    for key, data in pairs(bossData) do
        mask = data[EJ_CONST_ENCOUNTER_DIFFICULTYMASK]
        if mask == -1 or bit.band(mask, EJ_GetDifficultyMask(difficulty)) == EJ_GetDifficultyMask(difficulty) then
            return true
        end
    end

    return false
end

function EJ_GetNumTiers()
	return JOURNALTIER and tCount(JOURNALTIER) or nil
end

function EJ_GetCurrentTier()
	return EJ_TIER_SELECTED or 3
end

function EJ_GetTierInfo( index )
	if JOURNALTIER and JOURNALTIER[index] then
		local name = JOURNALTIER[index][EJ_CONST_TIER_NAME]
		local tierID = JOURNALTIER[index][EJ_CONST_TIER_ID]
		local hyperlink = string.format("|cff66bbff|Hjournal:3:%d:0|h[%s]|h|r", index, name)

		return name, hyperlink, tierID
	end
	return nil
end

function EJ_SelectTier( index )
	EJ_TIER_SELECTED = index
end

local INSTANCE_REALM_FLAG = {
	[E_REALM_ID.SCOURGE] = 128,
	[E_REALM_ID.ALGALON] = 256,
};

local function SortInstances(aData, bData)
	return aData[EJ_CONST_INSTANCE_ORDERINDEX] < bData[EJ_CONST_INSTANCE_ORDERINDEX]
end

function EJ_GetInstanceByIndex( index, isRaid )
	local tierID = select(3, EJ_GetTierInfo(EJ_GetCurrentTier())) or 1

	local realmFlag = INSTANCE_REALM_FLAG[C_Service:GetRealmID() or 0] or 0;

	local buffer = {}

	for id, data in pairs(JOURNALINSTANCE) do
		if JOURNALTIERXINSTANCE[data[EJ_CONST_INSTANCE_ID]] == tierID and bit.band(data[EJ_CONST_INSTANCE_FLAGS], realmFlag) == 0 then
			if EJ_IsRaid(data[EJ_CONST_INSTANCE_ID]) == isRaid then
				buffer[#buffer + 1] = data
			end
		end
	end

	if #buffer > 0 then
		table.sort(buffer, SortInstances)

		local data = buffer[index]
		if data then
			local instanceID = data[EJ_CONST_INSTANCE_ID]
			local name = data[EJ_CONST_INSTANCE_NAME]
			local description = data[EJ_CONST_INSTANCE_DESCRIPTION]
			local bgImage = data[EJ_CONST_INSTANCE_BACKGROUND]
			local buttonImage = data[EJ_CONST_INSTANCE_BUTTONICON]
			local loreImage = data[EJ_CONST_INSTANCE_LOREBACKGROUND]
			local mapID = data[EJ_CONST_INSTANCE_MAPID]
			local areaID = data[EJ_CONST_INSTANCE_AREAID]
			local hyperlink = EJ_LinkGenerate( name, 0, instanceID, nil )

			return instanceID, name, description, bgImage, buttonImage, loreImage, mapID, areaID, hyperlink
		end
	end

	return nil
end

function EJSuggestTab_GetPlayerTierIndex()
	local playerLevel = UnitLevel("player")
	local expansionId = LE_EXPANSION_LEVEL_CURRENT
	local minDiff = MAX_PLAYER_LEVEL_TABLE[LE_EXPANSION_LEVEL_CURRENT]
	for tierId, tierLevel in pairs(MAX_PLAYER_LEVEL_TABLE) do
		local diff = tierLevel - playerLevel
		if ( diff > 0 and diff < minDiff ) then
			expansionId = tierId
			minDiff = diff
		end
	end
	return ExpansionEnumToEJTierDataTableId[expansionId]
end

function EJ_GetCurrentInstance()
	local currentMapAreaID = GetCurrentMapAreaID()

	for id, data in pairs(JOURNALINSTANCE) do
		if data[EJ_CONST_INSTANCE_WORLDMAPAREAID] == (currentMapAreaID - 1) then
			return id
		end
	end

	return nil
end

function EJ_HideInstances( index )
	if ( not index ) then
		index = 1
	end

	local scrollChild = EncounterJournal.instanceSelect.scroll.child
	local instanceButton = scrollChild["instance"..index]
	while instanceButton do
		instanceButton:Hide()
		index = index + 1
		instanceButton = scrollChild["instance"..index]
	end
end

function EJ_HideNonInstancePanels()
	-- EJ_HideSuggestPanel()
	EJ_HideLootJournalPanel()
end

function EJ_HideLootJournalPanel()
	if ( EncounterJournal.LootJournal ) then
		EncounterJournal.LootJournal:Hide()
	end
end

function EJ_SelectInstance( instanceID )
	EJ_INSTANCE_SELECTED = instanceID
end

function EJ_GetInstanceInfo( instanceID )
	instanceID = instanceID or EncounterJournal.instanceID

	if instanceID and JOURNALINSTANCE[instanceID] then
		local data = JOURNALINSTANCE[instanceID]
		local name = data[EJ_CONST_INSTANCE_NAME]
		local description = data[EJ_CONST_INSTANCE_DESCRIPTION]
		local bgImage = data[EJ_CONST_INSTANCE_BACKGROUND]
		local buttonImage = data[EJ_CONST_INSTANCE_BUTTONICON]
		local loreImage = data[EJ_CONST_INSTANCE_LOREBACKGROUND]
		local dungeonAreaMapID = data[EJ_CONST_INSTANCE_WORLDMAPAREAID]
		local shouldDisplayDifficulty = bit.band(data[EJ_CONST_INSTANCE_FLAGS], EJ_FLAG_INSTANCE_HIDE_DIFFICULTY) ~= EJ_FLAG_INSTANCE_HIDE_DIFFICULTY

		return name, description, bgImage, loreImage, buttonImage, dungeonAreaMapID, shouldDisplayDifficulty
	end

	return nil
end

function UpdateDifficultyAnchoring(difficultyFrame)
	local infoFrame = difficultyFrame:GetParent()
	infoFrame.reset:ClearAllPoints()

	if difficultyFrame:IsShown() then
		infoFrame.reset:SetPoint("RIGHT", difficultyFrame, "LEFT", -10, 0)
	else
		infoFrame.reset:SetPoint("TOPRIGHT", infoFrame, "TOPRIGHT", -19, -13)
	end
end

function UpdateDifficultyVisibility()
	local shouldDisplayDifficulty = select(7, EJ_GetInstanceInfo());

	local info = EncounterJournal.encounter.info
	info.difficulty:SetShown(shouldDisplayDifficulty and (info.tab ~= 4))

	UpdateDifficultyAnchoring(info.difficulty)
end

function EJ_IsRaid( instanceID )
	if instanceID and JOURNALINSTANCE[instanceID] then
		if bit.band(JOURNALINSTANCE[instanceID][EJ_CONST_INSTANCE_FLAGS], EJ_FLAG_INSTANCE_ISRAID) == EJ_FLAG_INSTANCE_ISRAID then
			return true
		end
	end
	return false
end

function EJ_GetEncounterInfoByIndex( index, instanceID )
	if not EncounterJournal.instanceID and not instanceID then
		return nil
	end

	local buffer = {}
	local playerFaction = UnitFactionGroup("player")
	if playerFaction == "Renegade" then
		local raceData = C_CreatureInfo.GetFactionInfo(UnitRace("player"))
		if raceData then
			playerFaction = raceData.groupTag
		end
	end
	local playerFactionFlag = playerFaction == "Alliance" and 4 or 8

	local difficulty = SelectedDifficulty

	if not instanceID then
		instanceID = EncounterJournal.instanceID
	end

	if not JOURNALENCOUNTER[instanceID] then
		return nil
	end

	if not EJ_IsValidInstanceDifficulty(difficulty, EJ_GetCurrentInstance()) and WorldMapFrame:IsShown() then
		difficulty = EJ_GetValidationDifficulty(1, EJ_GetCurrentInstance())
	end

	for bossID, data in pairs(JOURNALENCOUNTER[instanceID]) do
		if data[EJ_CONST_ENCOUNTER_DIFFICULTYMASK] == -1 or bit.band(data[EJ_CONST_ENCOUNTER_DIFFICULTYMASK],  EJ_GetDifficultyMask(difficulty)) ==  EJ_GetDifficultyMask(difficulty) then
			if data[EJ_CONST_ENCOUNTER_FLAGS] == 0 or bit.band(data[EJ_CONST_ENCOUNTER_FLAGS], playerFactionFlag) == playerFactionFlag then
				table.insert(buffer, data)
			end
		end
	end

	if #buffer > 0 then
		table.sort(buffer, function(a, b)
			return a[EJ_CONST_ENCOUNTER_ORDERINDEX] < b[EJ_CONST_ENCOUNTER_ORDERINDEX]
		end)

		if buffer[index] then
			local data = buffer[index]
			local name = data[EJ_CONST_ENCOUNTER_NAME]
			local description = data[EJ_CONST_ENCOUNTER_DESCRIPTION]
			local bossID = data[EJ_CONST_ENCOUNTER_ID]
			local rootSectionID = 1 -- TODO
			local map_pos1 = data[EJ_CONST_ENCOUNTER_MAPPOS1]
			local map_pos2 = data[EJ_CONST_ENCOUNTER_MAPPOS2]
			local floorIndex = data[EJ_CONST_ENCOUNTER_FLOORINDEX]
			local worldMapAreaID = data[EJ_CONST_ENCOUNTER_WORLDMAPAREAID]
			local link = EJ_LinkGenerate( name, 1, bossID, difficulty )

			return name, description, bossID, rootSectionID, link, instanceID, map_pos1, map_pos2, floorIndex, worldMapAreaID
		end
	end

	return nil
end

function EJ_GetCreatureInfo( index, encounterID )
	if not encounterID and EncounterJournal.encounterID then
		encounterID = EncounterJournal.encounterID
	end

	if not index or not JOURNALENCOUNTERCREATURE[encounterID] then
		return nil
	end

	local buffer = {}

	for encounterID, data in pairs(JOURNALENCOUNTERCREATURE[encounterID]) do
		table.insert(buffer, data)
	end

	if #buffer > 0 then
		table.sort(buffer, function(a, b)
			return a[EJ_CONST_ENCOUNTERCREATURE_ORDERINDEX] < b[EJ_CONST_ENCOUNTERCREATURE_ORDERINDEX]
		end)

		if buffer[index] then
			local data = buffer[index]
			local id = data[EJ_CONST_ENCOUNTERCREATURE_ID]
			local name = data[EJ_CONST_ENCOUNTERCREATURE_NAME]
			local description = data[EJ_CONST_ENCOUNTERCREATURE_DESCRIPTION]
			local displayInfo = data[EJ_CONST_ENCOUNTERCREATURE_CREATUREDISPLAYID]
			local iconImage = data[EJ_CONST_ENCOUNTERCREATURE_ICON] ~= "" and data[EJ_CONST_ENCOUNTERCREATURE_ICON] or "Interface\\EncounterJournal\\UI-EJ-BOSS-Default"
			local creatureEntry = data[EJ_CONST_ENCOUNTERCREATURE_CREATUREENTRY]
			return id, name, description, displayInfo, iconImage, creatureEntry
		end
	end

	return nil
end

function EJ_GetSectionInfo( sectionID )
    local currentDiffMask = EJ_GetDifficultyMask(SelectedDifficulty);
    if JOURNALENCOUNTERSECTION[sectionID] then
        local data = JOURNALENCOUNTERSECTION[sectionID]
        local title = data[EJ_CONST_ENCOUNTERSECTION_NAME]
        local description = data[EJ_CONST_ENCOUNTERSECTION_DESCRIPTION]
        local depth = data[EJ_CONST_ENCOUNTERSECTION_TYPE]
        local abilityIcon = data[EJ_CONST_ENCOUNTERSECTION_DESCRIPTIONSPELLID] > 0 and select(3, GetSpellInfo(data[EJ_CONST_ENCOUNTERSECTION_DESCRIPTIONSPELLID])) or select(3, GetSpellInfo(data[EJ_CONST_ENCOUNTERSECTION_ICONSPELLID]))
        local displayInfo = data[EJ_CONST_ENCOUNTERSECTION_CREATUREDISPLAYID]
        local siblingID = data[EJ_CONST_ENCOUNTERSECTION_NEXTSECTIONID] or nil
        local nextSectionID = data[EJ_CONST_ENCOUNTERSECTION_SUBSECTIONID] or nil
        local filteredByDifficulty = data[EJ_CONST_ENCOUNTERSECTION_DIFFCULTYMASK] ~= -1 and bit.band(data[EJ_CONST_ENCOUNTERSECTION_DIFFCULTYMASK], currentDiffMask) ~=  currentDiffMask
        local link = EJ_LinkGenerate( title, 2, sectionID, SelectedDifficulty )
        local startsOpen = bit.band(data[EJ_CONST_ENCOUNTERSECTION_FLAGS], EJ_FLAG_SECTION_STARTS_OPEN) == EJ_FLAG_SECTION_STARTS_OPEN
        local creatureEntry = data[EJ_CONST_ENCOUNTERSECTION_CREATUREENTRY]

        local iconFlags = {}
        local tempFlags = data[EJ_CONST_ENCOUNTERSECTION_ICONFLAGS]
        if tempFlags ~= 0 then
            for i = 32, 0, -1 do
                local cur  = math.pow(2, i)
                local temp = tempFlags - cur
                if temp >= 0 then
                    table.insert(iconFlags, i)
                    tempFlags = tempFlags - cur
                end
            end
        end
        local returnedFlags = {}
        if #iconFlags > 4 then
            for i = 1, 4, 1 do
                table.insert(returnedFlags, iconFlags[i])
            end
        else
            returnedFlags = iconFlags
        end

        for i=1, math.floor(#returnedFlags / 2) do
            returnedFlags[i], returnedFlags[#returnedFlags - i + 1] = returnedFlags[#returnedFlags - i + 1], returnedFlags[i]
        end

        return title, description, depth, abilityIcon, displayInfo, siblingID, nextSectionID, filteredByDifficulty, link, startsOpen, creatureEntry, unpack(returnedFlags)
    end

    return nil
end

function EJ_GetEncounterInfo( encounterID )
	local instanceID

	if encounterID and JOURNALENCOUNTER_BY_ENCOUNTER[encounterID] then
		instanceID = JOURNALENCOUNTER_BY_ENCOUNTER[encounterID][EJ_CONST_ENCOUNTER_INSTANCEID]
	else
		instanceID = EncounterJournal.instanceID
	end

	if instanceID then
		if JOURNALENCOUNTER[instanceID] then
			for _, data in pairs(JOURNALENCOUNTER[instanceID]) do
				if data[EJ_CONST_ENCOUNTER_ID] == encounterID then
					local name = data[EJ_CONST_ENCOUNTER_NAME]
					local description = data[EJ_CONST_ENCOUNTER_DESCRIPTION]
					local encounterID = data[EJ_CONST_ENCOUNTER_ID]
					local rootSectionID = data[EJ_CONST_ENCOUNTER_FIRSTSECTIONID]
					local link = EJ_LinkGenerate( name, 1, encounterID, SelectedDifficulty )
					local instanceID = data[EJ_CONST_ENCOUNTER_INSTANCEID]
					local difficultyMask = data[EJ_CONST_ENCOUNTER_DIFFICULTYMASK]

					return name, description, encounterID, rootSectionID, link, instanceID, difficultyMask
				end
			end
		end
	end

	return nil
end

function EJ_InstanceIsRaid()
	if EncounterJournal.instanceID then
		return EJ_IsRaid(EncounterJournal.instanceID)
	end
end

local lootBuffer = {}
local lastBossData = {}
local lastDiffficulty = 0
local lastSlotFilter = 0
local lastClassFilter = 0
function EJ_GetLootInfoByIndex( index )
	if not index then
		return nil
	end

	EJ_BuildLootData()

	if lootBuffer[index] then
		return unpack(lootBuffer[index])
	end

	return nil
end

local ITEM_REALM_FLAG = {
	[E_REALM_ID.SCOURGE] = 4,
	[E_REALM_ID.ALGALON] = 8,
};

function EJ_BuildLootData()
	local bossData = not EncounterJournal.encounterID and EncounterJournal.encounterList or { EncounterJournal.encounterID }
	local factionGroup = EncounterJournal.playerFactionGroup
	local currentDiffMask = EJ_GetDifficultyMask(SelectedDifficulty)
	local slotFilter = EJ_GetSlotFilter()
	local classFilter = EJ_GetLootFilter()

	local realmFlag = ITEM_REALM_FLAG[C_Service:GetRealmID() or 0] or 0;

	if lastClassFilter ~= classFilter or slotFilter ~= lastSlotFilter or bossData ~= lastBossData or SelectedDifficulty ~= lastDiffficulty then
		lootBuffer = {}
		lastBossData = bossData
		lastDiffficulty = SelectedDifficulty
		lastSlotFilter = slotFilter
		lastClassFilter = classFilter
		for i = 1, #bossData do
			if JOURNALENCOUNTERITEM[bossData[i]] then
				for j = 1, #JOURNALENCOUNTERITEM[bossData[i]] do
					local data = JOURNALENCOUNTERITEM[bossData[i]][j]
					local factionMask = data[EJ_CONST_ENCOUNTERITEM_FACTIONMASK]
					local difficultyMask = data[EJ_CONST_ENCOUNTERITEM_DIFFIULTYMASK]
					local flag = data[EJ_CONST_ENCOUNTERITEM_FLAGS]

					if factionMask == -1 or factionMask == factionGroup then
						if bit.band(flag, realmFlag) == 0 and (data.link and difficultyMask == -1 or bit.band(difficultyMask, currentDiffMask) == currentDiffMask) then
							local itemID = data[EJ_CONST_ENCOUNTERITEM_ITEMENTRY]
							if not data.name then
								local name, link, quality, iLevel, reqLevel, armorType, subclass, maxStack, equipLoc, icon, vendorPrice = EJ_GetItemInfo(itemID)
								if name then
									data.name = name
									data.link = link
									data.quality = quality
									data.iLevel = iLevel
									data.reqLevel = reqLevel
									data.armorType = armorType
									data.subclass = subclass
									data.maxStack = maxStack
									data.equipLoc = equipLoc
									data.icon = icon
									data.vendorPrice = vendorPrice
								end
							end
							if data.name and (slotFilter == NO_INV_TYPE_FILTER or EJ_GetSlotFilterValidation(data.equipSlot)) then
								if classFilter == NO_CLASS_FILTER or EJ_GetClassFilterValidation(data.subclass, data.armorType, itemID) then
									local encounterID = data[EJ_CONST_ENCOUNTERITEM_ENCOUNTERID]
									table.insert(lootBuffer, {itemID, encounterID, data.name, data.icon, _G[data.equipSlot], data.subclass, data.link, data.armorType})
								end
							end
						end
					end
				end
			end
		end
		table.sort(lootBuffer, function(a, b)
			if a[5] == INVTYPE_CLOAK and b[5] ~= INVTYPE_CLOAK then
				return true
			elseif b[5] == INVTYPE_CLOAK and a[5] ~= INVTYPE_CLOAK then
				return false
			end

			if a[6] == ITEM_SUB_CLASS_4_1 and b[6] ~= ITEM_SUB_CLASS_4_1 then
				return true
			elseif b[6] == ITEM_SUB_CLASS_4_1 and a[6] ~= ITEM_SUB_CLASS_4_1 then
				return false
			end

			if a[6] == ITEM_SUB_CLASS_4_2 and b[6] ~= ITEM_SUB_CLASS_4_2 then
				return true
			elseif b[6] == ITEM_SUB_CLASS_4_2 and a[6] ~= ITEM_SUB_CLASS_4_2 then
				return false
			end

			if a[6] == ITEM_SUB_CLASS_4_3 and b[6] ~= ITEM_SUB_CLASS_4_3 then
				return true
			elseif b[6] == ITEM_SUB_CLASS_4_3 and a[6] ~= ITEM_SUB_CLASS_4_3 then
				return false
			end

			if a[6] == ITEM_SUB_CLASS_4_4 and b[6] ~= ITEM_SUB_CLASS_4_4 then
				return true
			elseif b[6] == ITEM_SUB_CLASS_4_4 and a[6] ~= ITEM_SUB_CLASS_4_4 then
				return false
			end

			if a[5] == INVTYPE_FINGER and b[5] ~= INVTYPE_FINGER then
				return true
			elseif b[5] == INVTYPE_FINGER and a[5] ~= INVTYPE_FINGER then
				return false
			end

			if a[5] == INVTYPE_NECK and b[5] ~= INVTYPE_NECK then
				return true
			elseif b[5] == INVTYPE_NECK and a[5] ~= INVTYPE_NECK then
				return false
			end

			if a[5] == INVTYPE_TRINKET and b[5] ~= INVTYPE_TRINKET then
				return true
			elseif b[5] == INVTYPE_TRINKET and a[5] ~= INVTYPE_TRINKET then
				return false
			end

			if a[5] == INVTYPE_2HWEAPON and b[5] ~= INVTYPE_2HWEAPON then
				return true
			elseif b[5] == INVTYPE_2HWEAPON and a[5] ~= INVTYPE_2HWEAPON then
				return false
			end

			if a[5] == INVTYPE_WEAPON and b[5] ~= INVTYPE_WEAPON then
				return true
			elseif b[5] == INVTYPE_WEAPON and a[5] ~= INVTYPE_WEAPON then
				return false
			end

			if a[5] == INVTYPE_RANGED and b[5] ~= INVTYPE_RANGED then
				return true
			elseif b[5] == INVTYPE_RANGED and a[5] ~= INVTYPE_RANGED then
				return false
			end

			if a[5] == INVTYPE_THROWN and b[5] ~= INVTYPE_THROWN then
				return true
			elseif b[5] == INVTYPE_THROWN and a[5] ~= INVTYPE_THROWN then
				return false
			end

			if a[5] == INVTYPE_RANGEDRIGHT and b[5] ~= INVTYPE_RANGEDRIGHT then
				return true
			elseif b[5] == INVTYPE_RANGEDRIGHT and a[5] ~= INVTYPE_RANGEDRIGHT then
				return false
			end

			if a[5] == INVTYPE_HOLDABLE and b[5] ~= INVTYPE_HOLDABLE then
				return true
			elseif b[5] == INVTYPE_HOLDABLE and a[5] ~= INVTYPE_HOLDABLE then
				return false
			end

			if a[5] == INVTYPE_WEAPONOFFHAND and b[5] ~= INVTYPE_WEAPONOFFHAND then
				return true
			elseif b[5] == INVTYPE_WEAPONOFFHAND and a[5] ~= INVTYPE_WEAPONOFFHAND then
				return false
			end

			if a[5] == INVTYPE_WEAPONMAINHAND and b[5] ~= INVTYPE_WEAPONMAINHAND then
				return true
			elseif b[5] == INVTYPE_WEAPONMAINHAND and a[5] ~= INVTYPE_WEAPONMAINHAND then
				return false
			end

			if a[5] == INVTYPE_RELIC and b[5] ~= INVTYPE_RELIC then
				return true
			elseif b[5] == INVTYPE_RELIC and a[5] ~= INVTYPE_RELIC then
				return false
			end

			if a[5] == INVTYPE_BODY and b[5] ~= INVTYPE_BODY then
				return true
			elseif b[5] == INVTYPE_BODY and a[5] ~= INVTYPE_BODY then
				return false
			end

			if a[5] == INVTYPE_TABARD and b[5] ~= INVTYPE_TABARD then
				return true
			elseif b[5] == INVTYPE_TABARD and a[5] ~= INVTYPE_TABARD then
				return false
			end

			return (a[3] or "") < (b[3] or "")
		end)
	end
end

function EJ_GetNumLoot()
    EJ_BuildLootData()
    return #lootBuffer
end

function EJ_GetSlotFilter()
	return EJ_slotFilter or NO_INV_TYPE_FILTER
end

function EJ_SetSlotFilter( slot )
	MountJournal_UpdateScrollPos(EncounterJournal.encounter.info.lootScroll, 1)
	EJ_slotFilter = slot
end

function EJ_GetSlotFilterValidation( slot )
	if not EJ_GetSlotFilter() then
		return
	end

	for k, v in pairs(EncounterJournalSlotFilters) do
		if v.invTypeName == _G[slot] and v.invType == EJ_GetSlotFilter() then
			return true
		end
	end

	return false
end

local subClassWhiteList = {ITEM_SUB_CLASS_4_5, ITEM_SUB_CLASS_4_6, ITEM_SUB_CLASS_4_8, ITEM_SUB_CLASS_4_9, ITEM_SUB_CLASS_4_10, ITEM_SUB_CLASS_4_7}
local itemClassWhiteList = {
	ITEM_SUB_CLASS_15_2,
	ITEM_SUB_CLASS_5_0,
	ITEM_SUB_CLASS_7_0,
	ITEM_SUB_CLASS_7_1,
	ITEM_SUB_CLASS_7_2,
	ITEM_SUB_CLASS_7_3,
	ITEM_SUB_CLASS_7_4,
	ITEM_SUB_CLASS_7_5,
	ITEM_SUB_CLASS_7_6,
	ITEM_SUB_CLASS_7_7,
	ITEM_SUB_CLASS_7_8,
	ITEM_SUB_CLASS_7_9,
	ITEM_SUB_CLASS_7_10,
	ITEM_SUB_CLASS_7_11,
	ITEM_SUB_CLASS_7_12,
	ITEM_SUB_CLASS_7_13,
	ITEM_SUB_CLASS_7_14,
	ITEM_SUB_CLASS_7_15,
	ITEM_SUB_CLASS_9_0,
	ITEM_SUB_CLASS_9_1,
	ITEM_SUB_CLASS_9_2,
	ITEM_SUB_CLASS_9_3,
	ITEM_SUB_CLASS_9_4,
	ITEM_SUB_CLASS_9_5,
	ITEM_SUB_CLASS_9_6,
	ITEM_SUB_CLASS_9_7,
	ITEM_SUB_CLASS_9_8,
	ITEM_SUB_CLASS_9_9,
	ITEM_SUB_CLASS_9_10,
	ITEM_SUB_CLASS_9_11,
	ITEM_SUB_CLASS_11_3,
	ITEM_SUB_CLASS_12_0,
	ITEM_SUB_CLASS_13_0,
	ITEM_SUB_CLASS_13_1,
	ITEM_SUB_CLASS_14_0,
	ITEM_SUB_CLASS_15_0,
	ITEM_SUB_CLASS_15_1,
	ITEM_SUB_CLASS_15_3,
	ITEM_SUB_CLASS_15_4,
	ITEM_SUB_CLASS_15_5,
	ITEM_SUB_CLASS_2_14,
}

function EJ_GetClassFilterValidation( subclass, armorType, itemEntry )
	if not subclass or not EJ_GetLootFilter() then
		return false
	end

	if EJ_GetLootFilter() == 0 then
		return true
	end

	local _, _, _, _, _, _, _, _, invtype = EJ_GetItemInfo(itemEntry)
	
	if armorType == ITEM_CLASS_2 or invtype == INVTYPE_CLOAK or (armorType == ITEM_CLASS_4 and tContains(subClassWhiteList, subclass)) then
		local classItemMask = weaponClassFilterMask[subclass]
		local classMask = classLootData[EJ_GetLootFilter()].flag

		if classItemMask and classMask then
			if bit.band(classItemMask, classMask) ~= 0 then
				return true
			end
		end
	elseif tContains(itemClassWhiteList, subclass) or invtype == "INVTYPE_CLOAK" then
		return true
	else
		local armorClassMask = UnitLevel("player") < 40 and classLootData[EJ_GetLootFilter()].subArmorMask or classLootData[EJ_GetLootFilter()].armorMask
		local armorMask = armorClassFilterMask[subclass]

		if armorMask and armorMask then
			if bit.band(armorClassMask, armorMask) ~= 0 then
				return true
			end
		end
	end

	return false
end

function EJ_SetSearch( text )
	EJ_SearchBuffer = {}

	for _, data in pairs(EJ_SearchData) do
		if string.find( string.upper( data.name ), string.upper( text ), 1, true ) then
			table.insert(EJ_SearchBuffer, data)
		end
	end
end

function EJ_GetNumSearchResults()
	return #EJ_SearchBuffer or 0
end

function EJ_GetSearchResult( index )
	if not index then
		return nil
	end

	if EJ_SearchBuffer[index] then
		local data = EJ_SearchBuffer[index]
		return data.id, data.stype, data.difficulty, data.instanceID, data.encounterID, data.link
	end

	return nil
end

function EJ_GetLootInfo( itemEntry )
	if not itemEntry then
		return nil
	end

	if JOURNALENCOUNTERITEM_BY_ENTRY[itemEntry] then
		local data = JOURNALENCOUNTERITEM_BY_ENTRY[itemEntry]
		local itemID = itemEntry
		local encounterID = data[EJ_CONST_ENCOUNTERITEM_ENCOUNTERID]
		local qualityColor = BAG_ITEM_QUALITY_COLORS[data.quality or 1]
		local name = (qualityColor and data.name) and qualityColor:WrapTextInColorCode(data.name) or data.name
		local icon = data.icon
		local slot = data.equipSlot
		local armorType = data.subclass
		local link = nil -- TODO
		local difficultyMask = data[EJ_CONST_ENCOUNTERITEM_DIFFIULTYMASK];
		local difficultyID = 1;

		if difficultyMask ~= -1 then
			for i = #EJ_DIFFICULTIES, 1, -1 do
				local diffInfo = EJ_DIFFICULTIES[i];
				if bit.band(difficultyMask, diffInfo.difficultyMask) == diffInfo.difficultyMask then
					difficultyID = diffInfo.difficultyID;
					break;
				end
			end
		end

		local factionID = data[EJ_CONST_ENCOUNTERITEM_FACTIONMASK]

		return itemID, encounterID, name, icon, slot, armorType, link, difficultyID, factionID
	end

	return nil
end

function EJ_GetSectionPath( sectionID )
	if not sectionID then
		return nil
	end
	if JOURNALENCOUNTERSECTION[sectionID] then
		local data = JOURNALENCOUNTERSECTION[sectionID]
		local _sectionID = data[EJ_CONST_ENCOUNTERSECTION_ID]
		local parentSectionID = data[EJ_CONST_ENCOUNTERSECTION_PARENTSECTIONID] or nil
		return _sectionID, parentSectionID
	end

	return nil
end

function EJ_GetMapEncounter( index )
	if not index then
		return nil
	end

	local _index = 1
	local buffer = {}
	local currentMapAeraID = GetCurrentMapAreaID()
	local currentMapDungeonLevel = GetCurrentMapDungeonLevel()
	local name, description, bossID, rootSectionID, link, instanceID, map_pos1, map_pos2, floorIndex, worldMapAreaID = EJ_GetEncounterInfoByIndex(_index, EJ_GetCurrentInstance())

	while name do
		if name and (currentMapAeraID - 1) == worldMapAreaID and floorIndex == currentMapDungeonLevel then
			table.insert(buffer, {map_pos1, map_pos2, instanceID, name, description, bossID, rootSectionID})
		end

		_index = _index + 1
		name, description, bossID, rootSectionID, link, instanceID, map_pos1, map_pos2, floorIndex, worldMapAreaID = EJ_GetEncounterInfoByIndex(_index, EJ_GetCurrentInstance())
	end

	if buffer[index] then
		return unpack(buffer[index])
	end

	return nil
end

function EJ_SetLootFilter( filter )
	MountJournal_UpdateScrollPos(EncounterJournal.encounter.info.lootScroll, 1)
	SelectedLootFilter = filter
end

function EJ_GetLootFilter()
	-- Default to NO_CLASS_FILTER (show ALL loot). The upstream default returned
	-- the player's own class, which hid most boss loot until you opened the class
	-- dropdown -- it looked like dungeons were "missing loot". The dropdown still
	-- lets the player filter to a class on demand.
	return SelectedLootFilter or NO_CLASS_FILTER
end

function EJ_ResetLootFilter()
	local _, fileName = UnitClass("player")
	SelectedLootFilter = fileName
	EncounterJournal_UpdateFilterString()
end

function EJ_LinkGenerate( name, jtype, id, difficulty )
	return string.format("|cff66bbff|Hjournal:%d:%d:%d|h[%s]|h|r", jtype or 0, id or 0, difficulty or 1, name or "~NOT NAME~")
end

function EJ_HandleLinkPath( jtype, id )
	local instanceID, encounterID, sectionID, tierIndex

	if jtype == 0 then
		instanceID = id
	elseif jtype == 1 then
		local name, description, _, rootSectionID, link, instID, difficultyMask = EJ_GetEncounterInfo(id)

		instanceID = instID
		encounterID = id
	elseif jtype == 2 then
		local data = JOURNALENCOUNTERSECTION[id]

		if data then
			encounterID = data[EJ_CONST_ENCOUNTERSECTION_ENCOUNTERID]
			instanceID = select(6, EJ_GetEncounterInfo(encounterID))
			sectionID = id
		end
	end

	if instanceID then
		tierIndex = EJ_GetTierIndex(JOURNALTIERXINSTANCE[instanceID])
	end

	return instanceID, encounterID, sectionID, tierIndex
end

function EJ_GetTierIndex( tierID )
	if not tierID then
		return
	end

	for k, v in pairs(JOURNALTIER) do
		if tierID == v[EJ_CONST_TIER_ID] then
			return k
		end
	end

	return nil
end

function EJ_SetDifficulty( difficulty )
	local _, creatureEntry;
	if EncounterJournal.encounterID then
		_, _, _, _, _, creatureEntry = EJ_GetCreatureInfo(1, EncounterJournal.encounterID);
	end

	SelectedDifficulty = difficulty

	if creatureEntry then
		local index = 1;
		local encounterID;
		_, _, encounterID = EJ_GetEncounterInfoByIndex(index);
		while encounterID do
			if EncounterJournal.encounterID ~= encounterID and select(6, EJ_GetCreatureInfo(1, encounterID)) == creatureEntry then
				EncounterJournal.encounterID = encounterID;
				break;
			end

			index = index + 1;
			_, _, encounterID = EJ_GetEncounterInfoByIndex(index);
		end
	end

	EncounterJournal_UpdateDifficulty(difficulty)
end

function EJ_GetValidationDifficulty( index, instanceID )
	if not index then
		return nil
	end

	local buffer = {}

	for i = 1, #EJ_DIFFICULTIES do
		local entry = EJ_DIFFICULTIES[i]
		if EJ_IsValidInstanceDifficulty(entry.difficultyID, instanceID) and (entry.size ~= "5" == EJ_IsRaid(instanceID or EncounterJournal.instanceID)) then
			table.insert(buffer, entry.difficultyID)
		end
	end

	if buffer[index] then
		return buffer[index]
	end
end

function EJ_SetValidationDifficulty( index )
	EncounterJournal_SelectDifficulty(nil, EJ_GetValidationDifficulty( index ))
end

function EncounterJournal_OnLoad( self, ... )
	SetPortraitToTexture(self.encounter.info.instanceButton.icon, "Interface\\EncounterJournal\\UI-EJ-Home-Icon")

	EJ_SearchData = {}

	for _, container in pairs(JOURNALENCOUNTERITEM) do
		for _, v in pairs(container) do
			local name, link, quality, iLevel, reqLevel, armorType, subclass, maxStack, equipSlot, icon, vendorPrice = EJ_GetItemInfo(v[1])
			if name then
				v.name 			= name
				v.link 			= link
				v.quality 		= quality
				v.iLevel 		= iLevel
				v.reqLevel 		= reqLevel
				v.armorType 	= armorType
				v.subclass 		= subclass
				v.maxStack 		= maxStack
				v.equipSlot 	= equipSlot
				v.icon 			= icon
				v.vendorPrice 	= vendorPrice
			end
		end
	end

	for _, data in pairs(JOURNALINSTANCE) do
		local name = data[EJ_CONST_INSTANCE_NAME]
		local id = data[EJ_CONST_INSTANCE_ID]
		local stype = EJ_STYPE_INSTANCE
		local difficulty = 1
		local instanceID = id
		local encounterID = -1
		local link = nil -- TODO

		table.insert(EJ_SearchData, {name = name, id = id, stype = stype, difficulty = difficulty, instanceID = instanceID, encounterID = encounterID, link = link})
	end

	for _, container in pairs(JOURNALENCOUNTER) do
		for _, data in pairs(container) do
			local name = data[EJ_CONST_ENCOUNTER_NAME]
			local id = data[EJ_CONST_ENCOUNTER_ID]
			local stype = EJ_STYPE_ENCOUNTER
			local difficulty = data[EJ_CONST_ENCOUNTER_DIFFICULTYMASK]
			local instanceID = data[EJ_CONST_ENCOUNTER_INSTANCEID]
			local encounterID = id
			local link = GetSpellLink(id)

			JOURNALENCOUNTER_BY_ENCOUNTER[encounterID] = data

			table.insert(EJ_SearchData, {name = name, id = id, stype = stype, difficulty = difficulty, instanceID = instanceID, encounterID = encounterID, link = link})
		end
	end

	for _, container in pairs(JOURNALENCOUNTERCREATURE) do
		for _, data in pairs(container) do
			local encounterID = data[EJ_CONST_ENCOUNTERCREATURE_ENCOUNTERID]
			local enc = JOURNALENCOUNTER_BY_ENCOUNTER[encounterID]
			if enc then  -- skip orphans (creature whose encounter was removed / not yet added)
				local name = data[EJ_CONST_ENCOUNTERCREATURE_NAME]
				local id = data[EJ_CONST_ENCOUNTERCREATURE_ID]
				local stype = EJ_STYPE_CREATURE
				local difficulty = enc[EJ_CONST_ENCOUNTER_DIFFICULTYMASK]
				local instanceID = enc[EJ_CONST_ENCOUNTER_INSTANCEID]
				local link = nil -- TODO

				table.insert(EJ_SearchData, {name = name, id = id, stype = stype, difficulty = difficulty, instanceID = instanceID, encounterID = encounterID, link = link})
			end
		end
	end

	for _, container in pairs(JOURNALENCOUNTERITEM) do
		for _, data in pairs(container) do
			if data.link then
				local id = data[EJ_CONST_ENCOUNTERITEM_ITEMENTRY]
				JOURNALENCOUNTERITEM_BY_ENTRY[id] = data

				local encounterID = data[EJ_CONST_ENCOUNTERITEM_ENCOUNTERID]
				local enc = JOURNALENCOUNTER_BY_ENCOUNTER[encounterID]
				if enc then  -- skip orphans (item whose encounter was removed / not yet added)
					local name = data.name
					local stype = EJ_STYPE_ITEM
					local difficulty = data[EJ_CONST_ENCOUNTERITEM_DIFFIULTYMASK]
					local instanceID = enc[EJ_CONST_ENCOUNTER_INSTANCEID]
					local link = data.link

					table.insert(EJ_SearchData, {name = name, id = id, stype = stype, difficulty = difficulty, instanceID = instanceID, encounterID = encounterID, link = link})
				end
			end
		end
	end

	for _, data in pairs(JOURNALENCOUNTERSECTION) do
		local encounterID = data[EJ_CONST_ENCOUNTERSECTION_ENCOUNTERID]
		local enc = JOURNALENCOUNTER_BY_ENCOUNTER[encounterID]
		if enc then  -- skip orphans (section whose encounter was removed / not yet added)
			local name = data[EJ_CONST_ENCOUNTERSECTION_NAME]
			local id = data[EJ_CONST_ENCOUNTERSECTION_ID]
			local stype = EJ_STYPE_SECTION
			local difficulty = data[EJ_CONST_ENCOUNTERSECTION_DIFFCULTYMASK]
			local instanceID = enc[EJ_CONST_ENCOUNTER_INSTANCEID]
			local link = nil -- TODO

			table.insert(EJ_SearchData, {name = name, id = id, stype = stype, difficulty = difficulty, instanceID = instanceID, encounterID = encounterID, link = link})
		end
	end

	self.inset:SetFrameLevel(self:GetFrameLevel())
	self.instanceSelect:SetFrameLevel(self:GetFrameLevel())
	self.encounter:SetFrameLevel(self:GetFrameLevel())
	self.encounter.info:SetFrameLevel(self.encounter:GetFrameLevel())

	self.encounter.freeHeaders = {}
	self.encounter.usedHeaders = {}
	self.encounterList = {}

	local function UpdateFactionArt()
		local playerFaction = UnitFactionGroup("player")
		if playerFaction == "Renegade" then
			local raceData = C_CreatureInfo.GetFactionInfo(UnitRace("player"))
			if raceData then
				playerFaction = raceData.groupTag
			end
		end
		self.playerFactionGroup = playerFaction == "Alliance" and -2 or -3
	end

	C_FactionManager:RegisterFactionOverrideCallback(UpdateFactionArt, true)

	EncounterJournalTitleText:SetText(ADVENTURE_JOURNAL)
	SetPortraitToTexture(EncounterJournalPortrait,"Interface\\EncounterJournal\\UI-EJ-PortraitIcon")

	self.encounter.instance.mapButton.Text:SetText(ENCOUNTER_JOURNAL_SHOW_MAP)

	local homeData = {
		name = NAVIGATIONBAR_HOME,
		OnClick = function()
			EJ_ContentTab_Select(EncounterJournal.instanceSelect.selectedTab)
			NavBar_Reset(EncounterJournal.navBar)
		end,
	}
	NavBar_Initialize(self.navBar, "NavButtonTemplate", homeData, self.navBar.home, self.navBar.overflow)

	self.encounter.overviewFrame = self.encounter.info.overviewScroll.child
	self.encounter.overviewFrame.isOverview = true
	self.encounter.overviewFrame.overviews = {}
	self.encounter.info.overviewScroll.ScrollBar.scrollStep = 30

	self.encounter.infoFrame = self.encounter.info.detailsScroll.child
	self.encounter.info.detailsScroll.ScrollBar.scrollStep = 30

	self.encounter.bossesFrame = self.encounter.info.bossesScroll.child
	self.encounter.info.bossesScroll.ScrollBar.scrollStep = 30

	self.encounter.info.lootScroll.update = EncounterJournal_LootUpdate
	self.encounter.info.lootScroll.scrollBar.doNotHide = true
	self.encounter.info.lootScroll.dynamic = EncounterJournal_LootCalcScroll
	HybridScrollFrame_CreateButtons(self.encounter.info.lootScroll, "EncounterItemTemplate", 0, 0)

	self.searchResults.scrollFrame.update = EncounterJournal_SearchUpdate
	self.searchResults.scrollFrame.scrollBar.doNotHide = true
	HybridScrollFrame_CreateButtons(self.searchResults.scrollFrame, "EncounterSearchLGTemplate", 0, 0)

	UIDropDownMenu_Initialize(self.encounter.info.lootScroll.lootFilter, EncounterJournal_InitLootFilter, "MENU")
	UIDropDownMenu_Initialize(self.encounter.info.lootScroll.lootSlotFilter, EncounterJournal_InitLootSlotFilter, "MENU")

	local instanceSelect = EncounterJournal.instanceSelect
	local tierName = EJ_GetTierInfo(EJ_GetCurrentTier())
	UIDropDownMenu_SetText(instanceSelect.tierDropDown, tierName)

	local dungeonInstanceID = EJ_GetInstanceByIndex(1, false)
	if( not dungeonInstanceID ) then
		instanceSelect.dungeonsTab.grayBox:Show()
	end
	local raidInstanceID = EJ_GetInstanceByIndex(1, true)
	if( not raidInstanceID ) then
		instanceSelect.raidsTab.grayBox:Show()
	end

	if C_Service:GetRealmID() then
		EncounterJournal_InitTab(self)
	else
		EncounterJournal_InitTab(self)
	end
end

function EncounterJournal_InitTab( self )
	self.tab1:SetFrameLevel(1)
	self.tab2:SetFrameLevel(1)

	self.maxTabWidth = (self:GetWidth() - 19) / 2

	if C_Service:IsLockRenegadeFeatures() then
		self.tab2:Hide()
		PanelTemplates_SetNumTabs(self, 1)
		return
	end

	PanelTemplates_SetNumTabs(self, 2)
end

function EncounterJournal_OnShow( self, ... )
	PanelTemplates_SetTab(self, 1)

	if not LOOTJOURNAL_CLASSFILTER or not LOOTJOURNAL_SPECFILTER then
		local _, _, classID = UnitClass("player")
		local specIndex = GetSpecializationIndex()
		local _, _, _, _, _, _, specNum = GetSpecializationInfoForClassID(classID, specIndex)

		LOOTJOURNAL_CLASSFILTER = classID
		LOOTJOURNAL_SPECFILTER = specNum

		LootJournal_GenerateLootData()
	end

	UpdateMicroButtons()
	PlaySound("igCharacterInfoOpen")
	EncounterJournal_LootUpdate()

	local instanceSelect = EncounterJournal.instanceSelect
	local instanceID = EJ_GetCurrentInstance()
	local _, instanceType, difficultyID = GetInstanceInfo()

	local tierData = EJ_TIER_DATA[EJ_GetCurrentTier()]
	instanceSelect.bg:SetTexture(tierData.backgroundTexture)
	instanceSelect.raidsTab.selectedGlow:SetVertexColor(tierData.r, tierData.g, tierData.b)
	instanceSelect.dungeonsTab.selectedGlow:SetVertexColor(tierData.r, tierData.g, tierData.b)

	EncounterJournal_ListInstances()

	EJ_SetSlotFilter(NO_INV_TYPE_FILTER)

	-- local name, type, difficulty, difficultyName, maxPlayers, playerDifficulty, isDynamicInstance = GetInstanceInfo()

	-- if EJ_IsValidInstanceDifficulty(difficulty) then
	-- 	EncounterJournal_UpdateDifficulty(difficulty)
	-- end

	EJ_ContentTab_Select(EncounterJournal.instanceSelect.selectedTab or 2)
	EncounterJournal_SetTab(1)

	if instanceID then
		EncounterJournal_ResetDisplay(instanceID, instanceType, difficultyID)
	end

	local index = 1
	local bossX, bossY, instanceID, name, description, encounterID = EJ_GetMapEncounter(index)

	if encounterID then
		local unitX, unitY = GetPlayerMapPosition("player")
		local dist = math.sqrt(math.pow(bossX - unitX, 2) + math.pow(bossY - unitY, 2))

		while encounterID do
			if dist < 0.13 then
				EncounterJournal_DisplayEncounter(encounterID, true)
				return
			end

			index = index + 1
			bossX, bossY, instanceID, name, description, encounterID = EJ_GetMapEncounter(index)

			bossX = bossX or 0
			bossY = bossY or 0
			dist = math.sqrt(math.pow(bossX - unitX, 2) + math.pow(bossY - unitY, 2))
		end
	end
end

function EncounterJournal_OnHide( self, ... )
	EJ_TIER_SELECTED = nil
	EJ_INSTANCE_SELECTED = nil

	LOOTJOURNAL_CLASSFILTER = nil
	LOOTJOURNAL_SPECFILTER = nil

	UpdateMicroButtons()

	self.searchBox:SetText("")

	EJ_ResetLootFilter()
	EJ_SetSlotFilter(NO_INV_TYPE_FILTER)

	PlaySound("igCharacterInfoClose")
end

function EncounterJournal_OnEvent( self, event, ... ) end

function EncounterJournal_UpdateDifficulty(newDifficultyID)
	for i = 1, #EJ_DIFFICULTIES do
		local entry = EJ_DIFFICULTIES[i]
		if entry.difficultyID == newDifficultyID then
			if EJ_IsValidInstanceDifficulty(entry.difficultyID) and (entry.size ~= "5" == EJ_IsRaid(EncounterJournal.instanceID)) then
				if entry.size ~= "5" then
					EncounterJournal.encounter.info.difficulty:SetFormattedText("(%s) %s", entry.size, entry.prefix)
				else
					EncounterJournal.encounter.info.difficulty:SetText(entry.prefix)
				end
				EncounterJournal_Refresh()
				break
			end
		end
	end
end

function EncounterJournal_Refresh(self)
	EncounterJournal_LootUpdate()

	if EncounterJournal.encounterID then
		EncounterJournal_DisplayEncounter(EncounterJournal.encounterID, true)
	elseif EncounterJournal.instanceID then
		EncounterJournal_DisplayInstance(EncounterJournal.instanceID, true)
	end
end

function EJ_ContentTab_OnClick( self, ... )
	EJ_ContentTab_Select(self:GetID())
end

function EJ_ContentTab_Select(id)
	local instanceSelect = EncounterJournal.instanceSelect
	id = id == 1 and 2 or id

	local selectedTab = nil
	for i = 1, #instanceSelect.Tabs do
		local tab = instanceSelect.Tabs[i]
		if ( tab:GetID() ~= id ) then
			tab:Enable()
			tab:GetFontString():SetTextColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
			tab.selectedGlow:Hide()
		else
			tab:GetFontString():SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
			tab:Disable()
			selectedTab = tab
		end
	end

	local tierData
	if ( id == instanceSelect.suggestTab.id ) then
		tierData = EJ_TIER_DATA[EJSuggestTab_GetPlayerTierIndex()]
	elseif id == instanceSelect.LootJournalTab:GetID() then
		tierData = EJ_TIER_DATA[1]
	else
		tierData = EJ_TIER_DATA[EJ_GetCurrentTier()]
	end
	selectedTab.selectedGlow:SetVertexColor(tierData.r, tierData.g, tierData.b)
	selectedTab.selectedGlow:Show()
	instanceSelect.bg:SetTexture(tierData.backgroundTexture)
	EncounterJournal.encounter:Hide()
	EncounterJournal.instanceSelect:Show()

	-- if ( id == instanceSelect.suggestTab:GetID() ) then
	-- 	EJ_HideInstances()
	-- 	EJ_HideLootJournalPanel()
	-- 	instanceSelect.scroll:Hide()
	-- 	EncounterJournal.suggestFrame:Show()
	-- 	if ( not instanceSelect.dungeonsTab.grayBox:IsShown() or not instanceSelect.raidsTab.grayBox:IsShown() ) then
	-- 		EncounterJournal_DisableTierDropDown(true)
	-- 	else
	-- 		EncounterJournal_EnableTierDropDown()
	-- 	end
	-- -- elseif ( id == instanceSelect.LootJournalTab.id ) then
	-- -- 	EJ_HideInstances()
	-- -- 	EJ_HideSuggestPanel()
	-- -- 	instanceSelect.scroll:Hide()
	-- -- 	EncounterJournal_DisableTierDropDown(true)
	-- -- 	EncounterJournal.LootJournal:Show()
	-- elseif ( id == instanceSelect.dungeonsTab:GetID() or id == instanceSelect.raidsTab:GetID() ) then
	-- 	EJ_HideNonInstancePanels()
	-- 	instanceSelect.scroll:Show()
	-- 	EncounterJournal_ListInstances()
	-- 	EncounterJournal_EnableTierDropDown()
	-- end

	if id == instanceSelect.dungeonsTab:GetID() or id == instanceSelect.raidsTab:GetID() then
		EJ_HideNonInstancePanels()
		instanceSelect.scroll:Show()
		EncounterJournal_ListInstances()
		EncounterJournal_EnableTierDropDown()
	elseif id == instanceSelect.LootJournalTab:GetID() then
		EJ_HideInstances()
		instanceSelect.scroll:Hide()
		EncounterJournal_DisableTierDropDown(true)
		EncounterJournal.LootJournal:Show()
	end

	instanceSelect.Tabs[1]:Enable()
	instanceSelect.Tabs[1].grayBox:Show()

	EncounterJournal.instanceSelect.selectedTab = id

	PlaySound("igMainMenuOptionCheckBoxOn")
end

function EncounterJournal_DisableTierDropDown(removeText)
	UIDropDownMenu_DisableDropDown(EncounterJournal.instanceSelect.tierDropDown)
	if ( removeText ) then
		UIDropDownMenu_SetText(EncounterJournal.instanceSelect.tierDropDown, nil)
	else
		local tierName = EJ_GetTierInfo(EJ_GetCurrentTier())
		UIDropDownMenu_SetText(EncounterJournal.instanceSelect.tierDropDown, tierName)
	end
end

function EncounterJournal_EnableTierDropDown()
	local tierName = EJ_GetTierInfo(EJ_GetCurrentTier())
	UIDropDownMenu_SetText(EncounterJournal.instanceSelect.tierDropDown, tierName)
	UIDropDownMenu_EnableDropDown(EncounterJournal.instanceSelect.tierDropDown)
end

function EJTierDropDown_Initialize( self, level, ... )
	local info = UIDropDownMenu_CreateInfo()
	local numTiers = EJ_GetNumTiers()
	local currTier = EJ_GetCurrentTier()
	for i=1, numTiers do
		info.text = EJ_GetTierInfo(i)
		info.func = EncounterJournal_TierDropDown_Select
		info.checked = i == currTier
		info.arg1 = i
		UIDropDownMenu_AddButton(info, level)
	end
end

function EncounterJournal_TierDropDown_Select( _, tier, ... )
	EJ_SelectTier(tier)

	local instanceSelect = EncounterJournal.instanceSelect
	instanceSelect.dungeonsTab.grayBox:Hide()
	instanceSelect.raidsTab.grayBox:Hide()

	local tierData = EJ_TIER_DATA[tier]
	instanceSelect.bg:SetTexture(tierData.backgroundTexture)
	instanceSelect.raidsTab.selectedGlow:SetVertexColor(tierData.r, tierData.g, tierData.b)
	instanceSelect.dungeonsTab.selectedGlow:SetVertexColor(tierData.r, tierData.g, tierData.b)

	UIDropDownMenu_SetText(instanceSelect.tierDropDown, EJ_GetTierInfo(EJ_GetCurrentTier()))

	EncounterJournal_ListInstances()
end

local infiniteLoopPolice = false
function EncounterJournal_ListInstances()
	local instanceSelect = EncounterJournal.instanceSelect

	local tierName = EJ_GetTierInfo(EJ_GetCurrentTier())
	UIDropDownMenu_SetText(instanceSelect.tierDropDown, tierName)
	NavBar_Reset(EncounterJournal.navBar)
	EncounterJournal.encounter:Hide()
	instanceSelect:Show()
	local showRaid = instanceSelect.raidsTab:IsEnabled() ~= 1

	local scrollFrame = instanceSelect.scroll.child
	local index = 1
	local instanceID, name, description, _, buttonImage, _, _, _, link = EJ_GetInstanceByIndex(index, showRaid)

	if not instanceID and not infiniteLoopPolice then
		infiniteLoopPolice = true
		if ( showRaid ) then
			instanceSelect.raidsTab.grayBox:Show()
			EJ_ContentTab_Select(instanceSelect.dungeonsTab:GetID())
		else
			instanceSelect.dungeonsTab.grayBox:Show()
			EJ_ContentTab_Select(instanceSelect.raidsTab:GetID())
		end
		return
	end
	infiniteLoopPolice = false

	while instanceID do
		local instanceButton = scrollFrame["instance"..index]
		if not instanceButton then
			instanceButton = CreateFrame("BUTTON", scrollFrame:GetParent():GetName().."instance"..index, scrollFrame, "EncounterInstanceButtonTemplate")
			if ( EncounterJournal.localizeInstanceButton ) then
				EncounterJournal.localizeInstanceButton(instanceButton)
			end
			scrollFrame["instance"..index] = instanceButton
			if mod(index-1, EJ_NUM_INSTANCE_PER_ROW) == 0 then
				instanceButton:SetPoint("TOP", scrollFrame["instance"..(index-EJ_NUM_INSTANCE_PER_ROW)], "BOTTOM", 0, -15)
			else
				instanceButton:SetPoint("LEFT", scrollFrame["instance"..(index-1)], "RIGHT", 15, 0)
			end
		end

		instanceButton.name:SetText(name)
		instanceButton.bgImage:SetTexture(buttonImage)
		instanceButton.instanceID = instanceID
		instanceButton.tooltipTitle = name
		instanceButton.tooltipText = description
		instanceButton.link = link
		instanceButton:Show()

		index = index + 1
		instanceID, name, description, _, buttonImage, _, _, _, link = EJ_GetInstanceByIndex(index, showRaid)
	end

	EJ_HideInstances(index)

	local instanceText = EJ_GetInstanceByIndex(1, not showRaid)
	if not instanceText then
		if ( showRaid ) then
			instanceSelect.dungeonsTab.grayBox:Show()
		else
			instanceSelect.raidsTab.grayBox:Show()
		end
	end
end

function EncounterJournal_HasChangedContext(instanceID, instanceType, difficultyID)
	if ( instanceType == "none" ) then
		return EncounterJournal.lastInstance ~= nil
	elseif ( instanceID ~= 0 and (instanceID ~= EncounterJournal.lastInstance or EncounterJournal.lastDifficulty ~= difficultyID) ) then
		return true
	end
	return false
end

function EncounterJournal_ResetDisplay(instanceID, instanceType, difficultyID)
	if ( instanceType == "none" ) then
		EncounterJournal.lastInstance = nil
		EncounterJournal.lastDifficulty = nil
		-- EJSuggestFrame_OpenFrame()
	else
		EJ_ContentTab_Select(EncounterJournal.instanceSelect.dungeonsTab:GetID())

		EncounterJournal_DisplayInstance(instanceID)
		EncounterJournal.lastInstance = instanceID
		if ( EJ_IsValidInstanceDifficulty(difficultyID) ) then
			EJ_SetDifficulty(difficultyID)
		end
		EncounterJournal.lastDifficulty = difficultyID
	end
end

function EncounterJournal_TabClicked(self, button)
	local tabType = self:GetID()
	EncounterJournal_SetTab(tabType)
	PlaySound("igAbiliityPageTurn")
end

function EncounterJournal_SetTab(tabType)
	local info = EncounterJournal.encounter.info
	info.tab = tabType

	for key, data in pairs(EJ_Tabs) do
		if key == tabType then
			info[data.frame]:Show()
			info[data.button].selected:Show()
			info[data.button].unselected:Hide()
			info[data.button]:LockHighlight()
		else
			info[data.frame]:Hide()
			info[data.button].selected:Hide()
			info[data.button].unselected:Show()
			info[data.button]:UnlockHighlight()
		end
	end

	UpdateDifficultyVisibility()
end

function EJNAV_RefreshInstance()
	EncounterJournal_DisplayInstance(EncounterJournal.instanceID, true)
end

function EJNAV_SelectInstance(self, index, navBar)
	local instanceID = EJ_GetInstanceByIndex(index, EJ_InstanceIsRaid())

	NavBar_Reset(navBar)
	EncounterJournal_DisplayInstance(instanceID)
end

function EJNAV_ListInstance(self, index)
	local _, name = EJ_GetInstanceByIndex(index, EJ_InstanceIsRaid())
	return name, EJNAV_SelectInstance
end

function EncounterJournal_DisplayInstance( instanceID, noButton )
	EJ_ResetLootFilter()
	EJ_SetSlotFilter(NO_INV_TYPE_FILTER)
	EncounterJournal_RefreshSlotFilterText()

	EJ_HideNonInstancePanels()

	EncounterJournal.encounter.info.overviewTab:Click()

	local self = EncounterJournal.encounter
	EncounterJournal.instanceSelect:Hide()
	EncounterJournal.encounter:Show()
	EncounterJournal.ceatureDisplayID = 0

	EncounterJournal.instanceID = instanceID
	EncounterJournal.encounterID = nil

	EJ_SelectInstance(instanceID)
	EncounterJournal_LootUpdate()
	EncounterJournal_ClearDetails()

	local iname, description, bgImage, loreImage, buttonImage, dungeonAreaMapID = EJ_GetInstanceInfo()
	self.instance.title:SetText(iname)
	self.instance.titleBG:SetWidth(self.instance.title:GetStringWidth() + 80)
	self.instance.loreBG:SetTexture(loreImage)
	self.info.TitleFrame.instanceTitle:SetText(iname)
	self.instance.mapButton:SetShown(dungeonAreaMapID and dungeonAreaMapID > 0)
	self.instance.mapButton.dungeonAreaMapID = dungeonAreaMapID

	self.instance.loreScroll.child.lore:SetText(description)
	local loreHeight = self.instance.loreScroll.child.lore:GetHeight()
	self.instance.loreScroll.ScrollBar:SetValue(0)
	if loreHeight <= EJ_LORE_MAX_HEIGHT then
		self.instance.loreScroll.ScrollBar:Hide()
	else
		self.instance.loreScroll.ScrollBar:Show()
	end

	self.info.instanceButton.instanceID = instanceID
	-- self.info.instanceButton.icon:SetMask("Interface\\CharacterFrame\\TempPortraitAlphaMask")
	-- self.info.instanceButton.icon:SetTexture(buttonImage)

	self.info.model.dungeonBG:SetTexture(bgImage)

	UpdateDifficultyVisibility()

	local bossIndex = 1
	local name, description, bossID, rootSectionID, link = EJ_GetEncounterInfoByIndex(bossIndex)
	local bossButton
	local hasBossAbilities = false

	EncounterJournal.encounterList = {}

	while bossID do
		bossButton = _G["EncounterJournalBossButton"..bossIndex]
		if not bossButton then
			bossButton = CreateFrame("BUTTON", "EncounterJournalBossButton"..bossIndex, EncounterJournal.encounter.bossesFrame, "EncounterBossButtonTemplate")
			if bossIndex > 1 then
				bossButton:SetPoint("TOPLEFT", _G["EncounterJournalBossButton"..(bossIndex-1)], "BOTTOMLEFT", 0, -15)
			else
				bossButton:SetPoint("TOPLEFT", EncounterJournal.encounter.bossesFrame, "TOPLEFT", 0, -10)
			end
		end

		bossButton:SetText(name)
		bossButton:Show()
		bossButton.encounterID = bossID
		bossButton.link = link

		local _, _, _, bossDisplay, bossImage = EJ_GetCreatureInfo(1, bossID)
		bossImage = bossImage or "Interface\\EncounterJournal\\UI-EJ-BOSS-Default"
		-- No hand-made boss portrait .blp? Render one from the creature display id
		-- (custom bosses otherwise show the red "?" default icon).
		if bossImage == "Interface\\EncounterJournal\\UI-EJ-BOSS-Default"
			and bossDisplay and bossDisplay > 0 and bossButton.creature.SetPortrait then
			bossButton.creature:SetPortrait(bossDisplay)
		else
			bossButton.creature:SetTexture(bossImage)
		end
		bossButton:UnlockHighlight()
		if ( not hasBossAbilities ) then
			hasBossAbilities = rootSectionID > 0
		end

		table.insert(EncounterJournal.encounterList, bossID)

		bossIndex = bossIndex + 1
		name, description, bossID, rootSectionID, link = EJ_GetEncounterInfoByIndex(bossIndex)
	end

	EncounterJournal_SetTabEnabled(EncounterJournal.encounter.info.overviewTab, true)
	EncounterJournal_SetTabEnabled(EncounterJournal.encounter.info.modelTab, false)
	EncounterJournal_SetTabEnabled(EncounterJournal.encounter.info.bossTab, false)

	if (EncounterJournal_SearchForOverview(instanceID)) then
		EJ_Tabs[1].frame = "overviewScroll"
		EJ_Tabs[3].frame = "detailsScroll"
		self.info[EJ_Tabs[1].button].tooltip = OVERVIEW
		self.info[EJ_Tabs[3].button]:Show()
		self.info[EJ_Tabs[4].button]:SetPoint("TOP", self.info[EJ_Tabs[3].button], "BOTTOM", 0, 2)
		self.info.overviewFound = true
	else
		EJ_Tabs[1].frame = "detailsScroll"
		EJ_Tabs[3].frame = "overviewScroll"
		if ( hasBossAbilities ) then
			self.info[EJ_Tabs[1].button].tooltip = ABILITIES
		else
			self.info[EJ_Tabs[1].button].tooltip = OVERVIEW
		end
		self.info[EJ_Tabs[3].button]:Hide()
		self.info[EJ_Tabs[4].button]:SetPoint("TOP", self.info[EJ_Tabs[2].button], "BOTTOM", 0, 2)
		self.info.overviewFound = false
	end

	self.instance:Show()
	self.info.overviewScroll:Hide()
	self.info.detailsScroll:Hide()
	self.info.lootScroll:Hide()
	self.info.rightShadow:Hide()

	if (self.info.tab and self.info.tab < 3) then
		self.info[EJ_Tabs[self.info.tab].button]:Click()
	else
		self.info.overviewTab:Click()
	end

	if not noButton then
		local buttonData = {
			id = instanceID,
			name = iname,
			OnClick = EJNAV_RefreshInstance,
			listFunc = EJNAV_ListInstance,
		}
		NavBar_AddButton(EncounterJournal.navBar, buttonData)
	end
end

function EncounterJournal_SetTabEnabled(tab, enabled)
	tab:SetEnabled(enabled)
	tab:GetDisabledTexture():SetDesaturated(not enabled)
	tab.unselected:SetDesaturated(not enabled)
end

function EncounterJournalInstanceButton_OnClick( self, ... )
	CloseDropDownMenus()
	NavBar_Reset(EncounterJournal.navBar)
	EncounterJournal_DisplayInstance(EncounterJournal.instanceID)
end

function EncounterJournal_CheckForOverview(rootSectionID)
	return select(3, EJ_GetSectionInfo(rootSectionID)) == EJ_HTYPE_OVERVIEW
end

function EncounterJournal_SearchForOverview(instanceID)
	local bossIndex = 1
	local _, _, bossID = EJ_GetEncounterInfoByIndex(bossIndex)
	while bossID do
		local _, _, _, rootSectionID = EJ_GetEncounterInfo(bossID)

		if (EncounterJournal_CheckForOverview(rootSectionID)) then
			return true
		end

		bossIndex = bossIndex + 1
		_, _, bossID = EJ_GetEncounterInfoByIndex(bossIndex)
	end

	return false
end

function EncounterJournal_ClearDetails()
	EncounterJournal.encounter.instance:Hide()
	EncounterJournal.encounter.infoFrame.description:SetText("")
	EncounterJournal.encounter.info.TitleFrame.encounterTitle:SetText("")

	EncounterJournal.encounter.info.overviewScroll.ScrollBar:SetValue(0)
	EncounterJournal.encounter.info.lootScroll.scrollBar:SetValue(0)
	EncounterJournal.encounter.info.detailsScroll.ScrollBar:SetValue(0)
	EncounterJournal.encounter.info.bossesScroll.ScrollBar:SetValue(0)

	local freeHeaders = EncounterJournal.encounter.freeHeaders
	local usedHeaders = EncounterJournal.encounter.usedHeaders

	for key, used in pairs(usedHeaders) do
		used:Hide()
		usedHeaders[key] = nil
		freeHeaders[#freeHeaders+1] = used
	end

	local creatures = EncounterJournal.encounter.info.creatureButtons
	for i=1, #creatures do
		creatures[i]:Hide()
		creatures[i].displayInfo = nil
	end

	local bossIndex = 1
	local bossButton = _G["EncounterJournalBossButton"..bossIndex]
	while bossButton do
		bossButton:Hide()
		bossIndex = bossIndex + 1
		bossButton = _G["EncounterJournalBossButton"..bossIndex]
	end

	-- EncounterJournal.searchResults:Hide()
	-- EncounterJournal_HideSearchPreview()
	-- EncounterJournal.searchBox:ClearFocus()
end

function EncounterJournal_GetRootAfterOverviews(rootSectionID)
	local nextSectionID = rootSectionID

	local headerType, siblingID, _

	repeat
		_, _, headerType, _, _, siblingID = EJ_GetSectionInfo(nextSectionID)
		if (headerType == EJ_HTYPE_OVERVIEW) then
			nextSectionID = siblingID
		end
	until headerType ~= EJ_HTYPE_OVERVIEW

	return nextSectionID
end

function EncounterJournal_DisplayEncounter(encounterID, noButton)
	if encounterID == -1 then
		return
	end

	local self = EncounterJournal.encounter
	local ename, description, _, rootSectionID, link, instanceID = EJ_GetEncounterInfo(encounterID)

	if EncounterJournal.encounterID == encounterID or EncounterJournal.instanceID == instanceID then
		EncounterJournal_SetTab(EncounterJournal.encounter.info.tab)
	else
		EncounterJournal_SetTab(1)
	end

	if rootSectionID == 0 then
		EncounterJournal_SetTab(EncounterJournal.encounter.info.lootTab:GetID())
	end

	if (EncounterJournal.encounterID == encounterID) then
		noButton = true
	elseif (EncounterJournal.encounterID) then
		NavBar_OpenTo(EncounterJournal.navBar, EncounterJournal.instanceID)
	end

	EncounterJournal.encounterID = encounterID
	-- EJ_SelectEncounter(encounterID)
	EncounterJournal_LootUpdate()

	local bossListScrollValue = self.info.bossesScroll.ScrollBar:GetValue()
	EncounterJournal_ClearDetails()
	EncounterJournal.encounter.info.bossesScroll.ScrollBar:SetValue(bossListScrollValue)

	self.info.TitleFrame.encounterTitle:SetText(ename)

	EncounterJournal_SetTabEnabled(EncounterJournal.encounter.info.overviewTab, (rootSectionID > 0))

	local overviewFound
	if (EncounterJournal_CheckForOverview(rootSectionID)) then
		local _, overviewDescription = EJ_GetSectionInfo(rootSectionID)
		self.overviewFrame.loreDescription:SetHeight(0)
		self.overviewFrame.loreDescription:SetWidth(self.overviewFrame:GetWidth() - 5)
		self.overviewFrame.loreDescription:SetText(description)
		self.overviewFrame.overviewDescription:SetWidth(self.overviewFrame:GetWidth() - 5)
		self.overviewFrame.overviewDescription.Text:SetWidth(self.overviewFrame:GetWidth() - 5)
		EncounterJournal_SetBullets(self.overviewFrame.overviewDescription, overviewDescription, false)
		local bulletHeight = 0
		if (self.overviewFrame.Bullets and #self.overviewFrame.Bullets > 0) then
			for i = 1, #self.overviewFrame.Bullets do
				bulletHeight = bulletHeight + self.overviewFrame.Bullets[i]:GetHeight()
			end
			local bullet = self.overviewFrame.Bullets[1]
			bullet:ClearAllPoints()
			bullet:SetPoint("TOPLEFT", self.overviewFrame.overviewDescription, "BOTTOMLEFT", 0, -9)
		end
		self.overviewFrame.descriptionHeight = self.overviewFrame.loreDescription:GetHeight() + self.overviewFrame.overviewDescription:GetHeight() + bulletHeight + 42
		self.overviewFrame.rootOverviewSectionID = rootSectionID
		rootSectionID = EncounterJournal_GetRootAfterOverviews(rootSectionID)
		overviewFound = true
	end

	self.infoFrame.description:SetWidth(self.infoFrame:GetWidth() -5)
	self.infoFrame.description:SetText(description)
	self.infoFrame.descriptionHeight = self.infoFrame.description:GetHeight()

	self.infoFrame.encounterID = encounterID
	self.infoFrame.rootSectionID = rootSectionID
	self.infoFrame.expanded = false

	EncounterJournal.encounterList = {}

	local bossIndex = 1
	local name, description, bossID, _, link = EJ_GetEncounterInfoByIndex(bossIndex)
	local bossButton
	while bossID do
		bossButton = _G["EncounterJournalBossButton"..bossIndex]
		if not bossButton then
			bossButton = CreateFrame("BUTTON", "EncounterJournalBossButton"..bossIndex, EncounterJournal.encounter.bossesFrame, "EncounterBossButtonTemplate")
			if bossIndex > 1 then
				bossButton:SetPoint("TOPLEFT", _G["EncounterJournalBossButton"..(bossIndex-1)], "BOTTOMLEFT", 0, -15)
			else
				bossButton:SetPoint("TOPLEFT", EncounterJournal.encounter.bossesFrame, "TOPLEFT", 0, -10)
			end
		end

		bossButton.link = link
		bossButton:SetText(name)
		bossButton:Show()
		bossButton.encounterID = bossID

		local _, _, _, bossDisplay, bossImage = EJ_GetCreatureInfo(1, bossID)
		bossImage = bossImage or "Interface\\EncounterJournal\\UI-EJ-BOSS-Default"
		-- No hand-made boss portrait .blp? Render one from the creature display id
		-- (custom bosses otherwise show the red "?" default icon).
		if bossImage == "Interface\\EncounterJournal\\UI-EJ-BOSS-Default"
			and bossDisplay and bossDisplay > 0 and bossButton.creature.SetPortrait then
			bossButton.creature:SetPortrait(bossDisplay)
		else
			bossButton.creature:SetTexture(bossImage)
		end

		if (encounterID == bossID) then
			bossButton:LockHighlight()
		else
			bossButton:UnlockHighlight()
		end

		table.insert(EncounterJournal.encounterList, bossID)

		bossIndex = bossIndex + 1
		name, description, bossID, _, link = EJ_GetEncounterInfoByIndex(bossIndex)
	end

	local id, name, displayInfo, iconImage
	for i= 1, MAX_CREATURES_PER_ENCOUNTER do
		id, name, description, displayInfo, iconImage, creatureEntry = EJ_GetCreatureInfo(i)
		if id then
			local button = EncounterJournal_GetCreatureButton(i)
			-- SetPortraitTexture(button.creature, displayInfo)
			button.creature:SetPortrait(displayInfo)
			button.name = name
			button.id = id
			button.description = description
			button.displayInfo = creatureEntry
		end
	end

	EncounterJournal_SetTabEnabled(EncounterJournal.encounter.info.modelTab, true)
	EncounterJournal_SetTabEnabled(EncounterJournal.encounter.info.bossTab, true)

	if (overviewFound) then
		EncounterJournal_ToggleHeaders(self.overviewFrame)
		self.overviewFrame:Show()
	else
		self.overviewFrame:Hide()
	end

	EncounterJournal_ToggleHeaders(self.infoFrame)

	self:Show()

	self.info[EJ_Tabs[self.info.tab].button]:Click()

	if not noButton then
		local buttonData = {
			id = encounterID,
			name = ename,
			OnClick = EJNAV_RefreshEncounter,
			listFunc = EJNAV_ListEncounter,
		}
		NavBar_AddButton(EncounterJournal.navBar, buttonData)
	end
end

function EJNAV_RefreshEncounter()
	EncounterJournal_DisplayInstance(EncounterJournal.encounterID)
end

function EJNAV_ListEncounter(self, index)
	local name = EJ_GetEncounterInfoByIndex(index)
	return name, EJNAV_SelectEncounter
end

function EJNAV_SelectEncounter(self, index, navBar)
	local _, _, bossID = EJ_GetEncounterInfoByIndex(index)
	EncounterJournal_DisplayEncounter(bossID)
end

function EncounterJournal_GetCreatureButton(index)
	if index > MAX_CREATURES_PER_ENCOUNTER then
		return nil
	end

	local self = EncounterJournal.encounter.info
	local button = self.creatureButtons[index]
	if (not button) then
		button = CreateFrame("BUTTON", nil, self, "EncounterCreatureButtonTemplate")
		button:SetPoint("TOPLEFT", self.creatureButtons[index-1], "BOTTOMLEFT", 0, 8)
		self.creatureButtons[index] = button
	end
	return button
end

local toggleTempList = {}
local headerCount = 0

function EncounterJournal_ToggleHeaders(self, doNotShift)
	local numAdded = 0
	local infoHeader, parentID, _
	local hWidth = self:GetWidth()
	local nextSectionID
	local topLevelSection = false

	local isOverview = self.isOverview

	local hideHeaders
	if (not self.isOverview or (self.isOverview and self.overviewIndex)) then
		self.expanded = not self.expanded
		hideHeaders = not self.expanded
	end

	if hideHeaders then
		self.button.expandedIcon:SetText("+")
		self.description:Hide()
		if (self.overviewDescription) then
			self.overviewDescription:Hide()
		end
		self.descriptionBG:Hide()
		self.descriptionBGBottom:Hide()

		EncounterJournal_CleanBullets(self, nil, true)

		if (self.overviewIndex) then
			local overview = EncounterJournal.encounter.overviewFrame.overviews[self.overviewIndex + 1]

			if (overview) then
				overview:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -9)
			end
		else
			EncounterJournal_ClearChildHeaders(self)
		end
	else
		if (not isOverview) then
			if strlen(self.description:GetText() or "") > 2 then
				self.description:Show()
				if (self.overviewDescription) then
					self.overviewDescription:Hide()
				end
				if self.button then
					self.descriptionBG:Show()
					self.descriptionBGBottom:Show()
					self.button.expandedIcon:SetText("-")
				end
			elseif self.button then
				self.description:Hide()
				if (self.overviewDescription) then
					self.overviewDescription:Hide()
				end
				self.descriptionBG:Hide()
				self.descriptionBGBottom:Hide()
				self.button.expandedIcon:SetText("-")
			end
		else
			if (self.overviewIndex) then
				self.button.expandedIcon:SetText("-")
				for i = 1, #self.Bullets do
					self.Bullets[i]:Show()
				end
				self.description:Hide()
				self.overviewDescription:Show()
				self.descriptionBG:Show()
				self.descriptionBGBottom:Show()

				local overview = EncounterJournal.encounter.overviewFrame.overviews[self.overviewIndex + 1]

				if (overview) then
					if (self.Bullets and #self.Bullets > 0) then
						overview:SetPoint("TOPLEFT", self.Bullets[#self.Bullets], "BOTTOMLEFT", -13, -18)
					else
						local yoffset = -18 - self:GetHeight()
						overview:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, yoffset)
					end
				end
				EncounterJournal_UpdateButtonState(self.button)
			end
		end

		if (not isOverview) then
			local freeHeaders = EncounterJournal.encounter.freeHeaders
			local usedHeaders = EncounterJournal.encounter.usedHeaders

			local listEnd = #usedHeaders

			if self.myID then
				_, _, _, _, _, _, nextSectionID =  EJ_GetSectionInfo(self.myID)
				parentID = self.myID
				self.description:SetWidth(self:GetWidth() -20)
				hWidth = hWidth - HEADER_INDENT
			else
				parentID = self.encounterID
				nextSectionID = self.rootSectionID
				topLevelSection = true
			end

			while nextSectionID do
				local title, description, headerType, abilityIcon, displayInfo, siblingID, _, fileredByDifficulty, link, startsOpen, creatureEntry, flag1, flag2, flag3, flag4 = EJ_GetSectionInfo(nextSectionID)
				if not title then
					break
				elseif not fileredByDifficulty then
					if #freeHeaders == 0 then
						headerCount = headerCount + 1
						infoHeader = CreateFrame("FRAME", "EncounterJournalInfoHeader"..headerCount, EncounterJournal.encounter.infoFrame, "EncounterInfoTemplate")
						infoHeader:Hide()
					else
						infoHeader = freeHeaders[#freeHeaders]
						freeHeaders[#freeHeaders] = nil
					end

					numAdded = numAdded + 1
					toggleTempList[#toggleTempList+1] = infoHeader

					infoHeader.button.link = link
					infoHeader.parentID = parentID
					infoHeader.myID = nextSectionID

					description = description:gsub("\|cffffffff(.-)\|r", "%1")

                    description = EncounterJournal_ParseDifficultyMacros(description);

					infoHeader.description:SetText(description)
					infoHeader.button.title:SetText(title)
					if topLevelSection then
						infoHeader.button.title:SetFontObject("GameFontNormalMed3")
					else
						infoHeader.button.title:SetFontObject("GameFontNormal")
					end

					infoHeader.expanded = false
					infoHeader.description:Hide()
					infoHeader.descriptionBG:Hide()
					infoHeader.descriptionBGBottom:Hide()
					infoHeader.button.expandedIcon:SetText("+")

					for i = 1, #infoHeader.Bullets do
						infoHeader.Bullets[i]:Hide()
					end

					local textLeftAnchor = infoHeader.button.expandedIcon
					if abilityIcon then
						infoHeader.button.abilityIcon:SetTexture(abilityIcon)
						infoHeader.button.abilityIcon:Show()
						textLeftAnchor = infoHeader.button.abilityIcon
					else
						infoHeader.button.abilityIcon:Hide()
					end

					if displayInfo ~= 0 then
						-- SetPortraitTexture(infoHeader.button.portrait.icon, displayInfo)
						infoHeader.button.portrait.icon:SetPortrait(displayInfo)
						infoHeader.button.portrait.name = title
						infoHeader.button.portrait.displayInfo = creatureEntry
						infoHeader.button.portrait:Show()
						textLeftAnchor = infoHeader.button.portrait
						infoHeader.button.abilityIcon:Hide()
					else
						infoHeader.button.portrait:Hide()
						infoHeader.button.portrait.name = nil
						infoHeader.button.portrait.displayInfo = nil
					end
					infoHeader.button.title:SetPoint("LEFT", textLeftAnchor, "RIGHT", 5, 0)

					local textRightAnchor = nil
					infoHeader.button.icon1:Hide()
					infoHeader.button.icon2:Hide()
					infoHeader.button.icon3:Hide()
					infoHeader.button.icon4:Hide()
					if flag1 then
						textRightAnchor = infoHeader.button.icon1
						infoHeader.button.icon1:Show()
						infoHeader.button.icon1.tooltipTitle = _G["ENCOUNTER_JOURNAL_SECTION_FLAG"..flag1]
						infoHeader.button.icon1.tooltipText = _G["ENCOUNTER_JOURNAL_SECTION_FLAG_DESCRIPTION"..flag1]
						EncounterJournal_SetFlagIcon(infoHeader.button.icon1.icon, flag1)
						if flag2 then
							textRightAnchor = infoHeader.button.icon2
							infoHeader.button.icon2:Show()
							EncounterJournal_SetFlagIcon(infoHeader.button.icon2.icon, flag2)
							infoHeader.button.icon2.tooltipTitle = _G["ENCOUNTER_JOURNAL_SECTION_FLAG"..flag2]
							infoHeader.button.icon2.tooltipText = _G["ENCOUNTER_JOURNAL_SECTION_FLAG_DESCRIPTION"..flag2]
							if flag3 then
								textRightAnchor = infoHeader.button.icon3
								infoHeader.button.icon3:Show()
								EncounterJournal_SetFlagIcon(infoHeader.button.icon3.icon, flag3)
								infoHeader.button.icon3.tooltipTitle = _G["ENCOUNTER_JOURNAL_SECTION_FLAG"..flag3]
								infoHeader.button.icon3.tooltipText = _G["ENCOUNTER_JOURNAL_SECTION_FLAG_DESCRIPTION"..flag3]
								if flag4 then
									textRightAnchor = infoHeader.button.icon4
									infoHeader.button.icon4:Show()
									EncounterJournal_SetFlagIcon(infoHeader.button.icon4.icon, flag4)
									infoHeader.button.icon4.tooltipTitle = _G["ENCOUNTER_JOURNAL_SECTION_FLAG"..flag4]
									infoHeader.button.icon4.tooltipText = _G["ENCOUNTER_JOURNAL_SECTION_FLAG_DESCRIPTION"..flag4]
								end
							end
						end
					end
					if textRightAnchor then
						infoHeader.button.title:SetPoint("RIGHT", textRightAnchor, "LEFT", -5, 0)
					else
						infoHeader.button.title:SetPoint("RIGHT", infoHeader.button, "RIGHT", -5, 0)
					end

					infoHeader.index = nil
					infoHeader:SetWidth(hWidth)


					if EJ_section_openTable[infoHeader.myID] == nil and startsOpen then
						EJ_section_openTable[infoHeader.myID] = true
					end

					if EJ_section_openTable[infoHeader.myID]  then
						infoHeader.expanded = false
						numAdded = numAdded + EncounterJournal_ToggleHeaders(infoHeader, true)
					end

					infoHeader:Show()
				end
				nextSectionID = siblingID
			end

			if not doNotShift and numAdded > 0 then
				local startIndex = self.index or 0
				for i=listEnd,startIndex+1,-1 do
					usedHeaders[i+numAdded] = usedHeaders[i]
					usedHeaders[i+numAdded].index = i + numAdded
					usedHeaders[i] = nil
				end
				for i=1,numAdded do
					usedHeaders[startIndex + i] = toggleTempList[i]
					usedHeaders[startIndex + i].index = startIndex + i
					toggleTempList[i] = nil
				end
			end

			if topLevelSection and usedHeaders[1] then
				usedHeaders[1]:SetPoint("TOPRIGHT", 0 , -8 - EncounterJournal.encounter.infoFrame.descriptionHeight - SECTION_BUTTON_OFFSET)
			end
		elseif (not self.overviewIndex) then
			for i = 1, #self.overviews do
				self.overviews[i]:Hide()
			end

			EncounterJournal.overviewDefaultRole = nil

			if (not self.rootOverviewSectionID) then
				return
			end

			local spec, role

			-- spec = GetSpecialization()
			-- if (spec) then
			-- 	role = GetSpecializationRole(spec)
			-- else
			-- 	role = "DAMAGER"
			-- end

			role = "DAMAGER"

			EncounterJournal_SetUpOverview(self, role, 1)

			local k = 2
			for i = 1, 3 do
				local otherRole = overviewPriorities[i]
				if (otherRole ~= role) then
					EncounterJournal_SetUpOverview(self, otherRole, k)
					k = k + 1
				end
			end

			if (self.linkSection) then
				for i = 1, 3 do
					local overview = self.overviews[i]
					if (overview.sectionID == self.linkSection) then
						overview.expanded = false
							EncounterJournal_ToggleHeaders(overview)
						overview.cbCount = 0
						overview.button.glow.flashAnim:Play()
						overview:SetScript("OnUpdate", EncounterJournal_FocusSectionCallback)
					else
						overview.expanded = true
							EncounterJournal_ToggleHeaders(overview)
						overview.button.glow.flashAnim:Stop()
						overview:SetScript("OnUpdate", nil)
					end
				end
				self.linkSection = nil
			else
				self.overviews[1].expanded = false
				EncounterJournal.overviewDefaultRole = role
				EncounterJournal_ToggleHeaders(self.overviews[1])
			end
		end
	end

	if (not isOverview) then
		if self.myID then
			EJ_section_openTable[self.myID] = self.expanded
		end

		if not doNotShift then
			EncounterJournal_ShiftHeaders(self.index or 1)

			if self.index then
				local scrollValue = EncounterJournal.encounter.info.detailsScroll.ScrollBar:GetValue()
				local cutoff = EncounterJournal.encounter.info.detailsScroll:GetHeight() + scrollValue

				local _, _, _, _, anchorY = self:GetPoint()
				anchorY = anchorY - self:GetHeight()
				if self.description:IsShown() then
					anchorY = anchorY - self.description:GetHeight() - SECTION_DESCRIPTION_OFFSET
				end

				if cutoff < abs(anchorY) then
					self.frameCount = 0
					self:SetScript("OnUpdate", EncounterJournal_MoveSectionUpdate)
				end
			end
		end
		return numAdded
	else
		return 0
	end
end

function EncounterJournal_SetFlagIcon(texture, index)
	local iconSize = 32
	local columns = 256/iconSize
	local rows = 64/iconSize

	if (index == 12) then
		index = 3
	end

	local l = mod(index, columns) / columns
	local r = l + (1/columns)
	local t = floor(index/columns) / rows
	local b = t + (1/rows)

	texture:SetTexCoord(l,r,t,b)
end

function EncounterJournal_CleanBullets(self, start, keep)
	if (not self.Bullets) then return end
    start = start or 1
	for i = start, #self.Bullets do
		self.Bullets[i]:Hide()
		if (not keep) then
			if (not self.BulletCache) then
				self.BulletCache = {}
			end
			self.Bullets[i]:ClearAllPoints()
			tinsert(self.BulletCache, self.Bullets[i])
			self.Bullets[i] = nil
		end
	end
end

function EncounterJournal_ClearChildHeaders(self, doNotShift)
	local usedHeaders = EncounterJournal.encounter.usedHeaders
	local freeHeaders = EncounterJournal.encounter.freeHeaders
	local numCleared = 0
	for key,header in pairs(usedHeaders) do
		if header.parentID == self.myID then
			if header.expanded then
				numCleared = numCleared + EncounterJournal_ClearChildHeaders(header, true)
			end
			header:Hide()
			usedHeaders[key] = nil
			freeHeaders[#freeHeaders+1] = header
			numCleared = numCleared + 1
		end
	end

	if numCleared > 0 and not doNotShift then
		local placeIndex = self.index + 1
		local shiftHeader = usedHeaders[placeIndex + numCleared]
		while shiftHeader do
			usedHeaders[placeIndex] = shiftHeader
			usedHeaders[placeIndex].index = placeIndex
			usedHeaders[placeIndex + numCleared] = nil
			placeIndex = placeIndex + 1
			shiftHeader = usedHeaders[placeIndex + numCleared]
		end
	end
	return numCleared
end

function EncounterJournal_UpdateButtonState(self)
	local oldtex = self.textures.expanded
	if self:GetParent().expanded then
		self.tex = self.textures.expanded
		oldtex = self.textures.collapsed
		self.expandedIcon:SetTextColor(0.929, 0.788, 0.620)
		self.title:SetTextColor(0.929, 0.788, 0.620)
	else
		self.tex = self.textures.collapsed
		self.expandedIcon:SetTextColor(0.827, 0.659, 0.463)
		self.title:SetTextColor(0.827, 0.659, 0.463)
	end

	oldtex.up[1]:Hide()
	oldtex.up[2]:Hide()
	oldtex.up[3]:Hide()
	oldtex.down[1]:Hide()
	oldtex.down[2]:Hide()
	oldtex.down[3]:Hide()


	self.tex.up[1]:Show()
	self.tex.up[2]:Show()
	self.tex.up[3]:Show()
	self.tex.down[1]:Hide()
	self.tex.down[2]:Hide()
	self.tex.down[3]:Hide()
end

function EncounterJournal_SetUpOverview(self, role, index)
	local infoHeader
	if not self.overviews[index] then -- create a new header
		infoHeader = CreateFrame("FRAME", "EncounterJournalOverviewInfoHeader"..index, EncounterJournal.encounter.overviewFrame, "EncounterInfoTemplate")
		infoHeader.description:Hide()
		infoHeader.overviewDescription:Hide()
		infoHeader.descriptionBG:Hide()
		infoHeader.descriptionBGBottom:Hide()
		infoHeader.button.abilityIcon:Hide()
		infoHeader.button.portrait:Hide()
		infoHeader.button.portrait.name = nil
		infoHeader.button.portrait.displayInfo = nil
		infoHeader.button.icon2:Hide()
		infoHeader.button.icon3:Hide()
		infoHeader.button.icon4:Hide()
		infoHeader.overviewIndex = index
		infoHeader.isOverview = true

		local textLeftAnchor = infoHeader.button.expandedIcon
		local textRightAnchor = infoHeader.button.icon1
		infoHeader.button.title:SetPoint("LEFT", textLeftAnchor, "RIGHT", 5, 0)
		infoHeader.button.title:SetPoint("RIGHT", textRightAnchor, "LEFT", -5, 0)

		self.overviews[index] = infoHeader
	else
		infoHeader = self.overviews[index]
	end

	infoHeader.button.expandedIcon:SetText("+")
	infoHeader.expanded = false

	infoHeader:ClearAllPoints()
	if (index == 1) then
		infoHeader:SetPoint("TOPLEFT", 0, -15 - self.descriptionHeight - SECTION_BUTTON_OFFSET)
		infoHeader:SetPoint("TOPRIGHT", 0, -15 - self.descriptionHeight - SECTION_BUTTON_OFFSET)
	else
		infoHeader:SetPoint("TOPLEFT", self.overviews[index-1], "BOTTOMLEFT", 0, -9)
		infoHeader:SetPoint("TOPRIGHT", self.overviews[index-1], "BOTTOMRIGHT", 0, -9)
	end

	infoHeader.description:Hide()

	for i = 1, #infoHeader.Bullets do
		infoHeader.Bullets[i]:Hide()
	end

	wipe(infoHeader.Bullets)
	local title, description, siblingID, link, flag1

	local _, _, _, _, _, _, nextSectionID =  EJ_GetSectionInfo(self.rootOverviewSectionID)

	while nextSectionID do
		title, description, _, _, _, siblingID, _, filteredByDifficulty, link, _, _, flag1 = EJ_GetSectionInfo(nextSectionID)
		if (role == rolesByFlag[flag1] and not filteredByDifficulty) then
			break
		end
		nextSectionID = siblingID
	end

	if (not title) then
		infoHeader:Hide()
		return
	end

	infoHeader.button.icon1:Show()
	EncounterJournal_SetFlagIcon(infoHeader.button.icon1.icon, flag1)

	infoHeader.button.title:SetText(title)
	infoHeader.button.link = link
	infoHeader.sectionID = nextSectionID

	infoHeader.overviewDescription:SetWidth(infoHeader:GetWidth() - 20)
	EncounterJournal_SetDescriptionWithBullets(infoHeader, description)
	infoHeader:Show()
end

function EncounterJournal_SetDescriptionWithBullets(infoHeader, description)
    description = EncounterJournal_ParseDifficultyMacros(description)
	EncounterJournal_SetBullets(infoHeader.overviewDescription, description, true)

	infoHeader.descriptionBG:ClearAllPoints()
	infoHeader.descriptionBG:SetPoint("TOPLEFT", infoHeader.button, "BOTTOMLEFT", 1, 0)
	if (infoHeader.Bullets and #infoHeader.Bullets > 0) then
		infoHeader.descriptionBG:SetPoint("BOTTOMRIGHT", infoHeader.Bullets[#infoHeader.Bullets], -1, -11)
	else
		infoHeader.descriptionBG:SetPoint("BOTTOMRIGHT", infoHeader.overviewDescription, 9, -11)
	end
	infoHeader.descriptionBG:Hide()
	infoHeader.descriptionBGBottom:Hide()
end

function EncounterJournal_ParseDifficultyMacros(description)
    if not string.find(description, "$%[(!?)") then
        return description
    end

    local toReplace = {}

    for modificator, difficulty, text in string.gmatch(description,"%$%[(!?)([%d,]+)%s(.-)%$%]") do
    	local difficultyData = {strsplit(",", difficulty)}
    	local textDefoult = string.format("$%%[%s%s %s$%%]", modificator, difficulty, text)

    	if modificator == "!" then
    		text = string.gsub(text, "^([\n]*)(%s*%w.+)", "%1|TInterface\\EncounterJournal\\UI-EJ-WarningTextIcon.blp:0|t|cffb70e0e%2|r")
    	end

    	if tContains(difficultyData, tostring(SelectedDifficulty)) then
    		table.insert(toReplace, {textDefoult, text})
    	else
    		table.insert(toReplace, {textDefoult, ""})
    	end
    end

    for _, value in pairs(toReplace) do
    	description = description:gsub(value[1], value[2])
    end

    return description
end

function EncounterJournal_SetBullets(object, description, hideBullets)
	local parent = object:GetParent()
	local parentWidth = 60
	local characterHeight = 16

	if (not string.find(description, "\$bullet;")) then
		object.Text:SetText(description)
		object.textString = description
		local Height = (utf8len(description) / parentWidth) * characterHeight
		object:SetHeight(Height)
		-- object:SetHeight(object.Text:GetContentHeight())
		EncounterJournal_CleanBullets(parent)
		return
	end

	local desc = string.match(description, "(.-)\$bullet;")

	if (desc) then
		object.Text:SetText(desc)
		object.textString = desc
		local Height = (utf8len(desc) / parentWidth) * characterHeight
		object:SetHeight(Height)
		-- object:SetHeight(object.Text:GetContentHeight())
	end

	local bullets = {}
	for v in string.gmatch(description,"\$bullet;([^$]+)") do
		tinsert(bullets, v)
	end

	local k = 1
	local skipped = 0
	for j = 1,#bullets do
		local text = bullets[j]
		if (text and text ~= "") then
			local bullet
			bullet = parent.Bullets and parent.Bullets[k]
			if (not bullet) then
				if (parent.BulletCache and #parent.BulletCache > 0) then
					parent.Bullets[k] = tremove(parent.BulletCache)
					bullet = parent.Bullets[k]
				else
					bullet = CreateFrame("Frame", nil, parent, "EncounterOverviewBulletTemplate")
				end
				bullet:SetWidth(307)
				bullet.Text:SetWidth(300 - 26)
				-- bullet:SetWidth(parent:GetWidth() - 13)
				-- bullet.Text:SetWidth(parentWidth - 26)
			end
			bullet:ClearAllPoints()
			if (k == 1) then
				if (parent.button) then
					bullet:SetPoint("TOPLEFT", parent.button, "BOTTOMLEFT", 13, -9 - object:GetHeight())
				else
					bullet:SetPoint("TOPLEFT", parent, "TOPLEFT", 13, -9 - object:GetHeight())
				end
			else
				bullet:SetPoint("TOP", parent.Bullets[k-1], "BOTTOM", 0, -8)
			end
			bullet.Text:SetText(text)

			local Height = (utf8len(text) / parentWidth) * characterHeight or 0
			if (Height ~= 0) then
				bullet:SetHeight(Height)
			end

			-- if (bullet.Text:GetContentHeight() ~= 0) then
				-- bullet:SetHeight(bullet.Text:GetContentHeight())
			-- end

			if (hideBullets) then
				bullet:Hide()
			else
				bullet:Show()
			end
			k = k + 1
		else
			skipped = skipped + 1
		end
	end

	EncounterJournal_CleanBullets(parent, (#bullets - skipped) + 1)
end
function EncounterJournal_ResetHeaders()
	for key,_ in pairs(EJ_section_openTable) do
		EJ_section_openTable[key] = nil
	end

	PlaySound("igMainMenuOptionCheckBoxOn")
	MountJournal_UpdateScrollPos(EncounterJournal.encounter.info.lootScroll, 1)
	EJ_SetValidationDifficulty(1)
	EJ_ResetLootFilter()
	EncounterJournal_Refresh()
end

function EncounterJournal_ShiftHeaders(index)
	local usedHeaders = EncounterJournal.encounter.usedHeaders
	if not usedHeaders[index] then
		return
	end

	local _, _, _, _, anchorY = usedHeaders[index]:GetPoint()
	for i=index,#usedHeaders-1 do
		anchorY = anchorY - usedHeaders[i]:GetHeight()
		if usedHeaders[i].description:IsShown() then
			anchorY = anchorY - usedHeaders[i].description:GetHeight() - SECTION_DESCRIPTION_OFFSET
		else
			anchorY = anchorY - SECTION_BUTTON_OFFSET
		end
		usedHeaders[i+1]:SetPoint("TOPRIGHT", 0, anchorY)
	end
end

function EncounterJournal_FocusSection(sectionID)
	if (not EncounterJournal_CheckForOverview(sectionID)) then
		local usedHeaders = EncounterJournal.encounter.usedHeaders
		for _, section in pairs(usedHeaders) do
			if section.myID == sectionID then
				section.cbCount = 0
				section.button.glow.flashAnim:Play()
				section:SetScript("OnUpdate", EncounterJournal_FocusSectionCallback)
			else
				section.button.glow.flashAnim:Stop()
				section:SetScript("OnUpdate", nil)
			end
		end
	end
end

function EncounterJournal_FocusSectionCallback(self)
	if self.cbCount > 0 then
		local _, _, _, _, anchorY = self:GetPoint()
		anchorY = abs(anchorY)
		anchorY = anchorY - EncounterJournal.encounter.info.detailsScroll:GetHeight()/2
		EncounterJournal.encounter.info.detailsScroll.ScrollBar:SetValue(anchorY)
		self:SetScript("OnUpdate", nil)
	end
	self.cbCount = self.cbCount + 1
end

function EncounterJournal_MoveSectionUpdate(self)
	if self.frameCount > 0 then
		local _, _, _, _, anchorY = self:GetPoint()
		local height = min(EJ_MAX_SECTION_MOVE, self:GetHeight() + self.description:GetHeight() + SECTION_DESCRIPTION_OFFSET)
		local scrollValue = abs(anchorY) - (EncounterJournal.encounter.info.detailsScroll:GetHeight()-height)
		EncounterJournal.encounter.info.detailsScroll.ScrollBar:SetValue(scrollValue)
		self:SetScript("OnUpdate", nil)
	end
	self.frameCount = self.frameCount + 1
end

function EncounterJournal_ShowCreatures()
	local button
	local creatures = EncounterJournal.encounter.info.creatureButtons
	for i=1, #creatures do
		button = creatures[i]
		if (button.displayInfo) then
			button:Show()
			if (i==1) then
				EncounterJournal_DisplayCreature(button)
			end
		end
	end
end

function EncounterJournal_HideCreatures()
	local button
	local creatures = EncounterJournal.encounter.info.creatureButtons
	for i=1, #creatures do
		creatures[i]:Hide()
	end
end

function EncounterJournal_DisplayCreature(self)
	if EncounterJournal.encounter.info.shownCreatureButton then
		EncounterJournal.encounter.info.shownCreatureButton:Enable()
	end

	EJ_SetCreatureModel(EncounterJournal.encounter.info.model, self.displayInfo)
	EncounterJournal.ceatureDisplayID = self.displayInfo

	EncounterJournal.encounter.info.model.imageTitle:SetText(self.name)

	self:Disable()
	EncounterJournal.encounter.info.shownCreatureButton = self
end

function EncounterJournal_UpdateFilterString()
	local name = LOCALIZED_CLASS_NAMES_MALE[EJ_GetLootFilter()]
	-- local classID, specID = EJ_GetLootFilter()

	-- if (specID > 0) then
	-- 	_, name = GetSpecializationInfoByID(specID, UnitSex("player"))
	-- elseif (classID > 0) then
	-- 	name = GetClassInfoByID(classID)
	-- end

	if name then
		EncounterJournal.encounter.info.lootScroll.classClearFilter.text:SetFormattedText(EJ_CLASS_FILTER, name)
		EncounterJournal.encounter.info.lootScroll.classClearFilter:Show()
		EncounterJournal.encounter.info.lootScroll:SetHeight(360)
	else
		EncounterJournal.encounter.info.lootScroll.classClearFilter:Hide()
		EncounterJournal.encounter.info.lootScroll:SetHeight(382)
	end
end

function EncounterJournal_LootUpdate()
	EncounterJournal_UpdateFilterString()
	local scrollFrame = EncounterJournal.encounter.info.lootScroll
	local offset = HybridScrollFrame_GetOffset(scrollFrame)
	local items = scrollFrame.buttons
	local item, index

	local numLoot = EJ_GetNumLoot()
	local buttonSize = BOSS_LOOT_BUTTON_HEIGHT

	for i = 1,#items do
		item = items[i]
		index = offset + i
		if index <= numLoot then
			if (EncounterJournal.encounterID) then
				item:SetHeight(BOSS_LOOT_BUTTON_HEIGHT)
				item.boss:Hide()
				item.bossTexture:Hide()
				item.bosslessTexture:Show()
			else
				buttonSize = INSTANCE_LOOT_BUTTON_HEIGHT
				item:SetHeight(INSTANCE_LOOT_BUTTON_HEIGHT)
				item.boss:Show()
				item.bossTexture:Show()
				item.bosslessTexture:Hide()
			end
			item.index = index
			EncounterJournal_SetLootButton(item)
			item.glow.flashAnim:Stop()
		else
			item:Hide()
		end
	end

	local totalHeight = numLoot * buttonSize
	HybridScrollFrame_Update(scrollFrame, totalHeight, scrollFrame:GetHeight())
end

function EncounterJournal_SetLootButton(item)
	local itemID, encounterID, name, icon, slot, armorType, link = EJ_GetLootInfoByIndex(item.index)

	if ( name ) then
		item.name:SetText(name)
		item.icon:SetTexture(icon)
		item.slot:SetText(slot)
		item.armorType:SetText(armorType)

		item.boss:SetFormattedText(BOSS_INFO_STRING, EJ_GetEncounterInfo(encounterID))

		local itemName, _, quality = EJ_GetItemInfo(link)
		SetItemButtonQuality(item, quality, itemID)

		if (quality > LE_ITEM_QUALITY_COMMON and BAG_ITEM_QUALITY_COLORS[quality]) then
			item.name:SetTextColor(BAG_ITEM_QUALITY_COLORS[quality].r, BAG_ITEM_QUALITY_COLORS[quality].g, BAG_ITEM_QUALITY_COLORS[quality].b)
		end
	else
		item.name:SetText(RETRIEVING_ITEM_INFO)
		item.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
		item.slot:SetText("")
		item.armorType:SetText("")
		item.boss:SetText("")
		item:Hide()
	end

	item.encounterID = encounterID
	item.itemID = itemID
	item.link = link
	item:Show()

	if item.showingTooltip then
		EncounterJournal_SetTooltip(link)
	end
end

function EncounterJournal_SetTooltip(link)
	if (not link) then
		return
	end

	GameTooltip:SetAnchorType("ANCHOR_RIGHT")
	GameTooltip:SetHyperlink(link)
end

function EncounterJournal_Loot_OnUpdate(self)
	if GameTooltip:IsOwned(self) then
		if IsModifiedClick("DRESSUP") then
			ShowInspectCursor()
		else
			ResetCursor()
		end
	end
end

function EncounterJournal_OnFilterChanged(self)
	CloseDropDownMenus(1)
	EncounterJournal_LootUpdate()
end

function EncounterJournal_SetClassAndSpecFilter( self, classFileName )
	EJ_SetLootFilter( classFileName )
	EncounterJournal_OnFilterChanged(self)
end

function EncounterJournal_InitLootFilter()
	local classFileName = EJ_GetLootFilter()
	local info = UIDropDownMenu_CreateInfo()

	-- info.text = EJ_FILTER_ALL_CLASS
	-- info.checked = classFileName == NO_CLASS_FILTER
	-- info.arg1 = NO_CLASS_FILTER
	-- info.func = EncounterJournal_SetClassAndSpecFilter
	-- UIDropDownMenu_AddButton(info)

	info.func = EncounterJournal_SetClassAndSpecFilter

	for k, v in pairs(classLootData) do
		local className = LOCALIZED_CLASS_NAMES_MALE[v.fileName]

		if className then
			info.text = className
			info.arg1 = v.fileName
			info.checked = classFileName == v.fileName
			UIDropDownMenu_AddButton(info)
		end
	end
end

function EncounterJournal_InitLootSlotFilter( ... )
	local slotFilter = EJ_GetSlotFilter()

	local info = UIDropDownMenu_CreateInfo()
	info.text = ALL_INVENTORY_SLOTS
	info.checked = slotFilter == NO_INV_TYPE_FILTER
	info.arg1 = NO_INV_TYPE_FILTER
	info.func = EncounterJournal_SetSlotFilter
	UIDropDownMenu_AddButton(info)

	for _, slot in ipairs(EncounterJournalSlotFilters) do
		info.text = slot.invTypeName
		info.checked = slotFilter == slot.invType
		info.arg1 = slot.invType
		UIDropDownMenu_AddButton(info)
	end
end

function EncounterJournal_SetSlotFilter(self, slot)
	EJ_SetSlotFilter(slot)
	EncounterJournal_RefreshSlotFilterText(self)
	EncounterJournal_OnFilterChanged(self)
end

function EncounterJournal_RefreshSlotFilterText(self)
	local text = ALL_INVENTORY_SLOTS
	local slotFilter = EJ_GetSlotFilter()
	if slotFilter ~= NO_INV_TYPE_FILTER then
		for _, slot in ipairs(EncounterJournalSlotFilters) do
			if ( slot.invType == slotFilter ) then
				text = slot.invTypeName
				break
			end
		end
	end

	EncounterJournal.encounter.info.lootScroll.slotFilter:SetText(text)
end

function EncounterJournal_OnFilterChanged(self)
	CloseDropDownMenus(1)
	EncounterJournal_LootUpdate()
end

function EncounterJournal_DifficultyInit(self, level)
	local currDifficulty = EJ_GetDifficulty()
	local info = UIDropDownMenu_CreateInfo()
	for i=1,#EJ_DIFFICULTIES do
		local entry = EJ_DIFFICULTIES[i]
		if EJ_IsValidInstanceDifficulty(entry.difficultyID) and (entry.size ~= "5" == EJ_IsRaid(EncounterJournal.instanceID)) then
			info.func = EncounterJournal_SelectDifficulty
			if (entry.size ~= "5") then
				info.text = string.format("(%s) %s", entry.size, entry.prefix)
			else
				info.text = entry.prefix
			end
			info.arg1 = entry.difficultyID
			info.checked = currDifficulty == entry.difficultyID
			UIDropDownMenu_AddButton(info)
		end
	end
end

function EncounterJournal_SelectDifficulty(self, value)
	EJ_SetDifficulty(value)
end

function EncounterJournal_LootCalcScroll(offset)
	local buttonHeight = BOSS_LOOT_BUTTON_HEIGHT

	if not EncounterJournal.encounterID then
		buttonHeight = INSTANCE_LOOT_BUTTON_HEIGHT
	end

	local index = floor(offset / buttonHeight)
	return index, offset - (index * buttonHeight)
end

function EncounterJournal_Loot_OnClick(self)
	if (EncounterJournal.encounterID ~= self.encounterID) then
		PlaySound("igSpellBookOpen")
		EncounterJournal_DisplayEncounter(self.encounterID)
	end
end

function EncounterJournalSearchBox_OnLoad( self, ... )
	SearchBoxTemplate_OnLoad(self)
	self.HasStickyFocus = function()
		local ancestry = EncounterJournal.searchBox;
		return DoesAncestryInclude(ancestry, GetMouseFocus());
	end
	self.selectedIndex = 1
end

function EncounterJournalSearchBox_OnShow( self, ... )
	self:SetFrameLevel(self:GetParent():GetFrameLevel() + 10)
end

function EncounterJournalSearchBox_OnHide( self, ... )
	self.searchPreviewUpdateDelay = nil
	self:SetScript("OnUpdate", nil)
end

function EncounterJournalSearchBox_OnTextChanged( self, ... )
	SearchBoxTemplate_OnTextChanged(self)

	local text = self:GetText()
	if strlen(text) < MIN_CHARACTER_SEARCH then
		-- EJ_ClearSearch()
		EncounterJournal_HideSearchPreview()
		EncounterJournal.searchResults:Hide()
		return
	end

	EncounterJournal_SetSearchPreviewSelection(1)
	EJ_SetSearch(text)
	EncounterJournal_RestartSearchTracking()
end

function EncounterJournal_RestartSearchTracking()
	if EJ_GetNumSearchResults() > 0 then
		EncounterJournal_ShowSearch()
	else
		EncounterJournal.searchBox.searchPreviewUpdateDelay = 0
		EncounterJournal.searchBox:SetScript("OnUpdate", EncounterJournalSearchBox_OnUpdate)

		EncounterJournal.searchBox.searchProgress:Hide()
		EncounterJournal_FixSearchPreviewBottomBorder()
	end
end

local ENCOUNTER_JOURNAL_SEARCH_PREVIEW_UPDATE_DELAY = 0.6
function EncounterJournalSearchBox_OnUpdate(self, elapsed)
	if EJ_GetNumSearchResults() > 0 then
		EncounterJournal_ShowSearch()
		self.searchPreviewUpdateDelay = nil
		self:SetScript("OnUpdate", nil)
		return
	end

	self.searchPreviewUpdateDelay = (self.searchPreviewUpdateDelay or 0) + elapsed

	if self.searchPreviewUpdateDelay > ENCOUNTER_JOURNAL_SEARCH_PREVIEW_UPDATE_DELAY then
		self.searchPreviewUpdateDelay = nil
		self:SetScript("OnUpdate", nil)
		EncounterJournal_UpdateSearchPreview()
		return
	end
end

function EncounterJournal_ShowSearch()
	if EncounterJournal.searchResults:IsShown() then
		EncounterJournal_ShowFullSearch()
	else
		EncounterJournal_UpdateSearchPreview()
	end
end

function EncounterJournal_ShowFullSearch()
	local numResults = EJ_GetNumSearchResults()
	if numResults == 0 then
		EncounterJournal.searchResults:Hide()
		return
	end

	EncounterJournal.searchResults.TitleText:SetFormattedText(ENCOUNTER_JOURNAL_SEARCH_RESULTS, EncounterJournal.searchBox:GetText(), numResults)
	EncounterJournal.searchResults:Show()
	EncounterJournal_SearchUpdate()
	EncounterJournal.searchResults.scrollFrame.scrollBar:SetValue(0)
	EncounterJournal_HideSearchPreview()
	EncounterJournal.searchBox:ClearFocus()
end

function EncounterJournal_GetSearchDisplay(index)
	local name, icon, path, typeText, displayInfo, itemID, _
	local id, stype, _, instanceID, encounterID, itemLink = EJ_GetSearchResult(index)
	if stype == EJ_STYPE_INSTANCE then
		name, _, _, icon = EJ_GetInstanceInfo(id)
		typeText = ENCOUNTER_JOURNAL_INSTANCE
	elseif stype == EJ_STYPE_ENCOUNTER then
		name = EJ_GetEncounterInfo(id)
		typeText = ENCOUNTER_JOURNAL_ENCOUNTER
		path = EJ_GetInstanceInfo(instanceID)
		icon = "Interface\\EncounterJournal\\UI-EJ-GenericSearchCreature"
		--_, _, _, displayInfo = EJ_GetCreatureInfo(1, encounterID)
	elseif stype == EJ_STYPE_SECTION then
		name, _, _, icon, displayInfo = EJ_GetSectionInfo(id)
		if displayInfo and displayInfo > 0 then
			typeText = ENCOUNTER_JOURNAL_ENCOUNTER_ADD
			displayInfo = nil
			icon = "Interface\\EncounterJournal\\UI-EJ-GenericSearchCreature"
		else
			typeText = GARRISON_RECRUIT_ABILITY
		end
		path = EJ_GetInstanceInfo(instanceID).." > "..EJ_GetEncounterInfo(encounterID)
	elseif stype == EJ_STYPE_ITEM then
		itemID, _, name, icon = EJ_GetLootInfo(id)
		typeText = ENCOUNTER_JOURNAL_ITEM
		path = EJ_GetInstanceInfo(instanceID).." > "..EJ_GetEncounterInfo(encounterID)
	elseif stype == EJ_STYPE_CREATURE then
		for i=1,MAX_CREATURES_PER_ENCOUNTER do
			local cId, cName, _, cDisplayInfo = EJ_GetCreatureInfo(i, encounterID)
			if cId == id then
				name = cName
				displayInfo = cDisplayInfo
				break
			end
		end
		icon = "Interface\\EncounterJournal\\UI-EJ-GenericSearchCreature"
		typeText = CREATURE
		path = EJ_GetInstanceInfo(instanceID).." > "..EJ_GetEncounterInfo(encounterID)
	end
	return name, icon, path, typeText, displayInfo, itemID, stype, itemLink
end

function EncounterJournal_UpdateSearchPreview()
	if strlen(EncounterJournal.searchBox:GetText()) < MIN_CHARACTER_SEARCH then
		EncounterJournal_HideSearchPreview()
		EncounterJournal.searchResults:Hide()
		return
	end

	local numResults = EJ_GetNumSearchResults()

	if numResults == 0 then
		EncounterJournal_HideSearchPreview()
		return
	end

	local lastShown = EncounterJournal.searchBox
	for index = 1, EJ_NUM_SEARCH_PREVIEWS do
		local button = EncounterJournal.searchBox.searchPreview[index]
		if index <= numResults then
			local name, icon, path, typeText, displayInfo, itemID, stype, itemLink = EncounterJournal_GetSearchDisplay(index)
			button.name:SetText(name)
			button.icon:SetTexture(icon)
			button.link = itemLink
			if displayInfo and displayInfo > 0 then
				-- SetPortraitTexture(button.icon, displayInfo)
				button.icon:SetPortrait(displayInfo)
			end
			button:SetID(index)
			button:Show()
			lastShown = button
		else
			button:Hide()
		end
	end

	EncounterJournal.searchBox.showAllResults:Hide()
	EncounterJournal.searchBox.searchProgress:Hide()

	EncounterJournal.searchBox.showAllResults.text:SetFormattedText(ENCOUNTER_JOURNAL_SHOW_SEARCH_RESULTS, numResults)

	EncounterJournal_FixSearchPreviewBottomBorder()
	EncounterJournal.searchBox.searchPreviewContainer:Show()
end

function EncounterJournal_SelectSearch(index)
	local _
	local id, stype, difficultyID, instanceID, encounterID = EJ_GetSearchResult(index)
	local sectionID, creatureID, itemID
	if stype == EJ_STYPE_INSTANCE then
		instanceID = id
	elseif stype == EJ_STYPE_SECTION then
		sectionID = id
	elseif stype == EJ_STYPE_ITEM then
		itemID = id
	elseif stype == EJ_STYPE_CREATURE then
		creatureID = id
	end

	if not EJ_IsValidInstanceDifficulty(difficultyID, instanceID) then
		difficultyID = EJ_GetValidationDifficulty(1)
	end

	EncounterJournal_OpenJournal(difficultyID, instanceID, encounterID, sectionID, creatureID, itemID)
	EncounterJournal.searchResults:Hide()
	EncounterJournal_HideSearchPreview()
	EncounterJournal.searchBox:ClearFocus()
end

function EncounterJournal_OpenJournalLink(tag, jtype, id, difficultyID)
	jtype = tonumber(jtype)
	id = tonumber(id)
	difficultyID = tonumber(difficultyID)
	local instanceID, encounterID, sectionID, tierIndex = EJ_HandleLinkPath(jtype, id)
	EncounterJournal_OpenJournal(difficultyID, instanceID, encounterID, sectionID, nil, nil, tierIndex)
end

function EncounterJournal_OpenJournal(difficultyID, instanceID, encounterID, sectionID, creatureID, itemID, tierIndex)
	EJ_HideNonInstancePanels()
	ShowUIPanel(EncounterJournal)
	if instanceID then
		NavBar_Reset(EncounterJournal.navBar)
		EncounterJournal_DisplayInstance(instanceID)
		if not difficultyID or difficultyID == -1 then
			EJ_SetValidationDifficulty(1)
		else
			EJ_SetDifficulty(difficultyID)
		end
		if encounterID then
			if sectionID then
				if (EncounterJournal_CheckForOverview(sectionID)) then
					EncounterJournal.encounter.overviewFrame.linkSection = sectionID
				else
					local s, t = EJ_GetSectionPath(sectionID)
					local sectionPath = {EJ_GetSectionPath(sectionID)}
					for _, id in pairs(sectionPath) do
						EJ_section_openTable[id] = true
					end
				end
			end
			EncounterJournal_DisplayEncounter(encounterID)
			if sectionID then
				if (EncounterJournal_CheckForOverview(sectionID) or not EncounterJournal_SearchForOverview(instanceID)) then
					EncounterJournal.encounter.info.overviewTab:Click()
				else
					EncounterJournal.encounter.info.bossTab:Click()
				end
				EncounterJournal_FocusSection(sectionID)
			elseif itemID then
				local _, _, _, _, _, itemType, itemSubType = EJ_GetItemInfo(itemID)

				if not EJ_GetClassFilterValidation(itemSubType, itemType, itemID) then
					EJ_SetLootFilter(0)
					EncounterJournal_LootUpdate()
				end

				EncounterJournal.encounter.info.lootTab:Click()

				local index = 1
				local _itemID, _encounterID, _name, _icon, _slot, _armorType, _link = EJ_GetLootInfoByIndex(index)

				while _itemID do
					if _itemID == itemID then
						MountJournal_UpdateScrollPos(EncounterJournal.encounter.info.lootScroll, index)

						local buttons = EncounterJournal.encounter.info.lootScroll.buttons
						for i = 1, #buttons do
							local button = buttons[i]

							if button.itemID == itemID then
								button.glow.flashAnim:Play()
								break
							end
						end
						break
					end

					index = index + 1
					_itemID, _encounterID, _name, _icon, _slot, _armorType, _link = EJ_GetLootInfoByIndex(index)
				end
			end

		end
	elseif tierIndex then
		EncounterJournal_TierDropDown_Select(EncounterJournal, tierIndex+1)
	else
		EncounterJournal_ListInstances()
	end
end

function EncounterJournal_FixSearchPreviewBottomBorder()
	EncounterJournal.searchBox.showAllResults:SetShown(EJ_GetNumSearchResults() >= EJ_SHOW_ALL_SEARCH_RESULTS_INDEX)

	local lastShownButton = nil
	if EncounterJournal.searchBox.showAllResults:IsShown() then
		lastShownButton = EncounterJournal.searchBox.showAllResults
	elseif EncounterJournal.searchBox.searchProgress:IsShown() then
		lastShownButton = EncounterJournal.searchBox.searchProgress
	else
		for index = 1, EJ_NUM_SEARCH_PREVIEWS do
			local button = EncounterJournal.searchBox.searchPreview[index]
			if button:IsShown() then
				lastShownButton = button
			end
		end
	end

	if lastShownButton ~= nil then
		EncounterJournal.searchBox.searchPreviewContainer.botRightCorner:SetPoint("BOTTOM", lastShownButton, "BOTTOM", 0, -8)
		EncounterJournal.searchBox.searchPreviewContainer.botLeftCorner:SetPoint("BOTTOM", lastShownButton, "BOTTOM", 0, -8)
	else
		EncounterJournal_HideSearchPreview()
	end
end

function EncounterJournal_SetSearchPreviewSelection(selectedIndex)
	local searchBox = EncounterJournal.searchBox
	local numShown = 0
	for index = 1, EJ_NUM_SEARCH_PREVIEWS do
		searchBox.searchPreview[index].selectedTexture:Hide()

		if searchBox.searchPreview[index]:IsShown() then
			numShown = numShown + 1
		end
	end

	if searchBox.showAllResults:IsShown() then
		numShown = numShown + 1
	end

	searchBox.showAllResults.selectedTexture:Hide()

	if numShown == 0 then
		selectedIndex = 1
	elseif selectedIndex > numShown then
		selectedIndex = 1
	elseif selectedIndex < 1 then
		selectedIndex = numShown
	end

	searchBox.selectedIndex = selectedIndex

	if selectedIndex == EJ_SHOW_ALL_SEARCH_RESULTS_INDEX then
		searchBox.showAllResults.selectedTexture:Show()
	else
		searchBox.searchPreview[selectedIndex].selectedTexture:Show()
	end
end

function EncounterJournal_HideSearchPreview()
	EncounterJournal.searchBox.showAllResults:Hide()
	EncounterJournal.searchBox.searchProgress:Hide()

	local index = 1
	local unusedButton = EncounterJournal.searchBox.searchPreview[index]
	while unusedButton do
		unusedButton:Hide()
		index = index + 1
		unusedButton = EncounterJournal.searchBox.searchPreview[index]
	end

	EncounterJournal.searchBox.searchPreviewContainer:Hide()
end

function EncounterJournalSearchBox_OnEnterPressed( self, ... )
	if self.selectedIndex > EJ_SHOW_ALL_SEARCH_RESULTS_INDEX or self.selectedIndex < 0 then
		return
	elseif self.selectedIndex == EJ_SHOW_ALL_SEARCH_RESULTS_INDEX then
		if EncounterJournal.searchBox.showAllResults:IsShown() then
			EncounterJournal.searchBox.showAllResults:Click()
		end
	else
		local preview = EncounterJournal.searchBox.searchPreview[self.selectedIndex]
		if preview:IsShown() then
			preview:Click()
		end
	end

	EncounterJournal_HideSearchPreview()
end

function EncounterJournalSearchBox_OnKeyDown( self, key )
	if key == "UP" then
		EncounterJournal_SetSearchPreviewSelection(EncounterJournal.searchBox.selectedIndex - 1)
	elseif key == "DOWN" then
		EncounterJournal_SetSearchPreviewSelection(EncounterJournal.searchBox.selectedIndex + 1)
	end
end

function EncounterJournalSearchBox_OnFocusLost( self, ... )
	SearchBoxTemplate_OnEditFocusLost(self)
	EncounterJournal_HideSearchPreview()
end

function EncounterJournalSearchBox_OnFocusGained( self, ... )
	SearchBoxTemplate_OnEditFocusGained(self)
	EncounterJournal.searchResults:Hide()
	EncounterJournal_SetSearchPreviewSelection(1)
	EncounterJournal_UpdateSearchPreview()
end

function EncounterJournalSearchBoxSearchProgressBar_OnLoad( self, ... )
	self:SetStatusBarColor(0, .6, 0, 1)
	self:SetMinMaxValues(0, 1000)
	self:SetValue(0)
	self:GetStatusBarTexture():SetDrawLayer("BORDER")
end

function EncounterJournalSearchBoxSearchProgressBar_OnShow( self, ... )
	-- self:SetScript("OnUpdate", EncounterJournalSearchBoxSearchProgressBar_OnUpdate)
end

function EncounterJournalSearchBoxSearchProgressBar_OnHide( self, ... )
	self:SetScript("OnUpdate", nil)
	self:SetValue(0)
	self.previousResults = nil
end

function EncounterJournal_SearchUpdate()
	local scrollFrame = EncounterJournal.searchResults.scrollFrame
	local offset = HybridScrollFrame_GetOffset(scrollFrame)
	local results = scrollFrame.buttons
	local result, index

	local numResults = EJ_GetNumSearchResults()

	for i = 1,#results do
		result = results[i]
		index = offset + i
		if index <= numResults then
			local name, icon, path, typeText, displayInfo, itemID, stype, itemLink = EncounterJournal_GetSearchDisplay(index)
			if stype == EJ_STYPE_INSTANCE then
				result.icon:SetTexCoord(0.16796875, 0.51171875, 0.03125, 0.71875)
			else
				result.icon:SetTexCoord(0, 1, 0, 1)
			end

			result.name:SetText(name)
			result.resultType:SetText(typeText)
			result.path:SetText(path)
			result.icon:SetTexture(icon)
			result.link = itemLink
			if displayInfo and displayInfo > 0 then
				-- SetPortraitTexture(result.icon, displayInfo)
				result.icon:SetPortrait(displayInfo)
			end
			result:SetID(index)
			result:Show()

			if result.showingTooltip then
				if itemLink then
					GameTooltip:SetOwner(result, "ANCHOR_RIGHT")
					GameTooltip:SetHyperlink(itemLink)
					GameTooltip_ShowCompareItem()
				else
					GameTooltip:Hide()
				end
			end
		else
			result:Hide()
		end
	end

	local totalHeight = numResults * 49
	HybridScrollFrame_Update(scrollFrame, totalHeight, 370)
end

function EncounterJournalSearchBoxShowAllResults_OnEnter(self)
	EncounterJournal_SetSearchPreviewSelection(EJ_SHOW_ALL_SEARCH_RESULTS_INDEX)
end

function LootJournal_GetEJItemInfoByEntry( itemEntry )
	if not itemEntry then
		return
	end

	local _, encounterID, _, _, _, _, _, difficultyID, factionID = EJ_GetLootInfo(itemEntry)

	if encounterID then
		local _, _, _, _, _, instanceID = EJ_GetEncounterInfo(encounterID)

		if difficultyID and encounterID and instanceID and encounterID then
			return difficultyID, encounterID, instanceID, encounterID, factionID
		end
	end

	return
end

function LootJournal_OpenItemByEntry( itemEntry )
	if not itemEntry then
		return
	end

	local difficultyID, encounterID, instanceID, encounterID = LootJournal_GetEJItemInfoByEntry(itemEntry)

	if encounterID then
		EncounterJournal_OpenJournal(difficultyID, instanceID, encounterID, nil, nil, itemEntry)
	end
end

local factionData = {
	[PLAYER_FACTION_GROUP.Horde] = -3,
	[PLAYER_FACTION_GROUP.Alliance] = -2,
	[PLAYER_FACTION_GROUP.Renegade] = -4,
	[PLAYER_FACTION_GROUP.Neutral] = -1,
}

function LootJournal_CanOpenItemByEntry( itemEntry, dontIgnoredFaction )
	local _, encounterID, _, _, factionID = LootJournal_GetEJItemInfoByEntry(itemEntry)
	local canOpened = false

	if encounterID then
		canOpened = true
	end

	if dontIgnoredFaction then
		local playerFactionID 		= C_Unit:GetFactionID("player")
		local convertedFactionID 	= factionData[playerFactionID]

		if factionID ~= convertedFactionID and factionID ~= -1 then
			canOpened = false
		end
	end

	return canOpened
end

function LootJournal_CheckFilterValidation( classID, specID )
	local specFilter = LOOTJOURNAL_SPECFILTER == 3 and 4 or LOOTJOURNAL_SPECFILTER

	if LOOTJOURNAL_CLASSFILTER and specFilter then
		if LOOTJOURNAL_CLASSFILTER == NO_CLASS_FILTER and specFilter == NO_SPEC_FILTER then
			return true
		elseif LOOTJOURNAL_CLASSFILTER == classID and specFilter == NO_SPEC_FILTER then
			return true
		elseif LOOTJOURNAL_CLASSFILTER == classID and bit.band(specFilter, specID) == specFilter then
			return true
		end

		return false
	end

	return false
end

LOOTJOURNAL_FACTION_NEUTRAL = 0
LOOTJOURNAL_FACTION_ALLIANCE = 1
LOOTJOURNAL_FACTION_HORDE = 2
function LootJournal_FactionValidation( factionID )
	local factionGroup = UnitFactionGroup("player")
	if factionGroup == "Renegade" then
		local raceData = C_CreatureInfo.GetFactionInfo(UnitRace("player"))
		if raceData then
			factionGroup = raceData.groupTag
		end
	end

	factionGroup = factionGroup or "NEUTRAL"

	if factionID == LOOTJOURNAL_FACTION_NEUTRAL then
		return true
	elseif factionID == _G["LOOTJOURNAL_FACTION_"..string.upper(factionGroup)] then
		return true
	end

	return false
end

local LootJournal_LootBuffer = {}
function LootJournal_GenerateLootData()
	LootJournal_LootBuffer = {}

	for i = 1, #EJ_LOOTJOURNAL_DATA do
		local data = EJ_LOOTJOURNAL_DATA[i]

		if data then
			local name 			= data[1]
			local itemlevel 	= data[2]
			local tierName 		= data[3]
			local source 		= data[4]
			local classID 		= data[5]
			local specID 		= data[6]
			local isPVP 		= data[7] == 1
			local tempitems 	= data[8]
			local items 		= {}
			local factionID 	= data[9] or 0

			if LootJournal_CheckFilterValidation( classID, specID ) and LootJournal_FactionValidation(factionID) then
				local numItems = 0

				if tempitems and #tempitems > 0 then
					numItems = #tempitems

					for j = 1, numItems do
						local itemEntry = tempitems[j]
						local _, itemLink, itemQuality, _, _, _, _, _, _, itemTexture = EJ_GetItemInfo(itemEntry)

						items[j] = {itemEntry, itemLink, itemQuality, itemTexture}
					end
				end

				LootJournal_LootBuffer[#LootJournal_LootBuffer + 1] = {name, tierName, itemlevel, source, isPVP, items, numItems}
			end
		end
	end

	table.sort(LootJournal_LootBuffer, function(a, b)
		return a[3] > b[3]
	end)

	return LootJournal_LootBuffer
end

function LootJournal_GetNumLoot()
	return #LootJournal_LootBuffer
end

function LootJournal_GetSetInfo( index )
	if not index then
		return
	end

	local data = LootJournal_LootBuffer

	if data[index] then
		return unpack(data[index])
	end

	return
end

function LootJournalItemSetsScrollFrame_OnLoad( self, ... )
	self.scrollBar.trackBG:Hide()
	self.update = LootJournalItemSetsScrollFrame_UpdateList
	HybridScrollFrame_CreateButtons(self, "LootJournalItemSetButtonTemplate", LJ_ITEMSET_X_OFFSET, -LJ_ITEMSET_Y_OFFSET, "TOPLEFT", nil, nil, -LJ_ITEMSET_BUTTON_SPACING);
end

function LootJournalItemSetsScrollFrame_OnShow( self, ... )
	LootJournalItemSetsScrollFrame_UpdateList()
end

function LootJournalItemButton_OnEnter( self, ... )
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:SetHyperlink(self.itemLink)

	if LootJournal_CanOpenItemByEntry(self.itemID) then
		GameTooltip:AddLine(LOOTJOURNAL_ITEM_CLICK_TO_OPEN_LOOT, 0, 0.8, 1)
	end

	GameTooltip:Show()

	EncounterJournal.LootJournal.ItemSetsScrollFrame.activeItemSetButton = self
end

function LootJournalItemButton_OnClick( self, ... )
	if HandleModifiedItemClick(self.itemLink) then
		return
	end

	LootJournal_OpenItemByEntry(self.itemID)
end

function LootJournalItemButton_OnUpdate(self)
	if GameTooltip:IsOwned(self) then
		if IsModifiedClick("DRESSUP") then
			ShowInspectCursor();
		else
			ResetCursor();
		end
	end
end

function LootJournalItemSetsScrollFrame_UpdateList()
	local scrollFrame = EncounterJournal.LootJournal.ItemSetsScrollFrame
	local buttons = scrollFrame.buttons
	local offset = HybridScrollFrame_GetOffset(scrollFrame)

	local numSets = LootJournal_GetNumLoot()

	for i = 1, #buttons do
		local button = buttons[i]
		local index = offset + i

		if ( index <= numSets ) then
			local name, tierName, itemlevel, source, isPVP, items, numItems = LootJournal_GetSetInfo(index)

			button.SetName:SetText(name)
			button.ItemLevel:SetFormattedText(EJ_SET_ITEM_LEVEL, tierName, itemlevel)
			button.PVPIcon:SetShown(isPVP)

			button.tooltipText = source

			for j = 1, numItems do
				local itemButton = button.ItemButtons[j]
				local itemData 	 = items[j]

				itemButton.Icon:SetTexture(itemData[4] or "Interface\\ICONS\\temp")

				local itemQuality = itemData[3] or LE_ITEM_QUALITY_EPIC
				if ( itemQuality == LE_ITEM_QUALITY_UNCOMMON ) then
					itemButton.Border:SetTexCoord(0.171875, 0.332031, 0.0078125, 0.328125)
				elseif ( itemQuality == LE_ITEM_QUALITY_RARE ) then
					itemButton.Border:SetTexCoord(0.339844, 0.5, 0.0078125, 0.328125)
				elseif ( itemQuality == LE_ITEM_QUALITY_EPIC ) then
					itemButton.Border:SetTexCoord(0.00390625, 0.164062, 0.0078125, 0.328125)
				end

				itemButton:GetParent().SetName:SetTextColor(GetItemQualityColor(itemQuality))

				itemButton.itemID = itemData[1]
				itemButton.itemLink = itemData[2]

				itemButton:Show()
			end

			for j = numItems + 1, #button.ItemButtons do
				button.ItemButtons[j].itemID = nil
				button.ItemButtons[j]:Hide()
			end

			button:Show()
		else
			button:Hide()
		end
	end

	local totalHeight = numSets * buttons[1]:GetHeight() + (numSets - 1) * LJ_ITEMSET_BUTTON_SPACING + LJ_ITEMSET_Y_OFFSET + LJ_ITEMSET_BOTTOM_BUFFER
	HybridScrollFrame_Update(scrollFrame, totalHeight, scrollFrame:GetHeight())

	if EncounterJournal.LootJournal.ItemSetsScrollFrame.activeButton then
		LootJournalItemSetButton_OnEnter(EncounterJournal.LootJournal.ItemSetsScrollFrame.activeButton)
	end

	if EncounterJournal.LootJournal.ItemSetsScrollFrame.activeItemSetButton then
		LootJournalItemButton_OnEnter(EncounterJournal.LootJournal.ItemSetsScrollFrame.activeItemSetButton)
	end
end

function LootJournalItemSetButton_OnEnter( self, ... )
	if self:GetParent().tooltipText then
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText(LOOTJOURNAL_SOURCE_TOOLTIP_HEAD, 1, 1, 1)
		GameTooltip:AddLine(self:GetParent().tooltipText, nil, nil, nil, 1)
		GameTooltip:Show()

		EncounterJournal.LootJournal.ItemSetsScrollFrame.activeButton = self
	else
		GameTooltip_Hide()
	end
end

function LootJournalClassDropDown_OnLoad( self, ... )
	UIDropDownMenu_Initialize(self, LootJournalClassDropDown_Init, "MENU")
end

function LootJournalSetClassAndSpecFilters( _, classFilter, specFilter )
	LOOTJOURNAL_CLASSFILTER = classFilter
	LOOTJOURNAL_SPECFILTER = specFilter
	CloseDropDownMenus(1)

	LootJournal_GenerateLootData()
	LootJournalItemSetsScrollFrame_UpdateList()

	-- print("classFilter -", classFilter, "specFilter -", specFilter)
end

function LootJournalClassDropDown_Init(self, level)
	local info = UIDropDownMenu_CreateInfo()

	local filterClassID = LOOTJOURNAL_CLASSFILTER
	local filterSpecID = LOOTJOURNAL_SPECFILTER

	if UIDROPDOWNMENU_MENU_VALUE == CLASS_DROPDOWN then
		info.text = ALL_CLASSES
		info.checked = filterClassID == NO_CLASS_FILTER
		info.arg1 = NO_CLASS_FILTER
		info.arg2 = NO_SPEC_FILTER
		info.func = LootJournalSetClassAndSpecFilters
		UIDropDownMenu_AddButton(info, level)

		local numClasses = GetNumClasses()
		for i = 1, numClasses do
			local classDisplayName, classTag, classID = GetClassInfo(i)
			if classID ~= 10 then -- temp remove demonhunter
				info.text = classDisplayName
				info.checked = filterClassID == classID
				info.arg1 = classID
				info.arg2 = NO_SPEC_FILTER
				info.func = LootJournalSetClassAndSpecFilters
				UIDropDownMenu_AddButton(info, level)
			end
		end
	end

	if level == 1 then
		info.text = CLASS
		info.func =  nil
		info.notCheckable = true
		info.hasArrow = true
		info.value = CLASS_DROPDOWN
		UIDropDownMenu_AddButton(info, level)

		local classDisplayName, classTag, classID
		if filterClassID ~= NO_CLASS_FILTER then
			classID = filterClassID
			classDisplayName = GetClassInfo(classID)
		else
			classDisplayName, classTag, classID = UnitClass("player")
		end

		info.text = classDisplayName
		info.notCheckable = true
		info.arg1 = nil
		info.arg2 = nil
		info.func =  nil
		info.hasArrow = false
		UIDropDownMenu_AddButton(info, level)

		info.notCheckable = nil;
		for i = 1, GetNumSpecializationsForClassID(classID) do
			local _, specName, _, _, _, _, specNum = GetSpecializationInfoForClassID(classID, i)
			info.leftPadding = 10
			info.text = specName
			info.checked = filterSpecID == specNum
			info.arg1 = classID
			info.arg2 = specNum
			info.func = LootJournalSetClassAndSpecFilters
			UIDropDownMenu_AddButton(info, level)
		end

		info.text = ALL_SPECS
		info.leftPadding = 10
		info.checked = (classID == filterClassID and filterSpecID == NO_SPEC_FILTER) or (filterClassID == NO_CLASS_FILTER and filterSpecID == NO_SPEC_FILTER)
		info.arg1 = classID
		info.arg2 = NO_SPEC_FILTER
		info.func = LootJournalSetClassAndSpecFilters
		UIDropDownMenu_AddButton(info, level)
	end
end